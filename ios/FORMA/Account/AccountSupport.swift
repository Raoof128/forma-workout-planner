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
  }
}

/// The lime button, with a spinner while its request is in flight.
struct SubmitButton: View {
  let title: String
  var working = false
  var identifier = "account-submit"
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
}

extension Error {
  /// The words to show for a failed account request.
  var accountMessage: String {
    (self as? AccountFailure)?.message ?? (self as? LocalizedError)?.errorDescription
      ?? localizedDescription
  }

  /// A refusal the screen explains (validation) versus a failure to save.
  var accountHaptic: FormaHaptic {
    guard let failure = self as? AccountFailure else { return .failed }
    return failure.kind == .rejected || failure.kind == .reauthenticationRequired
      ? .warning : .failed
  }
}
