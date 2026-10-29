import Combine
import SwiftUI
import UIKit

// FORMA's motion system: one resolved level, a small set of timing tokens and
// helpers that degrade to a cross-fade or to nothing. See
// ios/docs/commit-2/MOTION_SPEC.md for the rules behind each token.

/// How much of FORMA's own motion to play.
///
/// System Reduce Motion always wins over the You › Motion preference. With it
/// on, spatial movement becomes a short cross-fade (Apple's HIG guidance for
/// reduced motion), and FORMA's "Off" removes even that. "Off" covers FORMA's
/// own decorative motion only; native system transitions are not ours to turn
/// off.
enum FormaMotionLevel: Sendable, Equatable {
  /// Springs, spatial transitions and one-time emphasis.
  case full
  /// Short cross-fades in place of movement or scale.
  case minimal
  /// Instant state changes; every final state is still shown.
  case off

  init(preference: MotionPreference, reduceMotion: Bool, prefersCrossFade: Bool = false) {
    switch preference {
    case .off: self = .off
    case .minimal: self = .minimal
    case .system: self = reduceMotion || prefersCrossFade ? .minimal : .full
    }
  }

  /// The animation to use for `token` at this level, or nil for none.
  func animation(_ token: Animation) -> Animation? {
    switch self {
    case .full: token
    case .minimal: FormaMotion.fade
    case .off: nil
    }
  }

  /// A spatial transition at full motion, a fade at minimal, none when off.
  func transition(_ full: AnyTransition) -> AnyTransition {
    switch self {
    case .full: full
    case .minimal: .opacity
    case .off: .identity
    }
  }

  var allowsSpatialMotion: Bool { self == .full }
}

/// Timing tokens. Durations are design choices tuned for gym use (short,
/// interruptible, no overshoot on data), not Apple-mandated values.
enum FormaMotion {
  /// 120 ms. Press acknowledgement on buttons and cards.
  static let press = Animation.spring(duration: 0.12, bounce: 0)
  /// 180 ms. Small state changes, such as a set turning complete.
  static let state = Animation.spring(duration: 0.18, bounce: 0.12)
  /// 300 ms. Content appearing or disappearing, card expansion.
  static let reveal = Animation.spring(duration: 0.3, bounce: 0.08)
  /// 380 ms. Larger, navigation-scale choreography.
  static let navigation = Animation.spring(duration: 0.38, bounce: 0.1)
  /// 420 ms with a little overshoot. The tab highlight sliding to a new tab,
  /// so the choice lands with a small settle instead of stopping dead.
  static let tabSelection = Animation.spring(duration: 0.42, bounce: 0.28)
  /// 520 ms. One-time emphasis for genuine progress: a finished workout.
  static let emphasis = Animation.spring(duration: 0.52, bounce: 0.22)
  /// 160 ms. The minimal-level replacement for any spatial animation.
  static let fade = Animation.easeOut(duration: 0.16)
  /// Delay between staggered siblings in a one-time reveal.
  static let stagger: Double = 0.05
}

private struct FormaMotionLevelKey: EnvironmentKey {
  static let defaultValue: FormaMotionLevel = .full
}

extension EnvironmentValues {
  /// FORMA's resolved motion level. Set once at the root from the preference
  /// and the system Reduce Motion setting.
  var formaMotion: FormaMotionLevel {
    get { self[FormaMotionLevelKey.self] }
    set { self[FormaMotionLevelKey.self] = newValue }
  }
}

/// Resolves the motion level from the system setting and the preference and
/// publishes it to the whole view tree.
@MainActor
private struct FormaMotionRoot: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var prefersCrossFade = UIAccessibility.prefersCrossFadeTransitions
  let preference: MotionPreference

  func body(content: Content) -> some View {
    content
      .environment(
        \.formaMotion,
        FormaMotionLevel(
          preference: preference, reduceMotion: reduceMotion, prefersCrossFade: prefersCrossFade)
      )
      // UIKit exposes this preference from iOS 14. A runtime availability check
      // cannot make the newer SwiftUI environment symbol compile on older SDKs.
      .onReceive(
        NotificationCenter.default.publisher(
          for: UIAccessibility.prefersCrossFadeTransitionsStatusDidChange
        ).receive(on: RunLoop.main)
      ) { _ in
        prefersCrossFade = UIAccessibility.prefersCrossFadeTransitions
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { prefersCrossFade = UIAccessibility.prefersCrossFadeTransitions }
      }
  }
}

private struct FormaAnimation<Value: Equatable>: ViewModifier {
  @Environment(\.formaMotion) private var level
  let token: Animation
  let value: Value

  func body(content: Content) -> some View {
    content.animation(level.animation(token), value: value)
  }
}

/// Fades and lifts content in once per view lifetime. A view kept alive by a
/// TabView keeps its state, so switching tabs does not replay it; minimal and
/// off levels show the content at once.
private struct FormaReveal: ViewModifier {
  @Environment(\.formaMotion) private var level
  @State private var shown = false
  let order: Int

  func body(content: Content) -> some View {
    let hidden = !shown && level.allowsSpatialMotion
    content
      .opacity(hidden ? 0 : 1)
      .offset(y: hidden ? 12 : 0)
      .onAppear {
        guard !shown else { return }
        if level.allowsSpatialMotion {
          withAnimation(FormaMotion.reveal.delay(Double(order) * FormaMotion.stagger)) {
            shown = true
          }
        } else {
          shown = true
        }
      }
  }
}

extension View {
  /// Publishes the motion level resolved from `preference` and Reduce Motion.
  @MainActor func formaMotionRoot(_ preference: MotionPreference) -> some View {
    modifier(FormaMotionRoot(preference: preference))
  }

  /// Animates changes to `value` with `token`, degraded for the current level.
  func formaAnimation<Value: Equatable>(_ token: Animation, value: Value) -> some View {
    modifier(FormaAnimation(token: token, value: value))
  }

  /// A one-time entrance; `order` staggers siblings by `FormaMotion.stagger`.
  func formaReveal(order: Int = 0) -> some View {
    modifier(FormaReveal(order: order))
  }
}

/// Runs `body` with `token` at the given level (or without animation when off).
@MainActor
func withFormaAnimation<Result>(
  _ level: FormaMotionLevel, _ token: Animation, _ body: () throws -> Result
) rethrows -> Result {
  if let animation = level.animation(token) {
    return try withAnimation(animation, body)
  }
  return try body()
}
