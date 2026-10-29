import FORMACore
import SwiftUI

/// Where your data lives, signing out, and deleting the account.
struct AccountPrivacyView: View {
  @Environment(AppModel.self) private var model
  @State private var confirmSignOut = false
  @State private var signingOut = false
  @State private var deleteOpen = false
  @State private var error: String?

  private var origin: URL? { model.account.origin }

  var body: some View {
    Form {
      Section {
        AdaptiveRow {
          Label("Cloud workout storage", systemImage: "icloud")
        } trailing: {
          Text((model.syncDisplay?.title ?? "").uppercased())
            .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.accent)
        }
        Text(
          "Your workout data is attached to your signed-in account. Signing out does not delete it. Account deletion removes active account data; operational backups follow the service retention schedule."
        )
        .font(.subheadline)
        Text(
          "This iPhone keeps a saved copy of your training so FORMA works offline. Signing out leaves that copy on this iPhone, ready for next time. Choose “Sign out and remove from this iPhone” to delete it. If some changes haven’t been sent yet, FORMA keeps the copy so they aren’t lost, and you can remove it from the Account section after signing out."
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      } header: {
        Text("Your data, your call")
      }

      Section {
        NavigationLink {
          NativePrivacyView()
        } label: {
          Label("Privacy notice for this app", systemImage: "hand.raised")
        }
        if let origin {
          Link(destination: accountWebsite(origin, fragment: "privacy")) {
            Label("Privacy Policy (website)", systemImage: "safari")
          }
          Link(destination: accountWebsite(origin, fragment: "terms")) {
            Label("Terms of Use (website)", systemImage: "safari")
          }
        }
      }

      Section {
        if let error { FormNotice(text: error, tone: .error) }
        Button {
          confirmSignOut = true
        } label: {
          HStack {
            Text("Sign out")
            if signingOut { ProgressView() }
          }
        }
        .disabled(signingOut)
        .accessibilityIdentifier("account-sign-out")
      } header: {
        Text("Sign out")
      } footer: {
        Text("End this session on this iPhone.")
      }

      Section {
        if let requestedAt = model.account.deletionRequestedAt {
          FormNotice(
            text:
              "Deletion requested \(Self.time(requestedAt)). Open the link in the email we sent to finish. Until you do, your account stays active.",
            tone: .info, identifier: "account-delete-pending")
        } else {
          Text(
            "You’ll need to confirm your password and type DELETE. We’ll email a confirmation link; your account remains active until you use it."
          )
          .font(.subheadline)
        }
        Button(
          model.account.deletionRequestedAt == nil
            ? "Review account deletion" : "Send the confirmation email again",
          role: .destructive
        ) { deleteOpen = true }
        .accessibilityIdentifier("account-delete-review")
      } header: {
        Text("Delete account")
      } footer: {
        Text("Request removal of your account and active workout data.")
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Privacy & account").navigationBarTitleDisplayMode(.inline)
    .task { model.account.refreshDeletionRequest() }
    .confirmationDialog(
      "Sign out of FORMA?", isPresented: $confirmSignOut, titleVisibility: .visible
    ) {
      Button("Sign out") { Task { await signOut(removing: false) } }
        .accessibilityIdentifier("account-sign-out-confirm")
      Button("Sign out and remove from this iPhone", role: .destructive) {
        Task { await signOut(removing: true) }
      }
      .accessibilityIdentifier("account-sign-out-remove")
    } message: {
      Text(
        removalMessage
      )
    }
    .sheet(isPresented: $deleteOpen) { DeleteAccountSheet().protectWidgetNavigation() }
  }

  /// What the sign-out dialog promises, which depends on whether anything is
  /// still waiting to be sent. Removal only happens when nothing is.
  private var removalMessage: String {
    let base =
      "Your training stays in your account. This iPhone returns to its own on-device training."
    if case .idle = model.syncStatus {
      return base
        + " Choosing “Sign out and remove from this iPhone” also deletes the saved copy here."
    }
    return base
      + " Some changes haven’t been sent yet, so FORMA keeps the saved copy on this iPhone even if you choose to remove it. After signing out you can remove it from the Account section."
  }

  private static func time(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .shortened)
  }

  private func signOut(removing: Bool) async {
    signingOut = true
    defer { signingOut = false }
    error = nil
    do {
      try await model.account.signOut(removeLocalCopy: removing)
      model.accountSucceeded()
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}

private struct DeleteAccountSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var password = ""
  @State private var phrase = ""
  @State private var working = false
  @State private var error: String?
  @State private var requested = false
  @State private var errorRevision = 0
  @FocusState private var focus: Field?

  private enum Field { case password, phrase }

  private var canDelete: Bool { !password.isEmpty && phrase == "DELETE" }

  /// Everything the account holds, per the privacy notice.
  private static let consequences = [
    "Your account: name, email address and password",
    "Every signed-in browser and device, and two-step verification",
    "Your cloud routines, workouts, history and weekly goal",
    "Your coach tokens",
  ]

  var body: some View {
    NavigationStack {
      Form {
        if requested {
          Section {
            FormNotice(
              text: "Confirmation email sent. Your account remains active until you confirm.",
              tone: .success, identifier: "account-delete-sent")
            Text(
              "Open the link in the email to finish. Until you do, you stay signed in and your training is unchanged."
            )
            .font(.subheadline)
          }
          Section { Button("Close") { dismiss() } }
        } else {
          Section {
            VStack(alignment: .leading, spacing: 6) {
              Text("Once you use the emailed link, this is permanent:")
                .font(.subheadline.weight(.semibold))
              ForEach(Self.consequences, id: \.self) { line in
                Label(line, systemImage: "minus.circle")
                  .labelStyle(.titleAndIcon).font(.subheadline)
              }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("account-delete-consequences")
          } header: {
            Text("What will be deleted")
          } footer: {
            Text(
              "Copies in backups are removed within 35 days. The training on this iPhone isn’t changed by this step. When your session ends, FORMA removes this account’s saved copy from the iPhone if everything was already sent; otherwise you can remove it from the Account section. Training you keep without an account stays."
            )
          }
          Section {
            SecureField("Confirm your password", text: $password)
              .textContentType(.password).accessibilityIdentifier("account-delete-password")
              .submitLabel(.next).focused($focus, equals: .password)
              .onSubmit { focus = .phrase }
            TextField("Type DELETE to confirm", text: $phrase)
              .textInputAutocapitalization(.characters).autocorrectionDisabled()
              .submitLabel(.go).focused($focus, equals: .phrase)
              .onSubmit { if canDelete { Task { await request() } } }
              .accessibilityIdentifier("account-delete-phrase")
            if let error {
              FormNotice(text: error, tone: .error, revision: errorRevision)
            }
          } footer: {
            Text(
              "You’ll need to confirm your password and type DELETE. We’ll email a confirmation link; your account remains active until you use it."
            )
          }
          Section {
            Button(role: .destructive) {
              Task { await request() }
            } label: {
              HStack {
                Text("Delete account")
                if working { ProgressView() }
              }
            }
            .disabled(working || !canDelete)
            .accessibilityHint(
              password.isEmpty
                ? "Enter your password first." : phrase != "DELETE" ? "Type DELETE first." : ""
            )
            .accessibilityIdentifier("account-delete-submit")
          }
        }
      }
      .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(requested ? "Close" : "Cancel") { dismiss() }.disabled(working)
        }
      }
    }
    .interactiveDismissDisabled(working)
  }

  private func request() async {
    guard canDelete, !working else { return }
    working = true
    defer { working = false }
    error = nil
    let secret = password
    do {
      try await model.account.call { try await $0.deleteAccount(password: secret) }
      password = ""
      // Remembered so a session that then ends can be told apart from an
      // ordinary expiry, and so Privacy shows that a request is outstanding.
      model.account.recordDeletionRequest()
      requested = true
      model.accountSucceeded()
    } catch {
      if error.rejectsCredentials { password = "" }
      self.error = error.accountMessage
      errorRevision += 1
      model.haptic(error.accountHaptic)
    }
  }
}
