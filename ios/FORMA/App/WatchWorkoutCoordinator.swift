import FORMACore
import Foundation
import HealthKit
import Observation
import WatchConnectivity
import os

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
    /// `notActivated`: this iPhone's own link to the Watch isn't up yet.
    /// `unreachable`: the Watch didn't answer, so it is away, locked or off.
    case appNotInstalled, notActivated, unreachable
    case ready

    var hasPairedWatch: Bool {
      [.appNotInstalled, .notActivated, .unreachable, .ready].contains(self)
    }

    /// What `WCSession` reports, as an availability. Not a reachability check:
    /// `isReachable` is true only while the Watch app is already running, which
    /// is the state this flow is trying to reach, so gating on it would stop
    /// every first start. A Watch that is away shows up when opening fails.
    static func resolve(
      activation: WCSessionActivationState, isPaired: Bool, isWatchAppInstalled: Bool
    ) -> Availability {
      guard activation == .activated else { return .notActivated }
      guard isPaired else { return .notPaired }
      guard isWatchAppInstalled else { return .appNotInstalled }
      return .ready
    }

    var message: String {
      switch self {
      case .checking: "Checking for your Apple Watch…"
      case .healthUnavailable: "Health data isn't available on this device."
      case .notSupported: "This device can't pair with an Apple Watch."
      case .notPaired: "No Apple Watch is paired with this iPhone."
      case .appNotInstalled:
        "Install FORMA on your Apple Watch from the Watch app on this iPhone, then try again."
      case .notActivated:
        "FORMA couldn't set up its connection to your Apple Watch. Check again in a moment."
      case .unreachable:
        "Your Apple Watch isn't in range or is locked. Unlock it and bring it closer, then check again."
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
  /// A sentence the iPhone's workout screen should show while it is set: the
  /// Watch disconnected, or it didn't get a Pause, Resume or End request. It
  /// clears itself when the problem does (the link returns, a command goes through).
  private(set) var notice: String?
  /// How this iPhone is hearing from the Watch during a recording.
  private(set) var link = WatchLink()
  /// Whether the latest reading is too old to show as live. Updated by a
  /// watchdog while a recording runs, so views need no timer of their own.
  private(set) var isReadingStale = false
  /// Called once when the Watch starts the workout this iPhone asked for.
  var onWatchStarted: ((_ routineID: String) -> Void)?

  private let healthStore = HKHealthStore()
  @ObservationIgnored private let bridge = WatchBridge()
  @ObservationIgnored private var mirrored: HKWorkoutSession?
  @ObservationIgnored private var activation: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var activationRequested = false
  @ObservationIgnored private var noticeSource: NoticeSource?
  @ObservationIgnored private var watchdog: Task<Void, Never>?

  private enum NoticeSource { case open, link, command }
  private static let log = Logger(
    subsystem: "dev.raoufabedini.forma", category: "watch")

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
    Availability.resolve(
      activation: session.activationState, isPaired: session.isPaired,
      isWatchAppInstalled: session.isWatchAppInstalled)
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
    clearNotice()
    guard availability == .ready else { return }
    do {
      try await healthStore.requestAuthorization(
        toShare: WatchWorkout.shareTypes, read: WatchWorkout.readTypes)
    } catch {
      Self.log.error("Health request failed: \(error.localizedDescription, privacy: .private)")
      phase = .idle
      post("FORMA couldn't ask for Health access. Try again.", from: .open)
      return
    }
    // Declining does not throw. Without workout write access the Watch could
    // only record a workout it can't save.
    guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied
    else {
      phase = .idle
      post(Self.healthAccessNotice, from: .open)
      return
    }
    try? WCSession.default.updateApplicationContext([
      WatchWorkout.routineNameKey: routine.name,
      WatchWorkout.requestedAtKey: Date.now.timeIntervalSince1970,
    ])
    do {
      try await healthStore.startWatchApp(toHandle: WatchWorkout.configuration())
      phase = .waiting(routineID: routine.id, routineName: routine.name)
    } catch {
      // The system's text is for developers; the person needs to know the
      // Watch is out of reach, and gets a Check again that works.
      Self.log.error("startWatchApp failed: \(error.localizedDescription, privacy: .private)")
      phase = .idle
      availability = .unreachable
    }
  }

  static let healthAccessNotice =
    "Health access is off for FORMA. In Settings, tap Health, then Data Access & Devices, then FORMA, and turn on Workouts."

  /// The person chose to train with this iPhone alone.
  func cancelWaiting() {
    guard case .waiting = phase else { return }
    phase = .idle
    clearRoutineOffer()
  }

  /// The Watch ignores an offer with no routine name, so a stale one can't
  /// reappear after the workout it was for has started or finished.
  private func clearRoutineOffer() {
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
      clearRoutineOffer()
      onWatchStarted?(routineID)
    } else {
      phase = ending ? .ending : .recording
    }
    applyLinkRestored()
    startWatchdog()
  }

  fileprivate func didReceive(_ data: [Data], from session: HKWorkoutSession) {
    guard mirrored === session else { return }
    // Delivery is batched after suspension; the newest snapshot wins. Decode
    // from the newest backwards and publish once, so a backlog doesn't
    // invalidate the live strip once per stale snapshot.
    for message in data.reversed().lazy.compactMap(WatchWorkoutMessage.decode) {
      if case .metrics(let snapshot) = message {
        apply(metrics: snapshot)
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
      if phase == .recording || phase == .ending {
        phase = .ended
        clearRoutineOffer()
      }
      stopWatchdog()
    }
  }

  fileprivate func didDisconnect(from session: HKWorkoutSession) {
    guard mirrored === session else { return }
    applyDisconnect()
  }

  // MARK: - Link state

  /// A snapshot from the Watch: the link is live and the reading is fresh.
  func apply(metrics snapshot: WatchMetrics, at date: Date = .now) {
    if metrics != snapshot { metrics = snapshot }
    let wasLost = link.state == .lost
    link.metricsReceived(at: date)
    if wasLost { clearNotice(from: .link) }
    refreshStaleness(now: date)
  }

  /// HealthKit reports the Watch's mirrored session is no longer connected.
  /// The Watch keeps recording, so the phase stays `.recording`.
  func applyDisconnect() {
    link.disconnected()
    refreshStaleness(now: .now)
    post(
      "Your Apple Watch disconnected and keeps recording. Bring it close to your iPhone, or choose Reconnect to iPhone on your Watch.",
      from: .link)
  }

  /// The Watch mirrored the session again, so commands can reach it.
  func applyLinkRestored(at date: Date = .now) {
    link.restored(at: date)
    refreshStaleness(now: date)
    clearNotice(from: .link)
  }

  /// Marks the reading stale once the Watch has been quiet for
  /// `WatchLink.staleAfter` seconds, or the link is lost.
  func refreshStaleness(now: Date) {
    let stale = link.isStale(at: now)
    if stale != isReadingStale { isReadingStale = stale }
  }

  /// Heart rate only while it is current. `nil` when the link is lost or the
  /// Watch has gone quiet, so a frozen number is never shown as live.
  var liveHeartRate: Double? { isReadingStale ? nil : metrics?.heartRate }
  /// The last heart rate received, for labelling it as old.
  var lastHeartRate: Double? { metrics?.heartRate }

  private func startWatchdog() {
    guard watchdog == nil else { return }
    watchdog = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        self?.refreshStaleness(now: .now)
      }
    }
  }

  private func stopWatchdog() {
    watchdog?.cancel()
    watchdog = nil
  }

  // MARK: - Notice

  private func post(_ message: String, from source: NoticeSource) {
    notice = message
    noticeSource = source
  }

  /// Clears the notice if `source` posted it; a later problem is left alone.
  private func clearNotice(from source: NoticeSource? = nil) {
    guard source == nil || noticeSource == source else { return }
    notice = nil
    noticeSource = nil
  }

  // MARK: - Commands

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
    link = WatchLink()
    isReadingStale = false
    stopWatchdog()
    clearNotice()
  }

  /// What the person is told when the Watch didn't get a command. Pure, so the
  /// wording can be tested.
  static func failureNotice(for command: Command, connected: Bool) -> String {
    let cause = connected ? "didn't respond to" : "isn't connected, so it didn't get"
    switch command {
    case .pause: return "Your Apple Watch \(cause) the pause request. Pause on your Watch instead."
    case .resume:
      return "Your Apple Watch \(cause) the resume request. Resume on your Watch instead."
    case .end:
      return
        "Your Apple Watch \(cause) the end request and may still be recording. End the workout on your Watch."
    }
  }

  enum Command: Equatable {
    case pause, resume, end

    init?(_ message: WatchWorkoutMessage) {
      switch message {
      case .pause: self = .pause
      case .resume: self = .resume
      case .end: self = .end
      case .metrics: return nil
      }
    }
  }

  @discardableResult
  private func send(_ message: WatchWorkoutMessage) async -> Bool {
    let command = Command(message)
    guard let mirrored else {
      if let command { post(Self.failureNotice(for: command, connected: false), from: .command) }
      return false
    }
    do {
      try await mirrored.sendToRemoteWorkoutSession(data: try message.encoded())
      clearNotice(from: .command)
      return true
    } catch {
      Self.log.error("Send failed: \(error.localizedDescription, privacy: .private)")
      if let command { post(Self.failureNotice(for: command, connected: true), from: .command) }
      return false
    }
  }
}

/// How the iPhone is hearing from the Watch while it records.
struct WatchLink: Equatable {
  enum State: Equatable { case live, lost }

  /// The Watch sends at least every 20 seconds while recording, so this is
  /// three missed messages.
  static let staleAfter: TimeInterval = 60

  private(set) var state = State.live
  private(set) var lastMetricsAt: Date?

  mutating func metricsReceived(at date: Date) {
    state = .live
    lastMetricsAt = date
  }

  mutating func disconnected() { state = .lost }

  /// Mirroring resumed. The Watch sends a snapshot straight away, so count the
  /// moment of contact as fresh rather than flashing "stale" until it lands.
  mutating func restored(at date: Date) {
    state = .live
    lastMetricsAt = date
  }

  func isStale(at date: Date) -> Bool {
    if state == .lost { return true }
    guard let lastMetricsAt else { return false }
    return date.timeIntervalSince(lastMetricsAt) > Self.staleAfter
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
