import Foundation

/// A read-only presentation contract. No database, Health, auth, profile or history dependencies.
public struct TrainingSnapshot: Codable, Equatable, Sendable {
  public static let schema = 1
  public static let group = "group.dev.raoufabedini.forma"
  public static let filename = "training-widget-v1.json"
  public static let kind = "dev.raoufabedini.forma.training"
  public var version = Self.schema
  public var epoch: String
  public var revision: Int
  public var generatedAt: Date
  public var expiresAt: Date
  public var state: State
  public var routine: RoutineSummary?
  public var active: ActiveSummary?
  public var week: WeekSummary?
  /// Set by `visible(at:)` after `expiresAt` while the next-routine facts are still shown. Never
  /// stored: the app only ever writes fresh snapshots, so this stays out of the file contract.
  public var carriedOver = false

  private enum CodingKeys: String, CodingKey {
    case version, epoch, revision, generatedAt, expiresAt, state, routine, active, week
  }

  public enum State: String, Codable, Sendable { case ready, empty, hidden, unavailable, stale }
  public struct RoutineSummary: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var exercises: Int
    public var minutes: Int
    public init(id: String, name: String, exercises: Int, minutes: Int) {
      self.id = id
      self.name = name
      self.exercises = exercises
      self.minutes = minutes
    }
  }
  public struct ActiveSummary: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var completedSets: Int
    public var totalSets: Int
    public init(id: String, name: String, completedSets: Int, totalSets: Int) {
      self.id = id
      self.name = name
      self.completedSets = completedSets
      self.totalSets = totalSets
    }
  }
  public struct WeekSummary: Codable, Equatable, Sendable {
    public var sessions: Int
    public var goal: Int
    /// Monday first; multiple sessions on one day still count as one trained day.
    public var days: [Bool]
    public init(sessions: Int, goal: Int, days: [Bool]) {
      self.sessions = sessions
      self.goal = goal
      self.days = days
    }
  }
  public init(
    epoch: String, revision: Int = 0, generatedAt: Date, expiresAt: Date,
    state: State, routine: RoutineSummary? = nil, active: ActiveSummary? = nil,
    week: WeekSummary? = nil
  ) {
    self.epoch = epoch
    self.revision = revision
    self.generatedAt = generatedAt
    self.expiresAt = expiresAt
    self.state = state
    self.routine = routine
    self.active = active
    self.week = week
  }

  public static func unavailable(at date: Date = .now) -> Self {
    Self(epoch: "", generatedAt: date, expiresAt: date, state: .unavailable)
  }

  /// Fail closed on corrupt/future contracts and bound allocations before decoding.
  public static func decode(_ data: Data, at now: Date) throws -> Self {
    guard data.count <= 32_768 else { throw SnapshotError.invalid }
    let value = try JSONDecoder().decode(Self.self, from: data)
    guard value.version == schema, value.revision >= 0, value.epoch.utf16.count <= 200,
      value.generatedAt <= now.addingTimeInterval(60), value.expiresAt >= value.generatedAt,
      value.expiresAt.timeIntervalSince(value.generatedAt) <= 90_000,
      value.routine.map({
        valid($0.id) && valid($0.name) && (0...200).contains($0.exercises)
          && (0...1440).contains($0.minutes)
      }) ?? true,
      value.active.map({
        valid($0.id) && valid($0.name) && $0.completedSets >= 0
          && $0.totalSets >= $0.completedSets && $0.totalSets <= 40_000
      }) ?? true,
      value.week.map({
        (0...10_000).contains($0.sessions) && (1...7).contains($0.goal)
          && $0.days.count == 7
      }) ?? true,
      value.state != .ready || value.week != nil,
      value.state == .ready || (value.routine == nil && value.active == nil && value.week == nil)
    else { throw SnapshotError.invalid }
    return value.visible(at: now)
  }

  /// How long after `expiresAt` the next routine and weekly count stay on screen. Midnight is
  /// when the day-bound facts lapse, not when the suggested routine changes: only training moves
  /// it, and training republishes. Bounded so a phone left alone for days does not keep offering
  /// a routine from a stale snapshot.
  public static let carryWindow: TimeInterval = 72 * 3600

  /// Instants after `now` at which `visible(at:)` changes what is shown. A timeline carries these
  /// as pre-built entries so content leaves on time without a reload.
  public func visibilityBoundaries(after now: Date) -> [Date] {
    guard state == .ready else { return [] }
    return [expiresAt, expiresAt.addingTimeInterval(Self.carryWindow)].filter { $0 > now }
  }

  public func visible(at now: Date) -> Self {
    guard state == .ready, now >= expiresAt else { return self }
    guard now < expiresAt.addingTimeInterval(Self.carryWindow) else {
      // Past the carry window nothing personal may remain tappable.
      return Self(
        epoch: epoch, revision: revision, generatedAt: generatedAt,
        expiresAt: expiresAt, state: .stale)
    }
    var carried = self
    // A saved workout is only trusted for its own short window; everything else outlives midnight.
    carried.active = nil
    carried.carriedOver = true
    if let week, !TrainingCalendar.isSameWeek(generatedAt, now) {
      carried.week = .init(
        sessions: 0, goal: week.goal, days: Array(repeating: false, count: 7))
    }
    return carried
  }

  private static func valid(_ text: String) -> Bool { !text.isEmpty && text.utf16.count <= 200 }
  public enum SnapshotError: Error { case invalid }
}
