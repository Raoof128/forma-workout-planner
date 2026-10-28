import SwiftUI

private let lime = Color(red: 0xDF / 255, green: 0xF7 / 255, blue: 0x80 / 255)
private let ink = Color(red: 0x20 / 255, green: 0x25 / 255, blue: 0x22 / 255)

struct WatchRootView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  var body: some View {
    Group {
      switch manager.phase {
      case .idle, .ready, .starting, .failed:
        StartView().transition(.opacity)
      case .running, .paused, .ending:
        SessionView().transition(.opacity)
      case .summary(let metrics, let saved):
        SummaryView(metrics: metrics, saved: saved).transition(.opacity)
      }
    }
    // A short cross-fade between screens; the same fade serves Reduce Motion.
    // Always On is still, so nothing animates while the display is dimmed.
    .animation(luminanceReduced ? nil : Animation.easeOut(duration: 0.16), value: screen)
    // Feedback follows state HealthKit has confirmed (the workout is running,
    // the save finished), never the tap that asked for it. The Watch app does
    // not log sets, so there is no per-set cue here; the iPhone owns that.
    .sensoryFeedback(trigger: manager.phase) { old, new in
      switch (old, new) {
      case (.starting, .running), (.paused, .running): return .start
      case (.running, .paused): return .stop
      case (.ending, .summary(_, saved: true)): return .success
      default: return nil
      }
    }
  }

  /// Which screen is showing, so live changes inside a screen do not animate.
  private enum Screen { case start, session, summary }

  private var screen: Screen {
    switch manager.phase {
    case .idle, .ready, .starting, .failed: .start
    case .running, .paused, .ending: .session
    case .summary: .summary
    }
  }
}

private struct StartView: View {
  @Environment(WorkoutManager.self) private var manager
  @State private var confirmingDiscard = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(
          manager.hasFailedRecording
            ? "RECORDING STOPPED" : manager.routineName == nil ? "FORMA" : "READY"
        )
        .font(.caption2.weight(.bold)).foregroundStyle(lime)
        Text(manager.routineName ?? "Strength workout")
          .font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        if manager.hasFailedRecording {
          Text(
            "This recording has not been confirmed saved to Health. Discard it to start again. Your iPhone sets are separate."
          )
          .font(.footnote)
          if manager.savingRecording {
            ProgressView("Finishing recording…")
          }
          Button("Discard failed recording", role: .destructive) { confirmingDiscard = true }
            .disabled(manager.savingRecording)
        } else {
          Button {
            Task { await manager.start() }
          } label: {
            Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
          }
          .tint(lime).foregroundStyle(ink)
          .buttonStyle(.borderedProminent)
          .disabled(manager.phase == .starting)
          .accessibilityLabel("Start \(manager.routineName ?? "strength workout")")
        }
        if case .failed(let message) = manager.phase {
          Text(message).font(.footnote).foregroundStyle(.red)
        }
        if !manager.hasFailedRecording {
          Text(
            manager.routineName == nil
              ? "Choose a routine on your iPhone, or start here. Heart rate and energy are recorded to Apple Health."
              : "Your iPhone starts this workout when you press Start. Heart rate and energy are recorded to Apple Health."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    .confirmationDialog("Discard this failed recording?", isPresented: $confirmingDiscard) {
      Button("Discard recording", role: .destructive) { manager.discardFailedRecording() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This failed workout won’t be saved. Health samples already recorded may remain. Your iPhone sets are unchanged."
      )
    }
  }
}

private struct SessionView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  // Each live value lives in its own small view so a heart-rate or energy update
  // re-renders one row, and the once-a-second clock re-renders one Text.
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        ElapsedTimeView()
        HeartRateRow()
        EnergyRow()
        if !manager.mirrored {
          Label("Not connected to iPhone", systemImage: "iphone.slash")
            .font(.footnote).foregroundStyle(.secondary)
          if !luminanceReduced {
            Button("Reconnect to iPhone") { Task { await manager.reconnect() } }
              .disabled(manager.reconnecting || manager.phase == .ending)
          }
        }
        if !luminanceReduced { SessionControls() }
      }
    }
  }
}

private struct ElapsedTimeView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  var body: some View {
    let paused = manager.phase == .paused
    // Always On: one update a minute, and no running animation.
    TimelineView(.periodic(from: .now, by: luminanceReduced ? 60 : 1)) { context in
      let elapsed = Self.format(manager.elapsed(at: context.date))
      Text(elapsed)
        .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
        .foregroundStyle(paused ? .secondary : lime)
        .accessibilityLabel("Elapsed time \(elapsed)")
    }
  }

  /// `m:ss` style text without `String(format:)`, which runs every second.
  private static func format(_ interval: TimeInterval) -> String {
    let seconds = Int(interval)
    let minutes = seconds % 3_600 / 60
    let rest = seconds % 60
    let clock = "\(minutes < 10 ? "0" : "")\(minutes):\(rest < 10 ? "0" : "")\(rest)"
    let hours = seconds / 3_600
    return hours > 0 ? "\(hours):\(clock)" : clock
  }
}

private struct HeartRateRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    MetricRow(
      text: manager.heartRate.map { "\($0) bpm" } ?? "-- bpm", symbol: "heart.fill", color: .red)
  }
}

private struct EnergyRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    MetricRow(
      text: manager.activeEnergy.map { "\($0) kcal" } ?? "-- kcal", symbol: "flame.fill",
      color: .orange)
  }
}

private struct MetricRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  let text: String
  let symbol: String
  let color: Color

  /// Digits roll from one real reading to the next only when the user has not
  /// asked for less motion and the display is fully lit.
  private var rollsDigits: Bool { !reduceMotion && !luminanceReduced }

  var body: some View {
    Label {
      Text(text).font(.title3.monospacedDigit())
        .contentTransition(rollsDigits ? ContentTransition.numericText() : .identity)
        .animation(rollsDigits ? Animation.easeOut(duration: 0.2) : nil, value: text)
    } icon: {
      Image(systemName: symbol).foregroundStyle(color)
    }
  }
}

private struct SessionControls: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    HStack {
      Button {
        manager.phase == .paused ? manager.resume() : manager.pause()
      } label: {
        Image(systemName: manager.phase == .paused ? "play.fill" : "pause.fill")
      }
      .accessibilityLabel(manager.phase == .paused ? "Resume workout" : "Pause workout")
      Button(role: .destructive) {
        manager.end(save: true)
      } label: {
        Image(systemName: "stop.fill")
      }
      .accessibilityLabel("End workout and save to Health")
    }
    .disabled(manager.phase == .ending)
  }
}

private struct SummaryView: View {
  @Environment(WorkoutManager.self) private var manager
  let metrics: WatchMetrics
  let saved: Bool

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text(saved ? "Saved to Health" : "Discarded").font(.headline)
        Text("\(Int(metrics.elapsed / 60)) min").font(.title2.weight(.bold))
        if let average = metrics.averageHeartRate {
          Label("\(Int(average.rounded())) bpm average", systemImage: "heart.fill")
        }
        if let energy = metrics.activeEnergy {
          Label("\(Int(energy.rounded())) kcal", systemImage: "flame.fill")
        }
        Text("Your sets are logged on your iPhone.").font(.footnote).foregroundStyle(.secondary)
        Button("Done") { manager.dismissSummary() }
      }
    }
  }
}
