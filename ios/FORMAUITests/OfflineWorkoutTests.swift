import XCTest

final class OfflineWorkoutTests: XCTestCase {
  @MainActor
  private func launchFreshWorkspace() -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-workspace"]
    app.launch()
    return app
  }

  @MainActor
  func testFreshWorkspaceHasNoInventedProgress() {
    let app = launchFreshWorkspace()
    let progress = app.tabBars.buttons["Progress"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    progress.tap()
    let empty = app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch
    XCTAssertTrue(empty.waitForExistence(timeout: 5))
  }

  @MainActor
  func testCompletedSetSurvivesProcessTerminationAndFinishesOnce() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()

    let set = app.buttons["complete-set-0-0"]
    XCTAssertTrue(set.waitForExistence(timeout: 5))
    set.tap()
    // Completion is observable only after the local transaction commits.
    XCTAssertTrue(set.waitForValue("Completed", timeout: 5))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    XCTAssertTrue(start.label.contains("Resume workout"))
    start.tap()
    XCTAssertTrue(set.waitForExistence(timeout: 5))
    XCTAssertEqual(set.value as? String, "Completed")

    let finish = app.buttons["finish-workout"]
    XCTAssertTrue(finish.waitForExistence(timeout: 5))
    finish.tap()
    let confirm = app.alerts.buttons["Finish workout"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.tap()
    let done = app.buttons["receipt-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    done.tap()

    app.tabBars.buttons["Progress"].tap()
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "progress-empty").firstMatch.exists)
    let journal = app.staticTexts.matching(
      NSPredicate(format: "label == %@", "Upper body strength"))
    XCTAssertTrue(journal.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(journal.count, 1)
    // The same finished workout cannot be resumed and submitted again.
    app.tabBars.buttons["Today"].tap()
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    XCTAssertTrue(start.label.contains("Start workout"))
    XCTAssertFalse(start.label.contains("Resume workout"))
  }

  @MainActor
  func testUnfinishedWorkoutSurvivesProcessTermination() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    XCTAssertTrue(app.buttons["complete-set-0-0"].waitForExistence(timeout: 5))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    XCTAssertTrue(start.label.contains("Resume workout"))
    start.tap()
    XCTAssertTrue(app.buttons["complete-set-0-0"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["complete-set-0-0"].value as? String, "Not completed")
  }

  @MainActor
  func testResumeAccessoryPreservesTheSelectedTabAndRoutineDetails() {
    let app = launchFreshWorkspace()
    let plan = app.tabBars.buttons["Plan"]
    XCTAssertTrue(plan.waitForExistence(timeout: 5))
    plan.tap()
    app.staticTexts["Upper body strength"].firstMatch.tap()
    let start = app.buttons["start-routine-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    let close = app.buttons["Save & close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    close.tap()
    XCTAssertTrue(plan.isSelected)
    XCTAssertTrue(app.buttons["edit-routine"].waitForExistence(timeout: 5))
    let resume = app.buttons["resume-workout-accessory"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    close.tap()
    XCTAssertTrue(plan.isSelected)
    XCTAssertTrue(app.buttons["edit-routine"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testDecimalEntryCommitsAndRestPauseSurvivesReopening() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    let previous = weight.value as? String ?? ""
    weight.typeText(
      String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + "42.5")
    let complete = app.buttons["complete-set-0-0"]
    complete.tap()
    XCTAssertTrue(complete.waitForValue("Completed", timeout: 5))
    let pause = app.buttons["rest-toggle"]
    XCTAssertTrue(pause.waitForExistence(timeout: 5))
    pause.tap()
    XCTAssertTrue(pause.waitForLabel("Resume rest", timeout: 5))
    app.buttons["Save & close"].tap()
    app.buttons["resume-workout-accessory"].tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "42.5")
    XCTAssertTrue(pause.waitForLabel("Resume rest", timeout: 5))
  }

  @MainActor
  func testInvalidDraftCannotCloseOrFinishAndCanBeCorrected() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    let weight = app.textFields["set-value-0-0-weight"]
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    weight.tap()
    let previous = weight.value as? String ?? ""
    weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))

    app.buttons["Save & close"].tap()
    let validation = app.descendants(matching: .any).matching(identifier: "workout-validation")
      .firstMatch
    XCTAssertTrue(validation.waitForExistence(timeout: 5))
    XCTAssertTrue(weight.exists)
    XCTAssertTrue(app.buttons["Save & close"].exists)

    app.buttons["finish-workout"].tap()
    let confirm = app.alerts.buttons["Finish workout"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 5))
    confirm.tap()
    XCTAssertTrue(validation.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["receipt-done"].exists)
    XCTAssertTrue(weight.exists)

    weight.tap()
    weight.typeText("42.5")
    app.buttons["Save & close"].tap()
    let resume = app.buttons["resume-workout-accessory"]
    XCTAssertTrue(resume.waitForExistence(timeout: 5))
    resume.tap()
    XCTAssertTrue(weight.waitForExistence(timeout: 5))
    XCTAssertEqual(weight.value as? String, "42.5")
    XCTAssertEqual(app.buttons["complete-set-0-0"].value as? String, "Not completed")
  }

  @MainActor
  func testSessionNotesPersistAndDiscardKeepsAcknowledgedText() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    let openNotes = app.buttons["session-notes"]
    XCTAssertTrue(openNotes.waitForExistence(timeout: 5))
    for _ in 0..<4 where !openNotes.isHittable { app.swipeUp() }
    XCTAssertTrue(openNotes.isHittable)
    openNotes.tap()
    let editor = app.textViews["session-notes-editor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    editor.tap()
    editor.typeText("Steady today. Keep this note.")
    app.buttons["session-notes-save"].tap()
    XCTAssertTrue(editor.waitForDisappearance(timeout: 5))
    XCTAssertTrue(openNotes.waitForExistence(timeout: 5))
    openNotes.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    XCTAssertEqual(editor.value as? String, "Steady today. Keep this note.")
    editor.tap()
    editor.typeText(" Unsaved addition.")
    app.buttons["Cancel"].tap()
    let discard = app.buttons["Discard changes"]
    XCTAssertTrue(discard.waitForExistence(timeout: 5))
    discard.tap()
    XCTAssertTrue(editor.waitForDisappearance(timeout: 5))
    XCTAssertTrue(openNotes.waitForExistence(timeout: 5))
    openNotes.tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 5))
    XCTAssertEqual(editor.value as? String, "Steady today. Keep this note.")
  }

  @MainActor
  func testDeletingLocalTrainingClearsAnAlreadyOpenHistoryDetail() {
    let app = launchFreshWorkspace()
    let start = app.buttons["start-workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    start.tap()
    let complete = app.buttons["complete-set-0-0"]
    XCTAssertTrue(complete.waitForExistence(timeout: 5))
    complete.tap()
    XCTAssertTrue(complete.waitForValue("Completed", timeout: 5))
    app.buttons["finish-workout"].tap()
    let confirmFinish = app.alerts.buttons["Finish workout"]
    XCTAssertTrue(confirmFinish.waitForExistence(timeout: 5))
    confirmFinish.tap()
    let done = app.buttons["receipt-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    done.tap()
    app.tabBars.buttons["Progress"].tap()
    let journal = app.staticTexts["Upper body strength"].firstMatch
    XCTAssertTrue(journal.waitForExistence(timeout: 5))
    journal.tap()
    XCTAssertTrue(app.navigationBars["Workout details"].waitForExistence(timeout: 5))

    app.tabBars.buttons["You"].tap()
    let delete = app.buttons["Delete training data on this iPhone"]
    XCTAssertTrue(delete.waitForExistence(timeout: 5))
    for _ in 0..<6 where !delete.isHittable { app.swipeUp() }
    XCTAssertTrue(delete.isHittable)
    delete.tap()
    let confirmDelete = app.alerts.buttons["Delete training data"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
    confirmDelete.tap()
    XCTAssertTrue(confirmDelete.waitForDisappearance(timeout: 5))
    app.tabBars.buttons["Progress"].tap()
    // SwiftUI may retain this destination or return to the journal when its
    // source link disappears. Both must show the acknowledged deletion.
    let cleared = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier IN %@", ["removed-workout-detail", "progress-empty"])
    ).firstMatch
    XCTAssertTrue(cleared.waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Upper body strength"].exists)
    XCTAssertFalse(
      app.descendants(matching: .any).matching(identifier: "local-save-status").firstMatch.exists)
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
  fileprivate func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "value == %@", expected)
    return XCTWaiter.wait(
      for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
      timeout: timeout
    ) == .completed
  }
}
