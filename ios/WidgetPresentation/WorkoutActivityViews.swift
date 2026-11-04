#if DEBUG || FORMA_WIDGET_EXTENSION
  import AppIntents
  import FORMASurfaces
  import SwiftUI
  import UIKit
  import WidgetKit

  /// Brand colours for the activity. The Lock Screen background is the brand ink in dark and the
  /// brand lime in light, with ink and lime drawn on them, so contrast is the brand's own pairing
  /// in both. The Dynamic Island is always black and always uses the dark palette.
  struct WorkoutActivityPalette {
    let isDark: Bool

    static let dark = WorkoutActivityPalette(isDark: true)

    private static func color(_ hex: UInt32) -> Color {
      Color(
        red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255)
    }

    /// `activityBackgroundTint` is applied outside the view, so it resolves with the trait.
    static let backgroundTint = Color(
      uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? BrandPalette.ink : BrandPalette.lime
        return UIColor(
          red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
      })
    /// The system's own dismiss and open controls sit on the same background.
    static let systemAction = Color(
      uiColor: UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? BrandPalette.lime : BrandPalette.ink
        return UIColor(
          red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
      })
    static let lime = color(BrandPalette.lime)

    var primary: Color { isDark ? .white : Self.color(BrandPalette.ink) }
    var secondary: Color {
      Self.color(isDark ? BrandPalette.secondaryText.dark : BrandPalette.secondaryText.light)
    }
    /// Emphasis: timers, the ring and the mark.
    var accent: Color { isDark ? Self.color(BrandPalette.lime) : Self.color(BrandPalette.ink) }
    var buttonFill: Color { accent }
    var buttonText: Color { isDark ? Self.color(BrandPalette.ink) : Self.color(BrandPalette.lime) }
  }

  /// Words for VoiceOver, kept apart from the visible strings.
  enum WorkoutActivitySpeech {
    static func duration(_ seconds: Int) -> String {
      Duration.seconds(max(0, seconds)).formatted(
        .units(allowed: [.minutes, .seconds], width: .wide))
    }

    static func pausedRest(_ state: WorkoutActivityState) -> String {
      "Rest paused, \(duration(state.restPausedSeconds ?? 0)) left"
    }
  }

  extension WorkoutActivityState {
    /// A rest whose countdown is still on screen. A stale one has run out while the app could not
    /// say so, and shows "Rest over" instead of a timer parked at zero.
    func countdown(isStale: Bool) -> ClosedRange<Date>? {
      guard !isStale, let restEnd, let restStart else { return nil }
      return restStart...max(restStart, restEnd)
    }

    func restIsOver(isStale: Bool) -> Bool { isStale && restEnd != nil }

    /// Elapsed time since the workout started. The system counts it, nothing is sent.
    var elapsedRange: ClosedRange<Date> { startedAt...Date.distantFuture }
  }

  // MARK: Pieces

  /// The FORMA mark: a plain symbol, no container, as the HIG asks of a compact Island.
  struct WorkoutMark: View {
    var palette: WorkoutActivityPalette
    var body: some View {
      Image(systemName: "dumbbell.fill")
        .font(.body.weight(.semibold))
        .foregroundStyle(palette.accent)
        .accessibilityLabel("FORMA workout")
    }
  }

  /// Rest progress. The system draws and runs it from the two dates.
  struct ActivityRestRing: View {
    var range: ClosedRange<Date>
    var palette: WorkoutActivityPalette
    var body: some View {
      ProgressView(timerInterval: range, countsDown: true) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .progressViewStyle(.circular)
      .tint(palette.accent)
    }
  }

  /// A short, monospaced timer. `Text(timerInterval:)` is greedy, so the width is capped.
  /// `showsHours` reads "1:15:03" rather than "75:03" past an hour; the compact Island slot keeps
  /// it off because its width is fixed. The scale floor keeps caption text near 11 pt.
  struct WorkoutTimer: View {
    var range: ClosedRange<Date>
    var countsDown: Bool
    var maxWidth: CGFloat
    var showsHours = false
    var alignment: HorizontalAlignment = .trailing
    var body: some View {
      Text(timerInterval: range, pauseTime: nil, countsDown: countsDown, showsHours: showsHours)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        .frame(maxWidth: maxWidth, alignment: alignment == .leading ? .leading : .trailing)
    }
  }

  extension View {
    /// Speaks a timer as "Elapsed time, 12 minutes 3 seconds": a label on a `Text` replaces what
    /// it says, so the running value goes in `accessibilityValue`.
    func elapsedTimeAccessibility(_ range: ClosedRange<Date>) -> some View {
      accessibilityLabel("Elapsed time")
        .accessibilityValue(Text(timerInterval: range, countsDown: false))
    }
  }

  /// The rest, in words and a timer, wherever there is room for both.
  struct RestReadout: View {
    var state: WorkoutActivityState
    var isStale: Bool
    var palette: WorkoutActivityPalette
    var timerFont: Font = .title2.weight(.bold)
    /// Leading in the `.small` family, where it sits under the exercise name.
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
      if let range = state.countdown(isStale: isStale) {
        VStack(alignment: alignment, spacing: 0) {
          Text("Rest").font(.caption.weight(.semibold)).foregroundStyle(palette.secondary)
          WorkoutTimer(range: range, countsDown: true, maxWidth: 96, alignment: alignment)
            .font(timerFont).foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .combine)
      } else if let paused = state.restPausedSeconds {
        VStack(alignment: alignment, spacing: 0) {
          Text("Rest paused").font(.caption.weight(.semibold)).foregroundStyle(palette.secondary)
          Text(WorkoutActivityState.clock(paused))
            .font(timerFont).monospacedDigit().foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WorkoutActivitySpeech.pausedRest(state))
      } else if state.restIsOver(isStale: isStale) {
        Text("Rest over")
          .font(.headline).foregroundStyle(palette.accent)
      }
    }
  }

  /// A capsule button for the intents, at least 44 pt high (the HIG's default control size).
  struct WorkoutActionStyle: ButtonStyle {
    var palette: WorkoutActivityPalette
    var prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(prominent ? palette.buttonText : palette.accent)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
          Capsule().fill(prominent ? palette.buttonFill : Color.clear)
        )
        .overlay(Capsule().strokeBorder(palette.accent, lineWidth: prominent ? 0 : 1.5))
        .opacity(configuration.isPressed ? 0.7 : 1)
        .contentShape(Capsule())
    }
  }

  /// One action at a time, as the HIG prefers for a Live Activity: "Skip rest" while a rest is on
  /// screen, otherwise "Complete set". Two buttons side by side invited a wrong tap mid-set, and
  /// both intents save after Face ID, so a miss was not caught. Complete set stays in the app.
  struct WorkoutActions: View {
    var sessionID: String
    var state: WorkoutActivityState
    var isStale: Bool
    var palette: WorkoutActivityPalette

    var body: some View {
      if state.isResting, !state.restIsOver(isStale: isStale) {
        Button(intent: SkipRestIntent(sessionID: sessionID)) {
          Label("Skip rest", systemImage: "forward.end.fill")
        }
        .buttonStyle(WorkoutActionStyle(palette: palette, prominent: true))
      } else if state.isFinishedAllSets {
        Text("All sets done. Finish in FORMA.")
          .font(.subheadline.weight(.medium)).foregroundStyle(palette.secondary)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      } else {
        Button(intent: CompleteSetIntent(sessionID: sessionID)) {
          Label("Complete set", systemImage: "checkmark")
        }
        .buttonStyle(WorkoutActionStyle(palette: palette, prominent: true))
      }
    }
  }

  // MARK: Lock Screen, banner, StandBy

  /// Picks the layout for the surface: the full Lock Screen card, or on iOS 18 and later the
  /// compact one for the Apple Watch Smart Stack and CarPlay.
  struct WorkoutActivityRoot: View {
    var sessionID: String
    var state: WorkoutActivityState
    var isStale: Bool

    var body: some View {
      if #available(iOS 18.0, *) {
        FamilyAwareView(sessionID: sessionID, state: state, isStale: isStale)
      } else {
        WorkoutLockScreenView(sessionID: sessionID, state: state, isStale: isStale)
      }
    }

    @available(iOS 18.0, *)
    private struct FamilyAwareView: View {
      @Environment(\.activityFamily) private var family
      var sessionID: String
      var state: WorkoutActivityState
      var isStale: Bool

      var body: some View {
        switch family {
        case .small: WorkoutSmallView(state: state, isStale: isStale)
        default: WorkoutLockScreenView(sessionID: sessionID, state: state, isStale: isStale)
        }
      }
    }
  }

  /// At most 160 pt tall, or the system truncates it. Larger Dynamic Type sizes drop the header
  /// row first, so the exercise, the set and the buttons stay.
  struct WorkoutLockScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    /// StandBy shows the card full screen: the rest timer gets the room.
    @Environment(\.isActivityFullscreen) private var isFullscreen
    var sessionID: String
    var state: WorkoutActivityState
    var isStale: Bool
    private var palette: WorkoutActivityPalette {
      WorkoutActivityPalette(isDark: colorScheme == .dark)
    }

    var body: some View {
      ViewThatFits(in: .vertical) {
        card(showHeader: true)
        card(showHeader: false)
      }
      // The HIG's standard Lock Screen margin for Live Activities.
      .padding(14)
      .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func card(showHeader: Bool) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        if showHeader { header }
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            Text(state.exercise)
              .font(.headline).foregroundStyle(palette.primary)
              .lineLimit(1).minimumScaleFactor(0.8)
              .privacySensitive()
            Text(progressLine)
              .font(.subheadline.weight(.medium)).foregroundStyle(palette.secondary)
              .lineLimit(1).minimumScaleFactor(0.8)
          }
          Spacer(minLength: 0)
          if state.isResting {
            if let range = state.countdown(isStale: isStale) {
              ActivityRestRing(range: range, palette: palette)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            }
            RestReadout(
              state: state, isStale: isStale, palette: palette,
              timerFont: isFullscreen ? .largeTitle.weight(.bold) : .title2.weight(.bold))
          }
        }
        WorkoutActions(sessionID: sessionID, state: state, isStale: isStale, palette: palette)
      }
    }

    private var header: some View {
      HStack(spacing: 6) {
        // The words beside it already say "FORMA workout"; the mark is decoration here.
        WorkoutMark(palette: palette).accessibilityHidden(true)
        // The public title is neutral. The routine's name is the private part.
        Text("FORMA workout")
          .font(.caption.weight(.semibold)).foregroundStyle(palette.primary)
          .lineLimit(1).fixedSize()
        Text(state.title)
          .font(.caption.weight(.medium)).foregroundStyle(palette.secondary)
          .lineLimit(1)
          .privacySensitive()
        Spacer(minLength: 4)
        WorkoutTimer(range: state.elapsedRange, countsDown: false, maxWidth: 72, showsHours: true)
          .font(.caption.weight(.semibold)).foregroundStyle(palette.primary)
          .elapsedTimeAccessibility(state.elapsedRange)
      }
    }

    /// "Set 3 of 4 · 7 of 18 done", or a stale notice when the app has not updated it for hours.
    private var progressLine: String {
      if isStale, !state.isResting { return "Open FORMA to update" }
      var parts: [String] = []
      if let set = state.setLabel { parts.append(set) }
      if state.totalSets > 0 { parts.append("\(state.doneSets) of \(state.totalSets) done") }
      return parts.joined(separator: " · ")
    }
  }

  // MARK: Apple Watch Smart Stack and CarPlay

  /// The `.small` family: the exercise, then the rest or the set. No buttons, no scrolling.
  /// The palette follows the host's appearance: the Watch Smart Stack is dark, but CarPlay or
  /// another host may draw it light, where lime on white would be unreadable.
  @available(iOS 18.0, *)
  struct WorkoutSmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    var state: WorkoutActivityState
    var isStale: Bool
    private var palette: WorkoutActivityPalette {
      WorkoutActivityPalette(isDark: colorScheme == .dark)
    }

    var body: some View {
      HStack(spacing: 8) {
        if let range = state.countdown(isStale: isStale) {
          ActivityRestRing(range: range, palette: palette)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
        } else {
          WorkoutMark(palette: palette)
        }
        VStack(alignment: .leading, spacing: 0) {
          Text(state.exercise)
            .font(.headline).foregroundStyle(palette.primary)
            .lineLimit(1).minimumScaleFactor(0.85)
            .privacySensitive()
          if state.isResting {
            RestReadout(
              state: state, isStale: isStale, palette: palette, timerFont: .headline,
              alignment: .leading)
          } else {
            Text(state.setLabel ?? "FORMA workout")
              .font(.subheadline.weight(.medium)).foregroundStyle(palette.secondary)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }

  // MARK: Dynamic Island

  /// Compact leading. It carries the meaning on its own: iOS 27 can show the leading view alone
  /// in landscape, so the trailing side only adds the time. A running rest shows its ring, which
  /// fits a 28 pt circle.
  struct IslandCompactLeading: View {
    var state: WorkoutActivityState
    var isStale: Bool
    var body: some View {
      if let range = state.countdown(isStale: isStale) {
        ActivityRestRing(range: range, palette: .dark)
          .frame(width: 22, height: 22)
          .accessibilityLabel("Rest")
      } else {
        WorkoutMark(palette: .dark)
      }
    }
  }

  /// Compact trailing: the rest countdown while resting, else the elapsed time. Both are short.
  struct IslandCompactTrailing: View {
    var state: WorkoutActivityState
    var isStale: Bool
    var body: some View {
      Group {
        if let range = state.countdown(isStale: isStale) {
          WorkoutTimer(range: range, countsDown: true, maxWidth: 48)
        } else if let paused = state.restPausedSeconds {
          Text(WorkoutActivityState.clock(paused)).monospacedDigit()
            .accessibilityLabel(WorkoutActivitySpeech.pausedRest(state))
        } else {
          WorkoutTimer(range: state.elapsedRange, countsDown: false, maxWidth: 48)
            .elapsedTimeAccessibility(state.elapsedRange)
        }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(WorkoutActivityPalette.dark.accent)
    }
  }

  /// The compact trailing slot. On iOS 27, when the Island is limited in width (landscape, iPhone
  /// Duo) the system shows compact and minimal in a 28 pt circle, which a "1:23" cannot fit; the
  /// HIG asks for an empty trailing view then, which the system hides. The leading view carries
  /// the meaning on its own. The check is compiler-gated so the iOS 26.2 SDK in CI still builds.
  struct IslandCompactTrailingSlot: View {
    var state: WorkoutActivityState
    var isStale: Bool
    var body: some View {
      #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
          LimitedWidthAwareTrailing(state: state, isStale: isStale)
        } else {
          IslandCompactTrailing(state: state, isStale: isStale)
        }
      #else
        IslandCompactTrailing(state: state, isStale: isStale)
      #endif
    }
  }

  #if compiler(>=6.4)
    @available(iOS 27.0, *)
    private struct LimitedWidthAwareTrailing: View {
      @Environment(\.isDynamicIslandLimitedInWidth) private var limited
      var state: WorkoutActivityState
      var isStale: Bool
      var body: some View {
        if !limited { IslandCompactTrailing(state: state, isStale: isStale) }
      }
    }
  #endif

  struct IslandMinimal: View {
    var state: WorkoutActivityState
    var isStale: Bool
    var body: some View {
      if let range = state.countdown(isStale: isStale) {
        ActivityRestRing(range: range, palette: .dark)
          .padding(2)
          .accessibilityLabel("Rest")
      } else {
        WorkoutMark(palette: .dark)
      }
    }
  }

  struct IslandExpandedLeading: View {
    var state: WorkoutActivityState
    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        WorkoutMark(palette: .dark)
        if let set = state.setLabel {
          Text(set).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.8)
        }
      }
    }
  }

  struct IslandExpandedTrailing: View {
    var state: WorkoutActivityState
    var isStale: Bool
    private let palette = WorkoutActivityPalette.dark
    var body: some View {
      if state.isResting {
        RestReadout(
          state: state, isStale: isStale, palette: palette, timerFont: .title3.weight(.bold))
      } else {
        VStack(alignment: .trailing, spacing: 0) {
          Text("Elapsed").font(.caption.weight(.semibold)).foregroundStyle(palette.secondary)
          WorkoutTimer(
            range: state.elapsedRange, countsDown: false, maxWidth: 96, showsHours: true
          )
          .font(.title3.weight(.bold)).foregroundStyle(palette.accent)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  struct IslandExpandedCenter: View {
    var state: WorkoutActivityState
    var body: some View {
      Text(state.exercise)
        .font(.headline).foregroundStyle(.white)
        .lineLimit(1).minimumScaleFactor(0.8)
        .privacySensitive()
    }
  }

  struct IslandExpandedBottom: View {
    var sessionID: String
    var state: WorkoutActivityState
    var isStale: Bool
    var body: some View {
      WorkoutActions(
        sessionID: sessionID, state: state, isStale: isStale, palette: .dark)
    }
  }
#endif
