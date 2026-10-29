import Foundation
import XCTest

@testable import FORMASurfaces

final class TrainingPresentationTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_793_200_000)

  private func snapshot(
    state: TrainingSnapshot.State = .ready, routine: Bool = true, active: Bool = false
  ) -> TrainingSnapshot {
    let ready = state == .ready
    return TrainingSnapshot(
      epoch: "epoch", generatedAt: now, expiresAt: now.addingTimeInterval(3600), state: state,
      routine: ready && routine
        ? .init(id: "routine", name: "Upper body", exercises: 6, minutes: 50) : nil,
      active: ready && active
        ? .init(id: "active", name: "Legs", completedSets: 3, totalSets: 18) : nil,
      week: ready
        ? .init(sessions: 2, goal: 4, days: [true, false, true, false, false, false, false]) : nil)
  }

  private func presentation(
    _ value: TrainingSnapshot, week: Bool = false, unlock: Bool = false
  ) -> TrainingPresentation {
    TrainingPresentation(snapshot: value, weekFocus: week, awaitingUnlock: unlock)
  }

  // Wg-H1: the generic privacy and fallback messages must never be marked privacy sensitive.
  func testOnlyPersonalLayoutsAreMarkedPrivacySensitive() {
    let ready = presentation(snapshot(active: true))
    XCTAssertEqual(ready.layout(privacyRedacted: true, compact: false), .privacyFallback)
    XCTAssertEqual(ready.layout(privacyRedacted: true, compact: true), .privacyFallback)
    XCTAssertFalse(Layout.privacyFallback.containsPersonalContent)
    XCTAssertEqual(ready.layout(privacyRedacted: false, compact: false), .data)
    XCTAssertEqual(ready.layout(privacyRedacted: false, compact: true), .compactSummary)
    XCTAssertTrue(Layout.data.containsPersonalContent)
    XCTAssertTrue(Layout.compactSummary.containsPersonalContent)
    for state in [TrainingSnapshot.State.hidden, .empty, .stale, .unavailable] {
      let layout = presentation(snapshot(state: state)).layout(
        privacyRedacted: false, compact: true)
      XCTAssertEqual(layout, .fallback, "\(state)")
      XCTAssertFalse(layout.containsPersonalContent)
    }
  }

  func testPrivacyFallbackKeepsLockIconAndMessage() {
    XCTAssertEqual(TrainingPresentation.privacyFallback.title, "Training is private")
    XCTAssertEqual(TrainingPresentation.privacyFallback.symbol, "lock")
    XCTAssertFalse(TrainingPresentation.privacyFallback.detail.isEmpty)
  }

  // Wg-M1: the label must match where the tap goes.
  func testActionLabelFollowsTheRoute() {
    let cases: [(TrainingPresentation, WidgetRoute, String)] = [
      (presentation(snapshot()), .routine(id: "routine", epoch: "epoch"), "View routine"),
      (
        presentation(snapshot(active: true)), .active(id: "active", epoch: "epoch"),
        "Resume in FORMA"
      ),
      (presentation(snapshot(routine: false)), .progress, "View progress"),
      (presentation(snapshot(), week: true), .progress, "View progress"),
      (presentation(snapshot(active: true), week: true), .progress, "View progress"),
    ]
    for (value, route, label) in cases {
      XCTAssertEqual(value.route(), route)
      XCTAssertEqual(value.actionLabel(), label)
    }
    XCTAssertEqual(presentation(snapshot(active: true)).actionLabel(short: true), "Resume")
    XCTAssertEqual(presentation(snapshot()).route(progressOnly: true), .progress)
  }

  func testFallbackRoutesAndStatesAreDistinct() {
    XCTAssertEqual(presentation(snapshot(state: .hidden)).route(), .settings)
    XCTAssertEqual(presentation(snapshot(state: .empty)).route(), .plan)
    XCTAssertEqual(presentation(snapshot(state: .stale)).route(), .today)
    XCTAssertEqual(presentation(snapshot(state: .unavailable), unlock: true).route(), .today)
    var seen = Set<String>()
    for state in [TrainingSnapshot.State.hidden, .empty, .stale, .unavailable] {
      let fallback = presentation(snapshot(state: state)).fallback
      XCTAssertTrue(seen.insert(fallback.title).inserted, fallback.title)
      XCTAssertTrue(seen.insert(fallback.inline).inserted, fallback.inline)
    }
    let locked = presentation(snapshot(state: .unavailable), unlock: true).fallback
    XCTAssertFalse(seen.contains(locked.title))
    // An unavailable file is a problem, not privacy: it must not borrow the privacy lock.
    XCTAssertNotEqual(presentation(snapshot(state: .unavailable)).fallback.symbol, "lock")
    XCTAssertEqual(
      presentation(snapshot(state: .hidden)).fallback.detail, "Turn on widgets in You.")
  }

  // Wg-L: "SAVED WORKOUT" must not head the "This week" view.
  func testWeekFocusNeverShowsSavedWorkoutHeading() {
    let active = snapshot(active: true)
    XCTAssertEqual(presentation(active).status, "SAVED WORKOUT")
    XCTAssertEqual(presentation(active, week: true).status, "A LITTLE, CONSISTENTLY")
    XCTAssertEqual(presentation(active, week: true).title, "This week")
    XCTAssertEqual(presentation(snapshot()).status, "YOUR NEXT SESSION")
  }

  func testInlineTextHasAShortFormWithTheCount() {
    XCTAssertEqual(presentation(snapshot()).inlineText, "FORMA · 6 exercises · 50 min")
    XCTAssertEqual(presentation(snapshot()).inlineShortText, "FORMA · 2/4 this week")
    XCTAssertEqual(presentation(snapshot(active: true)).inlineShortText, "FORMA · 3/18 sets")
  }

  func testWeekdayMarksAreMondayFirstAndLocalised() {
    let english = Locale(identifier: "en_AU")
    // en_AU separates Tuesday/Thursday and Saturday/Sunday ("Tu", "Th", "Sa", "Su").
    XCTAssertEqual(
      TrainingPresentation.weekdayInitials(locale: english),
      ["M", "Tu", "W", "Th", "F", "Sa", "Su"])
    XCTAssertEqual(TrainingPresentation.weekdayNames(locale: english).first, "Monday")
    XCTAssertEqual(TrainingPresentation.weekdayNames(locale: english).last, "Sunday")
    XCTAssertEqual(
      presentation(snapshot()).trainedDaySummary(locale: english), "Trained on Monday, Wednesday")
    XCTAssertEqual(
      presentation(snapshot(state: .hidden)).trainedDaySummary(locale: english),
      "No days recorded this week")
  }

  func testBrandPaletteMirrorsTheAppTokens() {
    XCTAssertEqual(BrandPalette.accent.hex(dark: false, highContrast: false), 0x4C631C)
    XCTAssertEqual(BrandPalette.accent.hex(dark: true, highContrast: false), 0xDFF780)
    XCTAssertEqual(BrandPalette.accent.hex(dark: false, highContrast: true), 0x354A0D)
    XCTAssertEqual(BrandPalette.secondaryText.hex(dark: true, highContrast: true), 0xE8EDE9)
  }

  /// The consent tile's link; the app scrolls You to the widget toggle for it.
  func testSettingsRouteURLIsStable() {
    XCTAssertEqual(WidgetRoute.settings.url.absoluteString, "forma://widget/settings")
  }

  private typealias Layout = TrainingPresentation.Layout
}
