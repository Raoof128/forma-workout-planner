import Foundation
import XCTest

@testable import FORMASurfaces

final class SnapshotReaderTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)
  private let url = URL(fileURLWithPath: "/group/training-widget-v1.json")

  private func ready(expiring seconds: TimeInterval = 3600) -> TrainingSnapshot {
    TrainingSnapshot(
      epoch: "epoch", revision: 1, generatedAt: now, expiresAt: now.addingTimeInterval(seconds),
      state: .ready,
      routine: .init(id: "r", name: "Upper body", exercises: 4, minutes: 35),
      week: .init(sessions: 1, goal: 4, days: [true, false, false, false, false, false, false]))
  }

  private func read(
    size: () throws -> Int?, load: () throws -> Data = { Data() }
  ) -> SnapshotReadResult {
    SnapshotReader.read(
      url: url, at: now, fileSize: { _ in try size() }, load: { _ in try load() },
      modified: { _ in self.published })
  }

  private let published = Date(timeIntervalSince1970: 1_793_200_000 - 90)

  private func cocoa(_ code: CocoaError.Code) -> Error { CocoaError(code) }

  func testReadableFileDecodes() throws {
    let data = try JSONEncoder().encode(ready())
    XCTAssertEqual(read(size: { data.count }, load: { data }), .snapshot(ready()))
  }

  func testLockedFileIsProtectedNotBroken() throws {
    // Complete protection while locked: metadata is visible, contents are refused.
    let denied = read(size: { 200 }, load: { throw self.cocoa(.fileReadNoPermission) })
    XCTAssertEqual(denied, .protectedDataUnavailable(lastPublished: published))
    let posix = read(size: { 200 }, load: { throw POSIXError(.EPERM) })
    XCTAssertEqual(posix, .protectedDataUnavailable(lastPublished: published))
    let wrapped = read(
      size: { 200 },
      load: {
        throw NSError(
          domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
          userInfo: [NSUnderlyingErrorKey: POSIXError(.EPERM)])
      })
    XCTAssertEqual(wrapped, .protectedDataUnavailable(lastPublished: published))
    XCTAssertEqual(
      read(size: { throw self.cocoa(.fileReadNoPermission) }),
      .protectedDataUnavailable(lastPublished: published))
  }

  func testMissingCorruptAndOversizedFilesAreUnavailable() throws {
    XCTAssertEqual(read(size: { throw self.cocoa(.fileReadNoSuchFile) }), .unavailable)
    XCTAssertEqual(read(size: { throw POSIXError(.ENOENT) }), .unavailable)
    XCTAssertEqual(
      read(size: { 200 }, load: { throw self.cocoa(.fileNoSuchFile) }), .unavailable)
    XCTAssertEqual(read(size: { 0 }), .unavailable)
    XCTAssertEqual(read(size: { SnapshotReader.maxBytes + 1 }), .unavailable)
    XCTAssertEqual(read(size: { 2 }, load: { Data("{}".utf8) }), .unavailable)
  }

  func testLockedReadSelfHealsWithinMinutesWhenTheAppWasJustOpen() {
    let plan = TrainingTimelinePlan.make(
      from: .protectedDataUnavailable(lastPublished: published), at: now)
    XCTAssertEqual(plan.entries.count, 1)
    XCTAssertTrue(plan.entries[0].awaitingUnlock)
    XCTAssertEqual(plan.entries[0].snapshot.state, .unavailable)
    XCTAssertEqual(plan.reloadAt, now.addingTimeInterval(120))
  }

  func testProtectedRetryBacksOffWithTimeSinceTheLastPublish() {
    let steps: [(age: TimeInterval, retry: TimeInterval)] = [
      (0, 120), (599, 120), (600, 300), (1799, 300), (1800, 900), (7199, 900),
      (7200, 1800), (86_400, 1800),
    ]
    for step in steps {
      XCTAssertEqual(
        TrainingTimelinePlan.protectedRetryInterval(
          lastPublished: now.addingTimeInterval(-step.age), at: now),
        step.retry, "age \(step.age)")
    }
    // Unknown age and a clock that ran backwards both stay on a safe, non-zero step.
    XCTAssertEqual(TrainingTimelinePlan.protectedRetryInterval(lastPublished: nil, at: now), 300)
    XCTAssertEqual(
      TrainingTimelinePlan.protectedRetryInterval(
        lastPublished: now.addingTimeInterval(500), at: now), 120)
  }

  func testAnOvernightLockStaysInsideTheReloadBudget() {
    // Simulate retries from a publish at 22:30 through eight hours of lock.
    let publish = now
    var clock = publish.addingTimeInterval(1800)
    let end = publish.addingTimeInterval(8 * 3600 + 1800)
    var reloads = 0
    while clock < end {
      clock = clock.addingTimeInterval(
        TrainingTimelinePlan.protectedRetryInterval(lastPublished: publish, at: clock))
      reloads += 1
    }
    XCTAssertLessThan(reloads, 30, "a fixed 2 minute retry would be about 240")
  }

  func testASuccessfulReadResetsTheLadder() {
    // A new publish moves the clock back to the 2 minute step; a readable file never backs off.
    let stale = now.addingTimeInterval(-10_000)
    XCTAssertEqual(TrainingTimelinePlan.protectedRetryInterval(lastPublished: stale, at: now), 1800)
    XCTAssertEqual(TrainingTimelinePlan.protectedRetryInterval(lastPublished: now, at: now), 120)
    let plan = TrainingTimelinePlan.make(from: .snapshot(ready()), at: now)
    XCTAssertEqual(plan.reloadAt, now.addingTimeInterval(3600))
    XCTAssertFalse(plan.entries[0].awaitingUnlock)
  }

  func testMissingFileKeepsTheRegularCadence() {
    let plan = TrainingTimelinePlan.make(from: .unavailable, at: now)
    XCTAssertFalse(plan.entries[0].awaitingUnlock)
    XCTAssertEqual(plan.reloadAt, now.addingTimeInterval(1800))
  }

  func testReadySnapshotCarriesExpiryAndCarryEndEntries() {
    let value = ready(expiring: 7200)
    let plan = TrainingTimelinePlan.make(from: .snapshot(value), at: now)
    XCTAssertEqual(
      plan.entries.map(\.date),
      [now, value.expiresAt, value.expiresAt.addingTimeInterval(TrainingSnapshot.carryWindow)])
    XCTAssertEqual(plan.entries[1].snapshot.state, .ready)
    XCTAssertTrue(plan.entries[1].snapshot.carriedOver)
    XCTAssertEqual(plan.entries[2].snapshot.state, .stale)
    XCTAssertEqual(plan.reloadAt, value.expiresAt)
  }

  func testAlreadyCarriedSnapshotOnlySchedulesTheCarryEnd() {
    let value = ready(expiring: -3600)
    let plan = TrainingTimelinePlan.make(
      from: .snapshot(value.visible(at: now)), at: now)
    XCTAssertEqual(plan.entries.count, 2)
    XCTAssertEqual(plan.reloadAt, now.addingTimeInterval(1800))
  }
}
