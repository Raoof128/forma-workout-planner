/// The website's hold timer rules (src/exerciseLoad.js, src/components/HoldTimer.jsx
/// and Workout.jsx). The running countdown is local view state, as on the web:
/// only the set it logs is saved, so the workspace format is unchanged.
public enum HoldTimer {
  public static let minimumSeconds = 5
  public static let maximumSeconds = 3_600
  public static let stepSeconds = 5
  public static let defaultSeconds = 60

  /// The legacy starter plank logs ten-second reps, so its timer has no field
  /// to write while it logs each side separately.
  public static func isAvailable(for exercise: Exercise?, entry: SessionEntry) -> Bool {
    guard let exercise, exercise.usesHoldTimer else { return false }
    if exercise.id == "plank" { return !(entry.perSide && exercise.metric == "load_reps") }
    return true
  }

  public static func maximum(_ unit: HoldUnit) -> Int { min(maximumSeconds, unit.max) }
  public static func step(_ unit: HoldUnit) -> Int { max(stepSeconds, unit.seconds) }
  public static func minimum(_ unit: HoldUnit) -> Int { max(minimumSeconds, unit.seconds) }

  /// Whole units only, and never longer than the set's field can record.
  public static func clamp(_ seconds: Int, unit: HoldUnit) -> Int {
    let units = (Double(seconds) / Double(unit.seconds)).rounded()
    let rounded = Int(units) * unit.seconds
    return min(maximum(unit), max(minimum(unit), rounded))
  }

  /// The next unfinished set's planned time, or a minute when it has none.
  public static func defaultLength(for entry: SessionEntry, unit: HoldUnit) -> Int {
    let planned: Double
    if let set = entry.sets.first(where: { !$0.done }) {
      planned =
        unit.key == "reps"
        ? Double(set.reps) * Double(unit.seconds)
        : (set.durationSeconds ?? 0) * Double(unit.seconds)
    } else {
      planned = 0
    }
    let seconds = planned.isFinite && planned > 0 ? Int(planned.rounded()) : defaultSeconds
    return clamp(seconds, unit: unit)
  }

  /// Full units held. A ten-second-rep plank held for 37 seconds logs 3 reps.
  public static func loggedCount(seconds: Int, unit: HoldUnit) -> Int {
    max(0, seconds) / unit.seconds
  }

  /// The set a finished hold writes: the one it started on, or the first
  /// unfinished set if that one was ticked while the timer ran.
  public static func targetSet(in entry: SessionEntry, startedOn index: Int) -> Int? {
    if entry.sets.indices.contains(index), !entry.sets[index].done { return index }
    return entry.sets.firstIndex { !$0.done }
  }

  public static func loggedText(count: Int, unit: HoldUnit) -> String {
    unit.seconds == 1
      ? "\(count) seconds"
      : "\(count) \(count == 1 ? "rep" : "reps") (\(count * unit.seconds) seconds)"
  }
}

extension WorkoutEngine {
  /// Writes a finished hold into its set and completes that set exactly as
  /// ticking it would, including the programmed rest.
  public static func logHold(
    in workspace: Workspace, entryID: String, startedOn setIndex: Int, seconds: Int, now: Double,
    catalog: [Exercise]
  ) throws -> (workspace: Workspace, setIndex: Int, count: Int) {
    guard var active = workspace.active else { throw FormaError.noActiveWorkout }
    guard let entryIndex = active.exercises.firstIndex(where: { $0.id == entryID }) else {
      throw FormaError.invalidIndex
    }
    let entry = active.exercises[entryIndex]
    guard let exercise = catalog.first(where: { $0.id == entry.exerciseId }),
      HoldTimer.isAvailable(for: exercise, entry: entry)
    else { throw FormaError.invalid("This exercise doesn't use the hold timer.") }
    guard let index = HoldTimer.targetSet(in: entry, startedOn: setIndex) else {
      throw FormaError.invalid("Every set is already logged.")
    }
    let unit = exercise.holdUnit
    let count = HoldTimer.loggedCount(seconds: seconds, unit: unit)
    guard count >= 1 else {
      throw FormaError.invalid("Hold for at least \(unit.seconds) seconds before ending the set.")
    }
    if unit.key == "reps" {
      active.exercises[entryIndex].sets[index].reps = count
    } else {
      active.exercises[entryIndex].sets[index].durationSeconds = Double(count)
    }
    var candidate = workspace
    candidate.active = active
    let logged = try toggleSet(
      in: candidate, entryIndex: entryIndex, setIndex: index, now: now, catalog: catalog)
    return (logged, index, count)
  }
}
