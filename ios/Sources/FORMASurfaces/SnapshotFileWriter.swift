import Foundation

/// Only the containing app constructs this writer. The extension has no mutation intent.
public actor SnapshotFileWriter {
  private var latest: UInt64 = 0
  private let url: URL
  public init(url: URL) { self.url = url }

  @discardableResult
  public func publish(_ snapshot: TrainingSnapshot, sequence: UInt64) throws -> Bool {
    // Tasks can arrive out of order after an account switch. Older work cannot republish its owner.
    guard sequence > latest else { return false }
    latest = sequence
    let manager = FileManager.default
    let directory = url.deletingLastPathComponent()
    #if os(iOS)
      let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.complete]
    #else
      let attributes: [FileAttributeKey: Any] = [:]
    #endif
    try manager.createDirectory(
      at: directory, withIntermediateDirectories: true, attributes: attributes)
    var directoryURL = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directoryURL.setResourceValues(values)
    let data = try JSONEncoder().encode(snapshot)
    #if os(iOS)
      try data.write(to: url, options: [.atomic, .completeFileProtection])
    #else
      try data.write(to: url, options: [.atomic])
    #endif
    return true
  }
}
