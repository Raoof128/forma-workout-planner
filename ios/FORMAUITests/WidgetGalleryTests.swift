import XCTest

/// System-hosted gallery evidence, distinct from the shared-view render matrix.
final class WidgetGalleryTests: XCTestCase {
  @MainActor
  func testSystemWidgetGallery() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
    app.trainingTab("You").tap()
    let sharing = app.switches["widget-sharing"]
    app.revealTrainingControl(sharing)
    XCTAssertTrue(sharing.waitForExistence(timeout: 10))
    if sharing.value as? String == "0" {
      // The native switch thumb is at the trailing edge of the semantic row.
      sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    }
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "1"), object: sharing)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let icon = springboard.icons["FORMA"].firstMatch
    XCTAssertTrue(icon.waitForExistence(timeout: 10))
    icon.press(forDuration: 1.5)
    let edit = springboard.buttons["Edit Home Screen"]
    XCTAssertTrue(edit.waitForExistence(timeout: 10))
    edit.tap()
    let attachment = XCTAttachment(screenshot: springboard.screenshot())
    attachment.name = "widget-system-home-edit"
    attachment.lifetime = .keepAlways
    add(attachment)
    springboard.buttons["Edit"].tap()
    let addWidget = springboard.buttons.matching(
      NSPredicate(format: "label IN %@", ["Add Widget", "Add Widgets"])
    ).firstMatch
    XCTAssertTrue(addWidget.waitForExistence(timeout: 10))
    addWidget.tap()
    let search = springboard.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("FORMA")
    let provider = springboard.staticTexts["FORMA"].firstMatch
    XCTAssertTrue(provider.waitForExistence(timeout: 10))
    provider.tap()
    XCTAssertTrue(springboard.staticTexts["Training at a glance"].waitForExistence(timeout: 10))
    capture(springboard, "widget-system-small-gallery")
    springboard.swipeLeft()
    capture(springboard, "widget-system-medium-gallery")
    let install = springboard.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS[c] %@", "Add Widget")
    ).firstMatch
    if install.waitForExistence(timeout: 3) {
      install.tap()
    } else {
      // iOS27's remote gallery AX host sometimes omits this visible system control.
      // On modern portrait iPhones, the observed48pt control sits84pt above the bottom.
      // Keep a strict viewport guard; older layouts must expose the semantic control.
      XCTAssertGreaterThanOrEqual(springboard.frame.height, 800)
      XCTAssertGreaterThan(springboard.frame.height, springboard.frame.width)
      XCTAssertTrue(springboard.staticTexts["Training at a glance"].exists)
      springboard.coordinate(
        withNormalizedOffset: CGVector(
          dx: 0.5, dy: (springboard.frame.height - 84) / springboard.frame.height)
      ).tap()
    }
    let done = springboard.buttons["Done"].firstMatch
    if done.waitForExistence(timeout: 5) { done.tap() }
    let routine = springboard.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Upper body strength")
    ).firstMatch
    XCTAssertTrue(routine.waitForExistence(timeout: 15))
    capture(springboard, "widget-system-home-installed")
    routine.tap()
    XCTAssertTrue(app.buttons["start-routine-workout"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.navigationBars["Routine"].exists)
    XCTAssertFalse(
      app.buttons["complete-set-0-0"].exists, "Opening a widget must not start a workout")
  }

  @MainActor
  private func capture(_ app: XCUIApplication, _ name: String) {
    _ = XCTWaiter.wait(
      for: [XCTestExpectation(description: "gallery animation settles")], timeout: 1.2)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
