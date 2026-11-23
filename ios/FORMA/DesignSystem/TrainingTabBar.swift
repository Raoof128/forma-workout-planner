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

  /// The filled form shown while the tab is selected. The chart has no
  /// filled form, so it keeps its outline.
  var selectedSymbol: String {
    switch self {
    case .today: "sun.max.fill"
    case .plan: "square.stack.fill"
    case .progress: "chart.xyaxis.line"
    case .you: "person.crop.circle.fill"
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

/// Where the selection bubble sits on the tab row, and which tab a finger on
/// the row is over. The tabs share the row equally, with a fixed gap between.
struct TabBubbleTrack: Equatable {
  let width: CGFloat
  let count: Int
  let spacing: CGFloat

  var slotWidth: CGFloat {
    guard count > 0, width.isFinite else { return 0 }
    return max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
  }

  /// The leading edge of the tab at `index`.
  func leading(of index: Int) -> CGFloat {
    CGFloat(min(max(index, 0), max(count - 1, 0))) * (slotWidth + spacing)
  }

  /// The tab whose centre is nearest `x`; past either end, the end tab.
  func index(at x: CGFloat) -> Int {
    let stride = slotWidth + spacing
    guard count > 0, stride > 0, x.isFinite else { return 0 }
    let nearest = Int(((x - slotWidth / 2) / stride).rounded())
    return min(max(nearest, 0), count - 1)
  }

  /// The bubble's leading edge while a finger holds it at `x`: centred under
  /// the finger and kept inside the row.
  func leading(following x: CGFloat) -> CGFloat {
    guard x.isFinite else { return 0 }
    return min(max(x - slotWidth / 2, 0), max(0, width - slotWidth))
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
  case mediaCredits
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
  /// At the root and already at the top: nothing moves, so nothing is played.
  case alreadyAtTop
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
  /// The height of the floating tab bar (and the resume control above it),
  /// which every tab's screens keep clear at the bottom so their last rows
  /// scroll above the bar instead of ending under it.
  var barInset: CGFloat = 0
  /// True while the software keyboard is on screen. The bar and its clearance
  /// step aside, as the system tab bar stays behind the keyboard instead of
  /// riding above it and taking the space a search or a field needs.
  var keyboardVisible = false
  /// What a tab screen keeps clear at the bottom for the bar right now.
  var bottomClearance: CGFloat { keyboardVisible ? 0 : barInset }
  /// What each tab has pushed, bound to that tab's `NavigationStack`. Clearing
  /// a path returns the tab to its root.
  var paths: [TrainingTab: [TrainingRoute]] = [:]
  /// Counts the root scroll-to-top requests per tab; each tab's root scrolls on a change.
  private(set) var scrollToTopEvents: [TrainingTab: Int] = [:]
  @ObservationIgnored private var scroll = TabBarScrollState()
  /// Whether each tab's root screen rests at its top. Not observed: it changes
  /// on every scroll and only a re-tap reads it. Unknown (iOS 17, or before
  /// the screen first scrolls) counts as "not at the top".
  @ObservationIgnored private var rootAtTop: [TrainingTab: Bool] = [:]
  /// Entrance reveals already played on the tab screens, kept across rebuilt stacks.
  @ObservationIgnored let revealLedger = FormaRevealLedger()

  func observe(offset: CGFloat, limit: CGFloat) {
    scroll.observe(offset: offset, limit: limit)
    if collapsed != scroll.collapsed { collapsed = scroll.collapsed }
  }

  /// Records where a tab's root screen is scrolled to.
  func observeRoot(_ tab: TrainingTab, offset: CGFloat) {
    guard offset.isFinite else { return }
    rootAtTop[tab] = offset <= 1
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
  /// its root; at the root it scrolls to the top, unless it is already there.
  @discardableResult
  func reselect(_ tab: TrainingTab) -> TabReselection {
    expand()
    if paths[tab]?.isEmpty == false {
      paths[tab] = []
      return .poppedToRoot
    }
    if rootAtTop[tab] == true { return .alreadyAtTop }
    scrollToTopEvents[tab, default: 0] += 1
    return .scrolledToTop
  }
}

/// The anchor a tab's first content carries, so re-tapping the tab can scroll there.
enum TabScrollAnchor {
  static let top = "forma.tab.top"
}

/// Feeds the tab's vertical scroll position to the bar. It follows position
/// alone: the scroll phase never left `idle` on device (iOS 26), so a filter
/// on "the person is dragging" stopped the bar from ever collapsing.
/// `TabBarScrollState` already ignores small moves and overscroll, and a
/// programmatic jump to the top only ever expands the bar.
private struct TrainingTabScrollObserver: ViewModifier {
  @Environment(TrainingNavigation.self) private var navigation
  /// Set on a tab's root screen, which also reports whether it is at its top.
  var tab: TrainingTab?

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content
        .onScrollGeometryChange(for: Position.self) { geometry in
          // `containerSize` and `bounds` exclude the insets (on Today, 640 pt
          // of an 812 pt screen), so a limit built from them counted the
          // insets twice: the end of the page was never reached and the
          // rubber-band settle read as scrolling back up, re-opening the bar.
          // `visibleRect` spans the whole viewport, insets included.
          Position(
            offset: geometry.contentOffset.y + geometry.contentInsets.top,
            limit: geometry.contentSize.height + geometry.contentInsets.top
              + geometry.contentInsets.bottom - geometry.visibleRect.height)
        } action: { _, position in
          navigation.observe(offset: position.offset, limit: position.limit)
          if let tab { navigation.observeRoot(tab, offset: position.offset) }
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

/// Keeps a screen's scroll view clear of the floating bar: the content still
/// scrolls under the glass, but its last row can always scroll fully above it.
/// It sits on each scroll view, not on the tab's stack: a stack-level inset
/// never reached Today, which hides its navigation bar. On iOS 26 the space is
/// a `safeAreaBar`, so the scroll view softens content under the bar with its
/// scroll-edge effect, as it does under the system tab bar. While the keyboard
/// is up the bar is hidden and the space is released.
private struct TrainingBarClearance: ViewModifier {
  @Environment(TrainingNavigation.self) private var navigation

  @ViewBuilder
  func body(content: Content) -> some View {
    let spacer = Color.clear.frame(height: navigation.bottomClearance).accessibilityHidden(true)
    if #available(iOS 26.0, *) {
      content.safeAreaBar(edge: .bottom, spacing: 0) { spacer }
    } else {
      content.safeAreaInset(edge: .bottom, spacing: 0) { spacer }
    }
  }
}

private struct TrainingTabRoot: ViewModifier {
  @Environment(TrainingNavigation.self) private var navigation
  @Environment(\.formaMotion) private var motion
  let tab: TrainingTab

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content
        .modifier(TrainingTabScrollObserver(tab: tab))
        .modifier(TrainingBarClearance())
        .environment(\.formaRevealLedger, navigation.revealLedger)
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
      destination(route).modifier(TrainingBarClearance())
    }
  }

  @ViewBuilder private func destination(_ route: TrainingRoute) -> some View {
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
    case .mediaCredits: MediaCreditsView()
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

/// A tab's symbol. Choosing the tab fills it and plays that tab's own effect:
/// the sun turns, the stack lifts layer by layer, the chart draws itself
/// across and the person waves (iOS 18). Where an effect is newer than the
/// system, the symbol bounces instead; below full motion nothing moves.
private struct TabSymbol: View {
  let tab: TrainingTab
  let selected: Bool
  /// Changes once each time the tab is chosen.
  let trigger: Int
  let size: CGFloat
  let animated: Bool

  var body: some View {
    effect(
      Image(systemName: selected ? tab.selectedSymbol : tab.symbol)
        .font(.system(size: size, weight: selected ? .semibold : .medium))
        .contentTransition(animated ? .symbolEffect(.replace) : .identity)
    )
    .symbolEffectsRemoved(!animated)
    // Each effect stays inside the symbol's own frame, so the row never shifts.
    .frame(height: size * 1.2)
  }

  @ViewBuilder private func effect(_ image: some View) -> some View {
    switch tab {
    case .today:
      if #available(iOS 18.0, *) {
        image.symbolEffect(.rotate.clockwise.wholeSymbol, options: .nonRepeating, value: trigger)
      } else {
        image.symbolEffect(.bounce, options: .nonRepeating, value: trigger)
      }
    case .plan:
      image.symbolEffect(.bounce.up.byLayer, options: .nonRepeating, value: trigger)
    case .progress:
      if animated {
        ChartSweep(trigger: trigger) { image }
      } else {
        image
      }
    case .you:
      if #available(iOS 18.0, *) {
        image.symbolEffect(.wiggle.forward.byLayer, options: .nonRepeating, value: trigger)
      } else {
        image.symbolEffect(.bounce, options: .nonRepeating, value: trigger)
      }
    }
  }
}

/// The Progress chart drawing itself from left to right: a faint copy holds
/// the shape while a full-strength copy is revealed across it, with a small
/// lift as it lands. SF Symbols' Draw On needs drawing data this symbol does
/// not have (it played nothing on device), so the reveal is FORMA's own; it
/// runs on every supported system and only changes opacity and a mask.
private struct ChartSweep<Symbol: View>: View {
  let trigger: Int
  @ViewBuilder let symbol: Symbol

  private struct Sweep {
    var reveal = 1.0
    var lift = 0.0
  }

  // One animator drives both copies. An animator placed inside the mask
  // never ran on device, which left the symbol at its faint copy.
  var body: some View {
    symbol.keyframeAnimator(initialValue: Sweep(), trigger: trigger) { content, sweep in
      ZStack {
        content.opacity(0.28)
        content.mask(alignment: .leading) {
          Rectangle().scaleEffect(x: sweep.reveal, y: 1, anchor: .leading)
        }
      }
      .offset(y: -sweep.lift)
    } keyframes: { _ in
      KeyframeTrack(\.reveal) {
        LinearKeyframe(0.0, duration: 0.01)
        // Ease out: the line leaves quickly and settles, like a pen stroke.
        LinearKeyframe(1.0, duration: 0.5, timingCurve: .easeOut)
      }
      KeyframeTrack(\.lift) {
        LinearKeyframe(0.0, duration: 0.4)
        SpringKeyframe(2.5, duration: 0.12)
        SpringKeyframe(0.0, duration: 0.22)
      }
    }
  }
}

/// App-owned symbols run their own SF Symbol effects (`TabSymbol`). The
/// capsule uses Apple's public Liquid Glass API, with an opaque accessibility
/// alternative.
struct TrainingTabBar: View {
  @Environment(AppModel.self) private var model
  @Environment(TrainingNavigation.self) private var navigation
  @Environment(\.formaMotion) private var motion
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @State private var selectionEvents: [TrainingTab: Int] = [:]
  /// The width of the row of four tabs, which places the bubble.
  @State private var rowWidth: CGFloat = 0
  /// Where a finger holds the bubble on the row, while it is being dragged.
  @State private var dragX: CGFloat?
  /// The tab under that finger. It opens only when the finger lifts.
  @State private var hovered: TrainingTab?

  /// The space between tabs, which the bubble's track has to know.
  private static let tabSpacing = FormaSpacing.xxs

  private var compact: Bool {
    navigation.collapsed && motion.allowsSpatialMotion && !textSize.isAccessibilitySize
      && !voiceOver
  }

  /// The opaque Reduce Transparency / Increase Contrast surface, where FORMA's
  /// own colours apply; on glass the foreground follows the material.
  private var opaque: Bool {
    ControlSurfaceAppearance.isOpaque(reduceTransparency: reduceTransparency, contrast: contrast)
  }

  /// Landscape iPhone: icons and labels side by side, as the system tab bar
  /// lays them out in that size class (HIG Tab bars).
  private var sideBySide: Bool { verticalSizeClass == .compact }

  var body: some View {
    HStack {
      if compact { Spacer(minLength: 0) }
      surface {
        HStack(spacing: FormaSpacing.xxs) {
          if compact {
            Button {
              withFormaAnimation(motion, FormaMotion.navigation) { navigation.expand() }
            } label: {
              HStack(spacing: FormaSpacing.xs) {
                Image(systemName: navigation.selection.symbol)
                Text(navigation.selection.title).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up").font(.caption.weight(.bold))
              }
              .padding(.horizontal, FormaSpacing.md).frame(minHeight: 52).contentShape(Capsule())
            }
            .accessibilityLabel("Show all tabs")
            .accessibilityValue("\(navigation.selection.title) selected")
            .accessibilityIdentifier("expand-training-tabs")
          } else {
            tabRow
          }
        }
        .padding(FormaSpacing.xxs)
      }
    }
    // Keep the viewport height stable during a drag, avoiding scroll feedback.
    .frame(minHeight: barHeight, alignment: .trailing)
    .buttonStyle(.plain)
    .foregroundStyle(ControlForeground.primary.style(opaque: opaque))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Training tabs")
    // VoiceOver treats the buttons as an ordered list of tabs ("tab, 1 of 4"),
    // as on the system bar. The single collapsed control is not a tab list.
    .accessibilityAddTraits(compact ? [] : .isTabBar)
    .accessibilityIdentifier("training-tab-bar")
    .animation(motion.animation(FormaMotion.navigation), value: compact)
    .onChange(of: motion) { _, _ in navigation.expand() }
  }

  /// The four tabs over the one selection bubble. The bubble can be pressed
  /// and dragged along the row, like the system tab bar's: it follows the
  /// finger, the tab under it lights up with a selection tick, and lifting the
  /// finger opens that tab. A tap still opens a tab the usual way.
  private var tabRow: some View {
    HStack(spacing: Self.tabSpacing) {
      ForEach(TrainingTab.allCases, id: \.self) { tab in tabButton(tab) }
    }
    .background(alignment: .leading) { bubble }
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
      if rowWidth != width { rowWidth = width }
    }
    // High priority, but it only begins after the finger moves, so a still
    // tap fails it and reaches the tab button; once it begins, the tap is
    // cancelled and the drag alone decides the tab.
    .highPriorityGesture(bubbleDrag)
    // A drag cut short (the keyboard took the bar away) leaves no held bubble.
    .onDisappear {
      dragX = nil
      hovered = nil
    }
  }

  private var track: TabBubbleTrack {
    TabBubbleTrack(width: rowWidth, count: TrainingTab.allCases.count, spacing: Self.tabSpacing)
  }

  /// The tab the bubble shows: the one under a dragging finger, else the open one.
  private var shownTab: TrainingTab { hovered ?? navigation.selection }

  private var bubbleDrag: some Gesture {
    DragGesture(minimumDistance: 10, coordinateSpace: .local)
      .onChanged { value in
        guard rowWidth > 0 else { return }
        let tab = TrainingTab.allCases[track.index(at: value.location.x)]
        if dragX == nil {
          // The bubble lifts and moves under the finger; after that it tracks
          // the finger directly, with no animation in between.
          withFormaAnimation(motion, FormaMotion.tabSelection) { dragX = value.location.x }
        } else {
          dragX = value.location.x
        }
        if hovered != tab {
          // The first tick is skipped: the drag starts over its own tab.
          if hovered != nil || tab != navigation.selection { model.haptic(.selected) }
          hovered = tab
        }
      }
      .onEnded { value in
        guard rowWidth > 0 else { return endDrag() }
        let tab = TrainingTab.allCases[track.index(at: value.location.x)]
        guard tab != navigation.selection else { return endDrag() }
        model.haptic(.tabChanged)
        withFormaAnimation(motion, FormaMotion.tabSelection) {
          dragX = nil
          hovered = nil
          navigation.select(tab)
          selectionEvents[tab, default: 0] += 1
        }
      }
  }

  /// Settles the bubble back on the open tab (a drag that ended where it began).
  private func endDrag() {
    withFormaAnimation(motion, FormaMotion.tabSelection) {
      dragX = nil
      hovered = nil
    }
  }

  /// The tinted capsule behind the shown tab. At full motion it slides between
  /// tabs, follows a dragging finger and swells a little while held; otherwise
  /// it appears under the new tab with a fade.
  @ViewBuilder private var bubble: some View {
    if rowWidth > 0 {
      let held = dragX != nil && motion.allowsSpatialMotion
      let index = TrainingTab.allCases.firstIndex(of: shownTab) ?? 0
      let x = held ? track.leading(following: dragX ?? 0) : track.leading(of: index)
      let capsule = Capsule()
        .fill(FormaTheme.accent.opacity(bubbleOpacity(held: held)))
        .frame(width: track.slotWidth)
        .frame(maxHeight: .infinity)
        // Within the bar's 4 pt padding, so the swell never leaves the glass.
        .scaleEffect(held ? 1.06 : 1)
        .offset(x: x)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      if motion.allowsSpatialMotion {
        capsule
      } else {
        capsule.id(shownTab).transition(.opacity)
      }
    }
  }

  private func bubbleOpacity(held: Bool) -> Double {
    let resting = contrast == .increased ? 0.2 : 0.16
    return held ? resting + 0.06 : resting
  }

  private var barHeight: CGFloat {
    if sideBySide { return 60 }
    return textSize.isAccessibilitySize ? 76 : 72
  }

  private var tabHeight: CGFloat {
    if sideBySide { return 48 }
    return textSize.isAccessibilitySize ? 62 : 56
  }

  /// Selection is shown by the filled symbol, the bold label and the tinted
  /// capsule behind it. Colour goes on that background, not on the label (HIG
  /// Color, Liquid Glass color), except on the opaque surface.
  private func labelStyle(selected: Bool) -> AnyShapeStyle {
    if opaque { return AnyShapeStyle(selected ? FormaTheme.accent : FormaTheme.secondary) }
    return (selected ? ControlForeground.primary : .secondary).style(opaque: false)
  }

  private func tabButton(_ tab: TrainingTab) -> some View {
    // While the bubble is dragged, the tab under it is shown as the selected
    // one; VoiceOver still reports the tab that is open.
    let selected = shownTab == tab
    let layout =
      sideBySide
      ? AnyLayout(HStackLayout(spacing: FormaSpacing.xs))
      : AnyLayout(VStackLayout(spacing: FormaSpacing.xxs))
    return Button {
      guard navigation.selection != tab else {
        // A haptic only when the tap visibly did something (HIG Playing haptics).
        if navigation.reselect(tab) != .alreadyAtTop { model.haptic(.tabReturned) }
        return
      }
      model.haptic(.tabChanged)
      withFormaAnimation(motion, FormaMotion.tabSelection) {
        navigation.select(tab)
        selectionEvents[tab, default: 0] += 1
      }
    } label: {
      layout {
        TabSymbol(
          tab: tab, selected: selected, trigger: selectionEvents[tab, default: 0],
          size: textSize.isAccessibilitySize ? 25 : 21, animated: motion.allowsSpatialMotion)
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
      .foregroundStyle(labelStyle(selected: selected))
      .frame(maxWidth: .infinity, minHeight: tabHeight)
      .contentShape(Capsule())
    }
    .accessibilityLabel(tab.title)
    .accessibilityAddTraits(navigation.selection == tab ? [.isSelected] : [])
    .accessibilityIdentifier("tab-\(tab.rawValue)")
  }

  /// Not interactive: the capsule is a container, and each tab is the control.
  private func surface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content().formaControlSurface(.capsule)
  }
}
