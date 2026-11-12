import FORMACore
import FORMASurfaces
import SwiftUI
import UIKit

@main
struct FORMAApp: App {
  @State private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let model = AppModel()
    _model = State(initialValue: model)
    // Set before any scene exists: a Lock Screen button press can launch the app with no window.
    LiveActivityActions.handler = { [weak model] action in await model?.perform(action) }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .formaMotionRoot(model.motion)
        .tint(FormaTheme.accent)
        .task { await model.load() }
        .onOpenURL { url in
          if let route = WidgetRoute(url: url) { model.widgetRoute = route }
        }
        .task(id: scenePhase) {
          guard scenePhase == .active else { return }
          // A boundary tick, not a per-second timer; guest training also rolls over at midnight.
          while !Task.isCancelled {
            let now = Date.now
            let next =
              TrainingDate.calendar.date(
                byAdding: .day, value: 1,
                to: TrainingDate.calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
            do { try await Task.sleep(for: .seconds(max(1, next.timeIntervalSince(now)))) } catch {
              return
            }
            model.refreshTrainingClock()
          }
        }
        // Returning to the app fetches the account's copy and sends anything
        // waiting. Launch does the same from `load()`.
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { Task { await model.sceneBecameActive() } }
          if phase == .background { model.widgets.requestReload() }
          // The workout screen arms the rest reminder while it is open; this
          // covers a rest left running after Save & close.
          Task {
            await RestReminder.shared.sync(
              restEnd: model.workspace?.active?.restEnd,
              muted: model.workspace?.profile.muted ?? false, appActive: phase == .active)
          }
        }
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @State private var navigation = TrainingNavigation()
  @State private var workoutCoverVisible = false
  @State private var widgetNavigationIDs: [TrainingTab: UUID] = [:]

  var body: some View {
    @Bindable var model = model
    @Bindable var navigation = navigation
    Group {
      // `hasWorkspace` rather than `workspace`: the latter changes on every
      // logged set and would rebuild this whole tree each time.
      if model.hasWorkspace {
        TrainingTabs(selection: $navigation.selection) { tab in
          tabStack(tab)
        }
        .toolbar(.hidden, for: .tabBar)
        // A different owner (guest or a member) starts every screen afresh, so
        // nothing pushed earlier can keep showing another account's training.
        .id(model.storeIdentity)
        .modifier(ActiveTrainingAccessory())
        .sheet(
          item: $model.pendingStart,
          onDismiss: {
            model.startSheetDismissed()
            handleWidgetRoute()
          }
        ) { routine in
          StartWorkoutSheet(routine: routine).environment(model)
        }
        // Clearing the receipt while the cover is still sliding away would
        // re-render it as an empty screen, so clear it once dismissal ends.
        .fullScreenCover(
          isPresented: $model.workoutPresented,
          onDismiss: {
            workoutCoverVisible = false
            model.receipt = nil
            handleWidgetRoute()
          }
        ) {
          NavigationStack {
            if let receipt = model.receipt {
              WorkoutReceipt(session: receipt)
                .transition(motion.transition(.opacity.combined(with: .scale(scale: 0.98))))
            } else if model.workspace?.active != nil {
              WorkoutView()
                .transition(.opacity)
            }
          }
          // The receipt exists only after the finished workout is saved, so
          // this hand-off follows the durable result.
          .animation(motion.animation(FormaMotion.navigation), value: model.receipt != nil)
          .environment(model)
          .environment(\.formaMotion, motion)
          .onAppear { workoutCoverVisible = true }
          .onDisappear { workoutCoverVisible = false }
          .onOpenURL { model.receiveWidgetURL($0) }
          .interactiveDismissDisabled()
        }
      } else if let gate = model.accountGate {
        AccountGateView(gate: gate)
      } else if let failure = model.loadFailure {
        ContentUnavailableView {
          Label(
            "Your training couldn’t be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
          Text(failure)
        } actions: {
          Button("Try again") { Task { await model.load() } }
            .buttonStyle(PrimaryButtonStyle())
        }
      } else {
        VStack(spacing: 24) {
          FormaLoadingMark().frame(width: 64, height: 64)
          ProgressView("Opening your training space…")
        }
        .transition(.opacity)
      }
    }
    // The opened workspace cross-fades in over the loading state rather than
    // cutting to it.
    .animation(motion.animation(FormaMotion.reveal), value: model.hasWorkspace)
    // Fill the whole window so the loading state continues the launch
    // screen's colour instead of flashing the default white around it.
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FormaTheme.canvas.ignoresSafeArea())
    .background { FormaHapticRelay() }
    .environment(navigation)
    .onChange(of: model.storeIdentity) { _, _ in
      navigation.popAllToRoot()
      navigation.select(.today)
    }
    .onChange(of: model.widgetRoute) { handleWidgetRoute() }
    .onChange(of: model.hasWorkspace) { handleWidgetRoute() }
    .onChange(of: model.widgetEditingCount) { handleWidgetRoute() }
    .onChange(of: model.busy) { handleWidgetRoute() }
    .onAppear { handleWidgetRoute() }
    .preferredColorScheme(
      model.appearance == .system ? nil : model.appearance == .dark ? .dark : .light
    )
    .modifier(RootAlerts(navigation: navigation))
  }

  /// One tab: its own navigation stack, bound to the path the tab bar can clear.
  private func tabStack(_ tab: TrainingTab) -> some View {
    let path = Binding(
      get: { navigation.paths[tab] ?? [] }, set: { navigation.paths[tab] = $0 })
    return NavigationStack(path: path) {
      tabRoot(tab).trainingDestinations()
    }
    .id(widgetNavigationIDs[tab])
    .toolbar(.hidden, for: .tabBar)
  }

  @ViewBuilder
  private func tabRoot(_ tab: TrainingTab) -> some View {
    switch tab {
    case .today: TodayView()
    case .plan: PlanView()
    case .progress: ProgressViewScreen()
    case .you: YouView()
    }
  }

  private func openWidgetTab(_ tab: TrainingTab) {
    widgetNavigationIDs[tab] = UUID()
    // The stack is rebuilt, so a path left from before would push again.
    navigation.paths[tab] = []
    navigation.select(tab)
  }

  private func handleWidgetRoute() {
    guard model.hasWorkspace, let route = model.widgetRoute else { return }
    let destination = model.widgetDestination(for: route)
    guard model.widgetEditingCount == 0, !model.busy else { return }
    if destination != .active {
      if model.workoutPresented || workoutCoverVisible {
        if model.receipt != nil { model.workoutPresented = false }
        // A widget must never bypass the workout's validation/Save & close guard.
        // The workout shows a queued-link banner and onDismiss drains this route.
        return
      }
      guard model.pendingStart == nil else { return }
    }
    model.widgetRoute = nil
    switch destination {
    case .today:
      openWidgetTab(.today)
    case .plan: openWidgetTab(.plan)
    case .progress: openWidgetTab(.progress)
    case .settings:
      // The widget's "Enable widgets in You" prompt: land on the sharing toggle.
      navigation.youFocus = .widgetSharing
      openWidgetTab(.you)
    case .routine(let id):
      openWidgetTab(.today)
      navigation.paths[.today] = [.routine(id)]
    case .active:
      model.receipt = nil
      model.workoutPresented = true
    case .unavailable:
      // The notice sends the person to Plan, so that is where it opens.
      openWidgetTab(.plan)
      model.widgetNotice =
        "That saved item is no longer available for this training space. Choose a current routine in Plan."
    }
  }
}

/// The four tabs, in `TrainingTab` order. The system bar is hidden (FORMA
/// draws its own), so a tab's title and symbol only identify it. `Tab` from
/// iOS 18; `tabItem`, deprecated in the iOS 27.2 SDK, only where `Tab` does not exist.
private struct TrainingTabs<Content: View>: View {
  @Binding var selection: TrainingTab
  @ViewBuilder let content: (TrainingTab) -> Content

  var body: some View {
    if #available(iOS 18.0, *) {
      TabView(selection: $selection) {
        ForEach(TrainingTab.allCases, id: \.self) { tab in
          Tab(tab.title, systemImage: tab.symbol, value: tab) { content(tab) }
        }
      }
    } else {
      TabView(selection: $selection) {
        ForEach(TrainingTab.allCases, id: \.self) { tab in
          content(tab)
            .tabItem { Label(tab.title, systemImage: tab.symbol) }
            .tag(tab)
        }
      }
    }
  }
}

/// The floating tab bar and resume control. A `safeAreaInset` on the
/// `TabView` does not reach the tabs' scroll views (the hidden system tab bar
/// owns their insets), so each page ended under the bar. The bar floats as an
/// overlay instead and reports its height; every tab screen's scroll view
/// keeps that much clear at the bottom (`TrainingBarClearance`).
///
/// While the keyboard is up the bar steps aside, as the system tab bar stays
/// behind the keyboard: riding above it covered search results and the field
/// being typed in. It ignores the keyboard's safe area so it leaves from, and
/// returns to, its own place at the bottom instead of jumping above the keys.
private struct ActiveTrainingAccessory: ViewModifier {
  @Environment(AppModel.self) private var model
  @Environment(TrainingNavigation.self) private var navigation
  @Environment(\.formaMotion) private var motion

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        // The animation is scoped to the bar, so the tab screens behind it
        // follow the keyboard as they always have.
        ZStack {
          if !navigation.keyboardVisible {
            bar.transition(motion.transition(.opacity.combined(with: .move(edge: .bottom))))
          }
        }
        .animation(motion.animation(FormaMotion.reveal), value: navigation.keyboardVisible)
        .ignoresSafeArea(.keyboard, edges: .bottom)
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
      ) { _ in
        if !navigation.keyboardVisible { navigation.keyboardVisible = true }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
      ) { _ in
        if navigation.keyboardVisible { navigation.keyboardVisible = false }
      }
  }

  private var bar: some View {
    // One container, so the two glass surfaces 4pt apart sample the same
    // backdrop and never merge (the container spacing is below the gap).
    GlassGroup(spacing: 2) {
      VStack(spacing: FormaSpacing.xxs) {
        if let name = model.activeWorkoutName {
          // A capsule like the bar beneath it; interactive glass, as it is one
          // whole-surface button.
          ResumeTrainingControl(name: name)
            .formaControlSurface(.capsule, interactive: true)
        }
        TrainingTabBar()
      }
      // In landscape the bar keeps a phone-width capsule instead of spanning
      // the screen (no effect in portrait, where every iPhone is narrower).
      .frame(maxWidth: 480)
    }
    .padding(.horizontal, FormaSpacing.md).padding(.vertical, FormaSpacing.xxs)
    .frame(maxWidth: .infinity)
    .background {
      GeometryReader { proxy in
        Color.clear.preference(key: TrainingBarHeightKey.self, value: proxy.size.height)
      }
    }
    .onPreferenceChange(TrainingBarHeightKey.self) { height in
      // Whole points only, so sub-point layout jitter never re-lays out every tab.
      let rounded = height.rounded(.up)
      if navigation.barInset != rounded { navigation.barInset = rounded }
    }
  }
}

private struct TrainingBarHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Adjacent Liquid Glass surfaces share a `GlassEffectContainer` on iOS 26.
private struct GlassGroup<Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) { content }
    } else {
      content
    }
  }
}

private struct ResumeTrainingControl: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var textSize
  /// The name alone: a whole session changes with every logged set.
  let name: String

  var body: some View {
    Button {
      model.receipt = nil
      model.workoutPresented = true
    } label: {
      HStack(spacing: FormaSpacing.sm) {
        Image(systemName: "figure.strengthtraining.traditional").font(.title3)
        VStack(alignment: .leading, spacing: 2) {
          Text("Workout in progress").font(.caption).formaControlForeground(.secondary)
          Text(name).font(.subheadline.weight(.semibold))
            .lineLimit(textSize.isAccessibilitySize ? nil : 1)
        }
        Spacer(minLength: FormaSpacing.xxs)
        Image(systemName: "play.fill").font(.body.weight(.semibold))
      }
      // On glass the text follows the material, which keeps it legible over
      // the dark Today panel as well as light rows; FORMA's colours return on
      // the opaque accessibility surface.
      .formaControlForeground(.primary)
      // Clear of the capsule's rounded ends.
      .padding(.horizontal, FormaSpacing.lg).padding(.vertical, FormaSpacing.xs)
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Resume \(name)")
    .accessibilityHint("Opens your saved active workout.")
    .accessibilityIdentifier("resume-workout-accessory")
    .disabled(model.busy)
  }
}

/// The root's alerts, kept out of `RootView.body` so the compiler can type-check
/// that chain in reasonable time.
private struct RootAlerts: ViewModifier {
  @Environment(AppModel.self) private var model
  let navigation: TrainingNavigation

  func body(content: Content) -> some View {
    content
      .alert(
        "Link unavailable",
        isPresented: Binding(
          get: { model.widgetNotice != nil }, set: { if !$0 { model.widgetNotice = nil } }
        )
      ) {
        Button("OK", role: .cancel) { model.widgetNotice = nil }
      } message: {
        Text(model.widgetNotice ?? "")
      }
      // A failure reported with its own title (a deletion, a setting, a
      // sign-out clean-up) is named as itself; any other is a change that
      // was not saved. "OK" because often nothing is left to edit.
      .alert(
        model.errorTitle ?? "Couldn’t save this change",
        isPresented: Binding(
          get: { model.errorMessage != nil && !model.workoutPresented },
          set: { if !$0 { model.errorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) { model.errorMessage = nil }
      } message: {
        Text(model.errorMessage ?? "Your last saved workout has been preserved.")
      }
      // The account ended this sign-in on its own: say why, and what happened
      // to the training and any open workout. Sign in continues on You.
      .alert(
        model.account.interruption?.title ?? "",
        isPresented: Binding(
          get: { model.account.interruption != nil },
          set: { if !$0 { model.account.dismissInterruption() } }),
        presenting: model.account.interruption
      ) { interruption in
        Button(interruption.signInTitle) {
          navigation.select(.you)
          model.account.signInFromInterruption()
        }
        Button(interruption.dismissTitle, role: .cancel) {}
      } message: {
        Text($0.message)
      }
  }
}
