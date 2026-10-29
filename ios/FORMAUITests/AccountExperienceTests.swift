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
    app.revealTrainingControl(app.buttons["account-sign-in"])
    XCTAssertTrue(app.buttons["account-sign-in"].waitForExistence(timeout: 15))
    app.revealTrainingControl(app.buttons["account-create"])
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
    app.revealTrainingControl(signIn)
    XCTAssertTrue(signIn.waitForExistence(timeout: 15))
    signIn.tap()

    let email = app.textFields["account-email"]
    app.scrollUntilExists(email)
    XCTAssertTrue(email.waitForExistence(timeout: 10))
    let password = app.secureTextFields["account-password"]
    app.scrollUntilExists(password)
    XCTAssertTrue(password.exists)
    let submit = app.buttons["account-submit"]
    app.scrollUntilExists(submit)
    XCTAssertTrue(submit.exists)
    XCTAssertFalse(submit.isEnabled, "nothing typed yet")
    // The dimmed button says what it is waiting for.
    XCTAssertTrue(
      app.descendants(matching: .any)["account-submit-reason"].waitForExistence(timeout: 5))

    app.scrollUntilExists(email, direction: .down)
    email.tap()
    email.typeText("not-an-address")
    app.scrollUntilExists(submit)
    XCTAssertFalse(submit.isEnabled, "an address needs an @ and a dot")
    app.scrollUntilExists(email, direction: .down)
    email.clearAndType("member@example.test")
    app.scrollUntilExists(password)
    password.tap()
    password.typeText("x")
    app.scrollUntilExists(submit)
    XCTAssertTrue(submit.isEnabled)

    app.scrollUntilExists(app.buttons["account-forgot"])
    XCTAssertTrue(app.buttons["account-forgot"].exists)
    app.buttons["account-cancel"].tap()
    XCTAssertTrue(app.buttons["account-sign-in"].waitForExistence(timeout: 10))
  }

  @MainActor
  func testCreateAccountNeedsTwoConsentsAndAFifteenCharacterPassword() {
    prepareManualPasswordEntry()
    let app = launchFreshWorkspace()
    openYou(app)
    let create = app.buttons["account-create"]
    app.revealTrainingControl(create)
    XCTAssertTrue(create.waitForExistence(timeout: 15))
    create.tap()

    let name = app.textFields["account-name"]
    app.scrollUntilExists(name)
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.tap()
    name.typeText("Nova")
    let email = app.textFields["account-email"]
    app.scrollUntilExists(email)
    email.tap()
    email.typeText("nova@example.test")
    let password = app.secureTextFields["account-password"]
    app.scrollUntilExists(password)
    password.tap()
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
    // The native toggle AX bridge reports 1/0 on some runtimes and On/Off on others.
    XCTAssertTrue(["1", "On"].contains(terms.value as? String ?? ""))
    app.scrollUntilExists(data)
    data.tap()
    XCTAssertTrue(["1", "On"].contains(data.value as? String ?? ""))
    app.scrollUntilExists(submit)
    XCTAssertFalse(submit.isEnabled, "the password is still too short")

    app.scrollUntilExists(password, direction: .down)
    password.tap()
    password.typeText(" but now long enough")
    app.scrollUntilExists(submit)
    XCTAssertTrue(submit.isEnabled)

    // Untick one consent again: the button follows.
    app.scrollUntilExists(terms, direction: .down)
    terms.tap()
    XCTAssertTrue(["0", "Off"].contains(terms.value as? String ?? ""))
    app.scrollUntilExists(submit)
    XCTAssertFalse(submit.isEnabled)
  }

  /// Negative password fixtures require manual entry, not a generated password.
  /// Change only the isolated simulator's documented setting; the app retains
  /// `.newPassword` and production AutoFill support without a test-only code path.
  @MainActor
  private func prepareManualPasswordEntry() {
    continueAfterFailure = false
    #if targetEnvironment(simulator)
      let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
      settings.launch()
      settings.prepareReviewViewport()
      let suggestions = settings.switches["SuggestStrongPasswordsToggle"]
      let autoFill = settings.switches.matching(
        NSPredicate(
          format: "identifier == %@ OR label BEGINSWITH[c] %@",
          "AutoFillToggle", "AutoFill Passwords")
      ).firstMatch
      if !suggestions.exists && !autoFill.exists {
        let modern = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 18
        let path =
          modern ? ["General", "AutoFill & Passwords"] : ["Passwords", "Password Options"]
        for title in path {
          let identifier =
            title == "General"
            ? "com.apple.settings.general"
            : title == "AutoFill & Passwords"
              ? "com.apple.settings.general.autoFillAndPasswords"
              : title
          // iOS 26 Settings also exposes elements with the row's title or
          // identifier that have no hit point (the "AUTOFILL" heading, a
          // container cell), and asking one whether it is hittable fails the
          // test. So never ask: take a match with a real on-screen frame,
          // buttons before cells, and tap its centre. The heading carries the
          // row's identifier, so a cell must also match the row's exact title.
          let matches = settings.descendants(matching: .any).matching(
            NSPredicate(
              format: "(elementType == %lu AND (identifier == %@ OR label ==[c] %@))"
                + " OR (elementType == %lu AND label ==[c] %@)",
              XCUIElement.ElementType.button.rawValue, identifier, title,
              XCUIElement.ElementType.cell.rawValue, title))
          let screen = settings.windows.firstMatch.frame
          func visibleRow() -> XCUIElement? {
            let rows = matches.allElementsBoundByIndex.filter { element in
              let frame = element.frame
              return frame.height >= 30 && frame.width >= 100
                && screen.contains(CGPoint(x: frame.midX, y: frame.midY))
            }
            return rows.first { $0.elementType == .button } ?? rows.first
          }
          for _ in 0..<12 where visibleRow() == nil { settings.swipeUp() }
          let row = visibleRow()
          XCTAssertNotNil(row, "Settings must expose \(title)")
          guard let row else { return }
          row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
      }
      // Newer systems expose just the suggestion toggle. Older systems use
      // the parent AutoFill control; both are simulator-only fixture choices.
      let control = suggestions.exists ? suggestions : autoFill
      XCTAssertTrue(control.waitForExistence(timeout: 10))
      if control.value as? String == "1" {
        // The AX switch includes its label; its trailing thumb is the hit target.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      }
      let disabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "value == %@", "0"), object: control)
      XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 5), .completed)
      settings.terminate()
    #else
      XCTFail("This manual-entry fixture changes only an isolated simulator's settings.")
    #endif
  }
}

extension XCUIApplication {
  fileprivate func scrollUntilExists(_ element: XCUIElement, direction: Direction = .up) {
    for _ in 0..<12 {
      let list = collectionViews["account-credentials-form"]
      XCTAssertTrue(list.exists)
      let frame = list.frame
      let keyboard = keyboards.firstMatch
      let top = frame.minY + 80
      let bottom = keyboard.exists ? min(frame.maxY, keyboard.frame.minY) : frame.maxY
      // A partially visible checkbox can be hittable while its center is
      // covered by the sheet toolbar. Reveal its full row before tapping.
      if element.exists && element.isHittable
        && element.frame.minY >= top && element.frame.maxY <= bottom - 8
      {
        return
      }
      let distance = min(180, max(40, (bottom - top) * 0.6))
      var upward = direction == .up
      if element.exists {
        if element.frame.maxY > bottom - 8 { upward = true }
        if element.frame.minY < top { upward = false }
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
    XCTFail("The requested form control must fit in the visible form above the keyboard")
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
