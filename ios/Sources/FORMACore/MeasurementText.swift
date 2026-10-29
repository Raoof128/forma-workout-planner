import Foundation

/// A measurement summary keeps the saved units visible in history and last-time hints.
public enum MeasurementText {
  public static func summary(
    _ set: LoggedSet, exercise: Exercise?, locale: Locale = .current
  ) -> String {
    let weight = set.weight.formatted(
      .number.precision(.fractionLength(0...2)).locale(locale))
    switch exercise?.metric ?? "load_reps" {
    case "duration":
      let seconds = (set.durationSeconds ?? 0).formatted(.number.locale(locale))
      return "\(seconds) sec" + (set.weight > 0 ? " · \(weight) kg" : "")
    case "duration_distance":
      let seconds = (set.durationSeconds ?? 0).formatted(.number.locale(locale))
      let metres = (set.distanceMeters ?? 0).formatted(.number.locale(locale))
      return "\(seconds) sec · \(metres) m" + (set.weight > 0 ? " · \(weight) kg" : "")
    case "load_distance":
      let metres = (set.distanceMeters ?? 0).formatted(.number.locale(locale))
      return "\(weight) kg · \(metres) m"
    default:
      let reps = set.sides.map { "\($0.left) L / \($0.right) R" } ?? "\(set.reps) reps"
      let showWeight = exercise?.loadType != "none" || set.weight > 0
      return (showWeight ? "\(weight) kg × " : "") + reps
        + (exercise?.id == "plank" ? " (10 sec / rep)" : "")
    }
  }
}
