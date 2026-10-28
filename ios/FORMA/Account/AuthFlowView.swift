import FORMACore
import SwiftUI

enum AuthMode: String, Identifiable {
  case signIn, signUp
  var id: String { rawValue }
}

/// Sign in, create an account, reset a password, answer the two-step challenge
/// and wait for the verification email. The words are the website's.
struct AuthFlowView: View {
  private enum Screen { case signIn, signUp, forgot }
  private enum Field { case name, email, password, code }

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.formaMotion) private var motion
  @State private var screen: Screen
  @State private var name = ""
  @State private var email = ""
  @State private var password = ""
  @State private var ageConsent = false
  @State private var dataConsent = false
  @State private var code = ""
  @State private var useRecoveryCode = false
  @State private var error: String?
  @State private var message: String?
  @State private var sending = false
  @FocusState private var focus: Field?

  init(mode: AuthMode) {
    _screen = State(initialValue: mode == .signUp ? .signUp : .signIn)
  }

  private var account: AccountModel { model.account }
  private var origin: URL? { account.origin }

  var body: some View {
    NavigationStack {
      Group {
        switch account.phase {
        case .twoFactor: twoFactorForm
        case .needsVerification(let address): checkEmail(address)
        default: credentialsForm
        }
      }
      .scrollContentBackground(.hidden).background(FormaTheme.canvas)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Not now") { dismiss() }
            .disabled(account.busy)
            .accessibilityIdentifier("account-cancel")
        }
      }
    }
    .interactiveDismissDisabled(account.busy)
    .onChange(of: account.isSignedIn) { _, signedIn in
      if signedIn { dismiss() }
    }
    .onDisappear { Task { await account.abandonPending() } }
  }

  // MARK: Sign in, sign up, forgot

  private var title: String {
    switch screen {
    case .signIn: "Welcome back"
    case .signUp: "Create your account"
    case .forgot: "Reset your password"
    }
  }

  private var subtitle: String {
    switch screen {
    case .signIn: "Pick up where your training left off."
    case .signUp: "One account for your routines, sessions and progress."
    case .forgot: "We’ll send a secure reset link if this address is registered."
    }
  }

  private var passwordIsLongEnough: Bool { password.count >= 15 }
  private var emailLooksRight: Bool {
    let trimmed = email.trimmingCharacters(in: .whitespaces)
    return trimmed.contains("@") && trimmed.contains(".") && !trimmed.contains(" ")
  }

  private var canSubmit: Bool {
    guard !account.busy, emailLooksRight else { return false }
    switch screen {
    case .signIn: return !password.isEmpty
    case .signUp:
      return !name.trimmingCharacters(in: .whitespaces).isEmpty && passwordIsLongEnough
        && ageConsent && dataConsent
    case .forgot: return true
    }
  }

  private var credentialsForm: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("FORMA MEMBER ACCESS").font(.caption.weight(.bold)).tracking(2)
            .foregroundStyle(FormaTheme.secondary)
          Text(title).font(.largeTitle.bold()).foregroundStyle(FormaTheme.primary)
            .accessibilityAddTraits(.isHeader)
          Text(subtitle).font(.subheadline).foregroundStyle(FormaTheme.secondary)
        }
        .padding(.vertical, 8).listRowBackground(Color.clear)
        if let error { FormNotice(text: error, tone: .error, identifier: "account-error") }
        if let message { FormNotice(text: message, tone: .success, identifier: "account-message") }
      }

      Section {
        if screen == .signUp {
          TextField("Display name", text: $name)
            .textContentType(.name).submitLabel(.next).focused($focus, equals: .name)
            .onChange(of: name) { _, value in
              if value.count > 50 { name = String(value.prefix(50)) }
            }
            .onSubmit { focus = .email }
            .accessibilityIdentifier("account-name")
        }
        TextField("Email address", text: $email)
          .textContentType(.emailAddress).keyboardType(.emailAddress)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .submitLabel(screen == .forgot ? .send : .next).focused($focus, equals: .email)
          .onSubmit { if screen == .forgot { Task { await submit() } } else { focus = .password } }
          .accessibilityIdentifier("account-email")
        if screen != .forgot {
          SecureField("Password", text: $password)
            .textContentType(screen == .signIn ? .password : .newPassword)
            .submitLabel(.go).focused($focus, equals: .password)
            .onSubmit { Task { await submit() } }
            .accessibilityIdentifier("account-password")
        }
      } footer: {
        if screen == .signUp {
          Text("Use at least 15 characters. Long passphrases work well.")
        }
      }

      if screen == .signUp, let origin {
        Section {
          Toggle(isOn: $ageConsent) {
            Text(
              "I am 16 or older (or 13 to 15 with a parent or guardian’s permission), I agree to the Terms of Use, and I have read the Privacy Policy."
            )
          }
          .toggleStyle(CheckboxToggleStyle())
          .accessibilityIdentifier("account-consent-terms")
          HStack(spacing: 16) {
            Link("Terms of Use", destination: accountWebsite(origin, fragment: "terms"))
            Link("Privacy Policy", destination: accountWebsite(origin, fragment: "privacy"))
          }
          .font(.subheadline)
          Toggle(isOn: $dataConsent) {
            Text(
              "I consent to FORMA storing my workout records, which may include health-related information, to provide my account."
            )
          }
          .toggleStyle(CheckboxToggleStyle())
          .accessibilityIdentifier("account-consent-data")
        } footer: {
          Text(
            "We collect your name, email address and workout data to run your account and send essential account emails; without them we cannot create an account. Our providers Cloudflare and DigitalOcean process it, including outside Australia (mainly the United States). The Privacy Policy explains how to access or correct your information and how to complain."
          )
        }
      }

      Section {
        SubmitButton(
          title: screen == .signUp
            ? "Create account" : screen == .signIn ? "Sign in" : "Send reset link",
          working: account.busy
        ) {
          Task { await submit() }
        }
        .disabled(!canSubmit)
      }

      Section {
        switch screen {
        case .signIn:
          Button("Forgot password?") { go(.forgot) }
            .accessibilityIdentifier("account-forgot")
          HStack {
            Text("Need a verification link?").foregroundStyle(FormaTheme.secondary)
            Spacer()
            Button("Resend verification") { Task { await resend() } }
              .disabled(!emailLooksRight || sending || account.busy)
              .accessibilityIdentifier("account-resend")
          }
          .font(.subheadline)
          Button {
            go(.signUp)
          } label: {
            Text("New to FORMA? ") + Text("Create account").bold()
          }
          .accessibilityIdentifier("account-switch-mode")
        case .signUp:
          Button {
            go(.signIn)
          } label: {
            Text("Already have an account? ") + Text("Sign in").bold()
          }
          .accessibilityIdentifier("account-switch-mode")
        case .forgot:
          Button("Back to sign in") { go(.signIn) }
            .accessibilityIdentifier("account-switch-mode")
        }
      } footer: {
        if screen == .forgot {
          Text(
            "The link opens the FORMA website, where you choose a new password. Then come back here and sign in."
          )
        }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .accessibilityIdentifier("account-credentials-form")
    .onAppear { if focus == nil { focus = screen == .signUp ? .name : .email } }
  }

  private func go(_ next: Screen) {
    error = nil
    message = nil
    withFormaAnimation(motion, FormaMotion.reveal) { screen = next }
    focus = next == .signUp ? .name : .email
  }

  private func submit() async {
    guard canSubmit else { return }
    error = nil
    message = nil
    let address = email.trimmingCharacters(in: .whitespaces)
    do {
      switch screen {
      case .signUp:
        try await account.signUp(
          name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: address,
          password: password)
        model.haptic(.added)
      case .signIn:
        try await account.signIn(email: address, password: password)
        if account.isSignedIn { model.haptic(.started) }
      case .forgot:
        try await account.requestPasswordReset(email: address)
        message = "If an account uses this address, a reset link is on its way."
        model.haptic(.selected)
      }
      password = ""
    } catch {
      password = ""
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func resend() async {
    let address = email.trimmingCharacters(in: .whitespaces)
    sending = true
    defer { sending = false }
    error = nil
    do {
      try await account.resendVerification(email: address)
      message = "If this address needs verification, a link is on its way."
      model.haptic(.selected)
    } catch {
      self.error = "We couldn’t send the verification email. \(error.accountMessage)"
      model.haptic(error.accountHaptic)
    }
  }

  // MARK: Two-step challenge

  private var twoFactorForm: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("TWO-STEP VERIFICATION").font(.caption.weight(.bold)).tracking(2)
            .foregroundStyle(FormaTheme.secondary)
          Text("One more step").font(.largeTitle.bold()).foregroundStyle(FormaTheme.primary)
            .accessibilityAddTraits(.isHeader)
          Text("Enter a code from your authenticator app, or use a recovery code.")
            .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        }
        .padding(.vertical, 8).listRowBackground(Color.clear)
        if let error { FormNotice(text: error, tone: .error, identifier: "account-error") }
      }
      Section {
        TextField(useRecoveryCode ? "Recovery code" : "Authenticator code", text: $code)
          .textContentType(useRecoveryCode ? nil : .oneTimeCode)
          .keyboardType(useRecoveryCode ? .asciiCapable : .numberPad)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .focused($focus, equals: .code)
          .submitLabel(.go).onSubmit { Task { await verify() } }
          .accessibilityIdentifier("account-code")
        Button("Use \(useRecoveryCode ? "authenticator code" : "recovery code")") {
          useRecoveryCode.toggle()
          code = ""
          error = nil
        }
        .accessibilityIdentifier("account-code-mode")
      }
      Section {
        SubmitButton(title: "Verify and sign in", working: account.busy) {
          Task { await verify() }
        }
        .disabled(account.busy || code.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      Section {
        Button("Back to sign in") {
          Task {
            await account.abandonPending()
            code = ""
            error = nil
            screen = .signIn
          }
        }
        .accessibilityIdentifier("account-switch-mode")
      }
    }
    .onAppear { focus = .code }
  }

  private func verify() async {
    error = nil
    do {
      try await account.submitTwoFactor(
        code: code.trimmingCharacters(in: .whitespaces), recovery: useRecoveryCode)
      if account.isSignedIn { model.haptic(.started) }
    } catch {
      code = ""
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  // MARK: Verification email

  private func checkEmail(_ address: String) -> some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Image(systemName: "envelope.badge").font(.largeTitle).foregroundStyle(FormaTheme.accent)
            .accessibilityHidden(true)
          Text("Check your email").font(.largeTitle.bold()).foregroundStyle(FormaTheme.primary)
            .accessibilityAddTraits(.isHeader)
          Text(
            "Your account is ready. Check your inbox for the verification link before signing in."
          )
          .foregroundStyle(FormaTheme.primary)
          Text("We sent it to \(address).").font(.subheadline).foregroundStyle(
            FormaTheme.secondary)
        }
        .padding(.vertical, 8).listRowBackground(Color.clear)
        if let error { FormNotice(text: error, tone: .error, identifier: "account-error") }
        if let message { FormNotice(text: message, tone: .success, identifier: "account-message") }
      }
      Section {
        Button("Resend verification email") {
          Task {
            sending = true
            defer { sending = false }
            error = nil
            message = nil
            do {
              try await account.resendVerification(email: address)
              message = "If this address needs verification, a link is on its way."
              model.haptic(.selected)
            } catch {
              self.error = "We couldn’t send the verification email. \(error.accountMessage)"
              model.haptic(error.accountHaptic)
            }
          }
        }
        .disabled(sending)
        .accessibilityIdentifier("account-resend")
        Button("Back to sign in") {
          email = address
          error = nil
          message =
            "Your account is ready. Check your inbox for the verification link before signing in."
          screen = .signIn
          Task { await account.abandonPending() }
        }
        .accessibilityIdentifier("account-switch-mode")
      }
    }
  }
}
