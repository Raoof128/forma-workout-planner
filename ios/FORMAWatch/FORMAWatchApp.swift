import HealthKit
import SwiftUI
import WatchKit

@main
struct FORMAWatchApp: App {
  @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

  var body: some Scene {
    WindowGroup {
      WatchRootView().environment(WorkoutManager.shared)
    }
  }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
  /// The iPhone opened FORMA here with `startWatchApp(toHandle:)`.
  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    WorkoutManager.shared.prepare(workoutConfiguration)
  }

  /// watchOS relaunched FORMA after it quit during a workout.
  func handleActiveWorkoutRecovery() {
    Task { await WorkoutManager.shared.recover() }
  }
}
