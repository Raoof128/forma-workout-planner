import Observation
import SwiftUI

enum TrainingTab: String, CaseIterable, Hashable {
  case today, plan, progress, you

  var title: String {
    switch self {
    case .today: "Today"
    case .plan: "Plan"
    case .progress: "Progress"
    case .you: "You"
    }
  }

  var symbol: String {
    switch self {
    case .today: "sun.max"
    case .plan: "square.stack"
    case .progress: "chart.xyaxis.line"
    case .you: "person.crop.circle"
    }
  }
}

/// Directional distance prevents flicker from small movements and overscroll.
struct TabBarScrollState {
  private var previous: CGFloat?
  private var travel: CGFloat = 0
  private(set) var collapsed = false

  mutating func observe(offset: CGFloat, limit: CGFloat) {
    guard offset.isFinite, limit.isFinite else { return }
    let position = min(max(0, offset), max(0, limit))
    defer { previous = position }
    guard limit > 40, position > 8 else {
      collapsed = false
      travel = 0
      return
    }
    guard let previous else { return }
    let delta = position - previous
    if delta == 0 { return }
    if (delta > 0) != (travel > 0) { travel = 0 }
    travel += delta
    if travel >= 32 { collapsed = true }
    if travel <= -16 { collapsed = false }
  }
}

@MainActor @Observable
final class TrainingNavigation {
  var selection: TrainingTab = .today
  private(set) var collapsed = false
  @ObservationIgnored private var scroll = TabBarScrollState()

  func observe(offset: CGFloat, limit: CGFloat) {
    scroll.observe(offset: offset, limit: limit)
    if collapsed != scroll.collapsed { collapsed = scroll.collapsed }
  }

  func expand() {
    scroll = TabBarScrollState()
    collapsed = false
  }

  func select(_ tab: TrainingTab) {
    selection = tab
    expand()
  }
}

private struct TrainingTabScrollObserver: ViewModifier {
  @Environment(TrainingNavigation.self) private var navigation
  @State private var userScrolling = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content
        .onScrollPhaseChange { _, phase in
          userScrolling = phase == .interacting || phase == .decelerating
        }
        .onScrollGeometryChange(for: Position.self) { geometry in
          Position(
            offset: geometry.contentOffset.y + geometry.contentInsets.top,
            limit: geometry.contentSize.height + geometry.contentInsets.top
              + geometry.contentInsets.bottom - geometry.containerSize.height)
        } action: { _, position in
          guard userScrolling else { return }
          navigation.observe(offset: position.offset, limit: position.limit)
        }
    } else {
      content
    }
  }

  private struct Position: Equatable {
    let offset: CGFloat
    let limit: CGFloat
  }
}

extension View {
  /// Only primary tab scroll views drive the bar; editors stay still.
  func formaTabScrollObserver() -> some View {
    modifier(TrainingTabScrollObserver())
  }
}

/// App-owned symbols can run a discrete SF Symbol effect. The capsule uses
/// Apple's public Liquid Glass API, with an opaque accessibility alternative.
struct TrainingTabBar: View {
  @Environment(TrainingNavigation.self) private var navigation
  @Environment(\.formaMotion) private var motion
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Namespace private var highlight
  @State private var selectionEvents: [TrainingTab: Int] = [:]

  private var compact: Bool {
    navigation.collapsed && motion.allowsSpatialMotion && !textSize.isAccessibilitySize
      && !voiceOver
  }

  var body: some View {
    HStack {
      if compact { Spacer(minLength: 0) }
      surface {
        HStack(spacing: 4) {
          if compact {
            Button {
              withFormaAnimation(motion, FormaMotion.navigation) { navigation.expand() }
            } label: {
              HStack(spacing: 10) {
                Image(systemName: navigation.selection.symbol)
                Text(navigation.selection.title).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up").font(.caption.weight(.bold))
              }
              .padding(.horizontal, 16).frame(minHeight: 52).contentShape(Capsule())
            }
            .accessibilityLabel("Show all tabs")
            .accessibilityValue("\(navigation.selection.title) selected")
            .accessibilityIdentifier("expand-training-tabs")
          } else {
            ForEach(TrainingTab.allCases, id: \.self) { tab in tabButton(tab) }
          }
        }
        .padding(5)
      }
    }
    // Keep the viewport height stable during a drag, avoiding scroll feedback.
    .frame(minHeight: textSize.isAccessibilitySize ? 76 : 72, alignment: .trailing)
    .buttonStyle(.plain)
    .foregroundStyle(FormaTheme.primary)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Training tabs")
    .accessibilityIdentifier("training-tab-bar")
    .animation(motion.animation(FormaMotion.navigation), value: compact)
    .onChange(of: motion) { _, _ in navigation.expand() }
  }

  private func tabButton(_ tab: TrainingTab) -> some View {
    let selected = navigation.selection == tab
    return Button {
      guard navigation.selection != tab else { return }
      withFormaAnimation(motion, FormaMotion.navigation) {
        navigation.select(tab)
        selectionEvents[tab, default: 0] += 1
      }
    } label: {
      VStack(spacing: 5) {
        Image(systemName: tab.symbol)
          .font(.system(size: textSize.isAccessibilitySize ? 25 : 21, weight: .medium))
          .symbolEffect(.bounce, options: .nonRepeating, value: selectionEvents[tab, default: 0])
          .symbolEffectsRemoved(!motion.allowsSpatialMotion)
        if !textSize.isAccessibilitySize {
          Text(tab.title).font(.caption2.weight(selected ? .bold : .medium)).lineLimit(1)
        }
      }
      .foregroundStyle(selected ? FormaTheme.accent : FormaTheme.secondary)
      .frame(maxWidth: .infinity, minHeight: textSize.isAccessibilitySize ? 62 : 56)
      .background {
        if selected {
          Capsule().fill(FormaTheme.accent.opacity(contrast == .increased ? 0.2 : 0.12))
            .matchedGeometryEffect(id: "selected-tab", in: highlight)
        }
      }
      .contentShape(Capsule())
    }
    .accessibilityLabel(tab.title)
    .accessibilityValue("Tab \((TrainingTab.allCases.firstIndex(of: tab) ?? 0) + 1) of 4")
    .accessibilityAddTraits(selected ? [.isSelected] : [])
    .accessibilityIdentifier("tab-\(tab.rawValue)")
  }

  @ViewBuilder
  private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if reduceTransparency || contrast == .increased {
      content().background(FormaTheme.surface, in: Capsule())
        .overlay { Capsule().stroke(FormaTheme.fieldBorder, lineWidth: 1) }
    } else if #available(iOS 26.0, *) {
      content().glassEffect(.regular.interactive(), in: .capsule)
    } else {
      content().background(.regularMaterial, in: Capsule())
    }
  }
}
