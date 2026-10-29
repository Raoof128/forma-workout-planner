import CryptoKit
import Foundation

/// Repointing a development build at staging must not send the production
/// session there or reuse its unsent training. Keep the original production
/// paths for existing installs; every other origin gets its own namespace.
struct AccountStorage: Sendable {
  let root: URL
  let origin: URL

  private var originalProduction: Bool {
    origin.absoluteString == "https://forma.raoufabedini.dev"
  }

  var keychainAccount: String {
    originalProduction ? "session" : "session:" + origin.absoluteString
  }

  var directory: URL {
    guard !originalProduction else { return root }
    let digest = SHA256.hash(data: Data(origin.absoluteString.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return root.appendingPathComponent("account-\(digest)", isDirectory: true)
  }
}

/// Remembers, on this iPhone only, that a member asked to delete their account
/// and when. The account answers a deleted member's session the same way it
/// answers an expired one, so this is how the app tells the two apart: a
/// session that ends within a day of a deletion request has probably ended
/// because the request went through. The file holds opaque member references
/// and times, never an address or a password.
enum AccountDeletionLedger {
  /// How long a request is treated as outstanding. The emailed link does not
  /// outlive a day.
  static let window: TimeInterval = 24 * 60 * 60
  static let filename = "account-deletion-requests.json"

  private static func url(_ directory: URL) -> URL {
    directory.appendingPathComponent(filename, isDirectory: false)
  }

  private static func read(_ directory: URL) -> [String: Double] {
    guard let data = try? Data(contentsOf: url(directory)),
      let table = try? JSONDecoder().decode([String: Double].self, from: data)
    else { return [:] }
    return table
  }

  private static func write(_ table: [String: Double], to directory: URL) {
    let location = url(directory)
    if table.isEmpty {
      try? FileManager.default.removeItem(at: location)
      return
    }
    guard let data = try? JSONEncoder().encode(table) else { return }
    try? data.write(to: location, options: [.atomic, .completeFileProtection])
  }

  static func record(member: String, in directory: URL, now: Date = .now) {
    var table = read(directory)
    table[member] = now.timeIntervalSince1970
    write(table, to: directory)
  }

  /// When the member asked, or nil when they have not (or it was long ago).
  static func requestedAt(member: String, in directory: URL, now: Date = .now) -> Date? {
    guard let stamp = read(directory)[member] else { return nil }
    let date = Date(timeIntervalSince1970: stamp)
    let age = now.timeIntervalSince(date)
    return age >= 0 && age <= window ? date : nil
  }

  static func clear(member: String, in directory: URL) {
    var table = read(directory)
    guard table.removeValue(forKey: member) != nil else { return }
    write(table, to: directory)
  }
}
