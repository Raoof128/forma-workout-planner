import FORMASurfaces
import SwiftUI
import UIKit

/// The app's brand hex values. The ones the widget extension also draws (lime,
/// ink, accent, secondary text) come from `BrandPalette` in FORMASurfaces, which
/// the app and the extension both link, so the two cannot drift. The Watch app
/// cannot link FORMASurfaces (it is not built for watchOS) and keeps its own
/// copy of lime and ink in `WatchTheme`; change those together.
enum FormaPalette {
  static let lime = UInt(BrandPalette.lime)
  static let ink = UInt(BrandPalette.ink)
  static let canvasLight: UInt = 0xF5F6F3
  static let canvasDark: UInt = 0x151A17
  static let accentLight = UInt(BrandPalette.accent.light)
  static let secondaryLight = UInt(BrandPalette.secondaryText.light)
  static let secondaryDark = UInt(BrandPalette.secondaryText.dark)
  /// The ink panel behind the Today hero. Equal to `canvasDark`, so in dark
  /// mode the panel has no edge of its own; see `FormaTheme.line`.
  static let heroInk: UInt = 0x151A17
  static let heroDetail: UInt = 0xDEE5DC
}

enum FormaTheme {
  static let lime = Color(hex: FormaPalette.lime)
  static let ink = Color(hex: FormaPalette.ink)
  /// Fixed colours for content drawn on the hero's ink panel. They do not adapt:
  /// the panel is ink in both appearances.
  static let heroInk = Color(hex: FormaPalette.heroInk)
  static let heroDetail = Color(hex: FormaPalette.heroDetail)
  static let canvas = adaptive(FormaPalette.canvasLight, FormaPalette.canvasDark)
  static let surface = adaptive(0xFFFFFF, 0x202722)
  static let primary = adaptive(
    0x202522, 0xF5F6F3, highContrastLight: 0x101712, highContrastDark: 0xFFFFFF)
  static let secondary = adaptive(
    FormaPalette.secondaryLight, FormaPalette.secondaryDark,
    highContrastLight: UInt(BrandPalette.secondaryText.highContrastLight),
    highContrastDark: UInt(BrandPalette.secondaryText.highContrastDark))
  static let accent = adaptive(
    FormaPalette.accentLight, UInt(BrandPalette.accent.dark),
    highContrastLight: UInt(BrandPalette.accent.highContrastLight),
    highContrastDark: UInt(BrandPalette.accent.highContrastDark))
  /// A hairline for separators that only decorate (list dividers, card edges).
  /// It is deliberately quiet, 1.2:1 to 2:1 against canvas, so never use it for a
  /// stroke that carries meaning; use `boundary`.
  static let line = adaptive(
    0xDFE4DC, 0x414C44, highContrastLight: 0x778176, highContrastDark: 0xA2B1A5)
  static let fieldBorder = adaptive(
    0x778176, 0x8B988D, highContrastLight: 0x434E46, highContrastDark: 0xCAD4CC)
  /// A stroke that carries meaning: the outline of an empty state such as an
  /// unscheduled day, an unfilled control, or the edge of a button. At least 3:1
  /// against both `canvas` and `surface` in all four appearance variants
  /// (WCAG 1.4.11). It is `fieldBorder` by design, so a field and a ring read as
  /// one family.
  static let boundary = fieldBorder
  static let error = adaptive(
    0xB42318, 0xFFB4AB, highContrastLight: 0x8B1E13, highContrastDark: 0xFFC9C1)

  private static func adaptive(
    _ light: UInt, _ dark: UInt, highContrastLight: UInt? = nil, highContrastDark: UInt? = nil
  ) -> Color {
    // The four variants are built once. The provider runs every time a view
    // resolves this colour for a trait change or a draw, and used to allocate
    // a new UIColor on each call.
    let lightColor = UIColor(hex: light)
    let darkColor = UIColor(hex: dark)
    let lightContrast = highContrastLight.map { UIColor(hex: $0) } ?? lightColor
    let darkContrast = highContrastDark.map { UIColor(hex: $0) } ?? darkColor
    return Color(
      uiColor: UIColor { traits in
        let increased = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
          ? increased ? darkContrast : darkColor
          : increased ? lightContrast : lightColor
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

/// Corner radii, from DESIGN_SYSTEM_V3: 24 hero, 18 reading card, 16 primary
/// control, with a 12 field radius for inputs and compact controls. Capsules
/// (navigation) use `Capsule()`. Screens adopt these as they are touched; the
/// older 10, 14 and 20 values should map to the nearest token.
enum FormaRadius {
  static let hero: CGFloat = 24
  static let card: CGFloat = 18
  static let control: CGFloat = 16
  static let field: CGFloat = 12
}

/// Spacing on a 4pt grid. Prefer these to literals; 5, 6, 10, 14 and 22 should
/// round to the nearest step.
enum FormaSpacing {
  static let xxs: CGFloat = 4
  static let xs: CGFloat = 8
  static let sm: CGFloat = 12
  static let md: CGFloat = 16
  static let lg: CGFloat = 20
  static let xl: CGFloat = 24
  static let xxl: CGFloat = 32
}

enum FormaFont {
  /// The one style for numbers that change or line up: timers, set readings,
  /// metrics, routine indexes. The default design with fixed-width digits, so a
  /// ticking value does not shift its neighbours. Rounded and monospaced
  /// designs are not used for numerals.
  static func numeral(_ style: Font.TextStyle = .title, weight: Font.Weight = .bold) -> Font {
    .system(style, design: .default, weight: weight).monospacedDigit()
  }
}

struct FormaMark: Shape {
  /// One facet of the mark, or nil for the whole mark. The loading state
  /// assembles the mark facet by facet.
  var facet: Int? = nil

  static let facetCount = 3

  /// Constant geometry, built once instead of on every path request.
  private static let facets: [[CGPoint]] = [
    [.init(x: 18, y: 12), .init(x: 29, y: 12), .init(x: 19, y: 52), .init(x: 8, y: 52)],
    [.init(x: 32, y: 12), .init(x: 58, y: 12), .init(x: 55, y: 23), .init(x: 29, y: 23)],
    [.init(x: 27, y: 29), .init(x: 47, y: 29), .init(x: 44, y: 40), .init(x: 24, y: 40)],
  ]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    for points in facet.map({ [Self.facets[$0]] }) ?? Self.facets {
      path.move(to: CGPoint(x: points[0].x / 64 * rect.width, y: points[0].y / 64 * rect.height))
      for point in points.dropFirst() {
        path.addLine(to: CGPoint(x: point.x / 64 * rect.width, y: point.y / 64 * rect.height))
      }
      path.closeSubpath()
    }
    return path
  }
}

/// FORMA's display face, the website's Barlow Condensed Bold (bundled from
/// public/fonts by scripts/build-ios-media.py, SIL Open Font License). It
/// scales with Dynamic Type relative to `style`. Body text stays on the system
/// font, which reads better at small sizes.
enum FormaDisplayFont {
  static let name = "BarlowCondensed-Bold"

  static func font(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
    .custom(name, size: size, relativeTo: style)
  }
}

struct EditorialTitle: View {
  let text: String
  var body: some View {
    Text(text).font(FormaDisplayFont.font(size: 50, relativeTo: .largeTitle))
      .tracking(-0.6).fixedSize(horizontal: false, vertical: true)
      .foregroundStyle(FormaTheme.primary)
      .accessibilityAddTraits(.isHeader)
  }
}

/// The lime action. The label is ink, never white: ink on lime is 13.2:1 in
/// every appearance, white on lime is 1.2:1.
///
/// Lime is 1.09:1 against the light canvas and 1.18:1 against a white surface,
/// so in light mode the fill alone does not show where the button ends. The
/// button therefore carries a `FormaTheme.accent` edge (6.2:1 against canvas
/// and 6.8:1 against surface; 9.1:1 and 9.8:1 with Increase Contrast), drawn
/// inside the shape so the layout does not change. Increase Contrast doubles
/// its weight. In dark mode `accent` is the lime itself, so the edge vanishes
/// and the fill (14.9:1 against canvas) does the work.
struct PrimaryButtonStyle: ButtonStyle {
  enum Size {
    /// Full width, 56pt minimum: the one main action on a screen.
    case regular
    /// Hugs its label, 44pt minimum: a main action inside a row of controls,
    /// such as starting a timed hold next to its stepper.
    case compact
  }

  @Environment(\.formaMotion) private var motion
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.colorSchemeContrast) private var contrast
  var size: Size = .regular
  /// Set when the button sits on an ink panel such as the Today hero, where the
  /// lime fill is already 14.9:1 against its backdrop and an olive edge would
  /// only muddy it.
  var onDarkSurface = false

  func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(
      cornerRadius: size == .regular ? FormaRadius.control : FormaRadius.field)
    configuration.label
      .font(.headline).foregroundStyle(FormaTheme.ink)
      .frame(maxWidth: size == .regular ? .infinity : nil, minHeight: size == .regular ? 56 : 44)
      .padding(.horizontal, FormaSpacing.md)
      .background(FormaTheme.lime, in: shape)
      .overlay {
        if !onDarkSurface {
          shape.strokeBorder(FormaTheme.accent, lineWidth: contrast == .increased ? 2 : 1)
        }
      }
      .opacity(isEnabled ? configuration.isPressed ? 0.85 : 1 : 0.5)
      .scaleEffect(isEnabled && configuration.isPressed && motion.allowsSpatialMotion ? 0.98 : 1)
      .animation(motion.animation(FormaMotion.press), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
  static var formaPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
  static var formaPrimaryCompact: PrimaryButtonStyle { PrimaryButtonStyle(size: .compact) }
  static var formaPrimaryOnDark: PrimaryButtonStyle { PrimaryButtonStyle(onDarkSurface: true) }
}

struct LocalSaveStatus: View {
  let saving: Bool
  var pendingChanges = false
  /// How to save, named after a control that is on screen when the status
  /// shows. Without one the status just says the edits are unsaved.
  var saveHint: String? = nil
  var body: some View {
    Label(
      saving
        && !pendingChanges
        ? "Saving on this iPhone…"
        : pendingChanges
          ? saveHint.map { "Unsaved edits · \($0)" } ?? "Unsaved edits" : "Saved on this iPhone",
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
