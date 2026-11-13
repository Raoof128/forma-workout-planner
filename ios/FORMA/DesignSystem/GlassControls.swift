import SwiftUI

/// The shape of a control surface. Navigation controls (the tab bar and the
/// resume control above it) are capsules; other controls use a token radius.
enum ControlSurfaceShape: Equatable {
  case capsule
  case rounded(CGFloat)
}

/// Whether control surfaces are drawn opaque: Reduce Transparency or Increase
/// Contrast replaces the glass with `FormaTheme.surface` and a visible edge.
/// One rule, so a surface and the text on it always agree about what is behind.
enum ControlSurfaceAppearance {
  static func isOpaque(reduceTransparency: Bool, contrast: ColorSchemeContrast) -> Bool {
    reduceTransparency || contrast == .increased
  }
}

/// Liquid Glass belongs to the control layer. Workout values, guides, charts
/// and receipts deliberately keep opaque content surfaces.
private struct ControlSurface: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  let shape: ControlSurfaceShape
  let interactive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    switch shape {
    case .capsule: surface(content, in: Capsule())
    case .rounded(let radius): surface(content, in: RoundedRectangle(cornerRadius: radius))
    }
  }

  @ViewBuilder
  private func surface(_ content: Content, in shape: some Shape) -> some View {
    if ControlSurfaceAppearance.isOpaque(reduceTransparency: reduceTransparency, contrast: contrast)
    {
      content
        .background(FormaTheme.surface, in: shape)
        .overlay { shape.stroke(FormaTheme.fieldBorder, lineWidth: 1) }
    } else if #available(iOS 26.0, *) {
      // Interactive glass gives a custom control the same press response as
      // a system glass button; a surface that only holds controls stays still.
      content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    } else {
      content.background(.regularMaterial, in: shape)
    }
  }
}

/// Text and symbols on a control surface. On glass (or the material before
/// iOS 26) they use the hierarchical styles, which the material keeps legible
/// over light and dark content alike; a fixed brand colour cannot follow the
/// glass when it darkens over the Today panel (HIG Color, Liquid Glass color;
/// HIG Materials: "use vibrant colors on top of materials"). On the opaque
/// accessibility surface the backdrop is known, so FORMA's own tokens apply.
enum ControlForeground {
  case primary
  case secondary

  func style(opaque: Bool) -> AnyShapeStyle {
    switch (self, opaque) {
    case (.primary, false): AnyShapeStyle(.primary)
    case (.secondary, false): AnyShapeStyle(.secondary)
    case (.primary, true): AnyShapeStyle(FormaTheme.primary)
    case (.secondary, true): AnyShapeStyle(FormaTheme.secondary)
    }
  }
}

private struct ControlForegroundStyle: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  let level: ControlForeground

  func body(content: Content) -> some View {
    content.foregroundStyle(
      level.style(
        opaque: ControlSurfaceAppearance.isOpaque(
          reduceTransparency: reduceTransparency, contrast: contrast)))
  }
}

extension View {
  func formaControlSurface(cornerRadius: CGFloat = 24, interactive: Bool = false) -> some View {
    modifier(ControlSurface(shape: .rounded(cornerRadius), interactive: interactive))
  }

  func formaControlSurface(_ shape: ControlSurfaceShape, interactive: Bool = false) -> some View {
    modifier(ControlSurface(shape: shape, interactive: interactive))
  }

  /// The foreground for text and symbols on `formaControlSurface`.
  func formaControlForeground(_ level: ControlForeground) -> some View {
    modifier(ControlForegroundStyle(level: level))
  }

  /// iOS 26's bar also supplies the system scroll-edge treatment. The earlier
  /// OS path reserves the same space and retains every control.
  @ViewBuilder
  func formaBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
    if #available(iOS 26.0, *) {
      safeAreaBar(edge: .bottom, spacing: 0, content: content)
    } else {
      safeAreaInset(edge: .bottom, spacing: 0, content: content)
    }
  }
}

/// No custom transition or geometry animation: data-entry targets stay still.
struct AdaptiveMetricGroup<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var textSize
  let content: Content

  init(@ViewBuilder content: () -> Content) { self.content = content() }

  var body: some View {
    if textSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 20) { content }
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 28) { content }.fixedSize(
          horizontal: true, vertical: false)
        VStack(alignment: .leading, spacing: 20) { content }
      }
    }
  }
}
