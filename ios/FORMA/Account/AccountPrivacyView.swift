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
        HStack {
          Label("Cloud workout storage", systemImage: "icloud")
          Spacer()
          Text((model.syncDisplay?.title ?? "").uppercased())
            .font(.caption.weight(.bold)).foregroundStyle(FormaTheme.accent)
        }
        Text(
          "Your workout data is attached to your signed-in account. Signing out does not delete it. Account deletion removes active account data; operational backups follow the service retention schedule."
        )
        .font(.subheadline)
        Text(
          "This iPhone keeps a saved copy of your training so FORMA works offline. Signing out leaves that copy on this iPhone, ready for next time. Choose “Sign out and remove from this iPhone” to delete it."
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
        Text(
          "You’ll need to confirm your password and type DELETE. We’ll email a confirmation link; your account remains active until you use it."
        )
        .font(.subheadline)
        Button("Review account deletion", role: .destructive) { deleteOpen = true }
          .accessibilityIdentifier("account-delete-review")
      } header: {
        Text("Delete account")
      } footer: {
        Text("Request removal of your account and active workout data.")
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Privacy & account").navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      "Sign out of FORMA?", isPresented: $confirmSignOut, titleVisibility: .visible
    ) {
      Button("Sign out") { Task { await signOut(removing: false) } }
        .accessibilityIdentifier("account-sign-out-confirm")
      if case .idle = model.syncStatus {
        Button("Sign out and remove from this iPhone", role: .destructive) {
          Task { await signOut(removing: true) }
        }
        .accessibilityIdentifier("account-sign-out-remove")
      }
    } message: {
      Text(
        "Your training stays in your account. This iPhone returns to its own on-device training. Changes that haven’t been sent yet stay saved on this iPhone."
      )
    }
    .sheet(isPresented: $deleteOpen) { DeleteAccountSheet().protectWidgetNavigation() }
  }

  private func signOut(removing: Bool) async {
    signingOut = true
    defer { signingOut = false }
    error = nil
    do {
      try await model.account.signOut(removeLocalCopy: removing)
      model.haptic(.stopped)
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
          Section { Button("Done") { dismiss() } }
        } else {
          Section {
            SecureField("Confirm your password", text: $password)
              .textContentType(.password).accessibilityIdentifier("account-delete-password")
            TextField("Type DELETE to confirm", text: $phrase)
              .textInputAutocapitalization(.characters).autocorrectionDisabled()
              .accessibilityIdentifier("account-delete-phrase")
            if let error { FormNotice(text: error, tone: .error) }
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
            .disabled(working || password.isEmpty || phrase != "DELETE")
            .accessibilityIdentifier("account-delete-submit")
          }
        }
      }
      .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(working)
        }
      }
    }
    .interactiveDismissDisabled(working)
  }

  private func request() async {
    guard phrase == "DELETE" else { return }
    working = true
    defer { working = false }
    error = nil
    let secret = password
    do {
      try await model.account.call { try await $0.deleteAccount(password: secret) }
      password = ""
      requested = true
      model.haptic(.selected)
    } catch {
      password = ""
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}
