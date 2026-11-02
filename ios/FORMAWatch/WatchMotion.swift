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
/// screen invites a tap. The rings only run while this screen is lit.
struct StartDisc: View {
  let label: String
  let action: () -> Void

  var body: some View {
    MotionGate { animates in
      Button(action: action) {
        ZStack {
          if animates {
            RippleRing(delay: 0)
            RippleRing(delay: 0.9)
          }
          Circle().fill(WatchTheme.lime).frame(width: 78, height: 78)
          Image(systemName: "play.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(WatchTheme.ink)
            .offset(x: 2)
        }
        .frame(width: 112, height: 112)
        .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)
      .accessibilityLabel(label)
    }
  }
}

private struct RippleRing: View {
  let delay: Double

  var body: some View {
    Circle()
      .stroke(WatchTheme.lime, lineWidth: 2)
      .frame(width: 78, height: 78)
      .phaseAnimator([false, true]) { ring, expanded in
        ring.scaleEffect(expanded ? 1.42 : 1).opacity(expanded ? 0 : 0.7)
      } animation: { expanded in
        expanded ? .easeOut(duration: 1.8).delay(delay) : .linear(duration: 0)
      }
      .accessibilityHidden(true)
  }
}

/// Three, two, one before the recording starts, as Apple's Workout app does: a
/// lime ring drains with each number and the wrist taps once per count. A tap
/// anywhere skips it. The numbers still count with Reduce Motion, without the
/// sweep.
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
          try? await Task.sleep(for: .seconds(1))
          if Task.isCancelled { return }
        }
        complete()
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Starting in \(count)")
    .accessibilityHint("Tap to start now.")
    .accessibilityAddTraits(.updatesFrequently)
  }

  private func complete() {
    guard !finished else { return }
    finished = true
    finish()
  }
}

// MARK: - Loading

/// The wait while HealthKit starts, restores or saves: a lime arc circles a
/// beating heart, so the screen never looks frozen.
struct LoadingHeart: View {
  @State private var spinning = false

  var body: some View {
    MotionGate { animates in
      ZStack {
        Circle().stroke(WatchTheme.lime.opacity(0.2), lineWidth: 3)
        if animates {
          Circle()
            .trim(from: 0, to: 0.28)
            .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
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
/// wrist is raised. The loop sleeps between beats and stops with the view.
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
            beat &+= 1
            try? await Task.sleep(for: .seconds(interval))
          }
        }
    }
  }
}

// MARK: - Summary

/// The finished seal: a lime ring draws itself closed, then the check lands.
/// A discarded recording gets a still, grey mark instead.
struct SummarySeal: View {
  let saved: Bool
  @State private var drawn = false

  var body: some View {
    MotionGate { animates in
      ZStack {
        Circle().stroke(Color.white.opacity(0.14), lineWidth: 5)
        if saved {
          Circle()
            .trim(from: 0, to: drawn || !animates ? 1 : 0)
            .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(-90))
        }
        Image(systemName: saved ? "checkmark" : "xmark")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(saved ? WatchTheme.lime : Color.secondary)
          .scaleEffect(drawn || !animates ? 1 : 0.2)
          .opacity(drawn || !animates ? 1 : 0)
      }
      .frame(width: 50, height: 50)
      .onAppear {
        guard animates, !drawn else { return }
        withAnimation(.easeOut(duration: 0.7)) { drawn = true }
      }
    }
    .accessibilityHidden(true)
  }
}

/// Rises into place after `order` beats, once, when the summary appears.
struct Reveal: ViewModifier {
  let order: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isLuminanceReduced) private var luminanceReduced
  @State private var shown = false

  func body(content: Content) -> some View {
    let animates = !reduceMotion && !luminanceReduced
    content
      .opacity(shown || !animates ? 1 : 0)
      .offset(y: shown || !animates ? 0 : 8)
      .onAppear {
        guard animates, !shown else { return }
        withAnimation(.snappy(duration: 0.35).delay(0.45 + Double(order) * 0.12)) { shown = true }
      }
  }
}

extension View {
  func reveal(_ order: Int) -> some View { modifier(Reveal(order: order)) }
}
