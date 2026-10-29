import Foundation
import XCTest

/// Geometry checks use the installed device's viewport, not a pretend size.
/// Run the portrait case on the smallest supported available simulator as well.
final class TodayLayoutAndWidgetRoutingTests: XCTestCase {
  @MainActor
  private func launch(textSize: String? = nil) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-workspace", "-UIPreferredContentSizeCategoryName",
      textSize ?? "UICTContentSizeCategoryL",
    ]
    app.launch()
    app.prepareReviewViewport()
    return app
  }

  @MainActor
  private func requireStartAboveNavigation(_ app: XCUIApplication, screenshot: String) {
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 20))
    XCTAssertTrue(start.isHittable, "Start must be available without scrolling")
    XCTAssertGreaterThanOrEqual(start.frame.minY, app.frame.minY)
    let tabs = app.descendants(matching: .any).matching(identifier: "training-tab-bar").firstMatch
    XCTAssertTrue(tabs.exists)
    XCTAssertLessThanOrEqual(
      start.frame.maxY, tabs.frame.minY + 1,
      "The entire Start target must fit above the app navigation controls")
    XCTAssertGreaterThanOrEqual(start.frame.height, 44)
    // The Simulator's screenshot surface can lag the accessibility viewport on rotation.
    _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settled capture")], timeout: 1.2)
    let image = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: image)
    attachment.name = screenshot
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertEqual(
      image.image.size.width > image.image.size.height, app.frame.width > app.frame.height,
      "The exported evidence must match the tested orientation")
  }

  @MainActor
  func testTodayStartVisibleAtLargestAccessibilityTextSize() {
    let app = launch(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
    requireStartAboveNavigation(app, screenshot: "16-today-largest-accessibility-text")
  }

  @MainActor
  func testTodayStartVisibleAtCompactLandscapeHeight() {
    let app = launch()
    defer { app.prepareReviewViewport() }
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
    XCUIDevice.shared.orientation = .landscapeLeft
    let landscape = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
    XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
    XCTAssertGreaterThan(app.frame.width, app.frame.height)
    requireStartAboveNavigation(app, screenshot: "17-today-compact-landscape")
  }

  @MainActor
  func testWidgetLinksOpenTheRequestedTabAfterColdLaunch() {
    let app = launch()
    XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
    // XCUIApplication.open(URL) is available from iOS 16.4; the app floor is 17.
    // Only local custom-scheme URLs are used, never a network service.
    app.terminate()
    app.launchArguments = [
      "--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
    ]
    app.open(URL(string: "forma://widget/progress")!)
    app.prepareReviewViewport()
    XCTAssertTrue(app.buttons["tab-progress"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.buttons["tab-progress"].isSelected)
    XCTAssertTrue(app.navigationBars["Progress"].exists)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "progress-empty")
        .firstMatch.waitForExistence(timeout: 10))

    app.terminate()
    app.open(URL(string: "forma://widget/plan")!)
    app.prepareReviewViewport()
    XCTAssertTrue(app.buttons["tab-plan"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.buttons["tab-plan"].isSelected)
    XCTAssertTrue(app.navigationBars["Plan"].exists)
    let library = app.staticTexts["Exercise library"].firstMatch
    XCTAssertTrue(library.waitForExistence(timeout: 10))
  }

  @MainActor
  private func openQueuedWidgetLink(_ path: String, in app: XCUIApplication) {
    // System URL delivery preserves the running process and its unsaved text.
    // XCUIApplication.open is a launch API, appropriate only for the cold test.
    app.launchArguments = [
      "--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
    ]
    XCUIDevice.shared.system.open(URL(string: "forma://widget/\(path)")!)
    app.prepareReviewViewport()
    let banner = app.descendants(matching: .any).matching(identifier: "widget-link-queued")
      .firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 10))
  }

  @MainActor
  private func closeWorkout(_ app: XCUIApplication) {
    let close = app.buttons["Save & close"]
    if !close.exists || !close.isHittable {
      app.buttons["workout-actions"].tap()
    }
    XCTAssertTrue(close.waitForExistence(timeout: 10))
    close.tap()
  }

  @MainActor
  private func requireSelectedTab(_ name: String, in app: XCUIApplication) {
    let tab = app.buttons["tab-\(name.lowercased())"]
    print("QUEUED_WIDGET_DESTINATION_STATE\n\(app.debugDescription)")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "queued-widget-destination-state"
    attachment.lifetime = .keepAlways
    add(attachment)
    let selected = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "selected == true"), object: tab)
    XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
    XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10))
  }

  @MainActor
  func testQueuedWidgetLinkPreservesInvalidWorkoutDraftUntilExplicitSaveAndClose() {
    let app = launch()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 20))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 10))
    let savedValue = weight.value as? String
    weight.replaceQueuedDraft(with: "")
    let invalidValue = weight.value as? String
    XCTAssertNotEqual(invalidValue, savedValue)
    closeWorkout(app)
    let validation = app.descendants(matching: .any).matching(identifier: "workout-validation")
      .firstMatch
    XCTAssertTrue(validation.waitForExistence(timeout: 10))

    openQueuedWidgetLink("progress", in: app)
    XCTAssertTrue(app.navigationBars["Training"].exists)
    XCTAssertTrue(weight.exists)
    XCTAssertEqual(weight.value as? String, invalidValue)
    XCTAssertTrue(validation.exists)
    weight.replaceQueuedDraft(with: "42.5")
    closeWorkout(app)
    requireSelectedTab("Progress", in: app)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch.exists)

    // The queued link changed navigation, without completing or losing the set.
    let resume = app.buttons["resume-workout-accessory"]
    XCTAssertTrue(resume.waitForExistence(timeout: 10))
    resume.tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 10))
    XCTAssertEqual(weight.value as? String, "42.5")
    XCTAssertEqual(app.buttons["complete-set-0-0"].value as? String, "Not completed")
  }

  @MainActor
  func testQueuedWidgetLinkKeepsProfileDraftUntilProfileSave() {
    let app = launch()
    let you = app.trainingTab("You")
    XCTAssertTrue(you.waitForExistence(timeout: 20))
    you.tap()
    let profile = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Profile & weekly goal")
    ).firstMatch
    app.revealTrainingControl(profile)
    XCTAssertTrue(profile.exists && profile.isHittable)
    profile.tap()
    let name = app.textFields["profile-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.replaceQueuedDraft(with: "Queued profile draft")
    openQueuedWidgetLink("plan", in: app)
    XCTAssertTrue(app.navigationBars["Your profile"].exists)
    XCTAssertEqual(name.value as? String, "Queued profile draft")
    let save = app.buttons["save-profile"]
    XCTAssertTrue(save.isEnabled)
    save.tap()
    requireSelectedTab("Plan", in: app)
    app.trainingTab("You").tap()
    let savedName = app.staticTexts["Queued profile draft"]
    app.revealTrainingControl(savedName, direction: .down)
    XCTAssertTrue(savedName.waitForExistence(timeout: 10))
  }

  @MainActor
  func testQueuedWidgetLinkKeepsRoutineDraftUntilExplicitDiscard() {
    let app = launch()
    let plan = app.trainingTab("Plan")
    XCTAssertTrue(plan.waitForExistence(timeout: 20))
    plan.tap()
    let create = app.buttons["create-routine"]
    app.revealTrainingControl(create)
    XCTAssertTrue(create.exists && create.isHittable)
    create.tap()
    let name = app.textFields["routine-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.replaceQueuedDraft(with: "Unsaved routine draft")
    openQueuedWidgetLink("progress", in: app)
    XCTAssertTrue(app.navigationBars["New routine"].exists)
    XCTAssertEqual(name.value as? String, "Unsaved routine draft")
    XCTAssertFalse(app.buttons["save-routine"].isEnabled, "A new routine still needs an exercise")
    app.buttons["Cancel"].tap()
    let discard = app.buttons["Discard changes"]
    XCTAssertTrue(discard.waitForExistence(timeout: 10))
    discard.tap()
    requireSelectedTab("Progress", in: app)
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch.exists)
  }
}

extension XCUIElement {
  @MainActor
  fileprivate func replaceQueuedDraft(with text: String) {
    tap()
    if let current = value as? String, !current.isEmpty, current != placeholderValue {
      doubleTap()
      typeText(XCUIKeyboardKey.delete.rawValue)
    }
    if let left = value as? String, !left.isEmpty, left != placeholderValue {
      typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: left.count + 2))
    }
    if !text.isEmpty { typeText(text) }
  }
}
