import XCTest

/// The account screens as a signed-out member meets them. Nothing here signs in
/// or reaches any server: the forms are exercised up to, never including, submit.
final class AccountExperienceTests: XCTestCase {
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
  private func openYou(_ app: XCUIApplication) {
    let you = app.trainingTab("You")
    XCTAssertTrue(you.waitForExistence(timeout: 20))
    you.tap()
  }

  @MainActor
  func testSignedOutYouOffersSignInAndCreateAccountAndKeepsGuestUseIntact() {
    let app = launchFreshWorkspace()
    openYou(app)
    XCTAssertTrue(app.buttons["account-sign-in"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.buttons["account-create"].exists)
    // Guest deletion stays available while signed out.
    let deletion = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Delete training data")
    ).firstMatch
    app.revealTrainingControl(deletion)
    XCTAssertTrue(deletion.waitForExistence(timeout: 10))
    XCTAssertTrue(deletion.isHittable)

  }

  @MainActor
  func testSignInSubmitWaitsForAnEmailAndAPassword() {
    let app = launchFreshWorkspace()
    openYou(app)
    let signIn = app.buttons["account-sign-in"]
    XCTAssertTrue(signIn.waitForExistence(timeout: 15))
    signIn.tap()

    let email = app.textFields["account-email"]
    XCTAssertTrue(email.waitForExistence(timeout: 10))
    let password = app.secureTextFields["account-password"]
    XCTAssertTrue(password.exists)
    let submit = app.buttons["account-submit"]
    XCTAssertTrue(submit.exists)
    XCTAssertFalse(submit.isEnabled, "nothing typed yet")

    email.tap()
    email.typeText("not-an-address")
    XCTAssertFalse(submit.isEnabled, "an address needs an @ and a dot")
    email.clearAndType("member@example.test")
    password.tap()
    password.typeText("x")
    XCTAssertTrue(submit.isEnabled)

    XCTAssertTrue(app.buttons["account-forgot"].exists)
    app.buttons["account-cancel"].tap()
    XCTAssertTrue(app.buttons["account-sign-in"].waitForExistence(timeout: 10))
  }

  @MainActor
  func testCreateAccountNeedsTwoConsentsAndAFifteenCharacterPassword() {
    let app = launchFreshWorkspace()
    openYou(app)
    let create = app.buttons["account-create"]
    XCTAssertTrue(create.waitForExistence(timeout: 15))
    create.tap()

    let name = app.textFields["account-name"]
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.tap()
    name.typeText("Nova")
    let email = app.textFields["account-email"]
    email.tap()
    email.typeText("nova@example.test")
    let password = app.secureTextFields["account-password"]
    password.tap()
    app.dismissStrongPasswordSuggestion()
    password.typeText("short")
    let submit = app.buttons["account-submit"]
    // The form is a lazy list: the consents and the button are below the fold.
    app.scrollUntilExists(submit)
    XCTAssertFalse(submit.isEnabled)

    let terms = app.descendants(matching: .any)["account-consent-terms"]
    let data = app.descendants(matching: .any)["account-consent-data"]
    // We just scrolled to Submit; the consent rows are above it.
    app.scrollUntilExists(terms, direction: .down)
    terms.tap()
    app.scrollUntilExists(data)
    data.tap()
    XCTAssertFalse(submit.isEnabled, "the password is still too short")

    app.scrollUntilExists(password, direction: .down)
    password.tap()
    app.dismissStrongPasswordSuggestion()
    password.typeText(" but now long enough")
    app.scrollUntilExists(submit)
    XCTAssertTrue(submit.isEnabled)

    // Untick one consent again: the button follows.
    app.scrollUntilExists(terms, direction: .down)
    terms.tap()
    app.scrollUntilExists(submit)
    XCTAssertFalse(submit.isEnabled)
  }
}

extension XCUIApplication {
  fileprivate func dismissStrongPasswordSuggestion() {
    // iOS can cover the keyboard with its new-password suggestion. Closing
    // that system UI lets this test enter its intentionally short fixture.
    if buttons["GenerateStrongPasswordButton"].waitForExistence(timeout: 2) {
      buttons["xmark"].firstMatch.tap()
    }
  }

  fileprivate func scrollUntilExists(_ element: XCUIElement, direction: Direction = .up) {
    for _ in 0..<12 {
      if element.exists && element.isHittable { return }
      let list = collectionViews["account-credentials-form"]
      XCTAssertTrue(list.exists)
      let frame = list.frame
      let keyboard = keyboards.firstMatch
      let top = frame.minY + 80
      let bottom = keyboard.exists ? min(frame.maxY, keyboard.frame.minY) : frame.maxY
      let distance = min(180, max(40, (bottom - top) * 0.6))
      var upward = direction == .up
      if element.exists {
        if element.frame.midY > bottom - 12 { upward = true }
        if element.frame.midY < top + 12 { upward = false }
      }
      // Keep the entire pan above the keyboard. A slow, short drag avoids
      // flinging past a tall consent row and then searching in the wrong direction.
      let anchor = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
      let upper = anchor.withOffset(CGVector(dx: 0, dy: top - frame.minY + 12))
      let lower = upper.withOffset(CGVector(dx: 0, dy: distance))
      (upward ? lower : upper).press(
        forDuration: 0.05, thenDragTo: upward ? upper : lower,
        withVelocity: .slow, thenHoldForDuration: 0.05)
    }
    XCTAssertTrue(
      element.exists && element.isHittable, "The requested form control must be visible")
  }
  fileprivate enum Direction { case up, down }
}

extension XCUIElement {
  fileprivate func clearAndType(_ text: String) {
    tap()
    if let current = value as? String, !current.isEmpty {
      typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
    typeText(text)
  }
}
