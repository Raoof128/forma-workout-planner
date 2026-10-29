import Foundation
import XCTest

@testable import FORMACore

/// Shared synthetic cases are also checked against src/storage.js. This guards
/// canonical export bounds; it does not establish arbitrary web import support.
final class ValidationBoundaryTests: XCTestCase {
  private func corpus() throws -> Corpus {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    return try JSONDecoder().decode(
      Corpus.self,
      from: Data(contentsOf: project.appendingPathComponent("Fixtures/validation-boundaries.json")))
  }

  func testHistoryDatesMatchStrictWebCalendarAndUTCGrammar() throws {
    let corpus = try corpus()
    XCTAssertTrue(corpus.synthetic)
    for fixture in corpus.historyDates {
      var workspace = Fixtures.workspace()
      var session = Fixtures.active(now: 1_792_440_000_000).active!
      session.exercises[0].sets[0].done = true
      session.date = fixture.value
      session.duration = 60
      workspace.history = [session]
      assertValidation(workspace, accepted: fixture.accepted, id: fixture.id)
    }
  }

  func testOptionalRoutineMeasurementsArePositiveEvenForOtherMetricProfiles() throws {
    for fixture in try corpus().routineMeasurements {
      var workspace = Fixtures.workspace()
      switch fixture.field {
      case "durationSeconds": workspace.routines[0].exercises[0].durationSeconds = fixture.value
      case "distanceMeters": workspace.routines[0].exercises[0].distanceMeters = fixture.value
      default: XCTFail("Unknown fixture measurement: \(fixture.field)")
      }
      assertValidation(workspace, accepted: fixture.accepted, id: fixture.id)
    }
  }

  func testActiveSessionCannotEncodeHistoryOnlyCompletionFields() throws {
    for fixture in try corpus().activeCompletionMetadata {
      var workspace = Fixtures.active(now: 1_792_440_000_000)
      workspace.active!.date = fixture.date
      workspace.active!.duration = fixture.duration
      assertValidation(workspace, accepted: fixture.accepted, id: fixture.id)
    }
  }

  private func assertValidation(_ workspace: Workspace, accepted: Bool, id: String) {
    if accepted {
      XCTAssertNoThrow(try workspace.validate(catalog: Fixtures.catalog), id)
    } else {
      XCTAssertThrowsError(try workspace.validate(catalog: Fixtures.catalog), id)
    }
  }

  private struct Corpus: Decodable {
    var synthetic: Bool
    var historyDates: [DateBoundary]
    var routineMeasurements: [MeasurementBoundary]
    var activeCompletionMetadata: [ActiveBoundary]
  }
  private struct DateBoundary: Decodable {
    var id: String
    var value: String
    var accepted: Bool
  }
  private struct MeasurementBoundary: Decodable {
    var id: String
    var field: String
    var value: Double
    var accepted: Bool
  }
  private struct ActiveBoundary: Decodable {
    var id: String
    var date: String?
    var duration: Double?
    var accepted: Bool
  }
}
