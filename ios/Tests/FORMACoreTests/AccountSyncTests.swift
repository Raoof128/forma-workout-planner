import CSQLite
import Foundation
import XCTest

@testable import FORMACore

/// An account that behaves like `server/workspace.ts`: it counts its own
/// revisions, rewrites `data.revision` on every save, replays an operation it
/// already applied, and refuses an identifier reused for other bytes. Faults are
/// scripted per request, in order.
actor FakeServer: WorkspaceTransport {
  enum Fault: Equatable {
    case offline, offlineAfterApply, unauthorized, accountChanged, operationReused
    case rateLimited(TimeInterval?), invalid(String), transient(String)
  }

  private(set) var workspace: Workspace
  private(set) var revision: Int
  private(set) var puts: [WorkspacePut] = []
  private(set) var fetches = 0
  private(set) var holding = false
  private var applied: [String: (payload: Data, expected: Int, revision: Int)] = [:]
  private var putFaults: [Fault] = []
  private var fetchFaults: [Fault] = []
  private var holdNext = false
  private var held: CheckedContinuation<Void, Never>?

  init(workspace: Workspace, revision: Int) {
    var stored = workspace
    stored.revision = revision
    self.workspace = stored
    self.revision = revision
  }

  func scriptPuts(_ faults: Fault...) { putFaults = faults }
  func scriptFetches(_ faults: Fault...) { fetchFaults = faults }
  func holdNextPut() { holdNext = true }
  func releaseHeldPut() {
    held?.resume()
    held = nil
  }

  /// Another device saves: the account moves on without this phone knowing.
  func externalEdit(name: String) {
    revision += 1
    workspace.profile.name = name
    workspace.revision = revision
  }

  private func current() -> RemoteWorkspace {
    RemoteWorkspace(workspace: workspace, revision: revision, updatedAt: "2026-10-28T00:00:00.000000Z")
  }

  private func throwing(_ fault: Fault) throws -> Never {
    switch fault {
    case .offline, .offlineAfterApply: throw WorkspaceTransportError.offline
    case .unauthorized: throw WorkspaceTransportError.unauthorized
    case .accountChanged: throw WorkspaceTransportError.accountChanged
    case .operationReused: throw WorkspaceTransportError.operationReused
    case .rateLimited(let after): throw WorkspaceTransportError.rateLimited(retryAfter: after)
    case .invalid(let message): throw WorkspaceTransportError.invalid(message)
    case .transient(let message): throw WorkspaceTransportError.transient(message)
    }
  }

  func fetch() async throws -> RemoteWorkspace {
    fetches += 1
    if !fetchFaults.isEmpty { try throwing(fetchFaults.removeFirst()) }
    return current()
  }

  func put(_ request: WorkspacePut) async throws -> RemoteWorkspace {
    puts.append(request)
    let fault = putFaults.isEmpty ? nil : putFaults.removeFirst()
    if let fault, fault != .offlineAfterApply { try throwing(fault) }
    if holdNext {
      holdNext = false
      holding = true
      await withCheckedContinuation { held = $0 }
      holding = false
    }
    var result: RemoteWorkspace
    if let prior = applied[request.operationId] {
      guard prior.payload == request.payload, prior.expected == request.expectedRevision else {
        throw WorkspaceTransportError.operationReused
      }
      result = RemoteWorkspace(workspace: workspace, revision: prior.revision, updatedAt: nil)
    } else if request.expectedRevision != revision {
      throw WorkspaceTransportError.staleRevision(latest: current())
    } else {
      var next = try JSONDecoder().decode(Workspace.self, from: request.payload)
      revision += 1
      next.revision = revision
      workspace = next
      applied[request.operationId] = (request.payload, request.expectedRevision, revision)
      result = current()
    }
    if fault == .offlineAfterApply { throw WorkspaceTransportError.offline }
    return result
  }
}

/// Predictable operation identifiers, so tests can tell a retry from a new upload.
final class OperationIds: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  let prefix: String
  init(_ prefix: String = "op") { self.prefix = prefix }
  func next() -> String {
    lock.lock()
    defer { lock.unlock() }
    count += 1
    return "\(prefix)-\(count)"
  }
}

final class AccountSyncTests: XCTestCase, @unchecked Sendable {
  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "forma-sync-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory
  }

  private func accountWorkspace(name: String = "Account") -> Workspace {
    var workspace = Fixtures.workspace()
    workspace.profile.name = name
    return workspace
  }

  /// A signed-in phone: a fresh member store that has done its full fetch from an
  /// account at revision 3.
  private struct Phone {
    var url: URL
    var store: WorkspaceStore
    var server: FakeServer
    var sync: AccountSync
    var ids: OperationIds
  }

  private func signedInPhone(serverRevision: Int = 3) async throws -> Phone {
    let directory = try temporaryDirectory()
    let url = WorkspaceStore.memberStoreURL(directory: directory, memberReference: "member-1")
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    _ = try await store.load(seed: Workspace(profile: Profile(name: "Member", goal: 4)))
    let server = FakeServer(workspace: accountWorkspace(), revision: serverRevision)
    let ids = OperationIds()
    let sync = AccountSync(store: store, transport: server, makeOperationId: { ids.next() })
    let status = await sync.initialFetch()
    XCTAssertEqual(status, .idle)
    return Phone(url: url, store: store, server: server, sync: sync, ids: ids)
  }

  /// The app's commit path: save locally, flagging the change for the account.
  @discardableResult
  private func edit(_ store: WorkspaceStore, name: String, markDirty: Bool = true) async throws
    -> Workspace
  {
    let current = try await store.load(seed: Workspace())
    var candidate = current
    candidate.profile.name = name
    return try await store.save(
      candidate, expectedRevision: current.revision, markingDirty: markDirty)
  }

  private func localName(_ store: WorkspaceStore) async throws -> String {
    try await store.load(seed: Workspace()).profile.name
  }

  private func waitUntil(_ condition: () async -> Bool) async {
    for _ in 0..<5_000 {
      if await condition() { return }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    XCTFail("Timed out waiting for the condition")
  }

  // MARK: Sending

  func testAcknowledgementRecordsServerRevisionAndClearsPending() async throws {
    let phone = try await signedInPhone()
    var metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 3, dirty: false, pending: nil))

    try await edit(phone.store, name: "Logged a set")
    await phone.sync.markDirty()
    let status = await phone.sync.flush()

    XCTAssertEqual(status, .idle)
    metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 1)
    XCTAssertEqual(puts[0].expectedRevision, 3)
    XCTAssertEqual(puts[0].operationId, "op-1")
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Logged a set")
    // Nothing waiting: another flush sends nothing.
    _ = await phone.sync.flush()
    let again = await phone.server.puts.count
    XCTAssertEqual(again, 1)
  }

  func testTransientFailureKeepsExactBytesAndOperationThenRetriesIdentically() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Offline edit")
    await phone.server.scriptPuts(.offline, .transient("503"))

    var status = await phone.sync.flush()
    XCTAssertEqual(status, .waiting(.offline))
    let pending = try await phone.store.syncMetadata().pending
    XCTAssertNotNil(pending)
    status = await phone.sync.flush()
    XCTAssertEqual(status, .waiting(.transient("503")))
    status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)

    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 3)
    XCTAssertEqual(puts[1], puts[0])
    XCTAssertEqual(puts[2], puts[0])
    XCTAssertEqual(puts[0].operationId, pending?.operationId)
    XCTAssertEqual(puts[0].payload, pending?.payload)
    // One operation, never one per attempt.
    XCTAssertEqual(phone.ids.next(), "op-2")
    let revision = await phone.server.revision
    XCTAssertEqual(revision, 4)
  }

  func testPendingOperationSurvivesReopeningTheStoreFromDisk() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Survives a relaunch")
    await phone.server.scriptPuts(.offline)
    _ = await phone.sync.flush()
    let first = await phone.server.puts[0]

    // A new process: new store connection, new engine, same file.
    let reopened = try WorkspaceStore(url: phone.url, catalog: Fixtures.catalog)
    let ids = OperationIds("after-restart")
    let engine = AccountSync(
      store: reopened, transport: phone.server, makeOperationId: { ids.next() })
    let persisted = try await reopened.syncMetadata()
    XCTAssertEqual(persisted.serverRevision, 3)
    XCTAssertEqual(persisted.pending?.operationId, first.operationId)
    XCTAssertEqual(persisted.pending?.payload, first.payload)

    let status = await engine.flush()
    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 2)
    XCTAssertEqual(puts[1], first)
    XCTAssertEqual(ids.next(), "after-restart-1", "a restart must not mint a new operation")
    let metadata = try await reopened.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
  }

  func testLostAcknowledgementIsReplayedNotAppliedTwice() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Applied before the network dropped")
    await phone.server.scriptPuts(.offlineAfterApply)

    var status = await phone.sync.flush()
    XCTAssertEqual(status, .waiting(.offline))
    var revision = await phone.server.revision
    XCTAssertEqual(revision, 4, "the server did apply it")

    status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)
    revision = await phone.server.revision
    XCTAssertEqual(revision, 4, "replaying the operation must not apply it again")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata.serverRevision, 4)
  }

  func testRefreshAfterALostAcknowledgementResendsInsteadOfFalseConflict() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    await phone.server.scriptPuts(.offlineAfterApply)
    _ = await phone.sync.flush()

    // The account is now at 4, past the pending operation's expected 3, but only
    // because of that very operation.
    let status = await phone.sync.refresh()
    XCTAssertEqual(status, .idle)
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Mine")
  }

  func testEditsDuringAnInFlightPutAreSentNextWithTheNewExpectedRevision() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "First")
    await phone.server.holdNextPut()
    let flushing = Task { await phone.sync.flush() }
    await waitUntil { await phone.server.holding }

    // The member keeps training while the first upload is in flight.
    try await edit(phone.store, name: "Second")
    await phone.sync.markDirty()
    await phone.server.releaseHeldPut()
    let status = await flushing.value

    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 2)
    XCTAssertEqual(puts[0].expectedRevision, 3)
    XCTAssertEqual(puts[1].expectedRevision, 4)
    XCTAssertNotEqual(puts[1].operationId, puts[0].operationId)
    let first = try JSONDecoder().decode(Workspace.self, from: puts[0].payload)
    let second = try JSONDecoder().decode(Workspace.self, from: puts[1].payload)
    XCTAssertEqual(first.profile.name, "First")
    XCTAssertEqual(second.profile.name, "Second")
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Second")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 5, dirty: false, pending: nil))
  }

  func testConcurrentFlushesAreSerialised() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Once")
    async let a = phone.sync.flush()
    async let b = phone.sync.flush()
    async let c = phone.sync.flush()
    let results = await [a, b, c]
    XCTAssertEqual(results, [.idle, .idle, .idle])
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 1)
  }

  func testAnEditSavedWithoutTheFlagIsStillNoticed() async throws {
    let phone = try await signedInPhone()
    // A crash between the save and markDirty() would leave exactly this.
    try await edit(phone.store, name: "Unflagged", markDirty: false)
    let metadata = try await phone.store.syncMetadata()
    XCTAssertTrue(metadata.dirty)
    let status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Unflagged")
  }

  func testAMemberStoreNeverUploadsItsPlaceholderBeforeTheFullFetch() async throws {
    let directory = try temporaryDirectory()
    let url = WorkspaceStore.memberStoreURL(directory: directory, memberReference: "fresh")
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    _ = try await store.load(seed: Workspace())
    try await edit(store, name: "Typed before the download finished")
    let server = FakeServer(workspace: accountWorkspace(), revision: 9)
    let sync = AccountSync(store: store, transport: server)
    let status = await sync.flush()
    guard case .failed = status else { return XCTFail("expected a failure, got \(status)") }
    let puts = await server.puts
    XCTAssertTrue(puts.isEmpty)
  }

  // MARK: Failures

  func testStaleRevisionEntersConflictAndKeepsLocalWork() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    await phone.server.externalEdit(name: "Theirs")

    let status = await phone.sync.flush()

    guard case .conflict(let latest) = status else { return XCTFail("expected conflict: \(status)") }
    XCTAssertEqual(latest.revision, 4)
    XCTAssertEqual(latest.workspace.profile.name, "Theirs")
    var name = try await localName(phone.store)
    XCTAssertEqual(name, "Mine", "a conflict never overwrites the local copy")
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Theirs")
    // Further flushes wait for the member's choice instead of resending.
    _ = await phone.sync.flush()
    _ = await phone.sync.refresh()
    var puts = await phone.server.puts.count
    XCTAssertEqual(puts, 1)

    // A restart forgets the in-memory conflict; the pending upload finds it again.
    let reopened = try WorkspaceStore(url: phone.url, catalog: Fixtures.catalog)
    let engine = AccountSync(store: reopened, transport: phone.server)
    let again = await engine.flush()
    guard case .conflict = again else { return XCTFail("expected conflict after restart") }
    puts = await phone.server.puts.count
    XCTAssertEqual(puts, 2)
    name = try await localName(reopened)
    XCTAssertEqual(name, "Mine")
  }

  func testResolvingAConflictWithTheAccountCopyReplacesLocal() async throws {
    let phone = try await signedInPhone()
    let before = try await phone.store.load(seed: Workspace())
    try await edit(phone.store, name: "Mine")
    await phone.server.externalEdit(name: "Theirs")
    _ = await phone.sync.flush()

    let status = await phone.sync.resolveConflictUsingAccount()

    XCTAssertEqual(status, .idle)
    let local = try await phone.store.load(seed: Workspace())
    XCTAssertEqual(local.profile.name, "Theirs")
    XCTAssertGreaterThan(local.revision, before.revision, "local revision only counts up")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
    // The replaced copy stays recoverable.
    let previous = try await phone.store.previousSnapshot()
    XCTAssertEqual(previous?.profile.name, "Mine")
    // Editing resumes against the new revision.
    try await edit(phone.store, name: "After resolving")
    let resumed = await phone.sync.flush()
    XCTAssertEqual(resumed, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts.last?.expectedRevision, 4)
  }

  func testResolvingAConflictByKeepingLocalResendsAgainstTheLatestRevision() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    await phone.server.externalEdit(name: "Theirs")
    _ = await phone.sync.flush()
    // More local edits after the conflict are included, not lost.
    try await edit(phone.store, name: "Mine, edited again")

    let status = await phone.sync.resolveConflictKeepingLocal()

    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 2)
    XCTAssertEqual(puts[1].expectedRevision, 4)
    XCTAssertNotEqual(puts[1].operationId, puts[0].operationId)
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Mine, edited again")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 5, dirty: false, pending: nil))
  }

  func testKeepingLocalIsAConflictAgainIfTheAccountMovesAgain() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    await phone.server.externalEdit(name: "Theirs")
    _ = await phone.sync.flush()
    await phone.server.externalEdit(name: "Theirs again")
    let status = await phone.sync.resolveConflictKeepingLocal()
    guard case .conflict(let latest) = status else { return XCTFail("expected conflict") }
    XCTAssertEqual(latest.revision, 5)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Mine")
  }

  func testResolvingWithoutAConflictChangesNothing() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Untouched")
    var status = await phone.sync.resolveConflictUsingAccount()
    XCTAssertEqual(status, .idle)
    status = await phone.sync.resolveConflictKeepingLocal()
    XCTAssertEqual(status, .idle)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Untouched")
  }

  func testAccountChangedSignsOutAndKeepsTheMemberCache() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Unsent")
    await phone.server.scriptPuts(.accountChanged)

    let status = await phone.sync.flush()

    XCTAssertEqual(status, .signedOut(.accountChanged))
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Unsent")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertNotNil(metadata.pending, "the unsent work stays on disk")
    // Signed out: nothing more is sent or fetched.
    _ = await phone.sync.flush()
    _ = await phone.sync.refresh()
    let puts = await phone.server.puts.count
    XCTAssertEqual(puts, 1)
  }

  func testUnauthorizedOnRefreshSignsOut() async throws {
    let phone = try await signedInPhone()
    await phone.server.scriptFetches(.unauthorized)
    let status = await phone.sync.refresh()
    XCTAssertEqual(status, .signedOut(.unauthorized))
  }

  func testRateLimitedKeepsThePendingOperation() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Busy")
    await phone.server.scriptPuts(.rateLimited(60))
    var status = await phone.sync.flush()
    XCTAssertEqual(status, .waiting(.rateLimited(retryAfter: 60)))
    status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts[0], puts[1])
  }

  func testRefusedPayloadDropsThePendingOperationButKeepsTheEditLocal() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Refused")
    await phone.server.scriptPuts(.invalid("Workspace payload is invalid."))

    var status = await phone.sync.flush()

    XCTAssertEqual(status, .failed("Workspace payload is invalid."))
    var metadata = try await phone.store.syncMetadata()
    XCTAssertNil(metadata.pending)
    XCTAssertTrue(metadata.dirty)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Refused")
    status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)
    metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata.serverRevision, 4)
  }

  func testReusedOperationIdentifierStartsOverWithAFreshOne() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Again")
    await phone.server.scriptPuts(.operationReused)
    var status = await phone.sync.flush()
    guard case .failed = status else { return XCTFail("expected failure, got \(status)") }
    let metadata = try await phone.store.syncMetadata()
    XCTAssertNil(metadata.pending)
    XCTAssertTrue(metadata.dirty)
    status = await phone.sync.flush()
    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertNotEqual(puts[0].operationId, puts[1].operationId)
  }

  // MARK: Reading

  func testRefreshReplacesALocalCopyThatIsClean() async throws {
    let phone = try await signedInPhone()
    let before = try await phone.store.load(seed: Workspace())
    await phone.server.externalEdit(name: "Logged on the website")

    let status = await phone.sync.refresh()

    XCTAssertEqual(status, .idle)
    let local = try await phone.store.load(seed: Workspace())
    XCTAssertEqual(local.profile.name, "Logged on the website")
    XCTAssertEqual(local.revision, before.revision + 1)
    var metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
    // Nothing new on the account: the local copy is left alone.
    _ = await phone.sync.refresh()
    let unchanged = try await phone.store.load(seed: Workspace())
    XCTAssertEqual(unchanged, local)
    metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata.serverRevision, 4)
  }

  func testRefreshWithUnsentLocalWorkAndAMovedAccountIsAConflictWithoutSending() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    await phone.server.externalEdit(name: "Theirs")

    let status = await phone.sync.refresh()

    guard case .conflict(let latest) = status else { return XCTFail("expected conflict: \(status)") }
    XCTAssertEqual(latest.workspace.profile.name, "Theirs")
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Mine")
    let puts = await phone.server.puts
    XCTAssertTrue(puts.isEmpty)
  }

  func testRefreshWithUnsentLocalWorkAndAnUnmovedAccountSendsIt() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Mine")
    let status = await phone.sync.refresh()
    XCTAssertEqual(status, .idle)
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Mine")
  }

  func testRefreshIgnoresAnOlderAccountRevision() async throws {
    let phone = try await signedInPhone(serverRevision: 5)
    // A read that began before the member's own newer save comes back older.
    let stale = FakeServer(workspace: accountWorkspace(name: "Older"), revision: 2)
    let engine = AccountSync(store: phone.store, transport: stale)
    let status = await engine.refresh()
    XCTAssertEqual(status, .idle)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Account")
  }

  func testInitialFetchReplacesTheMemberStoreCompletely() async throws {
    let directory = try temporaryDirectory()
    let url = WorkspaceStore.memberStoreURL(directory: directory, memberReference: "abc")
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    _ = try await store.load(seed: Workspace(profile: Profile(name: "Placeholder", goal: 4)))
    let server = FakeServer(workspace: accountWorkspace(name: "From the account"), revision: 41)
    let sync = AccountSync(store: store, transport: server)

    let status = await sync.initialFetch()

    XCTAssertEqual(status, .idle)
    var local = try await store.load(seed: Workspace())
    XCTAssertEqual(local.profile.name, "From the account")
    XCTAssertEqual(local.routines, Fixtures.workspace().routines)
    let metadata = try await store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 41, dirty: false, pending: nil))
    // The account's counter and the local one are separate numbers.
    XCTAssertEqual(local.revision, 1)
    local.revision = 41
    let account = await server.workspace
    XCTAssertEqual(local, account)
  }

  func testInitialFetchDoesNotDiscardUnsyncedWorkFromAnEarlierSession() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Made before the 401")
    await phone.server.scriptPuts(.unauthorized)
    var status = await phone.sync.flush()
    XCTAssertEqual(status, .signedOut(.unauthorized))

    // The member signs in again to the same cache.
    status = await phone.sync.initialFetch()

    XCTAssertEqual(status, .idle)
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Made before the 401")
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Made before the 401")
  }

  func testInitialFetchCanDiscardUnsyncedWorkWhenAskedTo() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Throw me away")
    let status = await phone.sync.initialFetch(discardingLocalChanges: true)
    XCTAssertEqual(status, .idle)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Account")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 3, dirty: false, pending: nil))
  }

  // MARK: Import

  func testReplaceAccountSendsTheImportAgainstTheCurrentRevisionThenAdoptsIt() async throws {
    let phone = try await signedInPhone()
    var imported = Fixtures.workspace()
    imported.profile.name = "Imported backup"
    imported.revision = 900  // a backup's own revision is informational only

    let status = await phone.sync.replaceAccount(with: imported, reviewedRevision: 3)

    XCTAssertEqual(status, .idle)
    let puts = await phone.server.puts
    XCTAssertEqual(puts.count, 1)
    XCTAssertEqual(puts[0].expectedRevision, 3)
    let account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Imported backup")
    let revision = await phone.server.revision
    XCTAssertEqual(revision, 4)
    let local = try await phone.store.load(seed: Workspace())
    XCTAssertEqual(local.profile.name, "Imported backup")
    let metadata = try await phone.store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: 4, dirty: false, pending: nil))
  }

  func testReplaceAccountRefusesAStaleReviewAndChangesNothing() async throws {
    let phone = try await signedInPhone()
    var imported = Fixtures.workspace()
    imported.profile.name = "Imported backup"

    let status = await phone.sync.replaceAccount(with: imported, reviewedRevision: 2)

    guard case .failed = status else { return XCTFail("expected a refusal, got \(status)") }
    let puts = await phone.server.puts
    XCTAssertTrue(puts.isEmpty)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Account")
    let shown = await phone.sync.status
    XCTAssertEqual(shown, .idle)
  }

  func testReplaceAccountOverAMovedAccountIsAConflictNotAnOverwrite() async throws {
    let phone = try await signedInPhone()
    await phone.server.externalEdit(name: "Newer on the website")
    var imported = Fixtures.workspace()
    imported.profile.name = "Imported backup"

    let status = await phone.sync.replaceAccount(with: imported)

    guard case .conflict(let latest) = status else { return XCTFail("expected conflict: \(status)") }
    XCTAssertEqual(latest.workspace.profile.name, "Newer on the website")
    var account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Newer on the website")
    // Declining the import returns to the account's copy.
    let used = await phone.sync.resolveConflictUsingAccount()
    XCTAssertEqual(used, .idle)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Newer on the website")
    account = await phone.server.workspace
    XCTAssertEqual(account.profile.name, "Newer on the website")
  }

  func testReplaceAccountRejectsAnInvalidWorkspaceBeforeTouchingAnything() async throws {
    let phone = try await signedInPhone()
    var invalid = Fixtures.workspace()
    invalid.version = 99
    let status = await phone.sync.replaceAccount(with: invalid)
    guard case .failed = status else { return XCTFail("expected a refusal, got \(status)") }
    let puts = await phone.server.puts
    XCTAssertTrue(puts.isEmpty)
    let name = try await localName(phone.store)
    XCTAssertEqual(name, "Account")
  }

  // MARK: Status

  func testStatusUpdatesFollowTheLatestState() async throws {
    let phone = try await signedInPhone()
    let updates = await phone.sync.statusUpdates()
    var iterator = updates.makeAsyncIterator()
    let initial = await iterator.next()
    XCTAssertEqual(initial, .idle)

    try await edit(phone.store, name: "Watched")
    await phone.server.scriptPuts(.offline)
    _ = await phone.sync.flush()
    let waiting = await iterator.next()
    XCTAssertEqual(waiting, .waiting(.offline))

    _ = await phone.sync.flush()
    let saved = await iterator.next()
    XCTAssertEqual(saved, .idle)
  }

  // MARK: Storage

  func testVersionOneGuestStoreMigratesWithoutLosingAnything() async throws {
    let directory = try temporaryDirectory()
    let url = directory.appendingPathComponent("workspace.sqlite")
    var older = Fixtures.workspace()
    older.profile.name = "Before the last save"
    older.revision = 4
    var newest = Fixtures.active(now: 1_000)
    newest.profile.name = "Guest athlete"
    newest.revision = 5
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let oldRaw = try encoder.encode(older)
    let newRaw = try encoder.encode(newest)
    // The schema exactly as shipped before accounts existed.
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    XCTAssertEqual(
      sqlite3_exec(
        database,
        "CREATE TABLE workspace (id INTEGER PRIMARY KEY CHECK (id = 1), revision INTEGER NOT NULL CHECK (revision >= 0), snapshot BLOB NOT NULL, previous_snapshot BLOB); PRAGMA user_version = 1",
        nil, nil, nil), SQLITE_OK)
    var statement: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(
        database, "INSERT INTO workspace (id, revision, snapshot, previous_snapshot) VALUES (1, 5, ?, ?)",
        -1, &statement, nil), SQLITE_OK)
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    _ = newRaw.withUnsafeBytes { sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32($0.count), transient) }
    _ = oldRaw.withUnsafeBytes { sqlite3_bind_blob(statement, 2, $0.baseAddress, Int32($0.count), transient) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    sqlite3_finalize(statement)
    sqlite3_close(database)

    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let loaded = try await store.load(seed: Workspace())
    XCTAssertEqual(loaded, newest)
    let previous = try await store.previousSnapshot()
    XCTAssertEqual(previous, older)
    let metadata = try await store.syncMetadata()
    XCTAssertEqual(metadata, SyncMetadata(serverRevision: nil, dirty: false, pending: nil))

    // The guest store still saves, and reopens as a current-version store.
    var candidate = loaded
    candidate.profile.name = "Saved after migrating"
    let saved = try await store.save(candidate, expectedRevision: loaded.revision)
    XCTAssertEqual(saved.revision, 6)
    let reopened = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let again = try await reopened.load(seed: Workspace())
    XCTAssertEqual(again, saved)
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    XCTAssertEqual(sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    XCTAssertEqual(sqlite3_column_int(statement, 0), 2)
    sqlite3_finalize(statement)
    sqlite3_close(database)
  }

  func testGuestSavesWithoutAccountSyncStayUntouched() async throws {
    let directory = try temporaryDirectory()
    let store = try WorkspaceStore(
      url: directory.appendingPathComponent("workspace.sqlite"), catalog: Fixtures.catalog)
    let loaded = try await store.load(seed: Fixtures.workspace())
    var candidate = loaded
    candidate.profile.name = "Guest"
    let saved = try await store.save(candidate, expectedRevision: loaded.revision)
    XCTAssertEqual(saved.revision, 1)
    let metadata = try await store.syncMetadata()
    XCTAssertNil(metadata.serverRevision)
    XCTAssertNil(metadata.pending)
  }

  func testMemberStoreURLsAreSafeDistinctAndCaseInsensitiveFriendly() {
    let directory = URL(fileURLWithPath: "/tmp/forma-members", isDirectory: true)
    func name(_ reference: String) -> String {
      WorkspaceStore.memberStoreURL(directory: directory, memberReference: reference)
        .lastPathComponent
    }
    XCTAssertEqual(name("abc-123"), "member-abc-123.sqlite")
    let hostile = ["../../etc/passwd", "a/b", "a\\b", "a.b", "a b", "ünï", "", "%41", "A", "a"]
    var seen = Set<String>()
    for reference in hostile {
      let url = WorkspaceStore.memberStoreURL(directory: directory, memberReference: reference)
      XCTAssertEqual(url.deletingLastPathComponent().path, directory.path)
      let file = url.lastPathComponent
      XCTAssertTrue(file.hasPrefix("member-") && file.hasSuffix(".sqlite"))
      let stem = String(file.dropFirst("member-".count).dropLast(".sqlite".count))
      XCTAssertFalse(stem.contains("/") || stem.contains(".") || stem.contains("\\"), file)
      XCTAssertTrue(seen.insert(file.lowercased()).inserted, "\(reference) collides: \(file)")
    }
    let long = String(repeating: "x", count: 500)
    let other = long + "y"
    XCTAssertLessThan(name(long).count, 120)
    XCTAssertNotEqual(name(long), name(other))
    XCTAssertEqual(name(long), name(long))
  }

  // MARK: Contract

  func testPayloadIsTheWorkspaceVersionTwoContractAndRequestBodyWrapsItUntouched() async throws {
    let phone = try await signedInPhone()
    try await edit(phone.store, name: "Contract \"check\"")
    await phone.server.scriptPuts(.offline)
    _ = await phone.sync.flush()
    let put = await phone.server.puts[0]

    let local = try await phone.store.load(seed: Workspace())
    XCTAssertEqual(try JSONDecoder().decode(Workspace.self, from: put.payload), local)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: put.payload) as? [String: Any])
    XCTAssertEqual(
      Set(object.keys),
      ["version", "revision", "routines", "history", "active", "profile", "schedule"])
    XCTAssertEqual(object["version"] as? Int, 2)
    XCTAssertTrue(object["active"] is NSNull, "the web envelope requires the active key")

    let body = put.requestBody()
    let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(Set(parsed.keys), ["data", "expectedRevision", "operationId"])
    XCTAssertEqual(parsed["expectedRevision"] as? Int, 3)
    XCTAssertEqual(parsed["operationId"] as? String, put.operationId)
    let data = try XCTUnwrap(parsed["data"] as? NSDictionary)
    XCTAssertEqual(data, object as NSDictionary)
    XCTAssertNotNil(body.range(of: put.payload), "the payload bytes are spliced in unchanged")

    let tricky = WorkspacePut(operationId: "a\"b\\c\nd", expectedRevision: 0, payload: Data("{}".utf8))
    let trickyObject = try XCTUnwrap(
      JSONSerialization.jsonObject(with: tricky.requestBody()) as? [String: Any])
    XCTAssertEqual(trickyObject["operationId"] as? String, "a\"b\\c\nd")
  }

  func testWireDecodesAccountResponsesAndMapsFailures() throws {
    let workspaceJSON = String(decoding: try WorkspaceExport.encode(Fixtures.workspace()), as: UTF8.self)
    let ok = Data(
      "{\"data\":\(workspaceJSON),\"revision\":7,\"updatedAt\":\"2026-10-28T10:00:00.000000Z\"}".utf8)
    let remote = try WorkspaceWire.decodeRemote(ok)
    XCTAssertEqual(remote.revision, 7)
    XCTAssertEqual(remote.updatedAt, "2026-10-28T10:00:00.000000Z")
    XCTAssertEqual(remote.workspace.routines, Fixtures.workspace().routines)
    XCTAssertThrowsError(try WorkspaceWire.decodeRemote(Data("{\"revision\":1}".utf8)))

    let stale = Data(
      "{\"error\":\"stale_revision\",\"message\":\"Workspace changed since it was loaded.\",\"data\":\(workspaceJSON),\"revision\":8,\"updatedAt\":null}"
        .utf8)
    XCTAssertEqual(
      WorkspaceWire.transportError(status: 409, body: stale),
      .staleRevision(latest: RemoteWorkspace(workspace: Fixtures.workspace(), revision: 8)))
    XCTAssertEqual(
      WorkspaceWire.transportError(status: 409, body: Data("{\"error\":\"account_changed\"}".utf8)),
      .accountChanged)
    XCTAssertEqual(
      WorkspaceWire.transportError(status: 401, body: Data("{\"error\":\"unauthorized\"}".utf8)),
      .unauthorized)
    XCTAssertEqual(
      WorkspaceWire.transportError(
        status: 409, body: Data("{\"error\":\"operation_id_reused\",\"revision\":2}".utf8)),
      .operationReused)
    XCTAssertEqual(
      WorkspaceWire.transportError(
        status: 400,
        body: Data("{\"error\":\"invalid_workspace\",\"message\":\"Workspace payload is invalid.\"}".utf8)),
      .invalid("Workspace payload is invalid."))
    XCTAssertEqual(
      WorkspaceWire.transportError(status: 429, body: nil, retryAfter: "60"),
      .rateLimited(retryAfter: 60))
    XCTAssertEqual(
      WorkspaceWire.transportError(status: 429, body: nil, retryAfter: nil),
      .rateLimited(retryAfter: nil))
    guard case .transient = WorkspaceWire.transportError(status: 503, body: nil) else {
      return XCTFail("5xx is transient")
    }
    guard case .transient = WorkspaceWire.transportError(status: 409, body: Data("{}".utf8)) else {
      return XCTFail("a conflict with no copy cannot be shown")
    }
  }
}
