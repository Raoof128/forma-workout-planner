import FORMACore
import Foundation
import Observation

enum AccountSignOutReason: Equatable {
  case requested
  /// The account ended the session (expired, revoked from the website, or the
  /// 30-day limit).
  case sessionEnded
  /// The session now belongs to a different member.
  case accountChanged
}

/// Everything the app needs to talk to the account, made off the main thread at
/// launch.
struct AccountEnvironment: Sendable {
  let client: AccountClient
  let jar: CookieJar
  let storage: AccountStorage
  /// The member whose session was kept from the last launch.
  let restored: AccountProfile?

  static func make(directory: URL, testing: Bool) async -> AccountEnvironment? {
    guard let origin = AccountConfiguration.origin else { return nil }
    let storage = AccountStorage(root: directory, origin: origin)
    do {
      try FileManager.default.createDirectory(
        at: storage.directory, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.complete])
    } catch {
      return nil
    }
    let vault: any AccountSessionVault =
      testing
      ? MemorySessionVault() : KeychainSessionVault(account: storage.keychainAccount)
    let jar = CookieJar(
      vault: vault, installMarker: storage.directory.appendingPathComponent("account-session"))
    var restored = await jar.profile
    if restored != nil, !(await jar.hasSession) {
      // The cookies ran out while the app was closed.
      await jar.clear()
      restored = nil
    }
    return AccountEnvironment(
      client: AccountClient(origin: origin, jar: jar, member: restored?.id), jar: jar,
      storage: storage,
      restored: restored)
  }
}

/// Who is signed in, and the account actions the screens call. It owns no
/// training data: switching between the guest store and a member's store, and
/// everything about syncing, is `AppModel`'s (see AppModel+Account.swift).
@MainActor @Observable
final class AccountModel {
  enum Phase: Equatable {
    case signedOut
    /// The password was right; the account wants a code.
    case twoFactor(email: String)
    /// An account was just created and its address must be verified.
    case needsVerification(email: String)
    case signedIn(AccountProfile)
  }

  private(set) var phase: Phase = .signedOut
  /// A sign-in, sign-up or sign-out request is in flight.
  private(set) var busy = false
  /// Why the member was signed out, shown in the Account section until they
  /// sign in again.
  var notice: String?
  private(set) var isAvailable = false
  @ObservationIgnored private var client: AccountClient?
  @ObservationIgnored private var sessionGeneration: UInt64 = 0
  @ObservationIgnored weak var app: AppModel?

  var profile: AccountProfile? {
    if case .signedIn(let profile) = phase { profile } else { nil }
  }
  var isSignedIn: Bool { profile != nil }
  var origin: URL? { AccountConfiguration.origin }

  func attach(_ environment: AccountEnvironment?) {
    sessionGeneration &+= 1
    client = environment?.client
    isAvailable = environment != nil
    if let restored = environment?.restored { phase = .signedIn(restored) }
  }

  private var unavailable: AccountFailure {
    AccountFailure(kind: .rejected, message: "Accounts are not available in this build.")
  }

  // MARK: Signing up and in

  func signUp(name: String, email: String, password: String) async throws {
    guard let client else { throw unavailable }
    try await working {
      try await client.signUp(name: name, email: email, password: password)
    }
    phase = .needsVerification(email: email)
  }

  func signIn(email: String, password: String) async throws {
    guard let client else { throw unavailable }
    try requireNoWorkoutInProgress("signing in")
    try await working {
      self.sessionGeneration &+= 1
      switch try await client.signIn(email: email, password: password) {
      case .twoFactorRequired: self.phase = .twoFactor(email: email)
      case .signedIn: try await self.finishSignIn(client)
      }
    }
  }

  /// The code from the authenticator app, or one recovery code.
  func submitTwoFactor(code: String, recovery: Bool) async throws {
    guard let client else { throw unavailable }
    try await working {
      try await client.verifyTwoFactor(code: code, recovery: recovery)
      try await self.finishSignIn(client)
    }
  }

  private func finishSignIn(_ client: AccountClient) async throws {
    let signedIn: AccountProfile?
    do {
      signedIn = try await client.getSession()
    } catch {
      await client.endLocalSession()
      phase = .signedOut
      throw error
    }
    guard let signedIn else {
      await client.endLocalSession()
      phase = .signedOut
      throw AccountFailure(
        kind: .rejected, message: "We couldn’t finish signing you in. Please try again.")
    }
    guard app?.canSwitchAccount != false else {
      await client.signOut()
      phase = .signedOut
      throw workoutInProgress("signing in")
    }
    await client.adopt(signedIn)
    guard let app, await app.activateAccount(signedIn) else {
      await client.signOut()
      phase = .signedOut
      throw AccountFailure(
        kind: .rejected,
        message:
          "Your account’s training couldn’t be opened on this iPhone. Nothing was changed. Please try again."
      )
    }
    notice = nil
    phase = .signedIn(signedIn)
  }

  /// Leaving the sign-in sheet part-way: a half-finished challenge is dropped.
  func abandonPending() async {
    switch phase {
    case .twoFactor:
      await client?.endLocalSession()
      phase = .signedOut
    case .needsVerification: phase = .signedOut
    case .signedOut, .signedIn: break
    }
  }

  func resendVerification(email: String) async throws {
    guard let client else { throw unavailable }
    try await working { try await client.resendVerification(email: email) }
  }

  func requestPasswordReset(email: String) async throws {
    guard let client else { throw unavailable }
    try await working { try await client.requestPasswordReset(email: email) }
  }

  // MARK: Signed in

  /// Runs `operation` against the account. An answer that says the session is
  /// gone ends the sign-in here, as on the website.
  func call<T: Sendable>(_ operation: @Sendable (AccountClient) async throws -> T) async throws
    -> T
  {
    guard let client else { throw unavailable }
    let generation = sessionGeneration
    do {
      let result = try await operation(client)
      guard generation == sessionGeneration else { throw CancellationError() }
      return result
    } catch let failure as AccountFailure {
      if failure.endsSession, generation == sessionGeneration {
        await sessionEnded(failure.kind == .accountChanged ? .accountChanged : .sessionEnded)
      }
      throw failure
    }
  }

  /// Checks the session again (launch, foreground). A definite "no session"
  /// signs out; being offline changes nothing.
  func refreshSession() async {
    guard let client, case .signedIn(let current) = phase else { return }
    let generation = sessionGeneration
    do {
      let refreshed = try await client.getSession()
      guard generation == sessionGeneration, profile?.id == current.id else { return }
      guard let latest = refreshed else {
        await sessionEnded(.sessionEnded)
        return
      }
      guard latest.id == current.id else {
        await sessionEnded(.accountChanged)
        return
      }
      if latest != current {
        await client.adopt(latest)
        guard generation == sessionGeneration else { return }
        phase = .signedIn(latest)
      }
    } catch let failure as AccountFailure {
      if failure.endsSession, generation == sessionGeneration {
        await sessionEnded(failure.kind == .accountChanged ? .accountChanged : .sessionEnded)
      }
    } catch {}
  }

  /// Ends this sign-in on this iPhone. `removeLocalCopy` also deletes the
  /// member's saved copy of their training from the device.
  @discardableResult
  func signOut(removeLocalCopy: Bool = false) async throws -> Bool {
    guard let client, case .signedIn = phase else { return true }
    try requireNoWorkoutInProgress("signing out")
    guard !busy else { throw actionInProgress }
    busy = true
    defer { busy = false }
    sessionGeneration &+= 1
    let unsent = await app?.settleBeforeSignOut() == false
    let confirmed = await client.signOut()
    phase = .signedOut
    var parts: [String] = []
    if !confirmed {
      parts.append(
        "Signed out on this iPhone. FORMA couldn’t be reached to end the session there; you can sign it out from Security on the website."
      )
    }
    if unsent && !removeLocalCopy {
      parts.append(
        "Some changes hadn’t reached your account. They stay saved on this iPhone and send when you sign in again."
      )
    }
    notice = parts.isEmpty ? nil : parts.joined(separator: " ")
    await app?.accountDidSignOut(removeLocalCopy: removeLocalCopy && !unsent)
    return confirmed
  }

  /// "Sign out everywhere": the account ends every session, this one included.
  func signOutEverywhere() async throws {
    guard client != nil, case .signedIn = phase else { return }
    try requireNoWorkoutInProgress("signing out")
    guard !busy else { throw actionInProgress }
    busy = true
    defer { busy = false }
    sessionGeneration &+= 1
    try await call { try await $0.signOutEverywhere() }
    phase = .signedOut
    notice = nil
    await app?.accountDidSignOut(removeLocalCopy: false)
  }

  /// The account (or the sync engine) says this sign-in is over.
  func sessionEnded(_ reason: AccountSignOutReason) async {
    guard case .signedIn = phase else { return }
    sessionGeneration &+= 1
    busy = true
    defer { busy = false }
    phase = .signedOut
    await client?.endLocalSession()
    notice =
      reason == .accountChanged
      ? "This session no longer matched your account, so you’ve been signed out. Your training is still saved on this iPhone."
      : "Your FORMA session ended, so you’ve been signed out. Your training is still saved on this iPhone; sign in again to keep syncing."
    await app?.accountDidSignOut(removeLocalCopy: false)
  }

  // MARK: Plumbing

  private func working(_ body: () async throws -> Void) async throws {
    guard !busy else { throw actionInProgress }
    busy = true
    defer { busy = false }
    try await body()
  }

  private var actionInProgress: AccountFailure {
    AccountFailure(
      kind: .rejected,
      message: "Another account action is still finishing. Try again in a moment.")
  }

  private func workoutInProgress(_ doing: String) -> AccountFailure {
    AccountFailure(
      kind: .rejected,
      message: "Finish or discard your workout in progress before \(doing).")
  }

  private func requireNoWorkoutInProgress(_ doing: String) throws {
    if app?.canSwitchAccount == false { throw workoutInProgress(doing) }
  }
}
