import FORMACore
import Foundation
import XCTest

@testable import FORMA

/// No service is contacted. Every PUT first verifies that the protected local
/// ownership reservation was already readable before any upload could occur.
private actor PhoneImportTransport: WorkspaceTransport {
  let directory: URL
  let offline: Bool
  private(set) var puts = 0
  private(set) var reservationSeen = false

  init(directory: URL, offline: Bool) {
    self.directory = directory
    self.offline = offline
  }

  func fetch() async throws -> RemoteWorkspace { throw WorkspaceTransportError.offline }

  func put(_ request: WorkspacePut) async throws -> RemoteWorkspace {
    let directory = directory
    let record = try await MainActor.run { try PhoneTrainingLedger.read(in: directory) }
    guard record?.member == "member-a", record?.status == .reserved else {
      throw WorkspaceTransportError.invalid("Upload reached transport without ownership reserved")
    }
    puts += 1
    reservationSeen = true
    if offline { throw WorkspaceTransportError.offline }
    return RemoteWorkspace(
      workspace: try JSONDecoder().decode(Workspace.self, from: request.payload),
      revision: request.expectedRevision + 1)
  }
}

@MainActor
final class PhoneTrainingLedgerTests: XCTestCase {
  private func directory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }

  func testReservationPersistsBeforeCompletionAndOnlyItsMemberCanRetry() throws {
    let directory = try directory()
    let reserved = try PhoneTrainingLedger.reserve(member: "member-a", in: directory)
    XCTAssertEqual(try PhoneTrainingLedger.read(in: directory), reserved)
    XCTAssertEqual(reserved.status, .reserved)
    XCTAssertEqual(
      try PhoneTrainingLedger.reserve(member: "member-a", in: directory), reserved)
    XCTAssertThrowsError(try PhoneTrainingLedger.reserve(member: "member-b", in: directory))
    try PhoneTrainingLedger.complete(reserved, in: directory)
    XCTAssertEqual(try PhoneTrainingLedger.read(in: directory)?.status, .imported)
    XCTAssertThrowsError(try PhoneTrainingLedger.reserve(member: "member-a", in: directory))
    XCTAssertThrowsError(try PhoneTrainingLedger.reserve(member: "member-b", in: directory))
  }

  func testLegacySuccessfulImportRemainsOwnedWithoutAStatusKey() throws {
    let directory = try directory()
    let legacy = #"{"member":"member-a","importedAt":"2026-10-28T00:00:00Z"}"#
    try Data(legacy.utf8).write(to: PhoneTrainingLedger.url(in: directory))
    let record = try XCTUnwrap(PhoneTrainingLedger.read(in: directory))
    XCTAssertEqual(record.status, .imported)
    XCTAssertThrowsError(try PhoneTrainingLedger.reserve(member: "member-b", in: directory))
    XCTAssertEqual(try Data(contentsOf: PhoneTrainingLedger.url(in: directory)), Data(legacy.utf8))
  }

  func testCorruptOwnershipNeverBecomesAnUnclaimedImport() throws {
    let directory = try directory()
    let original = Data("unreadable ownership fixture".utf8)
    try original.write(to: PhoneTrainingLedger.url(in: directory))
    XCTAssertThrowsError(try PhoneTrainingLedger.read(in: directory))
    XCTAssertThrowsError(try PhoneTrainingLedger.reserve(member: "member-a", in: directory))
    XCTAssertEqual(try Data(contentsOf: PhoneTrainingLedger.url(in: directory)), original)
  }

  private struct Fixture {
    let model: AppModel
    let memberStore: WorkspaceStore
    let guestStore: WorkspaceStore
    let phone: Workspace
    let transport: PhoneImportTransport
    let directory: URL
  }

  private func fixture(ledgerDirectoryExists: Bool = true, offline: Bool = false) async throws
    -> Fixture
  {
    let root = try directory()
    let origin = URL(string: "https://phone-import.example.test")!
    let storage = AccountStorage(root: root, origin: origin)
    if ledgerDirectoryExists {
      try FileManager.default.createDirectory(
        at: storage.directory, withIntermediateDirectories: true)
    }
    let jar = CookieJar(vault: MemorySessionVault(), installMarker: nil)
    let environment = AccountEnvironment(
      client: AccountClient(origin: origin, jar: jar), jar: jar, storage: storage, restored: nil)
    let memberStore = try WorkspaceStore(
      url: root.appendingPathComponent("member.sqlite"), catalog: [])
    let cloud = Workspace(profile: Profile(name: "Account before import", goal: 4))
    _ = try await memberStore.load(seed: cloud)
    _ = try await memberStore.replaceWorkspace(with: cloud, serverRevision: 8)
    let phone = Workspace(revision: 1, profile: Profile(name: "Guest training", goal: 3))
    let guestStore = try WorkspaceStore(
      url: root.appendingPathComponent("guest.sqlite"), catalog: [])
    _ = try await guestStore.load(seed: phone)
    let transport = PhoneImportTransport(directory: storage.directory, offline: offline)
    let model = AppModel()
    model.store = memberStore
    model.guestStore = guestStore
    model.seedWorkspace = phone
    model.workspace = try await memberStore.load(seed: cloud)
    model.activeMember = "member-a"
    model.accountEnvironment = environment
    model.sync = AccountSync(store: memberStore, transport: transport)
    return Fixture(
      model: model, memberStore: memberStore, guestStore: guestStore, phone: phone,
      transport: transport, directory: storage.directory)
  }

  func testReservationWriteFailureBlocksReplacementAndUploadAndPreservesGuest() async throws {
    let fixture = try await fixture(ledgerDirectoryExists: false)
    defer { fixture.model.stopSync() }
    let before = fixture.model.workspace
    let guestBefore = try await fixture.guestStore.load(seed: fixture.phone)
    let status = await fixture.model.bringPhoneTraining(fixture.phone, reviewedRevision: 8)
    guard case .failed(let message) = status else {
      return XCTFail("Import must stop before mutation")
    }
    XCTAssertTrue(message.contains("did not start"))
    XCTAssertEqual(fixture.model.workspace, before)
    let stored = try await fixture.memberStore.load(seed: Workspace())
    XCTAssertEqual(stored, before)
    let puts = await fixture.transport.puts
    XCTAssertEqual(puts, 0)
    let guestAfter = try await fixture.guestStore.load(seed: Workspace())
    XCTAssertEqual(guestAfter, guestBefore)
  }

  func testSuccessfulImportUploadsOnlyAfterReservationAndKeepsGuestUntouched() async throws {
    let fixture = try await fixture()
    defer { fixture.model.stopSync() }
    let guestBefore = try await fixture.guestStore.load(seed: fixture.phone)
    let status = await fixture.model.bringPhoneTraining(fixture.phone, reviewedRevision: 8)
    XCTAssertEqual(status, .idle)
    let seen = await fixture.transport.reservationSeen
    XCTAssertTrue(seen)
    XCTAssertEqual(try PhoneTrainingLedger.read(in: fixture.directory)?.status, .imported)
    XCTAssertEqual(fixture.model.workspace?.profile.name, fixture.phone.profile.name)
    let guestAfter = try await fixture.guestStore.load(seed: Workspace())
    XCTAssertEqual(guestAfter, guestBefore)
    let offer = await fixture.model.loadPhoneTraining().offer
    XCTAssertEqual(offer, .importedHere)
  }

  func testEarlierOfflineUploadDoesNotReportThatNewImportSucceeded() async throws {
    let fixture = try await fixture(offline: true)
    defer { fixture.model.stopSync() }
    _ = try await fixture.memberStore.capturePending(
      operationId: "earlier-change", expectedRevision: 8)
    let before = fixture.model.workspace
    let status = await fixture.model.bringPhoneTraining(fixture.phone, reviewedRevision: 8)
    guard case .failed = status else {
      return XCTFail("An unsettled earlier upload is not an import")
    }
    XCTAssertEqual(fixture.model.workspace, before)
    XCTAssertEqual(try PhoneTrainingLedger.read(in: fixture.directory)?.status, .reserved)
    let offer = await fixture.model.loadPhoneTraining().offer
    guard case .reservedHere = offer else { return XCTFail("Only this member may review a retry") }
    fixture.model.activeMember = "member-b"
    let other = await fixture.model.loadPhoneTraining()
    XCTAssertEqual(other.offer, .reservedElsewhere)
    XCTAssertNil(other.workspace)
  }

  func testUnreadableLedgerShowsUnavailableInsteadOfOfferingPhoneTraining() async throws {
    let fixture = try await fixture()
    defer { fixture.model.stopSync() }
    try Data("damaged".utf8).write(to: PhoneTrainingLedger.url(in: fixture.directory))
    let offer = await fixture.model.loadPhoneTraining()
    guard case .unavailable = offer.offer else { return XCTFail("Read errors must be visible") }
    XCTAssertNil(offer.workspace)
  }
}
