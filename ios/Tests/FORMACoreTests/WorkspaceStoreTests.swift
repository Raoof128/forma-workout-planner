import CSQLite
import Foundation
import XCTest

@testable import FORMACore

final class WorkspaceStoreTests: XCTestCase, @unchecked Sendable {
  private func temporaryURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "forma-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory.appendingPathComponent("workspace.sqlite")
  }

  func testCommitSurvivesNewConnectionAndPreservesCompletedSet() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let loaded = try await store.load(seed: Fixtures.active(now: 1_000))
    let candidate = try WorkoutEngine.toggleSet(
      in: loaded, entryIndex: 0, setIndex: 0, now: 2_000, catalog: Fixtures.catalog)
    let committed = try await store.save(candidate, expectedRevision: loaded.revision)
    XCTAssertEqual(committed.revision, loaded.revision + 1)
    let reopened = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let restored = try await reopened.load(seed: Workspace())
    XCTAssertEqual(restored, committed)
    XCTAssertTrue(restored.active!.exercises[0].sets[0].done)
    XCTAssertEqual(restored.active!.restEnd, 92_000)
  }

  func testTwoWritersCannotSilentlyOverwriteSameRevision() async throws {
    let url = try temporaryURL()
    let first = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let second = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    var a = try await first.load(seed: Fixtures.workspace())
    var b = try await second.load(seed: Fixtures.workspace())
    a.profile.name = "First writer"
    _ = try await first.save(a, expectedRevision: a.revision)
    b.profile.name = "Stale writer"
    do {
      _ = try await second.save(b, expectedRevision: b.revision)
      XCTFail("A stale writer must not overwrite a committed workspace")
    } catch let error as FormaError {
      XCTAssertEqual(error, .conflictingRevision(expected: 0, actual: 1))
    }
    let restored = try await second.load(seed: Fixtures.workspace())
    XCTAssertEqual(restored.profile.name, "First writer")
  }

  func testInvalidWriteLeavesLastCommittedWorkspaceUntouched() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.active(now: 1_000))
    var invalid = original
    invalid.active!.exercises[0].sets[0] = LoggedSet(weight: 40, reps: 0, done: true)
    do {
      _ = try await store.save(invalid, expectedRevision: original.revision)
      XCTFail("Invalid completed measurements must be rejected")
    } catch {}
    let loaded = try await store.load(seed: Workspace())
    XCTAssertEqual(loaded, original)
  }

  func testCorruptDatabaseIsNotReplacedWithStarterData() throws {
    let url = try temporaryURL()
    let raw = Data("not a database; preserve this original".utf8)
    try raw.write(to: url)
    XCTAssertThrowsError(try WorkspaceStore(url: url, catalog: Fixtures.catalog))
    XCTAssertEqual(try Data(contentsOf: url), raw)
  }

  func testUnsupportedStoreSchemaIsNotSilentlyDowngraded() throws {
    let url = try temporaryURL()
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(database, "PRAGMA user_version = 77", nil, nil, nil), SQLITE_OK)
    sqlite3_close(database)
    XCTAssertThrowsError(try WorkspaceStore(url: url, catalog: Fixtures.catalog)) { error in
      XCTAssertEqual(error as? FormaError, .unsupportedStoreSchema(77))
    }
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    var statement: OpaquePointer?
    sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil)
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    XCTAssertEqual(sqlite3_column_int(statement, 0), 77)
    sqlite3_finalize(statement)
    sqlite3_close(database)
  }

  func testSQLiteWriteFailureRollsBackRevisionAndLeavesPreviousCommitReadable() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.workspace())
    var connection: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &connection), SQLITE_OK)
    XCTAssertEqual(
      sqlite3_exec(
        connection,
        "CREATE TRIGGER fail_write BEFORE UPDATE ON workspace BEGIN SELECT RAISE(ABORT, 'injected write failure'); END",
        nil, nil, nil), SQLITE_OK)
    sqlite3_close(connection)
    var candidate = original
    candidate.profile.name = "Must not appear as saved"
    do {
      _ = try await store.save(candidate, expectedRevision: original.revision)
      XCTFail("An aborted SQLite update must fail its save operation")
    } catch {}
    let restored = try await store.load(seed: Workspace())
    XCTAssertEqual(restored, original)
    XCTAssertEqual(restored.revision, 0)
    XCTAssertEqual(sqlite3_open(url.path, &connection), SQLITE_OK)
    XCTAssertEqual(sqlite3_exec(connection, "DROP TRIGGER fail_write", nil, nil, nil), SQLITE_OK)
    sqlite3_close(connection)
    let retried = try await store.save(candidate, expectedRevision: original.revision)
    XCTAssertEqual(retried.profile.name, candidate.profile.name)
    XCTAssertEqual(retried.revision, 1)
    let previous = try await store.previousSnapshot()
    XCTAssertEqual(previous, original)
  }

  func testCorruptedSnapshotPreservesRawDataAndLastGoodRecoverySnapshot() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.workspace())
    var candidate = original
    candidate.profile.name = "Next commit"
    _ = try await store.save(candidate, expectedRevision: 0)
    var connection: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &connection), SQLITE_OK)
    XCTAssertEqual(
      sqlite3_exec(connection, "UPDATE workspace SET snapshot = X'7B62726F6B656E'", nil, nil, nil),
      SQLITE_OK)
    sqlite3_close(connection)
    do {
      _ = try await store.load(seed: Workspace())
      XCTFail("Corrupt canonical data must never be replaced with starter content")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    let previous = try await store.previousSnapshot()
    XCTAssertEqual(previous, original)
    let files = try FileManager.default.contentsOfDirectory(
      at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
    let recovery = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("forma-recovery-") })
    XCTAssertEqual(try Data(contentsOf: recovery), Data("{broken".utf8))
  }

  func testResetCommitsEmptyGuestErasesPreviousSnapshotAndNeverReseeds() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.active(now: 1_000))
    var candidate = original
    candidate.active!.exercises[0].sets[0].done = true
    let saved = try await store.save(candidate, expectedRevision: original.revision)
    let recovery = url.deletingLastPathComponent().appendingPathComponent(
      "forma-recovery-\(UUID().uuidString).json")
    try JSONEncoder().encode(original).write(to: recovery)
    let reset = try await store.reset(expectedRevision: saved.revision)
    XCTAssertEqual(reset.revision, saved.revision + 1)
    XCTAssertTrue(reset.routines.isEmpty)
    XCTAssertTrue(reset.history.isEmpty)
    XCTAssertNil(reset.active)
    XCTAssertEqual(reset.profile.name, "Guest")
    XCTAssertEqual(reset.profile.goal, 4)
    let previous = try await store.previousSnapshot()
    XCTAssertNil(previous)
    XCTAssertFalse(FileManager.default.fileExists(atPath: recovery.path))
    let reopened = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let loaded = try await reopened.load(seed: Fixtures.workspace())
    XCTAssertEqual(loaded, reset)
  }

  func testStaleResetCannotDeleteNewerCommitOrRecoveryFiles() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.workspace())
    var changed = original
    changed.profile.name = "Keep the newer data"
    let saved = try await store.save(changed, expectedRevision: original.revision)
    let recovery = url.deletingLastPathComponent().appendingPathComponent(
      "forma-recovery-\(UUID().uuidString).json")
    try JSONEncoder().encode(original).write(to: recovery)
    do {
      _ = try await store.reset(expectedRevision: original.revision)
      XCTFail("A stale delete must not remove a newer workspace")
    } catch {
      XCTAssertEqual(error as? FormaError, .conflictingRevision(expected: 0, actual: 1))
    }
    let loaded = try await store.load(seed: Workspace())
    XCTAssertEqual(loaded, saved)
    XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.path))
  }

  func testOversizedSnapshotAndRecoveryBlobsAreRefusedWithoutReplacingData() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    _ = try await store.load(seed: Fixtures.workspace())
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    defer { sqlite3_close(database) }
    let oversized = Workspace.maximumBytes + 1
    XCTAssertEqual(
      sqlite3_exec(
        database,
        "UPDATE workspace SET snapshot = zeroblob(\(oversized)), previous_snapshot = zeroblob(\(oversized))",
        nil, nil, nil),
      SQLITE_OK)
    do {
      _ = try await store.load(seed: Workspace())
      XCTFail("An oversized canonical blob must not be decoded or replaced by seed data")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    do {
      _ = try await store.previousSnapshot()
      XCTFail("An oversized recovery blob must not be decoded")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    var statement: OpaquePointer?
    XCTAssertEqual(
      sqlite3_prepare_v2(
        database,
        "SELECT revision, length(snapshot), length(previous_snapshot) FROM workspace WHERE id = 1",
        -1, &statement, nil), SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
    XCTAssertEqual(sqlite3_column_int(statement, 0), 0)
    XCTAssertEqual(sqlite3_column_int(statement, 1), Int32(oversized))
    XCTAssertEqual(sqlite3_column_int(statement, 2), Int32(oversized))
  }

  func testRetryingTheSameCorruptSnapshotDoesNotFillTheDeviceWithDuplicateRecoveryFiles()
    async throws
  {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    _ = try await store.load(seed: Fixtures.workspace())
    var database: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
    defer { sqlite3_close(database) }
    XCTAssertEqual(
      sqlite3_exec(database, "UPDATE workspace SET snapshot = X'7B62726F6B656E'", nil, nil, nil),
      SQLITE_OK)
    for _ in 0..<3 {
      do {
        _ = try await store.load(seed: Workspace())
        XCTFail("The snapshot is still corrupt")
      } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    }
    let reopened = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    do {
      _ = try await reopened.load(seed: Workspace())
      XCTFail("Reopening must not replace corruption")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    func recoveryFiles() throws -> [URL] {
      try FileManager.default.contentsOfDirectory(
        at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil
      )
      .filter { $0.lastPathComponent.hasPrefix("forma-recovery-") && $0.pathExtension == "json" }
    }
    XCTAssertEqual(try recoveryFiles().count, 1)
    XCTAssertEqual(try recoveryFiles().map { try Data(contentsOf: $0) }, [Data("{broken".utf8)])
    // A genuinely different damaged original still deserves its own copy.
    XCTAssertEqual(
      sqlite3_exec(database, "UPDATE workspace SET snapshot = X'7B62726F6B656E32'", nil, nil, nil),
      SQLITE_OK)
    do {
      _ = try await store.load(seed: Workspace())
      XCTFail("The second snapshot is also corrupt")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    XCTAssertEqual(try recoveryFiles().count, 2)
    XCTAssertEqual(
      Set(try recoveryFiles().map { try Data(contentsOf: $0) }),
      [Data("{broken".utf8), Data("{broken2".utf8)])
  }
}
