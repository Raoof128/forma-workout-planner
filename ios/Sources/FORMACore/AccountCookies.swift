import Foundation

/// One FORMA session cookie, kept exactly as the account sent it.
public struct FormaCookie: Codable, Equatable, Sendable {
  public var name: String
  /// Never decoded or re-encoded: the value is signed by the account.
  public var value: String
  /// Nil for a cookie the account sent without a lifetime (a session cookie).
  public var expires: Date?

  public init(name: String, value: String, expires: Date? = nil) {
    self.name = name
    self.value = value
    self.expires = expires
  }
}

/// The app's own cookie jar for the account: FORMA cookies only, held as a
/// plain value so the app can keep it in the Keychain and never in
/// `HTTPCookieStorage`.
///
/// Only `forma.*` and `__Secure-forma.*` cookies are accepted, which is all the
/// account sets. A cookie with an empty value, `Max-Age` of zero or less, or an
/// `Expires` in the past is a deletion, as in a browser. The jar talks to one
/// host, so `Domain` and `Path` are not tracked.
public struct FormaCookieJar: Codable, Equatable, Sendable {
  public private(set) var cookies: [FormaCookie]

  public init(cookies: [FormaCookie] = []) { self.cookies = cookies }

  public var isEmpty: Bool { cookies.isEmpty }

  static let maximumCookies = 16
  static let maximumNameBytes = 128
  static let maximumValueBytes = 4_096
  /// A browser caps cookie lifetime near this too.
  static let maximumLifetime: TimeInterval = 400 * 24 * 60 * 60

  public static func isFormaCookieName(_ name: String) -> Bool {
    guard name.utf8.count <= maximumNameBytes else { return false }
    guard name.hasPrefix("forma.") || name.hasPrefix("__Secure-forma.") else { return false }
    // RFC 6265 token characters only.
    let allowed = CharacterSet(
      charactersIn: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return name.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  /// True when a cookie whose name ends with `suffix` (for example
  /// `session_token`) is held and not expired.
  public func contains(suffix: String, now: Date = Date()) -> Bool {
    cookies.contains { $0.name.hasSuffix(suffix) && !Self.isExpired($0, now: now) }
  }

  public mutating func removeAll() { cookies.removeAll() }

  public mutating func pruneExpired(now: Date = Date()) {
    cookies.removeAll { Self.isExpired($0, now: now) }
  }

  /// The `Cookie` request header, or nil when nothing is held.
  public func cookieHeader(now: Date = Date()) -> String? {
    let live = cookies.filter { !Self.isExpired($0, now: now) }
    guard !live.isEmpty else { return nil }
    return live.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
  }

  /// Applies every `Set-Cookie` in a response. `combinedHeader` is the value
  /// `HTTPURLResponse` gives for `Set-Cookie`, where several cookies are joined
  /// with ", " (and an `Expires` date contains a comma of its own).
  public mutating func absorb(combinedHeader: String?, now: Date = Date()) {
    guard let combinedHeader else { return }
    absorb(lines: Self.splitCombined(combinedHeader), now: now)
  }

  public mutating func absorb(lines: [String], now: Date = Date()) {
    for line in lines { absorb(line: line, now: now) }
  }

  public mutating func absorb(line: String, now: Date = Date()) {
    let parts = line.split(separator: ";", omittingEmptySubsequences: false)
    guard let pair = parts.first, let equals = pair.firstIndex(of: "=") else { return }
    let name = pair[pair.startIndex..<equals].trimmingCharacters(in: .whitespaces)
    let value = pair[pair.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    guard Self.isFormaCookieName(name), value.utf8.count <= Self.maximumValueBytes else { return }

    var maxAge: Int?
    var expires: Date?
    var secure = false
    for attribute in parts.dropFirst() {
      let text = attribute.trimmingCharacters(in: .whitespaces)
      let key: String
      let argument: String
      if let split = text.firstIndex(of: "=") {
        key = text[text.startIndex..<split].trimmingCharacters(in: .whitespaces).lowercased()
        argument = text[text.index(after: split)...].trimmingCharacters(in: .whitespaces)
      } else {
        key = text.lowercased()
        argument = ""
      }
      switch key {
      case "max-age":
        // A value that is not an integer is ignored, as in a browser.
        if let seconds = Int(argument) { maxAge = seconds }
      case "expires": expires = Self.parseHTTPDate(argument)
      case "secure": secure = true
      default: break
      }
    }
    // Deletions come first, and need no Secure attribute: they can only remove.
    var deadline: Date?
    if let maxAge {
      if maxAge <= 0 {
        remove(name)
        return
      }
      deadline = now.addingTimeInterval(min(TimeInterval(maxAge), Self.maximumLifetime))
    } else if let expires {
      if expires <= now {
        remove(name)
        return
      }
      deadline = min(expires, now.addingTimeInterval(Self.maximumLifetime))
    }
    if value.isEmpty {
      remove(name)
      return
    }
    // A __Secure- cookie must say so; refuse one that does not.
    if name.hasPrefix("__Secure-") && !secure { return }
    let cookie = FormaCookie(name: name, value: value, expires: deadline)
    if let index = cookies.firstIndex(where: { $0.name == name }) {
      cookies[index] = cookie
    } else if cookies.count < Self.maximumCookies {
      cookies.append(cookie)
    }
  }

  private mutating func remove(_ name: String) { cookies.removeAll { $0.name == name } }

  private static func isExpired(_ cookie: FormaCookie, now: Date) -> Bool {
    guard let expires = cookie.expires else { return false }
    return expires <= now
  }

  /// Splits a joined `Set-Cookie` header at the ", " that starts a new cookie
  /// (a name, then "="), leaving the comma inside an `Expires` date alone.
  public static func splitCombined(_ header: String) -> [String] {
    var lines: [String] = []
    var current = ""
    let characters = Array(header)
    var index = 0
    while index < characters.count {
      let character = characters[index]
      if character == ",", index + 1 < characters.count {
        // Look past the whitespace: a new cookie is `token=`, a date's weekday
        // or day-of-month is followed by a space or digit instead.
        var look = index + 1
        while look < characters.count, characters[look] == " " { look += 1 }
        var sawName = false
        var scan = look
        while scan < characters.count {
          let next = characters[scan]
          if next == "=" {
            sawName = scan > look
            break
          }
          if next == ";" || next == "," || next == " " { break }
          scan += 1
        }
        if sawName {
          lines.append(current)
          current = ""
          index += 1
          continue
        }
      }
      current.append(character)
      index += 1
    }
    if !current.isEmpty { lines.append(current) }
    return lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  static func parseHTTPDate(_ text: String) -> Date? {
    let formats = [
      "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd-MMM-yyyy HH:mm:ss zzz",
      "EEEE, dd-MMM-yy HH:mm:ss zzz", "EEE MMM d HH:mm:ss yyyy",
    ]
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    for format in formats {
      formatter.dateFormat = format
      if let date = formatter.date(from: text) { return date }
    }
    return nil
  }
}
