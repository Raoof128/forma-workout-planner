import XCTest

/// Checks the Commit 2 motion rules from the user's side: motion never hides a
/// final state, set completion resolves in place, and the receipt only appears
/// once the finished workout has been confirmed and saved.
final class MotionExperienceTests: XCTestCase {
  @MainActor
  private func launchFreshWorkspace() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    return app
  }

  /// With You › Motion set to Off, every state change still lands: the set
  /// reads as completed and the finished workout reaches its receipt.
  @MainActor
  func testMotionOffStillShowsEveryFinalState() {
    let app = launchFreshWorkspace()
    let you = app.trainingTab("You")
    XCTAssertTrue(you.waitForExistence(timeout: 15))
    you.tap()
    let motion = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Motion"))
      .firstMatch
    app.revealTrainingControl(motion)
    XCTAssertTrue(motion.waitForExistence(timeout: 10))
    motion.tap()
    let off = app.buttons["Off"].firstMatch
    XCTAssertTrue(off.waitForExistence(timeout: 10))
    off.tap()

    app.trainingTab("Today").tap()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 10))
    start.tap()
    let set = app.buttons["complete-set-0-0"]
    XCTAssertTrue(set.waitForExistence(timeout: 10))
    set.tap()
    XCTAssertTrue(set.waitForMotionValue("Completed", timeout: 10))

    app.buttons["finish-workout"].firstMatch.tap()
    let confirm = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    confirm.tap()
    let receipt = app.descendants(matching: .any).matching(identifier: "receipt-screen").firstMatch
    XCTAssertTrue(receipt.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["receipt-done"].firstMatch.exists)
  }

  /// Set completion is the most repeated action, so it must not move the row
  /// being worked on: the weight field keeps its frame after the commit.
  @MainActor
  func testCompletingASetKeepsTheRowInPlace() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    let set = app.buttons["complete-set-0-0"]
    XCTAssertTrue(weight.waitForExistence(timeout: 10))
    XCTAssertTrue(set.waitForExistence(timeout: 10))
    let fieldBefore = weight.frame
    let buttonBefore = set.frame

    set.tap()
    XCTAssertTrue(set.waitForMotionValue("Completed", timeout: 10))
    // Let any state animation settle before measuring.
    _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 0.8)
    XCTAssertEqual(weight.frame, fieldBefore)
    XCTAssertEqual(set.frame, buttonBefore)
  }

  /// The receipt (and its success feedback) belongs to a saved workout, so it
  /// must not appear while the finish is still only a request.
  @MainActor
  func testReceiptWaitsForTheConfirmedFinish() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let set = app.buttons["complete-set-0-0"]
    XCTAssertTrue(set.waitForExistence(timeout: 10))
    set.tap()
    XCTAssertTrue(set.waitForMotionValue("Completed", timeout: 10))

    app.buttons["finish-workout"].firstMatch.tap()
    let confirm = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    let receipt = app.descendants(matching: .any).matching(identifier: "receipt-screen").firstMatch
    XCTAssertFalse(receipt.exists)
    confirm.tap()
    XCTAssertTrue(receipt.waitForExistence(timeout: 10))
    app.buttons["receipt-done"].firstMatch.tap()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 10))
  }
}

extension XCUIElement {
  fileprivate func waitForMotionValue(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    return XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout)
      == .completed
  }
}
