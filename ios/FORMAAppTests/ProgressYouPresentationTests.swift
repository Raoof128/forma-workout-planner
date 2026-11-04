import Accessibility
import SwiftUI
import XCTest

@testable import FORMA

/// What Progress, You and the exercise guide show and speak, decided in
/// plain functions so the 2 November audit fixes stay fixed.
@MainActor
final class ProgressYouPresentationTests: XCTestCase {
  func testAMissingDurationIsLeftOutAndAShortOneIsNotZero() {
    XCTAssertNil(durationPhrase(nil))
    XCTAssertEqual(durationPhrase(0), "under 1 min")
    XCTAssertEqual(durationPhrase(59), "under 1 min")
    XCTAssertEqual(durationPhrase(60), "1 min")
    XCTAssertEqual(durationPhrase(2_730), "45 min")
  }

  func testTheReadoutFollowsTheMotionLevel() {
    XCTAssertEqual(MetricValue.transition(for: .full, value: 12), .numericText(value: 12))
    XCTAssertEqual(MetricValue.transition(for: .minimal, value: 12), .opacity)
    XCTAssertEqual(MetricValue.transition(for: .off, value: 12), .identity)
  }

  func testRestChoicesKeepASavedValueThatIsNotCommon() {
    let common = ProfileEditor.restChoices(including: 90)
    XCTAssertTrue(common.contains(90))
    XCTAssertEqual(common, common.sorted())
    let custom = ProfileEditor.restChoices(including: 95)
    XCTAssertTrue(custom.contains(95))
    XCTAssertEqual(custom, custom.sorted())
    XCTAssertEqual(custom.count, common.count + 1)
  }

  func testRestTextNamesMinutesNotOnlySeconds() {
    XCTAssertTrue(restText(600).contains("10"), restText(600))
    XCTAssertFalse(restText(600).contains("600"), restText(600))
  }

  func testAnIllustrationTitledLikeItsExerciseIsNotReadTwice() {
    func illustration(_ title: String) -> ExerciseMediaLibrary.Illustration {
      .init(
        sheet: "s", x: 0, y: 0, width: 1, height: 1, title: title, equipment: false, caption: "")
    }
    XCTAssertEqual(
      ExerciseIllustration.label(name: "Ab Roller", illustration: illustration("ab roller")),
      "Exercise illustration for Ab Roller")
    XCTAssertEqual(
      ExerciseIllustration.label(name: "Bench Press", illustration: illustration("Lowering phase")),
      "Exercise illustration for Bench Press: Lowering phase")
  }

  func testTheChartDescriptorNamesWorkoutsNotSessionIDs() throws {
    let descriptor = VolumeChartDescriptor(
      categories: ["1 Nov · Upper", "2 Nov · Lower"], volumes: [1_000, 3_000], peak: 3_000,
      average: 2_000
    ).makeChartDescriptor()
    let x = try XCTUnwrap(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
    XCTAssertEqual(x.categoryOrder, ["1 Nov · Upper", "2 Nov · Lower"])
    XCTAssertEqual(descriptor.series.first?.dataPoints.count, 2)
    XCTAssertTrue(descriptor.summary?.contains("Average") == true)
    let y = try XCTUnwrap(descriptor.yAxis)
    XCTAssertEqual(y.range, 0...3_000)
  }

  func testADemoPosterDecodesOffTheMainThread() async throws {
    let library = ExerciseMediaLibrary.shared
    let clip = try XCTUnwrap(library.demos.values.first?.clip)
    let url = try XCTUnwrap(ExerciseMediaLibrary.url(clip, "jpg", in: "demos"))
    let poster = await MediaDecoder.shared.decode(url)
    XCTAssertNotNil(poster?.cgImage)
  }
}
