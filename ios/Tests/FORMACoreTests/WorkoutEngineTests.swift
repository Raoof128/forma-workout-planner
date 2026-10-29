import Foundation
import XCTest

@testable import FORMACore

final class WorkoutEngineTests: XCTestCase {
  private let now = 1_792_700_000_000.0

  func testStartSnapshotsRoutineAndFinishRequiresCompletedSet() throws {
    var routine = Fixtures.routine()
    let session = try WorkoutEngine.start(routine: routine, now: now)
    routine.name = "Edited later"
    routine.exercises[0].weight = 100
    XCTAssertEqual(session.name, "Upper body")
    XCTAssertEqual(session.exercises[0].sets[0].weight, 60)
    XCTAssertEqual(session.exercises[0].sets.count, 3)
    XCTAssertFalse(session.exercises[0].sets[0].done)
    var workspace = Fixtures.workspace()
    workspace.active = session
    XCTAssertThrowsError(try WorkoutEngine.finish(workspace, now: now + 60_000))
    XCTAssertEqual(workspace.history.count, 0)
  }

  func testCompletionValidationUndoAndRestUseCanonicalDeadline() throws {
    var workspace = Fixtures.active(now: now)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog)
    XCTAssertTrue(workspace.active!.exercises[0].sets[0].done)
    XCTAssertEqual(workspace.active!.restEnd, now + 90_000)
    XCTAssertEqual(WorkoutEngine.remainingRest(workspace.active!, now: now + 15_500), 75)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now + 2_000, catalog: Fixtures.catalog)
    XCTAssertFalse(workspace.active!.exercises[0].sets[0].done)
    workspace.active!.exercises[0].sets[0].weight = -.infinity
    XCTAssertThrowsError(
      try WorkoutEngine.toggleSet(
        in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog))
  }

  func testDurationDistanceAndCarryNeverContributeToLiftingVolume() throws {
    var workspace = Fixtures.workspace()
    workspace.active = WorkoutSession(
      id: "session", name: "Mixed", startedAt: now,
      exercises: [
        SessionEntry(exerciseId: "bench", sets: [LoggedSet(weight: 60, reps: 8, done: true)]),
        SessionEntry(
          exerciseId: "rower",
          sets: [
            LoggedSet(weight: 0, reps: 1, durationSeconds: 90, distanceMeters: 500, done: true)
          ]),
        SessionEntry(
          exerciseId: "carry",
          sets: [LoggedSet(weight: 40, reps: 1, distanceMeters: 30, done: true)]),
      ])
    try workspace.validate(catalog: Fixtures.catalog)
    XCTAssertEqual(WorkoutEngine.volume(workspace.active!, catalog: Fixtures.catalog), 480)
    workspace.active!.exercises[1].sets[0].durationSeconds = 0
    XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog))
  }

  func testFinishIsAtomicValueTransformationAndCannotRepeat() throws {
    var workspace = Fixtures.active(now: now)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog)
    let finished = try WorkoutEngine.finish(
      workspace, now: now + 125_500, catalog: Fixtures.catalog)
    XCTAssertNil(finished.active)
    XCTAssertEqual(finished.history.count, 1)
    XCTAssertEqual(finished.history[0].duration, 125)
    XCTAssertNotNil(finished.history[0].date)
    XCTAssertNotNil(workspace.active)
    XCTAssertThrowsError(
      try WorkoutEngine.finish(finished, now: now + 126_000, catalog: Fixtures.catalog))
  }

  func testPauseResumeAdjustAndSkipRestSurviveClockIndependentReopening() throws {
    var workspace = Fixtures.active(now: now)
    workspace.active!.restEnd = now + 90_000
    workspace = try WorkoutEngine.pauseRest(in: workspace, now: now + 30_000)
    XCTAssertNil(workspace.active!.restEnd)
    XCTAssertEqual(workspace.active!.restPaused, 60)
    workspace = try WorkoutEngine.resumeRest(in: workspace, now: now + 300_000)
    XCTAssertEqual(workspace.active!.restEnd, now + 360_000)
    workspace = try WorkoutEngine.adjustRest(in: workspace, by: 900, now: now + 300_000)
    XCTAssertEqual(WorkoutEngine.remainingRest(workspace.active!, now: now + 300_000), 600)
    workspace = try WorkoutEngine.skipRest(in: workspace)
    XCTAssertEqual(WorkoutEngine.remainingRest(workspace.active!, now: now + 400_000), 0)
  }

  func testSupersetRestsOnlyAfterLastExerciseAndSnapshotsPerSideTargets() throws {
    var routine = Fixtures.routine()
    routine.exercises[0].groupId = "superset-a"
    routine.exercises.append(
      Prescription(
        exerciseId: "single-row", sets: 2, reps: 8, weight: 20, perSide: true, groupId: "superset-a"
      ))
    var workspace = Fixtures.workspace()
    workspace.routines = [routine]
    workspace.active = try WorkoutEngine.start(routine: routine, now: now)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog)
    XCTAssertNil(workspace.active!.restEnd)
    XCTAssertEqual(workspace.active!.exercises[1].sets[0].sides, SetSides(left: 8, right: 8))
    XCTAssertEqual(workspace.active!.exercises[1].sets[0].reps, 16)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 1, setIndex: 0, now: now, catalog: Fixtures.catalog)
    XCTAssertEqual(workspace.active!.restEnd, now + 90_000)
    XCTAssertEqual(WorkoutEngine.volume(workspace.active!, catalog: Fixtures.catalog), 800)
  }

  func testStrengthEstimateExcludesHighRepsAndUsesActualWeightForSingleRep() {
    XCTAssertEqual(WorkoutEngine.estimatedOneRM(weight: 60, reps: 1), 60)
    XCTAssertEqual(WorkoutEngine.estimatedOneRM(weight: 60, reps: 8)!, 76, accuracy: 0.0001)
    XCTAssertNil(WorkoutEngine.estimatedOneRM(weight: 60, reps: 13))
    XCTAssertNil(WorkoutEngine.estimatedOneRM(weight: .nan, reps: 8))
  }

  func testPerSideRepRangeAboveFiftyCannotStartAWorkout() throws {
    func routine(reps: Int, repsMax: Int?) -> Routine {
      Routine(
        name: "Single-arm rows",
        exercises: [
          Prescription(
            exerciseId: "single-row", sets: 1, reps: reps, repsMax: repsMax, perSide: true)
        ])
    }
    XCTAssertNoThrow(
      try WorkoutEngine.start(
        routine: routine(reps: 40, repsMax: 50), now: now, catalog: Fixtures.catalog))
    XCTAssertThrowsError(
      try WorkoutEngine.start(
        routine: routine(reps: 40, repsMax: 60), now: now, catalog: Fixtures.catalog))
    XCTAssertThrowsError(
      try WorkoutEngine.start(
        routine: routine(reps: 51, repsMax: nil), now: now, catalog: Fixtures.catalog))
  }

  func testTimedPrescriptionDoesNotInventPerSideRepetitions() throws {
    // Some catalog names carry the same perSide default as a rep exercise,
    // but duration and distance still use their own measurement profile.
    let routine = Routine(
      name: "Timed balance",
      exercises: [
        Prescription(exerciseId: "balance", sets: 1, reps: 1, durationSeconds: 30, perSide: true)
      ])
    let active = try WorkoutEngine.start(routine: routine, now: now)
    XCTAssertNil(active.exercises[0].sets[0].sides)
    XCTAssertEqual(active.exercises[0].sets[0].reps, 1)
  }

  func testUnknownCatalogIDsUnsupportedVersionAndDuplicateIdentityAreRejected() throws {
    var workspace = Fixtures.workspace()
    workspace.version = 1
    XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog))
    workspace.version = 2
    workspace.routines[0].exercises[0].exerciseId = "unknown"
    XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog))
    workspace = Fixtures.workspace()
    workspace.routines[0].exercises.append(workspace.routines[0].exercises[0])
    XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog))
  }

  func testEncodingHasVersionTwoCanonicalMillisecondsAndNoComputedIdentityKeys() throws {
    let workspace = Fixtures.active(now: now)
    let data = try JSONEncoder().encode(workspace)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(object["version"] as? Int, 2)
    let active = try XCTUnwrap(object["active"] as? [String: Any])
    XCTAssertEqual(active["startedAt"] as? Double, now)
    let entries = try XCTUnwrap(active["exercises"] as? [[String: Any]])
    XCTAssertNil(entries[0]["id"])
    XCTAssertEqual(try JSONDecoder().decode(Workspace.self, from: data), workspace)
  }

  func testEmptyWorkspaceEncodesExplicitNullActiveForTheWebEnvelope() throws {
    let raw = try JSONEncoder().encode(Fixtures.workspace())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
    XCTAssertNotNil(object["active"])
    XCTAssertTrue(object["active"] is NSNull)
  }

  func testReopenedSetKeepsTheRunningRestAndStartsOneWhenNoneIsRunning() throws {
    var workspace = Fixtures.active(now: now)
    func toggle(_ index: Int, at time: Double, rest: WorkoutEngine.RestTrigger = .always) throws {
      workspace = try WorkoutEngine.toggleSet(
        in: workspace, entryIndex: 0, setIndex: index, now: time, catalog: Fixtures.catalog,
        rest: rest)
    }
    try toggle(0, at: now)
    XCTAssertEqual(workspace.active!.restEnd, now + 90_000)

    // Reopen and re-tick 40 s in: the countdown keeps its original deadline.
    try toggle(0, at: now + 40_000)
    try toggle(0, at: now + 45_000, rest: .onlyIfIdle)
    XCTAssertTrue(workspace.active!.exercises[0].sets[0].done)
    XCTAssertEqual(workspace.active!.restEnd, now + 90_000)

    // A paused rest is still a rest.
    workspace = try WorkoutEngine.pauseRest(in: workspace, now: now + 50_000)
    try toggle(0, at: now + 51_000)
    try toggle(0, at: now + 52_000, rest: .onlyIfIdle)
    XCTAssertNil(workspace.active!.restEnd)
    XCTAssertEqual(workspace.active!.restPaused, 40)

    // Once the rest has run out or been skipped, a correction starts the next one.
    workspace = try WorkoutEngine.skipRest(in: workspace)
    try toggle(0, at: now + 60_000)
    try toggle(0, at: now + 61_000, rest: .onlyIfIdle)
    XCTAssertEqual(workspace.active!.restEnd, now + 61_000 + 90_000)

    // A first completion restarts the countdown even while one is running.
    try toggle(1, at: now + 100_000)
    XCTAssertEqual(workspace.active!.restEnd, now + 190_000)
  }

  func testRestIsNotRunningOnceItsDeadlinePassed() throws {
    var workspace = Fixtures.active(now: now)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog)
    let session = workspace.active!
    XCTAssertTrue(WorkoutEngine.isResting(session, now: now + 89_000))
    XCTAssertFalse(WorkoutEngine.isResting(session, now: now + 90_000))
    var idle = session
    idle.restEnd = nil
    XCTAssertFalse(WorkoutEngine.isResting(idle, now: now))
  }

  func testResumeIndexProgressAndUnfinishedCounts() throws {
    var routine = Fixtures.routine()
    routine.exercises.append(
      Prescription(exerciseId: "single-row", sets: 2, reps: 8, weight: 20, perSide: true))
    var workspace = Fixtures.workspace()
    workspace.routines = [routine]
    workspace.active = try WorkoutEngine.start(routine: routine, now: now)
    XCTAssertEqual(WorkoutEngine.resumeIndex(workspace.active!), 0)
    XCTAssertEqual(WorkoutEngine.totalSets(workspace.active!), 5)
    XCTAssertEqual(WorkoutEngine.unfinishedSets(workspace.active!), 5)

    for set in 0..<3 {
      workspace = try WorkoutEngine.toggleSet(
        in: workspace, entryIndex: 0, setIndex: set, now: now, catalog: Fixtures.catalog)
    }
    let session = workspace.active!
    XCTAssertEqual(WorkoutEngine.resumeIndex(session), 1)
    XCTAssertEqual(WorkoutEngine.setProgress(session.exercises[0]).done, 3)
    XCTAssertEqual(WorkoutEngine.setProgress(session.exercises[0]).total, 3)
    XCTAssertEqual(WorkoutEngine.setProgress(session.exercises[1]).done, 0)
    XCTAssertEqual(WorkoutEngine.unfinishedSets(session), 2)

    // An earlier set left unticked wins over a later exercise's progress.
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 1, now: now, catalog: Fixtures.catalog)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 1, setIndex: 0, now: now, catalog: Fixtures.catalog)
    XCTAssertEqual(WorkoutEngine.resumeIndex(workspace.active!), 0)

    // Everything done lands on the last exercise, beside the Finish action.
    for (entry, set) in [(0, 1), (1, 1)] {
      workspace = try WorkoutEngine.toggleSet(
        in: workspace, entryIndex: entry, setIndex: set, now: now, catalog: Fixtures.catalog)
    }
    XCTAssertEqual(WorkoutEngine.unfinishedSets(workspace.active!), 0)
    XCTAssertEqual(WorkoutEngine.resumeIndex(workspace.active!), 1)
  }
}

enum Fixtures {
  static let catalog: [Exercise] = [
    Exercise(
      id: "bench", name: "Barbell bench press", muscle: "Chest", equipment: "Barbell",
      description: "Reviewed guide", weight: 40),
    Exercise(
      id: "rower", name: "Rowing", muscle: "Cardio", equipment: "Machine",
      description: "Reviewed guide", metric: "duration_distance"),
    Exercise(
      id: "carry", name: "Farmer carry", muscle: "Full body", equipment: "Dumbbell",
      description: "Reviewed guide", metric: "load_distance"),
    Exercise(
      id: "single-row", name: "One-arm row", muscle: "Back", equipment: "Dumbbell",
      description: "Reviewed guide", perSide: true),
  ]

  static func routine() -> Routine {
    Routine(
      id: "upper", name: "Upper body", description: "A starter", minutes: 40, level: "All levels",
      image: 0,
      exercises: [
        Prescription(exerciseId: "bench", sets: 3, reps: 8, weight: 60)
      ])
  }

  static func workspace() -> Workspace { Workspace(routines: [routine()]) }

  static func active(now: Double) -> Workspace {
    var workspace = workspace()
    workspace.active = try! WorkoutEngine.start(routine: workspace.routines[0], now: now)
    return workspace
  }
}
