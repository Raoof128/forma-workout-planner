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
