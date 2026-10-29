import AppIntents
import Foundation

/// A button press on the Lock Screen or in the Dynamic Island.
enum LiveActivityAction: Sendable, Equatable {
  case completeSet(sessionID: String)
  case skipRest(sessionID: String)
}

/// Where the intents land. The app installs `handler` at launch; the widget extension never does,
/// so an intent that somehow ran there would do nothing. The extension never writes storage: the
/// system runs a `LiveActivityIntent` in the app's process, and the handler goes through the
/// model's own validated commit path.
@MainActor
enum LiveActivityActions {
  static var handler: (@MainActor (LiveActivityAction) async -> Void)?

  static func run(_ action: LiveActivityAction) async {
    await handler?(action)
  }
}

/// "Complete set": ticks the next unfinished set of the current exercise, as the in-app ✓ does.
struct CompleteSetIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Complete set"
  static let description = IntentDescription("Marks the next set of your current exercise done.")
  static let isDiscoverable = false
  /// A saved workout and its data are unreadable while the iPhone is locked, so ask for unlock.
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  /// The workout the button was drawn for. A press after that workout ended does nothing.
  @Parameter(title: "Workout") var sessionID: String

  init() {}
  init(sessionID: String) { self.sessionID = sessionID }

  @MainActor
  func perform() async throws -> some IntentResult {
    await LiveActivityActions.run(.completeSet(sessionID: sessionID))
    return .result()
  }
}

/// "Skip rest": ends the running or paused rest, as the rest dock's Skip does.
struct SkipRestIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Skip rest"
  static let description = IntentDescription("Ends the rest between sets.")
  static let isDiscoverable = false
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: "Workout") var sessionID: String

  init() {}
  init(sessionID: String) { self.sessionID = sessionID }

  @MainActor
  func perform() async throws -> some IntentResult {
    await LiveActivityActions.run(.skipRest(sessionID: sessionID))
    return .result()
  }
}
