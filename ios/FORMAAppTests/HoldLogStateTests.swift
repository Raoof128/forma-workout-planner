import Foundation
import XCTest

@testable import FORMA

final class HoldLogStateTests: XCTestCase {
  func testDeadlineAndManualEndCanClaimOnlyOneSave() throws {
    var state = HoldLogState()
    let id = UUID()
    state.begin(id)
    let first = try XCTUnwrap(state.claim(holdID: id, seconds: 30))
    XCTAssertNil(state.claim(holdID: id, seconds: 31))
    XCTAssertEqual(first.seconds, 30)
    XCTAssertTrue(state.isSaving)
    XCTAssertTrue(state.acknowledged(first))
    // A delayed duplicate must not target the next unfinished workout set.
    XCTAssertNil(state.claim(holdID: id, seconds: 32))
    XCTAssertFalse(state.begin(id), "A saved timer cannot be rearmed as a new effort")
  }

  func testFailedSaveRetainsExactDurationUntilAcknowledgedRetry() throws {
    var state = HoldLogState()
    let id = UUID()
    state.begin(id)
    let first = try XCTUnwrap(state.claim(holdID: id, seconds: 37))
    XCTAssertTrue(state.failed(first))
    XCTAssertTrue(state.needsRetry)
    XCTAssertEqual(state.attempt?.seconds, 37)
    let retry = try XCTUnwrap(state.claim(holdID: id, seconds: 95))
    XCTAssertEqual(retry.holdID, first.holdID)
    XCTAssertEqual(
      retry.seconds, first.seconds, "Waiting/correcting a draft must not extend the hold")
    XCTAssertNotEqual(retry.id, first.id)
    XCTAssertFalse(state.acknowledged(first), "An earlier response cannot acknowledge a retry")
    XCTAssertFalse(state.failed(first), "An earlier response cannot fail a retry")
    XCTAssertTrue(state.acknowledged(retry))
    XCTAssertNil(state.attempt)
    XCTAssertFalse(state.needsRetry)
  }

  func testCancelledOrReplacedHoldRejectsOldTriggers() throws {
    var state = HoldLogState()
    let old = UUID()
    state.begin(old)
    let submitted = try XCTUnwrap(state.claim(holdID: old, seconds: 20))
    state.failed(submitted)
    state.cancel(old)
    XCTAssertNil(state.claim(holdID: old, seconds: 21))
    let current = UUID()
    state.begin(current)
    let replacement = try XCTUnwrap(state.claim(holdID: current, seconds: 10))
    XCTAssertNil(state.claim(holdID: old, seconds: 22))
    XCTAssertFalse(state.acknowledged(submitted))
    XCTAssertFalse(state.failed(submitted))
    XCTAssertEqual(state.attempt, replacement)
  }

  func testInFlightSaveCannotBeCancelledOrReplaced() throws {
    var state = HoldLogState()
    let id = UUID()
    state.begin(id)
    let submitted = try XCTUnwrap(state.claim(holdID: id, seconds: 15))
    state.cancel(id)
    XCTAssertFalse(state.begin(UUID()))
    XCTAssertEqual(state.attempt, submitted)
    XCTAssertTrue(state.acknowledged(submitted))
  }
}
