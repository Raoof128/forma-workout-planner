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

/// A screen pushed onto a tab's navigation stack. It holds ids, not models, so
/// a screen always shows the current saved data and a removed item is reported
/// in place instead of lingering in the path.
enum TrainingRoute: Hashable {
  case routine(String)
  case session(String)
  case guide(String)
  case trainingDays
  case exerciseLibrary
  case privacy
  // Account screens under You, so re-tapping You returns from them too.
  case syncDetails
  case accountProfile
  case accountSecurity
  case trainingData
  case accountPrivacy
  case changePassword
  case twoFactor
  case sessions
  case coachAccess
}

/// What tapping the already-selected tab did, like the system tab bar: a tab
/// deep in a stack returns to its root; at the root it scrolls to the top.
enum TabReselection: Equatable {
  case poppedToRoot
  case scrolledToTop
}

/// A place on the You screen that another part of the app asks to be shown.
enum YouFocus: Hashable {
  /// The "Share training with widgets" toggle, which a widget's consent prompt points to.
  case widgetSharing
}

@MainActor @Observable
final class TrainingNavigation {
  var selection: TrainingTab = .today
  /// Set before opening You; the screen scrolls there, then clears it.
  var youFocus: YouFocus?
  private(set) var collapsed = false
  /// What each tab has pushed, bound to that tab's `NavigationStack`. Clearing
  /// a path returns the tab to its root.
  var paths: [TrainingTab: [TrainingRoute]] = [:]
  /// Counts the root scroll-to-top requests per tab; each tab's root scrolls on a change.
  private(set) var scrollToTopEvents: [TrainingTab: Int] = [:]
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

  /// Returns every tab to its root, as when a different training space opens.
  func popAllToRoot() {
    paths = [:]
  }

  /// Handles a tap on the selected tab. A tab with screens pushed returns to
  /// its root; at the root it scrolls to the top.
  @discardableResult
  func reselect(_ tab: TrainingTab) -> TabReselection {
    expand()
    if paths[tab]?.isEmpty == false {
      paths[tab] = []
      return .poppedToRoot
    }
    scrollToTopEvents[tab, default: 0] += 1
    return .scrolledToTop
  }
}

/// The anchor a tab's first content carries, so re-tapping the tab can scroll there.
enum TabScrollAnchor {
  static let top = "forma.tab.top"
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

private struct TrainingTabRoot: ViewModifier {
  @Environment(TrainingNavigation.self) private var navigation
  @Environment(\.formaMotion) private var motion
  let tab: TrainingTab

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content
        .modifier(TrainingTabScrollObserver())
        .onChange(of: navigation.scrollToTopEvents[tab, default: 0]) {
          withFormaAnimation(motion, FormaMotion.navigation) {
            proxy.scrollTo(TabScrollAnchor.top, anchor: .top)
          }
        }
    }
  }
}

/// The screens a tab can push. Every tab's stack registers the same set, so a
/// link can name its destination with a `TrainingRoute` from any tab.
private struct TrainingDestinations: ViewModifier {
  @Environment(AppModel.self) private var model

  func body(content: Content) -> some View {
    content.navigationDestination(for: TrainingRoute.self) { route in
      switch route {
      case .routine(let id): RoutineDetailView(routineID: id)
      case .session(let id): SessionDetailView(sessionID: id)
      case .guide(let id):
        if let exercise = model.exercise(id) {
          GuideView(exercise: exercise)
        } else {
          ContentUnavailableView(
            "This exercise is unavailable", systemImage: "book",
            description: Text("Return to the exercise library to choose another."))
        }
      case .trainingDays: TrainingDaysView()
      case .exerciseLibrary: ExerciseLibraryView()
      case .privacy: NativePrivacyView()
      case .syncDetails: SyncDetailsView()
      case .accountProfile: AccountProfileView()
      case .accountSecurity: AccountSecurityView()
      case .trainingData: TrainingDataView()
      case .accountPrivacy: AccountPrivacyView()
      case .changePassword: ChangePasswordView()
      case .twoFactor: TwoFactorView()
      case .sessions: SessionsView()
      case .coachAccess: CoachAccessView()
      }
    }
  }
}

extension View {
  /// Registers the screens a tab can push; put it on a stack's root view.
  func trainingDestinations() -> some View {
    modifier(TrainingDestinations())
  }

  /// Only primary tab scroll views drive the bar; editors stay still.
  func formaTabScrollObserver() -> some View {
    modifier(TrainingTabScrollObserver())
  }

  /// A tab's root screen: drives the bar like `formaTabScrollObserver`, and
  /// answers a re-tap of its tab. Put `.id(TabScrollAnchor.top)` on the first
  /// row or block of its scroll view.
  func formaTabRoot(_ tab: TrainingTab) -> some View {
    modifier(TrainingTabRoot(tab: tab))
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
      guard navigation.selection != tab else {
        navigation.reselect(tab)
        return
      }
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
        // The label stays at every size: it scales with the text, up to a cap
        // that keeps four tabs on one row, and shrinks a little before it clips.
        // The large content viewer shows the full-size title and symbol.
        Text(tab.title).font(.caption2.weight(selected ? .bold : .medium)).lineLimit(1)
          .minimumScaleFactor(textSize.isAccessibilitySize ? 0.6 : 1)
          .dynamicTypeSize(...DynamicTypeSize.accessibility1)
      }
      .accessibilityShowsLargeContentViewer {
        Label(tab.title, systemImage: tab.symbol)
      }
      .foregroundStyle(selected ? FormaTheme.accent : FormaTheme.secondary)
      .frame(maxWidth: .infinity, minHeight: textSize.isAccessibilitySize ? 62 : 56)
      .background {
        if selected {
          // The capsule slides between tabs only at full motion; otherwise it
          // appears under the new tab with a fade.
          let capsule = Capsule().fill(
            FormaTheme.accent.opacity(contrast == .increased ? 0.2 : 0.12))
          if motion.allowsSpatialMotion {
            capsule.matchedGeometryEffect(id: "selected-tab", in: highlight)
          } else {
            capsule.transition(.opacity)
          }
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
      // Not interactive: the capsule is a container, and each tab is the control.
      content().glassEffect(.regular, in: .capsule)
    } else {
      content().background(.regularMaterial, in: Capsule())
    }
  }
}
