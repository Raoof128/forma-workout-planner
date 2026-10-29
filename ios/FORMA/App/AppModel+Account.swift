import FORMACore
import Foundation

// Accounts and sync, on top of the local-first store.
//
// Which store is open
// -------------------
// Signed out, the open store is the guest store (workspace.sqlite), exactly as
// before accounts existed. Signing in opens a second store, one SQLite file per
// member (`WorkspaceStore.memberStoreURL`), so a shared phone never mixes
// accounts and guest training is never merged into one silently. The guest
// store stays open and untouched. Signing out switches back to it; the member's
// file stays on disk (with any unsent edits) until that member signs in again
// or chooses "Sign out and remove from this iPhone". Guest training reaches an
// account only through the explicit "Bring your phone training" review.
//
// How sync is triggered
// ---------------------
// `AccountSync` schedules nothing itself, so this file does:
//   - after every successful local commit: `markDirty()` then `flush()`, off the
//     commit path (the screens never wait for the network);
//   - at launch and when the scene becomes active: `refresh()` (which also sends
//     anything waiting);
//   - after a failed attempt that is only waiting (offline, rate limited, 5xx):
//     a timed retry with back-off, and at once when the network returns;
//   - on sign-in: `initialFetch()`.
// After any call that may have replaced the member store's workspace, the open
// workspace is reloaded from the store, because a screen holding an older local
// revision would otherwise fail its next save with `conflictingRevision`.

/// A signed-in member whose saved copy is not on this iPhone yet.
enum AccountGate: Equatable {
  case loading
  case unavailable(String)
}

/// What the Account header and the banners say about syncing.
enum SyncDisplay: Equatable {
  case saved
  case saving
  case offline
  case waiting(String)
  case conflict
  case failed(String)

  var title: String {
    switch self {
    case .saved: "Saved"
    case .saving: "Saving"
    case .offline: "Offline"
    case .waiting: "Will retry"
    case .conflict: "Needs review"
    case .failed: "Not synced"
    }
  }

  var detail: String {
    switch self {
    case .saved: "Your training is saved to your account."
    case .saving: "Sending your latest changes."
    case .offline:
      "You’re offline. Changes are saved on this iPhone and send when you’re back online."
    case .waiting(let message), .failed(let message): message
    case .conflict:
      "Training data changed on another device. Review it before more changes are sent."
    }
  }

  var symbol: String {
    switch self {
    case .saved: "checkmark.icloud"
    case .saving: "arrow.triangle.2.circlepath.icloud"
    case .offline: "icloud.slash"
    case .waiting: "clock.arrow.circlepath"
    case .conflict: "exclamationmark.icloud"
    case .failed: "exclamationmark.icloud"
    }
  }

  /// Worth interrupting Today for.
  var needsAttention: Bool {
    switch self {
    case .saved, .saving: false
    default: true
    }
  }
}

extension AppModel {
  /// Nil while signed out.
  var syncDisplay: SyncDisplay? {
    guard activeMember != nil else { return nil }
    switch syncStatus {
    case .idle: return .saved
    case .saving: return .saving
    case .waiting(.offline): return .offline
    case .waiting(.rateLimited):
      return .waiting(
        "Too many saves in a short time. FORMA will try again in a minute. Your changes are saved on this iPhone."
      )
    case .waiting(.transient):
      return .waiting(
        "FORMA couldn’t be reached right now. Your changes are saved on this iPhone and send automatically."
      )
    case .conflict: return .conflict
    case .signedOut: return .failed("You’ve been signed out. Sign in again to keep syncing.")
    case .failed(let message): return .failed(message)
    }
  }

  var syncConflict: RemoteWorkspace? {
    if case .conflict(let remote) = syncStatus { remote } else { nil }
  }

  /// Changes whenever the open store changes owner, so every screen starts
  /// clean: no pushed screen can keep showing the other account's training.
  var storeIdentity: String { activeMember ?? "guest" }
  /// Consent is scoped to both the service origin and the member/guest store.
  var widgetOwnerIdentity: String {
    (accountEnvironment?.storage.origin.absoluteString ?? "local") + "|" + storeIdentity
  }

  // MARK: Switching stores

  /// Called once the member has signed in: opens their saved copy and starts
  /// syncing it. False when the copy could not be opened (nothing changed).
  func activateAccount(_ profile: AccountProfile) async -> Bool {
    guard canSwitchAccount, let environment = accountEnvironment else { return false }
    pendingMutations += 1
    await mutationGate.acquire()
    defer {
      mutationGate.release()
      pendingMutations -= 1
    }
    guard canSwitchAccount else { return false }
    // Hide the prior owner's snapshot before any asynchronous store operation.
    widgets.publish(nil)
    do {
      let opened = try await Self.openMemberStore(
        directory: environment.storage.directory, member: profile.id, catalog: catalog)
      store = opened.store
      activeMember = profile.id
      widgets.selectOwner(widgetOwnerIdentity)
      accountGate = opened.downloaded ? nil : .loading
      workspace = opened.downloaded ? opened.workspace : nil
      receipt = nil
      workoutPresented = false
      errorMessage = nil
      watch.reset()
      startSync(profile: profile, store: opened.store, initial: true)
      return true
    } catch {
      widgets.publish(workspace)
      return false
    }
  }

  /// The member signed out (or the account ended the session): back to the
  /// guest store. Their saved copy stays on disk unless `removeLocalCopy`.
  func accountDidSignOut(removeLocalCopy: Bool) async {
    let leaving = activeMember
    let leavingStore = store
    let leavingSync = sync
    stopSync()
    await leavingSync?.stop()
    pendingMutations += 1
    await mutationGate.acquire()
    defer {
      mutationGate.release()
      pendingMutations -= 1
    }
    // A late Watch start from the departed member must not start a guest routine
    // merely because the two spaces use the same starter routine identifier.
    watch.cancelWaiting()
    pendingStart = nil
    activeMember = nil
    widgets.selectOwner(widgetOwnerIdentity)
    accountGate = nil
    receipt = nil
    workoutPresented = false
    errorMessage = nil
    // Nothing of the member's is shown while the guest copy loads.
    workspace = nil
    store = guestStore
    await watch.end(save: true)
    guard let guestStore, let seedWorkspace else { return }
    do {
      workspace = try await guestStore.load(seed: seedWorkspace)
    } catch {
      loadFailure =
        "FORMA couldn't open the local training store. No existing data has been replaced. \(error.localizedDescription)"
    }
    if removeLocalCopy, leaving != nil, accountEnvironment != nil,
      let metadata = try? await leavingSync?.metadata(), !metadata.dirty, metadata.pending == nil
    {
      // Re-check after draining local commits. A save may have landed while
      // the sign-out request was in flight, after the original review.
      do {
        try await leavingStore?.removeLocalFiles()
      } catch {
        errorMessage =
          "You’re signed out, but the saved account copy couldn’t be fully removed. \(error.localizedDescription)"
      }
    }
  }

  struct OpenedMemberStore: Sendable {
    let store: WorkspaceStore
    let workspace: Workspace
    /// False until the first full fetch: the workspace is then only a
    /// placeholder, which the sync engine never uploads.
    let downloaded: Bool
  }

  @concurrent
  nonisolated static func openMemberStore(
    directory: URL, member: String, catalog: [Exercise]
  ) async throws -> OpenedMemberStore {
    let url = WorkspaceStore.memberStoreURL(directory: directory, memberReference: member)
    func open() async throws -> OpenedMemberStore {
      let store = try WorkspaceStore(url: url, catalog: catalog)
      let placeholder = Workspace(revision: 0, profile: Profile(name: "FORMA member", goal: 4))
      let workspace = try await store.load(seed: placeholder)
      let downloaded = try await store.syncMetadata().serverRevision != nil
      return OpenedMemberStore(store: store, workspace: workspace, downloaded: downloaded)
    }
    let opened: OpenedMemberStore
    do {
      opened = try await open()
    } catch let error as FormaError where error == .corruptStore {
      // The member's copy is only a cache of the account. Set the damaged file
      // aside (it is kept, not deleted) and download a fresh one.
      Self.setAside(url)
      opened = try await open()
    }
    try protectFiles(in: directory)
    return opened
  }

  nonisolated private static func setAside(_ url: URL) {
    let stamp = Int(Date.now.timeIntervalSince1970)
    for suffix in ["", "-wal", "-shm"] {
      let source = URL(fileURLWithPath: url.path + suffix)
      let target = URL(fileURLWithPath: url.path + suffix + ".unreadable-\(stamp)")
      try? FileManager.default.moveItem(at: source, to: target)
    }
  }

  nonisolated static func removeMemberFiles(directory: URL, member: String) {
    let base = WorkspaceStore.memberStoreURL(directory: directory, memberReference: member)
    for suffix in ["", "-wal", "-shm"] {
      try? FileManager.default.removeItem(at: URL(fileURLWithPath: base.path + suffix))
    }
  }

  // MARK: Starting and stopping sync

  func startSync(profile: AccountProfile, store: WorkspaceStore, initial fresh: Bool) {
    guard let environment = accountEnvironment else { return }
    stopSync()
    let generation = syncGeneration
    let engine = AccountSync(
      store: store,
      transport: URLSessionWorkspaceTransport(client: environment.client, member: profile.id))
    sync = engine
    syncStatus = .idle
    retryAttempt = 0
    syncObserver = Task { [weak self] in
      for await status in await engine.statusUpdates() {
        guard let self else { return }
        self.syncStatusChanged(status, generation: generation)
      }
    }
    let monitor = ConnectivityMonitor()
    monitor.start { [weak self] in
      Task { @MainActor in
        guard let self, self.syncGeneration == generation else { return }
        if case .waiting = self.syncStatus { await self.syncNow() }
      }
    }
    connectivity = monitor
    Task { [weak self] in await self?.firstSync(generation: generation, fresh: fresh) }
  }

  func stopSync() {
    syncGeneration += 1
    syncObserver?.cancel()
    syncObserver = nil
    retryTask?.cancel()
    retryTask = nil
    connectivity?.stop()
    connectivity = nil
    let previous = sync
    Task { await previous?.stop() }
    sync = nil
    syncStatus = .idle
    retryAttempt = 0
  }

  private func firstSync(generation: Int, fresh: Bool) async {
    guard generation == syncGeneration, let sync else { return }
    let status = fresh ? await sync.initialFetch() : await sync.refresh()
    guard generation == syncGeneration else { return }
    await reloadWorkspaceFromStore(after: status)
    attempted(status, generation: generation)
    if !fresh { await account.refreshSession() }
  }

  private func syncStatusChanged(_ status: SyncStatus, generation: Int) {
    guard generation == syncGeneration else { return }
    if status != syncStatus { syncStatus = status }
    if case .signedOut(let reason) = status {
      Task { [weak self] in
        guard let self, self.syncGeneration == generation else { return }
        await account.sessionEnded(reason == .accountChanged ? .accountChanged : .sessionEnded)
      }
    }
  }

  /// What a finished attempt means for the next one.
  private func attempted(_ status: SyncStatus, generation: Int) {
    guard generation == syncGeneration else { return }
    switch status {
    case .idle:
      retryAttempt = 0
      retryTask?.cancel()
      retryTask = nil
    case .waiting(let reason):
      scheduleRetry(reason, generation: generation)
    default:
      break
    }
  }

  private func scheduleRetry(_ reason: SyncWaitingReason, generation: Int) {
    let delays: [Double] = [5, 15, 30, 60, 120, 300]
    let seconds: Double
    if case .rateLimited(let after) = reason {
      seconds = max(5, after ?? 60)
    } else {
      seconds = delays[min(retryAttempt, delays.count - 1)]
    }
    retryAttempt += 1
    retryTask?.cancel()
    retryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled, let self, self.syncGeneration == generation else { return }
      await self.syncNow()
    }
  }

  // MARK: Sending and receiving

  /// After a local commit. Cheap; the network part runs off the commit path.
  func sendAfterCommit() {
    guard let sync else { return }
    let generation = syncGeneration
    Task { [weak self] in
      await sync.markDirty()
      let status = await sync.flush()
      self?.attempted(status, generation: generation)
    }
  }

  /// Fetches the account's copy and sends anything waiting.
  func syncNow() async {
    guard let sync else { return }
    let generation = syncGeneration
    let before = try? await sync.metadata().serverRevision
    let status = await sync.refresh()
    guard generation == syncGeneration else { return }
    let after = try? await sync.metadata().serverRevision
    if workspace == nil || before != after { await reloadWorkspaceFromStore(after: status) }
    attempted(status, generation: generation)
  }

  /// Launch is handled by `load()`; this is every return to the foreground.
  func sceneBecameActive() async {
    refreshTrainingClock()
    guard activeMember != nil, Date.now.timeIntervalSince(lastForegroundSync) > 5 else { return }
    lastForegroundSync = .now
    await account.refreshSession()
    await syncNow()
  }

  func refreshTrainingClock() {
    trainingNow = .now
    widgets.publish(workspace, at: trainingNow)
  }

  /// "Retry connection" on the loading screen.
  func retryAccountLoad() async {
    guard accountGate != nil else { return }
    accountGate = .loading
    await syncNow()
  }

  /// The open workspace may be older than the store after the sync engine
  /// replaced it. Show the store's copy; until then a save would be refused.
  func reloadWorkspaceFromStore(after status: SyncStatus? = nil) async {
    await mutationGate.acquire()
    defer { mutationGate.release() }
    guard let store, activeMember != nil, let sync else { return }
    do {
      guard try await sync.metadata().serverRevision != nil else {
        if workspace == nil { accountGate = .unavailable(gateMessage(status ?? syncStatus)) }
        return
      }
      let stored = try await store.load(
        seed: Workspace(revision: 0, profile: Profile(name: "FORMA member", goal: 4)))
      if workspace?.revision != stored.revision { workspace = stored }
      if accountGate != nil { accountGate = nil }
    } catch {
      if workspace == nil { accountGate = .unavailable(error.localizedDescription) }
    }
  }

  private func gateMessage(_ status: SyncStatus) -> String {
    switch status {
    case .waiting(.offline):
      return "You appear to be offline. Your training will load when you’re back online."
    case .failed(let message): return message
    default: return "Your training couldn’t be loaded from your account right now."
    }
  }

  // MARK: Conflicts

  /// "Reload cloud data": the account's copy replaces this iPhone's unsent edits.
  func resolveConflictUsingAccount() async {
    guard let sync else { return }
    let generation = syncGeneration
    let status = await sync.resolveConflictUsingAccount()
    await reloadWorkspaceFromStore(after: status)
    attempted(status, generation: generation)
  }

  /// "Keep my version": this iPhone's copy replaces the account's.
  func resolveConflictKeepingLocal() async {
    guard let sync else { return }
    let generation = syncGeneration
    let status = await sync.resolveConflictKeepingLocal()
    attempted(status, generation: generation)
  }

  // MARK: Signing out

  /// True when nothing is left unsent. Gives a send in progress a few seconds.
  func settleBeforeSignOut() async -> Bool {
    guard let sync else { return true }
    Task { _ = await sync.flush() }
    for _ in 0..<24 {
      // The status stream can lag behind a durable commit. Only the store
      // can prove there is nothing left to upload before removing a cache.
      guard let metadata = try? await sync.metadata() else { return false }
      if !metadata.dirty && metadata.pending == nil { return true }
      switch await sync.status {
      case .conflict, .waiting, .failed, .signedOut: return false
      case .idle, .saving: break
      }
      try? await Task.sleep(for: .milliseconds(250))
    }
    return false
  }

  // MARK: Bringing phone training

  /// This iPhone's guest training, and whether to offer it.
  func loadPhoneTraining() async -> (offer: PhoneTrainingOffer, workspace: Workspace?) {
    guard let member = activeMember, let guestStore, let seedWorkspace,
      let directory = accountEnvironment?.storage.directory
    else {
      return (.none, nil)
    }
    do {
      let record = try PhoneTrainingLedger.read(in: directory)
      if let record {
        if record.status == .imported {
          return (record.member == member ? .importedHere : .importedElsewhere, nil)
        }
        if record.member != member { return (.reservedElsewhere, nil) }
      }
      let guest = try await guestStore.load(seed: seedWorkspace)
      guard PhoneTrainingLedger.hasTraining(guest) else {
        return record == nil
          ? (.none, nil)
          : (.unavailable("The reserved phone training is no longer available to review."), nil)
      }
      let summary = PhoneTrainingSummary(
        routines: guest.routines.count, workouts: guest.history.count,
        workoutInProgress: guest.active != nil)
      return (
        record == nil ? .available(summary) : .reservedHere(summary), guest
      )
    } catch {
      return (
        .unavailable("Phone training could not be checked safely. \(error.localizedDescription)"),
        nil
      )
    }
  }

  /// The account revision a review of the account's copy is pinned to.
  func reviewedAccountRevision() async -> Int? {
    guard let sync, let metadata = try? await sync.metadata() else { return nil }
    return metadata.serverRevision
  }

  /// Replaces the account's training with this phone's (the website's import
  /// semantics). `reviewedRevision` is the revision the member saved a copy of.
  func bringPhoneTraining(_ phone: Workspace, reviewedRevision: Int?) async -> SyncStatus {
    guard let sync, let member = activeMember,
      let directory = accountEnvironment?.storage.directory
    else {
      return .failed("Your account’s local storage is not available. Sign in again to retry.")
    }
    let generation = syncGeneration
    let before = workspace?.revision
    let reservation: PhoneTrainingLedger.Record
    do {
      reservation = try PhoneTrainingLedger.reserve(member: member, in: directory)
    } catch {
      return .failed(
        "The import did not start because its ownership could not be saved. \(error.localizedDescription)"
      )
    }
    let status = await sync.replaceAccount(with: phone, reviewedRevision: reviewedRevision)
    guard generation == syncGeneration else {
      return .failed("Your signed-in account changed. Review the import again.")
    }
    await reloadWorkspaceFromStore(after: status)
    guard generation == syncGeneration, activeMember == member else {
      return .failed("Your signed-in account changed. Review the import again.")
    }
    // An ownership-finalization error must not strand an already committed
    // account upload: retain the ordinary sync retry behavior independently.
    attempted(status, generation: generation)
    if let current = workspace, current.revision != before {
      var expected = phone
      expected.revision = current.revision
      if current == expected {
        do {
          try PhoneTrainingLedger.complete(reservation, in: directory)
        } catch {
          return .failed(
            "Your training may already be in this account, but the import could not be confirmed. Its ownership remains assigned to this account. Review its training and import status before retrying. \(error.localizedDescription)"
          )
        }
        return status
      }
    }
    switch status {
    case .idle, .waiting:
      return .failed(
        "The import was not confirmed. Your phone training remains reserved for this account. Finish syncing, then review and retry the import."
      )
    default:
      return status
    }
  }
}
