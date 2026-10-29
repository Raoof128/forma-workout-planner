import Foundation

/// What the workout Live Activity shows, as plain values. Pure and `Codable`, so the mapping is
/// tested without ActivityKit (which does not build for macOS) and the encoded size is checked
/// against ActivityKit's 4 KB limit. It carries the current exercise only, never the routine, and
/// no notes, account identity, Health metrics or history. Timers are dates, not seconds: the
/// system counts them, so nothing is sent while a rest runs down.
public struct WorkoutActivityState: Codable, Hashable, Sendable {
  public var sessionID: String
  /// The routine's name. Shown `privacySensitive`; the public title is "FORMA workout".
  public var title: String
  public var exercise: String
  /// Zero-based, so `exerciseIndex + 1` of `exerciseCount` reads as a number.
  public var exerciseIndex: Int
  public var exerciseCount: Int
  /// The set being worked on, one-based. Zero when the exercise has no sets.
  public var setNumber: Int
  public var setCount: Int
  public var doneSets: Int
  public var totalSets: Int
  public var startedAt: Date
  /// Set only while a rest is counting down.
  public var restEnd: Date?
  /// The programmed rest, for the progress ring's start (`restEnd - restTotalSeconds`).
  public var restTotalSeconds: Int?
  /// Seconds left on a paused rest, in place of `restEnd`.
  public var restPausedSeconds: Int?
  /// Every set is ticked: the person is about to finish in the app.
  public var isFinishedAllSets: Bool

  public init(
    sessionID: String, title: String, exercise: String, exerciseIndex: Int, exerciseCount: Int,
    setNumber: Int, setCount: Int, doneSets: Int, totalSets: Int, startedAt: Date,
    restEnd: Date? = nil, restTotalSeconds: Int? = nil, restPausedSeconds: Int? = nil,
    isFinishedAllSets: Bool = false
  ) {
    self.sessionID = sessionID
    self.title = title
    self.exercise = exercise
    self.exerciseIndex = exerciseIndex
    self.exerciseCount = exerciseCount
    self.setNumber = setNumber
    self.setCount = setCount
    self.doneSets = doneSets
    self.totalSets = totalSets
    self.startedAt = startedAt
    self.restEnd = restEnd
    self.restTotalSeconds = restTotalSeconds
    self.restPausedSeconds = restPausedSeconds
    self.isFinishedAllSets = isFinishedAllSets
  }

  /// Plain values from a saved session. The app fills these from `WorkoutSession`.
  public struct Input: Equatable, Sendable {
    public var sessionID: String
    public var title: String
    /// The current exercise's name, or nil when the session has no exercises.
    public var exercise: String?
    public var exerciseIndex: Int
    public var exerciseCount: Int
    /// Ticked and total sets in the current exercise only.
    public var exerciseDoneSets: Int
    public var exerciseSetCount: Int
    public var doneSets: Int
    public var totalSets: Int
    public var startedAt: Date
    public var restEnd: Date?
    /// Seconds left on a paused rest.
    public var restPausedSeconds: Double?
    /// The programmed rest length.
    public var restSeconds: Int

    public init(
      sessionID: String, title: String, exercise: String?, exerciseIndex: Int, exerciseCount: Int,
      exerciseDoneSets: Int, exerciseSetCount: Int, doneSets: Int, totalSets: Int,
      startedAt: Date, restEnd: Date?, restPausedSeconds: Double?, restSeconds: Int
    ) {
      self.sessionID = sessionID
      self.title = title
      self.exercise = exercise
      self.exerciseIndex = exerciseIndex
      self.exerciseCount = exerciseCount
      self.exerciseDoneSets = exerciseDoneSets
      self.exerciseSetCount = exerciseSetCount
      self.doneSets = doneSets
      self.totalSets = totalSets
      self.startedAt = startedAt
      self.restEnd = restEnd
      self.restPausedSeconds = restPausedSeconds
      self.restSeconds = restSeconds
    }
  }

  /// Names are cut short so a long one cannot grow the payload or the layout: at most 40
  /// characters and 96 UTF-8 bytes, which keeps even a string of emoji sequences small.
  public static let nameLimit = 40
  static let nameByteLimit = 96
  /// Longest pause a rest can hold (the engine caps it too).
  static let longestRestSeconds = 600
  /// How long an untouched activity stays current. Tapping a set refreshes it.
  public static let idleStaleInterval: TimeInterval = 3 * 3_600

  /// `now` decides only whether a rest is still counting down; an expired rest is not resting.
  public init(_ input: Input, now: Date) {
    let exerciseCount = max(0, input.exerciseCount)
    let setCount = max(0, input.exerciseSetCount)
    let done = min(max(0, input.exerciseDoneSets), setCount)
    let totalSets = max(0, input.totalSets)
    let doneSets = min(max(0, input.doneSets), totalSets)
    var restEnd: Date?
    var restTotal: Int?
    var restPaused: Int?
    // The engine's rule (`WorkoutEngine.isResting`): a deadline decides when there is one,
    // otherwise a paused rest with time left is resting.
    if let end = input.restEnd {
      if end > now {
        restEnd = end
        restTotal = max(1, input.restSeconds)
      }
    } else if let paused = input.restPausedSeconds, paused > 0 {
      restPaused = min(Self.longestRestSeconds, max(1, Int(paused.rounded(.up))))
    }
    self.init(
      sessionID: input.sessionID,
      title: Self.clipped(input.title, fallback: "Workout"),
      exercise: Self.clipped(input.exercise ?? "", fallback: "Exercise"),
      exerciseIndex: min(max(0, input.exerciseIndex), max(0, exerciseCount - 1)),
      exerciseCount: exerciseCount,
      setNumber: setCount == 0 ? 0 : min(done + 1, setCount), setCount: setCount,
      doneSets: doneSets, totalSets: totalSets, startedAt: input.startedAt,
      restEnd: restEnd, restTotalSeconds: restTotal, restPausedSeconds: restPaused,
      isFinishedAllSets: totalSets > 0 && doneSets == totalSets)
  }

  private static func clipped(_ text: String, fallback: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return fallback }
    var result = ""
    var bytes = 0
    for character in trimmed.prefix(nameLimit) {
      bytes += String(character).utf8.count
      if bytes > nameByteLimit { break }
      result.append(character)
    }
    return result
  }

  public var isResting: Bool { restEnd != nil || restPausedSeconds != nil }

  /// Where the progress ring starts. Nil unless a rest is counting down.
  public var restStart: Date? {
    guard let restEnd, let restTotalSeconds else { return nil }
    return restEnd.addingTimeInterval(-Double(restTotalSeconds))
  }

  /// When the system should mark the activity stale. A running rest goes stale as it ends, so the
  /// views can say "Rest over" instead of a timer parked at zero when the app is suspended and
  /// cannot send the update; anything else goes stale after a few idle hours, so a forgotten
  /// workout stops looking live.
  public func staleDate(now: Date) -> Date {
    if let restEnd { return restEnd.addingTimeInterval(1) }
    return now.addingTimeInterval(Self.idleStaleInterval)
  }

  /// "m:ss" (or "h:mm:ss") for a paused rest, which no system timer renders.
  public static func clock(_ seconds: Int) -> String {
    let total = max(0, seconds)
    let (hours, minutes, secs) = (total / 3_600, total % 3_600 / 60, total % 60)
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, secs)
      : String(format: "%d:%02d", minutes, secs)
  }

  /// "Set 3 of 4", or nil for an exercise with no sets.
  public var setLabel: String? {
    setCount == 0 ? nil : "Set \(setNumber) of \(setCount)"
  }

  /// "Exercise 2 of 5", or nil when the session has none.
  public var exerciseLabel: String? {
    exerciseCount == 0 ? nil : "Exercise \(exerciseIndex + 1) of \(exerciseCount)"
  }
}
