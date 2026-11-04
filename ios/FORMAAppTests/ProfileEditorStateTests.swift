import FORMACore
import Foundation
import XCTest

@testable import FORMA

@MainActor
private final class HeldProfileNameSync {
  private let started: XCTestExpectation
  private var continuation: CheckedContinuation<Void, any Error>?
  private var result: Result<Void, any Error>?
  private(set) var names: [String] = []

  init(started: XCTestExpectation) { self.started = started }

  func send(_ name: String) async throws {
    names.append(name)
    started.fulfill()
    if let result { return try result.get() }
    try await withCheckedThrowingContinuation { continuation = $0 }
  }

  func finish(_ result: Result<Void, any Error> = .success(())) {
    self.result = result
    continuation?.resume(with: result)
    continuation = nil
  }
}

@MainActor
final class ProfileEditorStateTests: XCTestCase {
  private func fixture() async throws -> (ProfileEditorState, AppModel, WorkspaceStore) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    let store = try WorkspaceStore(
      url: directory.appendingPathComponent("profile.sqlite"), catalog: [])
    let model = AppModel(
      liveActivity: WorkoutLiveActivityController(host: InertWorkoutActivityHost()))
    model.store = store
    model.workspace = try await store.load(
      seed: Workspace(profile: Profile(name: "Original", goal: 4)))
    let draft = ProfileEditorState()
    draft.load(try XCTUnwrap(model.workspace).profile, owner: model.storeIdentity)
    return (draft, model, store)
  }

  func testLateEditsSurviveANameSyncAndSaveAgainstTheAcknowledgedProfile() async throws {
    let (draft, model, store) = try await fixture()
    draft.name = "Submitted"
    draft.goal = 5
    let started = expectation(description: "The synthetic name sync started after local save")
    let remote = HeldProfileNameSync(started: started)
    let save = Task { await draft.save(in: model) { try await remote.send($0) } }
    await fulfillment(of: [started], timeout: 5)
    XCTAssertTrue(draft.saving)
    XCTAssertEqual(model.workspace?.profile.name, "Submitted")
    draft.name = "Newer draft"
    draft.goal = 6
    draft.rest = 120
    remote.finish()
    let dismissed = await save.value

    XCTAssertFalse(dismissed)
    XCTAssertFalse(draft.saving)
    XCTAssertEqual(draft.name, "Newer draft")
    XCTAssertEqual(draft.goal, 6)
    XCTAssertEqual(draft.rest, 120)
    XCTAssertEqual(draft.original?.name, "Submitted")
    XCTAssertTrue(draft.failure?.contains("Newer profile edits") == true)
    let retried = await draft.save(in: model) { _ in }
    XCTAssertTrue(retried, "Our own saved profile must not look like an external conflict")
    let persisted = try await store.load(seed: Workspace())
    XCTAssertEqual(persisted.profile.name, "Newer draft")
    XCTAssertEqual(persisted.profile.goal, 6)
    XCTAssertEqual(persisted.profile.restSeconds, 120)
    XCTAssertEqual(remote.names, ["Submitted"])
  }

  func testFailedAccountSyncKeepsARetryAndAllowsChangedFieldsAfterLocalSave() async throws {
    let (draft, model, store) = try await fixture()
    draft.name = "Saved locally"
    let failed = await draft.save(in: model) { _ in throw URLError(.notConnectedToInternet) }
    XCTAssertFalse(failed)
    XCTAssertFalse(draft.saving)
    XCTAssertTrue(draft.needsAccountRetry, "Save must remain available even without newer edits")
    XCTAssertFalse(draft.changed)
    XCTAssertEqual(draft.original?.name, "Saved locally")
    draft.goal = 7
    let retried = await draft.save(in: model) { _ in }
    XCTAssertTrue(retried)
    XCTAssertFalse(draft.needsAccountRetry)
    let persisted = try await store.load(seed: Workspace())
    XCTAssertEqual(persisted.profile.name, "Saved locally")
    XCTAssertEqual(persisted.profile.goal, 7)
    XCTAssertNil(draft.failure)
  }

  func testDuplicateSaveDuringNameSyncDoesNotSubmitAgain() async throws {
    let (draft, model, store) = try await fixture()
    draft.name = "One request"
    let revision = try XCTUnwrap(model.workspace).revision
    let started = expectation(description: "Name sync is pending")
    let remote = HeldProfileNameSync(started: started)
    let first = Task { await draft.save(in: model) { try await remote.send($0) } }
    await fulfillment(of: [started], timeout: 5)
    let duplicate = await draft.save(in: model) { _ in XCTFail("Duplicate request") }
    remote.finish()
    let finished = await first.value
    XCTAssertFalse(duplicate)
    XCTAssertTrue(finished)
    XCTAssertEqual(remote.names, ["One request"])
    let persisted = try await store.load(seed: Workspace())
    XCTAssertEqual(persisted.revision, revision + 1)
  }

  func testDraftCannotSaveIntoAnotherTrainingOwner() async throws {
    let (draft, model, store) = try await fixture()
    draft.name = "Previous owner draft"
    model.activeMember = "another-synthetic-member"
    let saved = await draft.save(in: model) { _ in XCTFail("Previous owner must not send a request")
    }
    XCTAssertFalse(saved)
    let persisted = try await store.load(seed: Workspace())
    XCTAssertEqual(persisted.profile.name, "Original")
  }

  func testQueuedSaveCannotClearTheNextOwnersFailure() async throws {
    let (draft, model, store) = try await fixture()
    draft.name = "Queued old owner edit"
    await model.mutationGate.acquire()
    let queued = Task {
      await draft.save(in: model) { _ in XCTFail("Previous owner must not send a request") }
    }
    for _ in 0..<1_000 {
      if model.pendingMutations == 1 { break }
      await Task.yield()
    }
    let reachedCommit = model.pendingMutations == 1
    model.activeMember = "another-synthetic-member"
    model.errorMessage = "The new owner's saved data could not open."
    model.mutationGate.release()
    let saved = await queued.value
    XCTAssertTrue(reachedCommit)
    XCTAssertFalse(saved)
    XCTAssertEqual(model.errorMessage, "The new owner's saved data could not open.")
    let persisted = try await store.load(seed: Workspace())
    XCTAssertEqual(persisted.profile.name, "Original")
  }
}
