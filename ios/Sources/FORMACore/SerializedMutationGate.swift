/// Serializes a main-actor client's local transactions in arrival order.
///
/// Acquire before reading the current workspace; always release in `defer`.
/// This gate is deliberately non-reentrant. Acquisition does not throw on task
/// cancellation: an enqueued local save must finish rather than disappear when
/// its presenting view leaves the screen. Keep the protected operation bounded
/// and do not await a second acquisition while already owning this gate.
@MainActor
public final class SerializedMutationGate {
  private var held = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init() {}

  public func acquire() async {
    if !held {
      held = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  public func release() {
    precondition(held, "Release requires ownership of the mutation gate.")
    if waiters.isEmpty {
      held = false
    } else {
      // Ownership transfers before the continuation runs; a fresh arrival
      // cannot pass an existing waiter in the meantime.
      waiters.removeFirst().resume()
    }
  }
}
