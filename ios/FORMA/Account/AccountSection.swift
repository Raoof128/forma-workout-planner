import FORMACore
import SwiftUI

/// The Account section at the top of You. Signed out it offers Sign in and
/// Create account; signed in it shows who you are, how syncing is going and the
/// way to the account screens.
struct AccountSection: View {
  @Environment(AppModel.self) private var model
  @Binding var authMode: AuthMode?

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
    if let notice = account.notice {
      FormNotice(text: notice, tone: .info, identifier: "account-notice")
    }
    Button("Sign in") { authMode = .signIn }
      .buttonStyle(PrimaryButtonStyle())
      .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
      .accessibilityIdentifier("account-sign-in")
    Button("Create account") { authMode = .signUp }
      .accessibilityIdentifier("account-create")
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
      Label("Email not verified", systemImage: "envelope.badge")
        .foregroundStyle(FormaTheme.primary)
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

  var body: some View {
    VStack(spacing: 24) {
      switch gate {
      case .loading:
        FormaLoadingMark().frame(width: 64, height: 64)
        ProgressView("Loading your training from your account…")
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
          Button("Sign out", role: .destructive) {
            signingOut = true
            Task {
              _ = try? await model.account.signOut()
              signingOut = false
            }
          }
          .disabled(signingOut)
          .accessibilityIdentifier("account-gate-sign-out")
        }
      }
    }
    .padding()
    .accessibilityIdentifier("account-gate")
  }
}
