import FORMACore
import Foundation

/// What "Bring your phone training" has to say about this iPhone's guest data.
struct PhoneTrainingSummary: Equatable, Sendable {
  var routines: Int
  var workouts: Int
  var workoutInProgress: Bool
}

enum PhoneTrainingOffer: Equatable, Sendable {
  /// Nothing on this iPhone worth bringing (an untouched starter workspace).
  case none
  case available(PhoneTrainingSummary)
  /// This phone's training was already brought into the signed-in account.
  case importedHere
  /// It was brought into another account, so it is not offered again.
  case importedElsewhere
  /// An interrupted import can be reviewed and retried only by its member.
  case reservedHere(PhoneTrainingSummary)
  case reservedElsewhere
  /// An unreadable ownership record must never look like unclaimed training.
  case unavailable(String)
}

/// Remembers which member brought this phone's guest training into an account,
/// as the website remembers it in `forma-v1-migrated`. A file in the app's data
/// directory, not UserDefaults (see ios/docs/privacy-inventory.md). It holds
/// only the opaque member reference and a date.
enum PhoneTrainingLedger {
  struct Record: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case reserved, imported }
    var member: String
    var importedAt: Date
    var status: Status

    init(member: String, importedAt: Date = .now, status: Status = .imported) {
      self.member = member
      // ISO8601's existing on-disk representation has whole-second precision.
      self.importedAt = Date(timeIntervalSince1970: floor(importedAt.timeIntervalSince1970))
      self.status = status
    }

    private enum CodingKeys: String, CodingKey { case member, importedAt, status }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      member = try values.decode(String.self, forKey: .member)
      importedAt = try values.decode(Date.self, forKey: .importedAt)
      // Existing successful imports predate reservation state.
      status = try values.decodeIfPresent(Status.self, forKey: .status) ?? .imported
    }
  }

  enum Failure: LocalizedError {
    case anotherMember, alreadyImported, changedReservation, invalidRecord

    var errorDescription: String? {
      switch self {
      case .anotherMember:
        "This iPhone’s training is reserved for another account and cannot be imported here."
      case .alreadyImported:
        "This iPhone’s training was already brought into this account."
      case .changedReservation:
        "The phone training ownership record changed. Review the import again."
      case .invalidRecord:
        "The phone training ownership record could not be verified. No new import can start."
      }
    }
  }

  static func url(in directory: URL) -> URL {
    directory.appendingPathComponent("phone-training-import.json")
  }

  @MainActor static func read(in directory: URL) throws -> Record? {
    let data: Data
    do {
      data = try Data(contentsOf: url(in: directory))
    } catch let error as NSError
      where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError
    {
      return nil
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let record = try decoder.decode(Record.self, from: data)
    guard !record.member.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw Failure.invalidRecord
    }
    return record
  }

  /// Persist ownership before any account replacement or upload. Reservations
  /// intentionally survive every failure: two files and a remote service cannot
  /// share a transaction, so an uncertain outcome must not release another
  /// member's claim. Only the same member may review and retry it.
  @MainActor static func reserve(member: String, in directory: URL) throws -> Record {
    guard !member.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw Failure.invalidRecord
    }
    if let existing = try read(in: directory) {
      guard existing.member == member else { throw Failure.anotherMember }
      guard existing.status == .reserved else { throw Failure.alreadyImported }
      // A previous atomic write may have succeeded before its flush failed.
      // A retry must establish persistence again before touching the account.
      try write(existing, in: directory)
      return existing
    }
    let reservation = Record(member: member, status: .reserved)
    try write(reservation, in: directory)
    return reservation
  }

  @MainActor static func complete(_ reservation: Record, in directory: URL) throws {
    guard try read(in: directory) == reservation, reservation.status == .reserved else {
      throw Failure.changedReservation
    }
    var imported = reservation
    imported.status = .imported
    try write(imported, in: directory)
  }

  @MainActor private static func write(_ record: Record, in directory: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let destination = url(in: directory)
    try encoder.encode(record).write(to: destination, options: [.atomic, .completeFileProtection])
    // Complete the local file flush before allowing the account mutation.
    let file = try FileHandle(forWritingTo: destination)
    do {
      try file.synchronize()
    } catch {
      // Preserve the primary flush failure; no import is allowed to follow it.
      do {
        try file.close()
      } catch {
        // The flush failure is reported below.
      }
      throw error
    }
    try file.close()
  }

  /// Is this guest workspace anything more than the untouched starter one?
  static func hasTraining(_ guest: Workspace) -> Bool {
    guest.revision > 0 || !guest.history.isEmpty || guest.active != nil
  }
}
