import FORMACore
import SwiftUI

/// Change password, two-step verification, active sessions and coach access.
struct AccountSecurityView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let profile = model.account.profile
    Form {
      Section {
        NavigationLink {
          ChangePasswordView()
        } label: {
          Label("Change password", systemImage: "key")
        }
        .accessibilityIdentifier("security-password")
        NavigationLink {
          TwoFactorView()
        } label: {
          LabeledContent {
            Text(profile?.twoFactorEnabled == true ? "On" : "Off")
              .foregroundStyle(
                profile?.twoFactorEnabled == true ? FormaTheme.accent : FormaTheme.secondary)
          } label: {
            Label("Two-step verification", systemImage: "iphone.badge.checkmark")
          }
        }
        .accessibilityIdentifier("security-two-step")
      } header: {
        Text("Keep your account safe")
      } footer: {
        Text(
          "Password and account changes require a verified sign-in. Session expiry and revocation are enforced by the account service."
        )
      }
      Section {
        NavigationLink {
          SessionsView()
        } label: {
          Label("Active sessions", systemImage: "person.2")
        }
        .accessibilityIdentifier("security-sessions")
        NavigationLink {
          CoachAccessView()
        } label: {
          Label("Coach access", systemImage: "key.viewfinder")
        }
        .accessibilityIdentifier("security-coach")
      } footer: {
        Text("Review the devices signed in to your account, and the tokens coaching tools use.")
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Security").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
  }
}

// MARK: Password

struct ChangePasswordView: View {
  @Environment(AppModel.self) private var model
  @State private var current = ""
  @State private var new = ""
  @State private var confirm = ""
  @State private var working = false
  @State private var message: String?
  @State private var error: String?

  var body: some View {
    Form {
      Section {
        SecureField("Current password", text: $current)
          .textContentType(.password).accessibilityIdentifier("password-current")
        SecureField("New password", text: $new)
          .textContentType(.newPassword).accessibilityIdentifier("password-new")
        SecureField("Confirm new password", text: $confirm)
          .textContentType(.newPassword).accessibilityIdentifier("password-confirm")
      } footer: {
        Text(
          "At least 15 characters. Passphrases are welcome. Changing your password signs out other sessions."
        )
      }
      Section {
        SubmitButton(title: "Update password", working: working, identifier: "password-submit") {
          Task { await submit() }
        }
        .disabled(working || current.isEmpty || new.isEmpty || confirm.isEmpty)
        if let message { FormNotice(text: message, tone: .success) }
        if let error { FormNotice(text: error, tone: .error) }
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Change password").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
  }

  private func submit() async {
    error = nil
    message = nil
    if new.count < 15 {
      error = "Use at least 15 characters for your new password."
      model.haptic(.warning)
      return
    }
    if new != confirm {
      error = "The new passwords do not match."
      model.haptic(.warning)
      return
    }
    working = true
    defer { working = false }
    let (oldPassword, newPassword) = (current, new)
    do {
      try await model.account.call {
        try await $0.changePassword(current: oldPassword, new: newPassword)
      }
      current = ""
      new = ""
      confirm = ""
      message = "Password updated. Other sessions were signed out."
      model.haptic(.selected)
      await model.account.refreshSession()
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}

// MARK: Two-step verification

struct TwoFactorView: View {
  @Environment(AppModel.self) private var model
  @State private var password = ""
  @State private var code = ""
  @State private var enrollment: TwoFactorEnrollment?
  @State private var recoveryCodes: [String] = []
  @State private var working = false
  @State private var message: String?
  @State private var error: String?
  @State private var confirming: Confirmation?
  @State private var confirmPassword = ""

  private enum Confirmation: Identifiable {
    case newCodes, turnOff
    var id: Self { self }
  }

  private var enabled: Bool { model.account.profile?.twoFactorEnabled == true }

  var body: some View {
    Form {
      Section {
        LabeledContent("Status") {
          Text(enabled ? "On" : "Off").foregroundStyle(
            enabled ? FormaTheme.accent : FormaTheme.secondary)
        }
        .accessibilityIdentifier("two-step-status")
        if let message { FormNotice(text: message, tone: .success) }
        if let error { FormNotice(text: error, tone: .error) }
      } footer: {
        Text("Add an authenticator app as a second layer.")
      }

      if !enabled && enrollment == nil {
        Section {
          SecureField("Confirm your password", text: $password)
            .textContentType(.password).accessibilityIdentifier("two-step-password")
          Button {
            Task { await start() }
          } label: {
            HStack {
              Text("Set up authenticator")
              if working { ProgressView() }
            }
          }
          .disabled(working || password.isEmpty)
          .accessibilityIdentifier("two-step-start")
        }
      }

      if let enrollment { setup(enrollment) }

      if enabled {
        Section {
          Button("Generate new recovery codes") {
            confirmPassword = ""
            confirming = .newCodes
          }
          .disabled(working)
          .accessibilityIdentifier("two-step-new-codes")
          Button("Turn off", role: .destructive) {
            confirmPassword = ""
            confirming = .turnOff
          }
          .disabled(working)
          .accessibilityIdentifier("two-step-turn-off")
        }
      }

      if !recoveryCodes.isEmpty && enrollment == nil { codes(title: "Recovery codes") }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Two-step verification").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .sheet(item: $confirming) { confirmation in
      NavigationStack {
        Form {
          Section {
            SecureField("Confirm your password", text: $confirmPassword)
              .textContentType(.password).accessibilityIdentifier("two-step-confirm-password")
          } footer: {
            Text(
              confirmation == .newCodes
                ? "Generating new codes replaces every existing recovery code. Save the new set before closing this page."
                : "Turning two-step verification off makes your password the only protection for your account."
            )
          }
          Section {
            Button(
              confirmation == .newCodes ? "Generate new codes" : "Turn off two-step verification",
              role: confirmation == .turnOff ? .destructive : nil
            ) {
              Task { await confirmed(confirmation) }
            }
            .disabled(confirmPassword.isEmpty || working)
            .accessibilityIdentifier("two-step-confirm")
          }
        }
        .navigationTitle(confirmation == .newCodes ? "New recovery codes" : "Turn off")
        .protectWidgetNavigation()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { confirming = nil }
          }
        }
      }
      .presentationDetents([.medium])
    }
    .onDisappear {
      // Secrets are shown once and never kept.
      recoveryCodes = []
      enrollment = nil
      password = ""
      confirmPassword = ""
    }
  }

  @ViewBuilder
  private func setup(_ enrollment: TwoFactorEnrollment) -> some View {
    Section {
      Text("Open an authenticator app and add a new account.")
      if let url = URL(string: enrollment.totpURI) {
        Link(destination: url) {
          Label("Open in authenticator app", systemImage: "arrow.up.forward.app")
        }
        .accessibilityIdentifier("two-step-open-authenticator")
      }
      QRCodeImage(text: enrollment.totpURI)
        .frame(width: 180, height: 180).frame(maxWidth: .infinity)
        .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 12))
      LabeledContent("Setup key") {
        Text(enrollment.secret).font(.callout.monospaced()).textSelection(.enabled)
      }
      Button("Copy setup key") { SecretPasteboard.copy(enrollment.secret) }
    } header: {
      Text("Add it to your authenticator")
    } footer: {
      Text(
        "Scan the code from another device, open the link on this iPhone, or enter the setup key if scanning is unavailable."
      )
    }
    Section {
      TextField("Authenticator code", text: $code)
        .keyboardType(.numberPad).textContentType(.oneTimeCode)
        .onChange(of: code) { _, value in
          let digits = value.filter(\.isNumber)
          let trimmed = String(digits.prefix(6))
          if trimmed != value { code = trimmed }
        }
        .accessibilityIdentifier("two-step-code")
      Button {
        Task { await verify() }
      } label: {
        HStack {
          Text("Verify and enable")
          if working { ProgressView() }
        }
      }
      .disabled(working || code.count != 6)
      .accessibilityIdentifier("two-step-verify")
    } footer: {
      Text("Enter the current six-digit code to confirm setup.")
    }
    if !recoveryCodes.isEmpty { codes(title: "Save these recovery codes now") }
  }

  @ViewBuilder
  private func codes(title: String) -> some View {
    Section {
      Text("Each code can be used once if you lose access to your authenticator.")
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
      Text(recoveryCodes.joined(separator: "\n"))
        .font(.callout.monospaced()).textSelection(.enabled)
        .accessibilityIdentifier("two-step-codes")
      Button("Copy codes") { SecretPasteboard.copy(recoveryCodes.joined(separator: "\n")) }
      ShareLink(item: recoveryCodes.joined(separator: "\n")) {
        Label("Save or share codes", systemImage: "square.and.arrow.up")
      }
    } header: {
      Text(title)
    }
  }

  private func start() async {
    working = true
    defer { working = false }
    error = nil
    message = nil
    let secret = password
    do {
      let setup = try await model.account.call { try await $0.enableTwoFactor(password: secret) }
      enrollment = setup
      recoveryCodes = setup.backupCodes
      password = ""
    } catch {
      password = ""
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func verify() async {
    working = true
    defer { working = false }
    error = nil
    let value = code
    do {
      try await model.account.call { try await $0.confirmTwoFactorEnrollment(code: value) }
      enrollment = nil
      code = ""
      message = "Two-step verification is now on."
      model.haptic(.started)
      await model.account.refreshSession()
    } catch {
      code = ""
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func confirmed(_ confirmation: Confirmation) async {
    working = true
    defer { working = false }
    error = nil
    message = nil
    let secret = confirmPassword
    do {
      switch confirmation {
      case .newCodes:
        recoveryCodes = try await model.account.call {
          try await $0.recoveryCodes(password: secret)
        }
        message = "New recovery codes are ready. Save them now."
        model.haptic(.selected)
      case .turnOff:
        try await model.account.call { try await $0.disableTwoFactor(password: secret) }
        recoveryCodes = []
        message = "Two-step verification is off."
        model.haptic(.stopped)
        await model.account.refreshSession()
      }
      confirmPassword = ""
      confirming = nil
    } catch {
      confirmPassword = ""
      confirming = nil
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}

// MARK: Active sessions

struct SessionsView: View {
  @Environment(AppModel.self) private var model
  @State private var devices: [AccountDevice] = []
  @State private var loading = true
  @State private var acting: String?
  @State private var error: String?
  @State private var stepUp: StepUp?
  @State private var confirmOthers = false
  @State private var confirmEverywhere = false

  struct StepUp: Identifiable {
    /// A device reference, or "others".
    let action: String
    let twoFactor: Bool
    var id: String { action }
  }

  var body: some View {
    Form {
      Section {
        if let error { FormNotice(text: error, tone: .error) }
        if loading && devices.isEmpty {
          HStack {
            ProgressView()
            Text("Loading sessions…").foregroundStyle(FormaTheme.secondary)
          }
        } else if devices.isEmpty {
          Text("No session details are available.").foregroundStyle(FormaTheme.secondary)
        }
        ForEach(devices) { device in
          HStack(spacing: 12) {
            Image(
              systemName: device.userAgent?.contains("CFNetwork") == true
                ? "iphone" : "desktopcomputer"
            )
            .foregroundStyle(FormaTheme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
              Text(DeviceDescription.describe(device.userAgent)).font(.headline)
              Text(
                "\(device.current ? "This device · " : "")\(AccountDates.label(device.createdAt))"
              )
              .font(.footnote).foregroundStyle(FormaTheme.secondary)
            }
            Spacer(minLength: 0)
            if device.current {
              Text("Current").font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.accent)
            } else {
              Button("Revoke") { Task { await revoke(device.id) } }
                .disabled(acting != nil)
                .accessibilityIdentifier("session-revoke-\(device.id)")
            }
          }
          .accessibilityElement(children: .combine)
        }
      } header: {
        Text("Signed-in browsers and devices")
      }
      Section {
        Button("Sign out other devices", role: .destructive) { confirmOthers = true }
          .disabled(acting != nil || devices.count < 2)
          .accessibilityIdentifier("sessions-sign-out-others")
        Button("Sign out everywhere", role: .destructive) { confirmEverywhere = true }
          .disabled(acting != nil)
          .accessibilityIdentifier("sessions-sign-out-everywhere")
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Active sessions").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          Task { await load() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(loading)
        .accessibilityLabel("Refresh sessions")
      }
    }
    .task { await load() }
    .refreshable { await load() }
    .confirmationDialog(
      "Sign out all other devices?", isPresented: $confirmOthers, titleVisibility: .visible
    ) {
      Button("Sign out other devices", role: .destructive) { Task { await signOutOthers() } }
    }
    .confirmationDialog(
      "Sign out of FORMA on every device?", isPresented: $confirmEverywhere,
      titleVisibility: .visible
    ) {
      Button("Sign out everywhere", role: .destructive) { Task { await signOutEverywhere() } }
    } message: {
      Text(
        "This iPhone is signed out too. Your training stays saved on this iPhone and in your account."
      )
    }
    .sheet(item: $stepUp) { step in
      StepUpSheet(step: step) { password, code in
        try await perform(step.action, password: password, code: code)
      }
    }
  }

  private func load() async {
    loading = true
    defer { loading = false }
    do {
      devices = try await model.account.call { try await $0.devices() }
      error = nil
    } catch {
      self.error = error.accountMessage
    }
  }

  private func revoke(_ id: String) async {
    await attempt(id)
  }

  private func signOutOthers() async { await attempt("others") }

  private func signOutEverywhere() async {
    acting = "everywhere"
    defer { acting = nil }
    do {
      try await model.account.signOutEverywhere()
      model.haptic(.stopped)
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  /// Revoking another device needs a sign-in from the last five minutes; an
  /// older one confirms with its password (and a code when two-step is on).
  private func attempt(_ action: String) async {
    guard acting == nil else { return }
    acting = action
    defer { acting = nil }
    error = nil
    do {
      try await perform(action, password: nil, code: nil)
    } catch let failure as AccountFailure where failure.kind == .reauthenticationRequired {
      stepUp = StepUp(action: action, twoFactor: failure.twoFactor)
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func perform(_ action: String, password: String?, code: String?) async throws {
    if action == "others" {
      try await model.account.call {
        try await $0.revokeOtherDevices(password: password, code: code)
      }
      devices = devices.filter(\.current)
    } else {
      try await model.account.call {
        try await $0.revokeDevice(id: action, password: password, code: code)
      }
      devices = devices.filter { $0.id != action }
    }
    model.haptic(.stopped)
  }
}

private struct StepUpSheet: View {
  @Environment(\.dismiss) private var dismiss
  let step: SessionsView.StepUp
  let confirm: (String, String?) async throws -> Void
  @State private var password = ""
  @State private var code = ""
  @State private var working = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("Confirm your password", text: $password).textContentType(.password)
            .accessibilityIdentifier("step-up-password")
          if step.twoFactor {
            TextField("Authenticator code", text: $code).keyboardType(.numberPad)
              .textContentType(.oneTimeCode).accessibilityIdentifier("step-up-code")
          }
          if let error { FormNotice(text: error, tone: .error) }
        } footer: {
          Text("For your security, confirm it’s you. You signed in more than 5 minutes ago.")
        }
        Section {
          Button(
            step.action == "others" ? "Confirm and sign out" : "Confirm and sign out device",
            role: .destructive
          ) {
            Task {
              working = true
              defer { working = false }
              do {
                try await confirm(
                  password, step.twoFactor ? code.trimmingCharacters(in: .whitespaces) : nil)
                dismiss()
              } catch {
                password = ""
                self.error = error.accountMessage
              }
            }
          }
          .disabled(working || password.isEmpty || (step.twoFactor && code.isEmpty))
          .accessibilityIdentifier("step-up-confirm")
        }
      }
      .navigationTitle("Confirm it’s you").navigationBarTitleDisplayMode(.inline)
      .protectWidgetNavigation()
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
    .presentationDetents([.medium])
  }
}

// MARK: Coach access

struct CoachAccessView: View {
  @Environment(AppModel.self) private var model
  @State private var tokens: [CoachTokenRecord] = []
  @State private var loading = true
  @State private var label = ""
  @State private var full = false
  @State private var issued: IssuedCoachToken?
  @State private var copied = false
  @State private var acting: String?
  @State private var error: String?
  @State private var revoking: CoachTokenRecord?

  var body: some View {
    Form {
      Section {
        if let error { FormNotice(text: error, tone: .error) }
      } footer: {
        Text(
          "Give a coaching tool or AI assistant its own token. A read-only token reads your routines, workouts and personal bests. A full-access token can also read and change everything in your training workspace. No token can see your email or change your password, sign-ins, 2-step verification or account."
        )
      }
      if let issued {
        Section {
          Text(
            issued.record.isFullAccess
              ? "This token can read and change your routines, workouts, history, profile and schedule. Store it like a password, for example in your coaching tool’s secret settings. Never paste it into a chat."
              : "This token can only read your training. Store it like a password, for example in your coaching tool’s secret settings. Never paste it into a chat."
          )
          .font(.footnote)
          Text(issued.token).font(.callout.monospaced()).textSelection(.enabled)
            .accessibilityIdentifier("coach-token-value")
          Text("It expires on \(AccountDates.label(issued.record.expiresAt)).").font(.footnote)
            .foregroundStyle(FormaTheme.secondary)
          Button(copied ? "Copied" : "Copy token") {
            SecretPasteboard.copy(issued.token)
            copied = true
          }
          .accessibilityIdentifier("coach-copy")
          Button("I’ve saved it") {
            self.issued = nil
            copied = false
          }
          .accessibilityIdentifier("coach-saved")
        } header: {
          Text("Copy this token now. It will not be shown again.")
        }
      }
      Section {
        TextField("Token name, e.g. Claude coach", text: $label)
          .autocorrectionDisabled()
          .onChange(of: label) { _, value in
            if value.count > 60 { label = String(value.prefix(60)) }
          }
          .accessibilityIdentifier("coach-label")
        Picker("Access", selection: $full) {
          Text("Read only").tag(false)
          Text("Full access: read and edit").tag(true)
        }
        .accessibilityIdentifier("coach-scope")
        Button {
          Task { await create() }
        } label: {
          HStack {
            Text(full ? "Create full-access token" : "Create read-only token")
            if acting == "create" { ProgressView() }
          }
        }
        .disabled(acting != nil || label.trimmingCharacters(in: .whitespaces).isEmpty)
        .accessibilityIdentifier("coach-create")
      }
      Section {
        if loading && tokens.isEmpty {
          HStack {
            ProgressView()
            Text("Loading coach access…").foregroundStyle(FormaTheme.secondary)
          }
        } else if tokens.isEmpty {
          Text(
            "No coach tokens yet. Tokens expire after 90 days and you can hold up to five at a time."
          )
          .foregroundStyle(FormaTheme.secondary)
        }
        ForEach(tokens) { token in
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(token.label).font(.headline)
              Text(
                "\(token.isFullAccess ? "Full access" : "Read only") · "
                  + (token.lastUsedAt.map { "Last used \(AccountDates.label($0))" } ?? "Never used")
                  + " · Expires \(AccountDates.label(token.expiresAt))"
              )
              .font(.footnote).foregroundStyle(FormaTheme.secondary)
            }
            Spacer(minLength: 0)
            Button("Revoke", role: .destructive) { revoking = token }
              .disabled(acting != nil)
              .accessibilityIdentifier("coach-revoke-\(token.id)")
          }
          .accessibilityElement(children: .combine)
        }
      } header: {
        Text("Your tokens")
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Coach access").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .task { await load() }
    .refreshable { await load() }
    .onDisappear { issued = nil }
    .confirmationDialog(
      revoking.map { "Revoke the “\($0.label)” token?" } ?? "Revoke token?",
      isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
      titleVisibility: .visible
    ) {
      Button("Revoke token", role: .destructive) {
        if let token = revoking { Task { await revoke(token) } }
      }
    } message: {
      Text("Tools using it will lose access immediately.")
    }
  }

  private func load() async {
    loading = true
    defer { loading = false }
    do {
      tokens = try await model.account.call { try await $0.coachTokens() }
    } catch {
      self.error = error.accountMessage
    }
  }

  private func create() async {
    acting = "create"
    defer { acting = nil }
    error = nil
    copied = false
    let (name, scopeFull) = (label.trimmingCharacters(in: .whitespaces), full)
    do {
      let result = try await model.account.call {
        try await $0.createCoachToken(label: name, full: scopeFull)
      }
      issued = result
      tokens.insert(result.record, at: 0)
      label = ""
      full = false
      model.haptic(.added)
    } catch let failure as AccountFailure where failure.kind == .reauthenticationRequired {
      error = "Sign in again before creating a coach token."
      model.haptic(.warning)
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }

  private func revoke(_ token: CoachTokenRecord) async {
    acting = token.id
    defer { acting = nil }
    error = nil
    do {
      try await model.account.call { try await $0.revokeCoachToken(id: token.id) }
      tokens.removeAll { $0.id == token.id }
      if issued?.record.id == token.id { issued = nil }
      model.haptic(.stopped)
    } catch {
      self.error = error.accountMessage
      model.haptic(error.accountHaptic)
    }
  }
}
