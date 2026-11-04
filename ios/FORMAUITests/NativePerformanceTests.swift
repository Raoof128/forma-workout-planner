import XCTest

/// Repeatable synthetic measurements for Simulator and an isolated device
/// build. Clock results include XCTest's interaction/synchronization cost;
/// they are not frame-time, energy, or pure application-response measurements.
final class NativePerformanceTests: XCTestCase {
  @MainActor
  private func reviewApp() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    return app
  }

  @MainActor
  func testLaunchUntilResponsive() {
    let app = reviewApp()
    measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
      app.launch()
      XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
    }
  }

  @MainActor
  func testRepeatedTabNavigationResources() {
    let app = reviewApp()
    app.launch()
    app.prepareReviewViewport()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
    measure(
      metrics: [
        XCTClockMetric(), XCTMemoryMetric(application: app), XCTCPUMetric(application: app),
      ]
    ) {
      for title in ["Plan", "Progress", "You", "Today"] {
        let tab = app.trainingTab(title)
        XCTAssertTrue(tab.isHittable)
        tab.tap()
        XCTAssertTrue(tab.isSelected)
      }
    }
  }
}
