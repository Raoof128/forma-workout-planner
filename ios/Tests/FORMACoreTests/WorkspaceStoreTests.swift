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
    let recovery = try XCTUnwrap(
      files.first { $0.lastPathComponent.hasPrefix(url.lastPathComponent + ".recovery-") })
    XCTAssertEqual(try Data(contentsOf: recovery), Data("{broken".utf8))
  }

  func testSaveStillDetectsDamageWrittenAfterThisConnectionsOwnCommit() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.workspace())
    var candidate = original
    candidate.profile.name = "Verified by this connection"
    let saved = try await store.save(candidate, expectedRevision: original.revision)
    var connection: OpaquePointer?
    XCTAssertEqual(sqlite3_open(url.path, &connection), SQLITE_OK)
    XCTAssertEqual(
      sqlite3_exec(connection, "UPDATE workspace SET snapshot = X'7B62726F6B656E'", nil, nil, nil),
      SQLITE_OK)
    sqlite3_close(connection)
    var next = saved
    next.profile.name = "Must not replace damaged data"
    do {
      _ = try await store.save(next, expectedRevision: saved.revision)
      XCTFail("Damaged bytes must not be treated as the snapshot this connection verified")
    } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
    let files = try FileManager.default.contentsOfDirectory(
      at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
    let recovery = try XCTUnwrap(
      files.first { $0.lastPathComponent.hasPrefix(url.lastPathComponent + ".recovery-") })
    XCTAssertEqual(try Data(contentsOf: recovery), Data("{broken".utf8))
  }

  func testConsecutiveSavesAdvanceRevisionAndKeepPreviousSnapshot() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    var current = try await store.load(seed: Fixtures.workspace())
    var before = current
    for index in 1...3 {
      before = current
      current.profile.name = "Save \(index)"
      current = try await store.save(current, expectedRevision: current.revision)
      XCTAssertEqual(current.revision, index)
    }
    let previous = try await store.previousSnapshot()
    XCTAssertEqual(previous?.profile.name, "Save 2")
    XCTAssertEqual(before.revision, 2)
    let reopened = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let loaded = try await reopened.load(seed: Workspace())
    XCTAssertEqual(loaded, current)
  }

  func testResetCommitsEmptyGuestErasesPreviousSnapshotAndNeverReseeds() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.active(now: 1_000))
    var candidate = original
    candidate.active!.exercises[0].sets[0].done = true
    let saved = try await store.save(candidate, expectedRevision: original.revision)
    let recovery = url.deletingLastPathComponent().appendingPathComponent(
      url.lastPathComponent + ".recovery-\(UUID().uuidString).json")
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
      url.lastPathComponent + ".recovery-\(UUID().uuidString).json")
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

  func testGuestResetPreservesMemberRecoveryOriginalsAndHistoricalUnscopedEvidence() async throws {
    let guestURL = try temporaryURL()
    let directory = guestURL.deletingLastPathComponent()
    let urls =
      [guestURL]
      + ["member-a", "member-b"].map {
        WorkspaceStore.memberStoreURL(directory: directory, memberReference: $0)
      }
    var stores: [WorkspaceStore] = []
    for (index, url) in urls.enumerated() {
      let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
      _ = try await store.load(seed: Fixtures.workspace())
      var database: OpaquePointer?
      XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
      let raw = Data("{broken synthetic original \(index)".utf8)
      var statement: OpaquePointer?
      XCTAssertEqual(
        sqlite3_prepare_v2(database, "UPDATE workspace SET snapshot = ?", -1, &statement, nil),
        SQLITE_OK)
      let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      _ = raw.withUnsafeBytes {
        sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32($0.count), transient)
      }
      XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
      sqlite3_finalize(statement)
      sqlite3_close(database)
      do {
        _ = try await store.load(seed: Workspace())
        XCTFail("Corruption must preserve a scoped original")
      } catch { XCTAssertEqual(error as? FormaError, .corruptStore) }
      stores.append(store)
    }
    let historical = directory.appendingPathComponent("forma-recovery-\(UUID().uuidString).json")
    let historicalRaw = Data("synthetic unknown owner evidence".utf8)
    try historicalRaw.write(to: historical)
    let before = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }
    XCTAssertEqual(before.count, 4)

    let reset = try await stores[0].reset(expectedRevision: 0)
    XCTAssertEqual(reset.revision, 1)
    for file in before {
      if file.lastPathComponent.hasPrefix(guestURL.lastPathComponent + ".recovery-") {
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
      } else {
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), file.lastPathComponent)
      }
    }
    XCTAssertEqual(try Data(contentsOf: historical), historicalRaw)
  }

  func testMemberRemovalClosesOnlyItsStoreAndRemovesOnlyItsIdentifiableArtifacts() async throws {
    let guestURL = try temporaryURL()
    let directory = guestURL.deletingLastPathComponent()
    let aURL = WorkspaceStore.memberStoreURL(directory: directory, memberReference: "a")
    let bURL = WorkspaceStore.memberStoreURL(directory: directory, memberReference: "b")
    let guest = try WorkspaceStore(url: guestURL, catalog: Fixtures.catalog)
    let a = try WorkspaceStore(url: aURL, catalog: Fixtures.catalog)
    let b = try WorkspaceStore(url: bURL, catalog: Fixtures.catalog)
    let guestSaved = try await guest.load(seed: Fixtures.workspace())
    let bSaved = try await b.load(seed: Fixtures.active(now: 1_000))
    _ = try await a.load(seed: Fixtures.workspace())
    let ownNames = [
      aURL.lastPathComponent + ".recovery-\(UUID().uuidString).json",
      aURL.lastPathComponent + ".unreadable-1790000000",
      aURL.lastPathComponent + "-wal.unreadable-1790000000",
      aURL.lastPathComponent + "-shm.unreadable-1790000000",
    ]
    let preservedNames = [
      guestURL.lastPathComponent + ".recovery-\(UUID().uuidString).json",
      bURL.lastPathComponent + ".recovery-\(UUID().uuidString).json",
      bURL.lastPathComponent + ".unreadable-1790000000",
      "forma-recovery-\(UUID().uuidString).json",
      aURL.lastPathComponent + ".unreadable-not-a-timestamp",
      aURL.lastPathComponent + "-other.unreadable-1790000000",
      aURL.lastPathComponent + ".recovery-not-a-uuid.json",
    ]
    let raw = Data("synthetic artifact".utf8)
    for name in ownNames + preservedNames {
      try raw.write(to: directory.appendingPathComponent(name))
    }

    try await a.removeLocalFiles()
    XCTAssertFalse(FileManager.default.fileExists(atPath: aURL.path))
    for name in ownNames {
      XCTAssertFalse(
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path))
    }
    for name in preservedNames {
      XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(name)), raw, name)
    }
    let guestLoaded = try await guest.load(seed: Workspace())
    let bLoaded = try await b.load(seed: Workspace())
    XCTAssertEqual(guestLoaded, guestSaved)
    XCTAssertEqual(bLoaded, bSaved)
    do {
      _ = try await a.load(seed: Workspace())
      XCTFail("A removed store must not silently recreate itself through its old actor")
    } catch {
      guard case .storage = error as? FormaError else {
        return XCTFail("Expected closed-store error")
      }
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: aURL.path))
  }

  func testRemovalRefusesUnexpectedArtifactDirectoriesWithoutDeletingTheirContents() async throws {
    let url = try temporaryURL()
    let store = try WorkspaceStore(url: url, catalog: Fixtures.catalog)
    let original = try await store.load(seed: Fixtures.workspace())
    let unexpected = URL(fileURLWithPath: url.path + ".unreadable-1790000000", isDirectory: true)
    try FileManager.default.createDirectory(at: unexpected, withIntermediateDirectories: false)
    let evidence = unexpected.appendingPathComponent("keep.txt")
    try Data("keep this synthetic evidence".utf8).write(to: evidence)
    do {
      try await store.removeLocalFiles()
      XCTFail("Unexpected directories must not grant recursive deletion authority")
    } catch {
      guard case .storage = error as? FormaError else { return XCTFail("Expected artifact error") }
    }
    XCTAssertTrue(FileManager.default.fileExists(atPath: evidence.path))
    let loaded = try await store.load(seed: Workspace())
    XCTAssertEqual(loaded, original)
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
      .filter {
        $0.lastPathComponent.hasPrefix(url.lastPathComponent + ".recovery-")
          && $0.pathExtension == "json"
      }
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
