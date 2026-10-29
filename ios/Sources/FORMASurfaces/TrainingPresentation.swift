import Foundation

/// Decisions and copy for the training widget, kept free of SwiftUI so tests can assert them.
/// The view only lays these out.
public struct TrainingPresentation: Equatable, Sendable {
  public let snapshot: TrainingSnapshot
  /// "This week" configuration rather than "Next session".
  public let weekFocus: Bool
  /// The file could not be read because the device is locked; recovery is expected shortly.
  public let awaitingUnlock: Bool

  public init(snapshot: TrainingSnapshot, weekFocus: Bool = false, awaitingUnlock: Bool = false) {
    self.snapshot = snapshot
    self.weekFocus = weekFocus
    self.awaitingUnlock = awaitingUnlock
  }

  // MARK: Layout and privacy

  public enum Layout: Equatable, Sendable {
    /// System privacy redaction (Lock Screen, StandBy). Generic, so it must stay unredacted.
    case privacyFallback
    /// Hidden, empty, stale or unavailable. Generic, so it must stay unredacted.
    case fallback
    /// Personal facts in the reduced layout used at large text sizes.
    case compactSummary
    /// Personal facts in the family's regular layout.
    case data

    /// Only layouts that show routine, workout or weekly facts may be marked privacy sensitive.
    /// Marking a fallback redacts the very message that explains the redaction.
    public var containsPersonalContent: Bool { self == .compactSummary || self == .data }
  }

  public func layout(privacyRedacted: Bool, compact: Bool) -> Layout {
    if privacyRedacted { return .privacyFallback }
    if snapshot.state != .ready { return .fallback }
    return compact ? .compactSummary : .data
  }

  // MARK: Destination and action

  /// `progressOnly` is the circular Lock Screen gauge, which only ever shows the weekly count.
  public func route(progressOnly: Bool = false) -> WidgetRoute {
    if progressOnly, snapshot.state == .ready { return .progress }
    guard snapshot.state == .ready else {
      if awaitingUnlock { return .today }
      switch snapshot.state {
      case .hidden: return .settings
      case .empty: return .plan
      default: return .today
      }
    }
    if weekFocus { return .progress }
    if let active = snapshot.active { return .active(id: active.id, epoch: snapshot.epoch) }
    if let routine = snapshot.routine { return .routine(id: routine.id, epoch: snapshot.epoch) }
    return .progress
  }

  /// The label always names where the tap goes, derived from the route.
  public func actionLabel(short: Bool = false) -> String {
    switch route() {
    case .active: short ? "Resume" : "Resume in FORMA"
    case .routine: "View routine"
    case .progress: "View progress"
    case .plan: "Create a routine"
    case .settings: "Choose what to share"
    case .today: "Open FORMA"
    }
  }

  // MARK: Ready content

  public var title: String {
    if weekFocus { return "This week" }
    return snapshot.active?.name ?? snapshot.routine?.name ?? "Your training"
  }

  public var status: String {
    if weekFocus { return "A LITTLE, CONSISTENTLY" }
    return snapshot.active != nil ? "SAVED WORKOUT" : "YOUR NEXT SESSION"
  }

  public var detail: String {
    if let active = snapshot.active, !weekFocus {
      return "\(active.completedSets) of \(active.totalSets) sets saved"
    }
    if let routine = snapshot.routine, !weekFocus {
      return "\(routine.exercises) exercises · \(routine.minutes) min"
    }
    return "\(sessions) of \(goal) workouts"
  }

  public var sessions: Int { snapshot.week?.sessions ?? 0 }
  public var goal: Int { snapshot.week?.goal ?? 4 }
  public var weeklyLabel: String { "\(sessions) of \(goal) workouts this week" }
  public var inlineText: String { "FORMA · \(detail)" }
  /// Fits the narrowest Lock Screen inline slot when `inlineText` would clip.
  public var inlineShortText: String {
    if let active = snapshot.active, !weekFocus {
      return "FORMA · \(active.completedSets)/\(active.totalSets) sets"
    }
    return "FORMA · \(sessions)/\(goal) this week"
  }

  public func isTrained(day: Int) -> Bool {
    guard let days = snapshot.week?.days, days.indices.contains(day) else { return false }
    return days[day]
  }

  /// Monday-first weekday names and single-letter marks, in the reader's language.
  public static func weekdayNames(locale: Locale = .autoupdatingCurrent) -> [String] {
    ordered(calendar(locale).standaloneWeekdaySymbols)
  }
  public static func weekdayInitials(locale: Locale = .autoupdatingCurrent) -> [String] {
    ordered(calendar(locale).veryShortStandaloneWeekdaySymbols)
  }
  private static func calendar(_ locale: Locale) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = locale
    return calendar
  }
  /// Gregorian symbols run Sunday first; the training week starts on Monday.
  private static func ordered(_ sundayFirst: [String]) -> [String] {
    Array(sundayFirst[1...]) + [sundayFirst[0]]
  }

  public func trainedDaySummary(locale: Locale = .autoupdatingCurrent) -> String {
    let names = Self.weekdayNames(locale: locale)
    let trained = (0..<7).filter(isTrained(day:)).map { names[$0] }
    return trained.isEmpty
      ? "No days recorded this week" : "Trained on " + trained.joined(separator: ", ")
  }

  // MARK: Fallback copy

  public struct Fallback: Equatable, Sendable {
    public let title: String
    /// Shown by families with room for a sentence. Says what to do next.
    public let detail: String
    public let symbol: String
    /// The only text the inline Lock Screen family can show.
    public let inline: String
  }

  public static let privacyFallback = Fallback(
    title: "Training is private", detail: "Unlock to see your training.", symbol: "lock",
    inline: "FORMA · Private")

  public var fallback: Fallback {
    if awaitingUnlock {
      return Fallback(
        title: "Updating after unlock",
        detail: "Your saved training is safe. This refreshes shortly after you unlock.",
        symbol: "lock", inline: "FORMA · Updating")
    }
    switch snapshot.state {
    case .hidden:
      return Fallback(
        title: "Choose what you share", detail: "Turn on widgets in You.",
        symbol: "hand.raised", inline: "FORMA · Turn on")
    case .empty:
      return Fallback(
        title: "No routine yet", detail: "Create a routine in Plan.", symbol: "plus",
        inline: "FORMA · Add routine")
    case .stale:
      return Fallback(
        title: "Refresh your training", detail: "Open FORMA to update.",
        symbol: "arrow.clockwise", inline: "FORMA · Open to update")
    case .unavailable, .ready:
      return Fallback(
        title: "Can’t load training", detail: "Open FORMA to see your saved training.",
        symbol: "exclamationmark.circle", inline: "FORMA · Open app")
    }
  }
}
