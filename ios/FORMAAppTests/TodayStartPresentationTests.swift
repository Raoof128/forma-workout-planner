import Foundation
import XCTest

@testable import FORMA

/// The wording and VoiceOver decisions behind Today and the Watch start sheet
/// (front-end audit, 2 November 2026: H1, H2, L2).
@MainActor
final class TodayStartPresentationTests: XCTestCase {
  // MARK: - Start sheet focus (H1)

  func testWaitingOnTheWatchMovesFocusToTheInstruction() {
    XCTAssertTrue(
      StartWorkoutSheet.shouldFocusStatus(phase: .waiting(routineID: "r1", routineName: "Upper")))
    XCTAssertFalse(StartWorkoutSheet.shouldFocusStatus(phase: .idle))
    XCTAssertFalse(StartWorkoutSheet.shouldFocusStatus(phase: .recording))
  }

  func testAWatchThatDropsOutOfReachMovesFocusToTheStatus() {
    XCTAssertTrue(
      StartWorkoutSheet.shouldFocusStatus(from: .ready, to: .unreachable, checkRequested: false))
    XCTAssertTrue(
      StartWorkoutSheet.shouldFocusStatus(from: .checking, to: .notPaired, checkRequested: false))
  }

  func testCheckingNeverTakesFocus() {
    XCTAssertFalse(
      StartWorkoutSheet.shouldFocusStatus(from: .unreachable, to: .checking, checkRequested: true))
  }

  func testAPassingCheckIsReadOutOnlyWhenThePersonAskedForIt() {
    XCTAssertTrue(
      StartWorkoutSheet.shouldFocusStatus(from: .checking, to: .ready, checkRequested: true))
    XCTAssertFalse(
      StartWorkoutSheet.shouldFocusStatus(from: .checking, to: .ready, checkRequested: false))
    // Check again that finds the Watch still out of reach still says so.
    XCTAssertTrue(
      StartWorkoutSheet.shouldFocusStatus(
        from: .checking, to: .unreachable, checkRequested: true))
  }

  // MARK: - Live strip (H2)

  func testAPausedRecordingIsSpokenAsPaused() {
    let spoken = WatchRecordingStrip.spokenStatus(
      paused: true, liveHeartRate: 128, lastHeartRate: nil, activeEnergy: 41.6)
    XCTAssertEqual(
      spoken, "Paused on Apple Watch, heart rate 128 beats per minute, 42 active kilocalories")
    XCTAssertFalse(spoken.contains("Recording"))
  }

  func testARunningRecordingKeepsItsStaleReadingWording() {
    XCTAssertEqual(
      WatchRecordingStrip.spokenStatus(
        paused: false, liveHeartRate: nil, lastHeartRate: 131, activeEnergy: nil),
      "Recording on Apple Watch, heart rate not current, last 131 beats per minute")
    XCTAssertEqual(
      WatchRecordingStrip.spokenStatus(
        paused: false, liveHeartRate: nil, lastHeartRate: nil, activeEnergy: nil),
      "Recording on Apple Watch")
  }

  // MARK: - Week strip (L2)

  func testWeekdaysStartOnMondayAndFollowTheLanguage() {
    let english = Locale(identifier: "en")
    XCTAssertEqual(
      WeekStrip.weekdaySymbols(short: true, locale: english), ["M", "T", "W", "T", "F", "S", "S"])
    XCTAssertEqual(
      WeekStrip.weekdaySymbols(short: false, locale: english),
      ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"])
    XCTAssertEqual(WeekStrip.weekdaySymbols(short: false, locale: Locale(identifier: "de")).first, "Montag")
  }

  func testWeeklyProgressIsWordsNotASlash() {
    XCTAssertEqual(WeekStrip.progressDetail(count: 2, goal: 4), "2 of 4 workouts")
    XCTAssertEqual(WeekStrip.progressDetail(count: 0, goal: 1), "0 of 1 workout")
  }

  // MARK: - Copy (M4)

  func testExerciseCountAgreesWithItsNoun() {
    XCTAssertEqual(countPhrase(1, "exercise"), "1 exercise")
    XCTAssertEqual(countPhrase(6, "exercise"), "6 exercises")
  }
}
