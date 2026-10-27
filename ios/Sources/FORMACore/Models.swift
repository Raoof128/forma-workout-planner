import Foundation

public enum FormaError: Error, LocalizedError, Equatable, Sendable {
  case unsupportedVersion(Int)
  case unsupportedStoreSchema(Int)
  case invalid(String)
  case noActiveWorkout
  case noCompletedSets
  case invalidIndex
  case conflictingRevision(expected: Int, actual: Int)
  case storage(String)
  case corruptStore

  public var errorDescription: String? {
    switch self {
    case .unsupportedVersion:
      "This training-data version is not supported. Your original data has been preserved."
    case .unsupportedStoreSchema:
      "This database was created by a different app version. Your original database has been preserved."
    case .invalid(let reason): reason
    case .noActiveWorkout: "There is no active workout."
    case .noCompletedSets: "Complete at least one valid set before finishing."
    case .invalidIndex: "This set is no longer available."
    case .conflictingRevision:
      "This workout changed in another window. Reopen it before saving again."
    case .storage:
      "Your change could not be saved on this device. Keep this screen open and try again."
    case .corruptStore:
      "Your saved data could not be read. The original has been preserved; it has not been replaced with starter data."
    }
  }
}

public struct ExerciseSource: Codable, Equatable, Sendable {
  public var title: String?
  public var url: String?
  public var author: String?
  public var license: String?
  public var licenseUrl: String?
  public var modified: String?

  public init(
    title: String? = nil, url: String? = nil, author: String? = nil, license: String? = nil,
    licenseUrl: String? = nil, modified: String? = nil
  ) {
    self.title = title
    self.url = url
    self.author = author
    self.license = license
    self.licenseUrl = licenseUrl
    self.modified = modified
  }
}

public struct ExerciseReference: Codable, Equatable, Sendable {
  public var title: String
  public var url: String
  public init(title: String, url: String) {
    self.title = title
    self.url = url
  }
}

public struct ExerciseDefaults: Codable, Equatable, Sendable {
  public var sets: Int
  public var reps: Int
  public var weight: Double
  public var perSide: Bool
  public var durationSeconds: Double?
  public var distanceMeters: Double?

  public init(
    sets: Int = 3, reps: Int = 10, weight: Double = 0, perSide: Bool = false,
    durationSeconds: Double? = nil, distanceMeters: Double? = nil
  ) {
    self.sets = sets
    self.reps = reps
    self.weight = weight
    self.perSide = perSide
    self.durationSeconds = durationSeconds
    self.distanceMeters = distanceMeters
  }
}

/// The set field a hold timer writes, how many seconds make one unit of it, and
/// the longest hold that field can record. Generated from the web's `holdUnit`.
public struct HoldUnit: Codable, Equatable, Sendable {
  public var key: String
  public var seconds: Int
  public var max: Int

  public init(key: String = "durationSeconds", seconds: Int = 1, max: Int = 86_400) {
    self.key = key
    self.seconds = seconds
    self.max = max
  }
}

public struct Exercise: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String { didSet { refreshSearchKey() } }
  public var muscle: String { didSet { refreshSearchKey() } }
  public var equipment: String { didSet { refreshSearchKey() } }
  public var description: String
  public var metric: String
  public var weight: Double
  public var perSide: Bool
  public var loadType: String
  public var source: ExerciseSource?
  public var rawSource: ExerciseSource?
  public var selectable: Bool
  public var guide: String
  public var aliases: [String] { didSet { refreshSearchKey() } }
  public var defaults: ExerciseDefaults
  public var canonicalId: String
  public var guideId: String
  public var side: String?
  public var guideUnavailable: Bool
  public var references: [ExerciseReference]
  /// Catalogue-level decision from the web's `usesHoldTimer(exercise)`. Use
  /// `HoldTimer.isAvailable(for:entry:)`, which also applies the entry's sides.
  public var usesHoldTimer: Bool
  public var holdUnit: HoldUnit
  /// Folded name, muscle, equipment and aliases for `matches(query:)`. Derived
  /// from those four fields, so it never affects equality or the stored format.
  private(set) var searchKey: String

  private mutating func refreshSearchKey() {
    searchKey = Self.makeSearchKey(
      name: name, muscle: muscle, equipment: equipment, aliases: aliases)
  }

  public init(
    id: String, name: String, muscle: String, equipment: String, description: String,
    metric: String = "load_reps", weight: Double = 0, perSide: Bool = false,
    loadType: String = "load", source: ExerciseSource? = nil, rawSource: ExerciseSource? = nil,
    selectable: Bool = true, guide: String = "", aliases: [String] = [],
    defaults: ExerciseDefaults? = nil, canonicalId: String? = nil, guideId: String? = nil,
    side: String? = nil, guideUnavailable: Bool = false, references: [ExerciseReference] = [],
    usesHoldTimer: Bool = false, holdUnit: HoldUnit? = nil
  ) {
    self.id = id
    self.name = name
    self.muscle = muscle
    self.equipment = equipment
    self.description = description
    self.metric = metric
    self.weight = weight
    self.perSide = perSide
    self.loadType = loadType
    self.source = source
    self.rawSource = rawSource
    self.selectable = selectable
    self.guide = guide
    self.aliases = aliases
    self.defaults =
      defaults
      ?? ExerciseDefaults(
        sets: metric == "duration_distance" ? 1 : 3, reps: metric == "load_reps" ? 10 : 1,
        weight: weight, perSide: perSide,
        durationSeconds: ["duration", "duration_distance"].contains(metric) ? 60 : nil,
        distanceMeters: ["duration_distance", "load_distance"].contains(metric) ? 100 : nil)
    self.canonicalId = canonicalId ?? id
    self.guideId = guideId ?? id
    self.side = side
    self.guideUnavailable = guideUnavailable
    self.references = references
    self.usesHoldTimer = usesHoldTimer
    self.holdUnit = holdUnit ?? HoldUnit()
    searchKey = Self.makeSearchKey(
      name: name, muscle: muscle, equipment: equipment, aliases: aliases)
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, muscle, equipment, description, metric, weight, perSide, loadType, source,
      rawSource, selectable, guide, aliases, defaults, canonicalId, guideId, side, guideUnavailable,
      references, usesHoldTimer, holdUnit
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
      muscle: try c.decode(String.self, forKey: .muscle),
      equipment: try c.decode(String.self, forKey: .equipment),
      description: try c.decode(String.self, forKey: .description),
      metric: try c.decodeIfPresent(String.self, forKey: .metric) ?? "load_reps",
      weight: try c.decodeIfPresent(Double.self, forKey: .weight) ?? 0,
      perSide: try c.decodeIfPresent(Bool.self, forKey: .perSide) ?? false,
      loadType: try c.decodeIfPresent(String.self, forKey: .loadType) ?? "load",
      source: try c.decodeIfPresent(ExerciseSource.self, forKey: .source),
      rawSource: try c.decodeIfPresent(ExerciseSource.self, forKey: .rawSource),
      selectable: try c.decodeIfPresent(Bool.self, forKey: .selectable) ?? true,
      guide: try c.decodeIfPresent(String.self, forKey: .guide) ?? "",
      aliases: try c.decodeIfPresent([String].self, forKey: .aliases) ?? [],
      defaults: try c.decodeIfPresent(ExerciseDefaults.self, forKey: .defaults),
      canonicalId: try c.decodeIfPresent(String.self, forKey: .canonicalId),
      guideId: try c.decodeIfPresent(String.self, forKey: .guideId),
      side: try c.decodeIfPresent(String.self, forKey: .side),
      guideUnavailable: try c.decodeIfPresent(Bool.self, forKey: .guideUnavailable) ?? false,
      references: try c.decodeIfPresent([ExerciseReference].self, forKey: .references) ?? [],
      usesHoldTimer: try c.decodeIfPresent(Bool.self, forKey: .usesHoldTimer) ?? false,
      holdUnit: try c.decodeIfPresent(HoldUnit.self, forKey: .holdUnit))
  }
}

public struct Profile: Codable, Equatable, Sendable {
  public var name: String
  public var goal: Int
  public var restSeconds: Int
  public var muted: Bool
  public var fillSets: Bool
  public init(
    name: String = "Guest", goal: Int = 3, restSeconds: Int = 90, muted: Bool = false,
    fillSets: Bool = true
  ) {
    self.name = name
    self.goal = goal
    self.restSeconds = restSeconds
    self.muted = muted
    self.fillSets = fillSets
  }
  private enum CodingKeys: String, CodingKey { case name, goal, restSeconds, muted, fillSets }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      name: try c.decode(String.self, forKey: .name), goal: try c.decode(Int.self, forKey: .goal),
      restSeconds: try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90,
      muted: try c.decodeIfPresent(Bool.self, forKey: .muted) ?? false,
      fillSets: try c.decodeIfPresent(Bool.self, forKey: .fillSets) ?? true)
  }
}

public struct Prescription: Codable, Identifiable, Equatable, Sendable {
  public var exerciseId: String
  public var entryId: String?
  public var sets: Int
  public var reps: Int
  public var repsMax: Int?
  public var weight: Double
  public var durationSeconds: Double?
  public var distanceMeters: Double?
  public var perSide: Bool
  public var rpe: Double?
  public var restSeconds: Int?
  public var note: String?
  public var groupId: String?
  public var id: String { entryId ?? exerciseId }

  public init(
    exerciseId: String, entryId: String? = nil, sets: Int = 3, reps: Int = 10, repsMax: Int? = nil,
    weight: Double = 0, durationSeconds: Double? = nil, distanceMeters: Double? = nil,
    perSide: Bool = false, rpe: Double? = nil, restSeconds: Int? = nil, note: String? = nil,
    groupId: String? = nil
  ) {
    self.exerciseId = exerciseId
    self.entryId = entryId
    self.sets = sets
    self.reps = reps
    self.repsMax = repsMax
    self.weight = weight
    self.durationSeconds = durationSeconds
    self.distanceMeters = distanceMeters
    self.perSide = perSide
    self.rpe = rpe
    self.restSeconds = restSeconds
    self.note = note
    self.groupId = groupId
  }
  private enum CodingKeys: String, CodingKey {
    case exerciseId, entryId, sets, reps, repsMax, weight, durationSeconds, distanceMeters, perSide,
      rpe, restSeconds, note, groupId
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      exerciseId: try c.decode(String.self, forKey: .exerciseId),
      entryId: try c.decodeIfPresent(String.self, forKey: .entryId),
      sets: try c.decode(Int.self, forKey: .sets), reps: try c.decode(Int.self, forKey: .reps),
      repsMax: try c.decodeIfPresent(Int.self, forKey: .repsMax),
      weight: try c.decode(Double.self, forKey: .weight),
      durationSeconds: try c.decodeIfPresent(Double.self, forKey: .durationSeconds),
      distanceMeters: try c.decodeIfPresent(Double.self, forKey: .distanceMeters),
      perSide: try c.decodeIfPresent(Bool.self, forKey: .perSide) ?? false,
      rpe: try c.decodeIfPresent(Double.self, forKey: .rpe),
      restSeconds: try c.decodeIfPresent(Int.self, forKey: .restSeconds),
      note: try c.decodeIfPresent(String.self, forKey: .note),
      groupId: try c.decodeIfPresent(String.self, forKey: .groupId))
  }
}

public struct Routine: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var description: String
  public var minutes: Int
  public var level: String
  public var image: Int
  public var archivedAt: Double?
  public var exercises: [Prescription]

  public init(
    id: String = UUID().uuidString, name: String, description: String = "", minutes: Int = 45,
    level: String = "All levels", image: Int = 0, archivedAt: Double? = nil,
    exercises: [Prescription] = []
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.minutes = minutes
    self.level = level
    self.image = image
    self.archivedAt = archivedAt
    self.exercises = exercises
  }
}

public struct SetSides: Codable, Equatable, Sendable {
  public var left: Int
  public var right: Int
  public init(left: Int, right: Int) {
    self.left = left
    self.right = right
  }
}

/// Native edit controls retain typed drafts in view state. These canonical values
/// intentionally do not decode legacy blank-string drafts or v1 migrations.
public struct LoggedSet: Codable, Equatable, Sendable {
  public var weight: Double
  public var reps: Int
  public var sides: SetSides?
  public var durationSeconds: Double?
  public var distanceMeters: Double?
  public var rpe: Double?
  public var done: Bool

  public init(
    weight: Double = 0, reps: Int = 10, sides: SetSides? = nil, durationSeconds: Double? = nil,
    distanceMeters: Double? = nil, rpe: Double? = nil, done: Bool = false
  ) {
    self.weight = weight
    self.reps = reps
    self.sides = sides
    self.durationSeconds = durationSeconds
    self.distanceMeters = distanceMeters
    self.rpe = rpe
    self.done = done
  }
}

public struct SessionEntry: Codable, Identifiable, Equatable, Sendable {
  public var exerciseId: String
  public var entryId: String?
  public var repsMax: Int?
  public var rpe: Double?
  public var restSeconds: Int?
  public var perSide: Bool
  public var note: String?
  public var groupId: String?
  public var targetReps: Int?
  public var sets: [LoggedSet]
  public var id: String { entryId ?? exerciseId }

  public init(
    exerciseId: String, entryId: String? = nil, repsMax: Int? = nil, rpe: Double? = nil,
    restSeconds: Int? = nil, perSide: Bool = false, note: String? = nil, groupId: String? = nil,
    targetReps: Int? = nil, sets: [LoggedSet] = []
  ) {
    self.exerciseId = exerciseId
    self.entryId = entryId
    self.repsMax = repsMax
    self.rpe = rpe
    self.restSeconds = restSeconds
    self.perSide = perSide
    self.note = note
    self.groupId = groupId
    self.targetReps = targetReps
    self.sets = sets
  }
  private enum CodingKeys: String, CodingKey {
    case exerciseId, entryId, repsMax, rpe, restSeconds, perSide, note, groupId, targetReps, sets
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      exerciseId: try c.decode(String.self, forKey: .exerciseId),
      entryId: try c.decodeIfPresent(String.self, forKey: .entryId),
      repsMax: try c.decodeIfPresent(Int.self, forKey: .repsMax),
      rpe: try c.decodeIfPresent(Double.self, forKey: .rpe),
      restSeconds: try c.decodeIfPresent(Int.self, forKey: .restSeconds),
      perSide: try c.decodeIfPresent(Bool.self, forKey: .perSide) ?? false,
      note: try c.decodeIfPresent(String.self, forKey: .note),
      groupId: try c.decodeIfPresent(String.self, forKey: .groupId),
      targetReps: try c.decodeIfPresent(Int.self, forKey: .targetReps),
      sets: try c.decode([LoggedSet].self, forKey: .sets))
  }
}

public struct WorkoutSession: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var routineId: String?
  public var startedAt: Double
  public var notes: String
  public var restSeconds: Int
  public var restEnd: Double?
  public var restPaused: Double?
  public var exercises: [SessionEntry]
  public var date: String?
  public var duration: Double?

  public init(
    id: String = UUID().uuidString, name: String, routineId: String? = nil, startedAt: Double,
    notes: String = "", restSeconds: Int = 90, restEnd: Double? = nil, restPaused: Double? = nil,
    exercises: [SessionEntry] = [], date: String? = nil, duration: Double? = nil
  ) {
    self.id = id
    self.name = name
    self.routineId = routineId
    self.startedAt = startedAt
    self.notes = notes
    self.restSeconds = restSeconds
    self.restEnd = restEnd
    self.restPaused = restPaused
    self.exercises = exercises
    self.date = date
    self.duration = duration
  }
  private enum CodingKeys: String, CodingKey {
    case id, name, routineId, startedAt, notes, restSeconds, restEnd, restPaused, exercises, date,
      duration
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
      routineId: try c.decodeIfPresent(String.self, forKey: .routineId),
      startedAt: try c.decode(Double.self, forKey: .startedAt),
      notes: try c.decodeIfPresent(String.self, forKey: .notes) ?? "",
      restSeconds: try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90,
      restEnd: try c.decodeIfPresent(Double.self, forKey: .restEnd),
      restPaused: try c.decodeIfPresent(Double.self, forKey: .restPaused),
      exercises: try c.decode([SessionEntry].self, forKey: .exercises),
      date: try c.decodeIfPresent(String.self, forKey: .date),
      duration: try c.decodeIfPresent(Double.self, forKey: .duration))
  }
}

public struct Workspace: Codable, Equatable, Sendable {
  public var version: Int
  public var revision: Int
  public var routines: [Routine]
  public var history: [WorkoutSession]
  public var active: WorkoutSession?
  public var profile: Profile
  public var schedule: [Int]

  public init(
    version: Int = 2, revision: Int = 0, routines: [Routine] = [], history: [WorkoutSession] = [],
    active: WorkoutSession? = nil, profile: Profile = Profile(), schedule: [Int] = []
  ) {
    self.version = version
    self.revision = revision
    self.routines = routines
    self.history = history
    self.active = active
    self.profile = profile
    self.schedule = schedule
  }

  private enum CodingKeys: String, CodingKey {
    case version, revision, routines, history, active, profile, schedule
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(version, forKey: .version)
    try c.encode(revision, forKey: .revision)
    try c.encode(routines, forKey: .routines)
    try c.encode(history, forKey: .history)
    // The canonical web envelope requires this key even without a workout.
    try c.encode(active, forKey: .active)
    try c.encode(profile, forKey: .profile)
    try c.encode(schedule, forKey: .schedule)
  }
}
