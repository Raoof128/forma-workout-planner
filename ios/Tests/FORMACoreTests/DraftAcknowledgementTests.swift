import XCTest

@testable import FORMACore

final class DraftAcknowledgementTests: XCTestCase {
  func testAcknowledgementClearsOnlyTheValuesThatActuallyFinishedSaving() {
    let original = MeasurementDraft(LoggedSet(weight: 40, reps: 8))
    let acknowledged = ["first": original, "second": original, "removed": original]
    var edited = original
    edited.weight = "42.5"
    let current = ["first": original, "second": edited, "new": edited]
    let remaining = retainingUnacknowledgedDrafts(current, acknowledged: acknowledged)
    XCTAssertEqual(remaining, ["second": edited, "new": edited])
    XCTAssertNil(remaining["removed"])
    XCTAssertEqual(retainingUnacknowledgedDrafts(remaining, acknowledged: acknowledged), remaining)
  }

  func testAnUnacknowledgedOrFailedSaveCannotClearDrafts() {
    let current = ["active": MeasurementDraft(LoggedSet(weight: 40, reps: 8))]
    let noAcknowledgement: [String: MeasurementDraft] = [:]
    XCTAssertEqual(retainingUnacknowledgedDrafts(current, acknowledged: noAcknowledgement), current)
  }

  func testACompletedSaveNeverRecreatesDraftsTheUserAlreadyRemoved() {
    let acknowledged = ["old": MeasurementDraft(LoggedSet(weight: 40, reps: 8))]
    let current: [String: MeasurementDraft] = [:]
    XCTAssertTrue(retainingUnacknowledgedDrafts(current, acknowledged: acknowledged).isEmpty)
  }
}
