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
    app.launchArguments = ["--ui-testing", "--reset-workspace"]
    app.launch()

    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 30))
    capture(app, "01-today")

    let plan = app.tabBars.buttons["Plan"]
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

    let progress = app.tabBars.buttons["Progress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 10))
    progress.tap()
    XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
    capture(app, "07-progress")

    app.tabBars.buttons["You"].tap()
    XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
    capture(app, "08-you")

    app.tabBars.buttons["Today"].tap()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
    capture(app, "09-today-after-workout")
  }
}

extension XCUIElement {
  /// Waits until the element's accessibility value equals `expected`.
  fileprivate func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }
}
