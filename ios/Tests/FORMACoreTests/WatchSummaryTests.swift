import Foundation
import XCTest

@testable import FORMACore

final class WatchSummaryTests: XCTestCase {
  private let now = 1_792_700_000_000.0

  private func finished(watch: WorkoutWatchSummary? = nil) throws -> Workspace {
    var workspace = Fixtures.active(now: now)
    workspace = try WorkoutEngine.toggleSet(
      in: workspace, entryIndex: 0, setIndex: 0, now: now, catalog: Fixtures.catalog)
    return try WorkoutEngine.finish(
      workspace, now: now + 60_000, catalog: Fixtures.catalog, watch: watch)
  }

  /// The same cases unit/ios-validation-boundaries.test.js runs against the web schema.
  func testSharedBoundariesMatchTheWebSchema() throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(
      contentsOf: project.appendingPathComponent("Fixtures/validation-boundaries.json"))
    let corpus = try JSONDecoder().decode(Corpus.self, from: data)
    XCTAssertFalse(corpus.watchSummaries.isEmpty)
    for fixture in corpus.watchSummaries {
      let summary: WorkoutWatchSummary
      do {
        summary = try JSONDecoder().decode(WorkoutWatchSummary.self, from: fixture.summary)
      } catch {
        // A summary that doesn't decode (no time, a fraction) is a rejection.
        XCTAssertFalse(fixture.accepted, fixture.id)
        continue
      }
      var workspace = try finished()
      workspace.history[0].watch = summary
      if fixture.accepted {
        XCTAssertNoThrow(try workspace.validate(catalog: Fixtures.catalog), fixture.id)
      } else {
        XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog), fixture.id)
      }
    }
  }

  func testLiveReadingsRoundIntoStoredBounds() {
    let summary = WorkoutWatchSummary(
      elapsed: 2_520.9, averageHeartRate: 127.6, maxHeartRate: 161.5, activeEnergy: 309.5)
    XCTAssertEqual(
      summary,
      WorkoutWatchSummary(
        elapsedSeconds: 2_520, averageHeartRate: 128, maxHeartRate: 162, activeEnergyKcal: 310))
    XCTAssertTrue(summary.isValid)
  }

  func testOutOfRangeReadingsAreDroppedNotClamped() {
    let summary = WorkoutWatchSummary(
      elapsed: 200_000, averageHeartRate: 12, maxHeartRate: .nan, activeEnergy: -4)
    XCTAssertEqual(summary, WorkoutWatchSummary(elapsedSeconds: 86_400))
    XCTAssertTrue(summary.isValid)
  }

  func testAverageNeverExceedsMaximumAfterRounding() {
    let summary = WorkoutWatchSummary(
      elapsed: 60, averageHeartRate: 140.4, maxHeartRate: 139.6, activeEnergy: nil)
    XCTAssertEqual(summary.averageHeartRate, 140)
    XCTAssertEqual(summary.maxHeartRate, 140)
    XCTAssertTrue(summary.isValid)
  }

  func testFinishStoresTheSummaryOnHistoryAndItRoundTrips() throws {
    let summary = WorkoutWatchSummary(
      elapsedSeconds: 60, averageHeartRate: 120, maxHeartRate: 150, activeEnergyKcal: 12)
    let workspace = try finished(watch: summary)
    XCTAssertNil(workspace.active)
    XCTAssertEqual(workspace.history[0].watch, summary)
    let decoded = try JSONDecoder().decode(
      Workspace.self, from: try JSONEncoder().encode(workspace))
    XCTAssertEqual(decoded.history[0].watch, summary)
  }

  func testWorkoutsWithoutAWatchEncodeNoWatchKey() throws {
    let workspace = try finished()
    let json = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(workspace))
    let history = try XCTUnwrap((json as? [String: Any])?["history"] as? [[String: Any]])
    XCTAssertNil(history[0]["watch"])
  }

  func testActiveWorkoutCannotCarryASummary() throws {
    var workspace = Fixtures.active(now: now)
    workspace.active?.watch = WorkoutWatchSummary(elapsedSeconds: 60)
    XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog))
  }

  func testFinalReadingReplacesTheFinishedSummaryOnly() throws {
    let workspace = try finished(watch: WorkoutWatchSummary(elapsedSeconds: 50))
    let id = workspace.history[0].id
    let final = WorkoutWatchSummary(elapsedSeconds: 61, averageHeartRate: 118)
    let updated = try WorkoutEngine.attachWatchSummary(final, toFinished: id, in: workspace)
    XCTAssertEqual(updated.history[0].watch, final)
    // Deleted or never finished: nothing changes.
    let missing = try WorkoutEngine.attachWatchSummary(final, toFinished: "gone", in: workspace)
    XCTAssertEqual(missing, workspace)
    XCTAssertThrowsError(
      try WorkoutEngine.attachWatchSummary(
        WorkoutWatchSummary(elapsedSeconds: -1), toFinished: id, in: workspace))
  }

  private struct Corpus: Decodable {
    var watchSummaries: [Boundary]
  }
  private struct Boundary: Decodable {
    var id: String
    var summary: Data
    var accepted: Bool

    private enum CodingKeys: String, CodingKey { case id, summary, accepted }
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      id = try c.decode(String.self, forKey: .id)
      accepted = try c.decode(Bool.self, forKey: .accepted)
      summary = try JSONEncoder().encode(try c.decode(JSONValue.self, forKey: .summary))
    }
  }
}

/// Just enough JSON to re-encode a fixture object for `JSONDecoder`.
private enum JSONValue: Codable {
  case number(Double), string(String), bool(Bool), array([JSONValue]), object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let value = try? c.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? c.decode(Double.self) {
      self = .number(value)
    } else if let value = try? c.decode(String.self) {
      self = .string(value)
    } else if let value = try? c.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try c.decode([String: JSONValue].self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .number(let value):
      // Whole numbers stay integers so `Int` fields decode them.
      if value.rounded() == value, abs(value) < 1e15 { try c.encode(Int(value)) } else {
        try c.encode(value)
      }
    case .string(let value): try c.encode(value)
    case .bool(let value): try c.encode(value)
    case .array(let value): try c.encode(value)
    case .object(let value): try c.encode(value)
    }
  }
}

final class WatchTotalsTests: XCTestCase {
  private func session(_ id: String, _ watch: WorkoutWatchSummary?) -> WorkoutSession {
    WorkoutSession(id: id, name: "Upper", startedAt: 0, watch: watch)
  }

  func testTotalsWeightHeartRateByRecordedTime() {
    let totals = WatchTotals([
      session(
        "a",
        WorkoutWatchSummary(
          elapsedSeconds: 600, averageHeartRate: 100, maxHeartRate: 140, activeEnergyKcal: 50)),
      session("b", nil),
      session(
        "c",
        WorkoutWatchSummary(
          elapsedSeconds: 1_800, averageHeartRate: 140, maxHeartRate: 171, activeEnergyKcal: 200)),
      session("d", WorkoutWatchSummary(elapsedSeconds: 300)),
    ])
    XCTAssertEqual(totals.workouts, 3)
    XCTAssertEqual(totals.averageHeartRate, 130)
    XCTAssertEqual(totals.highestHeartRate, 171)
    XCTAssertEqual(totals.activeEnergyKcal, 250)
    XCTAssertEqual(totals.elapsedSeconds, 2_700)
  }

  func testNoWatchWorkoutsGiveEmptyTotals() {
    let totals = WatchTotals([session("a", nil)])
    XCTAssertEqual(totals.workouts, 0)
    XCTAssertNil(totals.averageHeartRate)
    XCTAssertNil(totals.highestHeartRate)
    XCTAssertEqual(totals.activeEnergyKcal, 0)
  }
}
