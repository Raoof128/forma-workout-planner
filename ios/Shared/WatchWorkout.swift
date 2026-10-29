import Foundation
import HealthKit

/// Compiled into both the iPhone and Apple Watch apps. Sets, weights and notes
/// stay in the FORMA workspace on the iPhone; heart rate and energy are
/// recorded by the Watch into Apple Health and never enter the workspace.
enum WatchWorkout {
  /// FORMA logs resistance training; Health shows it as Traditional Strength Training.
  static func configuration() -> HKWorkoutConfiguration {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .traditionalStrengthTraining
    configuration.locationType = .indoor
    return configuration
  }

  static let shareTypes: Set<HKSampleType> = [
    HKObjectType.workoutType(),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.heartRate),
  ]

  static let readTypes: Set<HKObjectType> = [
    HKObjectType.workoutType(),
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.basalEnergyBurned),
  ]

  /// Application-context keys the iPhone sets before opening the Watch app.
  static let routineNameKey = "pendingRoutineName"
  static let requestedAtKey = "pendingRequestedAt"
}

/// Messages over the mirrored workout session (iOS 17 / watchOS 10).
enum WatchWorkoutMessage: Codable, Equatable, Sendable {
  /// Watch to iPhone, about once a second while recording.
  case metrics(WatchMetrics)
  /// iPhone to Watch.
  case pause
  case resume
  case end(save: Bool)

  func encoded() throws -> Data { try JSONEncoder().encode(self) }
  static func decode(_ data: Data) -> WatchWorkoutMessage? {
    try? JSONDecoder().decode(WatchWorkoutMessage.self, from: data)
  }
}

struct WatchMetrics: Codable, Equatable, Sendable {
  enum State: String, Codable, Sendable { case running, paused, ended }

  var state: State
  var startedAt: Date
  /// Active (unpaused) time, as HealthKit's builder reports it.
  var elapsed: TimeInterval
  var heartRate: Double?
  var averageHeartRate: Double?
  /// Kilocalories of active energy.
  var activeEnergy: Double?
}
