import Foundation

// The account's HTTP contract as plain values, so the app's URLSession client is
// a thin shell and every request body, response shape and message is covered by
// `swift test`. Bodies and wording mirror the website (src/account/*,
// src/components/Account.jsx); the routes are the ones server/app.ts allows.

/// Who the signed-in member is. `id` is the member reference (`mem_…`) the
/// account already returns in place of its database id; it is what
/// `X-Forma-Member` carries.
public struct AccountProfile: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var name: String
  public var email: String
  public var emailVerified: Bool
  public var twoFactorEnabled: Bool
  /// The account's own text, e.g. `2026-10-13T01:02:03.000Z`.
  public var createdAt: String?

  public init(
    id: String, name: String, email: String, emailVerified: Bool = false,
    twoFactorEnabled: Bool = false, createdAt: String? = nil
  ) {
    self.id = id
    self.name = name
    self.email = email
    self.emailVerified = emailVerified
    self.twoFactorEnabled = twoFactorEnabled
    self.createdAt = createdAt
  }

  public var memberSince: Date? { createdAt.flatMap(AccountWire.parseDate) }
}

/// An active session as `/api/account/sessions` lists it. `id` is an opaque
/// reference, never the session token.
public struct AccountDevice: Equatable, Sendable, Identifiable {
  public var id: String
  public var createdAt: Date?
  public var expiresAt: Date?
  public var userAgent: String?
  public var current: Bool
}

/// A coach access token's record. The plaintext is only ever in `IssuedCoachToken`.
public struct CoachTokenRecord: Equatable, Sendable, Identifiable {
  public var id: String
  public var label: String
  /// `read` or `full`.
  public var scope: String
  public var createdAt: Date?
  public var expiresAt: Date?
  public var lastUsedAt: Date?

  public var isFullAccess: Bool { scope == "full" }
}

public struct IssuedCoachToken: Equatable, Sendable {
  public var token: String
  public var record: CoachTokenRecord
}

/// What turning on two-step verification returns.
public struct TwoFactorEnrollment: Equatable, Sendable {
  public var totpURI: String
  /// The setup key for typing into an authenticator when scanning is not possible.
  public var secret: String
  public var backupCodes: [String]
}

public enum SignInOutcome: Equatable, Sendable {
  /// The password was right and the account wants a code (the `two_factor`
  /// cookie it set must go back with it).
  case twoFactorRequired
  case signedIn
}

/// Why an account request did not succeed, in words fit for the screen.
public struct AccountFailure: Error, LocalizedError, Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case offline
    /// 401: there is no session.
    case unauthorized
    /// 409 `account_changed`.
    case accountChanged
    /// 403 `reauthentication_required`: the sign-in is older than five minutes.
    case reauthenticationRequired
    case rateLimited
    /// The account understood and said no (wrong password, bad code, …).
    case rejected
    case server
    case invalidResponse
  }

  public var kind: Kind
  public var status: Int?
  public var code: String?
  public var message: String
  /// With `reauthenticationRequired`: the member has two-step on, so the
  /// confirmation needs a code as well as the password.
  public var twoFactor: Bool
  public var retryAfter: TimeInterval?

  public init(
    kind: Kind, message: String, status: Int? = nil, code: String? = nil, twoFactor: Bool = false,
    retryAfter: TimeInterval? = nil
  ) {
    self.kind = kind
    self.message = message
    self.status = status
    self.code = code
    self.twoFactor = twoFactor
    self.retryAfter = retryAfter
  }

  public var errorDescription: String? { message }

  /// The session is gone or belongs to someone else: the app must sign out.
  public var endsSession: Bool { kind == .unauthorized || kind == .accountChanged }
}

public enum AccountWire {
  // MARK: Requests

  public struct Request: Equatable, Sendable {
    public var method: String
    public var path: String
    public var body: Data?

    public init(method: String, path: String, body: Data? = nil) {
      self.method = method
      self.path = path
      self.body = body
    }

    /// Routes that carry a JSON body need the matching content type.
    public var hasBody: Bool { body != nil }
  }

  public enum RequestError: Error, Equatable, Sendable { case invalidIdentifier }

  /// Session and coach-token references are base64url or short ids. The origin
  /// refuses `%` in a path, so anything else is rejected rather than escaped.
  static func pathSegment(_ identifier: String) throws -> String {
    let allowed = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
    guard !identifier.isEmpty, identifier.utf8.count <= 128,
      identifier.unicodeScalars.allSatisfy({ allowed.contains($0) })
    else { throw RequestError.invalidIdentifier }
    return identifier
  }

  private static func json(_ object: [String: Any]) -> Data {
    // Sorted keys keep the bytes stable, which the tests rely on.
    (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
  }

  public static let getSession = Request(method: "GET", path: "/api/auth/get-session", body: nil)
  public static let listSessions = Request(method: "GET", path: "/api/account/sessions", body: nil)
  public static let listCoachTokens = Request(
    method: "GET", path: "/api/account/coach-tokens", body: nil)
  public static let signOut = Request(method: "POST", path: "/api/auth/sign-out", body: json([:]))
  public static let signOutEverywhere = Request(
    method: "POST", path: "/api/account/sessions/revoke-all", body: json([:]))
  public static let fetchWorkspace = Request(method: "GET", path: "/api/workspace", body: nil)

  public static func signUp(name: String, email: String, password: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/sign-up/email",
      body: json(["name": name, "email": email, "password": password]))
  }

  public static func signIn(email: String, password: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/sign-in/email",
      body: json(["email": email, "password": password, "rememberMe": true]))
  }

  public static func verifyTOTP(code: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/two-factor/verify-totp",
      body: json(["code": code, "trustDevice": false]))
  }

  public static func verifyBackupCode(code: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/two-factor/verify-backup-code",
      body: json(["code": code, "trustDevice": false]))
  }

  /// `callbackURL` must be on the account's own origin (the account refuses any
  /// other).
  public static func sendVerificationEmail(email: String, callbackURL: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/send-verification-email",
      body: json(["email": email, "callbackURL": callbackURL]))
  }

  public static func requestPasswordReset(email: String, redirectTo: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/request-password-reset",
      body: json(["email": email, "redirectTo": redirectTo]))
  }

  public static func updateName(_ name: String) -> Request {
    Request(method: "POST", path: "/api/auth/update-user", body: json(["name": name]))
  }

  public static func changeEmail(newEmail: String, callbackURL: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/change-email",
      body: json(["newEmail": newEmail, "callbackURL": callbackURL]))
  }

  /// Other sessions always end with a password change; the account enforces it
  /// whatever is sent, and the website sends it too.
  public static func changePassword(current: String, new: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/change-password",
      body: json(["currentPassword": current, "newPassword": new, "revokeOtherSessions": true]))
  }

  public static func enableTwoFactor(password: String) -> Request {
    Request(method: "POST", path: "/api/auth/two-factor/enable", body: json(["password": password]))
  }

  public static func disableTwoFactor(password: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/two-factor/disable", body: json(["password": password]))
  }

  public static func generateBackupCodes(password: String) -> Request {
    Request(
      method: "POST", path: "/api/auth/two-factor/generate-backup-codes",
      body: json(["password": password]))
  }

  public static func deleteAccount(password: String) -> Request {
    Request(method: "POST", path: "/api/auth/delete-user", body: json(["password": password]))
  }

  /// An older sign-in confirms with `password` (and `code` when two-step is on).
  public static func revokeSession(id: String, password: String? = nil, code: String? = nil) throws
    -> Request
  {
    Request(
      method: "DELETE", path: "/api/account/sessions/\(try pathSegment(id))/revoke",
      body: confirmation(password: password, code: code))
  }

  public static func revokeOtherSessions(password: String? = nil, code: String? = nil) -> Request {
    Request(
      method: "POST", path: "/api/account/sessions/revoke-others",
      body: confirmation(password: password, code: code) ?? json([:]))
  }

  private static func confirmation(password: String?, code: String?) -> Data? {
    guard let password, !password.isEmpty else { return nil }
    var object: [String: Any] = ["password": password]
    if let code, !code.isEmpty { object["code"] = code }
    return json(object)
  }

  public static func createCoachToken(label: String, full: Bool) -> Request {
    Request(
      method: "POST", path: "/api/account/coach-tokens",
      body: json(["label": label, "scope": full ? "full" : "read"]))
  }

  public static func revokeCoachToken(id: String) throws -> Request {
    Request(
      method: "DELETE", path: "/api/account/coach-tokens/\(try pathSegment(id))", body: nil)
  }

  // MARK: Responses

  private static func object(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  public static func parseDate(_ text: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: text) { return date }
    return ISO8601DateFormatter().date(from: text)
  }

  private static func profile(_ user: [String: Any]) -> AccountProfile? {
    guard let id = user["id"] as? String, !id.isEmpty, let email = user["email"] as? String else {
      return nil
    }
    return AccountProfile(
      id: id, name: (user["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "FORMA member",
      email: email, emailVerified: user["emailVerified"] as? Bool ?? false,
      twoFactorEnabled: user["twoFactorEnabled"] as? Bool ?? false,
      createdAt: user["createdAt"] as? String)
  }

  /// `GET /api/auth/get-session`: the profile, or nil when there is no session
  /// (the account answers 200 with `null`).
  public static func decodeSession(_ body: Data) throws -> AccountProfile? {
    let value = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed])
    if value is NSNull { return nil }
    guard let root = value as? [String: Any] else {
      throw AccountFailure(
        kind: .invalidResponse, message: "FORMA sent an answer this app could not read.")
    }
    guard let user = root["user"] as? [String: Any] else { return nil }
    guard let profile = profile(user) else {
      throw AccountFailure(
        kind: .invalidResponse, message: "FORMA sent an answer this app could not read.")
    }
    return profile
  }

  public static func decodeSignIn(_ body: Data) -> SignInOutcome {
    object(body)?["twoFactorRedirect"] as? Bool == true ? .twoFactorRequired : .signedIn
  }

  public static func decodeDevices(_ body: Data) throws -> [AccountDevice] {
    guard let rows = (try? JSONSerialization.jsonObject(with: body)) as? [[String: Any]] else {
      throw AccountFailure(
        kind: .invalidResponse, message: "Active sessions could not be loaded.")
    }
    return rows.compactMap { row in
      guard let id = row["id"] as? String else { return nil }
      return AccountDevice(
        id: id, createdAt: (row["createdAt"] as? String).flatMap(parseDate),
        expiresAt: (row["expiresAt"] as? String).flatMap(parseDate),
        userAgent: row["userAgent"] as? String, current: row["current"] as? Bool ?? false)
    }
  }

  private static func tokenRecord(_ row: [String: Any]) -> CoachTokenRecord? {
    guard let id = row["id"] as? String, let label = row["label"] as? String else { return nil }
    return CoachTokenRecord(
      id: id, label: label, scope: row["scope"] as? String == "full" ? "full" : "read",
      createdAt: (row["createdAt"] as? String).flatMap(parseDate),
      expiresAt: (row["expiresAt"] as? String).flatMap(parseDate),
      lastUsedAt: (row["lastUsedAt"] as? String).flatMap(parseDate))
  }

  public static func decodeCoachTokens(_ body: Data) throws -> [CoachTokenRecord] {
    guard let rows = (try? JSONSerialization.jsonObject(with: body)) as? [[String: Any]] else {
      throw AccountFailure(kind: .invalidResponse, message: "Coach access could not be loaded.")
    }
    return rows.compactMap(tokenRecord)
  }

  public static func decodeIssuedCoachToken(_ body: Data) throws -> IssuedCoachToken {
    guard let root = object(body), let token = root["token"] as? String, !token.isEmpty,
      let row = root["record"] as? [String: Any], let record = tokenRecord(row)
    else {
      throw AccountFailure(
        kind: .invalidResponse, message: "The coach token could not be created.")
    }
    return IssuedCoachToken(token: token, record: record)
  }

  public static func decodeEnrollment(_ body: Data) throws -> TwoFactorEnrollment {
    guard let root = object(body), let uri = root["totpURI"] as? String else {
      throw AccountFailure(
        kind: .invalidResponse, message: "Two-step verification could not be enabled.")
    }
    let secret =
      URLComponents(string: uri)?.queryItems?.first { $0.name == "secret" }?.value ?? uri
    return TwoFactorEnrollment(
      totpURI: uri, secret: secret, backupCodes: root["backupCodes"] as? [String] ?? [])
  }

  public static func decodeBackupCodes(_ body: Data) throws -> [String] {
    guard let root = object(body), let codes = root["backupCodes"] as? [String] else {
      throw AccountFailure(kind: .invalidResponse, message: "Recovery codes could not be loaded.")
    }
    return codes
  }

  // MARK: Errors

  /// Words for the codes the website handles itself (Account.jsx), keyed by the
  /// `error` or `code` the account sends.
  static let messages: [String: String] = [
    "account_changed": "This session no longer matches your account. Sign in again.",
    "unauthorized": "Your session has ended. Sign in again.",
    "invalid_password": "That password isn’t right.",
    "INVALID_PASSWORD": "That password isn’t right.",
    "invalid_code":
      "That code didn’t work. Enter the current 6-digit code from your authenticator app.",
    "INVALID_CODE":
      "That code didn’t work. Enter the current 6-digit code from your authenticator app.",
    "INVALID_BACKUP_CODE": "That recovery code didn’t work.",
    "session_not_found": "That device was already signed out.",
    "token_limit": "You already have the maximum number of coach tokens. Revoke one first.",
    "invalid_label": "Use a short plain-text name of up to 60 characters.",
    "invalid_scope": "Choose read-only or full access.",
    "reauthentication_required": "For your security, sign in again to do this.",
    "invalid_profile": "Use a shorter display name, up to 50 characters.",
    "TOO_MANY_ATTEMPTS":
      "Too many password attempts for this account. Try again later or reset your password.",
    "rate_limited": "Too many requests. Try again in a minute.",
    "invalid_redirect": "We couldn’t complete that request. Please try again.",
    "unsupported_media_type": "We couldn’t complete that request. Please try again.",
    "bad_request": "We couldn’t complete that request. Please try again.",
    "invalid_json": "We couldn’t complete that request. Please try again.",
    "internal_error": "FORMA is unavailable right now. Try again in a moment.",
    "workspace_unavailable": "FORMA is unavailable right now. Try again in a moment.",
    "token_not_found": "That coach token was already revoked.",
  ]

  /// The website shows the account's own message when it is short and
  /// readable, and its screen's fallback otherwise.
  static let longestShownMessage = 200

  public static func failure(
    status: Int, body: Data?, retryAfter: String? = nil, fallback: String
  ) -> AccountFailure {
    let root = body.flatMap(object)
    // FORMA's routes send `error`; Better Auth sends `code`.
    let code = (root?["error"] as? String) ?? (root?["code"] as? String)
    let serverMessage = (root?["message"] as? String).flatMap {
      !$0.isEmpty && $0.count <= longestShownMessage ? $0 : nil
    }
    let wait = retryAfter.flatMap { TimeInterval($0) }
    let twoFactor = root?["twoFactor"] as? Bool == true
    let known = code.flatMap { messages[$0] }

    func make(_ kind: AccountFailure.Kind, _ message: String) -> AccountFailure {
      AccountFailure(
        kind: kind, message: message, status: status, code: code, twoFactor: twoFactor,
        retryAfter: wait)
    }

    if code == "account_changed" { return make(.accountChanged, messages["account_changed"]!) }
    if code == "reauthentication_required" {
      return make(.reauthenticationRequired, known ?? fallback)
    }
    switch status {
    case 401:
      // A wrong password or code is a 401 too, but not an ended session: those
      // carry a code the website words itself.
      let ended = ["unauthorized", "UNAUTHORIZED", "SESSION_EXPIRED"].contains(code ?? "")
      if !ended, let known { return make(.rejected, serverMessage ?? known) }
      if !ended, let serverMessage { return make(.rejected, serverMessage) }
      return make(.unauthorized, messages["unauthorized"]!)
    case 429:
      return make(
        .rateLimited, serverMessage ?? known ?? "Too many requests. Please try again later.")
    case 500...599:
      return make(.server, known ?? "FORMA is unavailable right now. Try again in a moment.")
    default:
      return make(.rejected, serverMessage ?? known ?? fallback)
    }
  }

  /// A connection that never completed.
  public static func offlineFailure() -> AccountFailure {
    AccountFailure(
      kind: .offline,
      message: "You appear to be offline. Check your connection and try again.")
  }
}
