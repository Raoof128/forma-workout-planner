import Accessibility
import SwiftUI
import WatchKit

/// The Watch app's colours, in one place. Lime and ink match `BrandPalette`
/// (FORMASurfaces), which the Watch target cannot link; change them together.
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
      case .idle, .ready, .preparing, .starting, .recovering, .failed:
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
    // The same confirmed changes, spoken: the haptics alone don't reach a
    // VoiceOver user, and the paused label is hidden from VoiceOver.
    .onChange(of: manager.phase) { old, new in
      guard let line = Self.announcement(from: old, to: new) else { return }
      AccessibilityNotification.Announcement(line).post()
    }
    // The iPhone stopped following mid-workout: a wrist-down cue, since
    // nothing else on the Watch changes.
    .sensoryFeedback(.warning, trigger: manager.mirrored) { old, new in
      old && !new && (manager.phase == .running || manager.phase == .paused)
    }
  }

  private static func announcement(
    from old: WorkoutManager.Phase, to new: WorkoutManager.Phase
  ) -> String? {
    switch (old, new) {
    case (.starting, .running): "Recording started"
    case (.running, .paused): "Recording paused"
    case (.paused, .running): "Recording resumed"
    case (_, .summary(_, saved: true)): "Saved to Health"
    case (_, .summary(_, saved: false)): "Recording discarded"
    case (_, .failed(let message)): message
    default: nil
    }
  }

  /// Which screen is showing, so live changes inside a screen do not animate.
  private enum Screen { case start, session, summary }

  private var screen: Screen {
    switch manager.phase {
    case .idle, .ready, .preparing, .starting, .recovering, .failed: .start
    case .running, .paused, .ending: .session
    case .summary: .summary
    }
  }
}

// MARK: - Start

private struct StartView: View {
  @Environment(WorkoutManager.self) private var manager
  @State private var confirmingDiscard = false

  var body: some View {
    // The countdown runs while the prepared session warms its sensors, and
    // stays until the manager moves on, so no other screen flashes between.
    if manager.phase == .preparing {
      StartCountdown {
        Task { await manager.beginPrepared() }
      }
    } else {
      content
    }
  }

  private var content: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(heading).font(.footnote.weight(.semibold)).foregroundStyle(WatchTheme.lime)
          .accessibilityAddTraits(.isHeader)
        Text(manager.routineName ?? "Strength workout")
          .font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        // Errors come first so they are never below the fold.
        if case .failed(let message) = manager.phase {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote).foregroundStyle(WatchTheme.error)
            .fixedSize(horizontal: false, vertical: true)
        }
        if manager.phase == .recovering {
          WatchLoadingMark(title: "Restoring your workout…")
        } else if manager.phase == .starting {
          WatchLoadingMark(title: "Starting…")
        } else if manager.recoveryFailed {
          recoveryActions
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
    if manager.phase == .recovering { return "Restoring" }
    if manager.recoveryFailed { return "Couldn’t restore" }
    if manager.hasFailedRecording { return "Recording stopped" }
    return manager.routineName == nil ? "FORMA" : "Ready"
  }

  @ViewBuilder private var recoveryActions: some View {
    Button {
      Task { await manager.recover() }
    } label: {
      Label("Try again", systemImage: "arrow.clockwise")
    }
    .buttonStyle(WatchButtonStyle(.primary))
    .dimmedInAlwaysOn()
    Button("Dismiss") { manager.dismissRecoveryFailure() }
      .buttonStyle(WatchButtonStyle(.quiet))
      .dimmedInAlwaysOn()
  }

  @ViewBuilder private var failedRecording: some View {
    Text(
      "Your recording is kept until you save or discard it. Your iPhone sets are separate."
    )
    .font(.footnote)
    if manager.savingRecording {
      WatchLoadingMark(title: "Saving to Health…")
    } else {
      Button {
        manager.retrySave()
      } label: {
        Label("Try saving again", systemImage: "arrow.clockwise")
      }
      .buttonStyle(WatchButtonStyle(.primary))
      .dimmedInAlwaysOn()
      Button(role: .destructive) {
        confirmingDiscard = true
      } label: {
        Label("Discard recording", systemImage: "trash")
      }
      .buttonStyle(WatchButtonStyle(.quiet))
      .dimmedInAlwaysOn()
    }
  }

  @ViewBuilder private var startActions: some View {
    // Always On keeps the control in place, shown as unavailable; a tap
    // still wakes the app and starts, as watchOS intends.
    if manager.healthAccessDenied {
      // Retrying after Health access was off goes straight back to HealthKit.
      Button {
        Task { await manager.requestStart() }
      } label: {
        Label("Try again", systemImage: "arrow.clockwise")
      }
      .buttonStyle(WatchButtonStyle(.primary))
      .dimmedInAlwaysOn()
    } else {
      StartDisc(label: "Start \(manager.routineName ?? "strength workout")") {
        Task { await manager.requestStart() }
      }
      .dimmedInAlwaysOn()
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

/// Like Apple's Workout app: the controls (Pause, End, Discard) on the left
/// page, the live numbers in the middle, and Now Playing on the right, so a
/// brush of the wrist during a set can't end the workout. Always On keeps the
/// same layout and only slows the updates, returning to the numbers.
private struct SessionView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var page = Page.metrics

  private enum Page { case controls, metrics, nowPlaying }

  var body: some View {
    Group {
      if manager.phase == .ending {
        SavingView()
      } else {
        TabView(selection: $page) {
          ControlsPage().sessionBackground().tag(Page.controls)
          MetricsPage().sessionBackground().tag(Page.metrics)
          NowPlayingView().tag(Page.nowPlaying)
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
    WatchLoadingMark(
      title: manager.savingToHealth ? "Saving to Health…" : "Discarding…",
      detail: "Keep this screen open.")
  }
}

private struct MetricsPage: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @Environment(\.dynamicTypeSize) private var typeSize

  // Each live value lives in its own small view so a heart-rate or energy update
  // re-renders one row, and the once-a-second clock re-renders one Text.
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        if manager.phase == .paused { PausedLabel() }
        // At accessibility sizes the clock gets the full width, so the
        // setting that enlarges text never shrinks the main number.
        if typeSize.isAccessibilitySize {
          ElapsedTimeView()
          StopButton()
        } else {
          HStack(alignment: .center, spacing: 6) {
            ElapsedTimeView()
            Spacer(minLength: 0)
            StopButton()
          }
        }
        if luminanceReduced {
          // Dimmed wrist: the same rows, sampled with the minute tick rather
          // than redrawn on every HealthKit sample.
          TimelineView(.everyMinute) { context in
            SampledReadings(date: context.date)
          }
        } else {
          HeartRateRow()
          EnergyRow()
        }
        ConnectionRow()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// One control on the numbers page for "stop": it asks whether to pause the
/// recording or end the workout, so a brush of the wrist can't end it. It acts
/// only on the Watch's own recording; the iPhone keeps its sets and timers.
/// On a dimmed wrist it stays in place, outlined rather than filled.
private struct StopButton: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var choosing = false

  var body: some View {
    let paused = manager.phase == .paused
    let tint = paused ? WatchTheme.lime : WatchTheme.error
    Button {
      choosing = true
    } label: {
      Image(systemName: paused ? "play.fill" : "stop.fill")
        .font(.body.weight(.bold))
        .foregroundStyle(luminanceReduced ? tint : (paused ? WatchTheme.ink : WatchTheme.error))
        .frame(width: 44, height: 44)
        .background {
          Circle().fill(
            luminanceReduced ? Color.clear : (paused ? WatchTheme.lime : WatchTheme.error.opacity(0.28))
          )
        }
        .overlay {
          if luminanceReduced { Circle().stroke(tint.opacity(0.6), lineWidth: 1.5) }
        }
    }
    .buttonStyle(.plain)
    .dimmedInAlwaysOn()
    .accessibilityLabel(paused ? "Resume or end recording" : "Pause or end recording")
    .accessibilityHint("Asks before anything changes.")
    .confirmationDialog(
      paused ? "Recording paused" : "Stop recording?", isPresented: $choosing,
      titleVisibility: .visible
    ) {
      if paused {
        Button("Resume recording") { manager.resume() }
      } else {
        Button("Pause recording") { manager.pause() }
      }
      Button("End and save") { manager.end(save: true) }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("End and save keeps the recording in Health. Finish the workout on your iPhone to log your sets.")
    }
  }
}

/// Paused in words, not only in the timer's colour. VoiceOver hears it on the
/// timer and as an announcement, so this label is hidden from it.
private struct PausedLabel: View {
  var body: some View {
    MotionGate { animates in
      Label {
        Text("Paused")
      } icon: {
        Image(systemName: "pause.fill")
          .symbolEffect(.pulse, options: .repeating, isActive: animates)
      }
      .font(.caption.weight(.bold)).foregroundStyle(WatchTheme.warning)
    }
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

/// The clock: seconds while the wrist is raised, whole minutes when dimmed
/// (seconds that update once a minute read as frozen), in the same place.
private struct ElapsedTimeView: View {
  @Environment(WorkoutManager.self) private var manager
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  var body: some View {
    if manager.phase == .paused {
      // Nothing changes while paused, so there is nothing to tick.
      timer(at: .now, paused: true)
    } else if luminanceReduced {
      TimelineView(.everyMinute) { context in
        timer(at: context.date, paused: false)
      }
    } else {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        timer(at: context.date, paused: false)
      }
    }
  }

  private func timer(at date: Date, paused: Bool) -> some View {
    let elapsed = manager.elapsed(at: date)
    return Text(luminanceReduced ? WatchFormat.minutes(elapsed) : WatchFormat.clock(elapsed))
      .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
      .foregroundStyle(paused ? Color.secondary : WatchTheme.lime)
      .lineLimit(1).minimumScaleFactor(0.6)
      .accessibilityLabel("Elapsed time")
      .accessibilityValue(WatchFormat.spoken(elapsed, paused: paused))
      .accessibilityAddTraits(.updatesFrequently)
  }
}

private struct HeartRateRow: View {
  @Environment(WorkoutManager.self) private var manager
  /// The sensor has had long enough: stop animating (a repeating effect keeps
  /// the display redrawing) and say so plainly.
  @State private var waitedTooLong = false

  var body: some View {
    MetricRow.heartRate(
      manager.heartRate, off: manager.heartRateOff, waitedTooLong: waitedTooLong
    )
    .task(id: manager.heartRate == nil) {
      waitedTooLong = false
      guard manager.heartRate == nil else { return }
      try? await Task.sleep(for: .seconds(MetricRow.measuringLimit))
      if !Task.isCancelled { waitedTooLong = true }
    }
  }
}

private struct EnergyRow: View {
  @Environment(WorkoutManager.self) private var manager

  var body: some View {
    MetricRow.energy(manager.activeEnergy, off: manager.activeEnergyOff)
  }
}

/// The heart-rate and energy rows on a dimmed wrist. `metrics` is not
/// observed, so these change with the minute tick that passes `date`, not per
/// sample.
private struct SampledReadings: View {
  @Environment(WorkoutManager.self) private var manager
  let date: Date

  var body: some View {
    let rate = manager.metrics?.heartRate.map { Int($0.rounded()) }
    let energy = manager.metrics?.activeEnergy.map { Int($0.rounded()) }
    MetricRow.heartRate(
      rate, off: manager.heartRateOff,
      waitedTooLong: manager.elapsed(at: date) >= MetricRow.measuringLimit)
    MetricRow.energy(energy, off: manager.activeEnergyOff)
  }
}

private struct MetricRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @Environment(\.dynamicTypeSize) private var typeSize
  let text: String
  let symbol: String
  let color: Color
  /// What the row is, for VoiceOver ("Heart rate").
  let label: String
  /// The reading, spoken ("72 beats per minute").
  let value: String
  /// The symbol beats while the reading is still being collected.
  var pulsing = false
  /// A live heart rate: the heart beats at this rate.
  var beatsPerMinute: Int?

  /// How long "Measuring…" may pulse before the row says there is no reading.
  static let measuringLimit: TimeInterval = 15

  static func heartRate(_ rate: Int?, off: Bool, waitedTooLong: Bool) -> MetricRow {
    if off {
      return MetricRow(
        text: "Off", symbol: "heart.fill", color: .red, label: "Heart rate",
        value: "Off in Health")
    }
    if let rate {
      return MetricRow(
        text: "\(rate) bpm", symbol: "heart.fill", color: .red, label: "Heart rate",
        value: "\(rate) beats per minute", beatsPerMinute: rate)
    }
    // The sensor's first reading can take a few seconds: say so, with the
    // heart beating, rather than a blank "--".
    return MetricRow(
      text: waitedTooLong ? "No reading" : "Measuring…", symbol: "heart.fill", color: .red,
      label: "Heart rate",
      value: waitedTooLong ? "No reading yet. Check your Watch fits snugly." : "Measuring",
      pulsing: !waitedTooLong)
  }

  static func energy(_ energy: Int?, off: Bool) -> MetricRow {
    if off {
      return MetricRow(
        text: "Off", symbol: "flame.fill", color: .orange, label: "Active energy",
        value: "Off in Health")
    }
    if let energy {
      return MetricRow(
        text: "\(energy) kcal", symbol: "flame.fill", color: .orange, label: "Active energy",
        value: "\(energy) kilocalories")
    }
    return MetricRow(
      text: "-- kcal", symbol: "flame.fill", color: .orange, label: "Active energy",
      value: "Not available yet")
  }

  /// Digits roll from one real reading to the next only when the user has not
  /// asked for less motion and the display is fully lit.
  private var rollsDigits: Bool { !reduceMotion && !luminanceReduced }

  var body: some View {
    Label {
      Text(text).font(.title3.monospacedDigit())
        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).minimumScaleFactor(0.6)
        .contentTransition(rollsDigits ? ContentTransition.numericText() : .identity)
        .animation(rollsDigits ? Animation.easeOut(duration: 0.2) : nil, value: text)
    } icon: {
      // The heartbeat and the rolling digits are this page's only motion;
      // energy changes too often to earn its own effect.
      if let beatsPerMinute {
        HeartbeatSymbol(beatsPerMinute: beatsPerMinute)
      } else {
        Image(systemName: symbol).foregroundStyle(color)
          .symbolEffect(.pulse, options: .repeating, isActive: pulsing && rollsDigits)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

private struct ControlsPage: View {
  @Environment(WorkoutManager.self) private var manager
  @State private var confirmingDiscard = false

  var body: some View {
    let paused = manager.phase == .paused
    ScrollView {
      // Pause sits apart from End, which has no confirmation, so a rushed tap
      // meant for Pause can't end the recording.
      VStack(spacing: 12) {
        Button {
          paused ? manager.resume() : manager.pause()
        } label: {
          Label(
            paused ? "Resume recording" : "Pause recording",
            systemImage: paused ? "play.fill" : "pause.fill")
        }
        .buttonStyle(WatchButtonStyle(.primary))

        // End saves and shows the summary. No confirmation: Discard is the
        // separate, confirmed way to throw the workout away.
        Button {
          manager.end(save: true)
        } label: {
          Label("End and save", systemImage: "xmark")
        }
        .buttonStyle(WatchButtonStyle(.end))
        .padding(.top, 8)

        Button(role: .destructive) {
          confirmingDiscard = true
        } label: {
          Label("Discard recording", systemImage: "trash")
        }
        .buttonStyle(WatchButtonStyle(.quiet))

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
      Text(
        "This workout won’t be saved. Health samples already recorded may remain. Your iPhone sets stay."
      )
    }
  }
}

// MARK: - Summary

private struct SummaryView: View {
  @Environment(WorkoutManager.self) private var manager
  let metrics: WatchMetrics
  let saved: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 10) {
            SummarySeal(saved: saved)
            Text(saved ? "Saved to Health" : "Recording discarded").font(.headline)
              .fixedSize(horizontal: false, vertical: true)
          }
          Text(WatchFormat.clock(metrics.elapsed)).font(.title2.weight(.bold).monospacedDigit())
            .accessibilityLabel("Workout time")
            .accessibilityValue(WatchFormat.spoken(metrics.elapsed, paused: false))
            .reveal(0)
          if let average = metrics.averageHeartRate.map({ Int($0.rounded()) }) {
            SummaryRow(
              text: "\(average) bpm average", symbol: "heart.fill", color: .red,
              label: "Average heart rate", value: "\(average) beats per minute"
            )
            .reveal(1)
          }
          if let maximum = metrics.maxHeartRate.map({ Int($0.rounded()) }) {
            SummaryRow(
              text: "\(maximum) bpm max", symbol: "arrow.up.heart.fill", color: .red,
              label: "Highest heart rate", value: "\(maximum) beats per minute"
            )
            .reveal(2)
          }
          if let energy = metrics.activeEnergy.map({ Int($0.rounded()) }) {
            SummaryRow(
              text: "\(energy) kcal", symbol: "flame.fill", color: .orange,
              label: "Active energy", value: "\(energy) kilocalories"
            )
            .reveal(3)
          }
          Text(
            manager.endedFromPhone
              ? "Your sets and these numbers are on your iPhone."
              : "Finish the workout on your iPhone to log your sets with these numbers."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
      }
      // Done sits in the bottom toolbar, so it never scrolls out of reach and
      // watchOS draws it as a system control (Liquid Glass on watchOS 26).
      // It stays during Always On: there is nothing left to protect.
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button("Done") { manager.dismissSummary() }
            .tint(WatchTheme.lime)
        }
      }
    }
  }
}

/// A finished reading, read by VoiceOver as a name and a value rather than
/// as abbreviations.
private struct SummaryRow: View {
  let text: String
  let symbol: String
  let color: Color
  let label: String
  let value: String

  var body: some View {
    Label {
      Text(text)
    } icon: {
      Image(systemName: symbol).foregroundStyle(color)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
  }
}

// MARK: - Shared

/// Shown while the Watch is waiting on HealthKit: starting the session and its
/// sensors, restoring a workout, or saving. The heart beats so the screen never
/// looks frozen; with Reduce Motion or on a dimmed wrist it stays still.
private struct WatchLoadingMark: View {
  let title: String
  var detail: String?

  var body: some View {
    VStack(spacing: 8) {
      LoadingHeart()
      Text(title).font(.headline).multilineTextAlignment(.center)
      if let detail {
        Text(detail).font(.footnote).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}

/// Large, labelled targets (at least 48 pt tall) with the label colour set by
/// the style, so it doesn't depend on how the system tints a prominent button.
/// A destructive role reads in system red, and a press fades rather than snaps.
private struct WatchButtonStyle: ButtonStyle {
  enum Kind { case primary, end, quiet }

  @Environment(\.isEnabled) private var isEnabled
  let kind: Kind

  init(_ kind: Kind) { self.kind = kind }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .multilineTextAlignment(.center)
      .foregroundStyle(foreground(destructive: configuration.role == .destructive))
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 48)
      .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
      .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private func foreground(destructive: Bool) -> Color {
    if destructive { return WatchTheme.error }
    return switch kind {
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

/// Always On keeps a control where it was, shown as unavailable rather than
/// removed, so raising the wrist never reflows the screen.
private struct DimmedInAlwaysOn: ViewModifier {
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  func body(content: Content) -> some View {
    content.opacity(luminanceReduced ? 0.6 : 1)
  }
}

/// The live session's own look, as the Workouts HIG asks: a faint lime wash
/// behind the pages, gone on a dimmed wrist.
private struct SessionBackground: ViewModifier {
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  func body(content: Content) -> some View {
    content.containerBackground(
      luminanceReduced
        ? AnyShapeStyle(Color.black) : AnyShapeStyle(WatchTheme.lime.gradient.opacity(0.14)),
      for: .tabView)
  }
}

extension View {
  fileprivate func dimmedInAlwaysOn() -> some View { modifier(DimmedInAlwaysOn()) }
  fileprivate func sessionBackground() -> some View { modifier(SessionBackground()) }
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
