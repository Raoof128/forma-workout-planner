import Foundation
import XCTest

@testable import FORMACore

final class MeasurementDraftTests: XCTestCase {
  func testEditingRepsPreservesFullPrecisionLoadAndOtherMeasurements() throws {
    let original = LoggedSet(weight: 50.123456789, reps: 8, durationSeconds: 45.123456789)
    var draft = MeasurementDraft(original)
    draft.reps = "9"
    let result = try draft.value(from: original)
    XCTAssertEqual(result.weight, original.weight)
    XCTAssertEqual(result.durationSeconds, original.durationSeconds)
    XCTAssertEqual(result.reps, 9)
  }

  func testDotAndCommaDecimalsNormalizeToCanonicalKilograms() throws {
    let original = LoggedSet(weight: 0, reps: 8)
    for input in ["2.5", "2,5", " 2,5 "] {
      var draft = MeasurementDraft(original)
      draft.weight = input
      XCTAssertEqual(try draft.value(from: original).weight, 2.5)
    }
  }

  func testAmbiguousBlankAndNonFiniteDraftsNeverBecomeSavedNumbers() {
    let original = LoggedSet(weight: 40, reps: 8)
    for input in ["", " ", "NaN", "inf", "1,234.5", "1.234,5", "2 500"] {
      var draft = MeasurementDraft(original)
      draft.weight = input
      XCTAssertThrowsError(try draft.value(from: original), input)
    }
    for input in ["0", "101", "8.5", "-1"] {
      var draft = MeasurementDraft(original)
      draft.reps = input
      XCTAssertThrowsError(try draft.value(from: original), input)
    }
  }

  func testPerSideDraftKeepsTotalRepsAndRejectsInvalidSides() throws {
    let original = LoggedSet(weight: 12, reps: 16, sides: SetSides(left: 8, right: 8))
    var draft = MeasurementDraft(original)
    draft.left = "9"
    draft.right = "10"
    let result = try draft.value(from: original)
    XCTAssertEqual(result.reps, 19)
    XCTAssertEqual(result.sides, SetSides(left: 9, right: 10))
    for invalid in ["0", "101", "1.5", ""] {
      draft.left = invalid
      XCTAssertThrowsError(try draft.value(from: original))
    }
  }

  func testUnequalSidesWithinCanonicalTotalRemainEditableWithoutHiddenReps() throws {
    let original = LoggedSet(weight: 12, reps: 100, sides: SetSides(left: 60, right: 40))
    var draft = MeasurementDraft(original)
    XCTAssertEqual(try draft.value(from: original), original)
    draft.reps = "not a visible field"
    draft.weight = "12,5"
    let edited = try draft.value(from: original)
    XCTAssertEqual(edited.reps, 100)
    XCTAssertEqual(edited.sides, SetSides(left: 60, right: 40))
    XCTAssertEqual(edited.weight, 12.5)
  }

  func testPerSideDraftRejectsACombinedCountAboveTheCanonicalLimit() {
    let original = LoggedSet(weight: 12, reps: 16, sides: SetSides(left: 8, right: 8))
    var draft = MeasurementDraft(original)
    draft.left = "60"
    draft.right = "41"
    XCTAssertThrowsError(try draft.value(from: original))
  }

  func testLocaleKeyboardDigitsSaveForEveryVisibleMeasurement() throws {
    let original = LoggedSet(
      weight: 12, reps: 16, sides: SetSides(left: 8, right: 8), durationSeconds: 45,
      distanceMeters: 100)
    var draft = MeasurementDraft(original, locale: Locale(identifier: "ar_EG"))
    draft.weight = "١٢٫٥"
    draft.left = "٩"
    draft.right = "١٠"
    draft.seconds = "٤٥٫٥"
    draft.distance = "١٠٠٫٢٥"
    let value = try draft.value(from: original)
    XCTAssertEqual(value.weight, 12.5)
    XCTAssertEqual(value.reps, 19)
    XCTAssertEqual(value.sides, SetSides(left: 9, right: 10))
    XCTAssertEqual(value.durationSeconds, 45.5)
    XCTAssertEqual(value.distanceMeters, 100.25)
  }

  func testLocaleDraftDisplayPreservesPrecisionWhileOnlyRepsChange() throws {
    let original = LoggedSet(weight: 50.12345678912345, reps: 8, durationSeconds: 45.12345678912345)
    var draft = MeasurementDraft(original, locale: Locale(identifier: "fr_FR"))
    XCTAssertTrue(draft.weight.contains(","))
    draft.reps = "٩"
    let value = try draft.value(from: original)
    XCTAssertEqual(value.weight, original.weight)
    XCTAssertEqual(value.durationSeconds, original.durationSeconds)
    XCTAssertEqual(value.reps, 9)
  }
}
