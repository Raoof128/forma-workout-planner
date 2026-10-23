import Foundation

extension Exercise {
  /// Search is local. Every query word may match a different indexed field.
  public func matches(query: String) -> Bool {
    let text = Self.fold(([name, muscle, equipment] + aliases).joined(separator: " "))
    return query.split(whereSeparator: \.isWhitespace).allSatisfy {
      text.contains(Self.fold(String($0)))
    }
  }

  private static func fold(_ text: String) -> String {
    let normalized = text.folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    return String(
      normalized.unicodeScalars.filter {
        (97...122).contains($0.value) || (48...57).contains($0.value)
      })
  }
}
