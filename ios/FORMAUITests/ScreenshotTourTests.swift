import XCTest

/// Walks the primary screens of a fresh local workspace and attaches a
/// screenshot of each one. It records evidence for design reviews (run once in
/// light and once in dark appearance); the assertions only check that each
/// screen was actually reached, so a screenshot never shows the wrong screen.
final class ScreenshotTourTests: XCTestCase {
  @MainActor
  private func capture(_ app: XCUIApplication, _ name: String) {
    // Let one-time entrances and state animations settle so the screenshot
    // shows the resting state, not a frame mid-transition.
    _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.2)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testPrimaryScreensTour() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()

    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 30))
    capture(app, "01-today")

    let plan = app.trainingTab("Plan")
    plan.tap()
    let routine = app.staticTexts["Upper body strength"].firstMatch
    XCTAssertTrue(routine.waitForExistence(timeout: 10))
    capture(app, "02-plan")
    routine.tap()
    let startRoutine = app.buttons["start-routine-workout"]
    XCTAssertTrue(startRoutine.waitForExistence(timeout: 10))
    capture(app, "03-routine-detail")

    startRoutine.tap()
    let firstSet = app.buttons["complete-set-0-0"]
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    capture(app, "04-workout")
    firstSet.tap()
    XCTAssertTrue(
      NSPredicate(format: "value == %@", "Completed").evaluate(with: firstSet)
        || firstSet.waitForValue("Completed", timeout: 10))
    capture(app, "05-set-completed-rest")

    app.buttons["finish-workout"].firstMatch.tap()
    let confirm = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    confirm.tap()
    let receipt = app.descendants(matching: .any).matching(identifier: "receipt-screen").firstMatch
    XCTAssertTrue(receipt.waitForExistence(timeout: 10))
    capture(app, "06-receipt")
    app.buttons["receipt-done"].firstMatch.tap()

    let progress = app.trainingTab("Progress")
    XCTAssertTrue(progress.waitForExistence(timeout: 10))
    progress.tap()
    XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "lifting-volume-chart")
        .firstMatch.waitForExistence(timeout: 10))
    capture(app, "07-progress")

    app.trainingTab("You").tap()
    XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["account-sign-in"].waitForExistence(timeout: 10))
    capture(app, "08-you")

    app.trainingTab("Today").tap()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
    capture(app, "09-today-after-workout")
  }

  @MainActor
  func testLibrarySearchAndTechniqueGuideTour() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    let plan = app.trainingTab("Plan")
    XCTAssertTrue(plan.waitForExistence(timeout: 20))
    plan.tap()
    let libraryLink = app.staticTexts["Exercise library"].firstMatch
    app.revealTrainingControl(libraryLink)
    XCTAssertTrue(libraryLink.exists && libraryLink.isHittable)
    libraryLink.tap()
    XCTAssertTrue(app.navigationBars["Exercise library"].waitForExistence(timeout: 10))
    let library = app.descendants(matching: .any).matching(identifier: "exercise-library")
      .firstMatch
    XCTAssertTrue(library.waitForExistence(timeout: 10))
    capture(app, "10-library")

    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("Barbell bench press")
    let result = app.staticTexts["Barbell bench press"].firstMatch
    XCTAssertTrue(result.waitForExistence(timeout: 10))
    capture(app, "11-library-search")
    result.tap()
    XCTAssertTrue(app.navigationBars["Technique guide"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Barbell bench press"].waitForExistence(timeout: 10))
    capture(app, "12-technique-guide")
  }

  @MainActor
  func testTimedHoldTour() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    let plan = app.trainingTab("Plan")
    XCTAssertTrue(plan.waitForExistence(timeout: 20))
    plan.tap()
    let routine = app.staticTexts["Lower body foundation"].firstMatch
    app.revealTrainingControl(routine)
    XCTAssertTrue(routine.exists && routine.isHittable)
    routine.tap()
    let start = app.buttons["start-routine-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 10))
    start.tap()
    let choose = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Choose exercise")
    ).firstMatch
    XCTAssertTrue(choose.waitForExistence(timeout: 10))
    choose.tap()
    let plank = app.buttons["6. Forearm plank"]
    XCTAssertTrue(plank.waitForExistence(timeout: 10))
    plank.tap()
    let holdStart = app.buttons["hold-start"]
    app.revealTrainingControl(holdStart)
    XCTAssertTrue(holdStart.exists && holdStart.isHittable)
    capture(app, "13-hold-ready")
    holdStart.tap()
    let pause = app.buttons["hold-toggle"]
    XCTAssertTrue(pause.waitForExistence(timeout: 10))
    XCTAssertEqual(pause.label, "Pause hold timer")
    let remaining = app.descendants(matching: .any).matching(identifier: "hold-remaining")
      .firstMatch
    XCTAssertTrue(remaining.exists)
    capture(app, "14-hold-running")
    pause.tap()
    XCTAssertTrue(pause.waitForValueLabel("Resume hold timer", timeout: 10))
    capture(app, "15-hold-paused")
    app.buttons["hold-cancel"].tap()
    XCTAssertTrue(holdStart.waitForExistence(timeout: 10))
    let firstSet = app.buttons["complete-set-5-0"]
    app.revealTrainingControl(firstSet)
    XCTAssertTrue(firstSet.exists)
    XCTAssertEqual(firstSet.value as? String, "Not completed")
  }
}

extension XCUIElement {
  /// Waits until the element's accessibility value equals `expected`.
  fileprivate func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }

  fileprivate func waitForValueLabel(_ expected: String, timeout: TimeInterval) -> Bool {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", expected), object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }
}
