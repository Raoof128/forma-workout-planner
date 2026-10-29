import FORMACore
import SwiftUI

/// The Account section at the top of You. Signed out it offers Sign in and
/// Create account; signed in it shows who you are, how syncing is going and the
/// way to the account screens.
struct AccountSection: View {
  @Environment(AppModel.self) private var model
  @Binding var authMode: AuthMode?
  @State private var confirmRemoval = false
  @State private var removing = false
  @State private var removalError: String?

  var body: some View {
    let account = model.account
    if account.isAvailable {
      Section {
        if let profile = account.profile {
          signedIn(profile)
        } else {
          signedOut(account)
        }
      } header: {
        Text("Account")
      } footer: {
        if account.profile == nil {
          Text(
            "FORMA works without an account. Your training stays on this iPhone until you sign in.")
        }
      }
    }
  }

  // MARK: Signed out

  @ViewBuilder
  private func signedOut(_ account: AccountModel) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Keep your training with you").font(.headline)
      Text(
        "Sign in with your FORMA account to see your routines and workouts from the website here, and what you log here there."
      )
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
    .padding(.vertical, 4)
    .task { await model.refreshSavedAccountCopy() }
    if let notice = account.notice {
      FormNotice(text: notice, tone: .info, identifier: "account-notice")
    }
    Button("Sign in") { authMode = .signIn }
      .buttonStyle(PrimaryButtonStyle())
      .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
      .accessibilityIdentifier("account-sign-in")
      // "Sign in" on the signed-out alert asks for this sheet.
      .onChange(of: account.requestedAuth, initial: true) { _, requested in
        guard let requested else { return }
        authMode = requested
        account.requestedAuth = nil
      }
    Button("Create account") { authMode = .signUp }
      .accessibilityIdentifier("account-create")
    if account.hasSavedAccountCopy { savedCopy }
  }

  /// After a sign-out the member's training stays on this iPhone. This is the
  /// way to delete it without signing in again, which a deleted account
  /// cannot do.
  @ViewBuilder
  private var savedCopy: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Account training saved on this iPhone").font(.headline)
      Text(
        "This iPhone still holds the routines and workouts from the account you signed out of. Signing in again picks them up. Remove them if you don’t want them kept here."
      )
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
    .padding(.vertical, 4)
    if let removalError {
      FormNotice(text: removalError, tone: .error, identifier: "account-remove-error")
    }
    Button(role: .destructive) {
      confirmRemoval = true
    } label: {
      HStack {
        Text("Remove this account’s training from this iPhone")
        if removing { ProgressView() }
      }
    }
    .disabled(removing)
    .accessibilityIdentifier("account-remove-saved-copy")
    .confirmationDialog(
      "Remove this account’s training from this iPhone?", isPresented: $confirmRemoval,
      titleVisibility: .visible
    ) {
      Button("Remove from this iPhone", role: .destructive) { Task { await removeSavedCopy() } }
        .accessibilityIdentifier("account-remove-saved-copy-confirm")
    } message: {
      Text(
        "This deletes the routines, workouts and any workout in progress that this iPhone kept for that account. Changes that never reached the account are lost. The account itself, and the training you keep without an account, are not affected."
      )
    }
  }

  private func removeSavedCopy() async {
    removing = true
    defer { removing = false }
    removalError = nil
    do {
      try await model.removeSavedAccountCopies()
      model.account.notice = nil
      AccessibilityNotification.Announcement("Removed from this iPhone.").post()
    } catch {
      removalError = error.accountMessage
      model.haptic(.failed)
    }
  }

  // MARK: Signed in

  @ViewBuilder
  private func signedIn(_ profile: AccountProfile) -> some View {
    HStack(spacing: 14) {
      Text(Self.initials(profile.name))
        .font(.headline).foregroundStyle(FormaTheme.ink)
        .frame(width: 44, height: 44).background(FormaTheme.lime, in: Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(model.workspace?.profile.name ?? profile.name).font(.headline)
        Text(profile.email).font(.subheadline).foregroundStyle(FormaTheme.secondary)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("account-header")

    if let display = model.syncDisplay {
      NavigationLink {
        SyncDetailsView()
      } label: {
        LabeledContent {
          Text(display.title).foregroundStyle(
            display.needsAttention ? FormaTheme.error : FormaTheme.secondary)
        } label: {
          Label("Sync", systemImage: display.symbol)
        }
      }
      .accessibilityIdentifier("account-sync-status")
    }
    if !profile.emailVerified {
      NavigationLink {
        AccountProfileView()
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Label("Email not verified", systemImage: "envelope.badge")
            .foregroundStyle(FormaTheme.primary)
          Text("Open Profile to send the verification email again.")
            .font(.footnote).foregroundStyle(FormaTheme.secondary)
        }
      }
      .accessibilityIdentifier("account-verify-email")
    }
    NavigationLink {
      AccountProfileView()
    } label: {
      Label("Profile", systemImage: "person.crop.circle")
    }
    .accessibilityIdentifier("account-profile")
    NavigationLink {
      AccountSecurityView()
    } label: {
      Label("Security", systemImage: "lock.shield")
    }
    .accessibilityIdentifier("account-security")
    NavigationLink {
      TrainingDataView()
    } label: {
      Label("Training data", systemImage: "externaldrive.badge.icloud")
    }
    .accessibilityIdentifier("account-training-data")
    NavigationLink {
      AccountPrivacyView()
    } label: {
      Label("Privacy & account", systemImage: "hand.raised")
    }
    .accessibilityIdentifier("account-privacy")
  }

  private static func initials(_ name: String) -> String {
    let letters = name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap { $0.first }
    return letters.isEmpty ? "F" : String(letters).uppercased()
  }
}

/// Today and You show this when syncing needs attention: offline, waiting,
/// conflicting or failed. Saved and saving are quiet.
struct SyncBanner: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if let display = model.syncDisplay, display.needsAttention {
      NavigationLink {
        SyncDetailsView()
      } label: {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: display.symbol).font(.title3)
            .foregroundStyle(display == .conflict ? FormaTheme.error : FormaTheme.accent)
          VStack(alignment: .leading, spacing: 2) {
            Text(display.title).font(.subheadline.weight(.semibold)).foregroundStyle(
              FormaTheme.primary)
            Text(display.detail).font(.footnote).foregroundStyle(FormaTheme.secondary)
              .multilineTextAlignment(.leading)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.footnote).foregroundStyle(FormaTheme.secondary)
        }
        .padding(14)
        .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(FormaTheme.line, lineWidth: 1) }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("sync-banner")
      .accessibilityLabel("\(display.title). \(display.detail)")
      .accessibilityHint("Opens sync details")
    }
  }
}

/// Shown instead of the tabs while a signed-in member's copy is not on this
/// iPhone yet (first sign-in on a new device, or a reinstall).
struct AccountGateView: View {
  @Environment(AppModel.self) private var model
  let gate: AccountGate
  @State private var signingOut = false
  @State private var confirmSignOut = false
  @State private var signOutError: String?
  /// The load is taking long enough to offer a way out.
  @State private var slow = false

  var body: some View {
    VStack(spacing: 24) {
      switch gate {
      case .loading:
        FormaLoadingMark().frame(width: 64, height: 64)
        ProgressView("Loading your training from your account…")
        if slow {
          VStack(spacing: 12) {
            Text(
              "This is taking longer than usual. You can keep waiting, try again, or sign out and use FORMA on this iPhone without an account."
            )
            .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            .multilineTextAlignment(.center)
            Button("Try again") { Task { await model.retryAccountLoad() } }
              .buttonStyle(PrimaryButtonStyle())
              .accessibilityIdentifier("account-gate-retry")
            signOutControls
          }
        }
      case .unavailable(let message):
        ContentUnavailableView {
          Label("Cloud data is unavailable", systemImage: "icloud.slash")
        } description: {
          Text(
            "\(message) You’re still signed in. Retry the secure connection to load your routines and history."
          )
        } actions: {
          Button("Retry connection") { Task { await model.retryAccountLoad() } }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("account-gate-retry")
          signOutControls
        }
      }
    }
    .padding()
    .accessibilityIdentifier("account-gate")
    .task(id: gate) {
      slow = false
      guard gate == .loading else { return }
      try? await Task.sleep(for: .seconds(8))
      if !Task.isCancelled { slow = true }
    }
    .confirmationDialog(
      "Sign out of FORMA?", isPresented: $confirmSignOut, titleVisibility: .visible
    ) {
      Button("Sign out", role: .destructive) { Task { await signOut() } }
        .accessibilityIdentifier("account-gate-sign-out-confirm")
    } message: {
      Text(
        "Your training stays in your account. This iPhone goes back to its own on-device training."
      )
    }
  }

  @ViewBuilder
  private var signOutControls: some View {
    if let signOutError {
      FormNotice(text: signOutError, tone: .error, identifier: "account-gate-error")
    }
    Button("Sign out", role: .destructive) { confirmSignOut = true }
      .disabled(signingOut)
      .accessibilityIdentifier("account-gate-sign-out")
  }

  private func signOut() async {
    signingOut = true
    defer { signingOut = false }
    signOutError = nil
    do {
      try await model.account.signOut()
    } catch {
      signOutError = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}
