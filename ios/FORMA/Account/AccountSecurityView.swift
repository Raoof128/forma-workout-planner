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
          "Changing your password or account details asks you to sign in again if your last sign-in was more than 5 minutes ago."
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
  private enum Field { case current, new, confirm }

  @Environment(AppModel.self) private var model
  @State private var current = ""
  @State private var new = ""
  @State private var confirm = ""
  @State private var working = false
  @State private var message: String?
  @State private var error: String?
  /// Raised with every notice so a repeat of the same text is announced again.
  @State private var noticeRevision = 0
  @FocusState private var focus: Field?

  private var missing: String? {
    if current.isEmpty { return "Enter your current password." }
    if new.isEmpty { return "Enter a new password." }
    if confirm.isEmpty { return "Enter the new password again." }
    return nil
  }

  var body: some View {
    Form {
      Section {
        SecureField("Current password", text: $current)
          .textContentType(.password).accessibilityIdentifier("password-current")
          .submitLabel(.next).focused($focus, equals: .current)
          .onSubmit { focus = .new }
        RevealablePasswordField(
          title: "New password", text: $new, contentType: .newPassword,
          identifier: "password-new"
        )
        .submitLabel(.next).focused($focus, equals: .new)
        .onSubmit { focus = .confirm }
        SecureField("Confirm new password", text: $confirm)
          .textContentType(.newPassword).accessibilityIdentifier("password-confirm")
          .submitLabel(.go).focused($focus, equals: .confirm)
          .onSubmit { Task { await submit() } }
      } footer: {
        Text(
          new.isEmpty
            ? "At least 15 characters. Passphrases are welcome. Changing your password signs out other sessions."
            : "\(new.count) of 15 characters. Changing your password signs out other sessions."
        )
      }
      Section {
        SubmitButton(
          title: "Update password", working: working, identifier: "password-submit", hint: missing
        ) {
          Task { await submit() }
        }
        .disabled(working || missing != nil)
        if let missing, !working {
          Text(missing).font(.footnote).foregroundStyle(FormaTheme.secondary)
        }
        if let message {
          FormNotice(text: message, tone: .success, revision: noticeRevision)
        }
        if let error { FormNotice(text: error, tone: .error, revision: noticeRevision) }
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Change password").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
  }

  private func fail(_ text: String) {
    error = text
    message = nil
    noticeRevision += 1
  }

  private func submit() async {
    guard missing == nil, !working else { return }
    error = nil
    message = nil
    if new.count < 15 {
      fail("Use at least 15 characters for your new password.")
      focus = .new
      model.haptic(.warning)
      return
    }
    if new != confirm {
      fail("The new passwords do not match.")
      focus = .confirm
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
      noticeRevision += 1
      model.accountSucceeded()
      await model.account.refreshSession()
    } catch {
      fail(error.accountMessage)
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
  /// A refused confirmation is shown inside the sheet, next to the field.
  @State private var sheetError: String?
  @State private var sheetRevision = 0
  @State private var noticeRevision = 0
  @FocusState private var passwordFocused: Bool
  @FocusState private var sheetFocused: Bool

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
        if let message { FormNotice(text: message, tone: .success, revision: noticeRevision) }
        if let error { FormNotice(text: error, tone: .error, revision: noticeRevision) }
      } footer: {
        Text("Add an authenticator app as a second layer.")
      }

      if !enabled && enrollment == nil {
        Section {
          SecureField("Confirm your password", text: $password)
            .textContentType(.password).accessibilityIdentifier("two-step-password")
            .submitLabel(.go).focused($passwordFocused)
            .onSubmit { if !password.isEmpty { Task { await start() } } }
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
            sheetError = nil
            confirming = .newCodes
          }
          .disabled(working)
          .accessibilityIdentifier("two-step-new-codes")
          Button("Turn off", role: .destructive) {
            confirmPassword = ""
            sheetError = nil
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
              .submitLabel(.go).focused($sheetFocused)
              .onSubmit { if !confirmPassword.isEmpty { Task { await confirmed(confirmation) } } }
            if let sheetError {
              FormNotice(
                text: sheetError, tone: .error, identifier: "two-step-confirm-error",
                revision: sheetRevision)
            }
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
      CopySecretButton(
        title: "Copy setup key", secret: { enrollment.secret }, identifier: "two-step-copy-key")
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
          if trimmed != value {
            code = trimmed
          } else if trimmed.count == 6, !working {
            // The number pad has no return key: a full code is sent by itself.
            Task { await verify() }
          }
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
      CopySecretButton(
        title: "Copy codes", secret: { recoveryCodes.joined(separator: "\n") },
        identifier: "two-step-copy-codes")
      ShareLink(item: recoveryCodes.joined(separator: "\n")) {
        Label("Save or share codes", systemImage: "square.and.arrow.up")
      }
    } header: {
      Text(title)
    }
  }

  private func fail(_ text: String) {
    error = text
    message = nil
    noticeRevision += 1
  }

  private func start() async {
    guard !working else { return }
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
      if error.rejectsCredentials { password = "" }
      fail(error.accountMessage)
      model.haptic(error.accountHaptic)
    }
  }

  private func verify() async {
    guard !working else { return }
    working = true
    defer { working = false }
    error = nil
    let value = code
    do {
      try await model.account.call { try await $0.confirmTwoFactorEnrollment(code: value) }
      enrollment = nil
      code = ""
      message = "Two-step verification is now on."
      noticeRevision += 1
      model.accountSucceeded()
      await model.account.refreshSession()
    } catch {
      if error.rejectsCredentials { code = "" }
      fail(error.accountMessage)
      model.haptic(error.accountHaptic)
    }
  }

  private func confirmed(_ confirmation: Confirmation) async {
    guard !working else { return }
    working = true
    defer { working = false }
    error = nil
    message = nil
    sheetError = nil
    let secret = confirmPassword
    do {
      switch confirmation {
      case .newCodes:
        recoveryCodes = try await model.account.call {
          try await $0.recoveryCodes(password: secret)
        }
        message = "New recovery codes are ready. Save them now."
        model.accountSucceeded()
      case .turnOff:
        try await model.account.call { try await $0.disableTwoFactor(password: secret) }
        recoveryCodes = []
        message = "Two-step verification is off."
        model.accountSucceeded()
        await model.account.refreshSession()
      }
      noticeRevision += 1
      confirmPassword = ""
      confirming = nil
    } catch {
      // The sheet stays open with the reason beside the field. A wrong
      // password is cleared; a dropped connection keeps what was typed.
      if error.rejectsCredentials { confirmPassword = "" }
      sheetError = error.accountMessage
      sheetRevision += 1
      sheetFocused = true
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
  @State private var revoking: AccountDevice?

  struct StepUp: Identifiable {
    /// A device reference, or "others".
    let action: String
    let twoFactor: Bool
    var id: String { action }
  }

  var body: some View {
    Form {
      Section {
        if let error {
          FormNotice(text: error, tone: .error)
          if devices.isEmpty && !loading {
            Button("Try again") { Task { await load() } }
              .accessibilityIdentifier("sessions-retry")
          }
        }
        if loading && devices.isEmpty {
          HStack {
            ProgressView()
            Text("Loading sessions…").foregroundStyle(FormaTheme.secondary)
          }
        } else if devices.isEmpty && error == nil {
          Text("No session details are available.").foregroundStyle(FormaTheme.secondary)
        }
        ForEach(devices) { device in
          AdaptiveRow {
            HStack(spacing: 12) {
              Image(
                systemName: device.userAgent?.contains("CFNetwork") == true
                  ? "iphone" : "desktopcomputer"
              )
              .foregroundStyle(FormaTheme.accent).frame(width: 28)
              VStack(alignment: .leading, spacing: 2) {
                Text(DeviceDescription.describe(device.userAgent)).font(.headline)
                Text(Self.detail(for: device))
                  .font(.footnote).foregroundStyle(FormaTheme.secondary)
              }
            }
            .accessibilityElement(children: .combine)
          } trailing: {
            if device.current {
              Text("Current").font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.accent)
            } else {
              Button("Revoke", role: .destructive) { revoking = device }
                .frame(minHeight: 44).contentShape(Rectangle())
                .disabled(acting != nil)
                .accessibilityLabel("Revoke \(DeviceDescription.describe(device.userAgent))")
                .accessibilityIdentifier("session-revoke-\(device.id)")
            }
          }
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
      } footer: {
        if devices.count < 2 && !loading {
          Text("No other devices are signed in to your account.")
        }
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
      revoking.map { "Sign out “\(DeviceDescription.describe($0.userAgent))”?" }
        ?? "Sign out this device?",
      isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
      titleVisibility: .visible
    ) {
      Button("Sign out this device", role: .destructive) {
        if let device = revoking { Task { await attempt(device.id) } }
      }
    } message: {
      Text("It will need to sign in again to use FORMA.")
    }
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

  /// "This device · Signed in 12 October 2026".
  static func detail(for device: AccountDevice) -> String {
    let signedIn =
      device.createdAt.map { "Signed in \(AccountDates.label($0))" } ?? "Sign-in date not available"
    return device.current ? "This device · \(signedIn)" : signedIn
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

  private func signOutOthers() async { await attempt("others") }

  private func signOutEverywhere() async {
    acting = "everywhere"
    defer { acting = nil }
    do {
      try await model.account.signOutEverywhere()
      model.accountSucceeded()
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
    model.accountSucceeded()
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
  @State private var errorRevision = 0
  @FocusState private var focus: Field?

  private enum Field { case password, code }

  private var ready: Bool { !password.isEmpty && (!step.twoFactor || !code.isEmpty) }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("Confirm your password", text: $password).textContentType(.password)
            .submitLabel(step.twoFactor ? .next : .go).focused($focus, equals: .password)
            .onSubmit {
              if step.twoFactor { focus = .code } else if ready { Task { await submit() } }
            }
            .accessibilityIdentifier("step-up-password")
          if step.twoFactor {
            TextField("Authenticator code", text: $code).keyboardType(.numberPad)
              .textContentType(.oneTimeCode).focused($focus, equals: .code)
              .accessibilityIdentifier("step-up-code")
          }
          if let error {
            FormNotice(
              text: error, tone: .error, identifier: "step-up-error", revision: errorRevision)
          }
        } footer: {
          Text("For your security, confirm it’s you. You signed in more than 5 minutes ago.")
        }
        Section {
          Button(
            step.action == "others" ? "Confirm and sign out" : "Confirm and sign out device",
            role: .destructive
          ) {
            Task { await submit() }
          }
          .disabled(working || !ready)
          .accessibilityIdentifier("step-up-confirm")
        }
      }
      .navigationTitle("Confirm it’s you").navigationBarTitleDisplayMode(.inline)
      .protectWidgetNavigation()
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
      .onAppear { focus = .password }
    }
    .presentationDetents([.medium])
  }

  private func submit() async {
    guard !working, ready else { return }
    working = true
    defer { working = false }
    error = nil
    do {
      try await confirm(password, step.twoFactor ? code.trimmingCharacters(in: .whitespaces) : nil)
      dismiss()
    } catch {
      if error.rejectsCredentials { password = "" }
      self.error = error.accountMessage
      errorRevision += 1
    }
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
  @State private var acting: String?
  @State private var error: String?
  @State private var noticeRevision = 0
  @State private var revoking: CoachTokenRecord?
  @State private var confirmFull = false

  var body: some View {
    ScrollViewReader { proxy in
      Form {
        Section {
          if let error {
            FormNotice(text: error, tone: .error, revision: noticeRevision)
          }
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
            CopySecretButton(
              title: "Copy token", secret: { issued.token }, identifier: "coach-copy")
            Button("I’ve saved it") { self.issued = nil }
              .accessibilityIdentifier("coach-saved")
          } header: {
            Text("Copy this token now. It will not be shown again.")
          }
          .id("issued-token")
        }
        Section {
          TextField("Token name, e.g. Claude coach", text: $label)
            .autocorrectionDisabled().submitLabel(.done)
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
            if full { confirmFull = true } else { Task { await create() } }
          } label: {
            HStack {
              Text(full ? "Create full-access token" : "Create read-only token")
              if acting == "create" { ProgressView() }
            }
          }
          .disabled(acting != nil || label.trimmingCharacters(in: .whitespaces).isEmpty)
          .accessibilityIdentifier("coach-create")
        } footer: {
          if label.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("Give the token a name so you can tell it apart later.")
          }
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
            AdaptiveRow {
              VStack(alignment: .leading, spacing: 2) {
                Text(token.label).font(.headline)
                Text(
                  "\(token.isFullAccess ? "Full access" : "Read only") · "
                    + (token.lastUsedAt.map { "Last used \(AccountDates.label($0))" }
                      ?? "Never used")
                    + " · Expires \(AccountDates.label(token.expiresAt))"
                )
                .font(.footnote).foregroundStyle(FormaTheme.secondary)
              }
              .accessibilityElement(children: .combine)
            } trailing: {
              Button("Revoke", role: .destructive) { revoking = token }
                .frame(minHeight: 44).contentShape(Rectangle())
                .disabled(acting != nil)
                .accessibilityLabel("Revoke \(token.label)")
                .accessibilityIdentifier("coach-revoke-\(token.id)")
            }
          }
        } header: {
          Text("Your tokens")
        }
      }
      .onChange(of: issued?.record.id) { _, id in
        // The token is shown once. Bring it into view and say so.
        guard id != nil else { return }
        withAnimation { proxy.scrollTo("issued-token", anchor: .top) }
        AccessibilityNotification.Announcement(
          "Token created. Copy it now. It will not be shown again."
        ).post()
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Coach access").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .task { await load() }
    .refreshable { await load() }
    .onDisappear { issued = nil }
    .confirmationDialog(
      "Create a full-access token?", isPresented: $confirmFull, titleVisibility: .visible
    ) {
      Button("Create full-access token") { Task { await create() } }
        .accessibilityIdentifier("coach-create-full-confirm")
    } message: {
      Text(
        "Anyone holding it can read and change everything in your training workspace until it expires or you revoke it. The token is shown once."
      )
    }
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

  private func fail(_ text: String) {
    error = text
    noticeRevision += 1
  }

  private func load() async {
    loading = true
    defer { loading = false }
    do {
      tokens = try await model.account.call { try await $0.coachTokens() }
      error = nil
    } catch {
      fail(error.accountMessage)
    }
  }

  private func create() async {
    acting = "create"
    defer { acting = nil }
    error = nil
    let (name, scopeFull) = (label.trimmingCharacters(in: .whitespaces), full)
    do {
      let result = try await model.account.call {
        try await $0.createCoachToken(label: name, full: scopeFull)
      }
      issued = result
      tokens.insert(result.record, at: 0)
      label = ""
      full = false
      model.accountSucceeded()
    } catch let failure as AccountFailure where failure.kind == .reauthenticationRequired {
      fail("Sign in again before creating a coach token.")
      model.haptic(.warning)
    } catch {
      fail(error.accountMessage)
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
      model.accountSucceeded()
    } catch {
      fail(error.accountMessage)
      model.haptic(error.accountHaptic)
    }
  }
}
