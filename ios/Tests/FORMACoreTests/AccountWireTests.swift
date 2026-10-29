import Foundation
import XCTest

@testable import FORMACore

final class AccountCookieTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  func testKeepsOnlyFormaCookiesAndSendsThemBackAsOneHeader() {
    var jar = FormaCookieJar()
    jar.absorb(
      lines: [
        "__Secure-forma.session_token=abc.def%3D; Max-Age=604800; Path=/; HttpOnly; Secure; SameSite=Lax",
        "forma.two_factor=xyz; Max-Age=600; Path=/; HttpOnly",
        "CF_Authorization=nope; Path=/",
        "session=other; Path=/",
        "forma_lookalike=nope",
      ], now: now)
    XCTAssertEqual(
      jar.cookieHeader(now: now),
      "__Secure-forma.session_token=abc.def%3D; forma.two_factor=xyz")
    XCTAssertTrue(jar.contains(suffix: "session_token", now: now))
    XCTAssertTrue(jar.contains(suffix: "two_factor", now: now))
  }

  func testValueIsNeverDecodedAndMayContainEquals() {
    var jar = FormaCookieJar()
    jar.absorb(line: "forma.a=one=two%2Bthree; Path=/", now: now)
    XCTAssertEqual(jar.cookieHeader(now: now), "forma.a=one=two%2Bthree")
  }

  func testSecurePrefixNeedsTheSecureAttribute() {
    var jar = FormaCookieJar()
    jar.absorb(line: "__Secure-forma.session_token=abc; Path=/", now: now)
    XCTAssertTrue(jar.isEmpty)
  }

  func testADeletionNeedsNoSecureAttributeButASetDoes() {
    var jar = FormaCookieJar()
    jar.absorb(line: "__Secure-forma.a=1; Max-Age=600; Secure", now: now)
    jar.absorb(line: "__Secure-forma.a=; Max-Age=0; Path=/", now: now)
    XCTAssertTrue(jar.isEmpty)
  }

  func testMaxAgeZeroEmptyValueAndPastExpiresDeleteTheCookie() {
    var jar = FormaCookieJar()
    let live = [
      "forma.a=1; Max-Age=600", "forma.b=2; Max-Age=600", "forma.c=3; Max-Age=600",
    ]
    jar.absorb(lines: live, now: now)
    jar.absorb(line: "forma.a=; Max-Age=0; Path=/", now: now)
    jar.absorb(line: "forma.b=2; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/", now: now)
    jar.absorb(line: "forma.c=; Path=/", now: now)
    XCTAssertTrue(jar.isEmpty)
    XCTAssertNil(jar.cookieHeader(now: now))
  }

  func testMaxAgeWinsOverExpiresAndCookiesExpireOnTime() {
    var jar = FormaCookieJar()
    // Expires is far in the past, but Max-Age says ten minutes.
    jar.absorb(
      line: "forma.a=1; Max-Age=600; Expires=Thu, 01 Jan 1970 00:00:00 GMT", now: now)
    XCTAssertEqual(jar.cookieHeader(now: now.addingTimeInterval(599)), "forma.a=1")
    XCTAssertNil(jar.cookieHeader(now: now.addingTimeInterval(601)))
    jar.pruneExpired(now: now.addingTimeInterval(601))
    XCTAssertTrue(jar.isEmpty)
  }

  func testAFutureExpiresDateIsHonoured() {
    var jar = FormaCookieJar()
    // 1_800_000_000 is Fri, 15 Jan 2027 08:00:00 GMT.
    jar.absorb(
      line: "forma.a=1; Expires=Fri, 15 Jan 2027 08:00:00 GMT", now: now.addingTimeInterval(-3_600))
    XCTAssertEqual(jar.cookies.first?.expires?.timeIntervalSince1970, 1_800_000_000)
    XCTAssertEqual(jar.cookieHeader(now: now.addingTimeInterval(-1)), "forma.a=1")
    XCTAssertNil(jar.cookieHeader(now: now.addingTimeInterval(1)))
  }

  func testReplacesACookieOfTheSameNameRatherThanDuplicatingIt() {
    var jar = FormaCookieJar()
    jar.absorb(line: "forma.a=1; Max-Age=600", now: now)
    jar.absorb(line: "forma.a=2; Max-Age=600", now: now)
    XCTAssertEqual(jar.cookies.count, 1)
    XCTAssertEqual(jar.cookieHeader(now: now), "forma.a=2")
  }

  func testSplitsAJoinedSetCookieHeaderWithoutBreakingExpires() {
    let combined =
      "__Secure-forma.session_token=abc; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Path=/; HttpOnly, "
      + "__Secure-forma.session_data=def; Max-Age=300; Path=/, forma.two_factor=; Max-Age=0; Path=/"
    let lines = FormaCookieJar.splitCombined(combined)
    XCTAssertEqual(lines.count, 3)
    XCTAssertTrue(lines[0].hasPrefix("__Secure-forma.session_token=abc; Expires=Wed, 21 Oct"))
    XCTAssertTrue(lines[0].hasSuffix("HttpOnly"))
    XCTAssertTrue(lines[1].hasPrefix("__Secure-forma.session_data=def"))
    XCTAssertTrue(lines[2].hasPrefix("forma.two_factor="))
  }

  func testAbsorbsAJoinedHeaderEndToEnd() {
    var jar = FormaCookieJar()
    jar.absorb(
      combinedHeader:
        "__Secure-forma.session_token=abc; Max-Age=604800; Path=/; HttpOnly; Secure, "
        + "forma.two_factor=; Max-Age=0; Path=/",
      now: now)
    XCTAssertEqual(jar.cookieHeader(now: now), "__Secure-forma.session_token=abc")
  }

  func testTheJarSurvivesEncodingForTheKeychain() throws {
    var jar = FormaCookieJar()
    jar.absorb(line: "__Secure-forma.session_token=abc; Max-Age=604800; Secure", now: now)
    let data = try JSONEncoder().encode(jar)
    XCTAssertEqual(try JSONDecoder().decode(FormaCookieJar.self, from: data), jar)
  }

  func testRefusesOversizedAndOddNames() {
    var jar = FormaCookieJar()
    jar.absorb(line: "forma.\(String(repeating: "n", count: 200))=1", now: now)
    jar.absorb(line: "forma.a=\(String(repeating: "v", count: 5_000))", now: now)
    jar.absorb(line: "forma.b c=1", now: now)
    XCTAssertTrue(jar.isEmpty)
  }
}

final class AccountWireTests: XCTestCase {
  private func body(_ request: AccountWire.Request) -> [String: Any]? {
    request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
  }

  private func data(_ text: String) -> Data { Data(text.utf8) }

  func testRequestsMirrorTheWebsite() throws {
    let signUp = AccountWire.signUp(name: "Nova", email: "n@x.test", password: "p")
    XCTAssertEqual(signUp.method, "POST")
    XCTAssertEqual(signUp.path, "/api/auth/sign-up/email")
    XCTAssertEqual(body(signUp)?["name"] as? String, "Nova")
    XCTAssertEqual(Set(body(signUp)?.keys ?? [:].keys), ["name", "email", "password"])

    let signIn = AccountWire.signIn(email: "n@x.test", password: "p")
    XCTAssertEqual(signIn.path, "/api/auth/sign-in/email")
    XCTAssertEqual(body(signIn)?["rememberMe"] as? Bool, true)

    for request in [
      AccountWire.verifyTOTP(code: "123456"), AccountWire.verifyBackupCode(code: "ab"),
    ] {
      XCTAssertEqual(body(request)?["trustDevice"] as? Bool, false)
    }
    XCTAssertEqual(
      AccountWire.verifyBackupCode(code: "ab").path, "/api/auth/two-factor/verify-backup-code")

    let reset = AccountWire.requestPasswordReset(
      email: "n@x.test", redirectTo: "https://forma.test/#account")
    XCTAssertEqual(body(reset)?["redirectTo"] as? String, "https://forma.test/#account")
    XCTAssertNil(body(reset)?["callbackURL"])

    let verify = AccountWire.sendVerificationEmail(
      email: "n@x.test", callbackURL: "https://forma.test")
    XCTAssertEqual(body(verify)?["callbackURL"] as? String, "https://forma.test")

    let change = AccountWire.changePassword(current: "a", new: "b")
    XCTAssertEqual(body(change)?["revokeOtherSessions"] as? Bool, true)
    XCTAssertEqual(body(change)?["currentPassword"] as? String, "a")
    XCTAssertEqual(body(change)?["newPassword"] as? String, "b")

    XCTAssertEqual(AccountWire.deleteAccount(password: "p").path, "/api/auth/delete-user")
    XCTAssertEqual(
      AccountWire.changeEmail(newEmail: "a@b.test", callbackURL: "https://forma.test/#account")
        .path,
      "/api/auth/change-email")
    XCTAssertEqual(body(AccountWire.updateName("Nova"))?["name"] as? String, "Nova")
    XCTAssertEqual(AccountWire.signOut.method, "POST")
  }

  func testStepUpRequestsCarryTheConfirmationOnlyWhenGiven() throws {
    let bare = try AccountWire.revokeSession(id: "abc_-123")
    XCTAssertEqual(bare.method, "DELETE")
    XCTAssertEqual(bare.path, "/api/account/sessions/abc_-123/revoke")
    XCTAssertNil(bare.body)

    let confirmed = try AccountWire.revokeSession(id: "abc", password: "p", code: "123456")
    XCTAssertEqual(body(confirmed)?["password"] as? String, "p")
    XCTAssertEqual(body(confirmed)?["code"] as? String, "123456")
    XCTAssertEqual(
      Set(body(try AccountWire.revokeSession(id: "abc", password: "p"))?.keys ?? [:].keys),
      ["password"])

    XCTAssertEqual(body(AccountWire.revokeOtherSessions())?.count, 0)
    XCTAssertEqual(
      body(AccountWire.revokeOtherSessions(password: "p"))?["password"] as? String, "p")
    XCTAssertEqual(AccountWire.revokeOtherSessions().path, "/api/account/sessions/revoke-others")
  }

  func testIdentifiersThatCouldEscapeAPathAreRefused() {
    for bad in ["", "../x", "a/b", "a%2Fb", "a b", "a?b", String(repeating: "a", count: 129)] {
      XCTAssertThrowsError(try AccountWire.revokeSession(id: bad), bad)
      XCTAssertThrowsError(try AccountWire.revokeCoachToken(id: bad), bad)
    }
  }

  func testCoachTokenRequests() throws {
    XCTAssertEqual(
      body(AccountWire.createCoachToken(label: "Coach", full: false))?["scope"] as? String, "read")
    XCTAssertEqual(
      body(AccountWire.createCoachToken(label: "Coach", full: true))?["scope"] as? String, "full")
    let revoke = try AccountWire.revokeCoachToken(id: "ct_abc123")
    XCTAssertEqual(revoke.method, "DELETE")
    XCTAssertEqual(revoke.path, "/api/account/coach-tokens/ct_abc123")
  }

  func testDecodesTheSessionAndNoSession() throws {
    let profile = try AccountWire.decodeSession(
      data(
        """
        {"session":{"id":"s","createdAt":"2026-10-28T01:02:03.000Z"},
         "user":{"id":"mem_abc","name":"Nova","email":"n@x.test","emailVerified":true,
                 "twoFactorEnabled":true,"createdAt":"2026-10-13T00:00:00.000Z","image":null}}
        """))
    XCTAssertEqual(profile?.id, "mem_abc")
    XCTAssertEqual(profile?.email, "n@x.test")
    XCTAssertEqual(profile?.emailVerified, true)
    XCTAssertEqual(profile?.twoFactorEnabled, true)
    XCTAssertNotNil(profile?.memberSince)
    XCTAssertNil(try AccountWire.decodeSession(data("null")))
    XCTAssertNil(try AccountWire.decodeSession(data("{}")))
    XCTAssertThrowsError(try AccountWire.decodeSession(data("not json")))
    XCTAssertThrowsError(try AccountWire.decodeSession(data("{\"user\":{\"name\":\"x\"}}")))
  }

  func testDecodesTheSignInOutcome() {
    XCTAssertEqual(
      AccountWire.decodeSignIn(
        data("{\"twoFactorRedirect\":true,\"twoFactorMethods\":[\"totp\"]}")),
      .twoFactorRequired)
    XCTAssertEqual(
      AccountWire.decodeSignIn(data("{\"redirect\":false,\"user\":{\"id\":\"mem_a\"}}")), .signedIn)
  }

  func testDecodesDevicesAndCoachTokens() throws {
    let devices = try AccountWire.decodeDevices(
      data(
        """
        [{"id":"r1","createdAt":"2026-10-28T01:00:00.000Z","expiresAt":"2026-11-04T01:00:00.000Z",
          "userAgent":"FORMA/1 CFNetwork/1568","current":true},
         {"id":"r2","createdAt":"2026-10-20T01:00:00.000Z","expiresAt":"2026-10-27T01:00:00.000Z",
          "userAgent":null,"current":false}]
        """))
    XCTAssertEqual(devices.map(\.id), ["r1", "r2"])
    XCTAssertEqual(devices.first?.current, true)
    XCTAssertNil(devices.last?.userAgent)

    let tokens = try AccountWire.decodeCoachTokens(
      data(
        """
        [{"id":"ct_1","label":"Coach","scope":"full","createdAt":"2026-10-01T00:00:00.000Z",
          "expiresAt":"2026-12-30T00:00:00.000Z","lastUsedAt":null}]
        """))
    XCTAssertEqual(tokens.first?.isFullAccess, true)
    XCTAssertNil(tokens.first?.lastUsedAt)

    let issued = try AccountWire.decodeIssuedCoachToken(
      data(
        """
        {"token":"forma_coach_secret","record":{"id":"ct_2","label":"L","scope":"read",
         "createdAt":"2026-10-28T00:00:00.000Z","expiresAt":"2027-01-26T00:00:00.000Z","lastUsedAt":null}}
        """))
    XCTAssertEqual(issued.token, "forma_coach_secret")
    XCTAssertEqual(issued.record.scope, "read")
    XCTAssertThrowsError(try AccountWire.decodeIssuedCoachToken(data("{}")))
  }

  func testDecodesEnrollmentWithTheSetupKey() throws {
    let exampleSetupKey = "EXAMPLE"
    let enrollment = try AccountWire.decodeEnrollment(
      data(
        """
        {"totpURI":"otpauth://totp/FORMA:n%40x.test?secret=\(exampleSetupKey)&issuer=FORMA",
         "backupCodes":["aaaa-bbbb","cccc-dddd"]}
        """))
    XCTAssertEqual(enrollment.secret, exampleSetupKey)
    XCTAssertEqual(enrollment.backupCodes, ["aaaa-bbbb", "cccc-dddd"])
    XCTAssertEqual(
      try AccountWire.decodeBackupCodes(data("{\"status\":true,\"backupCodes\":[\"x\"]}")), ["x"])
  }

  func testErrorsUseTheWebsitesWords() {
    func fail(_ status: Int, _ json: String?, retry: String? = nil, fallback: String = "Fallback.")
      -> AccountFailure
    {
      AccountWire.failure(
        status: status, body: json.map(data), retryAfter: retry, fallback: fallback)
    }
    // A wrong sign-in is rejected, not an ended session.
    let wrong = fail(
      401, "{\"message\":\"Invalid email or password\",\"code\":\"INVALID_EMAIL_OR_PASSWORD\"}")
    XCTAssertEqual(wrong.kind, .rejected)
    XCTAssertEqual(wrong.message, "Invalid email or password")
    XCTAssertFalse(wrong.endsSession)

    XCTAssertEqual(fail(401, "{\"error\":\"invalid_code\"}").kind, .rejected)
    XCTAssertEqual(
      fail(401, "{\"error\":\"invalid_code\"}").message,
      "That code didn’t work. Enter the current 6-digit code from your authenticator app.")
    XCTAssertEqual(
      fail(401, "{\"error\":\"invalid_password\"}").message, "That password isn’t right.")

    XCTAssertEqual(fail(401, "{\"error\":\"unauthorized\"}").kind, .unauthorized)
    XCTAssertEqual(fail(401, nil).kind, .unauthorized)
    XCTAssertTrue(fail(401, "{\"error\":\"unauthorized\"}").endsSession)

    let changed = fail(409, "{\"error\":\"account_changed\"}")
    XCTAssertEqual(changed.kind, .accountChanged)
    XCTAssertTrue(changed.endsSession)

    let stepUp = fail(403, "{\"error\":\"reauthentication_required\",\"twoFactor\":true}")
    XCTAssertEqual(stepUp.kind, .reauthenticationRequired)
    XCTAssertTrue(stepUp.twoFactor)

    let throttled = fail(
      429,
      "{\"message\":\"Too many password attempts for this account. Try again later or reset your password.\",\"code\":\"TOO_MANY_ATTEMPTS\"}",
      retry: "60")
    XCTAssertEqual(throttled.kind, .rateLimited)
    XCTAssertEqual(throttled.retryAfter, 60)
    XCTAssertTrue(throttled.message.hasPrefix("Too many password attempts"))
    XCTAssertEqual(fail(429, nil).message, "Too many requests. Please try again later.")

    XCTAssertEqual(fail(500, "{\"error\":\"internal_error\"}").kind, .server)
    XCTAssertEqual(
      fail(409, "{\"error\":\"token_limit\"}").message,
      "You already have the maximum number of coach tokens. Revoke one first.")
    XCTAssertEqual(
      fail(404, "{\"error\":\"session_not_found\"}").message, "That device was already signed out.")
  }

  func testLongOrUnknownMessagesFallBackToTheScreensOwnWords() {
    let long = String(repeating: "x", count: 500)
    let failure = AccountWire.failure(
      status: 400, body: Data("{\"message\":\"\(long)\"}".utf8), fallback: "Please try again.")
    XCTAssertEqual(failure.message, "Please try again.")
    let unknown = AccountWire.failure(
      status: 400, body: Data("{\"error\":\"some_new_code\"}".utf8), fallback: "Please try again.")
    XCTAssertEqual(unknown.message, "Please try again.")
    XCTAssertEqual(AccountWire.failure(status: 400, body: nil, fallback: "F").message, "F")
  }
}
