import FORMACore
import FORMASurfaces
import Foundation
import XCTest

@testable import FORMA

/// ActivityKit stood in for, so every lifecycle rule is checked without a device. What the system
/// does with the activity afterwards (Lock Screen, Island, Watch) is a device gate.
@MainActor
private final class FakeActivityHost: WorkoutActivityHost {
  var isForeground = true
  var areActivitiesEnabled = true
  var requestError: Error?
  var activities: [RunningWorkoutActivity] = []
  private(set) var log: [String] = []
  private var counter = 0
  private var continuations: [String: AsyncStream<RunningWorkoutActivity.Phase>.Continuation] = [:]

  func running() -> [RunningWorkoutActivity] { activities }

  func request(
    sessionID: String, ownerEpoch: String, state: WorkoutActivityState, staleDate: Date
  ) throws -> RunningWorkoutActivity {
    if let requestError { throw requestError }
    counter += 1
    let activity = RunningWorkoutActivity(
      id: "activity-\(counter)", sessionID: sessionID, ownerEpoch: ownerEpoch, state: state,
      phase: .active)
    activities.append(activity)
    log.append("request \(sessionID)")
    return activity
  }

  func update(id: String, state: WorkoutActivityState, staleDate: Date) async {
    guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
    activities[index].state = state
    activities[index].phase = .active
    log.append("update \(id)")
  }

  func end(id: String) async {
    activities.removeAll { $0.id == id }
    log.append("end \(id)")
  }

  func phases(of id: String) -> AsyncStream<RunningWorkoutActivity.Phase> {
    AsyncStream { continuations[id] = $0 }
  }

  /// The person swipes the activity off the Lock Screen.
  func swipeAway(_ id: String) {
    guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
    activities[index].phase = .dismissed
    continuations[id]?.yield(.dismissed)
  }

  /// An activity left behind by an earlier launch.
  @discardableResult
  func leaveBehind(session: String, epoch: String, state: WorkoutActivityState) -> String {
    counter += 1
    let id = "left-\(counter)"
    activities.append(
      RunningWorkoutActivity(
        id: id, sessionID: session, ownerEpoch: epoch, state: state, phase: .active))
    return id
  }
}

@MainActor
final class WorkoutLiveActivityControllerTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)

  private func state(_ session: String = "s1", done: Int = 0) -> WorkoutActivityState {
    WorkoutActivityState(
      .init(
        sessionID: session, title: "Upper body", exercise: "Bench press", exerciseIndex: 0,
        exerciseCount: 2, exerciseDoneSets: done, exerciseSetCount: 3, doneSets: done,
        totalSets: 6, startedAt: now.addingTimeInterval(-300), restEnd: nil,
        restPausedSeconds: nil, restSeconds: 90),
      now: now)
  }

  private func target(
    _ session: String = "s1", epoch: String = "owner-a", done: Int = 0
  ) -> WorkoutLiveActivityController.Target {
    .init(sessionID: session, ownerEpoch: epoch, state: state(session, done: done))
  }

  private func make() -> (WorkoutLiveActivityController, FakeActivityHost) {
    let host = FakeActivityHost()
    return (WorkoutLiveActivityController(host: host, now: { self.now }), host)
  }

  func testStartsOneActivityForTheActiveWorkout() async {
    let (controller, host) = make()
    controller.sync(target())
    await controller.settle()
    XCTAssertEqual(host.log, ["request s1"])
    XCTAssertEqual(host.activities.first?.ownerEpoch, "owner-a")
  }

  func testDoesNotStartInTheBackgroundOrWhenActivitiesAreOff() async {
    let (controller, host) = make()
    host.isForeground = false
    controller.sync(target())
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
    // Coming to the front tries again.
    host.isForeground = true
    controller.sync(target(), force: true)
    await controller.settle()
    XCTAssertEqual(host.log, ["request s1"])

    let (other, offHost) = make()
    offHost.areActivitiesEnabled = false
    other.sync(target())
    await other.settle()
    XCTAssertTrue(offHost.activities.isEmpty)
  }

  func testARefusedStartLeavesTrainingAloneAndRetriesOnTheNextTrigger() async {
    let (controller, host) = make()
    host.requestError = CocoaError(.featureUnsupported)
    controller.sync(target())
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
    host.requestError = nil
    controller.sync(target(), force: true)
    await controller.settle()
    XCTAssertEqual(host.activities.count, 1)
  }

  func testUpdatesOnlyWhenTheMappedStateChanges() async {
    let (controller, host) = make()
    controller.sync(target())
    await controller.settle()
    controller.sync(target())
    controller.sync(target(done: 1))
    controller.sync(target(done: 1))
    await controller.settle()
    controller.sync(target(done: 1), force: true)
    await controller.settle()
    XCTAssertEqual(host.log.filter { $0.hasPrefix("update") }.count, 1)
    XCTAssertEqual(host.activities.first?.state.doneSets, 1)
  }

  func testRapidChangesSettleOnTheLatestWithoutIntermediateWork() async {
    let (controller, host) = make()
    controller.sync(target(done: 0))
    controller.sync(target(done: 1))
    controller.sync(target(done: 2))
    await controller.settle()
    XCTAssertEqual(host.log, ["request s1"])
    XCTAssertEqual(host.activities.first?.state.doneSets, 2)
  }

  func testEndsWhenTheWorkoutIsFinishedDiscardedOrReset() async {
    let (controller, host) = make()
    controller.sync(target())
    await controller.settle()
    controller.sync(nil)
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
    XCTAssertEqual(host.log, ["request s1", "end activity-1"])
  }

  func testANewSessionReplacesTheOldOneNeverRunningTwo() async {
    let (controller, host) = make()
    controller.sync(target("s1"))
    await controller.settle()
    controller.sync(target("s2"))
    await controller.settle()
    XCTAssertEqual(host.activities.map(\.sessionID), ["s2"])
    XCTAssertEqual(host.log, ["request s1", "end activity-1", "request s2"])
  }

  func testAChangedOwnerEndsTheOldActivityAtOnce() async {
    let (controller, host) = make()
    controller.sync(target(epoch: "owner-a"))
    await controller.settle()
    // Signing out leaves no workout at all.
    controller.sync(nil)
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
    // The same session id under another owner is not the same activity.
    controller.sync(target(epoch: "owner-b"))
    await controller.settle()
    controller.sync(target(epoch: "owner-c"))
    await controller.settle()
    XCTAssertEqual(host.activities.map(\.ownerEpoch), ["owner-c"])
  }

  func testRelaunchAdoptsTheMatchingActivityAndEndsEveryOther() async {
    let (controller, host) = make()
    let current = host.leaveBehind(session: "s1", epoch: "owner-a", state: state("s1"))
    host.leaveBehind(session: "old", epoch: "owner-a", state: state("old"))
    host.leaveBehind(session: "s1", epoch: "other-owner", state: state("s1"))
    controller.sync(target())
    await controller.settle()
    XCTAssertEqual(host.activities.map(\.id), [current])
    XCTAssertFalse(host.log.contains { $0.hasPrefix("request") }, "adopted, not restarted")
    XCTAssertFalse(host.log.contains { $0.hasPrefix("update") }, "same state, nothing to send")
  }

  func testRelaunchAdoptionRefreshesAStaleOrOutOfDateActivity() async {
    let (controller, host) = make()
    host.leaveBehind(session: "s1", epoch: "owner-a", state: state("s1", done: 0))
    controller.sync(target(done: 2))
    await controller.settle()
    XCTAssertEqual(host.activities.count, 1)
    XCTAssertEqual(host.activities.first?.state.doneSets, 2)
    XCTAssertEqual(host.log.filter { $0.hasPrefix("update") }.count, 1)
  }

  func testRelaunchWithNoActiveWorkoutEndsEveryLeftoverActivity() async {
    let (controller, host) = make()
    host.leaveBehind(session: "gone", epoch: "owner-a", state: state("gone"))
    host.leaveBehind(session: "gone-too", epoch: "owner-b", state: state("gone-too"))
    controller.sync(nil)
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
  }

  func testNothingIsDoneForRepeatedEmptyStateAfterTheFirstPass() async {
    let (controller, host) = make()
    controller.sync(nil)
    await controller.settle()
    host.leaveBehind(session: "late", epoch: "owner-a", state: state("late"))
    controller.sync(nil)
    await controller.settle()
    XCTAssertEqual(host.activities.count, 1, "an unchanged empty state is not re-reconciled")
    controller.sync(nil, force: true)
    await controller.settle()
    XCTAssertTrue(host.activities.isEmpty)
  }

  func testASwipedAwayActivityIsNotRestartedForTheSameWorkout() async {
    let (controller, host) = make()
    controller.sync(target())
    await controller.settle()
    host.swipeAway("activity-1")
    await Task.yield()
    await Task.yield()
    controller.sync(target(done: 1))
    await controller.settle()
    controller.sync(target(done: 1), force: true)
    await controller.settle()
    XCTAssertEqual(host.log.filter { $0.hasPrefix("request") }.count, 1)
    XCTAssertTrue(host.activities.isEmpty)
    // The next workout is a fresh start.
    controller.sync(target("s2"))
    await controller.settle()
    XCTAssertEqual(host.activities.map(\.sessionID), ["s2"])
  }

  func testStaleDateComesFromTheStateAndTheInjectedClock() async {
    let (controller, host) = make()
    var restState = state()
    restState.restEnd = now.addingTimeInterval(60)
    restState.restTotalSeconds = 90
    XCTAssertEqual(restState.staleDate(now: now), now.addingTimeInterval(61))
    controller.sync(.init(sessionID: "s1", ownerEpoch: "owner-a", state: restState))
    await controller.settle()
    XCTAssertEqual(host.activities.first?.state.restEnd, restState.restEnd)
  }
}

@MainActor
final class WorkoutLiveActivityMappingTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)
  private var nowMilliseconds: Double { now.timeIntervalSince1970 * 1_000 }

  private func session(
    restEnd: Double? = nil, restPaused: Double? = nil, firstDone: Int = 3
  ) -> WorkoutSession {
    func sets(_ count: Int, done: Int) -> [LoggedSet] {
      (0..<count).map { LoggedSet(weight: 60, reps: 8, done: $0 < done) }
    }
    return WorkoutSession(
      id: "s1", name: "Upper body", startedAt: nowMilliseconds - 600_000,
      notes: "PRIVATE NOTE NEVER SHOWN", restSeconds: 90, restEnd: restEnd,
      restPaused: restPaused,
      exercises: [
        SessionEntry(exerciseId: "squat", note: "PRIVATE EXERCISE NOTE", sets: sets(3, done: 3)),
        SessionEntry(exerciseId: "bench", sets: sets(4, done: firstDone)),
        SessionEntry(exerciseId: "row", sets: sets(3, done: 0)),
      ])
  }

  private let names = ["squat": "Back squat", "bench": "Bench press", "row": "Cable row"]

  private func state(_ session: WorkoutSession) -> WorkoutActivityState {
    WorkoutLiveActivityMapping.state(for: session, exerciseName: { names[$0] }, now: now)
  }

  func testCurrentExerciseIsTheOneTheWorkoutScreenOpensOn() {
    let value = state(session())
    XCTAssertEqual(WorkoutEngine.resumeIndex(session()), 1)
    XCTAssertEqual(value.exercise, "Bench press")
    XCTAssertEqual(value.exerciseIndex, 1)
    XCTAssertEqual(value.exerciseCount, 3)
    XCTAssertEqual(value.setLabel, "Set 4 of 4")
    XCTAssertEqual(value.doneSets, 6)
    XCTAssertEqual(value.totalSets, 10)
    XCTAssertEqual(value.title, "Upper body")
    XCTAssertEqual(value.startedAt, now.addingTimeInterval(-600))
  }

  func testRunningRestIsMappedAndAnExpiredOneIsNot() {
    let running = state(session(restEnd: nowMilliseconds + 30_000))
    XCTAssertTrue(running.isResting)
    XCTAssertEqual(running.restEnd, now.addingTimeInterval(30))
    let expired = state(session(restEnd: nowMilliseconds - 1))
    XCTAssertFalse(expired.isResting)
    XCTAssertNil(expired.restEnd)
  }

  func testPausedRestKeepsTheSecondsLeft() {
    let value = state(session(restPaused: 41.5))
    XCTAssertEqual(value.restPausedSeconds, 42)
    XCTAssertNil(value.restEnd)
  }

  func testUnknownExerciseAndEmptySessionsFallBackSafely() {
    XCTAssertEqual(
      WorkoutLiveActivityMapping.state(for: session(), exerciseName: { _ in nil }, now: now)
        .exercise, "Exercise")
    let empty = WorkoutSession(id: "e", name: "Empty", startedAt: nowMilliseconds)
    let value = state(empty)
    XCTAssertEqual(value.exerciseCount, 0)
    XCTAssertNil(value.setLabel)
    XCTAssertFalse(value.isFinishedAllSets)
  }

  func testEverySetTickedMarksTheWorkoutReadyToFinish() {
    var done = session()
    for entry in done.exercises.indices {
      for index in done.exercises[entry].sets.indices {
        done.exercises[entry].sets[index].done = true
      }
    }
    let value = state(done)
    XCTAssertTrue(value.isFinishedAllSets)
    XCTAssertEqual(value.exercise, "Cable row", "the last exercise stays on screen")
  }

  func testNotesAndIdentityNeverReachThePayload() throws {
    let data = try JSONEncoder().encode(state(session()))
    let text = String(decoding: data, as: UTF8.self)
    XCTAssertFalse(text.contains("PRIVATE"))
    XCTAssertFalse(text.contains("squat"))
    XCTAssertLessThan(data.count, 1_024)
  }
}

@MainActor
final class WorkoutLiveActivityModelTests: XCTestCase {
  private func workspace(active: WorkoutSession?) -> Workspace {
    Workspace(revision: 1, active: active)
  }

  private func session(_ id: String) -> WorkoutSession {
    WorkoutSession(
      id: id, name: "Legs", startedAt: Date.now.timeIntervalSince1970 * 1_000,
      exercises: [SessionEntry(exerciseId: "squat", sets: [LoggedSet(done: false)])])
  }

  /// The one hook: every workspace change, wherever it comes from, drives the activity.
  func testEveryWorkspaceChangeFollowsThroughTheSingleObserver() async {
    let host = FakeActivityHost()
    let model = AppModel(liveActivity: WorkoutLiveActivityController(host: host))
    model.workspace = workspace(active: nil)
    await model.liveActivity.settle()
    XCTAssertTrue(host.activities.isEmpty)

    model.workspace = workspace(active: session("a"))
    await model.liveActivity.settle()
    XCTAssertEqual(host.activities.map(\.sessionID), ["a"])
    XCTAssertEqual(host.activities.first?.ownerEpoch, model.widgets.epoch)

    // Finish, discard, reset and sign-out all end as an inactive or missing workout.
    model.workspace = workspace(active: nil)
    await model.liveActivity.settle()
    XCTAssertTrue(host.activities.isEmpty)

    model.workspace = workspace(active: session("b"))
    await model.liveActivity.settle()
    model.workspace = nil
    await model.liveActivity.settle()
    XCTAssertTrue(host.activities.isEmpty)
  }

  func testAttributesCarryNoAccountIdentity() async throws {
    let host = FakeActivityHost()
    let model = AppModel(liveActivity: WorkoutLiveActivityController(host: host))
    model.activeMember = "member-secret-id"
    model.workspace = workspace(active: session("a"))
    await model.liveActivity.settle()
    let activity = try XCTUnwrap(host.activities.first)
    XCTAssertEqual(activity.ownerEpoch, model.widgets.epoch)
    XCTAssertFalse(activity.ownerEpoch.contains("member-secret-id"))
    XCTAssertFalse(activity.sessionID.contains("member-secret-id"))
  }

  func testButtonPressForAnotherWorkoutDoesNothing() async {
    let model = AppModel(liveActivity: WorkoutLiveActivityController(host: FakeActivityHost()))
    model.workspace = workspace(active: session("a"))
    await model.perform(.completeSet(sessionID: "not-this-one"))
    await model.perform(.skipRest(sessionID: "not-this-one"))
    XCTAssertEqual(model.workspace?.active?.exercises.first?.sets.first?.done, false)
  }
}
