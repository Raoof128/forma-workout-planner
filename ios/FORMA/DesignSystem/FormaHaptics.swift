import SwiftUI

/// The haptics FORMA plays for real events, each mapped to the one system
/// pattern whose documented meaning fits it (HIG Playing haptics; see
/// ios/docs/commit-2/APPLE_RESEARCH.md section 7). A pattern keeps one meaning
/// so people learn it, and none is ever the only confirmation: every event
/// also changes something on screen.
///
/// Set completion and the receipt keep their own triggers (WorkoutView and
/// CompletionSeal); everything else goes through `AppModel.haptic(_:)`.
///
/// Training cases (`started` to `failed`) belong to the workout: a sign-in or a
/// saved profile must not feel like a set starting, so account outcomes have
/// their own `account…` cases. Use them like this:
///
/// | Account event | Case | Pattern |
/// |---|---|---|
/// | Signed in, two-step enabled, password or profile saved, email verified, import finished | `accountSuccess` | `.success` |
/// | A link or email was sent (reset, verification, new coach token issued) | `accountSent` | soft impact |
/// | A session, device or token was revoked, signed out, account data removed | `accountRemoved` | rigid impact |
/// | A request was refused and the screen says why (wrong password, bad code) | `accountWarning` | `.warning` |
/// | A request failed (offline, server error, could not save) | `accountFailure` | `.error` |
///
/// `FormaHapticRelay` plays every case, warnings and failures included, when
/// You › Haptics is on; the setting is one switch for all of them, not only for
/// set confirmation.
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
  /// An account change went through: sign-in, two-step, password, profile.
  case accountSuccess
  /// A link, email or one-time token was sent or issued.
  case accountSent
  /// A session, device or token was revoked, or the account was signed out.
  case accountRemoved
  /// An account request was refused and the screen explains why.
  case accountWarning
  /// An account request failed and nothing changed.
  case accountFailure

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
    case .accountSuccess: .success
    case .accountSent: .impact(flexibility: .soft, intensity: 0.5)
    case .accountRemoved: .impact(flexibility: .rigid, intensity: 0.6)
    case .accountWarning: .warning
    case .accountFailure: .error
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
