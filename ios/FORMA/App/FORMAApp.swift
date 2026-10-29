import FORMACore
import FORMASurfaces
import SwiftUI

@main
struct FORMAApp: App {
  @State private var model = AppModel()
  @Environment(\.scenePhase) private var scenePhase

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
        }
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @State private var navigation = TrainingNavigation()
  @State private var todayPath: [String] = []
  @State private var workoutCoverVisible = false
  @State private var widgetNavigationIDs: [TrainingTab: UUID] = [:]

  var body: some View {
    @Bindable var model = model
    @Bindable var navigation = navigation
    Group {
      // `hasWorkspace` rather than `workspace`: the latter changes on every
      // logged set and would rebuild this whole tree each time.
      if model.hasWorkspace {
        TabView(selection: $navigation.selection) {
          NavigationStack(path: $todayPath) {
            TodayView()
              .navigationDestination(for: String.self) { id in
                if let routine = model.routines.first(where: { $0.id == id }) {
                  RoutineDetailView(routine: routine)
                } else {
                  ContentUnavailableView(
                    "Routine unavailable", systemImage: "square.stack",
                    description: Text("Return to Plan to choose a current routine."))
                }
              }
          }
          .id(widgetNavigationIDs[.today])
          .toolbar(.hidden, for: .tabBar)
          .tabItem { Label("Today", systemImage: "sun.max") }
          .tag(TrainingTab.today)
          NavigationStack { PlanView() }
            .id(widgetNavigationIDs[.plan])
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Plan", systemImage: "square.stack") }
            .tag(TrainingTab.plan)
          NavigationStack { ProgressViewScreen() }
            .id(widgetNavigationIDs[.progress])
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            .tag(TrainingTab.progress)
          NavigationStack { YouView() }
            .id(widgetNavigationIDs[.you])
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("You", systemImage: "person.crop.circle") }
            .tag(TrainingTab.you)
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
            "Your training couldn't be opened", systemImage: "externaldrive.badge.exclamationmark")
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
      todayPath = []
      navigation.select(.today)
    }
    .onChange(of: model.widgetRoute) { handleWidgetRoute() }
    .onChange(of: model.hasWorkspace) { handleWidgetRoute() }
    .onChange(of: model.widgetEditingCount) { handleWidgetRoute() }
    .onChange(of: model.busy) { handleWidgetRoute() }
    .onAppear { handleWidgetRoute() }
    .alert(
      "Widget updated",
      isPresented: Binding(
        get: { model.widgetNotice != nil }, set: { if !$0 { model.widgetNotice = nil } }
      )
    ) {
      Button("OK", role: .cancel) { model.widgetNotice = nil }
    } message: {
      Text(model.widgetNotice ?? "")
    }
    .preferredColorScheme(
      model.appearance == .system ? nil : model.appearance == .dark ? .dark : .light
    )
    .alert(
      "Couldn't save this change",
      isPresented: Binding(
        get: { model.errorMessage != nil && !model.workoutPresented },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("Keep editing", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Your last saved workout has been preserved.")
    }
  }

  private func openWidgetTab(_ tab: TrainingTab) {
    widgetNavigationIDs[tab] = UUID()
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
      todayPath = []
      openWidgetTab(.today)
    case .plan: openWidgetTab(.plan)
    case .progress: openWidgetTab(.progress)
    case .settings: openWidgetTab(.you)
    case .routine(let id):
      openWidgetTab(.today)
      todayPath = [id]
    case .active:
      model.receipt = nil
      model.workoutPresented = true
    case .unavailable:
      openWidgetTab(.today)
      todayPath = []
      model.widgetNotice =
        "That saved item is no longer available for this training space. Choose a current routine in Plan."
    }
  }
}

private struct ActiveTrainingAccessory: ViewModifier {
  @Environment(AppModel.self) private var model

  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: 4) {
        if let name = model.activeWorkoutName {
          ResumeTrainingControl(name: name)
            .formaControlSurface(cornerRadius: 20)
        }
        TrainingTabBar()
      }
      .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 4)
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
      HStack(spacing: 12) {
        Image(systemName: "figure.strengthtraining.traditional").font(.title3)
        VStack(alignment: .leading, spacing: 2) {
          Text("Workout in progress").font(.caption).foregroundStyle(.secondary)
          Text(name).font(.subheadline.weight(.semibold))
            .lineLimit(textSize.isAccessibilitySize ? nil : 1)
        }
        Spacer(minLength: 4)
        Image(systemName: "play.fill").font(.body.weight(.semibold))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 16).padding(.vertical, 10)
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Resume \(name)")
    .accessibilityHint("Opens your saved active workout.")
    .accessibilityIdentifier("resume-workout-accessory")
    .disabled(model.busy)
  }
}
