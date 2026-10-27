import Foundation

extension Exercise {
  /// Search is local. Every query word may match a different indexed field.
  public func matches(query: String) -> Bool {
    let words = Self.foldedWords(of: query)
    // An empty query matches everything; skip folding the indexed text.
    guard !words.isEmpty else { return true }
    return matches(foldedWords: words)
  }

  /// The exercises that match `query`, in their original order. Equivalent to
  /// `exercises.filter { $0.matches(query: query) }`, but folds the query once
  /// instead of once per exercise.
  public static func filter(_ exercises: [Exercise], matching query: String) -> [Exercise] {
    let words = foldedWords(of: query)
    guard !words.isEmpty else { return exercises }
    return exercises.filter { $0.matches(foldedWords: words) }
  }

  /// Splits on whitespace and folds each word. The result is empty only for a
  /// query with no words; a word with no indexable letters folds to "" and
  /// (as before) matches nothing.
  private static func foldedWords(of query: String) -> [[UInt8]] {
    query.split(whereSeparator: \.isWhitespace).map { Array(fold(String($0)).utf8) }
  }

  private func matches(foldedWords words: [[UInt8]]) -> Bool {
    var key = searchKey
    return key.withUTF8 { haystack in words.allSatisfy { Self.contains(haystack, $0) } }
  }

  /// Substring test over the folded key's ASCII bytes. An empty needle (a word
  /// with no letters or digits, such as an emoji) matches nothing, as it always has.
  private static func contains(_ haystack: UnsafeBufferPointer<UInt8>, _ needle: [UInt8]) -> Bool {
    guard let first = needle.first, needle.count <= haystack.count else { return false }
    let last = haystack.count - needle.count
    var start = 0
    while start <= last {
      if haystack[start] == first {
        var offset = 1
        while offset < needle.count && haystack[start + offset] == needle[offset] { offset += 1 }
        if offset == needle.count { return true }
      }
      start += 1
    }
    return false
  }

  /// The folded text every query word is looked up in. Computed once per
  /// exercise (see `Exercise.searchKey`) rather than once per query.
  static func makeSearchKey(name: String, muscle: String, equipment: String, aliases: [String])
    -> String
  {
    fold(([name, muscle, equipment] + aliases).joined(separator: " "))
  }

  /// Lowercases, strips diacritics and keeps only ASCII letters and digits.
  static func fold(_ text: String) -> String {
    // Pure-ASCII text (nearly the whole catalogue and every English query)
    // folds to exactly this, without a trip through Foundation's ICU folding.
    var folded = [UInt8]()
    folded.reserveCapacity(text.utf8.count)
    for byte in text.utf8 {
      if byte >= 0x80 { return foldUnicode(text) }
      if (97...122).contains(byte) || (48...57).contains(byte) {
        folded.append(byte)
      } else if (65...90).contains(byte) {
        folded.append(byte + 32)
      }
    }
    return String(decoding: folded, as: UTF8.self)
  }

  /// The general rule, and the reference the ASCII path must equal.
  static func foldUnicode(_ text: String) -> String {
    let normalized = text.folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    return String(
      normalized.unicodeScalars.filter {
        (97...122).contains($0.value) || (48...57).contains($0.value)
      })
  }
}
