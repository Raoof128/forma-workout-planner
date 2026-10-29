import FORMACore
import Foundation
import XCTest
import os

@testable import FORMA

private struct OfflineAccount: WorkspaceTransport {
  func fetch() async throws -> RemoteWorkspace { throw WorkspaceTransportError.offline }
  func put(_ request: WorkspacePut) async throws -> RemoteWorkspace {
    throw WorkspaceTransportError.offline
  }
}

/// Every request stays inside URLProtocol. Synthetic cookies and .test hosts
/// make these races repeatable without contacting a FORMA service.
private final class HeldAccountRequest: URLProtocol, @unchecked Sendable {
  struct State {
    var pending: HeldAccountRequest?
    var requests: [URLRequest] = []
    var started: XCTestExpectation?
    var immediate = false
    var response: (@Sendable (URLRequest) -> (body: String, cookie: String?))?
  }

  static let state = OSAllocatedUnfairLock(initialState: State())

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let (started, immediate, response) = Self.state.withLock { state in
      state.pending = self
      state.requests.append(request)
      return (state.started, state.immediate, state.response)
    }
    started?.fulfill()
    if let response {
      let reply = response(request)
      complete(body: reply.body, cookie: reply.cookie)
    } else if immediate {
      complete(body: "null")
    }
  }

  override func stopLoading() {}

  func complete(body: String, cookie: String? = nil) {
    guard let url = request.url,
      let response = HTTPURLResponse(
        url: url, statusCode: 200, httpVersion: nil,
        headerFields: cookie.map { ["Set-Cookie": $0] })
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
}

@MainActor
final class AccountLifecycleTests: XCTestCase {
  private let origin = URL(string: "https://account.example.test")!
  private let first = AccountProfile(id: "mem_first", name: "First", email: "first@example.test")
  private let second = AccountProfile(
    id: "mem_second", name: "Second", email: "second@example.test")

  override func setUp() {
    super.setUp()
    HeldAccountRequest.state.withLock { $0 = .init() }
  }

  private func environment() async -> AccountEnvironment {
    let jar = CookieJar(vault: MemorySessionVault(), installMarker: nil)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HeldAccountRequest.self]
    let session = URLSession(configuration: configuration)
    addTeardownBlock { session.invalidateAndCancel() }
    let client = AccountClient(origin: origin, jar: jar, session: session)
    await client.adopt(first)
    return AccountEnvironment(
      client: client, jar: jar,
      storage: AccountStorage(root: FileManager.default.temporaryDirectory, origin: origin),
      restored: first)
  }

  private func holdNextRequest() -> XCTestExpectation {
    let started = expectation(description: "The request reached the synthetic server")
    HeldAccountRequest.state.withLock { $0.started = started }
    return started
  }

  private func release(body: String, cookie: String? = nil) throws {
    let pending = try XCTUnwrap(HeldAccountRequest.state.withLock { $0.pending })
    pending.complete(body: body, cookie: cookie)
  }

  private func setCookie(_ cookie: String, in jar: CookieJar) async throws {
    let response = try XCTUnwrap(
      HTTPURLResponse(
        url: origin, statusCode: 200, httpVersion: nil, headerFields: ["Set-Cookie": cookie]))
    await jar.absorb(response)
  }

  private func sessionBody(name: String = "First updated") -> String {
    """
    {"user":{"id":"mem_first","name":"\(name)","email":"first@example.test","emailVerified":true}}
    """
  }

  func testLateResponseCannotRestoreCookiesAfterSignOut() async throws {
    let environment = await environment()
    try await setCookie("forma.session_token=first; Path=/; Secure", in: environment.jar)
    let started = holdNextRequest()
    let request = Task { try await environment.client.getSession() }
    await fulfillment(of: [started], timeout: 5)

    await environment.client.endLocalSession()
    try release(body: sessionBody(), cookie: "forma.session_token=late; Path=/; Secure")

    if case .success = await request.result {
      XCTFail("A response from the ended session must be cancelled")
    }
    let header = await environment.jar.header()
    XCTAssertNil(header)
  }

  func testLateResponseCannotReplaceTheNextMembersCookie() async throws {
    let environment = await environment()
    let started = holdNextRequest()
    let request = Task { try await environment.client.getSession() }
    await fulfillment(of: [started], timeout: 5)

    await environment.client.endLocalSession()
    await environment.client.adopt(second)
    try await setCookie("forma.session_token=second; Path=/; Secure", in: environment.jar)
    try release(body: sessionBody(), cookie: "forma.session_token=first; Path=/; Secure")

    _ = await request.result
    let header = await environment.jar.header()
    XCTAssertEqual(header, "forma.session_token=second")
    let member = await environment.client.currentMember()
    XCTAssertEqual(member, second.id)
  }

  func testTransportFromPreviousMemberCannotSendUsingTheNewSession() async throws {
    let environment = await environment()
    await environment.client.endLocalSession()
    await environment.client.adopt(second)
    HeldAccountRequest.state.withLock { $0.immediate = true }

    do {
      _ = try await environment.client.workspace(AccountWire.fetchWorkspace, member: first.id)
      XCTFail("The previous member's transport should be cancelled")
    } catch is CancellationError {
      // Refused before creating a network request.
    } catch {
      XCTFail("Expected cancellation, got \(error)")
    }
    let count = HeldAccountRequest.state.withLock { $0.requests.count }
    XCTAssertEqual(count, 0)
  }

  func testLateSessionRefreshCannotSignInAgainAfterSignOut() async throws {
    let environment = await environment()
    let account = AccountModel()
    account.attach(environment)
    let started = holdNextRequest()
    let refresh = Task { await account.refreshSession() }
    await fulfillment(of: [started], timeout: 5)

    await account.sessionEnded(.sessionEnded)
    try release(body: sessionBody())
    await refresh.value

    XCTAssertEqual(account.phase, .signedOut)
    let profile = await environment.jar.profile
    XCTAssertNil(profile)
  }

  func testDifferentAccountOriginsCannotReadEachOthersSavedSession() throws {
    let root = FileManager.default.temporaryDirectory
    let firstOrigin = try XCTUnwrap(URL(string: "https://first-\(UUID().uuidString).example.test"))
    let otherOrigin = try XCTUnwrap(URL(string: "https://second-\(UUID().uuidString).example.test"))
    let firstStorage = AccountStorage(root: root, origin: firstOrigin)
    let secondStorage = AccountStorage(root: root, origin: otherOrigin)
    let firstVault = KeychainSessionVault(account: firstStorage.keychainAccount)
    let secondVault = KeychainSessionVault(account: secondStorage.keychainAccount)
    defer {
      firstVault.erase()
      secondVault.erase()
    }
    let session = StoredAccountSession(cookies: FormaCookieJar(), profile: first)

    XCTAssertTrue(firstVault.save(session))
    XCTAssertEqual(firstVault.load(), session)
    XCTAssertNil(secondVault.load())
    XCTAssertNotEqual(firstStorage.directory, secondStorage.directory)
  }

  func testStagingCredentialsCannotBeSentToProductionOrAnotherHost() throws {
    let environment = [
      "FORMA_STAGING_ACCESS_ID": "fixture-identifier",
      "FORMA_STAGING_ACCESS_SECRET": "fixture-value",
    ]
    let staging = try XCTUnwrap(URL(string: "https://forma-staging.raoufabedini.dev"))
    let production = try XCTUnwrap(URL(string: "https://forma.raoufabedini.dev"))
    XCTAssertEqual(
      AccountConfiguration.stagingHeaders(for: staging, environment: environment).count, 2)
    XCTAssertTrue(
      AccountConfiguration.stagingHeaders(for: production, environment: environment).isEmpty)
    XCTAssertTrue(
      AccountConfiguration.stagingHeaders(for: origin, environment: environment).isEmpty)
    XCTAssertTrue(AccountConfiguration.stagingHeaders(for: staging, environment: [:]).isEmpty)
  }

  func testAnEditQueuedForThePreviousStoreCannotChangeTheNextMembersTraining() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try WorkspaceStore(
      url: directory.appendingPathComponent("training.sqlite"), catalog: [])
    let model = AppModel()
    model.workspace = try await store.load(
      seed: Workspace(profile: Profile(name: "Original", goal: 4)))
    model.store = store
    await model.mutationGate.acquire()
    let queued = Task { await model.commit { $0.profile.name = "An old screen's edit" } }
    for _ in 0..<1_000 {
      if model.pendingMutations > 0 { break }
      await Task.yield()
    }
    XCTAssertEqual(model.pendingMutations, 1)
    model.activeMember = "mem_second"
    model.mutationGate.release()

    let saved = await queued.value
    XCTAssertFalse(saved)
    let name = try await store.load(seed: Workspace()).profile.name
    XCTAssertEqual(name, "Original")
  }

  func testSignOutChecksDurableUnsentChangesEvenWhenTheStatusLabelStillSaysSaved() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try WorkspaceStore(
      url: directory.appendingPathComponent("training.sqlite"), catalog: [])
    let seed = Workspace(profile: Profile(name: "Account", goal: 4))
    _ = try await store.load(seed: seed)
    _ = try await store.replaceWorkspace(with: seed, serverRevision: 3)
    var local = try await store.load(seed: seed)
    local.profile.name = "Not uploaded yet"
    _ = try await store.save(local, expectedRevision: local.revision, markingDirty: true)
    let model = AppModel()
    model.sync = AccountSync(store: store, transport: OfflineAccount())
    model.syncStatus = .idle

    let settled = await model.settleBeforeSignOut()
    XCTAssertFalse(settled)
    let metadata = try await store.syncMetadata()
    XCTAssertTrue(metadata.dirty || metadata.pending != nil)
    await model.sync?.stop()
  }

  func testSignInDownloadsTheAccountUploadsEditsAndSignOutRestoresGuestTraining() async throws {
    let base = await environment()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let storage = AccountStorage(root: directory, origin: origin)
    try FileManager.default.createDirectory(
      at: storage.directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let environment = AccountEnvironment(
      client: base.client, jar: base.jar, storage: storage, restored: nil)
    let cloud = Workspace(profile: Profile(name: "Cloud training", goal: 3))
    let cloudJSON = try XCTUnwrap(String(data: JSONEncoder().encode(cloud), encoding: .utf8))
    let profileJSON = sessionBody()
    HeldAccountRequest.state.withLock { state in
      state.response = { request in
        switch request.url?.path {
        case "/api/auth/sign-in/email":
          return ("{}", "forma.session_token=synthetic; Path=/; Secure")
        case "/api/auth/get-session": return (profileJSON, nil)
        case "/api/workspace":
          return (
            "{\"data\":\(cloudJSON),\"revision\":\(request.httpMethod == "PUT" ? 4 : 3)}", nil
          )
        default: return ("{}", nil)
        }
      }
    }
    let guest = try WorkspaceStore(
      url: directory.appendingPathComponent("guest.sqlite"), catalog: [])
    let seed = Workspace(profile: Profile(name: "Guest training", goal: 5))
    let model = AppModel()
    model.guestStore = guest
    model.store = guest
    model.workspace = try await guest.load(seed: seed)
    model.seedWorkspace = seed
    model.dataDirectory = directory
    model.accountEnvironment = environment
    model.account.attach(environment)

    try await model.account.signIn(email: "first@example.test", password: "synthetic passphrase")
    await model.syncNow()
    XCTAssertEqual(model.activeMember, first.id)
    XCTAssertEqual(model.workspace?.profile.name, "Cloud training")
    XCTAssertNil(model.accountGate)

    let committed = await model.commit { $0.profile.name = "Training edited on phone" }
    XCTAssertTrue(committed)
    await model.syncNow()
    let requests = HeldAccountRequest.state.withLock { $0.requests }
    let upload = try XCTUnwrap(requests.first { $0.httpMethod == "PUT" })
    XCTAssertEqual(upload.value(forHTTPHeaderField: "Cookie"), "forma.session_token=synthetic")
    XCTAssertEqual(upload.value(forHTTPHeaderField: "X-Forma-Member"), first.id)
    XCTAssertEqual(upload.value(forHTTPHeaderField: "X-Forma-Client"), "ios")
    XCTAssertNil(upload.value(forHTTPHeaderField: "Origin"))
    XCTAssertNil(upload.value(forHTTPHeaderField: "Referer"))

    try await model.account.signOut()
    XCTAssertEqual(model.account.phase, .signedOut)
    XCTAssertNil(model.activeMember)
    XCTAssertEqual(model.workspace?.profile.name, "Guest training")
    let unchangedGuest = try await guest.load(seed: seed)
    XCTAssertEqual(unchangedGuest.profile, seed.profile)
  }

  // MARK: Forced sign-out, saved copies and pending deletion

  func testForcedSignOutRaisesAnAnnouncedInterruptionThatNamesTheCause() async throws {
    let environment = await environment()
    let account = AccountModel()
    account.attach(environment)
    XCTAssertNil(account.interruption)

    await account.sessionEnded(.sessionEnded)

    let interruption = try XCTUnwrap(account.interruption)
    XCTAssertEqual(interruption.title, "You’ve been signed out")
    XCTAssertTrue(interruption.message.contains("30 days"))
    XCTAssertTrue(interruption.message.contains("still saved on this iPhone"))
    account.signInFromInterruption()
    XCTAssertNil(account.interruption)
    XCTAssertEqual(account.requestedAuth, .signIn)
  }

  func testInterruptionSaysWhatHappenedToAnOpenWorkout() {
    let ended = AccountInterruption.make(
      id: 1, reason: .sessionEnded, hadWorkout: true, removedCopy: false)
    XCTAssertTrue(ended.message.contains("workout in progress is saved on this iPhone"))
    let changed = AccountInterruption.make(
      id: 2, reason: .accountChanged, hadWorkout: false, removedCopy: false)
    XCTAssertTrue(changed.message.contains("no longer matched your account"))
    let deleted = AccountInterruption.make(
      id: 3, reason: .accountDeleted, hadWorkout: true, removedCopy: true)
    XCTAssertTrue(deleted.message.contains("removed from this iPhone"))
    XCTAssertTrue(deleted.message.contains("workout you had open"))
    let kept = AccountInterruption.make(
      id: 4, reason: .accountDeleted, hadWorkout: false, removedCopy: false)
    XCTAssertTrue(kept.message.contains("still has a saved copy"))
  }

  func testDeletionRequestsAreRememberedPerMemberAndExpire() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date()

    XCTAssertNil(AccountDeletionLedger.requestedAt(member: "a", in: directory, now: now))
    AccountDeletionLedger.record(member: "a", in: directory, now: now)
    XCTAssertNotNil(AccountDeletionLedger.requestedAt(member: "a", in: directory, now: now))
    XCTAssertNil(AccountDeletionLedger.requestedAt(member: "b", in: directory, now: now))
    XCTAssertNil(
      AccountDeletionLedger.requestedAt(
        member: "a", in: directory, now: now.addingTimeInterval(AccountDeletionLedger.window + 1)))
    AccountDeletionLedger.clear(member: "a", in: directory)
    XCTAssertNil(AccountDeletionLedger.requestedAt(member: "a", in: directory, now: now))
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(AccountDeletionLedger.filename).path))
  }

  func testSessionEndingAfterADeletionRequestIsTreatedAsTheAccountBeingDeleted() async throws {
    let base = await environment()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let storage = AccountStorage(root: directory, origin: origin)
    try FileManager.default.createDirectory(
      at: storage.directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let environment = AccountEnvironment(
      client: base.client, jar: base.jar, storage: storage, restored: first)
    let account = AccountModel()
    account.attach(environment)
    account.recordDeletionRequest()
    XCTAssertNotNil(account.deletionRequestedAt)

    await account.sessionEnded(.sessionEnded)

    XCTAssertEqual(account.phase, .signedOut)
    XCTAssertNil(account.deletionRequestedAt)
    XCTAssertTrue(try XCTUnwrap(account.notice).contains("asked to delete your account"))
    XCTAssertTrue(try XCTUnwrap(account.interruption).message.contains("deletion has probably"))
    XCTAssertNil(
      AccountDeletionLedger.requestedAt(member: first.id, in: storage.directory),
      "the request is spent once the session has ended")
  }

  func testSavedMemberCopiesAreFoundAndRemovedWithoutTouchingTheGuestStore() async throws {
    let base = await environment()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let storage = AccountStorage(root: directory, origin: origin)
    try FileManager.default.createDirectory(
      at: storage.directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let guest = try WorkspaceStore(
      url: storage.directory.appendingPathComponent("workspace.sqlite"), catalog: [])
    _ = try await guest.load(seed: Workspace(profile: Profile(name: "Guest", goal: 4)))
    do {
      let member = try WorkspaceStore(
        url: WorkspaceStore.memberStoreURL(directory: storage.directory, memberReference: "mem_a"),
        catalog: [])
      _ = try await member.load(seed: Workspace(profile: Profile(name: "Member", goal: 3)))
    }

    let model = AppModel()
    model.accountEnvironment = AccountEnvironment(
      client: base.client, jar: base.jar, storage: storage, restored: nil)
    await model.refreshSavedAccountCopy()
    XCTAssertTrue(model.account.hasSavedAccountCopy)

    try await model.removeSavedAccountCopies()

    XCTAssertFalse(model.account.hasSavedAccountCopy)
    XCTAssertTrue(AppModel.savedMemberCopies(directory: storage.directory).isEmpty)
    let name = try await guest.load(seed: Workspace()).profile.name
    XCTAssertEqual(name, "Guest")
  }

  func testNoticeWordsForEachForcedSignOut() {
    XCTAssertNil(AccountModel.signedOutNotice(.requested, removedCopy: false))
    XCTAssertTrue(
      try XCTUnwrap(AccountModel.signedOutNotice(.sessionEnded, removedCopy: false))
        .contains("sign in again to keep syncing"))
    XCTAssertTrue(
      try XCTUnwrap(AccountModel.signedOutNotice(.accountDeleted, removedCopy: true))
        .contains("was removed from this iPhone"))
    XCTAssertTrue(
      try XCTUnwrap(AccountModel.signedOutNotice(.accountDeleted, removedCopy: false))
        .contains("remove it below"))
  }

  func testAccountDeletedCodeEndsTheSessionAsADeletion() {
    let failure = AccountFailure(
      kind: .unauthorized, message: "Your session has ended. Sign in again.", status: 401,
      code: "account_deleted")
    XCTAssertEqual(failure.signOutReason, .accountDeleted)
    XCTAssertEqual(
      AccountFailure(kind: .accountChanged, message: "x").signOutReason, .accountChanged)
    XCTAssertEqual(AccountFailure(kind: .unauthorized, message: "x").signOutReason, .sessionEnded)
  }

  func testRejectedCredentialsAreTheOnlyFailuresThatClearATypedPassword() {
    XCTAssertTrue(AccountFailure(kind: .rejected, message: "x").rejectsCredentials)
    XCTAssertTrue(AccountFailure(kind: .unauthorized, message: "x").rejectsCredentials)
    XCTAssertFalse(AccountWire.offlineFailure().rejectsCredentials)
    XCTAssertFalse(AccountFailure(kind: .server, message: "x").rejectsCredentials)
    XCTAssertFalse(AccountFailure(kind: .rateLimited, message: "x").rejectsCredentials)
  }
}
