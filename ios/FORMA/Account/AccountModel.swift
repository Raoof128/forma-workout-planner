import FORMACore
import Foundation
import Observation
import SwiftUI

enum AccountSignOutReason: Equatable {
  case requested
  /// The account ended the session (expired, revoked from the website, or the
  /// 30-day limit).
  case sessionEnded
  /// The session now belongs to a different member.
  case accountChanged
  /// The member asked to delete the account and the session then ended, or the
  /// account said the account is gone.
  case accountDeleted
}

extension AccountFailure {
  /// Why a failure that ends the session ended it.
  var signOutReason: AccountSignOutReason {
    if kind == .accountChanged { return .accountChanged }
    return code == "account_deleted" ? .accountDeleted : .sessionEnded
  }
}

/// What the root view says when the account signs the member out without being
/// asked: an alert that names the cause, says what happens to the training and
/// the workout that may have been open, and offers Sign in.
struct AccountInterruption: Equatable, Identifiable, Sendable {
  let id: UInt64
  let title: String
  let message: String
  let signInTitle = "Sign in"
  let dismissTitle = "Not now"

  /// `removedCopy`: the saved copy of the member's training was removed from
  /// this iPhone as part of the sign-out.
  static func make(
    id: UInt64, reason: AccountSignOutReason, hadWorkout: Bool, removedCopy: Bool
  ) -> AccountInterruption {
    switch reason {
    case .requested, .sessionEnded, .accountChanged:
      let cause =
        reason == .accountChanged
        ? "This session no longer matched your account."
        : "Your FORMA session ended. This happens after 30 days, or when you sign out from another device or the website."
      let next =
        hadWorkout
        ? "Your workout in progress is saved on this iPhone. Sign in to the same account to pick it up where you left off."
        : "Your training is still saved on this iPhone. Sign in to keep syncing."
      return AccountInterruption(
        id: id, title: "You’ve been signed out", message: "\(cause) \(next)")
    case .accountDeleted:
      let outcome =
        removedCopy
        ? "The saved copy of its training was removed from this iPhone."
          + (hadWorkout ? " That included the workout you had open." : "")
        : "Some changes hadn’t reached the account, so this iPhone still has a saved copy. You can remove it from the Account section."
      return AccountInterruption(
        id: id, title: "Your account was signed out",
        message:
          "You asked to delete your account and this session has ended, so the deletion has probably gone through. \(outcome) Training you keep without an account is unchanged."
      )
    }
  }
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
  /// Set when the account signs the member out without being asked. The root
  /// view presents it as an alert; see `AccountInterruption`.
  private(set) var interruption: AccountInterruption?
  /// "Sign in" from the alert: the Account section opens the sign-in sheet.
  var requestedAuth: AuthMode?
  /// A signed-out iPhone still holds a member's saved training.
  var hasSavedAccountCopy = false
  /// When the member asked to delete the account from this iPhone, while that
  /// request can still be outstanding.
  private(set) var deletionRequestedAt: Date?
  @ObservationIgnored private var storage: AccountStorage?
  @ObservationIgnored private var interruptionCount: UInt64 = 0
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
    storage = environment?.storage
    isAvailable = environment != nil
    if let restored = environment?.restored { phase = .signedIn(restored) }
    refreshDeletionRequest()
  }

  // MARK: Interruptions and pending deletion

  func dismissInterruption() { interruption = nil }

  /// The alert's "Sign in".
  func signInFromInterruption() {
    interruption = nil
    requestedAuth = .signIn
  }

  private func present(_ reason: AccountSignOutReason, hadWorkout: Bool, removedCopy: Bool) {
    interruptionCount &+= 1
    let value = AccountInterruption.make(
      id: interruptionCount, reason: reason, hadWorkout: hadWorkout, removedCopy: removedCopy)
    interruption = value
    AccessibilityNotification.Announcement("\(value.title). \(value.message)").post()
  }

  func refreshDeletionRequest() {
    guard let storage, let profile else {
      deletionRequestedAt = nil
      return
    }
    deletionRequestedAt = AccountDeletionLedger.requestedAt(
      member: profile.id, in: storage.directory)
  }

  /// The delete-account request went out; remember it on this iPhone.
  func recordDeletionRequest() {
    guard let storage, let profile else { return }
    AccountDeletionLedger.record(member: profile.id, in: storage.directory)
    refreshDeletionRequest()
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
    interruption = nil
    hasSavedAccountCopy = false
    if let storage { AccountDeletionLedger.clear(member: signedIn.id, in: storage.directory) }
    phase = .signedIn(signedIn)
    refreshDeletionRequest()
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
        await sessionEnded(failure.signOutReason)
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
        await sessionEnded(failure.signOutReason)
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
    if unsent {
      parts.append(
        removeLocalCopy
          ? "This iPhone still has a saved copy because some changes hadn’t reached your account. They send when you sign in again, or you can remove the copy below."
          : "Some changes hadn’t reached your account. They stay saved on this iPhone and send when you sign in again."
      )
    }
    notice = parts.isEmpty ? nil : parts.joined(separator: " ")
    await app?.accountDidSignOut(removeLocalCopy: removeLocalCopy && !unsent)
    await app?.refreshSavedAccountCopy()
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
    await app?.refreshSavedAccountCopy()
  }

  /// The account (or the sync engine) says this sign-in is over. The open
  /// workout, if there is one, is already saved in the member's copy; the root
  /// view explains what happened instead of the screen changing silently.
  func sessionEnded(_ reason: AccountSignOutReason) async {
    guard case .signedIn(let leaving) = phase else { return }
    var reason = reason
    if reason == .sessionEnded, let storage,
      AccountDeletionLedger.requestedAt(member: leaving.id, in: storage.directory) != nil
    {
      reason = .accountDeleted
    }
    let hadWorkout = app?.workoutPresented == true || app?.workspace?.active != nil
    sessionGeneration &+= 1
    busy = true
    defer { busy = false }
    phase = .signedOut
    await client?.endLocalSession()
    // A deleted account's saved copy goes with it, unless it holds changes the
    // account never received.
    let removed = await app?.accountDidSignOut(removeLocalCopy: reason == .accountDeleted) ?? false
    if reason == .accountDeleted, let storage {
      AccountDeletionLedger.clear(member: leaving.id, in: storage.directory)
    }
    deletionRequestedAt = nil
    notice = Self.signedOutNotice(reason, removedCopy: removed)
    await app?.refreshSavedAccountCopy()
    if hadWorkout {
      // The workout screen is still closing; an alert raised now would be lost.
      Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(600))
        self?.present(reason, hadWorkout: true, removedCopy: removed)
      }
    } else {
      present(reason, hadWorkout: false, removedCopy: removed)
    }
  }

  /// The note under Account while signed out after a sign-out the member did
  /// not ask for.
  static func signedOutNotice(_ reason: AccountSignOutReason, removedCopy: Bool) -> String? {
    switch reason {
    case .requested: nil
    case .accountChanged:
      "This session no longer matched your account, so you’ve been signed out. Your training is still saved on this iPhone."
    case .sessionEnded:
      "Your FORMA session ended, so you’ve been signed out. Your training is still saved on this iPhone; sign in again to keep syncing."
    case .accountDeleted:
      removedCopy
        ? "You asked to delete your account and the session has ended. The saved copy of its training was removed from this iPhone."
        : "You asked to delete your account and the session has ended. Some changes hadn’t reached the account, so this iPhone still has a saved copy; you can remove it below."
    }
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
