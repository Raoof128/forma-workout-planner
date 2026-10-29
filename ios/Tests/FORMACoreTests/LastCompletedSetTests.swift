import XCTest

@testable import FORMACore

final class LastCompletedSetTests: XCTestCase {
  private func session(_ id: String, entries: [SessionEntry]) -> WorkoutSession {
    WorkoutSession(id: id, name: id, startedAt: 1_792_700_000_000, exercises: entries)
  }

  private func entry(_ id: String, weight: Double, done: Bool) -> SessionEntry {
    SessionEntry(
      exerciseId: "bench", entryId: id, sets: [LoggedSet(weight: weight, reps: 8, done: done)])
  }

  func testLaterDuplicateCompletionDoesNotFallBackToAnOlderWorkout() {
    let latest = session(
      "latest",
      entries: [entry("first", weight: 40, done: false), entry("later", weight: 42.5, done: true)])
    let older = session("older", entries: [entry("old", weight: 20, done: true)])
    XCTAssertEqual(
      WorkoutEngine.lastCompletedSet(for: "bench", in: [latest, older])?.weight, 42.5)
  }

  func testLastCompletedOccurrenceAndSetTakePrecedenceWithinTheNewestWorkout() {
    var later = entry("later", weight: 60, done: true)
    later.sets.append(LoggedSet(weight: 62.5, reps: 7, done: true))
    later.sets.append(LoggedSet(weight: 65, reps: 6, done: false))
    let latest = session("latest", entries: [entry("first", weight: 40, done: true), later])
    XCTAssertEqual(WorkoutEngine.lastCompletedSet(for: "bench", in: [latest])?.weight, 62.5)
  }

  func testExcludedAndUnfinishedSessionsAreSkippedWithoutInventingAResult() {
    let active = session("active", entries: [entry("current", weight: 100, done: true)])
    let unfinished = session("unfinished", entries: [entry("empty", weight: 80, done: false)])
    let older = session("older", entries: [entry("saved", weight: 20, done: true)])
    XCTAssertEqual(
      WorkoutEngine.lastCompletedSet(
        for: "bench", in: [active, unfinished, older], excluding: "active")?.weight,
      20)
    XCTAssertNil(WorkoutEngine.lastCompletedSet(for: "rower", in: [active, unfinished, older]))
    XCTAssertNil(WorkoutEngine.lastCompletedSet(for: "bench", in: [unfinished]))
  }
}
