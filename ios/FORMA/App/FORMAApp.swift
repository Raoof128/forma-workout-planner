import FORMACore
import SwiftUI

@main
struct FORMAApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .tint(FormaTheme.accent)
        .task { await model.load() }
    }
  }
}

struct RootView: View {
  @Environment(AppModel.self) private var model
  @State private var selectedTab: TrainingTab = .today

  var body: some View {
    @Bindable var model = model
    Group {
      if model.workspace != nil {
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
        .fullScreenCover(isPresented: $model.workoutPresented) {
          NavigationStack {
            if let receipt = model.receipt {
              WorkoutReceipt(session: receipt)
            } else if model.workspace?.active != nil {
              WorkoutView()
            }
          }
          .environment(model)
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
          FormaMark().fill(FormaTheme.accent).frame(width: 64, height: 64)
          ProgressView("Opening your training space…")
        }
      }
    }
    .background(FormaTheme.canvas)
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
        .tabViewBottomAccessory(isEnabled: model.workspace?.active != nil) {
          if let active = model.workspace?.active { ResumeTrainingControl(session: active) }
        }
        .tabBarMinimizeBehavior(.never)
    } else {
      content.safeAreaInset(edge: .bottom, spacing: 0) {
        if let active = model.workspace?.active {
          ResumeTrainingControl(session: active)
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
  let session: WorkoutSession

  var body: some View {
    Button {
      model.receipt = nil
      model.workoutPresented = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "figure.strengthtraining.traditional").font(.title3)
        VStack(alignment: .leading, spacing: 2) {
          Text("Workout in progress").font(.caption).foregroundStyle(.secondary)
          Text(session.name).font(.subheadline.weight(.semibold))
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
    .accessibilityLabel("Resume \(session.name)")
    .accessibilityHint("Opens your saved active workout.")
    .accessibilityIdentifier("resume-workout-accessory")
    .disabled(model.busy)
  }
}
