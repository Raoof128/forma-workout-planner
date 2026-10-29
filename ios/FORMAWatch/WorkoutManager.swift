import Foundation
import HealthKit
import Observation
import WatchConnectivity

/// Owns the HealthKit workout on the Watch. Pressing Start begins collection
/// and mirrors the session to the iPhone, which logs the sets.
@MainActor @Observable
final class WorkoutManager {
  static let shared = WorkoutManager()

  enum Phase: Equatable {
    case idle
    case ready
    case starting
    case running
    case paused
    case ending
    case summary(WatchMetrics, saved: Bool)
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  private(set) var routineName: String?
  /// Whole beats per minute and kilocalories as shown on screen. They change
  /// only when the rounded number does, so a view reading one re-renders when
  /// its own text changes, not on every HealthKit sample.
  private(set) var heartRate: Int?
  private(set) var activeEnergy: Int?
  /// The full snapshot, sent to the iPhone. Not observed: no view reads it.
  @ObservationIgnored private(set) var metrics: WatchMetrics?
  /// Whether the iPhone is following this workout.
  private(set) var mirrored = false
  private(set) var reconnecting = false
  private(set) var savingRecording = false

  var hasFailedRecording: Bool {
    if case .failed = phase { return session != nil }
    return false
  }

  private let healthStore = HKHealthStore()
  @ObservationIgnored private let bridge = WorkoutBridge()
  @ObservationIgnored private var session: HKWorkoutSession?
  @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
  @ObservationIgnored private var configuration = WatchWorkout.configuration()
  @ObservationIgnored private var saveWhenStopped = true
  @ObservationIgnored private var lastSent = Date.distantPast
  @ObservationIgnored private var lastSentKey: SentKey?

  /// What the iPhone shows; a message that changes none of it can wait.
  private struct SentKey: Equatable {
    var state: WatchMetrics.State
    var heartRate: Int?
    var activeEnergy: Int?
  }

  private static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
  private static let heartRateType = HKQuantityType(.heartRate)
  private static let activeEnergyType = HKQuantityType(.activeEnergyBurned)

  private init() {
    bridge.owner = self
    if WCSession.isSupported() {
      WCSession.default.delegate = bridge
      WCSession.default.activate()
    }
  }

  // MARK: - Starting

  /// The iPhone opened this app for a routine; wait for the Start button.
  func prepare(_ configuration: HKWorkoutConfiguration) {
    guard session == nil else { return }
    self.configuration = configuration
    routineName = Self.pendingRoutineName(WCSession.default.receivedApplicationContext)
    phase = .ready
  }

  fileprivate func contextChanged(_ context: [String: Any]) {
    routineName = Self.pendingRoutineName(context)
    // The iPhone started without the Watch: stop offering its routine.
    if phase == .ready, routineName == nil { phase = .idle }
  }

  private static func pendingRoutineName(_ context: [String: Any]) -> String? {
    guard let name = context[WatchWorkout.routineNameKey] as? String, !name.isEmpty,
      let requested = context[WatchWorkout.requestedAtKey] as? Double,
      Date.now.timeIntervalSince1970 - requested < 15 * 60
    else { return nil }
    return name
  }

  func start() async {
    guard session == nil, phase != .starting else { return }
    phase = .starting
    do {
      try await healthStore.requestAuthorization(
        toShare: WatchWorkout.shareTypes, read: WatchWorkout.readTypes)
      let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore, workoutConfiguration: configuration)
      session.delegate = bridge
      builder.delegate = bridge
      self.session = session
      self.builder = builder
      saveWhenStopped = true
      let startDate = Date.now
      session.startActivity(with: startDate)
      try await builder.beginCollection(at: startDate)
      metrics = WatchMetrics(state: .running, startedAt: startDate, elapsed: 0)
      lastSentKey = nil
      showMetrics()
      phase = .running
      await mirror(session)
    } catch {
      session?.end()
      session = nil
      builder = nil
      phase = .failed("The workout couldn't start. \(error.localizedDescription)")
    }
  }

  /// The Watch keeps recording if the iPhone can't follow; the sets can
  /// still be logged there once the workout is opened.
  private func mirror(_ session: HKWorkoutSession) async {
    guard self.session === session, !reconnecting else { return }
    reconnecting = true
    defer { reconnecting = false }
    do {
      try await session.startMirroringToCompanionDevice()
      guard self.session === session else { return }
      mirrored = true
      send(force: true)
    } catch {
      if self.session === session { mirrored = false }
    }
  }

  /// A failed mirror does not stop Health collection. Retry only on request,
  /// and keep a single attempt in flight rather than polling in the background.
  func reconnect() async {
    guard !mirrored, phase == .running || phase == .paused, let session else { return }
    await mirror(session)
  }

  /// Relaunch after a crash: reattach to the workout that is still running.
  func recover() async {
    guard session == nil else { return }
    do {
      guard let session = try await healthStore.recoverActiveWorkoutSession() else { return }
      let builder = session.associatedWorkoutBuilder()
      if builder.dataSource == nil {
        builder.dataSource = HKLiveWorkoutDataSource(
          healthStore: healthStore, workoutConfiguration: session.workoutConfiguration)
      }
      session.delegate = bridge
      builder.delegate = bridge
      self.session = session
      self.builder = builder
      metrics = WatchMetrics(
        state: session.state == .paused ? .paused : .running,
        startedAt: builder.startDate ?? session.startDate ?? .now, elapsed: builder.elapsedTime)
      phase = session.state == .paused ? .paused : .running
      collected()
      await mirror(session)
    } catch {
      phase = .failed("Your workout couldn't be restored. \(error.localizedDescription)")
    }
  }

  /// Active time, excluding pauses, as HealthKit records it.
  func elapsed(at date: Date) -> TimeInterval {
    builder?.elapsedTime(at: date) ?? metrics?.elapsed ?? 0
  }

  // MARK: - Controls

  func pause() { session?.pause() }
  func resume() { session?.resume() }

  /// Stop, wait for HealthKit to report stopped, then end collection, save
  /// (or discard) and end the session, in the order HealthKit requires.
  func end(save: Bool) {
    guard let session, phase == .running || phase == .paused else { return }
    saveWhenStopped = save
    phase = .ending
    session.stopActivity(with: .now)
  }

  func dismissSummary() {
    phase = routineName == nil ? .idle : .ready
    metrics = nil
    showMetrics()
  }

  /// Only an explicit, confirmed discard may abandon a failed builder. A
  /// delegate error alone must never silently throw away unsaved Health data.
  func discardFailedRecording() {
    guard hasFailedRecording, !savingRecording, let session else { return }
    session.end()
    // HealthKit discards the workout result; samples already added to Health
    // are retained by the system. This is not a deletion of Health history.
    builder?.discardWorkout()
    metrics?.state = .ended
    send(force: true)
    self.session = nil
    builder = nil
    mirrored = false
    metrics = nil
    routineName = nil
    showMetrics()
    phase = .idle
  }

  // MARK: - HealthKit callbacks

  fileprivate func stateChanged(
    to state: HKWorkoutSessionState, date: Date, from session: HKWorkoutSession
  ) {
    guard self.session === session else { return }
    switch state {
    case .running:
      if phase == .paused { phase = .running }
      metrics?.state = .running
      send(force: true)
    case .paused:
      if phase == .running { phase = .paused }
      metrics?.state = .paused
      send(force: true)
    case .stopped:
      // `finish` sends the final snapshot; one here would only repeat the last.
      Task { await finish(at: date, session: session) }
    default:
      break
    }
  }

  private func finish(at date: Date, session: HKWorkoutSession) async {
    guard self.session === session, let builder, !savingRecording else { return }
    savingRecording = true
    defer { savingRecording = false }
    do {
      try await builder.endCollection(at: date)
      guard self.session === session else { return }
      if saveWhenStopped {
        // A nil workout without an error means it was saved while the
        // device was locked; never save a second copy.
        _ = try await builder.finishWorkout()
      } else {
        builder.discardWorkout()
      }
    } catch {
      phase = .failed("Your workout couldn't be saved to Health. \(error.localizedDescription)")
      session.end()
      metrics?.state = .ended
      send(force: true)
      // Keep the failed builder reachable until the user explicitly discards.
      // A failed save is never converted into a successful summary or a new Start.
      return
    }
    session.end()
    metrics?.state = .ended
    metrics?.elapsed = builder.elapsedTime
    send(force: true)
    let summary = metrics ?? WatchMetrics(state: .ended, startedAt: date, elapsed: 0)
    self.session = nil
    self.builder = nil
    mirrored = false
    if case .failed = phase { return }
    phase = .summary(summary, saved: saveWhenStopped)
    routineName = nil
  }

  fileprivate func failed(_ error: Error, from session: HKWorkoutSession) {
    guard self.session === session else { return }
    phase = .failed("The workout stopped unexpectedly. \(error.localizedDescription)")
  }

  fileprivate func collected(from expected: HKLiveWorkoutBuilder? = nil) {
    if let expected, builder !== expected { return }
    guard let builder, metrics != nil else { return }
    let heart = builder.statistics(for: Self.heartRateType)
    metrics?.heartRate = heart?.mostRecentQuantity()?.doubleValue(for: Self.beatsPerMinute)
    metrics?.averageHeartRate = heart?.averageQuantity()?.doubleValue(for: Self.beatsPerMinute)
    metrics?.activeEnergy = builder.statistics(for: Self.activeEnergyType)?
      .sumQuantity()?.doubleValue(for: .kilocalorie())
    metrics?.elapsed = builder.elapsedTime
    showMetrics()
    send(force: false)
  }

  /// Publish the rounded values the views show, only when they change.
  private func showMetrics() {
    let rate = metrics?.heartRate.map { Int($0.rounded()) }
    if heartRate != rate { heartRate = rate }
    let energy = metrics?.activeEnergy.map { Int($0.rounded()) }
    if activeEnergy != energy { activeEnergy = energy }
  }

  fileprivate func received(_ data: [Data], from session: HKWorkoutSession) {
    guard self.session === session else { return }
    for message in data.compactMap(WatchWorkoutMessage.decode) {
      switch message {
      case .pause: pause()
      case .resume: resume()
      case .end(let save): end(save: save)
      case .metrics: break
      }
    }
  }

  fileprivate func disconnected(from session: HKWorkoutSession) {
    guard self.session === session else { return }
    mirrored = false
  }

  /// At most about once a second, and unchanged readings only every ten
  /// seconds (to keep elapsed time and average fresh), so the link and battery
  /// stay quiet.
  private func send(force: Bool) {
    guard let session, mirrored, let metrics else { return }
    let key = SentKey(
      state: metrics.state, heartRate: metrics.heartRate.map { Int($0.rounded()) },
      activeEnergy: metrics.activeEnergy.map { Int($0.rounded()) })
    let now = Date.now
    if !force {
      let age = now.timeIntervalSince(lastSent)
      guard age >= 1, key != lastSentKey || age >= 10 else { return }
    }
    lastSent = now
    lastSentKey = key
    guard let data = try? WatchWorkoutMessage.metrics(metrics).encoded() else { return }
    let target = UncheckedSendable(session)
    Task { try? await target.value.sendToRemoteWorkoutSession(data: data) }
  }
}

private final class WorkoutBridge: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate,
  WCSessionDelegate, @unchecked Sendable
{
  @MainActor weak var owner: WorkoutManager?
  private let heartRateType: HKSampleType = HKQuantityType(.heartRate)
  private let activeEnergyType: HKSampleType = HKQuantityType(.activeEnergyBurned)

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.stateChanged(to: toState, date: date, from: session.value) }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    let error = UncheckedSendable(error)
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.failed(error.value, from: session.value) }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.received(data, from: session.value) }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.disconnected(from: session.value) }
  }

  func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    // Basal energy and other types the Watch doesn't show arrive here too;
    // skip them before hopping to the main actor.
    guard collectedTypes.contains(heartRateType) || collectedTypes.contains(activeEnergyType)
    else { return }
    let builder = UncheckedSendable(workoutBuilder)
    Task { @MainActor in owner?.collected(from: builder.value) }
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let context = UncheckedSendable(session.receivedApplicationContext)
    Task { @MainActor in owner?.contextChanged(context.value) }
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    let context = UncheckedSendable(context)
    Task { @MainActor in owner?.contextChanged(context.value) }
  }
}

struct UncheckedSendable<Value>: @unchecked Sendable {
  let value: Value
  init(_ value: Value) { self.value = value }
}
