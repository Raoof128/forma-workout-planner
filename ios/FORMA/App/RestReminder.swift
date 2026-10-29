import Foundation
import UserNotifications

/// The notification centre as the reminder uses it, so a test can stand in.
protocol RestNotificationCenter: Sendable {
  func status() async -> UNAuthorizationStatus
  func askPermission() async -> Bool
  func schedule(_ request: UNNotificationRequest) async
  func cancel(identifier: String)
}

extension UNUserNotificationCenter: RestNotificationCenter {
  func status() async -> UNAuthorizationStatus {
    await notificationSettings().authorizationStatus
  }

  func askPermission() async -> Bool {
    (try? await requestAuthorization(options: [.alert, .sound])) ?? false
  }

  func schedule(_ request: UNNotificationRequest) async {
    try? await add(request)
  }

  func cancel(identifier: String) {
    removePendingNotificationRequests(withIdentifiers: [identifier])
  }
}

/// UI tests and previews never ask for permission or schedule anything.
private struct SilentNotificationCenter: RestNotificationCenter {
  func status() async -> UNAuthorizationStatus { .denied }
  func askPermission() async -> Bool { false }
  func schedule(_ request: UNNotificationRequest) async {}
  func cancel(identifier: String) {}
}

/// When, if at all, a rest-end reminder should fire. Pure, so it is tested
/// without a notification centre.
enum RestReminderPlan {
  /// Seconds from `now` (Unix milliseconds) until the rest ends, or nil when
  /// nothing should be pending: the app is in front and cues the end itself,
  /// no rest is counting down, or the deadline has already passed.
  static func delay(restEnd: Double?, now: Double, appActive: Bool) -> TimeInterval? {
    guard !appActive, let restEnd else { return nil }
    let seconds = (restEnd - now) / 1_000
    // A calendar-free interval trigger needs at least a second.
    return seconds >= 1 ? seconds : nil
  }
}

/// A local notification for the end of a rest, so a locked or backgrounded
/// phone still cues the next set. It exists only while the app is out of the
/// foreground: coming back, skipping, pausing, extending, finishing or
/// discarding all cancel it, and the in-app dock cues the end itself. Denied
/// permission degrades silently to that in-app cue.
@MainActor
final class RestReminder {
  static let identifier = "forma.rest-end"
  static let shared = RestReminder(
    center: ProcessInfo.processInfo.arguments.contains("--ui-testing")
      ? SilentNotificationCenter() : UNUserNotificationCenter.current())

  private let center: any RestNotificationCenter
  /// Each call supersedes earlier ones still waiting on the centre, so a slow
  /// permission lookup cannot schedule after the person has come back.
  private var generation = 0

  init(center: any RestNotificationCenter) { self.center = center }

  /// Asks once, the first time a rest starts, so the prompt arrives with the
  /// reason for it. Later calls do nothing: the system never re-asks.
  func requestAuthorizationIfNeeded() async {
    guard await center.status() == .notDetermined else { return }
    _ = await center.askPermission()
  }

  /// Brings the pending reminder in line with the rest and the app's state.
  /// `muted` is the profile's training-sound preference.
  func sync(restEnd: Double?, muted: Bool, appActive: Bool, now: Double = RestReminder.now) async {
    generation += 1
    let current = generation
    guard
      let delay = RestReminderPlan.delay(restEnd: restEnd, now: now, appActive: appActive)
    else {
      center.cancel(identifier: Self.identifier)
      return
    }
    let status = await center.status()
    guard current == generation,
      [.authorized, .provisional, .ephemeral].contains(status)
    else { return }
    let content = UNMutableNotificationContent()
    content.title = "Rest finished"
    // Nothing about the workout: this shows on a locked screen.
    content.body = "Ready for your next set."
    content.sound = muted ? nil : .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    await center.schedule(
      UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
  }

  func cancel() {
    generation += 1
    center.cancel(identifier: Self.identifier)
  }

  nonisolated static var now: Double { Date.now.timeIntervalSince1970 * 1_000 }
}
