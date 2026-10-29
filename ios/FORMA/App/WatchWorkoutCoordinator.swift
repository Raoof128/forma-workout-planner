import FORMACore
import Foundation
import HealthKit
import Observation
import WatchConnectivity

/// Finds the paired Apple Watch, opens FORMA on it for a chosen routine and
/// follows the workout the Watch records. The Watch owns recording: pressing
/// Start there begins the HealthKit session, which it mirrors to this iPhone.
@MainActor @Observable
final class WatchWorkoutCoordinator {
  enum Availability: Equatable {
    case checking
    /// No Watch can take part: train on the iPhone without asking.
    case healthUnavailable, notSupported, notPaired
    /// A Watch is paired but can't start yet; the person can fix this.
    case appNotInstalled, unreachable
    case ready

    var hasPairedWatch: Bool { [.appNotInstalled, .unreachable, .ready].contains(self) }

    var message: String {
      switch self {
      case .checking: "Checking for your Apple Watch…"
      case .healthUnavailable: "Health data isn't available on this device."
      case .notSupported: "This device can't pair with an Apple Watch."
      case .notPaired: "No Apple Watch is paired with this iPhone."
      case .appNotInstalled:
        "Install FORMA on your Apple Watch from the Watch app on this iPhone, then try again."
      case .unreachable:
        "Your Apple Watch couldn't be reached. Check that it's nearby and unlocked."
      case .ready: "Your Apple Watch is ready."
      }
    }
  }

  enum Phase: Equatable {
    case idle
    /// FORMA is open on the Watch, waiting for its Start button.
    case waiting(routineID: String, routineName: String)
    case recording
    /// An end command was sent, but the Watch has not reported session end.
    case ending
    /// Session end does not prove that the Watch's Health save succeeded.
    case ended
  }

  private(set) var availability: Availability = .checking
  private(set) var phase: Phase = .idle
  private(set) var metrics: WatchMetrics?
  private(set) var notice: String?
  /// Called once when the Watch starts the workout this iPhone asked for.
  var onWatchStarted: ((_ routineID: String) -> Void)?

  private let healthStore = HKHealthStore()
  @ObservationIgnored private let bridge = WatchBridge()
  @ObservationIgnored private var mirrored: HKWorkoutSession?
  @ObservationIgnored private var activation: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var activationRequested = false

  init() {
    bridge.owner = self
    // Registered at launch: iOS may start this app in the background to
    // deliver a session the Watch started. It can run again after reconnecting.
    let bridge = bridge
    healthStore.workoutSessionMirroringStartHandler = { session in
      bridge.mirroringStarted(UncheckedSendable(session))
    }
    // Activate at launch, as Apple's WCSession documentation asks: iOS can
    // wake this app in the background for a Watch message, and the session
    // must be active by then. `activate()` returns at once and finishes on a
    // background queue, so it does not hold up the first frame.
    activateSession()
  }

  /// Activates WatchConnectivity so Watch install and pairing changes are
  /// delivered. Idempotent, so `refresh` can call it safely.
  private func activateSession() {
    guard !activationRequested, WCSession.isSupported() else { return }
    activationRequested = true
    WCSession.default.delegate = bridge
    WCSession.default.activate()
  }

  // MARK: - Checking for the Watch

  func refresh() async {
    availability = .checking
    guard HKHealthStore.isHealthDataAvailable() else {
      availability = .healthUnavailable
      return
    }
    guard WCSession.isSupported() else {
      availability = .notSupported
      return
    }
    activateSession()
    let session = WCSession.default
    if session.activationState == .notActivated {
      // WatchConnectivity sets the state before its callback hops here, so
      // checking again on the main actor can't miss a completed activation.
      await withCheckedContinuation { continuation in
        if session.activationState == .notActivated {
          activation.append(continuation)
        } else {
          continuation.resume()
        }
      }
    }
    availability = Self.availability(of: session)
  }

  private static func availability(of session: WCSession) -> Availability {
    guard session.activationState == .activated else { return .unreachable }
    guard session.isPaired else { return .notPaired }
    guard session.isWatchAppInstalled else { return .appNotInstalled }
    return .ready
  }

  fileprivate func activationFinished() {
    let waiting = activation
    activation = []
    for continuation in waiting { continuation.resume() }
  }

  fileprivate func watchStateChanged() {
    guard availability != .checking else { return }
    availability = Self.availability(of: .default)
  }

  // MARK: - Starting from the iPhone

  /// Opens FORMA on the Watch with this routine. The workout itself starts
  /// only when the Start button is pressed on the Watch.
  func open(routine: Routine) async {
    notice = nil
    guard availability == .ready else { return }
    do {
      try await healthStore.requestAuthorization(
        toShare: WatchWorkout.shareTypes, read: WatchWorkout.readTypes)
      try? WCSession.default.updateApplicationContext([
        WatchWorkout.routineNameKey: routine.name,
        WatchWorkout.requestedAtKey: Date.now.timeIntervalSince1970,
      ])
      try await healthStore.startWatchApp(toHandle: WatchWorkout.configuration())
      phase = .waiting(routineID: routine.id, routineName: routine.name)
    } catch {
      phase = .idle
      notice = "FORMA couldn't open on your Apple Watch. \(error.localizedDescription)"
    }
  }

  /// The person chose to train with this iPhone alone.
  func cancelWaiting() {
    guard case .waiting = phase else { return }
    phase = .idle
    try? WCSession.default.updateApplicationContext([
      WatchWorkout.routineNameKey: "", WatchWorkout.requestedAtKey: Date.now.timeIntervalSince1970,
    ])
  }

  // MARK: - The mirrored session

  fileprivate func didStartMirroring(_ session: HKWorkoutSession) {
    // A reconnect delivers a new instance of the same workout: keep one
    // logical recording and never start a second FORMA workout for it.
    let first = mirrored == nil && phase != .recording
    let ending = phase == .ending
    mirrored = session
    session.delegate = bridge
    if case .waiting(let routineID, _) = phase, first {
      phase = .recording
      onWatchStarted?(routineID)
    } else {
      phase = ending ? .ending : .recording
    }
  }

  fileprivate func didReceive(_ data: [Data], from session: HKWorkoutSession) {
    guard mirrored === session else { return }
    // Delivery is batched after suspension; the newest snapshot wins. Decode
    // from the newest backwards and publish once, so a backlog doesn't
    // invalidate the live strip once per stale snapshot.
    for message in data.reversed().lazy.compactMap(WatchWorkoutMessage.decode) {
      if case .metrics(let snapshot) = message {
        if metrics != snapshot { metrics = snapshot }
        break
      }
    }
  }

  fileprivate func didChange(to state: HKWorkoutSessionState, from session: HKWorkoutSession) {
    guard mirrored === session else { return }
    if state == .stopped, phase == .recording {
      phase = .ending
    } else if state == .ended {
      mirrored = nil
      if phase == .recording || phase == .ending { phase = .ended }
    }
  }

  fileprivate func didDisconnect(from session: HKWorkoutSession) {
    guard mirrored === session else { return }
    notice =
      "Your Apple Watch disconnected and keeps recording. Choose Reconnect to iPhone on your Watch when it's nearby."
  }

  func pause() async { _ = await send(.pause) }
  func resume() async { _ = await send(.resume) }

  /// Ask the Watch to end its recording. Command delivery is not a Health save
  /// acknowledgement, and a failed send leaves the recording recoverable.
  func end(save: Bool) async {
    guard phase == .recording else { return }
    phase = .ending
    if !(await send(.end(save: save))), phase == .ending {
      phase = .recording
    }
  }

  func reset() {
    if case .ended = phase { phase = .idle }
    metrics = nil
    notice = nil
  }

  @discardableResult
  private func send(_ message: WatchWorkoutMessage) async -> Bool {
    guard let mirrored else {
      notice = "Your Apple Watch isn't connected. Use the Watch to control its recording."
      return false
    }
    do {
      try await mirrored.sendToRemoteWorkoutSession(data: try message.encoded())
      return true
    } catch {
      notice =
        "Your Apple Watch didn't receive that. End the workout on the Watch if it's still recording."
      return false
    }
  }
}

/// HealthKit and WatchConnectivity call back on their own queues. This hops
/// each callback to the main actor with only Sendable values.
private final class WatchBridge: NSObject, WCSessionDelegate, HKWorkoutSessionDelegate,
  @unchecked Sendable
{
  @MainActor weak var owner: WatchWorkoutCoordinator?

  func mirroringStarted(_ session: UncheckedSendable<HKWorkoutSession>) {
    Task { @MainActor in owner?.didStartMirroring(session.value) }
  }

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in owner?.activationFinished() }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // The person switched Watches: activate again for the new one.
    WCSession.default.activate()
  }

  func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in owner?.watchStateChanged() }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.didChange(to: toState, from: session.value) }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.didReceive(data, from: session.value) }
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: Error?
  ) {
    let session = UncheckedSendable(workoutSession)
    Task { @MainActor in owner?.didDisconnect(from: session.value) }
  }
}

/// HealthKit hands over a session it owns; only the main actor uses it after this.
struct UncheckedSendable<Value>: @unchecked Sendable {
  let value: Value
  init(_ value: Value) { self.value = value }
}
