import FORMACore
import SwiftUI

/// Shown only when an Apple Watch is paired. The workout begins when Start is
/// pressed on the Watch, or on this iPhone alone if the person prefers.
struct StartWorkoutSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let routine: Routine
  /// In-button progress, so each tap is acknowledged while its await runs.
  @State private var opening = false
  @State private var starting = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NEXT SESSION").font(.caption.weight(.bold)).tracking(2)
              .foregroundStyle(FormaTheme.accent)
            EditorialTitle(text: routine.name)
            Text("\(routine.exercises.count) exercises · about \(routine.minutes) min")
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
          }
          status
            .formaAnimation(FormaMotion.state, value: model.watch.availability)
            .formaAnimation(FormaMotion.state, value: model.watch.phase)
          if let notice = model.watch.notice {
            Label(notice, systemImage: "exclamationmark.circle")
              .font(.subheadline).foregroundStyle(FormaTheme.error)
              .accessibilityIdentifier("watch-start-notice")
          }
          VStack(spacing: 12) {
            if model.watch.availability == .ready, model.watch.phase == .idle {
              Button {
                opening = true
                Task {
                  await model.watch.open(routine: routine)
                  opening = false
                }
              } label: {
                Label {
                  Text("Open FORMA on Apple Watch")
                } icon: {
                  if opening {
                    ProgressView().tint(FormaTheme.ink)
                  } else {
                    Image(systemName: "applewatch")
                  }
                }
              }
              .buttonStyle(PrimaryButtonStyle())
              .disabled(opening)
              .accessibilityValue(opening ? "Opening" : "")
              .accessibilityIdentifier("watch-open")
            } else if model.watch.availability != .ready {
              Button {
                Task { await model.watch.refresh() }
              } label: {
                Label("Check again", systemImage: "arrow.clockwise")
              }
              .buttonStyle(.bordered)
              .disabled(model.watch.availability == .checking)
            }
            Button {
              starting = true
              Task {
                await model.start(routine)
                starting = false
              }
            } label: {
              HStack(spacing: 10) {
                if starting { ProgressView() }
                Text("Start on iPhone only")
              }
              .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.busy || starting)
            .accessibilityValue(starting ? "Starting" : "")
            .accessibilityIdentifier("start-on-iphone")
          }
        }
        .padding(24)
      }
      .background(FormaTheme.canvas)
      .navigationTitle("Start workout").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .task {
      if model.watch.availability == .ready, model.watch.phase == .idle {
        await model.watch.open(routine: routine)
      }
    }
  }

  @ViewBuilder private var status: some View {
    let availability = model.watch.availability
    if availability == .checking {
      ProgressView(availability.message)
    } else if case .waiting = model.watch.phase {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: "applewatch.radiowaves.left.and.right")
          .font(.system(size: 44)).foregroundStyle(FormaTheme.accent)
          .accessibilityHidden(true)
        Text("Press Start on your Apple Watch").font(.title3.bold())
          .accessibilityIdentifier("watch-waiting")
        Text(
          "FORMA is open on your Watch with \(routine.name). Your workout begins on both devices when you press Start, and your Watch records heart rate and energy to Apple Health."
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
    } else {
      Label {
        Text(availability.message).fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: availability == .ready ? "applewatch" : "applewatch.slash")
      }
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      .accessibilityIdentifier("watch-status")
    }
  }
}

/// Live values the Watch sends while it records this workout.
struct WatchRecordingStrip: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    switch model.watch.phase {
    case .recording:
      let metrics = model.watch.metrics
      HStack(spacing: 14) {
        Image(systemName: "applewatch").foregroundStyle(FormaTheme.accent)
        if let rate = metrics?.heartRate {
          Label("\(Int(rate.rounded())) bpm", systemImage: "heart.fill")
        }
        if let energy = metrics?.activeEnergy {
          Label("\(Int(energy.rounded())) kcal", systemImage: "flame.fill")
        }
        if metrics == nil { Text("Recording on Apple Watch") }
        if metrics?.state == .paused { Text("Paused").foregroundStyle(FormaTheme.secondary) }
      }
      .font(.subheadline.weight(.semibold).monospacedDigit())
      .foregroundStyle(FormaTheme.primary)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityText(metrics))
      .accessibilityIdentifier("watch-recording")
    case .ending:
      Label("Ending recording on Apple Watch…", systemImage: "applewatch")
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    case .ended:
      Label(
        "Apple Watch recording ended. Check your Watch for Health save status.",
        systemImage: "applewatch"
      )
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    default:
      EmptyView()
    }
  }

  private func accessibilityText(_ metrics: WatchMetrics?) -> String {
    var parts = ["Recording on Apple Watch"]
    if let rate = metrics?.heartRate {
      parts.append("heart rate \(Int(rate.rounded())) beats per minute")
    }
    if let energy = metrics?.activeEnergy {
      parts.append("\(Int(energy.rounded())) active kilocalories")
    }
    return parts.joined(separator: ", ")
  }
}
