import FORMACore
import UserNotifications
import XCTest

@testable import FORMA

final class WorkoutClockTests: XCTestCase {
  private let english = Locale(identifier: "en_US")

  func testHoldRestAndElapsedShareOneMinuteSecondFormat() {
    XCTAssertEqual(WorkoutClock.text(0, locale: english), "0:00")
    XCTAssertEqual(WorkoutClock.text(5, locale: english), "0:05")
    XCTAssertEqual(WorkoutClock.text(65, locale: english), "1:05")
    XCTAssertEqual(WorkoutClock.text(600, locale: english), "10:00")
    XCTAssertEqual(WorkoutClock.text(-3, locale: english), "0:00")
  }

  func testHoursAppearOnlyOncePastAnHour() {
    XCTAssertEqual(WorkoutClock.text(3_599, locale: english), "59:59")
    XCTAssertEqual(WorkoutClock.text(3_725, locale: english), "1:02:05")
  }

  func testSpokenFormIsAPhraseNotDigits() {
    XCTAssertEqual(WorkoutClock.spoken(65, locale: english), "1 minute, 5 seconds")
    XCTAssertEqual(WorkoutClock.spoken(45, locale: english), "45 seconds")
  }
}

final class SetDraftIssueTests: XCTestCase {
  private let english = Locale(identifier: "en_US")

  func testTheFirstUnsavableFieldIsNamedInReadingOrder() {
    let set = LoggedSet(weight: 60, reps: 8)
    var draft = MeasurementDraft(set, locale: english)
    XCTAssertNil(draft.invalidField(for: set, locale: english))
    draft.reps = "8-"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "reps")
    draft.weight = ""
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "weight")
  }

  func testRepsThatParseButAreOutOfRangeStillPointAtReps() {
    let set = LoggedSet(weight: 60, reps: 8)
    var draft = MeasurementDraft(set, locale: english)
    draft.reps = "101"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "reps")
    draft.reps = "2.5"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "reps")
  }

  func testPerSideSetsPointAtTheSideThatFails() {
    let set = LoggedSet(weight: 20, reps: 16, sides: SetSides(left: 8, right: 8))
    var draft = MeasurementDraft(set, locale: english)
    draft.right = "x"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "right")
    draft.right = "8"
    draft.left = "0"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "left")
    draft.left = "60"
    draft.right = "60"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "right")
  }

  func testTimeAndDistanceFieldsAreCheckedWhenTheSetHasThem() {
    let set = LoggedSet(weight: 0, reps: 1, durationSeconds: 90, distanceMeters: 500)
    var draft = MeasurementDraft(set, locale: english)
    draft.distance = "far"
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "distance")
    draft.seconds = ""
    XCTAssertEqual(draft.invalidField(for: set, locale: english), "seconds")
  }

  func testRepeatingTheSameMessageIsStillANewIssue() {
    let first = DraftIssue(message: "Set 2: reps must be a whole number from 1 to 100.")
    let second = DraftIssue(message: first.message)
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(first, first)
  }
}

@MainActor
final class RestReminderTests: XCTestCase {
  private final class FakeCenter: RestNotificationCenter, @unchecked Sendable {
    private let lock = NSLock()
    private var state:
      (
        status: UNAuthorizationStatus, asked: Int, pending: [String: Double], sounds: [Bool]
      ) = (.authorized, 0, [:], [])

    init(status: UNAuthorizationStatus) { state.status = status }

    var asked: Int { lock.withLock { state.asked } }
    var sounds: [Bool] { lock.withLock { state.sounds } }
    var pending: [String: Double] { lock.withLock { state.pending } }

    func status() async -> UNAuthorizationStatus { lock.withLock { state.status } }

    func askPermission() async -> Bool {
      lock.withLock {
        state.asked += 1
        state.status = .authorized
        return true
      }
    }

    func schedule(_ request: UNNotificationRequest) async {
      lock.withLock {
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        state.pending[request.identifier] = trigger?.timeInterval
        state.sounds.append(request.content.sound != nil)
      }
    }

    func cancel(identifier: String) {
      lock.withLock { _ = state.pending.removeValue(forKey: identifier) }
    }
  }

  private let now = 1_792_700_000_000.0

  func testNothingIsPendingWhileTheAppIsInFrontOrNoRestRuns() {
    XCTAssertNil(RestReminderPlan.delay(restEnd: now + 60_000, now: now, appActive: true))
    XCTAssertNil(RestReminderPlan.delay(restEnd: nil, now: now, appActive: false))
    XCTAssertNil(RestReminderPlan.delay(restEnd: now - 1_000, now: now, appActive: false))
    XCTAssertNil(RestReminderPlan.delay(restEnd: now + 400, now: now, appActive: false))
    XCTAssertEqual(
      RestReminderPlan.delay(restEnd: now + 60_000, now: now, appActive: false) ?? 0, 60,
      accuracy: 0.001)
  }

  func testLeavingTheForegroundSchedulesAndReturningCancels() async {
    let center = FakeCenter(status: .authorized)
    let reminder = RestReminder(center: center)
    await reminder.sync(restEnd: now + 90_000, muted: false, appActive: false, now: now)
    XCTAssertEqual(center.pending[RestReminder.identifier] ?? 0, 90, accuracy: 0.001)
    XCTAssertEqual(center.sounds, [true])

    await reminder.sync(restEnd: now + 90_000, muted: false, appActive: true, now: now)
    XCTAssertNil(center.pending[RestReminder.identifier])
  }

  func testSkippingPausingOrFinishingCancelsWhatWasPending() async {
    let center = FakeCenter(status: .authorized)
    let reminder = RestReminder(center: center)
    await reminder.sync(restEnd: now + 90_000, muted: false, appActive: false, now: now)
    // Paused or skipped: no deadline left.
    await reminder.sync(restEnd: nil, muted: false, appActive: false, now: now)
    XCTAssertTrue(center.pending.isEmpty)

    await reminder.sync(restEnd: now + 90_000, muted: false, appActive: false, now: now)
    reminder.cancel()
    XCTAssertTrue(center.pending.isEmpty)
  }

  func testMutedTrainingSoundsMakeASilentNotification() async {
    let center = FakeCenter(status: .authorized)
    await RestReminder(center: center)
      .sync(restEnd: now + 90_000, muted: true, appActive: false, now: now)
    XCTAssertEqual(center.sounds, [false])
  }

  func testDeniedPermissionDegradesWithoutSchedulingOrAsking() async {
    let center = FakeCenter(status: .denied)
    let reminder = RestReminder(center: center)
    await reminder.sync(restEnd: now + 90_000, muted: false, appActive: false, now: now)
    await reminder.requestAuthorizationIfNeeded()
    XCTAssertTrue(center.pending.isEmpty)
    XCTAssertEqual(center.asked, 0)
  }

  func testPermissionIsAskedOnlyWhileUndetermined() async {
    let center = FakeCenter(status: .notDetermined)
    let reminder = RestReminder(center: center)
    await reminder.requestAuthorizationIfNeeded()
    await reminder.requestAuthorizationIfNeeded()
    XCTAssertEqual(center.asked, 1)
  }
}
