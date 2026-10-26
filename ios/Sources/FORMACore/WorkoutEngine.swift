import Foundation

public enum WorkoutEngine {
  public static func validate(_ workspace: Workspace, catalog: [Exercise]) throws {
    try workspace.validate(catalog: catalog)
  }

  /// All times at the domain boundary use the website's Unix milliseconds.
  public static func start(
    routine: Routine, now: Double, restSeconds: Int = 90, catalog: [Exercise] = []
  ) throws -> WorkoutSession {
    try checkTimestamp(now)
    try check((10...600).contains(restSeconds), "Rest must be between 10 and 600 seconds.")
    try Workspace(routines: [routine]).validateStructure(catalog: catalog.isEmpty ? nil : catalog)
    let metrics = Dictionary(
      catalog.map { ($0.id, $0.metric) }, uniquingKeysWith: { first, _ in first })
    let entries = try routine.exercises.map { prescription in
      let loadReps =
        metrics[prescription.exerciseId].map { $0 == "load_reps" }
        ?? (prescription.durationSeconds == nil && prescription.distanceMeters == nil)
      let logsSides = prescription.perSide && loadReps
      // Matches the web's perSideTargetError: a rep range above 50 per side
      // cannot fit the logger's two side fields, even when the minimum does.
      if logsSides {
        try check(
          max(prescription.reps, prescription.repsMax ?? 0) <= 50,
          "Per-side starting targets must total no more than 100 reps.")
      }
      let sides = logsSides ? SetSides(left: prescription.reps, right: prescription.reps) : nil
      let set = LoggedSet(
        weight: prescription.weight, reps: sides.map { $0.left + $0.right } ?? prescription.reps,
        sides: sides, durationSeconds: prescription.durationSeconds,
        distanceMeters: prescription.distanceMeters)
      return SessionEntry(
        exerciseId: prescription.exerciseId, entryId: prescription.entryId,
        repsMax: prescription.repsMax, rpe: prescription.rpe, restSeconds: prescription.restSeconds,
        perSide: prescription.perSide, note: prescription.note, groupId: prescription.groupId,
        targetReps: prescription.reps, sets: Array(repeating: set, count: prescription.sets))
    }
    return WorkoutSession(
      name: routine.name, routineId: routine.id, startedAt: now, restSeconds: restSeconds,
      exercises: entries)
  }

  public static func toggleSet(
    in workspace: Workspace, entryIndex: Int, setIndex: Int, now: Double, catalog: [Exercise] = []
  ) throws -> Workspace {
    try checkTimestamp(now)
    guard var active = workspace.active else { throw FormaError.noActiveWorkout }
    guard active.exercises.indices.contains(entryIndex),
      active.exercises[entryIndex].sets.indices.contains(setIndex)
    else { throw FormaError.invalidIndex }
    active.exercises[entryIndex].sets[setIndex].done.toggle()
    let entry = active.exercises[entryIndex]
    if entry.sets[setIndex].done
      && (entry.groupId == nil
        || active.exercises.dropFirst(entryIndex + 1).first?.groupId != entry.groupId)
    {
      let duration = entry.restSeconds ?? workspace.profile.restSeconds
      active.restSeconds = duration
      active.restEnd = now + Double(duration) * 1_000
      active.restPaused = nil
    }
    var result = workspace
    result.active = active
    try result.validateStructure(catalog: catalog.isEmpty ? nil : catalog)
    return result
  }

  public static func finish(_ workspace: Workspace, now: Double, catalog: [Exercise] = []) throws
    -> Workspace
  {
    try checkTimestamp(now)
    guard var active = workspace.active else { throw FormaError.noActiveWorkout }
    guard active.exercises.contains(where: { $0.sets.contains(where: \.done) }) else {
      throw FormaError.noCompletedSets
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    active.date = formatter.string(from: Date(timeIntervalSince1970: now / 1_000))
    active.duration = floor(max(0, now - active.startedAt) / 1_000)
    active.restEnd = nil
    active.restPaused = nil
    var result = workspace
    result.active = nil
    result.history.append(active)
    try result.validateStructure(catalog: catalog.isEmpty ? nil : catalog)
    return result
  }

  public static func completedSets(_ session: WorkoutSession) -> Int {
    session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
  }

  public static func volume(_ session: WorkoutSession, catalog: [Exercise]) -> Double {
    let measurements = Dictionary(
      catalog.map { ($0.id, $0.metric) }, uniquingKeysWith: { first, _ in first })
    return session.exercises.reduce(0) { total, entry in
      guard measurements[entry.exerciseId] == "load_reps" else { return total }
      return total + entry.sets.filter(\.done).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
  }

  public static func estimatedOneRM(weight: Double, reps: Int) -> Double? {
    guard weight.isFinite, (0...1_000).contains(weight), (1...12).contains(reps) else { return nil }
    return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
  }

  public static func estimatedOneRM(_ set: LoggedSet, exercise: Exercise) -> Double? {
    guard set.done, exercise.metric == "load_reps" else { return nil }
    return estimatedOneRM(
      weight: set.weight, reps: set.sides.map { max($0.left, $0.right) } ?? set.reps)
  }

  public static func remainingRest(_ session: WorkoutSession, now: Double) -> Double {
    if let end = session.restEnd { return max(0, ceil((end - now) / 1_000)) }
    return session.restPaused ?? 0
  }

  public static func pauseRest(in workspace: Workspace, now: Double) throws -> Workspace {
    try updateRest(workspace, now: now) { active in
      guard active.restEnd != nil else { return }
      active.restPaused = min(600, remainingRest(active, now: now))
      active.restEnd = nil
    }
  }

  public static func resumeRest(in workspace: Workspace, now: Double) throws -> Workspace {
    try updateRest(workspace, now: now) { active in
      guard active.restEnd == nil else { return }
      let remaining = active.restPaused.flatMap { $0 > 0 ? $0 : nil } ?? Double(active.restSeconds)
      active.restEnd = now + remaining * 1_000
      active.restPaused = nil
    }
  }

  public static func adjustRest(in workspace: Workspace, by delta: Double, now: Double) throws
    -> Workspace
  {
    guard delta.isFinite else { throw FormaError.invalid("Rest adjustment must be a number.") }
    return try updateRest(workspace, now: now) { active in
      let seconds = min(600, max(0, remainingRest(active, now: now) + delta))
      if active.restEnd != nil {
        active.restEnd = seconds > 0 ? now + seconds * 1_000 : nil
        active.restPaused = nil
      } else {
        active.restPaused = seconds > 0 ? seconds : nil
      }
    }
  }

  public static func skipRest(in workspace: Workspace) throws -> Workspace {
    guard var active = workspace.active else { throw FormaError.noActiveWorkout }
    active.restEnd = nil
    active.restPaused = nil
    var result = workspace
    result.active = active
    try result.validateStructure(catalog: nil)
    return result
  }

  private static func updateRest(
    _ workspace: Workspace, now: Double, mutation: (inout WorkoutSession) -> Void
  ) throws -> Workspace {
    try checkTimestamp(now)
    guard var active = workspace.active else { throw FormaError.noActiveWorkout }
    mutation(&active)
    var result = workspace
    result.active = active
    try result.validateStructure(catalog: nil)
    return result
  }
}

extension Workspace {
  public static let maximumBytes = 20 * 1_024 * 1_024

  public func validate(catalog: [Exercise]) throws {
    try validateStructure(catalog: catalog)
  }

  // Nil is used only for pure structural operations without a catalog. Every
  // persistence boundary passes the complete current catalog, including aliases.
  func validateStructure(catalog: [Exercise]?) throws {
    guard version == 2 else { throw FormaError.unsupportedVersion(version) }
    try check(
      revision >= 0 && revision <= 9_007_199_254_740_991, "The workspace revision is invalid.")
    try check(
      routines.count <= 200 && history.count <= 10_000,
      "This workspace exceeds the supported record limit.")
    try check(
      Set(routines.map(\.id)).count == routines.count
        && Set(history.map(\.id)).count == history.count,
      "Training records must have unique identifiers.")
    try checkName(profile.name, maximum: 50)
    try check((1...7).contains(profile.goal), "Choose a weekly goal from 1 to 7 workouts.")
    try check((10...600).contains(profile.restSeconds), "Rest must be between 10 and 600 seconds.")
    try check(
      schedule.count <= 7 && Set(schedule).count == schedule.count
        && schedule.allSatisfy { (0...6).contains($0) }, "Choose each training weekday only once.")
    let byID = catalog.map {
      Dictionary($0.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    for routine in routines {
      try checkID(routine.id)
      try checkName(routine.name, maximum: 60)
      try check(
        routine.description.utf16.count <= 500 && (1...1_000).contains(routine.minutes)
          && (0...2).contains(routine.image) && (1...50).contains(routine.level.utf16.count),
        "This routine has invalid details.")
      if let archived = routine.archivedAt { try checkTimestamp(archived) }
      try checkEntries(routine.exercises.map { ($0.id, $0.groupId) })
      for entry in routine.exercises {
        try checkID(entry.exerciseId)
        if let id = entry.entryId { try checkID(id) }
        if let byID {
          try check(
            byID[entry.exerciseId] != nil,
            "This exercise identifier is not supported by this app version.")
        }
        try check(
          (1...12).contains(entry.sets) && (1...100).contains(entry.reps),
          "Routine targets require 1–12 sets and 1–100 reps.")
        if let maximum = entry.repsMax {
          try check(
            (entry.reps...100).contains(maximum),
            "The maximum rep target must be at least the minimum.")
        }
        try checkProgramming(
          rpe: entry.rpe, rest: entry.restSeconds, note: entry.note, group: entry.groupId)
        // Optional prescription measurements must be positive even when the
        // movement's main metric does not require that particular field.
        if let duration = entry.durationSeconds {
          try check(duration > 0, "A routine duration target must be greater than zero.")
        }
        if let distance = entry.distanceMeters {
          try check(distance > 0, "A routine distance target must be greater than zero.")
        }
        try checkSet(
          LoggedSet(
            weight: entry.weight, reps: entry.reps, durationSeconds: entry.durationSeconds,
            distanceMeters: entry.distanceMeters, done: true),
          metric: byID?[entry.exerciseId]?.metric)
      }
    }
    var totalSets = 0
    for session in history + (active.map { [$0] } ?? []) {
      totalSets += session.exercises.reduce(0) { $0 + $1.sets.count }
      try check(totalSets <= 150_000, "This workspace exceeds the supported total-set limit.")
      try checkID(session.id)
      try checkName(session.name, maximum: 60)
      if let id = session.routineId { try checkID(id) }
      try checkTimestamp(session.startedAt)
      try check(
        session.notes.utf16.count <= 10_000 && (10...600).contains(session.restSeconds),
        "This session has invalid notes or rest settings.")
      if let deadline = session.restEnd { try checkTimestamp(deadline) }
      if let paused = session.restPaused {
        try check(
          paused.isFinite && (0...600).contains(paused),
          "Paused rest must be between 0 and 600 seconds.")
      }
      try checkEntries(session.exercises.map { ($0.id, $0.groupId) })
      for entry in session.exercises {
        try checkID(entry.exerciseId)
        if let id = entry.entryId { try checkID(id) }
        if let byID {
          try check(
            byID[entry.exerciseId] != nil,
            "This exercise identifier is not supported by this app version.")
        }
        try check((1...100).contains(entry.sets.count), "An exercise must contain 1–100 sets.")
        if let target = entry.targetReps {
          try check((1...100).contains(target), "The rep target must be between 1 and 100.")
        }
        if let maximum = entry.repsMax {
          try check(
            (1...100).contains(maximum), "The maximum rep target must be between 1 and 100.")
        }
        try checkProgramming(
          rpe: entry.rpe, rest: entry.restSeconds, note: entry.note, group: entry.groupId)
        for set in entry.sets { try checkSet(set, metric: byID?[entry.exerciseId]?.metric) }
      }
    }
    for session in history {
      try check(
        session.exercises.contains { $0.sets.contains(where: \.done) },
        "A finished workout needs at least one completed set.")
      guard let date = session.date, let duration = session.duration else {
        throw FormaError.invalid("A finished workout needs its completion date and duration.")
      }
      try check(validCompletionDate(date), "The workout completion date is invalid.")
      try check(
        duration.isFinite && (0...9_007_199_254_740_991).contains(duration),
        "The workout duration is invalid.")
    }
    if let active {
      try check(
        active.date == nil && active.duration == nil,
        "An active workout cannot carry completed-history date or duration fields.")
      try check(
        !history.contains { $0.id == active.id },
        "The active workout is already present in history.")
    }
  }
}

/// Matches the shared web schema's UTC datetime contract. Foundation's ISO
/// parser accepts offsets and normalizes invalid dates such as 24:00 or 29
/// February in a non-leap year, so successful parsing alone is insufficient.
private func validCompletionDate(_ value: String) -> Bool {
  let bytes = Array(value.utf8)
  guard bytes.count >= 20, bytes[4] == 45, bytes[7] == 45, bytes[10] == 84,
    bytes[13] == 58, bytes[16] == 58, bytes.last == 90
  else { return false }
  let positions = [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]
  guard positions.allSatisfy({ (48...57).contains(bytes[$0]) }) else { return false }
  if bytes.count > 20 {
    guard bytes.count >= 22, bytes[19] == 46,
      bytes[20..<(bytes.count - 1)].allSatisfy({ (48...57).contains($0) })
    else { return false }
  }
  func number(_ range: Range<Int>) -> Int {
    range.reduce(0) { $0 * 10 + Int(bytes[$1] - 48) }
  }
  let year = number(0..<4)
  let month = number(5..<7)
  let day = number(8..<10)
  guard (1...12).contains(month), number(11..<13) <= 23,
    number(14..<16) <= 59, number(17..<19) <= 59
  else { return false }
  let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
  let monthDays = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  return (1...monthDays[month - 1]).contains(day)
}

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw FormaError.invalid(message) }
}

private func checkName(_ value: String, maximum: Int) throws {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  try check(
    (1...maximum).contains(trimmed.utf16.count), "Use a name between 1 and \(maximum) characters.")
}

private func checkID(_ value: String) throws {
  try check((1...200).contains(value.utf16.count), "A training record has an invalid identifier.")
}

private func checkTimestamp(_ value: Double) throws {
  try check(
    value.isFinite && (0...8_640_000_000_000_000).contains(value),
    "A training timestamp is invalid.")
}

private func checkProgramming(rpe: Double?, rest: Int?, note: String?, group: String?) throws {
  if let rpe {
    try check(
      rpe.isFinite && (1...10).contains(rpe) && (rpe * 2).rounded() == rpe * 2,
      "RPE must be between 1 and 10 in half steps.")
  }
  if let rest { try check((10...600).contains(rest), "Rest must be between 10 and 600 seconds.") }
  if let note {
    try check(note.utf16.count <= 140, "An exercise cue can contain up to 140 characters.")
  }
  if let group { try checkID(group) }
}

private func checkEntries(_ entries: [(String, String?)]) throws {
  try check((1...100).contains(entries.count), "A routine or workout needs 1–100 exercises.")
  try check(
    Set(entries.map(\.0)).count == entries.count, "Each exercise row must have a unique identity.")
  var groups: [String: [Int]] = [:]
  for (index, entry) in entries.enumerated() {
    if let group = entry.1 { groups[group, default: []].append(index) }
  }
  for positions in groups.values {
    try check(
      positions.count >= 2 && positions.last! - positions.first! + 1 == positions.count,
      "Supersets need at least two consecutive exercises.")
  }
}

private func checkSet(_ set: LoggedSet, metric: String?) throws {
  try check(
    set.weight.isFinite && (0...1_000).contains(set.weight) && (1...100).contains(set.reps),
    "Enter valid kilograms and reps before saving.")
  if let sides = set.sides {
    try check(
      (1...100).contains(sides.left) && (1...100).contains(sides.right)
        && set.reps == sides.left + sides.right,
      "The rep total must match the left and right sides.")
  }
  if let duration = set.durationSeconds {
    try check(
      duration.isFinite && (0...86_400).contains(duration),
      "Duration must be between 0 and 86,400 seconds.")
  }
  if let distance = set.distanceMeters {
    try check(
      distance.isFinite && (0...1_000_000).contains(distance),
      "Distance must be between 0 and 1,000,000 metres.")
  }
  if let rpe = set.rpe { try checkProgramming(rpe: rpe, rest: nil, note: nil, group: nil) }
  guard set.done else { return }
  if metric == "duration" || metric == "duration_distance" {
    try check(
      (set.durationSeconds ?? 0) >= 1, "Enter at least one second before completing this set.")
  }
  if metric == "duration_distance" || metric == "load_distance" {
    try check(
      (set.distanceMeters ?? 0) >= 1, "Enter at least one metre before completing this set.")
  }
}
