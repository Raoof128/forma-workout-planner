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
  func revealTrainingControl(_ element: XCUIElement, direction: TrainingScrollDirection = .up) {
    // Forms use shorter pans; retain the existing bound for ordinary scroll views.
    let attempts = collectionViews.firstMatch.exists ? 16 : 8
    for _ in 0..<attempts {
      let list = collectionViews.firstMatch
      if !list.exists {
        if element.exists && element.isHittable { return }
        let scroll = scrollViews.firstMatch
        if direction == .up { scroll.swipeUp() } else { scroll.swipeDown() }
        continue
      }
      let frame = list.frame.intersection(self.frame)
      let top = frame.minY + 80
      let bottom = min(
        frame.maxY - 100,
        keyboards.firstMatch.exists
          ? keyboards.firstMatch.frame.minY : frame.maxY)
      if element.exists && element.isHittable
        && element.frame.minY >= top && element.frame.maxY <= bottom
      {
        return
      }
      let distance = min(180, max(40, (bottom - top) * 0.6))
      var upward = direction == .up
      if element.exists {
        if element.frame.minY < top { upward = false }
        if element.frame.maxY > bottom { upward = true }
      }
      // Short drags reveal lazy rows without flinging past a whole section on SE.
      let origin = coordinate(withNormalizedOffset: .zero)
      let upper = origin.withOffset(CGVector(dx: frame.midX, dy: top))
      let lower = upper.withOffset(CGVector(dx: 0, dy: distance))
      (upward ? lower : upper).press(
        forDuration: 0.05, thenDragTo: upward ? upper : lower,
        withVelocity: .slow, thenHoldForDuration: 0.05)
    }
  }

  enum TrainingScrollDirection { case up, down }

  /// The app owns its glass navigation controls so their symbols can animate.
  /// Expand the scroll-collapsed capsule before choosing another tab.
  @MainActor
  func trainingTab(_ title: String) -> XCUIElement {
    let expand = buttons["expand-training-tabs"]
    if expand.exists { expand.tap() }
    return buttons["tab-\(title.lowercased())"]
  }
}
