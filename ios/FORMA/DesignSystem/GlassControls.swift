import SwiftUI

/// Liquid Glass belongs to the control layer. Workout values, guides, charts
/// and receipts deliberately keep opaque content surfaces.
private struct ControlSurface: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  let cornerRadius: CGFloat

  @ViewBuilder
  func body(content: Content) -> some View {
    if reduceTransparency || contrast == .increased {
      content
        .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius).stroke(FormaTheme.fieldBorder, lineWidth: 1)
        }
    } else if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
  }
}

extension View {
  func formaControlSurface(cornerRadius: CGFloat = 24) -> some View {
    modifier(ControlSurface(cornerRadius: cornerRadius))
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
