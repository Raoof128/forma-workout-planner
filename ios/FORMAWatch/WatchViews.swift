import SwiftUI

/// The Watch app's colours, in one place.
enum WatchTheme {
  static let lime = Color(red: 0xDF / 255, green: 0xF7 / 255, blue: 0x80 / 255)
  static let ink = Color(red: 0x20 / 255, green: 0x25 / 255, blue: 0x22 / 255)
  static let warning = Color.orange
  static let error = Color.red
}

struct WatchRootView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  var body: some View {
    Group {
      switch manager.phase {
      case .idle, .ready, .starting, .recovering, .failed:
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
    // the save finished or failed), never the tap that asked for it. The Watch
    // app does not log sets, so there is no per-set cue here; the iPhone owns that.
    .sensoryFeedback(trigger: manager.phase) { old, new in
      switch (old, new) {
      case (.starting, .running), (.paused, .running): return .start
      case (.running, .paused): return .stop
      case (.ending, .summary(_, saved: true)): return .success
      case (_, .failed): return .error
      default: return nil
      }
    }
    // The iPhone stopped following mid-workout: a wrist-down cue, since
    // nothing else on the Watch changes.
    .sensoryFeedback(.warning, trigger: manager.mirrored) { old, new in
      old && !new && (manager.phase == .running || manager.phase == .paused)
    }
  }

  /// Which screen is showing, so live changes inside a screen do not animate.
  private enum Screen { case start, session, summary }

  private var screen: Screen {
    switch manager.phase {
    case .idle, .ready, .starting, .recovering, .failed: .start
    case .running, .paused, .ending: .session
    case .summary: .summary
    }
  }
}

// MARK: - Start

private struct StartView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var confirmingDiscard = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(heading).font(.caption2.weight(.bold)).foregroundStyle(WatchTheme.lime)
        Text(manager.routineName ?? "Strength workout")
          .font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        // Errors come first so they are never below the fold.
        if case .failed(let message) = manager.phase {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote).foregroundStyle(WatchTheme.error)
            .fixedSize(horizontal: false, vertical: true)
        }
        if manager.phase == .recovering {
          ProgressView("Restoring your workout…")
        } else if manager.recoveryFailed {
          if !luminanceReduced { recoveryActions }
        } else if manager.hasFailedRecording {
          failedRecording
        } else {
          startActions
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

  private var heading: String {
    if manager.phase == .recovering { return "RESTORING" }
    if manager.recoveryFailed { return "COULDN’T RESTORE" }
    if manager.hasFailedRecording { return "RECORDING STOPPED" }
    return manager.routineName == nil ? "FORMA" : "READY"
  }

  @ViewBuilder private var recoveryActions: some View {
    Button {
      Task { await manager.recover() }
    } label: {
      Label("Try again", systemImage: "arrow.clockwise")
    }
    .buttonStyle(WatchButtonStyle(.primary))
    Button("Dismiss") { manager.dismissRecoveryFailure() }
      .buttonStyle(WatchButtonStyle(.quiet))
  }

  @ViewBuilder private var failedRecording: some View {
    Text(
      "Your recording is kept until you save or discard it. Your iPhone sets are separate."
    )
    .font(.footnote)
    if manager.savingRecording {
      ProgressView("Saving to Health…")
    } else if !luminanceReduced {
      Button {
        manager.retrySave()
      } label: {
        Label("Try saving again", systemImage: "arrow.clockwise")
      }
      .buttonStyle(WatchButtonStyle(.primary))
      Button(role: .destructive) {
        confirmingDiscard = true
      } label: {
        Label("Discard", systemImage: "trash")
      }
      .buttonStyle(WatchButtonStyle(.quiet))
    }
  }

  @ViewBuilder private var startActions: some View {
    if !luminanceReduced {
      Button {
        Task { await manager.start() }
      } label: {
        if manager.phase == .starting {
          Label {
            Text("Starting…")
          } icon: {
            ProgressView()
          }
        } else {
          Label(
            manager.healthAccessDenied ? "Try again" : "Start",
            systemImage: manager.healthAccessDenied ? "arrow.clockwise" : "play.fill")
        }
      }
      .buttonStyle(WatchButtonStyle(.primary))
      .disabled(manager.phase == .starting)
      .accessibilityLabel(
        manager.phase == .starting
          ? "Starting workout"
          : manager.healthAccessDenied
            ? "Try again" : "Start \(manager.routineName ?? "strength workout")")
    }
    Text(
      manager.routineName == nil
        ? "Choose a routine on your iPhone, or start here. Heart rate and energy are recorded to Apple Health."
        : "Your iPhone starts this workout when you press Start. Heart rate and energy are recorded to Apple Health."
    )
    .font(.footnote).foregroundStyle(.secondary)
  }
}

// MARK: - Session

/// Like Apple's Workout app: the live numbers on the main page and the
/// controls (Pause, End, Discard) on their own page, so a brush of the wrist
/// during a set can't end the workout. Always On shows only the numbers.
private struct SessionView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var page = Page.metrics

  private enum Page { case controls, metrics }

  var body: some View {
    Group {
      if manager.phase == .ending {
        SavingView()
      } else if luminanceReduced {
        AlwaysOnMetrics()
      } else {
        TabView(selection: $page) {
          ControlsPage().tag(Page.controls)
          MetricsPage().tag(Page.metrics)
        }
        .tabViewStyle(.page)
      }
    }
    // Wake on the numbers, not on whichever page was open when the wrist dropped.
    .onChange(of: luminanceReduced) { _, reduced in
      if reduced { page = .metrics }
    }
  }
}

/// End shows its work: the save can take seconds, and the screen must not
/// look frozen while it runs.
private struct SavingView: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    VStack(spacing: 8) {
      ProgressView()
      Text(manager.savingToHealth ? "Saving to Health…" : "Discarding…")
        .font(.headline)
      Text("Keep this screen open.").font(.footnote).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct MetricsPage: View {
  @Environment(WorkoutManager.self) private var manager

  // Each live value lives in its own small view so a heart-rate or energy update
  // re-renders one row, and the once-a-second clock re-renders one Text.
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        if manager.phase == .paused { PausedLabel() }
        ElapsedTimeView()
        HeartRateRow()
        EnergyRow()
        ConnectionRow()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Paused in words, not only in the timer's colour. VoiceOver hears it on the
/// timer, so this label is hidden from it.
private struct PausedLabel: View {
  var body: some View {
    Label("Paused", systemImage: "pause.fill")
      .font(.caption.weight(.bold)).foregroundStyle(WatchTheme.warning)
      .accessibilityHidden(true)
  }
}

private struct ConnectionRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    if manager.reconnecting {
      Label("Connecting to iPhone…", systemImage: "iphone.radiowaves.left.and.right")
        .font(.footnote).foregroundStyle(.secondary)
    } else if !manager.mirrored {
      Label("iPhone not connected", systemImage: "iphone.slash")
        .font(.footnote).foregroundStyle(.secondary)
    }
  }
}

/// Dimmed wrist: whole minutes only (seconds that update once a minute read
/// as frozen), and the readings are sampled with the minute tick rather than
/// redrawing on every HealthKit sample.
private struct AlwaysOnMetrics: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    TimelineView(.everyMinute) { context in
      let paused = manager.phase == .paused
      let elapsed = manager.elapsed(at: context.date)
      VStack(alignment: .leading, spacing: 6) {
        if paused { PausedLabel() }
        Text(WatchFormat.minutes(elapsed))
          .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
          .foregroundStyle(paused ? Color.secondary : WatchTheme.lime)
          .lineLimit(1).minimumScaleFactor(0.6)
          .accessibilityLabel("Elapsed time")
          .accessibilityValue(WatchFormat.spoken(elapsed, paused: paused))
        // `metrics` is not observed, so these change with the tick, not per sample.
        if let rate = manager.metrics?.heartRate {
          MetricRow(
            text: "\(Int(rate.rounded())) bpm", symbol: "heart.fill", color: .red,
            label: "Heart rate \(Int(rate.rounded())) beats per minute")
        }
        if !manager.mirrored {
          Label("iPhone not connected", systemImage: "iphone.slash")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct ElapsedTimeView: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    if manager.phase == .paused {
      // Nothing changes while paused, so there is nothing to tick.
      timer(at: .now, paused: true)
    } else {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        timer(at: context.date, paused: false)
      }
    }
  }

  private func timer(at date: Date, paused: Bool) -> some View {
    let elapsed = manager.elapsed(at: date)
    return Text(WatchFormat.clock(elapsed))
      .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
      .foregroundStyle(paused ? Color.secondary : WatchTheme.lime)
      .lineLimit(1).minimumScaleFactor(0.6)
      .accessibilityLabel("Elapsed time")
      .accessibilityValue(WatchFormat.spoken(elapsed, paused: paused))
  }
}

private struct HeartRateRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    if manager.heartRateOff {
      MetricRow(
        text: "Off", symbol: "heart.fill", color: .red, label: "Heart rate is off in Health")
    } else if let rate = manager.heartRate {
      MetricRow(
        text: "\(rate) bpm", symbol: "heart.fill", color: .red,
        label: "Heart rate \(rate) beats per minute")
    } else {
      MetricRow(
        text: "-- bpm", symbol: "heart.fill", color: .red, label: "Heart rate not available yet")
    }
  }
}

private struct EnergyRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    if manager.activeEnergyOff {
      MetricRow(
        text: "Off", symbol: "flame.fill", color: .orange,
        label: "Active energy is off in Health")
    } else if let energy = manager.activeEnergy {
      MetricRow(
        text: "\(energy) kcal", symbol: "flame.fill", color: .orange,
        label: "Active energy \(energy) kilocalories")
    } else {
      MetricRow(
        text: "-- kcal", symbol: "flame.fill", color: .orange,
        label: "Active energy not available yet")
    }
  }
}

private struct MetricRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  let text: String
  let symbol: String
  let color: Color
  let label: String

  /// Digits roll from one real reading to the next only when the user has not
  /// asked for less motion and the display is fully lit.
  private var rollsDigits: Bool { !reduceMotion && !luminanceReduced }

  var body: some View {
    Label {
      Text(text).font(.title3.monospacedDigit())
        .lineLimit(1).minimumScaleFactor(0.6)
        .contentTransition(rollsDigits ? ContentTransition.numericText() : .identity)
        .animation(rollsDigits ? Animation.easeOut(duration: 0.2) : nil, value: text)
    } icon: {
      Image(systemName: symbol).foregroundStyle(color)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }
}

private struct ControlsPage: View {
  @Environment(WorkoutManager.self) private var manager
  @State private var confirmingDiscard = false

  var body: some View {
    let paused = manager.phase == .paused
    ScrollView {
      VStack(spacing: 8) {
        Button {
          paused ? manager.resume() : manager.pause()
        } label: {
          Label(
            paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill")
        }
        .buttonStyle(WatchButtonStyle(.primary))
        .accessibilityLabel(paused ? "Resume workout" : "Pause workout")

        // End saves and shows the summary. No confirmation: Discard is the
        // separate, confirmed way to throw the workout away.
        Button {
          manager.end(save: true)
        } label: {
          Label("End", systemImage: "xmark")
        }
        .buttonStyle(WatchButtonStyle(.end))
        .accessibilityLabel("End workout and save to Health")

        Button {
          confirmingDiscard = true
        } label: {
          Label("Discard recording", systemImage: "trash")
        }
        .buttonStyle(WatchButtonStyle(.quiet))
        .accessibilityLabel("Discard recording")
        .padding(.top, 8)

        if !manager.mirrored {
          Button {
            Task { await manager.reconnect() }
          } label: {
            Label("Reconnect to iPhone", systemImage: "iphone.radiowaves.left.and.right")
          }
          .buttonStyle(WatchButtonStyle(.quiet))
          .disabled(manager.reconnecting)
        }
      }
    }
    .confirmationDialog("Discard this recording?", isPresented: $confirmingDiscard) {
      Button("Discard recording", role: .destructive) { manager.end(save: false) }
      Button("Keep going", role: .cancel) {}
    } message: {
      Text("Nothing is saved to Health. Your iPhone sets stay.")
    }
  }
}

// MARK: - Summary

private struct SummaryView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  let metrics: WatchMetrics
  let saved: Bool

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text(saved ? "Saved to Health" : "Recording discarded").font(.headline)
        Text(WatchFormat.clock(metrics.elapsed)).font(.title2.weight(.bold).monospacedDigit())
          .accessibilityLabel("Workout time")
          .accessibilityValue(WatchFormat.spoken(metrics.elapsed, paused: false))
        if let average = metrics.averageHeartRate {
          Label("\(Int(average.rounded())) bpm average", systemImage: "heart.fill")
        }
        if let energy = metrics.activeEnergy {
          Label("\(Int(energy.rounded())) kcal", systemImage: "flame.fill")
        }
        // Done sits above the footnote so it is not below the fold.
        if !luminanceReduced {
          Button("Done") { manager.dismissSummary() }
            .buttonStyle(WatchButtonStyle(.primary))
        }
        Text("Your sets are logged on your iPhone.").font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Shared

/// Large, labelled targets (at least 48 pt tall) with the label colour set by
/// the style, so it doesn't depend on how the system tints a prominent button.
private struct WatchButtonStyle: ButtonStyle {
  enum Kind { case primary, end, quiet }

  @Environment(\.isEnabled) private var isEnabled
  let kind: Kind

  init(_ kind: Kind) { self.kind = kind }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity, minHeight: 48)
      .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
      .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
  }

  private var foreground: Color {
    switch kind {
    case .primary: WatchTheme.ink
    case .end: WatchTheme.error
    case .quiet: .primary
    }
  }

  private var background: Color {
    switch kind {
    case .primary: WatchTheme.lime
    case .end: WatchTheme.error.opacity(0.28)
    case .quiet: Color.white.opacity(0.16)
    }
  }
}

/// Clock and duration text without `String(format:)`, which would run every second.
enum WatchFormat {
  /// `m:ss`, or `h:mm:ss` after the first hour.
  static func clock(_ interval: TimeInterval) -> String {
    let seconds = Int(interval)
    let minutes = seconds % 3_600 / 60
    let rest = seconds % 60
    let clock = "\(minutes < 10 ? "0" : "")\(minutes):\(rest < 10 ? "0" : "")\(rest)"
    let hours = seconds / 3_600
    return hours > 0 ? "\(hours):\(clock)" : clock
  }

  /// Whole minutes ("12 min", "1 h 05 min"), for Always On.
  static func minutes(_ interval: TimeInterval) -> String {
    let minutes = Int(interval) / 60
    guard minutes >= 60 else { return "\(minutes) min" }
    let rest = minutes % 60
    return "\(minutes / 60) h \(rest < 10 ? "0" : "")\(rest) min"
  }

  /// "12 minutes, 34 seconds", for VoiceOver, which would read `12:34` as a time of day.
  static func spoken(_ interval: TimeInterval, paused: Bool) -> String {
    let duration = Duration.seconds(Int(interval)).formatted(
      .units(allowed: [.hours, .minutes, .seconds], width: .wide))
    return paused ? "Paused, \(duration)" : duration
  }
}
