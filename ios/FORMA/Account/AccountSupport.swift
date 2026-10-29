import CoreImage.CIFilterBuiltins
import FORMACore
import SwiftUI
import UIKit

// Small pieces shared by the account screens.

/// An inline message under a form: what went wrong, or what just happened.
struct FormNotice: View {
  enum Tone { case error, success, info }
  let text: String
  var tone: Tone = .info
  var identifier: String?
  /// Bump it when the same text is raised again (a second failed tap), so the
  /// repeat is announced as well.
  var revision = 0

  private struct Announcement: Equatable {
    let text: String
    let revision: Int
  }

  var body: some View {
    Label {
      Text(text).foregroundStyle(FormaTheme.primary)
    } icon: {
      Image(
        systemName: tone == .error
          ? "exclamationmark.circle" : tone == .success ? "checkmark.circle" : "info.circle"
      )
      .foregroundStyle(tone == .error ? FormaTheme.error : FormaTheme.accent)
    }
    .font(.subheadline)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(identifier ?? "form-notice")
    .onAppear {
      if tone != .info { AccessibilityNotification.Announcement(text).post() }
    }
    // A changed or repeated message keeps the same view, so `onAppear` alone
    // would stay silent.
    .onChange(of: Announcement(text: text, revision: revision)) {
      AccessibilityNotification.Announcement(text).post()
    }
  }
}

/// The lime button, with a spinner while its request is in flight.
struct SubmitButton: View {
  let title: String
  var working = false
  var identifier = "account-submit"
  /// Why the button is dimmed, read after its name.
  var hint: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if working { ProgressView().tint(FormaTheme.ink) }
        Text(title)
      }
    }
    .buttonStyle(PrimaryButtonStyle())
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
    .accessibilityIdentifier(identifier)
    .accessibilityLabel(working ? "\(title), working" : title)
    .accessibilityHint(hint ?? "")
  }
}

struct CheckboxToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
          .font(.title3)
          .foregroundStyle(configuration.isOn ? FormaTheme.accent : FormaTheme.secondary)
          .accessibilityHidden(true)
        configuration.label.multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(.isToggle)
    .accessibilityValue(configuration.isOn ? "On" : "Off")
  }
}

/// Dates the way the website writes them: Sydney time, long form.
@MainActor
enum AccountDates {
  private static let long: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_AU")
    formatter.timeZone = TrainingDate.calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
    return formatter
  }()

  static func label(_ date: Date?) -> String {
    date.map { long.string(from: $0) } ?? "Not available"
  }
}

/// "Safari on Mac" for a browser's user agent, "FORMA app" for the app's own.
enum DeviceDescription {
  static func describe(_ userAgent: String?) -> String {
    guard let agent = userAgent, !agent.isEmpty else { return "Signed-in device" }
    if agent.contains("CFNetwork") || agent.hasPrefix("FORMA") { return "FORMA app" }
    let browser: String
    if agent.contains("Edg/") {
      browser = "Edge"
    } else if agent.contains("Firefox/") || agent.contains("FxiOS") {
      browser = "Firefox"
    } else if agent.contains("Chrome/") || agent.contains("CriOS") {
      browser = "Chrome"
    } else if agent.contains("Safari/") {
      browser = "Safari"
    } else {
      browser = "Browser"
    }
    let system: String?
    if agent.contains("iPhone") {
      system = "iPhone"
    } else if agent.contains("iPad") {
      system = "iPad"
    } else if agent.contains("Android") {
      system = "Android"
    } else if agent.contains("Macintosh") {
      system = "Mac"
    } else if agent.contains("Windows") {
      system = "Windows"
    } else if agent.contains("Linux") {
      system = "Linux"
    } else {
      system = nil
    }
    return system.map { "\(browser) on \($0)" } ?? browser
  }
}

/// A QR code for scanning from another device. The setup key and the
/// "Open in authenticator" link cover the phone this app is on.
struct QRCodeImage: View {
  let text: String

  var body: some View {
    if let image = Self.render(text) {
      Image(uiImage: image)
        .interpolation(.none).resizable().scaledToFit()
        .accessibilityHidden(true)
    }
  }

  private static func render(_ text: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

enum SecretPasteboard {
  /// Copies a one-time secret for two minutes, on this device only.
  static func copy(_ text: String) {
    UIPasteboard.general.setItems(
      [[UIPasteboard.typeAutomatic: text]],
      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
  }

  /// What a copy button says after it worked.
  static let copiedMessage = "Copied. It stays on the clipboard for 2 minutes."
}

/// A button that copies a secret and says so: its label changes, VoiceOver
/// hears it, and the pasteboard expiry is stated.
struct CopySecretButton: View {
  @Environment(AppModel.self) private var model
  let title: String
  let secret: () -> String
  var identifier: String?
  @State private var copied = false

  var body: some View {
    Button {
      SecretPasteboard.copy(secret())
      copied = true
      model.accountSucceeded()
      AccessibilityNotification.Announcement(SecretPasteboard.copiedMessage).post()
    } label: {
      if copied {
        Label("Copied for 2 minutes", systemImage: "checkmark")
      } else {
        Text(title)
      }
    }
    .accessibilityIdentifier(identifier ?? "copy-secret")
    .onChange(of: secret()) { copied = false }
  }
}

/// A leading description and a trailing control side by side, stacked at
/// accessibility text sizes so neither is squeezed or clipped.
struct AdaptiveRow<Leading: View, Trailing: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  var spacing: CGFloat = 12
  @ViewBuilder let leading: Leading
  @ViewBuilder let trailing: Trailing

  var body: some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 8) {
        leading
        trailing
      }
    } else {
      HStack(spacing: spacing) {
        leading
        Spacer(minLength: 0)
        trailing
      }
    }
  }
}

/// A password field with a show/hide control, for the long passphrases the
/// account asks for. Paste and AutoFill keep working in both states.
struct RevealablePasswordField: View {
  let title: String
  @Binding var text: String
  let contentType: UITextContentType
  var identifier: String
  var revealIdentifier: String?
  @State private var revealed = false

  var body: some View {
    HStack(spacing: 8) {
      Group {
        if revealed {
          TextField(title, text: $text)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
        } else {
          SecureField(title, text: $text)
        }
      }
      .textContentType(contentType)
      .accessibilityIdentifier(identifier)
      Button {
        revealed.toggle()
      } label: {
        Image(systemName: revealed ? "eye.slash" : "eye")
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(revealed ? "Hide \(title.lowercased())" : "Show \(title.lowercased())")
      .accessibilityIdentifier(revealIdentifier ?? identifier + "-reveal")
    }
  }
}

extension AppModel {
  /// A completed account action. Account outcomes have their own patterns
  /// (see `FormaHaptic`) rather than borrowing the workout ones: `.accountSent`
  /// for a link, email or token that went out, `.accountRemoved` for a
  /// sign-out, revoke or removal, and `.accountSuccess` for everything else.
  /// Refusals and failures use `accountHaptic`.
  func accountSucceeded(_ outcome: FormaHaptic = .accountSuccess) { haptic(outcome) }
}

extension Error {
  /// The words to show for a failed account request.
  var accountMessage: String {
    (self as? AccountFailure)?.message ?? (self as? LocalizedError)?.errorDescription
      ?? localizedDescription
  }

  /// The account answered that the credential (password or code) was wrong, as
  /// opposed to a dropped connection or a busy server.
  var rejectsCredentials: Bool {
    guard let failure = self as? AccountFailure else { return false }
    return failure.kind == .rejected || failure.kind == .unauthorized
  }

  /// A refusal the screen explains (validation) versus a failure to save.
  var accountHaptic: FormaHaptic {
    guard let failure = self as? AccountFailure else { return .accountFailure }
    return failure.kind == .rejected || failure.kind == .reauthenticationRequired
      ? .accountWarning : .accountFailure
  }
}
