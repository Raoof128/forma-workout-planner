import Foundation
import XCTest

@testable import FORMASurfaces

final class TrainingSnapshotTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)

  private func fixture() -> TrainingSnapshot {
    TrainingSnapshot(
      epoch: "installation-owner-epoch", revision: 7, generatedAt: now,
      expiresAt: now.addingTimeInterval(3600), state: .ready,
      routine: .init(id: "legacy/تست?1&x=✓", name: "Upper body", exercises: 4, minutes: 35),
      active: .init(id: "active", name: "Upper body", completedSets: 2, totalSets: 12),
      week: .init(sessions: 3, goal: 4, days: [true, false, true, false, false, false, false]))
  }

  func testRoundTripAndExpiryRemoveAllPersonalContent() throws {
    let value = fixture()
    let data = try JSONEncoder().encode(value)
    XCTAssertEqual(try TrainingSnapshot.decode(data, at: now), value)
    let expired = try TrainingSnapshot.decode(data, at: value.expiresAt)
    XCTAssertEqual(expired.state, .stale)
    XCTAssertNil(expired.active)
    XCTAssertNil(expired.routine)
    XCTAssertNil(expired.week)
  }

  func testCorruptFutureUnsupportedAndUnboundedPayloadsFailClosed() throws {
    XCTAssertThrowsError(try TrainingSnapshot.decode(Data("{}".utf8), at: now))
    XCTAssertThrowsError(try TrainingSnapshot.decode(Data(repeating: 32, count: 32_769), at: now))
    for kind in 0..<5 {
      var value = fixture()
      switch kind {
      case 0: value.version = 2
      case 1: value.generatedAt = now.addingTimeInterval(120)
      case 2: value.week?.days = []
      case 3: value.active?.completedSets = 100
      default: value.state = .hidden  // Hidden snapshots may not carry a previous owner's data.
      }
      XCTAssertThrowsError(try TrainingSnapshot.decode(JSONEncoder().encode(value), at: now))
    }
  }

  func testRoutesPreserveCanonicalIDsAndRejectAmbiguity() {
    let id = "legacy/تست?1&x=✓ #+%"
    let route = WidgetRoute.routine(id: id, epoch: "random-epoch")
    XCTAssertEqual(WidgetRoute(url: route.url), route)
    XCTAssertEqual(
      WidgetRoute(url: WidgetRoute.active(id: id, epoch: "epoch").url),
      .active(id: id, epoch: "epoch"))
    for text in [
      "https://widget/routine?id=a&epoch=b", "forma://widget/routine?id=a&id=b",
      "forma://widget/active?id=&epoch=x", "forma://widget/today?extra=x",
      "forma://attacker/today", "forma://widget/progress#x",
      "forma://user@widget/today", "forma://widget:80/today",
    ] {
      XCTAssertNil(WidgetRoute(url: URL(string: text)!))
    }
  }

  func testOlderPublicationCannotRestorePreviousOwnerEvenWithLargerRevision() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent(TrainingSnapshot.filename)
    let writer = SnapshotFileWriter(url: url)
    var old = fixture()
    old.revision = 900
    let hidden = TrainingSnapshot(
      epoch: "new-owner", generatedAt: now,
      expiresAt: now, state: .hidden)
    let first = try await writer.publish(old, sequence: 1)
    let second = try await writer.publish(hidden, sequence: 3)
    let delayed = try await writer.publish(old, sequence: 2)
    XCTAssertTrue(first)
    XCTAssertTrue(second)
    XCTAssertFalse(delayed)
    XCTAssertEqual(try TrainingSnapshot.decode(Data(contentsOf: url), at: now), hidden)
  }
}
