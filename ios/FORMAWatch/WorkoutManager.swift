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
  private(set) var metrics: WatchMetrics?
  /// Whether the iPhone is following this workout.
  private(set) var mirrored = false

  private let healthStore = HKHealthStore()
  @ObservationIgnored private let bridge = WorkoutBridge()
  @ObservationIgnored private var session: HKWorkoutSession?
  @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
  @ObservationIgnored private var configuration = WatchWorkout.configuration()
  @ObservationIgnored private var saveWhenStopped = true
  @ObservationIgnored private var lastSent = Date.distantPast

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
    do {
      try await session.startMirroringToCompanionDevice()
      mirrored = true
    } catch {
      mirrored = false
    }
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
  }

  // MARK: - HealthKit callbacks

  fileprivate func stateChanged(to state: HKWorkoutSessionState, date: Date) {
    switch state {
    case .running:
      if phase == .paused { phase = .running }
      metrics?.state = .running
    case .paused:
      if phase == .running { phase = .paused }
      metrics?.state = .paused
    case .stopped:
      Task { await finish(at: date) }
    default:
      break
    }
    send(force: true)
  }

  private func finish(at date: Date) async {
    guard let session, let builder else { return }
    do {
      try await builder.endCollection(at: date)
      if saveWhenStopped {
        // A nil workout without an error means it was saved while the
        // device was locked; never save a second copy.
        _ = try await builder.finishWorkout()
      } else {
        builder.discardWorkout()
      }
    } catch {
      phase = .failed("Your workout couldn't be saved to Health. \(error.localizedDescription)")
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

  fileprivate func failed(_ error: Error) {
    phase = .failed("The workout stopped unexpectedly. \(error.localizedDescription)")
  }

  fileprivate func collected() {
    guard let builder, metrics != nil else { return }
    let bpm = HKUnit.count().unitDivided(by: .minute())
    let heart = builder.statistics(for: HKQuantityType(.heartRate))
    metrics?.heartRate = heart?.mostRecentQuantity()?.doubleValue(for: bpm)
    metrics?.averageHeartRate = heart?.averageQuantity()?.doubleValue(for: bpm)
    metrics?.activeEnergy = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
      .sumQuantity()?.doubleValue(for: .kilocalorie())
    metrics?.elapsed = builder.elapsedTime
    send(force: false)
  }

  fileprivate func received(_ data: [Data]) {
    for message in data.compactMap(WatchWorkoutMessage.decode) {
      switch message {
      case .pause: pause()
      case .resume: resume()
      case .end(let save): end(save: save)
      case .metrics: break
      }
    }
  }

  fileprivate func disconnected() { mirrored = false }

  /// At most about once a second, so the link and battery stay quiet.
  private func send(force: Bool) {
    guard let session, mirrored, let metrics else { return }
    guard force || Date.now.timeIntervalSince(lastSent) >= 1 else { return }
    lastSent = .now
    guard let data = try? WatchWorkoutMessage.metrics(metrics).encoded() else { return }
    let target = UncheckedSendable(session)
    Task { try? await target.value.sendToRemoteWorkoutSession(data: data) }
  }
}

private final class WorkoutBridge: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate,
  WCSessionDelegate, @unchecked Sendable
{
  @MainActor weak var owner: WorkoutManager?

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    Task { @MainActor in owner?.stateChanged(to: toState, date: date) }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    let error = UncheckedSendable(error)
    Task { @MainActor in owner?.failed(error.value) }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
  ) {
    Task { @MainActor in owner?.received(data) }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?
  ) {
    Task { @MainActor in owner?.disconnected() }
  }

  func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    Task { @MainActor in owner?.collected() }
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
