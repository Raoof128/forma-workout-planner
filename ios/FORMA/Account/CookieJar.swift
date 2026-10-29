import FORMACore
import Foundation
import Security
import os

/// What the app remembers about a signed-in member between launches: the FORMA
/// cookies (the session) and who they belong to, so the member's own saved copy
/// can be opened offline. Both live in one Keychain item and are replaced
/// together.
struct StoredAccountSession: Codable, Equatable, Sendable {
  var cookies: FormaCookieJar
  var profile: AccountProfile?
}

protocol AccountSessionVault: Sendable {
  func load() -> StoredAccountSession?
  func save(_ session: StoredAccountSession) -> Bool
  func erase()
}

/// The Keychain item. `ThisDeviceOnly` keeps the session out of backups and off
/// other devices; `AfterFirstUnlock` lets a background refresh read it.
struct KeychainSessionVault: AccountSessionVault {
  private let service = "dev.raoufabedini.forma.account"
  let account: String

  private var identity: [CFString: Any] {
    [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
  }

  func load() -> StoredAccountSession? {
    var query = identity
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return try? JSONDecoder().decode(StoredAccountSession.self, from: data)
  }

  func save(_ session: StoredAccountSession) -> Bool {
    guard let data = try? JSONEncoder().encode(session) else { return false }
    let update = SecItemUpdate(identity as CFDictionary, [kSecValueData: data] as CFDictionary)
    if update == errSecSuccess { return true }
    guard update == errSecItemNotFound else { return false }
    var add = identity
    add[kSecValueData] = data
    add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    add[kSecAttrSynchronizable] = false
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
  }

  func erase() { SecItemDelete(identity as CFDictionary) }
}

/// For UI tests and previews: nothing touches the Keychain or survives launch.
final class MemorySessionVault: AccountSessionVault, @unchecked Sendable {
  private let lock = NSLock()
  private var session: StoredAccountSession?

  func load() -> StoredAccountSession? { lock.withLock { session } }
  func save(_ session: StoredAccountSession) -> Bool {
    lock.withLock { self.session = session }
    return true
  }
  func erase() { lock.withLock { session = nil } }
}

/// The app's cookie jar: FORMA cookies only, kept in the Keychain, never in
/// `HTTPCookieStorage`. The `URLSession` that uses it has cookie handling turned
/// off, so nothing else can read or add to it.
actor CookieJar {
  struct Snapshot: Sendable {
    let generation: UInt64
    let header: String?
  }

  private var cookies: FormaCookieJar
  private var generation: UInt64 = 0
  private(set) var profile: AccountProfile?
  private let vault: any AccountSessionVault
  /// A file in the app's data directory, written once a member is signed in.
  /// The Keychain survives deleting the app; this file does not, so a session
  /// found without it belongs to an earlier install and is dropped.
  private let installMarker: URL?
  private static let log = Logger(subsystem: "dev.raoufabedini.forma", category: "account")

  init(vault: any AccountSessionVault, installMarker: URL?) {
    self.vault = vault
    self.installMarker = installMarker
    if let stored = vault.load(), stored.profile != nil,
      installMarker.map({ FileManager.default.fileExists(atPath: $0.path) }) ?? true
    {
      var restored = stored.cookies
      restored.pruneExpired()
      cookies = restored
      profile = stored.profile
    } else {
      // A challenge cookie without a profile, or a session from before a
      // reinstall, is not a sign-in.
      cookies = FormaCookieJar()
      vault.erase()
    }
  }

  var hasSession: Bool { cookies.contains(suffix: "session_token") }

  func header() -> String? { cookies.cookieHeader() }

  func snapshot() -> Snapshot {
    Snapshot(generation: generation, header: cookies.cookieHeader())
  }

  /// Clearing a session invalidates every request sent with its cookies.
  /// Check inside the jar actor as well as in the HTTP client: an actor hop
  /// can otherwise let sign-out overtake the client's response check.
  func absorb(_ response: HTTPURLResponse, for snapshot: Snapshot) -> Bool {
    guard snapshot.generation == generation else { return false }
    absorb(response)
    return true
  }

  /// Applies the response's `Set-Cookie` headers (a deletion removes the cookie).
  func absorb(_ response: HTTPURLResponse) {
    guard let header = response.value(forHTTPHeaderField: "Set-Cookie") else { return }
    cookies.absorb(combinedHeader: header)
    persist()
  }

  func setProfile(_ profile: AccountProfile?) {
    self.profile = profile
    persist()
  }

  /// Signing out, or the account ending the session.
  func clear() {
    generation &+= 1
    cookies.removeAll()
    profile = nil
    vault.erase()
    if let installMarker { try? FileManager.default.removeItem(at: installMarker) }
  }

  private func persist() {
    cookies.pruneExpired()
    // The challenge cookie of a sign-in in progress is held in memory only.
    guard cookies.contains(suffix: "session_token") else {
      vault.erase()
      return
    }
    // The profile follows the first session check; until then nothing is saved.
    guard let profile else { return }
    if vault.save(StoredAccountSession(cookies: cookies, profile: profile)) {
      if let installMarker, !FileManager.default.fileExists(atPath: installMarker.path) {
        FileManager.default.createFile(atPath: installMarker.path, contents: Data())
      }
    } else {
      // The session still works for this launch; it will not be remembered.
      Self.log.error("The session could not be saved to the Keychain.")
    }
  }
}
