import XCTest

final class TrainingNavigationTests: XCTestCase {
  @MainActor
  func testAllTabsRemainReachableAfterCollapseAndSelectionStaysCorrect() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    let today = app.trainingTab("Today")
    XCTAssertTrue(today.waitForExistence(timeout: 20))
    XCTAssertFalse(app.tabBars.firstMatch.exists, "Only the app's glass bar should be visible")
    XCTAssertTrue(today.isSelected)

    app.trainingTab("You").tap()
    let you = app.buttons["tab-you"]
    XCTAssertTrue(you.isSelected)
    app.collectionViews.firstMatch.swipeUp()
    let expand = app.buttons["expand-training-tabs"]
    XCTAssertTrue(expand.waitForExistence(timeout: 5))
    expand.tap()
    let plan = app.trainingTab("Plan")
    XCTAssertTrue(plan.waitForExistence(timeout: 5))
    plan.tap()
    XCTAssertTrue(plan.isSelected)
    let create = app.buttons["create-routine"]
    app.revealTrainingControl(create)
    XCTAssertTrue(create.exists)
    app.trainingTab("Progress").tap()
    XCTAssertTrue(app.buttons["tab-progress"].isSelected)
    XCTAssertTrue(
      app.otherElements["progress-empty"].exists
        || app.staticTexts["Every first set counts."].exists)
  }
}

extension XCUIApplication {
  @MainActor
  func revealTrainingControl(_ element: XCUIElement) {
    for _ in 0..<8 {
      if element.exists && element.isHittable { return }
      let list = collectionViews.firstMatch
      if list.exists { list.swipeUp() } else { scrollViews.firstMatch.swipeUp() }
    }
  }

  /// The app owns its glass navigation controls so their symbols can animate.
  /// Expand the scroll-collapsed capsule before choosing another tab.
  @MainActor
  func trainingTab(_ title: String) -> XCUIElement {
    let expand = buttons["expand-training-tabs"]
    if expand.exists { expand.tap() }
    return buttons["tab-\(title.lowercased())"]
  }
}
