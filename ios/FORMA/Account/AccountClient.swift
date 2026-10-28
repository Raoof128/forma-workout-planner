import FORMACore
import Foundation

/// Where the account lives. The origin is a build setting
/// (`FORMA_ACCOUNT_ORIGIN` in project.yml, surfaced through Info.plist) so a
/// build can be pointed elsewhere without touching code. HTTPS only.
enum AccountConfiguration {
  static let origin: URL? = {
    guard
      let text = (Bundle.main.object(forInfoDictionaryKey: "FORMAAccountOrigin") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      var components = URLComponents(string: text), components.scheme == "https",
      let host = components.host, !host.isEmpty, components.user == nil, components.query == nil,
      components.fragment == nil, components.path.isEmpty || components.path == "/"
    else { return nil }
    components.path = ""
    return components.url
  }()

  /// An address on the account's own origin, which the account accepts for
  /// email links and refuses for anything else.
  static func link(_ origin: URL, _ suffix: String = "") -> String {
    origin.absoluteString + suffix
  }

  #if DEBUG
    /// Staging Access credentials are launch-time inputs, never bundled. Even
    /// in Debug they can only be sent to the project's exact staging origin.
    static func stagingHeaders(
      for origin: URL, environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
      guard origin.absoluteString == "https://forma-staging.raoufabedini.dev",
        let identifier = environment["FORMA_STAGING_ACCESS_ID"], !identifier.isEmpty,
        let secret = environment["FORMA_STAGING_ACCESS_SECRET"], !secret.isEmpty
      else { return [:] }
      return ["CF-Access-Client-Id": identifier, "CF-Access-Client-Secret": secret]
    }
  #endif
}

/// A web address for the website, e.g. the Terms of Use.
func accountWebsite(_ origin: URL, fragment: String) -> URL {
  URL(string: origin.absoluteString + "/#" + fragment) ?? origin
}

/// A reply that needs no further reading by the caller.
struct AccountResponse: Sendable {
  var status: Int
  var body: Data
  var retryAfter: String?
}

/// Refuses every redirect, so cookies and the member header can only ever go to
/// the account's own host.
final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

/// The account's HTTP client: JSON over one `URLSession`, a cookie jar of its own
/// and nothing else shared with the system.
///
/// Every request carries `X-Forma-Client: ios` and, once a member is known,
/// `X-Forma-Member`. It never adds `Origin`, `Referer` or `Sec-Fetch-*`: the
/// account recognises the app by their absence, and `URLSession` sends none.
actor AccountClient {
  let origin: URL
  private let jar: CookieJar
  private let session: URLSession
  private var member: String?
  private var sessionGeneration: UInt64 = 0

  init(origin: URL, jar: CookieJar, member: String? = nil, session: URLSession? = nil) {
    self.origin = origin
    self.jar = jar
    self.member = member
    self.session = session ?? Self.makeSession()
  }

  /// No system cookie jar, no cache, no stored credentials, no redirects.
  static func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieAcceptPolicy = .never
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    configuration.urlCredentialStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.waitsForConnectivity = false
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 300
    configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
    return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
  }

  func setMember(_ reference: String?) { member = reference }
  func currentMember() -> String? { member }

  // MARK: Transport

  private enum TransportFailure: Error {
    case offline
    case other(String)
  }

  /// One request. `memberOverride` pins the member reference for calls made on
  /// behalf of a particular account (the sync engine), so a transport left over
  /// from a previous sign-in can never act as the next member.
  private func perform(
    _ request: AccountWire.Request, member pinned: String?? = nil, timeout: TimeInterval = 30
  ) async throws -> AccountResponse {
    let generation = sessionGeneration
    if let pinned, pinned != member { throw CancellationError() }
    guard let url = URL(string: origin.absoluteString + request.path) else {
      throw TransportFailure.other("The request address was not valid.")
    }
    var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    urlRequest.httpMethod = request.method
    urlRequest.timeoutInterval = timeout
    urlRequest.httpShouldHandleCookies = false
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    urlRequest.setValue("ios", forHTTPHeaderField: "X-Forma-Client")
    #if DEBUG
      for (name, value) in AccountConfiguration.stagingHeaders(for: origin) {
        urlRequest.setValue(value, forHTTPHeaderField: name)
      }
    #endif
    if let body = request.body {
      urlRequest.httpBody = body
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let reference: String? = pinned ?? member
    if let reference { urlRequest.setValue(reference, forHTTPHeaderField: "X-Forma-Member") }
    let snapshot = await jar.snapshot()
    guard generation == sessionGeneration else { throw CancellationError() }
    if let cookie = snapshot.header { urlRequest.setValue(cookie, forHTTPHeaderField: "Cookie") }
    do {
      let (data, response) = try await session.data(for: urlRequest)
      guard generation == sessionGeneration else { throw CancellationError() }
      guard let http = response as? HTTPURLResponse else {
        throw TransportFailure.other("FORMA sent an answer this app could not read.")
      }
      guard await jar.absorb(http, for: snapshot), generation == sessionGeneration else {
        throw CancellationError()
      }
      return AccountResponse(
        status: http.statusCode, body: data,
        retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
    } catch let error as URLError {
      switch error.code {
      case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
        throw TransportFailure.offline
      case .cancelled:
        throw CancellationError()
      default:
        throw TransportFailure.other(error.localizedDescription)
      }
    }
  }

  /// A request whose answer is read by the account screens.
  private func send(
    _ request: AccountWire.Request,
    fallback: String = "We couldn’t complete that request. Please try again."
  ) async throws -> Data {
    let response: AccountResponse
    do {
      response = try await perform(request)
    } catch TransportFailure.offline {
      throw AccountWire.offlineFailure()
    } catch TransportFailure.other(let message) {
      throw AccountFailure(kind: .server, message: message)
    }
    guard (200..<300).contains(response.status) else {
      throw AccountWire.failure(
        status: response.status, body: response.body, retryAfter: response.retryAfter,
        fallback: fallback)
    }
    return response.body
  }

  /// A workspace request for the sync transport.
  func workspace(_ request: AccountWire.Request, member pinned: String) async throws
    -> AccountResponse
  {
    do {
      return try await perform(request, member: .some(pinned), timeout: 120)
    } catch TransportFailure.offline {
      throw WorkspaceTransportError.offline
    } catch TransportFailure.other(let message) {
      throw WorkspaceTransportError.transient(message)
    }
  }

  // MARK: Session

  /// The signed-in member, or nil when the account says there is no session.
  func getSession() async throws -> AccountProfile? {
    try AccountWire.decodeSession(try await send(AccountWire.getSession))
  }

  func signUp(name: String, email: String, password: String) async throws {
    _ = try await send(
      AccountWire.signUp(name: name, email: email, password: password),
      fallback: "We couldn’t complete that request. Please try again.")
  }

  func signIn(email: String, password: String) async throws -> SignInOutcome {
    // A new sign-in starts from nothing: no leftover session or challenge.
    await endLocalSession()
    return AccountWire.decodeSignIn(
      try await send(AccountWire.signIn(email: email, password: password)))
  }

  func verifyTwoFactor(code: String, recovery: Bool) async throws {
    _ = try await send(
      recovery ? AccountWire.verifyBackupCode(code: code) : AccountWire.verifyTOTP(code: code))
  }

  /// Ends the session at the account when it can be reached, and on this
  /// iPhone either way. True when the account confirmed.
  @discardableResult
  func signOut() async -> Bool {
    var confirmed = false
    if await jar.hasSession {
      do {
        _ = try await send(AccountWire.signOut)
        confirmed = true
      } catch {
        confirmed = false
      }
    }
    await endLocalSession()
    return confirmed
  }

  /// Forgets the session on this iPhone only.
  func endLocalSession() async {
    sessionGeneration &+= 1
    member = nil
    await jar.clear()
  }

  func adopt(_ profile: AccountProfile) async {
    member = profile.id
    await jar.setProfile(profile)
  }

  func signOutEverywhere() async throws {
    _ = try await send(AccountWire.signOutEverywhere)
    await endLocalSession()
  }

  // MARK: Email and password

  func resendVerification(email: String) async throws {
    _ = try await send(
      AccountWire.sendVerificationEmail(
        email: email, callbackURL: AccountConfiguration.link(origin)),
      fallback: "We couldn’t send the verification email.")
  }

  func requestPasswordReset(email: String) async throws {
    _ = try await send(
      AccountWire.requestPasswordReset(
        email: email, redirectTo: AccountConfiguration.link(origin, "/#account")))
  }

  func updateName(_ name: String) async throws {
    _ = try await send(AccountWire.updateName(name), fallback: "Your name could not be updated.")
  }

  func changeEmail(to newEmail: String) async throws {
    _ = try await send(
      AccountWire.changeEmail(
        newEmail: newEmail, callbackURL: AccountConfiguration.link(origin, "/#account")),
      fallback: "We couldn’t start the email change.")
  }

  func changePassword(current: String, new: String) async throws {
    _ = try await send(
      AccountWire.changePassword(current: current, new: new),
      fallback: "Password could not be updated.")
  }

  func deleteAccount(password: String) async throws {
    _ = try await send(
      AccountWire.deleteAccount(password: password), fallback: "Your account could not be deleted.")
  }

  // MARK: Two-step verification

  func enableTwoFactor(password: String) async throws -> TwoFactorEnrollment {
    try AccountWire.decodeEnrollment(
      try await send(
        AccountWire.enableTwoFactor(password: password),
        fallback: "Two-step verification could not be enabled."))
  }

  func confirmTwoFactorEnrollment(code: String) async throws {
    _ = try await send(
      AccountWire.verifyTOTP(code: code),
      fallback: "That code could not be verified. Try the latest code from your authenticator.")
  }

  func disableTwoFactor(password: String) async throws {
    _ = try await send(
      AccountWire.disableTwoFactor(password: password),
      fallback: "Two-step verification could not be disabled.")
  }

  func recoveryCodes(password: String) async throws -> [String] {
    try AccountWire.decodeBackupCodes(
      try await send(
        AccountWire.generateBackupCodes(password: password),
        fallback: "Recovery codes could not be loaded."))
  }

  // MARK: Sessions and coach access

  func devices() async throws -> [AccountDevice] {
    try AccountWire.decodeDevices(
      try await send(AccountWire.listSessions, fallback: "Active sessions could not be loaded."))
  }

  func revokeDevice(id: String, password: String? = nil, code: String? = nil) async throws {
    _ = try await send(
      try AccountWire.revokeSession(id: id, password: password, code: code),
      fallback: "That device could not be signed out.")
  }

  func revokeOtherDevices(password: String? = nil, code: String? = nil) async throws {
    _ = try await send(
      AccountWire.revokeOtherSessions(password: password, code: code),
      fallback: "Other devices could not be signed out.")
  }

  func coachTokens() async throws -> [CoachTokenRecord] {
    try AccountWire.decodeCoachTokens(
      try await send(AccountWire.listCoachTokens, fallback: "Coach access could not be loaded."))
  }

  func createCoachToken(label: String, full: Bool) async throws -> IssuedCoachToken {
    try AccountWire.decodeIssuedCoachToken(
      try await send(
        AccountWire.createCoachToken(label: label, full: full),
        fallback: "The coach token could not be created."))
  }

  func revokeCoachToken(id: String) async throws {
    _ = try await send(
      try AccountWire.revokeCoachToken(id: id), fallback: "The coach token could not be revoked.")
  }
}

/// `GET`/`PUT /api/workspace` for the sync engine, pinned to one member.
struct URLSessionWorkspaceTransport: WorkspaceTransport {
  let client: AccountClient
  let member: String

  func fetch() async throws -> RemoteWorkspace {
    let response = try await client.workspace(AccountWire.fetchWorkspace, member: member)
    guard (200..<300).contains(response.status) else {
      throw WorkspaceWire.transportError(
        status: response.status, body: response.body, retryAfter: response.retryAfter)
    }
    return try WorkspaceWire.decodeRemote(response.body)
  }

  func put(_ request: WorkspacePut) async throws -> RemoteWorkspace {
    let wire = AccountWire.Request(
      method: "PUT", path: "/api/workspace", body: request.requestBody())
    let response = try await client.workspace(wire, member: member)
    guard (200..<300).contains(response.status) else {
      throw WorkspaceWire.transportError(
        status: response.status, body: response.body, retryAfter: response.retryAfter)
    }
    return try WorkspaceWire.decodeRemote(response.body)
  }
}
