import Foundation

/// One full-string numeric contract for routine targets and workout drafts.
/// Grouping is deliberately unsupported; a point, comma or the locale's decimal
/// separator is treated as a decimal. Validation of field bounds is separate.
public enum MeasurementNumberInput {
  public static func parse(_ input: String, locale: Locale = .current) -> Double? {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }
    let separator = locale.decimalSeparator ?? "."
    var normalized = ""
    var decimals = 0
    for character in text {
      if let digit = character.wholeNumberValue, (0...9).contains(digit) {
        normalized += String(digit)
      } else if character == "." || character == "," || String(character) == separator {
        decimals += 1
        guard decimals <= 1 else { return nil }
        normalized += "."
      } else if character == "+" || character == "-" || character == "e" || character == "E" {
        normalized.append(character)
      } else {
        return nil
      }
    }
    guard let value = Double(normalized), value.isFinite else { return nil }
    return value
  }

  public static func display(_ value: Double, locale: Locale = .current) -> String {
    // String(Double) retains a round-trippable representation rather than
    // rounding a stored measurement when another field is edited.
    let value = String(value)
    let text = value.hasSuffix(".0") ? String(value.dropLast(2)) : value
    return text.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
  }
}
