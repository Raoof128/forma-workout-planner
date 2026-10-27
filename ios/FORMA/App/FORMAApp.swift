import FORMACore
import SwiftUI

@main
struct FORMAApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .formaMotionRoot(model.motion)
        .tint(FormaTheme.accent)
        .task { await model.load() }
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @State private var selectedTab: TrainingTab = .today

  var body: some View {
    @Bindable var model = model
    Group {
      // `hasWorkspace` rather than `workspace`: the latter changes on every
      // logged set and would rebuild this whole tree each time.
      if model.hasWorkspace {
        TabView(selection: $selectedTab) {
          NavigationStack { TodayView() }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(TrainingTab.today)
          NavigationStack { PlanView() }
            .tabItem { Label("Plan", systemImage: "square.stack") }
            .tag(TrainingTab.plan)
          NavigationStack { ProgressViewScreen() }
            .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            .accessibilityIdentifier("tab-progress")
            .tag(TrainingTab.progress)
          NavigationStack { YouView() }
            .tabItem { Label("You", systemImage: "person.crop.circle") }
            .tag(TrainingTab.you)
        }
        .modifier(ActiveTrainingAccessory())
        .sheet(item: $model.pendingStart, onDismiss: { model.startSheetDismissed() }) { routine in
          StartWorkoutSheet(routine: routine).environment(model)
        }
        // Clearing the receipt while the cover is still sliding away would
        // re-render it as an empty screen, so clear it once dismissal ends.
        .fullScreenCover(isPresented: $model.workoutPresented, onDismiss: { model.receipt = nil }) {
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
          .interactiveDismissDisabled()
        }
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
}

private enum TrainingTab: Hashable { case today, plan, progress, you }

private struct ActiveTrainingAccessory: ViewModifier {
  @Environment(AppModel.self) private var model

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 26.1, *) {
      content
        .tabViewBottomAccessory(isEnabled: model.activeWorkoutName != nil) {
          if let name = model.activeWorkoutName { ResumeTrainingControl(name: name) }
        }
        .tabBarMinimizeBehavior(.never)
    } else {
      content.safeAreaInset(edge: .bottom, spacing: 0) {
        if let name = model.activeWorkoutName {
          ResumeTrainingControl(name: name)
            .formaControlSurface(cornerRadius: 20)
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
      }
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
