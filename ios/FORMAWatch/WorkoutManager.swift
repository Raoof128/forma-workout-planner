import Foundation
import HealthKit
import Observation
import WatchConnectivity
import os

/// Owns the HealthKit workout on the Watch. Pressing Start begins collection
/// and mirrors the session to the iPhone, which logs the sets.
@MainActor @Observable
final class WorkoutManager {
  static let shared = WorkoutManager()

  enum Phase: Equatable {
    case idle
    case ready
    case starting
    /// watchOS relaunched FORMA during a workout and the session is being reattached.
    case recovering
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
  /// Health write access for workouts is off. Set when Start finds it denied or
  /// a save fails for that reason, so the Watch can say how to turn it back on.
  private(set) var healthAccessDenied = false
  /// Heart rate or energy can't be saved to Health: those rows say so instead
  /// of showing "--" forever.
  private(set) var heartRateOff = false
  private(set) var activeEnergyOff = false
  /// Reattaching to the running workout failed; the person can retry or dismiss.
  private(set) var recoveryFailed = false

  /// Whether the workout being stopped will be saved, for the wording of the wait.
  var savingToHealth: Bool { saveWhenStopped }

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
  /// Where HealthKit stopped the session, kept so a retried save ends the
  /// builder at the same moment.
  @ObservationIgnored private var stoppedAt: Date?
  @ObservationIgnored private var collectionEnded = false
  /// The iPhone's routine offer was used (a workout started or ended after it
  /// was made), so an older application context must not offer it again.
  @ObservationIgnored private var offerConsumedAt: Date?

  private static let log = Logger(subsystem: "dev.raoufabedini.forma.watch", category: "workout")
  /// The longest silence between messages to the iPhone while nothing changes.
  /// The iPhone calls readings stale after three of these.
  private static let heartbeat: TimeInterval = 20

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
    routineName = pendingRoutineName(WCSession.default.receivedApplicationContext)
    phase = .ready
  }

  fileprivate func contextChanged(_ context: [String: Any]) {
    routineName = pendingRoutineName(context)
    // The iPhone started without the Watch: stop offering its routine.
    if phase == .ready, routineName == nil { phase = .idle }
  }

  /// The routine the iPhone is offering, unless it is old or a workout has
  /// started or ended since the offer was made.
  private func pendingRoutineName(_ context: [String: Any]) -> String? {
    guard let name = context[WatchWorkout.routineNameKey] as? String, !name.isEmpty,
      let requested = context[WatchWorkout.requestedAtKey] as? Double,
      Date.now.timeIntervalSince1970 - requested < 15 * 60,
      requested > (offerConsumedAt?.timeIntervalSince1970 ?? 0)
    else { return nil }
    return name
  }

  func start() async {
    guard session == nil, phase != .starting, phase != .recovering else { return }
    phase = .starting
    healthAccessDenied = false
    do {
      try await healthStore.requestAuthorization(
        toShare: WatchWorkout.shareTypes, read: WatchWorkout.readTypes)
      // Declining does not throw, so ask HealthKit what was granted. Without
      // workout write access the recording could only fail at End.
      guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied
      else {
        healthAccessDenied = true
        phase = .failed(Self.healthAccessMessage)
        return
      }
      heartRateOff = healthStore.authorizationStatus(for: Self.heartRateType) == .sharingDenied
      activeEnergyOff =
        healthStore.authorizationStatus(for: Self.activeEnergyType) == .sharingDenied
      let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
      let builder = session.associatedWorkoutBuilder()
      builder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore, workoutConfiguration: configuration)
      session.delegate = bridge
      builder.delegate = bridge
      self.session = session
      self.builder = builder
      saveWhenStopped = true
      collectionEnded = false
      stoppedAt = nil
      let startDate = Date.now
      offerConsumedAt = startDate
      session.startActivity(with: startDate)
      try await builder.beginCollection(at: startDate)
      metrics = WatchMetrics(state: .running, startedAt: startDate, elapsed: 0)
      lastSentKey = nil
      showMetrics()
      phase = .running
      await mirror(session)
    } catch {
      Self.log.error("Start failed: \(error.localizedDescription, privacy: .private)")
      session?.end()
      session = nil
      builder = nil
      healthAccessDenied = Self.isAccessDenied(error)
      phase = .failed(Self.message(for: error, doing: .start))
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

  /// The iPhone app became reachable again: try once to restore mirroring.
  fileprivate func reachabilityChanged(isReachable: Bool) {
    guard isReachable, !mirrored, phase == .running || phase == .paused else { return }
    Task { await reconnect() }
  }

  /// Relaunch after a crash: reattach to the workout that is still running.
  func recover() async {
    guard session == nil, phase != .starting, phase != .recovering else { return }
    let before = phase
    phase = .recovering
    recoveryFailed = false
    do {
      guard let session = try await healthStore.recoverActiveWorkoutSession() else {
        // Nothing was running: put back what the screen showed before.
        if case .failed = before {
          phase = routineName == nil ? .idle : .ready
        } else {
          phase = before
        }
        recoveryFailed = false
        return
      }
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
      collectionEnded = false
      stoppedAt = nil
      collected()
      await mirror(session)
    } catch {
      Self.log.error("Recovery failed: \(error.localizedDescription, privacy: .private)")
      recoveryFailed = true
      phase = .failed(Self.message(for: error, doing: .restore))
    }
  }

  /// Give up on reattaching. The workout, if HealthKit still has one, is not
  /// touched; the person can start a new one.
  func dismissRecoveryFailure() {
    guard recoveryFailed else { return }
    recoveryFailed = false
    phase = routineName == nil ? .idle : .ready
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

  /// Try the Health save again after it failed. The recording is still held by
  /// the builder; only an explicit discard abandons it.
  func retrySave() {
    guard hasFailedRecording, !savingRecording, let session else { return }
    saveWhenStopped = true
    phase = .ending
    switch session.state {
    case .running, .paused:
      // The session failed but never stopped: stop it, and `stateChanged` saves.
      session.stopActivity(with: .now)
    default:
      Task { await finish(at: stoppedAt ?? .now, session: session) }
    }
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
    offerConsumedAt = .now
    healthAccessDenied = false
    showMetrics()
    phase = .idle
  }

  // MARK: - Wording

  private enum Action { case start, restore, save, record }

  static let healthAccessMessage =
    "Health access is off. On your iPhone, open Health, tap your picture, then Apps, then FORMA, and turn on Workouts."

  private static func isAccessDenied(_ error: Error) -> Bool {
    switch (error as? HKError)?.code {
    case .errorAuthorizationDenied, .errorRequiredAuthorizationDenied: true
    default: false
    }
  }

  /// Fixed sentences per cause. The system's own text stays in the log: it is
  /// not written for the person wearing the Watch.
  private static func message(for error: Error, doing action: Action) -> String {
    if isAccessDenied(error) { return healthAccessMessage }
    switch (error as? HKError)?.code {
    case .errorDatabaseInaccessible:
      return "Health is locked. Unlock your Watch, then try again."
    case .errorAnotherWorkoutSessionStarted:
      return "Another workout is running on this Watch. End it, then try again."
    default:
      break
    }
    return switch action {
    case .start: "The workout couldn't start. Try again."
    case .restore: "Your workout couldn't be restored. Try again."
    case .save:
      "Your workout couldn't be saved to Health. Your recording is kept. Try saving again."
    case .record: "Recording stopped unexpectedly. Try saving what was recorded."
    }
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
    let stopped = stoppedAt ?? date
    stoppedAt = stopped
    do {
      // A retry after a failed save must not end collection a second time.
      if !collectionEnded {
        try await builder.endCollection(at: stopped)
        collectionEnded = true
      }
      guard self.session === session else { return }
      if saveWhenStopped {
        // A nil workout without an error means it was saved while the
        // device was locked; never save a second copy.
        _ = try await builder.finishWorkout()
      } else {
        builder.discardWorkout()
      }
    } catch {
      Self.log.error("Save failed: \(error.localizedDescription, privacy: .private)")
      healthAccessDenied = Self.isAccessDenied(error)
      phase = .failed(Self.message(for: error, doing: .save))
      if session.state != .ended { session.end() }
      metrics?.state = .ended
      send(force: true)
      // Keep the failed builder reachable until the user retries or explicitly
      // discards. A failed save is never converted into a successful summary
      // or a new Start.
      return
    }
    session.end()
    metrics?.state = .ended
    metrics?.elapsed = builder.elapsedTime
    send(force: true)
    let summary = metrics ?? WatchMetrics(state: .ended, startedAt: stopped, elapsed: 0)
    self.session = nil
    self.builder = nil
    mirrored = false
    offerConsumedAt = .now
    healthAccessDenied = false
    phase = .summary(summary, saved: saveWhenStopped)
    routineName = nil
  }

  fileprivate func failed(_ error: Error, from session: HKWorkoutSession) {
    guard self.session === session else { return }
    Self.log.error("Session failed: \(error.localizedDescription, privacy: .private)")
    healthAccessDenied = Self.isAccessDenied(error)
    phase = .failed(Self.message(for: error, doing: .record))
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

  /// At most about once a second, and unchanged readings only every
  /// `heartbeat` seconds, which also tells the iPhone the link is alive, so the
  /// radio and battery stay quiet.
  private func send(force: Bool) {
    guard let session, mirrored, let metrics else { return }
    let key = SentKey(
      state: metrics.state, heartRate: metrics.heartRate.map { Int($0.rounded()) },
      activeEnergy: metrics.activeEnergy.map { Int($0.rounded()) })
    let now = Date.now
    if !force {
      let age = now.timeIntervalSince(lastSent)
      guard age >= 1, key != lastSentKey || age >= Self.heartbeat else { return }
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

  func sessionReachabilityDidChange(_ session: WCSession) {
    let reachable = session.isReachable
    Task { @MainActor in owner?.reachabilityChanged(isReachable: reachable) }
  }
}

struct UncheckedSendable<Value>: @unchecked Sendable {
  let value: Value
  init(_ value: Value) { self.value = value }
}
