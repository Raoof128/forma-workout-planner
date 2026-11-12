import FORMACore
import SwiftUI

/// Shown only when an Apple Watch is paired. The workout begins when Start is
/// pressed on the Watch, or on this iPhone alone if the person prefers. The
/// Watch is opened only when the person chooses to, never on appearing.
struct StartWorkoutSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var textSize
  let routine: Routine
  /// In-button progress, so each tap is acknowledged while its await runs.
  @State private var opening = false
  @State private var starting = false
  /// Set by Check again, so the settled result is read out even when the
  /// Watch turns out to be ready.
  @State private var checkRequested = false
  /// A failure raised while this sheet is up. `model.errorMessage` is app-wide,
  /// and one left over from elsewhere is not about this start.
  @State private var failure: String?
  /// The tapped button disappears in every outcome of Open on Watch and Check
  /// again, so VoiceOver is moved to the sentence that says what happened.
  @AccessibilityFocusState private var statusFocused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: FormaSpacing.xl) {
          VStack(alignment: .leading, spacing: FormaSpacing.xs) {
            EditorialTitle(text: routine.name)
            Text("\(countPhrase(routine.exercises.count, "exercise")) · about \(routine.minutes) min")
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
          }
          status
            .formaAnimation(FormaMotion.state, value: model.watch.availability)
            .formaAnimation(FormaMotion.state, value: model.watch.phase)
          if let notice = model.watch.notice {
            Label(notice, systemImage: "exclamationmark.circle")
              .font(.subheadline).foregroundStyle(FormaTheme.error)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("watch-start-notice")
          }
          // A start that failed to save says so here: the root alert cannot
          // present over a sheet.
          if let failure {
            Label(failure, systemImage: "exclamationmark.circle")
              .font(.subheadline).foregroundStyle(FormaTheme.error)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("start-failure")
          }
        }
        .padding(FormaSpacing.xl)
      }
      // Pinned, so the actions stay in reach at the medium detent and at the
      // largest text sizes however long the copy above them grows.
      .formaBottomBar {
        actions
          .padding(.horizontal, FormaSpacing.xl).padding(.vertical, FormaSpacing.md)
          .modifier(SheetBarBackground())
      }
      .modifier(SheetCanvas())
      .navigationTitle("Start workout").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    // One decision and two buttons: half height keeps Today in view, and on
    // iOS 26 a partial sheet takes the inset Liquid Glass appearance. Large
    // remains for accessibility text sizes and the longer waiting copy.
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    // A start in flight finishes before the sheet can be swiped away.
    .interactiveDismissDisabled(starting || opening)
    .onChange(of: model.errorMessage) { _, message in failure = message }
    .onChange(of: model.watch.phase) { _, phase in
      if Self.shouldFocusStatus(phase: phase) { statusFocused = true }
    }
    .onChange(of: model.watch.availability) { old, new in
      if Self.shouldFocusStatus(from: old, to: new, checkRequested: checkRequested) {
        statusFocused = true
      }
      if new != .checking { checkRequested = false }
    }
    // Failures and the coordinator's notices are announced when they appear,
    // since the sheet is modal.
    .task(id: failure) {
      if let failure { AccessibilityNotification.Announcement(failure).post() }
    }
    .task(id: model.watch.notice) {
      if let notice = model.watch.notice { AccessibilityNotification.Announcement(notice).post() }
    }
  }

  /// Waiting on the Watch replaces the Open button with an instruction for
  /// another device, which VoiceOver must read.
  static func shouldFocusStatus(phase: WatchWorkoutCoordinator.Phase) -> Bool {
    if case .waiting = phase { return true }
    return false
  }

  /// A settled check that leaves the Watch out of reach replaces Open with
  /// Check again; one the person asked for removes Check again when it passes.
  static func shouldFocusStatus(
    from old: WatchWorkoutCoordinator.Availability, to new: WatchWorkoutCoordinator.Availability,
    checkRequested: Bool
  ) -> Bool {
    guard new != .checking, new != old || checkRequested else { return false }
    return new != .ready || checkRequested
  }

  private var actions: some View {
    VStack(spacing: FormaSpacing.sm) {
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
          checkRequested = true
          Task { await model.watch.refresh() }
        } label: {
          Label("Check again", systemImage: "arrow.clockwise")
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered).controlSize(.large)
        .disabled(model.watch.availability == .checking)
        .accessibilityIdentifier("watch-check-again")
      }
      // With no Watch to wait for, starting here is the main action.
      if model.watch.availability == .ready {
        startOnIPhone.buttonStyle(.bordered)
      } else {
        startOnIPhone.buttonStyle(PrimaryButtonStyle())
      }
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
      HStack(spacing: FormaSpacing.xs) {
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
        .accessibilityFocused($statusFocused)
    } else if case .waiting = model.watch.phase {
      VStack(alignment: .leading, spacing: FormaSpacing.sm) {
        // The instruction carries the meaning; at accessibility sizes the
        // artwork would only push it down.
        if !textSize.isAccessibilitySize {
          Image(systemName: "applewatch.radiowaves.left.and.right")
            .font(.system(size: 44)).foregroundStyle(FormaTheme.accent)
            .accessibilityHidden(true)
        }
        Text("Press Start on your Apple Watch").font(.title3.bold())
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("watch-waiting")
        Text(
          "FORMA is open on your Watch with \(routine.name). Your workout begins on both devices when you press Start."
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        .fixedSize(horizontal: false, vertical: true)
        Text("Your Watch records heart rate and energy to Apple Health.")
          .font(.footnote).foregroundStyle(FormaTheme.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityFocused($statusFocused)
    } else {
      Label {
        Text(availability.message).fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: availability == .ready ? "applewatch" : "applewatch.slash")
      }
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      .accessibilityIdentifier("watch-status")
      .accessibilityFocused($statusFocused)
    }
  }
}

/// iOS 26 gives a partial sheet its Liquid Glass material, so the sheet paints
/// no canvas of its own there. Earlier systems keep the brand canvas.
private struct SheetCanvas: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
    } else {
      content.background(FormaTheme.canvas)
    }
  }
}

/// `safeAreaBar` on iOS 26 supplies the scroll-edge effect behind the actions;
/// the earlier inset needs an opaque backing so content doesn't show through.
private struct SheetBarBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content
    } else {
      content.background(FormaTheme.canvas)
    }
  }
}

/// Live values the Watch sends while it records this workout.
struct WatchRecordingStrip: View {
  @Environment(AppModel.self) private var model
  /// The workout screen's own Finish, offered here once the Watch has ended its
  /// recording so the person isn't left looking for it.
  var finish: (() -> Void)?

  var body: some View {
    // Nothing to show means no view at all, so the workout screen's spacing
    // doesn't leave a gap.
    if showsStrip || model.watch.notice != nil {
      VStack(alignment: .leading, spacing: FormaSpacing.sm) {
        strip
        if model.watch.phase == .ended, let finish {
          Button(action: finish) {
            HStack {
              Text("Finish workout")
              Spacer()
              Image(systemName: "flag.checkered")
            }
          }
          .buttonStyle(PrimaryButtonStyle())
          .disabled(model.busy)
          .accessibilityHint("Logs your sets with what your Apple Watch recorded.")
          .accessibilityIdentifier("watch-ended-finish")
        }
        // The coordinator's own account of a lost link or failed command, here
        // where the workout is, not only on the start sheet.
        if let notice = model.watch.notice {
          Label(notice, systemImage: "applewatch.slash")
            .font(.subheadline).foregroundStyle(FormaTheme.error)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("watch-notice")
        }
      }
      .padding(FormaSpacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: FormaRadius.card))
      .overlay(RoundedRectangle(cornerRadius: FormaRadius.card).strokeBorder(FormaTheme.line))
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
      // Wraps onto two lines at large text sizes rather than truncating.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: FormaSpacing.sm) { readings(metrics) }
        VStack(alignment: .leading, spacing: FormaSpacing.xs) { readings(metrics) }
      }
      .font(.subheadline.weight(.semibold).monospacedDigit())
      .foregroundStyle(FormaTheme.primary)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        Self.spokenStatus(
          paused: metrics?.state == .paused, liveHeartRate: model.watch.liveHeartRate,
          lastHeartRate: model.watch.isReadingStale ? model.watch.lastHeartRate : nil,
          activeEnergy: metrics?.activeEnergy)
      )
      // Heart rate and energy change while VoiceOver rests here.
      .accessibilityAddTraits(.updatesFrequently)
      .accessibilityIdentifier("watch-recording")
    case .ending:
      Label("Ending recording on Apple Watch…", systemImage: "applewatch")
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    case .ended:
      Label(
        "Recording ended on Apple Watch. Your Watch shows whether it saved to Health.",
        systemImage: "applewatch"
      )
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      .fixedSize(horizontal: false, vertical: true)
    default:
      EmptyView()
    }
  }

  @ViewBuilder private func readings(_ metrics: WatchMetrics?) -> some View {
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

  /// The strip's spoken label. It replaces the combined children, so it must
  /// carry every state they show, a pause included.
  static func spokenStatus(
    paused: Bool, liveHeartRate: Double?, lastHeartRate: Double?, activeEnergy: Double?
  ) -> String {
    var parts = [paused ? "Paused on Apple Watch" : "Recording on Apple Watch"]
    if let rate = liveHeartRate {
      parts.append("heart rate \(Int(rate.rounded())) beats per minute")
    } else if let last = lastHeartRate {
      parts.append("heart rate not current, last \(Int(last.rounded())) beats per minute")
    }
    if let energy = activeEnergy {
      parts.append("\(Int(energy.rounded())) active kilocalories")
    }
    return parts.joined(separator: ", ")
  }
}
