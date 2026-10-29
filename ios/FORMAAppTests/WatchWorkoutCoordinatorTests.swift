import Foundation
import WatchConnectivity
import XCTest

@testable import FORMA

/// The Watch link and the wording the iPhone shows when it breaks. A mirrored
/// `HKWorkoutSession` can't be built off a device, so these drive the same
/// entry points the HealthKit callbacks use once they have checked the session.
@MainActor
final class WatchWorkoutCoordinatorTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  private func snapshot(heartRate: Double? = 142) -> WatchMetrics {
    WatchMetrics(state: .running, startedAt: start, elapsed: 120, heartRate: heartRate)
  }

  // MARK: - Availability

  func testAvailabilitySeparatesActivationFailureFromTheOtherStates() {
    func resolve(
      _ activation: WCSessionActivationState, paired: Bool = true, installed: Bool = true
    ) -> WatchWorkoutCoordinator.Availability {
      .resolve(activation: activation, isPaired: paired, isWatchAppInstalled: installed)
    }
    XCTAssertEqual(resolve(.notActivated), .notActivated)
    XCTAssertEqual(resolve(.inactive), .notActivated)
    XCTAssertEqual(resolve(.activated, paired: false), .notPaired)
    XCTAssertEqual(resolve(.activated, installed: false), .appNotInstalled)
    XCTAssertEqual(resolve(.activated), .ready)
  }

  func testActivationFailureAndUnreachableGiveDifferentAdvice() {
    let activation = WatchWorkoutCoordinator.Availability.notActivated.message
    let away = WatchWorkoutCoordinator.Availability.unreachable.message
    XCTAssertNotEqual(activation, away)
    XCTAssertTrue(away.contains("range"), "Unreachable names the Watch being away or locked")
    XCTAssertFalse(activation.contains("nearby"), "An activation failure is not about distance")
    XCTAssertTrue(WatchWorkoutCoordinator.Availability.notActivated.hasPairedWatch)
    XCTAssertTrue(WatchWorkoutCoordinator.Availability.unreachable.hasPairedWatch)
  }

  // MARK: - Link and stale readings

  func testReadingGoesStaleAfterTheWatchGoesQuiet() {
    var link = WatchLink()
    XCTAssertFalse(link.isStale(at: start), "Nothing received yet is not stale")
    link.metricsReceived(at: start)
    XCTAssertFalse(link.isStale(at: start.addingTimeInterval(WatchLink.staleAfter)))
    XCTAssertTrue(link.isStale(at: start.addingTimeInterval(WatchLink.staleAfter + 1)))
    link.metricsReceived(at: start.addingTimeInterval(70))
    XCTAssertFalse(link.isStale(at: start.addingTimeInterval(71)))
  }

  func testLostLinkIsStaleImmediatelyAndRecoversOnContact() {
    var link = WatchLink()
    link.metricsReceived(at: start)
    link.disconnected()
    XCTAssertEqual(link.state, .lost)
    XCTAssertTrue(link.isStale(at: start), "A lost link never shows a reading as live")
    link.restored(at: start.addingTimeInterval(30))
    XCTAssertEqual(link.state, .live)
    XCTAssertFalse(link.isStale(at: start.addingTimeInterval(31)))
  }

  func testCoordinatorWithholdsHeartRateOnceStaleButKeepsTheLastOne() {
    let coordinator = WatchWorkoutCoordinator()
    coordinator.apply(metrics: snapshot(), at: start)
    XCTAssertEqual(coordinator.liveHeartRate, 142)
    XCTAssertFalse(coordinator.isReadingStale)

    coordinator.refreshStaleness(now: start.addingTimeInterval(WatchLink.staleAfter + 5))
    XCTAssertTrue(coordinator.isReadingStale)
    XCTAssertNil(coordinator.liveHeartRate)
    XCTAssertEqual(coordinator.lastHeartRate, 142, "The old number stays available to label as old")

    coordinator.apply(metrics: snapshot(heartRate: 131), at: start.addingTimeInterval(90))
    XCTAssertFalse(coordinator.isReadingStale)
    XCTAssertEqual(coordinator.liveHeartRate, 131)
  }

  func testDisconnectPublishesANoticeAndFreshDataClearsIt() {
    let coordinator = WatchWorkoutCoordinator()
    coordinator.apply(metrics: snapshot(), at: start)
    coordinator.applyDisconnect()
    XCTAssertEqual(coordinator.link.state, .lost)
    XCTAssertTrue(coordinator.isReadingStale)
    XCTAssertNil(coordinator.liveHeartRate)
    XCTAssertTrue(coordinator.notice?.contains("keeps recording") == true)

    coordinator.apply(metrics: snapshot(), at: start.addingTimeInterval(10))
    XCTAssertEqual(coordinator.link.state, .live)
    XCTAssertNil(coordinator.notice, "The disconnect notice goes when the Watch is back")
    XCTAssertFalse(coordinator.isReadingStale)
  }

  func testMirroringRestoredClearsTheDisconnectNotice() {
    let coordinator = WatchWorkoutCoordinator()
    coordinator.applyDisconnect()
    XCTAssertNotNil(coordinator.notice)
    coordinator.applyLinkRestored(at: start)
    XCTAssertNil(coordinator.notice)
    XCTAssertEqual(coordinator.link.state, .live)
  }

  func testResetForgetsTheLinkAndTheNotice() {
    let coordinator = WatchWorkoutCoordinator()
    coordinator.apply(metrics: snapshot(), at: start)
    coordinator.applyDisconnect()
    coordinator.reset()
    XCTAssertNil(coordinator.notice)
    XCTAssertNil(coordinator.metrics)
    XCTAssertEqual(coordinator.link, WatchLink())
    XCTAssertFalse(coordinator.isReadingStale)
  }

  // MARK: - Commands

  func testFailedEndSaysWhatToDoOnTheWatch() {
    let connected = WatchWorkoutCoordinator.failureNotice(for: .end, connected: true)
    let disconnected = WatchWorkoutCoordinator.failureNotice(for: .end, connected: false)
    for notice in [connected, disconnected] {
      XCTAssertTrue(notice.contains("End the workout on your Watch"))
      XCTAssertTrue(notice.contains("may still be recording"))
    }
    XCTAssertNotEqual(connected, disconnected, "Not connected and not answering read differently")
  }

  func testEachCommandNamesItself() {
    XCTAssertTrue(
      WatchWorkoutCoordinator.failureNotice(for: .pause, connected: true).contains("pause"))
    XCTAssertTrue(
      WatchWorkoutCoordinator.failureNotice(for: .resume, connected: true).contains("resume"))
    XCTAssertEqual(WatchWorkoutCoordinator.Command(.end(save: false)), .end)
    XCTAssertNil(WatchWorkoutCoordinator.Command(.metrics(snapshot())))
  }

  func testEndWhenNothingIsRecordingDoesNothing() async {
    let coordinator = WatchWorkoutCoordinator()
    // Not recording: nothing to end, and no false alarm.
    await coordinator.end(save: true)
    XCTAssertNil(coordinator.notice)
    XCTAssertEqual(coordinator.phase, .idle)
  }
}
