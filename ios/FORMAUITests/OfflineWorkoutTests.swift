import XCTest

final class OfflineWorkoutTests: XCTestCase {
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

  @MainActor
  func testFreshWorkspaceHasNoInventedProgress() {
    let app = launchFreshWorkspace()
    let progress = app.trainingTab("Progress")
    XCTAssertTrue(progress.waitForExistence(timeout: 15))
    progress.tap()
    let empty = app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch
    XCTAssertTrue(empty.waitForExistence(timeout: 15))
  }

  @MainActor
  func testCompletedSetSurvivesProcessTerminationAndFinishesOnce() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()

    let set = app.buttons["complete-set-0-0"]
    XCTAssertTrue(set.waitForExistence(timeout: 15))
    set.tap()
    // Completion is observable only after the local transaction commits.
    XCTAssertTrue(set.waitForValue("Completed", timeout: 15))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.prepareReviewViewport()
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    XCTAssertTrue(start.label.contains("Resume workout"))
    start.tap()
    XCTAssertTrue(set.waitForExistence(timeout: 15))
    XCTAssertEqual(set.value as? String, "Completed")

    let finish = app.buttons["finish-workout"]
    XCTAssertTrue(finish.waitForExistence(timeout: 15))
    finish.tap()
    let confirm = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 15))
    confirm.tap()
    let done = app.buttons["receipt-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 15))
    done.tap()

    app.trainingTab("Progress").tap()
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch.exists)
    let journal = app.staticTexts.matching(
      NSPredicate(format: "label == %@", "Upper body strength"))
    XCTAssertTrue(journal.firstMatch.waitForExistence(timeout: 15))
    XCTAssertEqual(journal.count, 1)
    // The same finished workout cannot be resumed and submitted again.
    app.trainingTab("Today").tap()
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    XCTAssertTrue(start.label.contains("Start workout"))
    XCTAssertFalse(start.label.contains("Resume workout"))
  }

  @MainActor
  func testUnfinishedWorkoutSurvivesProcessTermination() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    XCTAssertTrue(app.buttons["complete-set-0-0"].waitForExistence(timeout: 15))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.prepareReviewViewport()
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    XCTAssertTrue(start.label.contains("Resume workout"))
    start.tap()
    XCTAssertTrue(app.buttons["complete-set-0-0"].waitForExistence(timeout: 15))
    XCTAssertEqual(app.buttons["complete-set-0-0"].value as? String, "Not completed")
  }

  @MainActor
  func testResumeAccessoryPreservesTheSelectedTabAndRoutineDetails() {
    let app = launchFreshWorkspace()
    let plan = app.trainingTab("Plan")
    XCTAssertTrue(plan.waitForExistence(timeout: 15))
    plan.tap()
    app.staticTexts["Upper body strength"].firstMatch.tap()
    let start = app.buttons["start-routine-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let close = app.buttons["Save & close"]
    XCTAssertTrue(close.waitForExistence(timeout: 15))
    close.tap()
    XCTAssertTrue(plan.isSelected)
    XCTAssertTrue(app.revealInList(app.buttons["edit-routine"]))
    let resume = app.buttons["resume-workout-accessory"]
    XCTAssertTrue(resume.waitForExistence(timeout: 15))
    resume.tap()
    XCTAssertTrue(close.waitForExistence(timeout: 15))
    close.tap()
    XCTAssertTrue(plan.isSelected)
    XCTAssertTrue(app.revealInList(app.buttons["edit-routine"]))
  }

  @MainActor
  func testDecimalEntryCommitsAndRestPauseSurvivesReopening() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 15))
    weight.replaceText(with: "42.5")
    let complete = app.buttons["complete-set-0-0"]
    complete.tap()
    XCTAssertTrue(complete.waitForValue("Completed", timeout: 15))
    let pause = app.buttons["rest-toggle"]
    XCTAssertTrue(pause.waitForExistence(timeout: 15))
    pause.tap()
    XCTAssertTrue(pause.waitForLabel("Resume rest", timeout: 15))
    app.buttons["Save & close"].tap()
    app.buttons["resume-workout-accessory"].tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 15))
    XCTAssertEqual(weight.value as? String, "42.5")
    XCTAssertTrue(pause.waitForLabel("Resume rest", timeout: 15))
  }

  @MainActor
  func testInvalidDraftCannotCloseOrFinishAndCanBeCorrected() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 15))
    weight.replaceText(with: "")

    app.buttons["Save & close"].tap()
    let validation = app.descendants(matching: .any).matching(identifier: "workout-validation")
      .firstMatch
    XCTAssertTrue(validation.waitForExistence(timeout: 15))
    XCTAssertTrue(weight.exists)
    XCTAssertTrue(app.buttons["Save & close"].exists)

    app.buttons["finish-workout"].tap()
    let confirm = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 15))
    confirm.tap()
    XCTAssertTrue(validation.waitForExistence(timeout: 15))
    XCTAssertFalse(app.buttons["receipt-done"].exists)
    XCTAssertTrue(weight.exists)

    weight.tap()
    weight.typeText("42.5")
    app.buttons["Save & close"].tap()
    let resume = app.buttons["resume-workout-accessory"]
    XCTAssertTrue(resume.waitForExistence(timeout: 15))
    resume.tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 15))
    XCTAssertEqual(weight.value as? String, "42.5")
    XCTAssertEqual(app.buttons["complete-set-0-0"].value as? String, "Not completed")
  }

  @MainActor
  func testSessionNotesPersistAndDiscardKeepsAcknowledgedText() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let openNotes = app.buttons["session-notes"]
    XCTAssertTrue(openNotes.waitForExistence(timeout: 15))
    for _ in 0..<4 where !openNotes.isHittable { app.swipeUp() }
    XCTAssertTrue(openNotes.isHittable)
    openNotes.tap()
    let editor = app.textViews["session-notes-editor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 15))
    editor.tap()
    editor.typeText("Steady today. Keep this note.")
    app.buttons["session-notes-save"].tap()
    XCTAssertTrue(editor.waitForDisappearance(timeout: 15))
    XCTAssertTrue(openNotes.waitForExistence(timeout: 15))
    openNotes.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 15))
    XCTAssertEqual(editor.value as? String, "Steady today. Keep this note.")
    editor.tap()
    editor.typeText(" Unsaved addition.")
    app.buttons["Cancel"].tap()
    let discard = app.buttons["Discard changes"]
    XCTAssertTrue(discard.waitForExistence(timeout: 15))
    discard.tap()
    XCTAssertTrue(editor.waitForDisappearance(timeout: 15))
    XCTAssertTrue(openNotes.waitForExistence(timeout: 15))
    openNotes.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 15))
    XCTAssertEqual(editor.value as? String, "Steady today. Keep this note.")
  }

  @MainActor
  func testDeletingLocalTrainingClearsAnAlreadyOpenHistoryDetail() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 15))
    start.tap()
    let complete = app.buttons["complete-set-0-0"]
    XCTAssertTrue(complete.waitForExistence(timeout: 15))
    complete.tap()
    XCTAssertTrue(complete.waitForValue("Completed", timeout: 15))
    app.buttons["finish-workout"].tap()
    let confirmFinish = app.alerts.buttons["finish-confirm"].firstMatch
    XCTAssertTrue(confirmFinish.waitForExistence(timeout: 15))
    confirmFinish.tap()
    let done = app.buttons["receipt-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 15))
    done.tap()
    app.trainingTab("Progress").tap()
    let journal = app.staticTexts["Upper body strength"].firstMatch
    XCTAssertTrue(journal.waitForExistence(timeout: 15))
    journal.tap()
    XCTAssertTrue(app.navigationBars["Workout details"].waitForExistence(timeout: 15))

    app.trainingTab("You").tap()
    let delete = app.buttons["Delete training data on this iPhone"]
    // You is a lazy list: rows below the fold are not in the hierarchy until
    // scrolled to, so scroll first and then require the button.
    XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))
    for _ in 0..<6 where !delete.exists || !delete.isHittable { app.swipeUp() }
    XCTAssertTrue(delete.waitForExistence(timeout: 15))
    XCTAssertTrue(delete.isHittable)
    delete.tap()
    let confirmDelete = app.alerts.buttons["Delete training data"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 15))
    confirmDelete.tap()
    XCTAssertTrue(confirmDelete.waitForDisappearance(timeout: 15))
    app.trainingTab("Progress").tap()
    // SwiftUI may retain this destination or return to the journal when its
    // source link disappears. Both must show the acknowledged deletion.
    let cleared = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier IN %@", ["removed-workout-detail", "progress-empty"])
    ).firstMatch
    XCTAssertTrue(cleared.waitForExistence(timeout: 15))
    XCTAssertFalse(app.staticTexts["Upper body strength"].exists)
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "local-save-status").firstMatch.exists)
  }
}

@MainActor
extension XCUIApplication {
  /// Lists are lazy: a row below the fold is not in the hierarchy until it is
  /// scrolled near. Scrolls until `element` exists, then reports whether it does.
  fileprivate func revealInList(_ element: XCUIElement) -> Bool {
    if element.waitForExistence(timeout: 5) { return true }
    for _ in 0..<4 where !element.exists { swipeUp() }
    return element.waitForExistence(timeout: 10)
  }
}

@MainActor
extension XCUIElement {
  fileprivate func waitForDisappearance(timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "exists == false")
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout)
      == .completed
  }
  fileprivate func waitForLabel(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "label == %@", expected)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout)
      == .completed
  }
  /// Replaces a field's text by selecting it rather than sending one delete
  /// per character: synthesized deletes are dropped on some simulator keyboard
  /// layouts, which left "40" + "42.5" as "42.54".
  fileprivate func replaceText(with text: String) {
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
  fileprivate func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
      timeout: timeout
    ) == .completed
  }
}
