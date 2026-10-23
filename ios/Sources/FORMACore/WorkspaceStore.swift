import CSQLite
import Foundation

/// An offline guest store. This does not implement member authentication, cloud
/// sync, import migration or encryption. iOS supplies file protection separately.
public actor WorkspaceStore {
  private let database: SQLiteConnection
  private let catalog: [Exercise]
  private let url: URL
  private let encoder: JSONEncoder
  private let decoder = JSONDecoder()

  public init(url: URL, catalog: [Exercise]) throws {
    guard url.isFileURL else { throw FormaError.storage("A local file URL is required.") }
    self.url = url
    self.catalog = catalog
    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let connection = try SQLiteConnection(url: url)
    let schema = try connection.scalarInt("PRAGMA user_version") ?? 0
    guard schema == 0 || schema == 1 else { throw FormaError.unsupportedStoreSchema(schema) }
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
        try connection.execute("PRAGMA user_version = 1")
        try connection.execute("COMMIT")
      } catch {
        try? connection.execute("ROLLBACK")
        throw error
      }
    } else {
      // Check the existing table shape before setting journal options.
      _ = try connection.prepare(
        "SELECT revision, snapshot, previous_snapshot FROM workspace WHERE id = 1")
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
        try database.execute("COMMIT")
        return workspace
      }
      try seed.validate(catalog: catalog)
      let raw = try encode(seed)
      let statement = try database.prepare(
        "INSERT INTO workspace (id, revision, snapshot) VALUES (1, ?, ?)")
      try statement.bind(seed.revision, at: 1)
      try statement.bind(raw, at: 2)
      try statement.run()
      try database.execute("COMMIT")
      return seed
    } catch {
      try? database.execute("ROLLBACK")
      throw error
    }
  }

  /// Returns only after SQLite's COMMIT succeeds. Revision and a recoverable
  /// previous snapshot change in the same full-synchronous transaction.
  public func save(_ candidate: Workspace, expectedRevision: Int) throws -> Workspace {
    try candidate.validate(catalog: catalog)
    guard candidate.revision == expectedRevision else {
      throw FormaError.invalid("The edited workspace does not match its expected revision.")
    }
    try database.execute("BEGIN IMMEDIATE")
    do {
      guard let record = try readRecord() else { throw FormaError.corruptStore }
      _ = try decode(record)
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
      try database.execute("COMMIT")
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
    try snapshot.validate(catalog: catalog)
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

  private func decode(_ record: Record) throws -> Workspace {
    do {
      let workspace = try decoder.decode(Workspace.self, from: record.raw)
      try workspace.validate(catalog: catalog)
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
