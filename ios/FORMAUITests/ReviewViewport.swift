import XCTest

extension XCUIApplication {
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
