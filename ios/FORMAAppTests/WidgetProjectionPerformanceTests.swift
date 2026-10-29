import FORMACore
import FORMASurfaces
import Foundation
import XCTest

@testable import FORMA

@MainActor
final class WidgetProjectionPerformanceTests: XCTestCase {
  func testCanonicalRecordLimitProjectionPerformance() throws {
    // Construct and validate outside the measured block. One completed set per
    // session isolates projection cost at the canonical record limits without
    // conflating it with fixture allocation, catalogue decoding or validation.
    let workspace = try recordLimitWorkspace()
    let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-29T01:00:00Z"))
    let expected = WidgetSnapshotBridge.project(
      workspace, sharing: true, epoch: "synthetic-performance", at: now)
    XCTAssertEqual(workspace.history.count, 10_000)
    XCTAssertEqual(workspace.routines.count, 200)
    XCTAssertEqual(expected.state, .ready)
    XCTAssertEqual(expected.revision, 42)
    XCTAssertEqual(expected.routine?.id, "routine-1", "Archived routines must be excluded")
    XCTAssertEqual(expected.active?.completedSets, 1)
    XCTAssertEqual(expected.active?.totalSets, 2)
    XCTAssertEqual(expected.week?.sessions, 3, "History order must not hide in-week records")
    XCTAssertEqual(expected.week?.days, [true, false, true, false, false, false, false])
    XCTAssertEqual(expected.week?.goal, 4)
    let encoded = try JSONEncoder().encode(expected)
    XCTAssertEqual(try TrainingSnapshot.decode(encoded, at: now), expected)
    XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("SYNTHETIC PRIVATE NOTE"))

    var measured: TrainingSnapshot?
    let options = XCTMeasureOptions()
    options.iterationCount = 10
    measure(metrics: [XCTClockMetric()], options: options) {
      measured = WidgetSnapshotBridge.project(
        workspace, sharing: true, epoch: "synthetic-performance", at: now)
    }
    XCTAssertEqual(measured, expected, "Measured work must produce the verified projection")
    XCTAssertEqual(workspace.revision, 42, "Projection must not mutate canonical data")
  }

  private func recordLimitWorkspace() throws -> Workspace {
    let prescription = Prescription(exerciseId: "bench", sets: 1, reps: 8, weight: 40)
    let routines = (0..<200).map { index in
      Routine(
        id: "routine-\(index)", name: "Synthetic routine \(index)",
        archivedAt: index == 0 ? 1 : nil, exercises: [prescription])
    }
    let entry = SessionEntry(
      exerciseId: "bench", sets: [LoggedSet(weight: 40, reps: 8, done: true)])
    var history = (0..<10_000).map { index in
      WorkoutSession(
        id: "history-\(index)", name: "Synthetic saved workout",
        startedAt: 1_727_740_800_000, notes: "SYNTHETIC PRIVATE NOTE",
        exercises: [entry], date: "2024-10-01T00:00:00Z", duration: 60)
    }
    // Deliberately distribute current-week records through unsorted history.
    history[0].date = "2026-10-26T00:00:00Z"
    history[5_000].date = "2026-10-28T00:00:00Z"
    history[9_999].date = "2026-10-28T02:00:00Z"
    let active = WorkoutSession(
      id: "active-performance", name: "Synthetic active workout", startedAt: 1_793_235_600_000,
      exercises: [
        SessionEntry(
          exerciseId: "bench",
          sets: [LoggedSet(weight: 40, reps: 8, done: true), LoggedSet(weight: 40, reps: 8)])
      ])
    let workspace = Workspace(
      revision: 42, routines: routines, history: history, active: active,
      profile: Profile(name: "Synthetic performance fixture", goal: 4), schedule: [0, 2, 4])
    let catalog = [
      Exercise(
        id: "bench", name: "Barbell bench press", muscle: "Chest", equipment: "Barbell",
        description: "Synthetic test catalogue")
    ]
    try workspace.validate(catalog: catalog)
    return workspace
  }
}
