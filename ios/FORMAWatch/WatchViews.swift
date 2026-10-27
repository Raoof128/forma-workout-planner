import SwiftUI

private let lime = Color(red: 0xDF / 255, green: 0xF7 / 255, blue: 0x80 / 255)
private let ink = Color(red: 0x20 / 255, green: 0x25 / 255, blue: 0x22 / 255)

struct WatchRootView: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    switch manager.phase {
    case .idle, .ready, .starting, .failed:
      StartView()
    case .running, .paused, .ending:
      SessionView()
    case .summary(let metrics, let saved):
      SummaryView(metrics: metrics, saved: saved)
    }
  }
}

private struct StartView: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(manager.routineName == nil ? "FORMA" : "READY")
          .font(.caption2.weight(.bold)).foregroundStyle(lime)
        Text(manager.routineName ?? "Strength workout")
          .font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        Button {
          Task { await manager.start() }
        } label: {
          Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .tint(lime).foregroundStyle(ink)
        .buttonStyle(.borderedProminent)
        .disabled(manager.phase == .starting)
        .accessibilityLabel("Start \(manager.routineName ?? "strength workout")")
        if case .failed(let message) = manager.phase {
          Text(message).font(.footnote).foregroundStyle(.red)
        }
        Text(
          manager.routineName == nil
            ? "Choose a routine on your iPhone, or start here. Heart rate and energy are recorded to Apple Health."
            : "Your iPhone starts this workout when you press Start. Heart rate and energy are recorded to Apple Health."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
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
  let text: String
  let symbol: String
  let color: Color

  var body: some View {
    Label {
      Text(text).font(.title3.monospacedDigit())
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
