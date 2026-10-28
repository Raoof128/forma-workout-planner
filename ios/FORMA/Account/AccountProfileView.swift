import FORMACore
import SwiftUI

/// Name, weekly goal, and the email address.
struct AccountProfileView: View {
  @Environment(AppModel.self) private var model
  @State private var editing = false
  @State private var newEmail = ""
  @State private var working = false
  @State private var message: String?
  @State private var error: String?

  var body: some View {
    let profile = model.account.profile
    Form {
      Section {
        LabeledContent("Display name", value: model.workspace?.profile.name ?? profile?.name ?? "")
        LabeledContent(
          "Weekly goal", value: "\(model.workspace?.profile.goal ?? 4) workouts")
        Button("Edit name & weekly goal") { editing = true }
          .accessibilityIdentifier("account-edit-profile")
        if let since = profile?.memberSince {
          LabeledContent("Member since", value: AccountDates.label(since))
        }
      } header: {
        Text("Profile details")
      } footer: {
        Text("Weights use kg. Dates use Sydney time.")
      }

      Section {
        LabeledContent("Email", value: profile?.email ?? "")
        if let profile {
          if profile.emailVerified {
            Label("Email verified", systemImage: "checkmark.seal").foregroundStyle(
              FormaTheme.accent)
          } else {
            Label("Email not verified", systemImage: "envelope.badge")
            Button("Resend email") { Task { await resend(profile.email) } }
              .disabled(working)
              .accessibilityIdentifier("account-resend")
            Text("Verify your email to keep account recovery available.").font(.footnote)
              .foregroundStyle(FormaTheme.secondary)
          }
        }
      }

      Section {
        TextField("New email address", text: $newEmail)
          .textContentType(.emailAddress).keyboardType(.emailAddress)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("account-new-email")
        Button {
          Task { await changeEmail() }
        } label: {
          HStack {
            Text("Send verification")
            if working { ProgressView() }
          }
        }
        .disabled(working || !looksLikeEmail)
        .accessibilityIdentifier("account-change-email")
        if let message { FormNotice(text: message, tone: .success) }
        if let error { FormNotice(text: error, tone: .error) }
      } header: {
        Text("Change email address")
      } footer: {
        Text(
          "Approve the request from your current inbox, then verify the new address. Your current email stays in use until both steps are complete."
        )
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .sheet(isPresented: $editing) { ProfileEditor().protectWidgetNavigation() }
  }

  private var looksLikeEmail: Bool {
    let trimmed = newEmail.trimmingCharacters(in: .whitespaces)
    return trimmed.contains("@") && trimmed.contains(".") && !trimmed.contains(" ")
  }

  private func changeEmail() async {
    working = true
    defer { working = false }
    message = nil
    error = nil
    let address = newEmail.trimmingCharacters(in: .whitespaces)
    do {
      try await model.account.call { try await $0.changeEmail(to: address) }
      message =
        "Approve this request from your current inbox, then verify the new address. Your current email stays in use until both steps are complete."
      newEmail = ""
      model.haptic(.selected)
      await model.account.refreshSession()
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func resend(_ address: String) async {
    working = true
    defer { working = false }
    message = nil
    error = nil
    do {
      try await model.account.call { try await $0.resendVerification(email: address) }
      message = "Verification email sent."
      model.haptic(.selected)
    } catch {
      self.error = "Verification email could not be sent. \(error.accountMessage)"
      model.haptic(error.accountHaptic)
    }
  }
}
