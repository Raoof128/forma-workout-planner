import Foundation

/// Why an upload or download is waiting rather than failing.
public enum SyncWaitingReason: Equatable, Sendable {
  case offline
  case rateLimited(retryAfter: TimeInterval?)
  /// The account answered with a failure that a later attempt may survive.
  case transient(String)
}

public enum SyncSignedOutReason: Equatable, Sendable {
  case unauthorized
  case accountChanged
}

/// What the Account header shows.
public enum SyncStatus: Equatable, Sendable {
  /// Saved: nothing is waiting to be sent.
  case idle
  case saving
  /// Local work is safe on the device and will be sent when the account answers.
  case waiting(SyncWaitingReason)
  /// The account changed elsewhere. The local copy is untouched; the member
  /// chooses `resolveConflictUsingAccount()` or `resolveConflictKeepingLocal()`.
  case conflict(RemoteWorkspace)
  /// The app should sign out locally. The member cache stays on disk.
  case signedOut(SyncSignedOutReason)
  case failed(String)
}

/// Keeps one store and one account in step.
///
/// Pure logic over `WorkspaceTransport`; all state that must survive a crash
/// (the account revision, dirty, the pending operation) lives in the store, so a
/// new engine over the same file carries on exactly where the last one stopped.
/// Only the conflict and signed-out states are held here: a restart simply
/// resends the pending operation, which finds the same conflict again.
///
/// The engine never throws: storage and transport failures become a status.
public actor AccountSync {
  private let store: WorkspaceStore
  private let transport: any WorkspaceTransport
  private let makeOperationId: @Sendable () -> String

  public private(set) var status: SyncStatus = .idle
  private var conflict: RemoteWorkspace?
  private var signedOut: SyncSignedOutReason?
  private var subscribers: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]

  /// Network and resolution steps run one at a time, in arrival order. Local
  /// bookkeeping (`markDirty`) deliberately does not wait, so a commit made
  /// while a PUT is in flight is never blocked behind the network.
  private var running = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(
    store: WorkspaceStore, transport: any WorkspaceTransport,
    makeOperationId: @escaping @Sendable () -> String = { UUID().uuidString }
  ) {
    self.store = store
    self.transport = transport
    self.makeOperationId = makeOperationId
  }

  // MARK: Observing

  /// Current status first, then every change. Slow readers see the newest value.
  public func statusUpdates() -> AsyncStream<SyncStatus> {
    let id = UUID()
    let current = status
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      continuation.yield(current)
      subscribers[id] = continuation
      continuation.onTermination = { [weak self] _ in
        Task { await self?.removeSubscriber(id) }
      }
    }
  }

  private func removeSubscriber(_ id: UUID) { subscribers[id] = nil }

  @discardableResult
  private func publish(_ next: SyncStatus) -> SyncStatus {
    guard next != status else { return status }
    status = next
    for continuation in subscribers.values { continuation.yield(next) }
    return next
  }

  /// The store's sync bookkeeping, for the app's review and import screens.
  public func metadata() async throws -> SyncMetadata { try await store.syncMetadata() }

  // MARK: Local changes

  /// Call after each local commit (or commit with `markingDirty: true`). Cheap
  /// and immediate; follow it with `flush()`.
  public func markDirty() async {
    do { try await store.markDirty() } catch { fail(error) }
    if status == .idle { publish(.saving) }
  }

  // MARK: Sending

  /// Sends whatever is waiting, looping while local edits keep arriving.
  @discardableResult
  public func flush() async -> SyncStatus {
    await exclusive { await self.performFlush() }
  }

  private func performFlush() async -> SyncStatus {
    while true {
      if signedOut != nil || conflict != nil { return status }
      let metadata: SyncMetadata
      do { metadata = try await store.syncMetadata() } catch { return fail(error) }
      guard let serverRevision = metadata.serverRevision else {
        // A member cache is filled by the full fetch first; its placeholder
        // workspace must never be uploaded over the account.
        if metadata.pending == nil && !metadata.dirty { return publish(.idle) }
        return publish(.failed("Your account has not been downloaded on this device yet."))
      }
      let operation: PendingOperation
      if let pending = metadata.pending {
        operation = pending
      } else if metadata.dirty {
        // Written and committed before anything is sent.
        do {
          operation = try await store.capturePending(
            operationId: makeOperationId(), expectedRevision: serverRevision)
        } catch { return fail(error) }
      } else {
        return publish(.idle)
      }

      publish(.saving)
      let acknowledgement: RemoteWorkspace
      do {
        acknowledgement = try await transport.put(WorkspacePut(operation))
      } catch {
        return await handleSendFailure(error, operation: operation)
      }
      do {
        try await store.completePending(
          operationId: operation.operationId, serverRevision: acknowledgement.revision)
      } catch { return fail(error) }
      // Edits made during the request left the store dirty; go round again.
    }
  }

  private func handleSendFailure(_ error: any Error, operation: PendingOperation) async
    -> SyncStatus
  {
    guard let error = error as? WorkspaceTransportError else {
      return publish(.waiting(.transient(describe(error))))
    }
    switch error {
    case .staleRevision(let latest):
      // Keep the pending operation and the local copy. Nothing is overwritten
      // until the member chooses.
      conflict = latest
      return publish(.conflict(latest))
    case .unauthorized:
      signedOut = .unauthorized
      return publish(.signedOut(.unauthorized))
    case .accountChanged:
      signedOut = .accountChanged
      return publish(.signedOut(.accountChanged))
    case .operationReused:
      // The identifier was spent on other bytes: a bug, not a network state.
      // The edits are still local; send them again under a new identifier.
      do { try await store.discardPending(operationId: operation.operationId) } catch {
        return fail(error)
      }
      return publish(
        .failed("This change could not be sent safely. It is saved here and will be sent again."))
    case .invalid(let message):
      // The same bytes would be refused again. Drop the operation so later
      // edits are not stuck behind it; the data stays local and dirty.
      do { try await store.discardPending(operationId: operation.operationId) } catch {
        return fail(error)
      }
      return publish(.failed(message))
    case .rateLimited(let retryAfter):
      return publish(.waiting(.rateLimited(retryAfter: retryAfter)))
    case .offline:
      return publish(.waiting(.offline))
    case .transient(let message):
      return publish(.waiting(.transient(message)))
    }
  }

  // MARK: Reading

  /// Fetches the account's copy. A clean store takes a newer one; unsent work
  /// is sent, or becomes a conflict when the account moved past it.
  @discardableResult
  public func refresh() async -> SyncStatus {
    await exclusive { await self.performRefresh() }
  }

  private func performRefresh() async -> SyncStatus {
    if signedOut != nil || conflict != nil { return status }
    let remote: RemoteWorkspace
    do { remote = try await transport.fetch() } catch { return handleReadFailure(error) }
    // Anything may have happened locally during the request, so decide on what
    // the store says now, and let the store re-check at the moment it replaces.
    for _ in 0..<3 {
      let metadata: SyncMetadata
      do { metadata = try await store.syncMetadata() } catch { return fail(error) }
      if metadata.pending != nil {
        // The account having moved on proves nothing here: it may be this very
        // operation, applied before its acknowledgement was lost. Resending
        // gets the original acknowledgement back, or a real stale-revision.
        return await performFlush()
      }
      if metadata.dirty {
        guard let base = metadata.serverRevision else {
          return publish(.failed("Your account has not been downloaded on this device yet."))
        }
        if remote.revision > base {
          conflict = remote
          return publish(.conflict(remote))
        }
        return await performFlush()
      }
      if let current = metadata.serverRevision, remote.revision <= current {
        // Same revision, or a stale read that began before our own save.
        return publish(.idle)
      }
      do {
        if try await store.replaceWorkspace(
          with: remote.workspace, serverRevision: remote.revision, onlyIfClean: true) != nil
        {
          return publish(.idle)
        }
      } catch { return fail(error) }
      // An edit landed between the check and the replace; look again.
    }
    return publish(.failed("Your account could not be refreshed. Try again."))
  }

  /// The full fetch after sign-in: the account's copy replaces the member store.
  ///
  /// A member cache kept from an earlier session may hold edits the account has
  /// never seen. Those are not discarded unless `discardingLocalChanges` is set;
  /// without it such a store is reconciled like `refresh()` (send, or conflict).
  @discardableResult
  public func initialFetch(discardingLocalChanges: Bool = false) async -> SyncStatus {
    await exclusive {
      await self.performInitialFetch(discardingLocalChanges: discardingLocalChanges)
    }
  }

  private func performInitialFetch(discardingLocalChanges: Bool) async -> SyncStatus {
    signedOut = nil
    conflict = nil
    if !discardingLocalChanges {
      let metadata: SyncMetadata
      do { metadata = try await store.syncMetadata() } catch { return fail(error) }
      if metadata.serverRevision != nil && (metadata.pending != nil || metadata.dirty) {
        return await performRefresh()
      }
    }
    let remote: RemoteWorkspace
    do { remote = try await transport.fetch() } catch { return handleReadFailure(error) }
    do {
      _ = try await store.replaceWorkspace(with: remote.workspace, serverRevision: remote.revision)
    } catch { return fail(error) }
    return publish(.idle)
  }

  private func handleReadFailure(_ error: any Error) -> SyncStatus {
    guard let error = error as? WorkspaceTransportError else {
      return publish(.waiting(.transient(describe(error))))
    }
    switch error {
    case .unauthorized:
      signedOut = .unauthorized
      return publish(.signedOut(.unauthorized))
    case .accountChanged:
      signedOut = .accountChanged
      return publish(.signedOut(.accountChanged))
    case .rateLimited(let retryAfter):
      return publish(.waiting(.rateLimited(retryAfter: retryAfter)))
    case .offline:
      return publish(.waiting(.offline))
    case .transient(let message):
      return publish(.waiting(.transient(message)))
    case .invalid(let message):
      return publish(.failed(message))
    case .staleRevision, .operationReused:
      return publish(.failed("The account sent an unexpected answer. Try again."))
    }
  }

  // MARK: Conflicts

  /// Replaces the local workspace with the account's copy shown in the
  /// conflict. Local edits that were not sent are given up, as the member chose.
  @discardableResult
  public func resolveConflictUsingAccount() async -> SyncStatus {
    await exclusive { await self.performUseAccount() }
  }

  private func performUseAccount() async -> SyncStatus {
    guard let latest = conflict else { return status }
    do {
      _ = try await store.replaceWorkspace(with: latest.workspace, serverRevision: latest.revision)
    } catch { return fail(error) }
    conflict = nil
    return publish(.idle)
  }

  /// Sends the local workspace over the account's copy. The pending operation is
  /// re-captured against the revision the member saw, under a new identifier;
  /// should the account move again meanwhile, it is a new conflict.
  @discardableResult
  public func resolveConflictKeepingLocal() async -> SyncStatus {
    await exclusive { await self.performKeepLocal() }
  }

  private func performKeepLocal() async -> SyncStatus {
    guard let latest = conflict else { return status }
    do {
      _ = try await store.capturePending(
        operationId: makeOperationId(), expectedRevision: latest.revision)
    } catch { return fail(error) }
    conflict = nil
    return await performFlush()
  }

  // MARK: Import

  /// Replaces the whole account with `workspace` (the website's "restore or
  /// import"). It becomes the local copy and a pending operation in one commit,
  /// then is sent against the current account revision, so an account that has
  /// moved on is a conflict, never silently overwritten. If something is already
  /// waiting to be sent it is settled first; the import does not run while the
  /// account is unreachable or in conflict.
  ///
  /// `reviewedRevision` is the account revision the member reviewed the import
  /// against (`metadata().serverRevision`); a different current revision refuses.
  /// A refusal returns `.failed` without changing anything or the shown status.
  @discardableResult
  public func replaceAccount(with workspace: Workspace, reviewedRevision: Int? = nil) async
    -> SyncStatus
  {
    await exclusive { await self.performReplaceAccount(workspace, reviewedRevision) }
  }

  private func performReplaceAccount(_ workspace: Workspace, _ reviewedRevision: Int?) async
    -> SyncStatus
  {
    if signedOut != nil || conflict != nil { return status }
    var metadata: SyncMetadata
    do { metadata = try await store.syncMetadata() } catch { return fail(error) }
    if metadata.pending != nil {
      let settled = await performFlush()
      guard settled == .idle else { return settled }
      do { metadata = try await store.syncMetadata() } catch { return fail(error) }
    }
    guard let base = metadata.serverRevision else {
      return .failed("Your account has not been downloaded on this device yet.")
    }
    if let reviewedRevision, reviewedRevision != base {
      return .failed(
        "Your cloud workspace changed after you reviewed this backup. Review it again before replacing your data."
      )
    }
    do {
      _ = try await store.replaceWorkspace(
        with: workspace, serverRevision: base,
        uploading: (operationId: makeOperationId(), expectedRevision: base))
    } catch {
      // Refused before anything changed, e.g. a workspace that fails validation.
      return .failed((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }
    return await performFlush()
  }

  // MARK: Plumbing

  private func exclusive(_ body: () async -> SyncStatus) async -> SyncStatus {
    await acquire()
    defer { release() }
    return await body()
  }

  private func acquire() async {
    if !running {
      running = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty {
      running = false
    } else {
      waiters.removeFirst().resume()
    }
  }

  @discardableResult
  private func fail(_ error: any Error) -> SyncStatus {
    publish(.failed(describe(error)))
  }

  private func describe(_ error: any Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
  }
}
