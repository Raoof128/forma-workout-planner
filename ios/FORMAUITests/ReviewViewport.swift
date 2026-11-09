import XCTest

extension XCUIApplication {
  /// Exercise the isolated app's own preference, leaving the phone's global
  /// appearance setting unchanged. Captures still require a visual check.
  @MainActor
  func applyReviewAppearance() {
    let environment = ProcessInfo.processInfo.environment
    guard
      let appearance = environment["FORMA_REVIEW_APPEARANCE"]
        ?? environment["TEST_RUNNER_FORMA_REVIEW_APPEARANCE"]
    else {
      return
    }
    XCTAssertTrue(["Light", "Dark"].contains(appearance))
    guard ["Light", "Dark"].contains(appearance) else { return }
    print("FORMA_REVIEW_APPEARANCE_REQUESTED=\(appearance)")
    let you = trainingTab("You")
    XCTAssertTrue(you.waitForExistence(timeout: 20))
    you.tap()
    let picker = buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Appearance"))
      .firstMatch
    revealTrainingControl(picker)
    XCTAssertTrue(picker.exists && picker.isHittable)
    picker.tap()
    let option = buttons[appearance].firstMatch
    XCTAssertTrue(option.waitForExistence(timeout: 10))
    option.tap()
    let today = trainingTab("Today")
    XCTAssertTrue(today.waitForExistence(timeout: 10))
    today.tap()
    XCTAssertTrue(buttons["start-workout"].waitForExistence(timeout: 20))
  }

  /// A paired Watch presents a choice before the workout opens. Exercise the
  /// real iPhone-only action so hardware journeys never start a Health workout
  /// on the person's Watch or depend on their pairing configuration.
  @MainActor
  func continueWorkoutOnIPhone(file: StaticString = #filePath, line: UInt = #line) {
    let phone = buttons["start-on-iphone"]
    let firstSet = buttons["complete-set-0-0"]
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in phone.exists || firstSet.exists }, object: self)
    XCTAssertEqual(
      XCTWaiter.wait(for: [ready], timeout: 15), .completed,
      "Starting must reach the workout or the paired-Watch choice", file: file, line: line)
    if phone.exists {
      revealTrainingControl(phone)
      XCTAssertTrue(phone.isHittable, file: file, line: line)
      phone.tap()
    }
    XCTAssertTrue(
      firstSet.waitForExistence(timeout: 15),
      "The iPhone-only workout must open", file: file, line: line)
  }

  /// Orientation changes are asynchronous. A landscape case must not contaminate later journeys.
  @MainActor
  func prepareReviewViewport(file: StaticString = #filePath, line: UInt = #line) {
    XCUIDevice.shared.orientation = .portrait
    let portrait = NSPredicate { _, _ in self.frame.height > self.frame.width }
    let expectation = XCTNSPredicateExpectation(predicate: portrait, object: self)
    XCTAssertEqual(
      XCTWaiter.wait(for: [expectation], timeout: 8), .completed,
      "Review journey must start in portrait", file: file, line: line)
  }
}
