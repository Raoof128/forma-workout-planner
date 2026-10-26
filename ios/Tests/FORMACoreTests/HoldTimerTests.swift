import Foundation
import XCTest

@testable import FORMACore

final class HoldTimerTests: XCTestCase {
  private let now = 1_792_700_000_000.0
  private let seconds = HoldUnit(key: "durationSeconds", seconds: 1, max: 86_400)
  private let plankReps = HoldUnit(key: "reps", seconds: 10, max: 1_000)

  private var catalog: [Exercise] {
    Fixtures.catalog + [
      Exercise(
        id: "side-plank", name: "Side plank", muscle: "Core", equipment: "Bodyweight",
        description: "Reviewed guide", metric: "duration", loadType: "none", usesHoldTimer: true,
        holdUnit: seconds),
      Exercise(
        id: "plank", name: "Forearm plank", muscle: "Core", equipment: "Bodyweight",
        description: "Reviewed guide", loadType: "none", usesHoldTimer: true, holdUnit: plankReps),
      Exercise(
        id: "timed-bike", name: "Bike sprint", muscle: "Cardio", equipment: "Machine",
        description: "Reviewed guide", metric: "duration", usesHoldTimer: false),
    ]
  }

  private func workspace(_ entry: SessionEntry) -> Workspace {
    var workspace = Fixtures.workspace()
    workspace.active = WorkoutSession(
      id: "session", name: "Core", startedAt: now, exercises: [entry])
    return workspace
  }

  private func holdEntry(sets: [LoggedSet], rest: Int? = nil) -> SessionEntry {
    SessionEntry(exerciseId: "side-plank", entryId: "hold-row", restSeconds: rest, sets: sets)
  }

  func testLengthsClampToWholeUnitsAndTheRecordableMaximum() {
    XCTAssertEqual(HoldTimer.clamp(2, unit: seconds), 5)
    XCTAssertEqual(HoldTimer.clamp(47, unit: seconds), 47)
    XCTAssertEqual(HoldTimer.clamp(9_999, unit: seconds), 3_600)
    XCTAssertEqual(HoldTimer.clamp(34, unit: plankReps), 30)
    XCTAssertEqual(HoldTimer.clamp(35, unit: plankReps), 40)
    XCTAssertEqual(HoldTimer.clamp(3, unit: plankReps), 10)
    XCTAssertEqual(HoldTimer.clamp(9_999, unit: plankReps), 1_000)
    XCTAssertEqual(HoldTimer.step(seconds), 5)
    XCTAssertEqual(HoldTimer.step(plankReps), 10)
  }

  func testDefaultLengthUsesTheNextUnfinishedSetOrOneMinute() {
    let entry = holdEntry(sets: [
      LoggedSet(weight: 0, reps: 1, durationSeconds: 30, done: true),
      LoggedSet(weight: 0, reps: 1, durationSeconds: 45.5),
    ])
    XCTAssertEqual(HoldTimer.defaultLength(for: entry, unit: seconds), 46)
    let unplanned = holdEntry(sets: [LoggedSet(weight: 0, reps: 1)])
    XCTAssertEqual(HoldTimer.defaultLength(for: unplanned, unit: seconds), 60)
    let plank = SessionEntry(exerciseId: "plank", sets: [LoggedSet(weight: 0, reps: 3)])
    XCTAssertEqual(HoldTimer.defaultLength(for: plank, unit: plankReps), 30)
  }

  func testAvailabilityFollowsTheCatalogueAndThePerSidePlankRule() {
    let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    XCTAssertTrue(HoldTimer.isAvailable(for: byID["side-plank"], entry: holdEntry(sets: [])))
    XCTAssertFalse(
      HoldTimer.isAvailable(
        for: byID["timed-bike"], entry: SessionEntry(exerciseId: "timed-bike", sets: [])))
    XCTAssertFalse(
      HoldTimer.isAvailable(for: byID["bench"], entry: SessionEntry(exerciseId: "bench", sets: [])))
    XCTAssertTrue(
      HoldTimer.isAvailable(for: byID["plank"], entry: SessionEntry(exerciseId: "plank", sets: [])))
    XCTAssertFalse(
      HoldTimer.isAvailable(
        for: byID["plank"], entry: SessionEntry(exerciseId: "plank", perSide: true, sets: [])))
  }

  func testFinishedHoldLogsSecondsCompletesTheSetAndStartsItsRest() throws {
    let start = workspace(
      holdEntry(
        sets: [
          LoggedSet(weight: 0, reps: 1, durationSeconds: 45),
          LoggedSet(weight: 0, reps: 1, durationSeconds: 45),
        ], rest: 30))
    let result = try WorkoutEngine.logHold(
      in: start, entryID: "hold-row", startedOn: 0, seconds: 42, now: now, catalog: catalog)
    let set = try XCTUnwrap(result.workspace.active?.exercises[0].sets[0])
    XCTAssertEqual(result.setIndex, 0)
    XCTAssertEqual(result.count, 42)
    XCTAssertEqual(set.durationSeconds, 42)
    XCTAssertTrue(set.done)
    XCTAssertFalse(result.workspace.active!.exercises[0].sets[1].done)
    XCTAssertEqual(result.workspace.active?.restEnd, now + 30_000)
  }

  func testHoldWhoseSetWasTickedMeanwhileLogsTheFirstUnfinishedSet() throws {
    let start = workspace(
      holdEntry(sets: [
        LoggedSet(weight: 0, reps: 1, durationSeconds: 45, done: true),
        LoggedSet(weight: 0, reps: 1, durationSeconds: 45),
      ]))
    let result = try WorkoutEngine.logHold(
      in: start, entryID: "hold-row", startedOn: 0, seconds: 50, now: now, catalog: catalog)
    XCTAssertEqual(result.setIndex, 1)
    XCTAssertEqual(result.workspace.active?.exercises[0].sets[0].durationSeconds, 45)
    XCTAssertEqual(result.workspace.active?.exercises[0].sets[1].durationSeconds, 50)
    XCTAssertTrue(result.workspace.active!.exercises[0].sets[1].done)
  }

  func testLegacyPlankLogsOnlyFullTenSecondReps() throws {
    let start = workspace(
      SessionEntry(exerciseId: "plank", entryId: "plank-row", sets: [LoggedSet(weight: 0, reps: 3)])
    )
    let result = try WorkoutEngine.logHold(
      in: start, entryID: "plank-row", startedOn: 0, seconds: 37, now: now, catalog: catalog)
    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result.workspace.active?.exercises[0].sets[0].reps, 3)
    XCTAssertNil(result.workspace.active?.exercises[0].sets[0].durationSeconds)
    XCTAssertEqual(HoldTimer.loggedText(count: 3, unit: plankReps), "3 reps (30 seconds)")
    XCTAssertEqual(HoldTimer.loggedText(count: 1, unit: plankReps), "1 rep (10 seconds)")
    XCTAssertThrowsError(
      try WorkoutEngine.logHold(
        in: start, entryID: "plank-row", startedOn: 0, seconds: 9, now: now, catalog: catalog))
  }

  func testHoldCannotLogOnceEverySetIsDoneOrForAnotherExercise() {
    let done = workspace(
      holdEntry(sets: [LoggedSet(weight: 0, reps: 1, durationSeconds: 45, done: true)]))
    XCTAssertThrowsError(
      try WorkoutEngine.logHold(
        in: done, entryID: "hold-row", startedOn: 0, seconds: 45, now: now, catalog: catalog))
    var bench = Fixtures.active(now: now)
    bench.active?.exercises[0].entryId = "bench-row"
    XCTAssertThrowsError(
      try WorkoutEngine.logHold(
        in: bench, entryID: "bench-row", startedOn: 0, seconds: 45, now: now, catalog: catalog))
  }

  func testGeneratedCatalogueCarriesTheWebHoldDecisions() throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let exercises = try JSONDecoder().decode(
      [Exercise].self,
      from: Data(contentsOf: project.appendingPathComponent("FORMA/Resources/catalog.json")))
    let timed = exercises.filter(\.usesHoldTimer)
    XCTAssertEqual(timed.count, 214)
    XCTAssertEqual(exercises.first { $0.id == "plank" }?.holdUnit, plankReps)
    XCTAssertEqual(exercises.first { $0.id == "db-plank" }?.holdUnit, seconds)
    XCTAssertTrue(
      timed.allSatisfy { $0.metric == "duration" || $0.id == "plank" },
      "Only timed movements and the legacy plank offer a hold timer")
  }
}
