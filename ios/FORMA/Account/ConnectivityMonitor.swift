import Network
import os

/// Tells the app when the network comes back, so waiting changes are sent at
/// once rather than at the next timed retry. It only watches reachability; it
/// reads no addresses and sends nothing.
final class ConnectivityMonitor: Sendable {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "dev.raoufabedini.forma.connectivity")
  private let wasReachable = OSAllocatedUnfairLock(initialState: true)

  /// `onReconnect` runs each time the network goes from unavailable to available.
  func start(onReconnect: @escaping @Sendable () -> Void) {
    let reachable = wasReachable
    monitor.pathUpdateHandler = { path in
      let now = path.status == .satisfied
      let before = reachable.withLock { state -> Bool in
        let previous = state
        state = now
        return previous
      }
      if now && !before { onReconnect() }
    }
    monitor.start(queue: queue)
  }

  func stop() { monitor.cancel() }
}
