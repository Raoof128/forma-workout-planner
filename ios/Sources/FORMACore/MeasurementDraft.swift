import Foundation

/// Uncommitted text lives separately from canonical numeric set values. Parsing
/// never implies durability; the UI must still await its workspace transaction.
public struct MeasurementDraft: Equatable, Sendable {
  public var weight: String
  public var reps: String
  public var seconds: String
  public var distance: String
  public var left: String
  public var right: String
  private let locale: Locale

  public init(_ set: LoggedSet, locale: Locale = .current) {
    self.locale = locale
    weight = MeasurementNumberInput.display(set.weight, locale: locale)
    reps = MeasurementNumberInput.display(Double(set.reps), locale: locale)
    seconds = MeasurementNumberInput.display(set.durationSeconds ?? 60, locale: locale)
    distance = MeasurementNumberInput.display(set.distanceMeters ?? 100, locale: locale)
    left = MeasurementNumberInput.display(Double(set.sides?.left ?? 10), locale: locale)
    right = MeasurementNumberInput.display(Double(set.sides?.right ?? 10), locale: locale)
  }

  private func number(_ input: String, label: String) throws -> Double {
    guard let value = MeasurementNumberInput.parse(input, locale: locale) else {
      throw FormaError.invalid(
        "Enter a valid \(label). Use your decimal separator, a point or a comma, without thousands separators."
      )
    }
    return value
  }

  public func value(from original: LoggedSet) throws -> LoggedSet {
    var set = original
    set.weight = try number(weight, label: "weight")
    if original.sides != nil {
      // The visible side inputs own the canonical total. A hidden reps draft
      // must never block their save or rewrite an existing unequal split.
      let l = try number(left, label: "left-side repetitions")
      let r = try number(right, label: "right-side repetitions")
      guard l.rounded() == l, r.rounded() == r, (1...100).contains(l),
        (1...100).contains(r), l + r <= 100
      else {
        throw FormaError.invalid(
          "Each side needs whole repetitions from 1 to 100, with no more than 100 in total.")
      }
      set.sides = SetSides(left: Int(l), right: Int(r))
      set.reps = Int(l + r)
    } else {
      let repetitions = try number(reps, label: "repetition count")
      guard repetitions.rounded() == repetitions, (1...100).contains(repetitions) else {
        throw FormaError.invalid("Reps must be a whole number from 1 to 100.")
      }
      set.reps = Int(repetitions)
    }
    if original.durationSeconds != nil {
      set.durationSeconds = try number(seconds, label: "time in seconds")
    }
    if original.distanceMeters != nil {
      set.distanceMeters = try number(distance, label: "distance in metres")
    }
    return set
  }
}
