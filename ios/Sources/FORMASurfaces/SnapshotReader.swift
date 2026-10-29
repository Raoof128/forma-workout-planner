import Foundation

/// What the extension learned from the shared file. Separates "locked" from "broken" because they
/// recover differently: a protected file is fine and only needs a prompt retry after unlock.
public enum SnapshotReadResult: Equatable, Sendable {
  case snapshot(TrainingSnapshot)
  /// The file is there but its contents cannot be read right now (Complete file protection while
  /// the device is locked, or a read that failed for a reason other than absence).
  /// `lastPublished` is the file's modification time, which stays readable while locked. It
  /// drives the retry back-off (see `TrainingTimelinePlan.protectedRetryInterval`).
  case protectedDataUnavailable(lastPublished: Date?)
  /// Missing, oversized, corrupt, or a contract this build does not understand.
  case unavailable
}

public enum SnapshotReader {
  public static let maxBytes = 32_768

  /// `fileSize` and `load` are seams for tests; production uses the file system.
  public static func read(
    url: URL, at now: Date,
    fileSize: (URL) throws -> Int? = { try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize },
    load: (URL) throws -> Data = { try Data(contentsOf: $0) },
    modified: (URL) -> Date? = {
      try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
  ) -> SnapshotReadResult {
    let size: Int
    do { size = try fileSize(url) ?? 0 } catch { return failure(error, url, modified) }
    // Bound the file before mapping it, then validate the independent versioned contract.
    guard size > 0, size <= maxBytes else { return .unavailable }
    let data: Data
    do { data = try load(url) } catch { return failure(error, url, modified) }
    guard let value = try? TrainingSnapshot.decode(data, at: now) else { return .unavailable }
    return .snapshot(value)
  }

  private static func failure(
    _ error: Error, _ url: URL, _ modified: (URL) -> Date?
  ) -> SnapshotReadResult {
    isMissing(error) ? .unavailable : .protectedDataUnavailable(lastPublished: modified(url))
  }

  private static func isMissing(_ error: Error) -> Bool {
    let ns = error as NSError
    if ns.domain == NSCocoaErrorDomain,
      [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(ns.code)
    {
      return true
    }
    if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOENT) { return true }
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isMissing(underlying) }
    return false
  }
}

/// The entries and reload time for one timeline request, decided away from WidgetKit so the
/// locked-device behaviour can be unit tested.
public struct TrainingTimelinePlan: Equatable, Sendable {
  public struct Entry: Equatable, Sendable {
    public let date: Date
    public let snapshot: TrainingSnapshot
    /// True when the file could not be read because the device is locked.
    public let awaitingUnlock: Bool
  }

  /// Regular cadence. WidgetKit treats reloads as a budgeted request, not a promise.
  public static let refreshInterval: TimeInterval = 1800
  /// Retry back-off after a protected-data failure, from how long ago the app last published.
  ///
  /// Budget reasoning: WidgetKit grants a limited number of timeline reloads per day, and
  /// spends them whether or not the widget is visible. A phone locked overnight fails every read,
  /// so a fixed short retry would burn hundreds of reloads (about 240 at 2 minutes) and leave the
  /// widget throttled at the moment it is unlocked. The extension cannot count its own failures
  /// (it may not write while locked), but the file's modification time is readable while locked and
  /// grows with the time since the app was last open, so the age is the back-off clock:
  /// 2 minutes for the first 10 minutes, then 5 minutes up to 30 minutes, 15 minutes up to 2
  /// hours, then the regular 30 minute cadence. An 8 hour night costs about 27 reloads. The
  /// real recovery path is the app: it reloads timelines on `protectedDataDidBecomeAvailable`
  /// and `didBecomeActive`, which are not budget-limited. This retry only covers "unlocked,
  /// app not opened". A successful read produces a normal timeline, which resets the ladder
  /// because the next failure measures its age from the new publish.
  public static func protectedRetryInterval(lastPublished: Date?, at now: Date) -> TimeInterval {
    guard let lastPublished else { return 300 }
    let age = max(0, now.timeIntervalSince(lastPublished))
    switch age {
    case ..<600: return 120
    case ..<1800: return 300
    case ..<7200: return 900
    default: return refreshInterval
    }
  }

  public let entries: [Entry]
  public let reloadAt: Date

  public static func make(from result: SnapshotReadResult, at now: Date) -> Self {
    switch result {
    case .snapshot(let value):
      var entries = [Entry(date: now, snapshot: value, awaitingUnlock: false)]
      for boundary in value.visibilityBoundaries(after: now) {
        entries.append(
          Entry(date: boundary, snapshot: value.visible(at: boundary), awaitingUnlock: false))
      }
      return Self(
        entries: entries,
        reloadAt: max(now.addingTimeInterval(refreshInterval), value.expiresAt))
    case .protectedDataUnavailable(let lastPublished):
      return Self(
        entries: [Entry(date: now, snapshot: .unavailable(at: now), awaitingUnlock: true)],
        reloadAt: now.addingTimeInterval(
          protectedRetryInterval(lastPublished: lastPublished, at: now)))
    case .unavailable:
      return Self(
        entries: [Entry(date: now, snapshot: .unavailable(at: now), awaitingUnlock: false)],
        reloadAt: now.addingTimeInterval(refreshInterval))
    }
  }
}
