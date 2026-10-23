import XCTest

@testable import FORMACore

final class SerializedMutationGateTests: XCTestCase, @unchecked Sendable {
  @MainActor
  func testConcurrentMutationsHaveOneOwnerAndRetainFIFOOrder() async {
    let gate = SerializedMutationGate()
    await gate.acquire()
    var order: [Int] = []
    var owners = 0
    var maximumOwners = 0
    var tasks: [Task<Void, Never>] = []
    for index in 0..<20 {
      let started = ReadinessSignal()
      tasks.append(
        Task { @MainActor in
          started.signal()
          await gate.acquire()
          defer {
            owners -= 1
            gate.release()
          }
          owners += 1
          maximumOwners = max(maximumOwners, owners)
          order.append(index)
          await Task.yield()
        })
      // The task runs on this actor until acquire suspends, so observing its
      // readiness also establishes that it joined the queue before the next.
      await started.wait()
    }
    XCTAssertTrue(order.isEmpty)
    gate.release()
    for task in tasks { await task.value }
    XCTAssertEqual(order, Array(0..<20))
    XCTAssertEqual(maximumOwners, 1)
    XCTAssertEqual(owners, 0)
  }

  @MainActor
  func testFailureReleasesNextOwnerAndGateCanBeAcquiredAgain() async {
    enum ExpectedFailure: Error { case injected }
    let gate = SerializedMutationGate()
    await gate.acquire()
    var order: [String] = []
    let failedStarted = ReadinessSignal()
    let failing = Task { @MainActor in
      failedStarted.signal()
      await gate.acquire()
      defer { gate.release() }
      order.append("failed")
      throw ExpectedFailure.injected
    }
    await failedStarted.wait()
    let nextStarted = ReadinessSignal()
    let next = Task { @MainActor in
      nextStarted.signal()
      await gate.acquire()
      defer { gate.release() }
      order.append("next")
    }
    await nextStarted.wait()
    gate.release()
    do {
      try await failing.value
      XCTFail("The first mutation should fail")
    } catch {}
    await next.value
    await gate.acquire()
    order.append("reused")
    gate.release()
    XCTAssertEqual(order, ["failed", "next", "reused"])
  }

  @MainActor
  func testCancellingAQueuedCallerDoesNotDropItsLocalTransaction() async {
    let gate = SerializedMutationGate()
    await gate.acquire()
    let started = ReadinessSignal()
    var committed = false
    let queued = Task { @MainActor in
      started.signal()
      await gate.acquire()
      defer { gate.release() }
      committed = true
    }
    await started.wait()
    queued.cancel()
    XCTAssertFalse(committed)
    gate.release()
    await queued.value
    XCTAssertTrue(committed)
  }
}

@MainActor
private final class ReadinessSignal {
  private var ready = false
  private var continuation: CheckedContinuation<Void, Never>?
  func signal() {
    ready = true
    continuation?.resume()
    continuation = nil
  }
  func wait() async {
    if ready { return }
    await withCheckedContinuation { continuation = $0 }
  }
}
