import Foundation

/// A hold is one physical effort, even if its deadline and End button arrive
/// together. Keep its exact duration until the store acknowledges that effort.
struct HoldLogState {
  struct Attempt: Equatable {
    let id = UUID()
    let holdID: UUID
    let seconds: Int
  }

  private enum Phase { case ready, saving, retry, saved, cancelled }
  private var phase: Phase = .cancelled
  private var holdID: UUID?
  private(set) var attempt: Attempt?

  var isSaving: Bool { phase == .saving }
  var needsRetry: Bool { phase == .retry }

  @discardableResult
  mutating func begin(_ id: UUID) -> Bool {
    guard !isSaving, holdID != id else { return false }
    holdID = id
    attempt = nil
    phase = .ready
    return true
  }

  /// Claim synchronously before any await. A retry uses the original duration,
  /// never time spent waiting for storage or correcting another field.
  mutating func claim(holdID id: UUID, seconds: Int) -> Attempt? {
    guard holdID == id, phase == .ready || phase == .retry, seconds > 0 else { return nil }
    let claimed = Attempt(holdID: id, seconds: attempt?.seconds ?? seconds)
    attempt = claimed
    phase = .saving
    return claimed
  }

  @discardableResult
  mutating func failed(_ submitted: Attempt) -> Bool {
    guard isSaving, attempt == submitted else { return false }
    phase = .retry
    return true
  }

  @discardableResult
  mutating func acknowledged(_ submitted: Attempt) -> Bool {
    guard isSaving, attempt == submitted else { return false }
    phase = .saved
    attempt = nil
    return true
  }

  mutating func cancel(_ id: UUID) {
    guard holdID == id, !isSaving else { return }
    phase = .cancelled
    attempt = nil
  }
}
