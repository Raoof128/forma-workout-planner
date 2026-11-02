import Foundation

/// What an Apple Watch recorded for a finished workout, in whole numbers. The
/// web schema (`watchSummarySchema` in src/storage.js) has the same fields and
/// bounds; only history sessions carry one.
public struct WorkoutWatchSummary: Codable, Equatable, Sendable {
  /// Active (unpaused) time the Watch recorded.
  public var elapsedSeconds: Int
  public var averageHeartRate: Int?
  public var maxHeartRate: Int?
  public var activeEnergyKcal: Int?

  public init(
    elapsedSeconds: Int, averageHeartRate: Int? = nil, maxHeartRate: Int? = nil,
    activeEnergyKcal: Int? = nil
  ) {
    self.elapsedSeconds = elapsedSeconds
    self.averageHeartRate = averageHeartRate
    self.maxHeartRate = maxHeartRate
    self.activeEnergyKcal = activeEnergyKcal
  }

  public static let heartRateRange = 25...250
  public static let elapsedRange = 0...86_400
  public static let energyRange = 0...10_000

  /// Rounds live readings into a summary the workspace accepts. A reading
  /// outside the stored bounds is dropped rather than clamped, so a sensor
  /// glitch is never saved as a real number; time is capped at one day.
  public init(
    elapsed: TimeInterval, averageHeartRate: Double?, maxHeartRate: Double?,
    activeEnergy: Double?
  ) {
    func whole(_ value: Double?, in range: ClosedRange<Int>) -> Int? {
      guard let value, value.isFinite else { return nil }
      let rounded = Int(value.rounded())
      return range.contains(rounded) ? rounded : nil
    }
    let seconds = elapsed.isFinite ? Int(max(0, elapsed.rounded(.down))) : 0
    var average = whole(averageHeartRate, in: Self.heartRateRange)
    let maximum = whole(maxHeartRate, in: Self.heartRateRange)
    if let a = average, let m = maximum, m < a { average = m }
    self.init(
      elapsedSeconds: min(seconds, Self.elapsedRange.upperBound), averageHeartRate: average,
      maxHeartRate: maximum, activeEnergyKcal: whole(activeEnergy, in: Self.energyRange))
  }

  /// Whether this summary is inside the bounds the web schema enforces.
  public var isValid: Bool {
    guard Self.elapsedRange.contains(elapsedSeconds) else { return false }
    for rate in [averageHeartRate, maxHeartRate].compactMap({ $0 })
    where !Self.heartRateRange.contains(rate) { return false }
    if let average = averageHeartRate, let maximum = maxHeartRate, maximum < average {
      return false
    }
    if let energy = activeEnergyKcal, !Self.energyRange.contains(energy) { return false }
    return true
  }
}
