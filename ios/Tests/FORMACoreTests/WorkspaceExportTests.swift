import Foundation
import XCTest

@testable import FORMACore

final class WorkspaceExportTests: XCTestCase {
  func testMaximumSetWorkspaceExportsWithinExistingBackupLimitAndRoundTripsAllValues() throws {
    let set = LoggedSet(
      weight: 60, reps: 16, sides: SetSides(left: 8, right: 8), rpe: 7.5, done: true)
    let entry = SessionEntry(
      exerciseId: "bench", perSide: true, sets: Array(repeating: set, count: 100))
    let history = (0..<1_500).map { index in
      WorkoutSession(
        id: "synthetic-export-\(index)", name: "Synthetic capacity regression",
        startedAt: 1_792_440_000_000, exercises: [entry], date: "2026-10-20T00:00:00.000Z",
        duration: 60)
    }
    let workspace = Workspace(history: history)
    try workspace.validate(catalog: Fixtures.catalog)
    let exported = try WorkspaceExport.encode(workspace)
    XCTAssertLessThanOrEqual(exported.count, Workspace.maximumBytes)
    let restored = try JSONDecoder().decode(Workspace.self, from: exported)
    XCTAssertEqual(restored, workspace)
    XCTAssertEqual(restored.history.flatMap(\.exercises).flatMap(\.sets).count, 150_000)
  }

}
