import SwiftUI
import UIKit

enum FormaTheme {
  static let lime = Color(hex: 0xDFF780)
  static let ink = Color(hex: 0x202522)
  static let canvas = adaptive(0xF5F6F3, 0x151A17)
  static let surface = adaptive(0xFFFFFF, 0x202722)
  static let primary = adaptive(
    0x202522, 0xF5F6F3, highContrastLight: 0x101712, highContrastDark: 0xFFFFFF)
  static let secondary = adaptive(
    0x59635D, 0xB9C2BC, highContrastLight: 0x333D35, highContrastDark: 0xE8EDE9)
  static let accent = adaptive(0x4C631C, 0xDFF780, highContrastLight: 0x354A0D)
  static let line = adaptive(
    0xDFE4DC, 0x414C44, highContrastLight: 0x778176, highContrastDark: 0xA2B1A5)
  static let fieldBorder = adaptive(
    0x778176, 0x8B988D, highContrastLight: 0x434E46, highContrastDark: 0xCAD4CC)
  static let error = adaptive(
    0xB42318, 0xFFB4AB, highContrastLight: 0x8B1E13, highContrastDark: 0xFFC9C1)

  private static func adaptive(
    _ light: UInt, _ dark: UInt, highContrastLight: UInt? = nil, highContrastDark: UInt? = nil
  ) -> Color {
    Color(
      uiColor: UIColor { traits in
        let increased = traits.accessibilityContrast == .high
        let resolved =
          traits.userInterfaceStyle == .dark
          ? increased ? highContrastDark ?? dark : dark
          : increased ? highContrastLight ?? light : light
        return UIColor(hex: resolved)
      }
    )
  }
}

extension UIColor {
  convenience init(hex: UInt) {
    self.init(
      red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255, alpha: 1)
  }
}
extension Color {
  init(hex: UInt) { self.init(uiColor: UIColor(hex: hex)) }
}

struct FormaMark: Shape {
  func path(in rect: CGRect) -> Path {
    let facets: [[CGPoint]] = [
      [.init(x: 18, y: 12), .init(x: 29, y: 12), .init(x: 19, y: 52), .init(x: 8, y: 52)],
      [.init(x: 32, y: 12), .init(x: 58, y: 12), .init(x: 55, y: 23), .init(x: 29, y: 23)],
      [.init(x: 27, y: 29), .init(x: 47, y: 29), .init(x: 44, y: 40), .init(x: 24, y: 40)],
    ]
    var path = Path()
    for points in facets {
      path.move(to: CGPoint(x: points[0].x / 64 * rect.width, y: points[0].y / 64 * rect.height))
      for point in points.dropFirst() {
        path.addLine(to: CGPoint(x: point.x / 64 * rect.width, y: point.y / 64 * rect.height))
      }
      path.closeSubpath()
    }
    return path
  }
}

struct EditorialTitle: View {
  let text: String
  @ScaledMetric(relativeTo: .largeTitle) private var size = 48.0
  var body: some View {
    Text(text).font(.system(size: size, weight: .black).width(.condensed))
      .tracking(-0.8).fixedSize(horizontal: false, vertical: true)
      .foregroundStyle(FormaTheme.primary)
      .accessibilityAddTraits(.isHeader)
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(AppModel.self) private var model
  @Environment(\.isEnabled) private var isEnabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline).foregroundStyle(FormaTheme.ink)
      .frame(maxWidth: .infinity, minHeight: 56)
      .padding(.horizontal, 16)
      .background(FormaTheme.lime, in: RoundedRectangle(cornerRadius: 16))
      .opacity(isEnabled ? configuration.isPressed ? 0.85 : 1 : 0.5)
      .scaleEffect(
        isEnabled && configuration.isPressed && !reduceMotion && model.motion == .system ? 0.99 : 1)
  }
}

struct LocalSaveStatus: View {
  let saving: Bool
  var pendingChanges = false
  var body: some View {
    Label(
      saving
        && !pendingChanges
        ? "Saving on this iPhone…"
        : pendingChanges ? "Unsaved edits · tap Done to save" : "Saved on this iPhone",
      systemImage: pendingChanges
        ? "pencil.circle"
        : saving
          ? "arrow.triangle.2.circlepath" : "checkmark.shield"
    )
    .font(.footnote).foregroundStyle(FormaTheme.secondary)
    .accessibilityIdentifier("local-save-status")
  }
}

struct SectionHeading: View {
  let title: String
  let detail: String
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 16) {
        heading.fixedSize()
        Spacer(minLength: 8)
        supporting.fixedSize()
      }
      VStack(alignment: .leading, spacing: 8) {
        heading
        supporting
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var heading: some View {
    Text(title).font(.title2.bold()).foregroundStyle(FormaTheme.primary)
      .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
  }
  private var supporting: some View {
    Text(detail).font(.subheadline).foregroundStyle(FormaTheme.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
