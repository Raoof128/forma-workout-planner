import Foundation
import XCTest

@testable import FORMASurfaces

final class WorkoutActivityStateTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)

  private func input(
    exercise: String? = "Bench press", exerciseIndex: Int = 1, exerciseCount: Int = 5,
    exerciseDone: Int = 2, exerciseSets: Int = 4, done: Int = 7, total: Int = 18,
    restEnd: Date? = nil, restPaused: Double? = nil, restSeconds: Int = 90
  ) -> WorkoutActivityState.Input {
    .init(
      sessionID: "session-1", title: "Upper body", exercise: exercise,
      exerciseIndex: exerciseIndex, exerciseCount: exerciseCount, exerciseDoneSets: exerciseDone,
      exerciseSetCount: exerciseSets, doneSets: done, totalSets: total,
      startedAt: now.addingTimeInterval(-600), restEnd: restEnd, restPausedSeconds: restPaused,
      restSeconds: restSeconds)
  }

  func testMapsTheCurrentExerciseAndTheSetBeingWorkedOn() {
    let state = WorkoutActivityState(input(), now: now)
    XCTAssertEqual(state.exercise, "Bench press")
    XCTAssertEqual(state.setLabel, "Set 3 of 4")
    XCTAssertEqual(state.exerciseLabel, "Exercise 2 of 5")
    XCTAssertEqual(state.doneSets, 7)
    XCTAssertEqual(state.totalSets, 18)
    XCTAssertFalse(state.isResting)
    XCTAssertFalse(state.isFinishedAllSets)
  }

  func testAnExerciseWithNoSetsAndASessionWithNoExercisesAreSafe() {
    let empty = WorkoutActivityState(
      input(
        exercise: nil, exerciseIndex: 0, exerciseCount: 0, exerciseDone: 0, exerciseSets: 0,
        done: 0, total: 0),
      now: now)
    XCTAssertEqual(empty.exercise, "Exercise")
    XCTAssertEqual(empty.setNumber, 0)
    XCTAssertNil(empty.setLabel)
    XCTAssertNil(empty.exerciseLabel)
    XCTAssertFalse(empty.isFinishedAllSets, "No sets is not a finished workout")
  }

  func testEveryExerciseSetTickedStaysOnTheLastSetAndAllDoneIsReported() {
    let allDone = WorkoutActivityState(
      input(exerciseDone: 4, exerciseSets: 4, done: 18, total: 18), now: now)
    XCTAssertEqual(allDone.setLabel, "Set 4 of 4")
    XCTAssertTrue(allDone.isFinishedAllSets)
  }

  func testRunningRestCarriesItsDeadlineAndProgrammedLength() throws {
    let end = now.addingTimeInterval(45)
    let state = WorkoutActivityState(input(restEnd: end, restSeconds: 90), now: now)
    XCTAssertTrue(state.isResting)
    XCTAssertEqual(state.restEnd, end)
    XCTAssertEqual(state.restStart, end.addingTimeInterval(-90))
    XCTAssertNil(state.restPausedSeconds)
  }

  func testRestStateDoesNotDependOnTheClockWhileTheRestRuns() {
    let end = now.addingTimeInterval(80)
    let earlier = WorkoutActivityState(input(restEnd: end), now: now)
    let later = WorkoutActivityState(input(restEnd: end), now: now.addingTimeInterval(30))
    XCTAssertEqual(earlier, later, "A repeat commit must not look like a change worth an update")
  }

  func testExpiredRestIsNotResting() {
    for end in [now, now.addingTimeInterval(-5)] {
      let state = WorkoutActivityState(input(restEnd: end), now: now)
      XCTAssertFalse(state.isResting)
      XCTAssertNil(state.restEnd)
      XCTAssertNil(state.restTotalSeconds)
    }
    // A deadline wins over a stale paused value, as in the engine.
    let both = WorkoutActivityState(
      input(restEnd: now.addingTimeInterval(-1), restPaused: 30), now: now)
    XCTAssertFalse(both.isResting)
  }

  func testPausedRestKeepsTheRemainingSecondsRoundedUp() {
    let state = WorkoutActivityState(input(restPaused: 44.2), now: now)
    XCTAssertTrue(state.isResting)
    XCTAssertEqual(state.restPausedSeconds, 45)
    XCTAssertNil(state.restEnd)
    XCTAssertEqual(WorkoutActivityState(input(restPaused: 0), now: now).isResting, false)
    XCTAssertEqual(WorkoutActivityState(input(restPaused: 9_999), now: now).restPausedSeconds, 600)
  }

  func testOutOfRangeCountsAreClamped() {
    let state = WorkoutActivityState(
      input(
        exerciseIndex: 9, exerciseCount: 3, exerciseDone: 9, exerciseSets: 4, done: 99, total: 5),
      now: now)
    XCTAssertEqual(state.exerciseIndex, 2)
    XCTAssertEqual(state.setNumber, 4)
    XCTAssertEqual(state.doneSets, 5)
  }

  func testNamesAreTrimmedAndClipped() {
    let long = String(repeating: "x", count: 500)
    var value = input(exercise: "  " + long + "  ")
    value.title = "   "
    let state = WorkoutActivityState(value, now: now)
    XCTAssertEqual(state.exercise.count, WorkoutActivityState.nameLimit)
    XCTAssertEqual(state.title, "Workout")
  }

  func testEncodedPayloadStaysFarBelowTheLimit() throws {
    // Worst case: longest names (multi-scalar characters), a running rest, big counts.
    var value = input(
      exercise: String(repeating: "🏋🏽‍♀️", count: 200), exerciseIndex: 40, exerciseCount: 41,
      exerciseDone: 11, exerciseSets: 12, done: 400, total: 480,
      restEnd: now.addingTimeInterval(600),
      restSeconds: 600)
    value.title = String(repeating: "é", count: 200)
    let state = WorkoutActivityState(value, now: now)
    let data = try JSONEncoder().encode(state)
    XCTAssertLessThan(data.count, 1_024, "ActivityKit allows 4 KB for static plus dynamic data")
    XCTAssertEqual(try JSONDecoder().decode(WorkoutActivityState.self, from: data), state)
  }

  func testPayloadHoldsNothingPrivateBeyondTheNames() throws {
    let data = try JSONEncoder().encode(WorkoutActivityState(input(), now: now))
    let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
    XCTAssertEqual(
      keys,
      [
        "sessionID", "title", "exercise", "exerciseIndex", "exerciseCount", "setNumber",
        "setCount", "doneSets", "totalSets", "startedAt", "isFinishedAllSets",
      ])
  }

  func testStaleDateEndsWithTheRestAndOtherwiseLapsesAfterIdleHours() {
    let end = now.addingTimeInterval(45)
    XCTAssertEqual(
      WorkoutActivityState(input(restEnd: end), now: now).staleDate(now: now),
      end.addingTimeInterval(1))
    let idle = WorkoutActivityState(input(), now: now)
    XCTAssertEqual(
      idle.staleDate(now: now), now.addingTimeInterval(WorkoutActivityState.idleStaleInterval))
    let paused = WorkoutActivityState(input(restPaused: 30), now: now)
    XCTAssertEqual(
      paused.staleDate(now: now), now.addingTimeInterval(WorkoutActivityState.idleStaleInterval))
  }

  func testClockFormatsPausedRests() {
    XCTAssertEqual(WorkoutActivityState.clock(5), "0:05")
    XCTAssertEqual(WorkoutActivityState.clock(90), "1:30")
    XCTAssertEqual(WorkoutActivityState.clock(600), "10:00")
    XCTAssertEqual(WorkoutActivityState.clock(-4), "0:00")
  }
}
