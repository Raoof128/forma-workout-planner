import SwiftUI

/// The haptics FORMA plays for real events, each mapped to the one system
/// pattern whose documented meaning fits it (HIG Playing haptics; see
/// ios/docs/commit-2/APPLE_RESEARCH.md section 7). A pattern keeps one meaning
/// so people learn it, and none is ever the only confirmation: every event
/// also changes something on screen.
///
/// Set completion and the receipt keep their own triggers (WorkoutView and
/// CompletionSeal); everything else goes through `AppModel.haptic(_:)`.
enum FormaHaptic: Sendable {
  /// A workout, hold or rest began counting.
  case started
  /// A hold or rest stopped counting (paused, skipped or cancelled).
  case stopped
  /// A stepped value went up or down (hold length, rest +15 s).
  case increased, decreased
  /// The current choice changed (another exercise).
  case selected
  /// A completed set was reopened.
  case undone
  /// A set was added.
  case added
  /// An action was refused and the screen says why (validation).
  case warning
  /// A change could not be saved.
  case failed

  var feedback: SensoryFeedback {
    switch self {
    case .started: .start
    case .stopped: .stop
    case .increased: .increase
    case .decreased: .decrease
    case .selected: .selection
    case .undone: .impact(flexibility: .soft, intensity: 0.6)
    case .added: .impact(flexibility: .solid, intensity: 0.7)
    case .warning: .warning
    case .failed: .error
    }
  }
}

/// One occurrence of a haptic. The id makes two identical events in a row
/// two triggers, so a repeated action is felt each time.
struct FormaHapticEvent: Equatable, Sendable {
  let kind: FormaHaptic
  let id = UUID()

  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Plays `AppModel.hapticEvent`. It lives in a zero-size background view so
/// only this leaf observes the event, not the whole tree.
struct FormaHapticRelay: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
      .sensoryFeedback(trigger: model.hapticEvent) { _, event in
        guard model.hapticsEnabled, let event else { return nil }
        return event.kind.feedback
      }
  }
}
