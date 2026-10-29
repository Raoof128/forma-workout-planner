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
  /// Resending the verification email reports under its own button.
  @State private var resendMessage: String?
  @State private var resendError: String?
  @State private var resending = false
  @State private var noticeRevision = 0
  /// The address a change was last requested for, until the profile changes.
  @State private var pendingEmail: String?

  var body: some View {
    let profile = model.account.profile
    Form {
      Section {
        LabeledContent("Display name", value: model.workspace?.profile.name ?? profile?.name ?? "")
        LabeledContent(
          "Weekly goal", value: Self.workouts(model.workspace?.profile.goal ?? 4))
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
        if let pendingEmail, pendingEmail != profile?.email {
          Label(
            "Change to \(pendingEmail) requested. Approve it from this inbox, then verify the new address.",
            systemImage: "clock"
          )
          .font(.footnote).foregroundStyle(FormaTheme.secondary)
          .accessibilityIdentifier("account-email-pending")
        }
        if let profile {
          if profile.emailVerified {
            Label("Email verified", systemImage: "checkmark.seal").foregroundStyle(
              FormaTheme.accent)
          } else {
            Label("Email not verified", systemImage: "envelope.badge")
            Button {
              Task { await resend(profile.email) }
            } label: {
              HStack(spacing: 8) {
                Text("Resend email")
                if resending { ProgressView() }
              }
            }
            .disabled(working || resending)
            .accessibilityIdentifier("account-resend")
            if let resendMessage {
              FormNotice(
                text: resendMessage, tone: .success, identifier: "account-resend-message",
                revision: noticeRevision)
            }
            if let resendError {
              FormNotice(
                text: resendError, tone: .error, identifier: "account-resend-error",
                revision: noticeRevision)
            }
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
            Text("Change email address")
            if working { ProgressView() }
          }
        }
        .disabled(working || !looksLikeEmail)
        .accessibilityIdentifier("account-change-email")
        if let message { FormNotice(text: message, tone: .success, revision: noticeRevision) }
        if let error { FormNotice(text: error, tone: .error, revision: noticeRevision) }
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

  /// "1 workout", "4 workouts".
  static func workouts(_ count: Int) -> String {
    "\(count) \(count == 1 ? "workout" : "workouts")"
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
        "We sent a request to \(model.account.profile?.email ?? "your current inbox") for the change to \(address). Approve it there, then verify the new address. Your current email stays in use until both steps are complete."
      noticeRevision += 1
      pendingEmail = address
      newEmail = ""
      model.accountSucceeded(.accountSent)
      await model.account.refreshSession()
    } catch {
      self.error = error.accountMessage
      noticeRevision += 1
      model.haptic(error.accountHaptic)
    }
  }

  private func resend(_ address: String) async {
    resending = true
    defer { resending = false }
    resendMessage = nil
    resendError = nil
    do {
      try await model.account.call { try await $0.resendVerification(email: address) }
      resendMessage = "Verification email sent to \(address)."
      noticeRevision += 1
      model.accountSucceeded(.accountSent)
    } catch {
      resendError = "Verification email could not be sent. \(error.accountMessage)"
      noticeRevision += 1
      model.haptic(error.accountHaptic)
    }
  }
}
