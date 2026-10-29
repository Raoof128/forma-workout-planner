import FORMACore
import SwiftUI

/// Shown only when an Apple Watch is paired. The workout begins when Start is
/// pressed on the Watch, or on this iPhone alone if the person prefers. The
/// Watch is opened only when the person chooses to, never on appearing.
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
          // A start that failed to save says so here: the root alert cannot
          // present over a sheet.
          if let failure = model.errorMessage {
            Label(failure, systemImage: "exclamationmark.circle")
              .font(.subheadline).foregroundStyle(FormaTheme.error)
              .accessibilityIdentifier("start-failure")
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
            // With no Watch to wait for, starting here is the main action.
            if model.watch.availability == .ready {
              startOnIPhone.buttonStyle(.bordered)
            } else {
              startOnIPhone.buttonStyle(PrimaryButtonStyle())
            }
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
    // The failure is announced when it appears, since the sheet is modal.
    .task(id: model.errorMessage) {
      if let failure = model.errorMessage { AccessibilityNotification.Announcement(failure).post() }
    }
  }

  private var startOnIPhone: some View {
    Button {
      starting = true
      model.errorMessage = nil
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
    .disabled(model.busy || starting)
    .accessibilityValue(starting ? "Starting" : "")
    .accessibilityIdentifier("start-on-iphone")
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
    // Nothing to show means no view at all, so the workout screen's spacing
    // doesn't leave a gap.
    if showsStrip || model.watch.notice != nil {
      VStack(alignment: .leading, spacing: 8) {
        strip
        // The coordinator's own account of a lost link or failed command, here
        // where the workout is, not only on the start sheet.
        if let notice = model.watch.notice {
          Label(notice, systemImage: "applewatch.slash")
            .font(.subheadline).foregroundStyle(FormaTheme.error)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("watch-notice")
        }
      }
      .task(id: model.watch.notice) {
        if let notice = model.watch.notice { AccessibilityNotification.Announcement(notice).post() }
      }
    }
  }

  private var showsStrip: Bool {
    switch model.watch.phase {
    case .recording, .ending, .ended: true
    case .idle, .waiting: false
    }
  }

  @ViewBuilder private var strip: some View {
    switch model.watch.phase {
    case .recording:
      let metrics = model.watch.metrics
      HStack(spacing: 14) {
        Image(systemName: "applewatch").foregroundStyle(FormaTheme.accent)
        // A reading the Watch has stopped sending is labelled as old, never
        // shown as if it were live. A lost link also shows the notice below.
        if let rate = model.watch.liveHeartRate {
          Label("\(Int(rate.rounded())) bpm", systemImage: "heart.fill")
        } else if model.watch.isReadingStale, let last = model.watch.lastHeartRate {
          Label("Last \(Int(last.rounded())) bpm", systemImage: "heart.slash")
            .foregroundStyle(FormaTheme.secondary)
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
    if let rate = model.watch.liveHeartRate {
      parts.append("heart rate \(Int(rate.rounded())) beats per minute")
    } else if model.watch.isReadingStale, let last = model.watch.lastHeartRate {
      parts.append("heart rate not current, last \(Int(last.rounded())) beats per minute")
    }
    if let energy = metrics?.activeEnergy {
      parts.append("\(Int(energy.rounded())) active kilocalories")
    }
    return parts.joined(separator: ", ")
  }
}
