import ActivityKit
import FORMASurfaces
import Foundation
import UIKit

/// One workout Live Activity as the controller sees it, whether or not ActivityKit is behind it.
struct RunningWorkoutActivity: Equatable, Sendable {
  enum Phase: Sendable, Equatable { case active, stale, ended, dismissed }
  let id: String
  let sessionID: String
  let ownerEpoch: String
  var state: WorkoutActivityState
  var phase: Phase
}

/// ActivityKit as the controller uses it, so a test can stand in (the same shape as
/// `RestNotificationCenter`).
@MainActor
protocol WorkoutActivityHost {
  var isForeground: Bool { get }
  var areActivitiesEnabled: Bool { get }
  /// Every activity this app has, including ones left by an earlier launch.
  func running() -> [RunningWorkoutActivity]
  func request(sessionID: String, ownerEpoch: String, state: WorkoutActivityState, staleDate: Date)
    throws -> RunningWorkoutActivity
  func update(id: String, state: WorkoutActivityState, staleDate: Date) async
  /// Ends the activity and removes it from the Lock Screen at once.
  func end(id: String) async
  /// The phases the activity moves through, to notice the person swiping it away.
  func phases(of id: String) -> AsyncStream<RunningWorkoutActivity.Phase>
}

/// The real thing. Local only: `pushType` is nil, so there is no push token and no server.
@MainActor
struct SystemWorkoutActivityHost: WorkoutActivityHost {
  var isForeground: Bool { UIApplication.shared.applicationState == .active }
  var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

  func running() -> [RunningWorkoutActivity] {
    Activity<WorkoutActivityAttributes>.activities.map(Self.snapshot)
  }

  func request(
    sessionID: String, ownerEpoch: String, state: WorkoutActivityState, staleDate: Date
  ) throws -> RunningWorkoutActivity {
    let activity = try Activity.request(
      attributes: WorkoutActivityAttributes(sessionID: sessionID, ownerEpoch: ownerEpoch),
      content: ActivityContent(state: state, staleDate: staleDate), pushType: nil)
    return Self.snapshot(activity)
  }

  func update(id: String, state: WorkoutActivityState, staleDate: Date) async {
    await Self.send(id: id, state: state, staleDate: staleDate)
  }

  func end(id: String) async {
    await Self.finish(id: id)
  }

  // ActivityKit's own async calls are not main-actor isolated, so they run from a nonisolated
  // context that looks the activity up itself rather than being handed one.
  nonisolated private static func send(
    id: String, state: WorkoutActivityState, staleDate: Date
  ) async {
    let activity = Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    await activity?.update(ActivityContent(state: state, staleDate: staleDate))
  }

  nonisolated private static func finish(id: String) async {
    let activity = Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    await activity?.end(nil, dismissalPolicy: .immediate)
  }

  func phases(of id: String) -> AsyncStream<RunningWorkoutActivity.Phase> {
    guard let activity = find(id) else { return AsyncStream { $0.finish() } }
    return AsyncStream { continuation in
      let task = Task {
        for await state in activity.activityStateUpdates {
          continuation.yield(Self.phase(state))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func find(_ id: String) -> Activity<WorkoutActivityAttributes>? {
    Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
  }

  private static func snapshot(_ activity: Activity<WorkoutActivityAttributes>)
    -> RunningWorkoutActivity
  {
    RunningWorkoutActivity(
      id: activity.id, sessionID: activity.attributes.sessionID,
      ownerEpoch: activity.attributes.ownerEpoch, state: activity.content.state,
      phase: phase(activity.activityState))
  }

  private static func phase(_ state: ActivityState) -> RunningWorkoutActivity.Phase {
    switch state {
    case .active: .active
    case .stale: .stale
    case .ended: .ended
    case .dismissed: .dismissed
    // `.pending` (a scheduled start, iOS 26) is never requested here.
    default: .ended
    }
  }
}

/// Tests and previews never start a system activity.
@MainActor
struct InertWorkoutActivityHost: WorkoutActivityHost {
  var isForeground: Bool { false }
  var areActivitiesEnabled: Bool { false }
  func running() -> [RunningWorkoutActivity] { [] }
  func request(
    sessionID: String, ownerEpoch: String, state: WorkoutActivityState, staleDate: Date
  ) throws -> RunningWorkoutActivity {
    throw CocoaError(.featureUnsupported)
  }
  func update(id: String, state: WorkoutActivityState, staleDate: Date) async {}
  func end(id: String) async {}
  func phases(of id: String) -> AsyncStream<RunningWorkoutActivity.Phase> {
    AsyncStream { $0.finish() }
  }
}

/// Keeps at most one Live Activity, and only for the workout that is saved and active right now.
///
/// The model calls `sync` from the one place every workspace change passes through, so start,
/// update and end all follow the saved workout and cannot drift from it:
/// - A workout appears: start, but only while the app is in front and the person allows
///   activities (ActivityKit refuses a start from the background).
/// - Its mapped state changes: update. An unchanged state sends nothing, and a running rest is
///   never updated per second; the system counts the dates in it.
/// - The workout is finished, discarded or reset, the owner leaves, or the session changes: end at
///   once with no lingering dismissal. There is deliberately no "Workout saved" card; the receipt
///   belongs to the app, and an ended workout must not stay readable on a locked screen.
/// - Each pass compares against `running()`, so after a relaunch the matching activity is adopted
///   and every other one is ended. Two never coexist.
/// - A person who swipes the activity away is not asked again for that workout until the app
///   next launches.
@MainActor
final class WorkoutLiveActivityController {
  /// What the saved workout says should be on screen right now.
  struct Target: Equatable {
    var sessionID: String
    var ownerEpoch: String
    var state: WorkoutActivityState
  }

  private struct Key: Hashable {
    var sessionID: String
    var ownerEpoch: String
  }

  private let host: any WorkoutActivityHost
  private let now: () -> Date
  private var target: Target?
  /// The first pass after launch reconciles even with nothing to show, to end orphans.
  private var needsReconcile = true
  private var tail: Task<Void, Never>?
  private var watchers: [String: Task<Void, Never>] = [:]
  private var dismissed: Set<Key> = []

  init(host: any WorkoutActivityHost, now: @escaping () -> Date = { .now }) {
    self.host = host
    self.now = now
  }

  /// UI and unit test runs never touch the system's activities.
  static func makeDefault() -> WorkoutLiveActivityController {
    let testing =
      ProcessInfo.processInfo.arguments.contains("--ui-testing")
      || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    return WorkoutLiveActivityController(
      host: testing ? InertWorkoutActivityHost() : SystemWorkoutActivityHost())
  }

  /// Brings the activity in line with `next`. `force` repeats the pass when nothing changed, for
  /// the app coming to the front (a start that was refused in the background can now succeed).
  func sync(_ next: Target?, force: Bool = false) {
    guard force || needsReconcile || next != target else { return }
    needsReconcile = false
    target = next
    let previous = tail
    tail = Task { [weak self] in
      await previous?.value
      await self?.reconcile(next)
    }
  }

  /// Waits for queued work. Tests only.
  func settle() async {
    await tail?.value
  }

  private func reconcile(_ wanted: Target?) async {
    // A newer request is queued behind this one and will do the same work with fresher input.
    guard wanted == target else { return }
    let live = host.running()
    guard let wanted else {
      for activity in live { await finish(activity) }
      return
    }
    let key = Key(sessionID: wanted.sessionID, ownerEpoch: wanted.ownerEpoch)
    let match = live.first {
      $0.sessionID == key.sessionID && $0.ownerEpoch == key.ownerEpoch
        && ($0.phase == .active || $0.phase == .stale)
    }
    for activity in live where activity.id != match?.id {
      // Seen ended before its watcher reported it: still the person's or the system's doing.
      if activity.phase == .dismissed || activity.phase == .ended, watchers[activity.id] != nil {
        dismissed.insert(Key(sessionID: activity.sessionID, ownerEpoch: activity.ownerEpoch))
      }
      await finish(activity)
    }
    if let match {
      watch(match)
      // A stale activity is refreshed too: the person is using the app, so it is current again.
      if match.state != wanted.state || match.phase == .stale {
        await host.update(
          id: match.id, state: wanted.state, staleDate: wanted.state.staleDate(now: now()))
      }
      return
    }
    guard host.areActivitiesEnabled, host.isForeground, !dismissed.contains(key) else { return }
    // A refusal (activities off, too many running) leaves training untouched.
    if let started = try? host.request(
      sessionID: key.sessionID, ownerEpoch: key.ownerEpoch, state: wanted.state,
      staleDate: wanted.state.staleDate(now: now()))
    {
      watch(started)
    }
  }

  private func finish(_ activity: RunningWorkoutActivity) async {
    watchers.removeValue(forKey: activity.id)?.cancel()
    await host.end(id: activity.id)
  }

  /// Remembers an activity the person swiped away, or the system ended, so it is not restarted
  /// at the next tick.
  private func watch(_ activity: RunningWorkoutActivity) {
    guard watchers[activity.id] == nil else { return }
    let key = Key(sessionID: activity.sessionID, ownerEpoch: activity.ownerEpoch)
    let id = activity.id
    watchers[id] = Task { [weak self, host] in
      for await phase in host.phases(of: id) where phase == .dismissed || phase == .ended {
        self?.endedOutsideTheController(id: id, key: key)
        return
      }
    }
  }

  private func endedOutsideTheController(id: String, key: Key) {
    // `finish` removes the watcher first, so only an outside ending still has one.
    guard watchers.removeValue(forKey: id) != nil else { return }
    dismissed.insert(key)
  }
}
