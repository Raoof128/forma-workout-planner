import Accessibility
import SwiftUI
import WatchKit

/// The Watch app's motion. Every piece checks the same two things: the person
/// has not asked for less motion, and the wrist is raised. A dimmed (Always On)
/// display never animates, and Reduce Motion gets the same screens, still.

/// Reads whether motion is allowed, for views that need it in their body.
struct MotionGate<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @ViewBuilder let content: (_ animates: Bool) -> Content

  var body: some View { content(!reduceMotion && !luminanceReduced) }
}

// MARK: - Start

/// The start control: a lime disc with rings rippling outward, so the first
/// screen invites a tap. The rings pulse three times while this screen is lit,
/// then rest, and fade out rather than vanish when the wrist drops.
struct StartDisc: View {
  let label: String
  let action: () -> Void

  var body: some View {
    MotionGate { animates in
      Button(action: action) {
        ZStack {
          if animates {
            RippleRing(delay: 0).transition(.opacity)
            RippleRing(delay: RippleRing.period / 2).transition(.opacity)
          }
          Circle().fill(WatchTheme.lime).frame(width: 78, height: 78)
          Image(systemName: "play.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(WatchTheme.ink)
            .offset(x: 2)
        }
        .frame(width: 112, height: 112)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.3), value: animates)
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)
      .accessibilityLabel(label)
    }
  }
}

/// One ring of the start disc. Both rings share one period, and the second is
/// offset once at the start, so the stagger stays even across the pulses.
private struct RippleRing: View {
  static let period = 2.0
  static let pulses = 3
  let delay: Double
  @State private var pulse = 0

  var body: some View {
    Circle()
      .stroke(WatchTheme.lime, lineWidth: 2)
      .frame(width: 78, height: 78)
      .phaseAnimator([false, true], trigger: pulse) { ring, expanded in
        ring.scaleEffect(expanded ? 1.42 : 1).opacity(expanded ? 0 : 0.7)
      } animation: { expanded in
        expanded ? .easeOut(duration: 1.8) : .linear(duration: 0)
      }
      .task {
        try? await Task.sleep(for: .seconds(delay))
        for _ in 0..<Self.pulses {
          if Task.isCancelled { return }
          pulse += 1
          try? await Task.sleep(for: .seconds(Self.period))
        }
      }
      .accessibilityHidden(true)
  }
}

/// Three, two, one while the prepared session warms its sensors, as Apple's
/// Workout app does: a lime ring drains with each number, the wrist taps once
/// per count and VoiceOver speaks it. A tap anywhere starts at once. The
/// numbers still count with Reduce Motion, without the sweep.
struct StartCountdown: View {
  let finish: () -> Void
  @State private var count = 3
  @State private var remaining = 1.0
  @State private var finished = false

  var body: some View {
    MotionGate { animates in
      ZStack {
        Circle().stroke(WatchTheme.lime.opacity(0.18), lineWidth: 9)
        Circle()
          .trim(from: 0, to: remaining)
          .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 9, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text("\(count)")
          .font(.system(size: 68, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(WatchTheme.lime)
          .contentTransition(animates ? .numericText(countsDown: true) : .identity)
      }
      .padding(14)
      .contentShape(Rectangle())
      .onTapGesture { complete() }
      .task {
        for step in stride(from: 3, through: 1, by: -1) {
          if animates {
            withAnimation(.snappy(duration: 0.25)) { count = step }
            withAnimation(.linear(duration: 1)) { remaining = Double(step - 1) / 3 }
          } else {
            count = step
            remaining = Double(step - 1) / 3
          }
          WKInterfaceDevice.current().play(.click)
          AccessibilityNotification.Announcement("\(step)").post()
          try? await Task.sleep(for: .seconds(1))
          if Task.isCancelled || finished { return }
        }
        complete()
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Starting in \(count)")
    .accessibilityHint("Starts recording now.")
    .accessibilityAddTraits([.isButton, .updatesFrequently])
    .accessibilityAction { complete() }
    .accessibilityAction(named: "Start now") { complete() }
  }

  private func complete() {
    guard !finished else { return }
    finished = true
    finish()
  }
}

// MARK: - Loading

/// The wait while HealthKit starts, restores or saves: a lime arc circles a
/// beating heart, so the screen never looks frozen. The arc drives its own
/// turn, so it starts again whenever the wrist is raised.
struct LoadingHeart: View {
  var body: some View {
    MotionGate { animates in
      ZStack {
        Circle().stroke(WatchTheme.lime.opacity(0.2), lineWidth: 3)
        if animates {
          Circle()
            .trim(from: 0, to: 0.28)
            .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .phaseAnimator([0.0, 360.0]) { arc, angle in
              arc.rotationEffect(.degrees(angle))
            } animation: { angle in
              angle == 0 ? .linear(duration: 0) : .linear(duration: 1.1)
            }
        }
        Image(systemName: "heart.fill")
          .font(.title2).foregroundStyle(.red)
          .symbolEffect(.pulse, options: .repeating, isActive: animates)
      }
      .frame(width: 56, height: 56)
    }
    .accessibilityHidden(true)
  }
}

// MARK: - Live readings

/// A symbol that beats once per heartbeat at the measured rate, while the
/// wrist is raised. The loop sleeps before each beat, so a new reading keeps
/// the rhythm instead of forcing an extra beat, and it stops with the view.
struct HeartbeatSymbol: View {
  let beatsPerMinute: Int?
  @State private var beat = 0

  var body: some View {
    MotionGate { animates in
      Image(systemName: "heart.fill")
        .foregroundStyle(.red)
        .symbolEffect(.bounce.down, options: .speed(1.6), value: beat)
        .task(id: animates ? beatsPerMinute : nil) {
          guard animates, let bpm = beatsPerMinute, bpm > 0 else { return }
          let interval = 60 / Double(min(max(bpm, 30), 220))
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            if Task.isCancelled { return }
            beat &+= 1
          }
        }
    }
  }
}

// MARK: - Summary

/// The finished seal: a lime ring draws itself closed, then the check lands.
/// A discarded recording gets a still, grey mark instead. Shown on a dimmed
/// wrist or with Reduce Motion, it is drawn at once and stays drawn, so a
/// later wrist raise never hides it.
struct SummarySeal: View {
  let saved: Bool
  @State private var ringDrawn = false
  @State private var checkLanded = false

  var body: some View {
    MotionGate { animates in
      // A still seal is drawn from its first frame; `onAppear` then records it.
      let still = !animates || !saved
      ZStack {
        Circle().stroke(Color.white.opacity(0.14), lineWidth: 5)
        if saved {
          Circle()
            .trim(from: 0, to: ringDrawn || still ? 1 : 0)
            .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(-90))
        }
        Image(systemName: saved ? "checkmark" : "xmark")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(saved ? WatchTheme.lime : Color.secondary)
          .scaleEffect(checkLanded || still ? 1 : 0.2)
          .opacity(checkLanded || still ? 1 : 0)
      }
      .frame(width: 50, height: 50)
      .onAppear {
        guard !checkLanded else { return }
        if !still {
          withAnimation(.easeOut(duration: 0.5)) { ringDrawn = true }
          withAnimation(.spring(duration: 0.3, bounce: 0.35).delay(0.45)) { checkLanded = true }
        } else {
          // Still states count as already drawn.
          ringDrawn = true
          checkLanded = true
        }
      }
    }
    .accessibilityHidden(true)
  }
}

/// Rises into place after `order` beats, once, when the summary appears. On a
/// dimmed wrist or with Reduce Motion it is placed at once and counts as
/// revealed, so a later wrist raise never hides it.
struct Reveal: ViewModifier {
  let order: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var shown = false

  func body(content: Content) -> some View {
    // Still content is in place from its first frame; `onAppear` records it.
    let animates = !reduceMotion && !luminanceReduced
    content
      .opacity(shown || !animates ? 1 : 0)
      .offset(y: shown || !animates ? 0 : 8)
      .onAppear {
        guard !shown else { return }
        if animates {
          withAnimation(.snappy(duration: 0.35).delay(0.45 + Double(order) * 0.12)) {
            shown = true
          }
        } else {
          shown = true
        }
      }
  }
}

extension View {
  func reveal(_ order: Int) -> some View { modifier(Reveal(order: order)) }
}
