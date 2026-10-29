import Foundation
import XCTest

@testable import FORMACore

final class MeasurementTextTests: XCTestCase {
  private let locale = Locale(identifier: "en_US_POSIX")

  private func exercise(
    id: String = "movement", metric: String = "load_reps", loadType: String = "load"
  ) -> Exercise {
    Exercise(
      id: id, name: "Movement", muscle: "Full body", equipment: "Equipment", description: "",
      metric: metric, loadType: loadType)
  }

  func testTimedDistanceRetainsSavedLoad() {
    let set = LoggedSet(
      weight: 25, reps: 1, durationSeconds: 60, distanceMeters: 100, done: true)
    XCTAssertEqual(
      MeasurementText.summary(
        set, exercise: exercise(metric: "duration_distance"), locale: locale),
      "60 sec · 100 m · 25 kg")
  }

  func testUnloadedTimedDistanceOmitsZeroLoad() {
    let set = LoggedSet(
      weight: 0, reps: 1, durationSeconds: 90, distanceMeters: 400, done: true)
    XCTAssertEqual(
      MeasurementText.summary(
        set, exercise: exercise(metric: "duration_distance", loadType: "none"), locale: locale),
      "90 sec · 400 m")
  }

  func testDurationAndCarryKeepTheirOwnMeasurements() {
    let set = LoggedSet(
      weight: 12.5, reps: 1, durationSeconds: 45, distanceMeters: 80, done: true)
    XCTAssertEqual(
      MeasurementText.summary(set, exercise: exercise(metric: "duration"), locale: locale),
      "45 sec · 12.5 kg")
    XCTAssertEqual(
      MeasurementText.summary(set, exercise: exercise(metric: "load_distance"), locale: locale),
      "12.5 kg · 80 m")
  }

  func testUnequalSidesKeepLeftAndRightCounts() {
    let set = LoggedSet(weight: 20, reps: 19, sides: SetSides(left: 12, right: 7), done: true)
    XCTAssertEqual(
      MeasurementText.summary(set, exercise: exercise(), locale: locale),
      "20 kg × 12 L / 7 R")
  }

  func testNoLoadCatalogueEntryRetainsHistoricalNonzeroLoad() {
    let movement = exercise(loadType: "none")
    XCTAssertEqual(
      MeasurementText.summary(
        LoggedSet(weight: 0, reps: 10, done: true), exercise: movement, locale: locale), "10 reps")
    XCTAssertEqual(
      MeasurementText.summary(
        LoggedSet(weight: 5, reps: 10, done: true), exercise: movement, locale: locale),
      "5 kg × 10 reps")
  }

  func testLegacyPlankKeepsTenSecondRepMeaning() {
    XCTAssertEqual(
      MeasurementText.summary(
        LoggedSet(weight: 0, reps: 6, done: true),
        exercise: exercise(id: "plank", loadType: "none"), locale: locale),
      "6 reps (10 sec / rep)")
  }

  func testDecimalLoadUsesRequestedLocale() {
    XCTAssertEqual(
      MeasurementText.summary(
        LoggedSet(weight: 12.5, reps: 10, done: true), exercise: exercise(),
        locale: Locale(identifier: "fr_FR")), "12,5 kg × 10 reps")
  }
}
