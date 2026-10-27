import CSQLite
import Foundation

/// An offline workspace store: the guest store, or one member's cache. It holds
/// the account sync bookkeeping (see `SyncMetadata`) but does no networking, and
/// does not implement member authentication, import migration or encryption.
/// iOS supplies file protection separately.
public actor WorkspaceStore {
  private let database: SQLiteConnection
  /// Built once: every save, load and decode validates against the catalogue.
  private let catalog: ExerciseMetricIndex
  private let url: URL
  private let encoder: JSONEncoder
  private let decoder = JSONDecoder()
  /// The newest snapshot this connection has itself written, or decoded and
  /// validated. A stored record that is byte-for-byte equal to it needs no second
  /// full decode and validation before the next save; any other bytes (another
  /// writer, a damaged file) take the full path.
  private var verified: (revision: Int, raw: Data)?

  /// Schema 1 is a pre-account guest store; 2 adds `sync_state`.
  private static let currentSchema = 2
  private static let createSyncState = """
    CREATE TABLE sync_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      server_revision INTEGER CHECK (server_revision IS NULL OR server_revision >= 0),
      dirty INTEGER NOT NULL DEFAULT 0 CHECK (dirty IN (0, 1)),
      captured_revision INTEGER,
      pending_operation_id TEXT,
      pending_payload BLOB,
      pending_expected_revision INTEGER CHECK (pending_expected_revision IS NULL OR pending_expected_revision >= 0),
      CHECK ((pending_operation_id IS NULL) = (pending_payload IS NULL)
        AND (pending_operation_id IS NULL) = (pending_expected_revision IS NULL))
    )
    """

  public init(url: URL, catalog: [Exercise]) throws {
    guard url.isFileURL else { throw FormaError.storage("A local file URL is required.") }
    self.url = url
    self.catalog = ExerciseMetricIndex(catalog)
    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let connection = try SQLiteConnection(url: url)
    let schema = try connection.scalarInt("PRAGMA user_version") ?? 0
    guard schema == 0 || schema == 1 || schema == Self.currentSchema else {
      throw FormaError.unsupportedStoreSchema(schema)
    }
    if schema == 0 {
      // Existing, unrelated databases must not be repurposed as FORMA stores.
      let tables =
        try connection.scalarInt(
          "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
        ?? 0
      guard tables == 0 else { throw FormaError.corruptStore }
      try connection.execute("BEGIN IMMEDIATE")
      do {
        try connection.execute(
          "CREATE TABLE workspace (id INTEGER PRIMARY KEY CHECK (id = 1), revision INTEGER NOT NULL CHECK (revision >= 0), snapshot BLOB NOT NULL, previous_snapshot BLOB)"
        )
        try connection.execute(Self.createSyncState)
        try connection.execute("INSERT INTO sync_state (id) VALUES (1)")
        try connection.execute("PRAGMA user_version = \(Self.currentSchema)")
        try connection.execute("COMMIT")
      } catch {
        try? connection.execute("ROLLBACK")
        throw error
      }
    } else {
      // Check the existing table shape before setting journal options.
      _ = try connection.prepare(
        "SELECT revision, snapshot, previous_snapshot FROM workspace WHERE id = 1")
      if schema == 1 {
        // A guest store written before accounts existed. Adding the sync table
        // touches no workspace data, and the version only moves with it.
        try connection.execute("BEGIN IMMEDIATE")
        do {
          try connection.execute(Self.createSyncState)
          try connection.execute("INSERT INTO sync_state (id) VALUES (1)")
          try connection.execute("PRAGMA user_version = \(Self.currentSchema)")
          try connection.execute("COMMIT")
        } catch {
          try? connection.execute("ROLLBACK")
          throw error
        }
      } else {
        _ = try connection.prepare(
          "SELECT server_revision, dirty, captured_revision, pending_operation_id, pending_payload, pending_expected_revision FROM sync_state WHERE id = 1"
        )
      }
    }
    try connection.execute("PRAGMA journal_mode = WAL")
    try connection.execute("PRAGMA synchronous = FULL")
    try connection.execute("PRAGMA secure_delete = ON")
    database = connection
  }

  /// Seeds only an empty database. Existing invalid data is never replaced by
  /// seed content; callers receive an explicit recovery error instead.
  public func load(seed: Workspace) throws -> Workspace {
    try database.execute("BEGIN IMMEDIATE")
    do {
      if let record = try readRecord() {
        let workspace = try decode(record)
        verified = (record.revision, record.raw)
        try database.execute("COMMIT")
        return workspace
      }
      try seed.validateStructure(index: catalog)
      let raw = try encode(seed)
      let statement = try database.prepare(
        "INSERT INTO workspace (id, revision, snapshot) VALUES (1, ?, ?)")
      try statement.bind(seed.revision, at: 1)
      try statement.bind(raw, at: 2)
      try statement.run()
      try database.execute("COMMIT")
      verified = (seed.revision, raw)
      return seed
    } catch {
      try? database.execute("ROLLBACK")
      throw error
    }
  }

  /// Returns only after SQLite's COMMIT succeeds. Revision and a recoverable
  /// previous snapshot change in the same full-synchronous transaction.
  ///
  /// `markingDirty` records "not yet captured for the account" in the same
  /// transaction, so a crash cannot leave a committed edit that sync never hears
  /// about. A guest store ignores it harmlessly.
  public func save(
    _ candidate: Workspace, expectedRevision: Int, markingDirty: Bool = false
  ) throws -> Workspace {
    try candidate.validateStructure(index: catalog)
    guard candidate.revision == expectedRevision else {
      throw FormaError.invalid("The edited workspace does not match its expected revision.")
    }
    try database.execute("BEGIN IMMEDIATE")
    do {
      guard let record = try readRecord() else { throw FormaError.corruptStore }
      try verifyStored(record)
      guard record.revision == expectedRevision else {
        throw FormaError.conflictingRevision(expected: expectedRevision, actual: record.revision)
      }
      guard record.revision < 9_007_199_254_740_991 else {
        throw FormaError.invalid("This workspace revision cannot be advanced.")
      }
      var result = candidate
      result.revision = record.revision + 1
      let raw = try encode(result)
      let statement = try database.prepare(
        "UPDATE workspace SET previous_snapshot = snapshot, snapshot = ?, revision = ? WHERE id = 1 AND revision = ?"
      )
      try statement.bind(raw, at: 1)
      try statement.bind(result.revision, at: 2)
      try statement.bind(expectedRevision, at: 3)
      try statement.run()
      guard sqlite3_changes(database.handle) == 1 else {
        throw FormaError.storage("The local revision changed while saving.")
      }
      if markingDirty { try database.execute("UPDATE sync_state SET dirty = 1 WHERE id = 1") }
      try database.execute("COMMIT")
      verified = (result.revision, raw)
      return result
    } catch {
      try? database.execute("ROLLBACK")
      throw error
    }
  }

  /// Offers the previous known-good commit as data for a recovery UI. Reading
  /// this snapshot never changes the current database or its revision.
  public func previousSnapshot() throws -> Workspace? {
    let statement = try database.prepare("SELECT previous_snapshot FROM workspace WHERE id = 1")
    guard try statement.next(), let raw = try statement.data(at: 0) else { return nil }
    let snapshot: Workspace
    do { snapshot = try decoder.decode(Workspace.self, from: raw) } catch {
      throw FormaError.corruptStore
    }
    try snapshot.validateStructure(index: catalog)
    return snapshot
  }

  /// Deliberate local deletion replaces the canonical guest workspace and its
  /// recovery slot in one transaction. This is logical deletion, not a promise
  /// of forensic erasure from device snapshots or user-exported files.
  public func reset(expectedRevision: Int) throws -> Workspace {
    try database.execute("BEGIN IMMEDIATE")
    do {
      guard let record = try readRecord() else { throw FormaError.corruptStore }
      guard record.revision == expectedRevision else {
        throw FormaError.conflictingRevision(expected: expectedRevision, actual: record.revision)
      }
      guard record.revision < 9_007_199_254_740_991 else {
        throw FormaError.invalid("This workspace revision cannot be advanced.")
      }
      let result = Workspace(
        revision: record.revision + 1, profile: Profile(name: "Guest", goal: 4))
      let raw = try encode(result)
      let statement = try database.prepare(
        "UPDATE workspace SET previous_snapshot = NULL, snapshot = ?, revision = ? WHERE id = 1 AND revision = ?"
      )
      try statement.bind(raw, at: 1)
      try statement.bind(result.revision, at: 2)
      try statement.bind(expectedRevision, at: 3)
      try statement.run()
      guard sqlite3_changes(database.handle) == 1 else {
        throw FormaError.storage("The local revision changed while deleting.")
      }
      // Raw recovery copies are only this store's uniquely named JSON
      // files; an error aborts deletion rather than falsely claiming it.
      let files = try FileManager.default.contentsOfDirectory(
        at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
      for file in files
      where file.lastPathComponent.hasPrefix("forma-recovery-") && file.pathExtension == "json" {
        try FileManager.default.removeItem(at: file)
      }
      try database.execute("COMMIT")
      verified = (result.revision, raw)
      // An unrelated open connection may defer checkpointing. Once the
      // deletion has committed, never report it as an uncommitted failure.
      _ = sqlite3_wal_checkpoint_v2(database.handle, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
      return result
    } catch {
      try? database.execute("ROLLBACK")
      throw error
    }
  }

  private struct Record {
    var revision: Int
    var raw: Data
  }

  private func readRecord() throws -> Record? {
    let statement = try database.prepare("SELECT revision, snapshot FROM workspace WHERE id = 1")
    guard try statement.next() else { return nil }
    guard let raw = try statement.data(at: 1) else {
      throw FormaError.corruptStore
    }
    return Record(revision: Int(sqlite3_column_int64(statement.handle, 0)), raw: raw)
  }

  private func encode(_ workspace: Workspace) throws -> Data {
    let raw = try encoder.encode(workspace)
    guard raw.count <= Workspace.maximumBytes else {
      throw FormaError.invalid("This training workspace is larger than the supported 20 MiB limit.")
    }
    return raw
  }

  /// Confirms that the stored record decodes and validates, skipping the work
  /// when it is exactly the snapshot this connection last wrote or verified.
  private func verifyStored(_ record: Record) throws {
    if let verified, verified.revision == record.revision, verified.raw == record.raw { return }
    _ = try decode(record)
    verified = (record.revision, record.raw)
  }

  private func decode(_ record: Record) throws -> Workspace {
    do {
      let workspace = try decoder.decode(Workspace.self, from: record.raw)
      try workspace.validateStructure(index: catalog)
      guard workspace.revision == record.revision else { throw FormaError.corruptStore }
      return workspace
    } catch {
      // Preserve each distinct damaged original, rather than making another
      // full-size copy every time the recovery screen's Retry is pressed.
      try? preserveRecovery(record.raw)
      if let error = error as? FormaError, case .unsupportedVersion = error { throw error }
      throw FormaError.corruptStore
    }
  }

  private func preserveRecovery(_ raw: Data) throws {
    let directory = url.deletingLastPathComponent()
    let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: Array(keys))
    for file in files
    where file.lastPathComponent.hasPrefix("forma-recovery-") && file.pathExtension == "json" {
      guard let values = try? file.resourceValues(forKeys: keys),
        values.isRegularFile == true, values.isSymbolicLink != true,
        values.fileSize == raw.count
      else { continue }
      if let saved = try? Data(contentsOf: file, options: [.mappedIfSafe]), saved == raw { return }
    }
    let recovery = directory.appendingPathComponent("forma-recovery-\(UUID().uuidString).json")
    try raw.write(to: recovery, options: [.atomic])
  }
}

/// An upload written down before it is sent. A retry sends exactly these bytes
/// under exactly this identifier, so the server can recognise a repeat of an
/// operation it already applied (a lost acknowledgement) instead of applying
/// it twice, and can refuse a different payload that reuses the identifier.
public struct PendingOperation: Equatable, Sendable {
  public var operationId: String
  /// The workspace v2 JSON exactly as stored locally (sorted keys), which is the
  /// `data` member of the PUT body.
  public var payload: Data
  /// The account revision this upload was built on.
  public var expectedRevision: Int

  public init(operationId: String, payload: Data, expectedRevision: Int) {
    self.operationId = operationId
    self.payload = payload
    self.expectedRevision = expectedRevision
  }
}

/// What a store remembers about its account.
public struct SyncMetadata: Equatable, Sendable {
  /// The last revision the account acknowledged. Nil until the first full fetch.
  public var serverRevision: Int?
  /// Local changes exist that no pending operation covers yet. Besides the
  /// explicit flag this is true whenever the local workspace has moved on from
  /// the revision the last operation captured, so an edit saved without the flag
  /// (a crash between the save and `markDirty`) is still noticed.
  public var dirty: Bool
  public var pending: PendingOperation?

  public init(serverRevision: Int? = nil, dirty: Bool = false, pending: PendingOperation? = nil) {
    self.serverRevision = serverRevision
    self.dirty = dirty
    self.pending = pending
  }
}

// Account sync bookkeeping. Every write is one full-synchronous transaction, the
// same durability as a workspace save, and a pending operation is committed here
// before the engine hands it to the network.
extension WorkspaceStore {
  /// The file for one member's cache, so a shared phone never mixes accounts.
  /// The name is injective, ASCII, lower case and free of separators or dots, so
  /// it is safe on case-insensitive volumes and cannot escape `directory`.
  /// `memberReference` is an opaque, stable identifier, never an email address.
  public static func memberStoreURL(directory: URL, memberReference: String) -> URL {
    var name = ""
    for byte in memberReference.utf8 {
      switch byte {
      case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "0")...UInt8(ascii: "9"),
        UInt8(ascii: "-"):
        name.append(Character(UnicodeScalar(byte)))
      default:
        name += "%" + String(byte, radix: 16, uppercase: true).leftPadded(to: 2)
      }
    }
    if name.isEmpty { name = "_" }
    if name.count > 96 {
      // "~" never appears in an unshortened name, so the two forms cannot clash.
      var hash: UInt64 = 0xcbf2_9ce4_8422_2325
      for byte in memberReference.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
      name = String(name.prefix(64)) + "~" + String(hash, radix: 16).leftPadded(to: 16)
    }
    return directory.appendingPathComponent("member-\(name).sqlite", isDirectory: false)
  }

  public func syncMetadata() throws -> SyncMetadata {
    let row = try readSyncRow()
    return SyncMetadata(
      serverRevision: row.serverRevision, dirty: try isDirty(row), pending: row.pending)
  }

  /// Records that the local workspace changed. Prefer `save(_:expectedRevision:markingDirty:)`,
  /// which does this atomically with the save.
  public func markDirty() throws {
    try inTransaction { try database.execute("UPDATE sync_state SET dirty = 1 WHERE id = 1") }
  }

  /// Snapshots the local workspace into the pending operation and clears the
  /// dirty flag in one transaction, replacing any earlier pending operation. The
  /// payload is the stored snapshot itself, so it is what the contract check and
  /// local validation already accepted. Returns only once the operation is
  /// committed; send it afterwards, never before.
  public func capturePending(operationId: String, expectedRevision: Int) throws
    -> PendingOperation
  {
    guard !operationId.isEmpty, operationId.utf8.count <= 200, expectedRevision >= 0 else {
      throw FormaError.invalid("This sync operation is not valid.")
    }
    return try inTransaction {
      guard let record = try readRecord() else { throw FormaError.corruptStore }
      try verifyStored(record)
      let statement = try database.prepare(
        "UPDATE sync_state SET pending_operation_id = ?, pending_payload = ?, pending_expected_revision = ?, dirty = 0, captured_revision = ? WHERE id = 1"
      )
      try statement.bind(operationId, at: 1)
      try statement.bind(record.raw, at: 2)
      try statement.bind(expectedRevision, at: 3)
      try statement.bind(record.revision, at: 4)
      try statement.run()
      return PendingOperation(
        operationId: operationId, payload: record.raw, expectedRevision: expectedRevision)
    }
  }

  /// The account acknowledged this operation. Clears it and records the new
  /// account revision together. False when it is no longer the pending one.
  @discardableResult
  public func completePending(operationId: String, serverRevision: Int) throws -> Bool {
    guard serverRevision >= 0 else { throw FormaError.invalid("The account revision is invalid.") }
    return try inTransaction {
      let statement = try database.prepare(
        "UPDATE sync_state SET server_revision = ?, pending_operation_id = NULL, pending_payload = NULL, pending_expected_revision = NULL WHERE id = 1 AND pending_operation_id = ?"
      )
      try statement.bind(serverRevision, at: 1)
      try statement.bind(operationId, at: 2)
      try statement.run()
      return sqlite3_changes(database.handle) == 1
    }
  }

  /// Gives up a pending operation that can never succeed as sent. Its edits are
  /// still in the local workspace, so the store is marked dirty to capture them
  /// again later under a new identifier.
  public func discardPending(operationId: String) throws {
    try inTransaction {
      let statement = try database.prepare(
        "UPDATE sync_state SET pending_operation_id = NULL, pending_payload = NULL, pending_expected_revision = NULL, dirty = 1 WHERE id = 1 AND pending_operation_id = ?"
      )
      try statement.bind(operationId, at: 1)
      try statement.run()
    }
  }

  /// Replaces the local workspace with `workspace` (the account's copy, or an
  /// import) in one transaction. Pending and dirty state are cleared and the
  /// account revision is recorded, unless `uploading` is given, which leaves the
  /// new local copy as the payload of a pending operation instead.
  ///
  /// The local revision keeps counting up from the stored one, whatever
  /// `workspace.revision` says: the account's own counter is separate, and a
  /// screen holding an older local revision must still fail its next save.
  /// `onlyIfClean` refuses (returns nil) when unsynced local work exists,
  /// checked inside the transaction so an edit cannot slip in after the caller
  /// looked. The replaced snapshot becomes the recovery snapshot.
  public func replaceWorkspace(
    with workspace: Workspace, serverRevision: Int,
    uploading: (operationId: String, expectedRevision: Int)? = nil, onlyIfClean: Bool = false
  ) throws -> Workspace? {
    guard serverRevision >= 0 else { throw FormaError.invalid("The account revision is invalid.") }
    if let uploading {
      guard !uploading.operationId.isEmpty, uploading.operationId.utf8.count <= 200,
        uploading.expectedRevision >= 0
      else { throw FormaError.invalid("This sync operation is not valid.") }
    }
    let replaced: (workspace: Workspace, raw: Data)? = try inTransaction {
      let record = try readRecord()
      if onlyIfClean {
        let row = try readSyncRow()
        if row.pending != nil { return nil }
        if try isDirty(row) { return nil }
      }
      let next = (record?.revision ?? -1) + 1
      guard next < 9_007_199_254_740_991 else {
        throw FormaError.invalid("This workspace revision cannot be advanced.")
      }
      var result = workspace
      result.revision = next
      try result.validateStructure(index: catalog)
      let raw = try encode(result)
      if let record {
        // Keep the replaced copy as the recovery snapshot only if it was sound;
        // a damaged one has already been preserved as a recovery file.
        let sound = (try? verifyStored(record)) != nil
        let statement = try database.prepare(
          "UPDATE workspace SET previous_snapshot = ?, snapshot = ?, revision = ? WHERE id = 1")
        if sound { try statement.bind(record.raw, at: 1) } else { try statement.bindNull(at: 1) }
        try statement.bind(raw, at: 2)
        try statement.bind(next, at: 3)
        try statement.run()
      } else {
        let statement = try database.prepare(
          "INSERT INTO workspace (id, revision, snapshot) VALUES (1, ?, ?)")
        try statement.bind(next, at: 1)
        try statement.bind(raw, at: 2)
        try statement.run()
      }
      let sync = try database.prepare(
        "UPDATE sync_state SET server_revision = ?, dirty = 0, captured_revision = ?, pending_operation_id = ?, pending_payload = ?, pending_expected_revision = ? WHERE id = 1"
      )
      try sync.bind(serverRevision, at: 1)
      try sync.bind(next, at: 2)
      if let uploading {
        try sync.bind(uploading.operationId, at: 3)
        try sync.bind(raw, at: 4)
        try sync.bind(uploading.expectedRevision, at: 5)
      } else {
        try sync.bindNull(at: 3)
        try sync.bindNull(at: 4)
        try sync.bindNull(at: 5)
      }
      try sync.run()
      return (result, raw)
    }
    guard let replaced else { return nil }
    verified = (replaced.workspace.revision, replaced.raw)
    return replaced.workspace
  }

  private struct SyncRow {
    var serverRevision: Int?
    var flag: Bool
    var captured: Int?
    var pending: PendingOperation?
  }

  private func readSyncRow() throws -> SyncRow {
    let statement = try database.prepare(
      "SELECT server_revision, dirty, captured_revision, pending_operation_id, pending_payload, pending_expected_revision FROM sync_state WHERE id = 1"
    )
    guard try statement.next() else { throw FormaError.corruptStore }
    var pending: PendingOperation?
    if let id = statement.text(at: 3), let payload = try statement.data(at: 4),
      let expected = statement.optionalInt(at: 5)
    {
      pending = PendingOperation(operationId: id, payload: payload, expectedRevision: expected)
    }
    return SyncRow(
      serverRevision: statement.optionalInt(at: 0), flag: statement.optionalInt(at: 1) == 1,
      captured: statement.optionalInt(at: 2), pending: pending)
  }

  private func isDirty(_ row: SyncRow) throws -> Bool {
    if row.flag { return true }
    guard let captured = row.captured else { return false }
    return try database.scalarInt("SELECT revision FROM workspace WHERE id = 1") != captured
  }

  private func inTransaction<T>(_ body: () throws -> T) throws -> T {
    try database.execute("BEGIN IMMEDIATE")
    do {
      let result = try body()
      try database.execute("COMMIT")
      return result
    } catch {
      try? database.execute("ROLLBACK")
      throw error
    }
  }
}

extension String {
  fileprivate func leftPadded(to width: Int) -> String {
    count >= width ? self : String(repeating: "0", count: width - count) + self
  }
}

/// Ownership never escapes the actor. The wrapper's Sendable conformance permits
/// safe destruction without accessing an actor-isolated OpaquePointer in deinit.
private final class SQLiteConnection: @unchecked Sendable {
  let handle: OpaquePointer

  init(url: URL) throws {
    var opened: OpaquePointer?
    let code = sqlite3_open_v2(
      url.path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
    guard code == SQLITE_OK, let opened else {
      if let opened { sqlite3_close(opened) }
      throw FormaError.storage("SQLite open failed (\(code)).")
    }
    handle = opened
    sqlite3_extended_result_codes(opened, 1)
    sqlite3_busy_timeout(opened, 5_000)
  }

  deinit { sqlite3_close_v2(handle) }

  func execute(_ sql: String) throws {
    let code = sqlite3_exec(handle, sql, nil, nil, nil)
    guard code == SQLITE_OK else { throw FormaError.storage("SQLite operation failed (\(code)).") }
  }

  func prepare(_ sql: String) throws -> SQLiteStatement {
    try SQLiteStatement(database: handle, sql: sql)
  }

  func scalarInt(_ sql: String) throws -> Int? {
    let statement = try prepare(sql)
    return try statement.next() ? Int(sqlite3_column_int64(statement.handle, 0)) : nil
  }
}

private final class SQLiteStatement {
  let handle: OpaquePointer
  init(database: OpaquePointer, sql: String) throws {
    var prepared: OpaquePointer?
    let code = sqlite3_prepare_v2(database, sql, -1, &prepared, nil)
    guard code == SQLITE_OK, let prepared else {
      throw FormaError.storage("SQLite prepare failed (\(code)).")
    }
    handle = prepared
  }
  deinit { sqlite3_finalize(handle) }

  func bind(_ value: Int, at index: Int32) throws {
    let code = sqlite3_bind_int64(handle, index, sqlite3_int64(value))
    guard code == SQLITE_OK else { throw FormaError.storage("SQLite binding failed (\(code)).") }
  }

  func bind(_ value: String, at index: Int32) throws {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let code = sqlite3_bind_text(handle, index, value, -1, transient)
    guard code == SQLITE_OK else { throw FormaError.storage("SQLite binding failed (\(code)).") }
  }

  func bindNull(at index: Int32) throws {
    let code = sqlite3_bind_null(handle, index)
    guard code == SQLITE_OK else { throw FormaError.storage("SQLite binding failed (\(code)).") }
  }

  func optionalInt(at index: Int32) -> Int? {
    sqlite3_column_type(handle, index) == SQLITE_NULL
      ? nil : Int(sqlite3_column_int64(handle, index))
  }

  func text(at index: Int32) -> String? {
    guard sqlite3_column_type(handle, index) != SQLITE_NULL,
      let bytes = sqlite3_column_text(handle, index)
    else { return nil }
    return String(cString: bytes)
  }

  func bind(_ value: Data, at index: Int32) throws {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let code = value.withUnsafeBytes { bytes in
      sqlite3_bind_blob(handle, index, bytes.baseAddress, Int32(bytes.count), transient)
    }
    guard code == SQLITE_OK else { throw FormaError.storage("SQLite binding failed (\(code)).") }
  }

  func next() throws -> Bool {
    let code = sqlite3_step(handle)
    if code == SQLITE_ROW { return true }
    if code == SQLITE_DONE { return false }
    throw FormaError.storage("SQLite read failed (\(code)).")
  }

  func run() throws {
    let code = sqlite3_step(handle)
    guard code == SQLITE_DONE else { throw FormaError.storage("SQLite write failed (\(code)).") }
  }

  func data(at index: Int32) throws -> Data? {
    guard sqlite3_column_type(handle, index) != SQLITE_NULL else { return nil }
    let count = Int(sqlite3_column_bytes(handle, index))
    // Bound both canonical and recovery snapshots before allocating a Swift
    // copy. A corrupt database must not bypass the normal workspace byte cap.
    guard count <= Workspace.maximumBytes else { throw FormaError.corruptStore }
    guard let bytes = sqlite3_column_blob(handle, index), count > 0 else { return Data() }
    return Data(bytes: bytes, count: count)
  }
}
