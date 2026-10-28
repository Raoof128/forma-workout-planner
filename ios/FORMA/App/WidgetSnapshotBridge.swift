import FORMACore
import FORMASurfaces
import Foundation
import Observation
import WidgetKit

/// Private preferences never enter the group container. Consent is scoped to the current owner.
@MainActor @Observable
final class WidgetSnapshotBridge {
  private struct Consent: Codable {
    var owner: String
    var epoch: String
    var sharing: Bool
  }
  private(set) var sharing = false
  private(set) var epoch = UUID().uuidString
  private var consentError: String?
  private var publicationError: String?
  var status: String? { consentError ?? publicationError }
  @ObservationIgnored private let writeConsent: (Data, URL) throws -> Void
  @ObservationIgnored private let removeConsent: (URL) throws -> Void

  init(
    writeConsent: @escaping (Data, URL) throws -> Void = {
      try $0.write(to: $1, options: [.atomic, .completeFileProtection])
    },
    removeConsent: @escaping (URL) throws -> Void = {
      let values = try $0.resourceValues(forKeys: [.isRegularFileKey])
      guard values.isRegularFile == true else { throw CocoaError(.fileWriteNoPermission) }
      try FileManager.default.removeItem(at: $0)
    }
  ) {
    self.writeConsent = writeConsent
    self.removeConsent = removeConsent
  }
  @ObservationIgnored private var consent: Consent?
  @ObservationIgnored private var preferencesURL: URL?
  @ObservationIgnored private var writer: SnapshotFileWriter?
  @ObservationIgnored private var sequence: UInt64 = 0
  @ObservationIgnored private var publicationTask: Task<Void, Never>?

  func configure(directory: URL, owner: String) {
    preferencesURL = directory.appendingPathComponent("widget-consent.json")
    if let preferencesURL {
      do {
        consent = try JSONDecoder().decode(Consent.self, from: Data(contentsOf: preferencesURL))
      } catch { consent = nil }
    }
    prepareWriter()
    selectOwner(owner)
  }

  private func prepareWriter() {
    guard writer == nil else { return }
    if let group = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: TrainingSnapshot.group)
    {
      writer = SnapshotFileWriter(url: group.appendingPathComponent(TrainingSnapshot.filename))
    } else {
      publicationError = "Widgets are unavailable in this build. Your training is saved in the app."
    }
  }

  /// A failed database launch must not advertise an old projection as current training.
  func requestReload() {
    WidgetCenter.shared.reloadTimelines(ofKind: TrainingSnapshot.kind)
  }

  func publishUnavailable() {
    prepareWriter()
    publish(nil, unavailable: true)
  }

  func selectOwner(_ owner: String) {
    if consent?.owner != owner {
      consent = Consent(owner: owner, epoch: UUID().uuidString, sharing: false)
    }
    sharing = consent?.sharing ?? false
    epoch = consent?.epoch ?? UUID().uuidString
    if !persistConsent() { sharing = false }
  }

  func setSharing(_ value: Bool, workspace: Workspace?) {
    guard let previous = consent else { return }
    consent?.sharing = value
    if !value { consent?.epoch = UUID().uuidString }
    if persistConsent() {
      sharing = value
    } else if !value, let preferencesURL {
      do {
        // Deletion is a durable fail-closed fallback if replacing the preference fails.
        try removeConsent(preferencesURL)
        sharing = false
        consentError = nil
      } catch {
        consent = previous
        sharing = previous.sharing
        consentError =
          "Sharing couldn’t be turned off on disk. Unlock your iPhone and try again. Remove the widget if you need to hide it now."
      }
    } else {
      consent = previous
      sharing = previous.sharing
    }
    epoch = consent?.epoch ?? UUID().uuidString
    publish(workspace)
  }

  @discardableResult
  private func persistConsent() -> Bool {
    guard let preferencesURL, let consent else { return false }
    do {
      try writeConsent(JSONEncoder().encode(consent), preferencesURL)
      consentError = nil
      return true
    } catch {
      consentError = "The widget privacy preference couldn’t be saved. Try again after unlocking."
      return false
    }
  }

  func publish(_ workspace: Workspace?, at now: Date = .now, unavailable: Bool = false) {
    guard let writer else { return }
    sequence += 1
    let publication = sequence
    let enabled = sharing
    let ownerEpoch = epoch
    publicationTask?.cancel()
    publicationTask = Task {
      // Up to10,000 saved dates must not be parsed on the input/UI actor.
      let snapshot =
        unavailable
        ? TrainingSnapshot.unavailable(at: now)
        : await Self.prepare(workspace, sharing: enabled, epoch: ownerEpoch, at: now)
      guard !Task.isCancelled, publication == sequence else { return }
      do {
        if try await writer.publish(snapshot, sequence: publication) {
          WidgetCenter.shared.reloadTimelines(ofKind: TrainingSnapshot.kind)
        }
        if publication == sequence { publicationError = nil }
      } catch {
        if publication == sequence {
          publicationError =
            "Widgets couldn’t update. Your saved training is intact. Open FORMA after unlocking to retry."
        }
      }
    }
  }

  /// Only committed in-memory workspaces enter here. No drafts, Health data or sync credentials.
  @concurrent
  nonisolated private static func prepare(
    _ workspace: Workspace?, sharing: Bool, epoch: String,
    at now: Date
  ) async -> TrainingSnapshot {
    project(workspace, sharing: sharing, epoch: epoch, at: now)
  }

  nonisolated static func project(
    _ workspace: Workspace?, sharing: Bool, epoch: String, at now: Date
  )
    -> TrainingSnapshot
  {
    let midnight =
      TrainingCalendar.calendar.date(
        byAdding: .day, value: 1,
        to: TrainingCalendar.calendar.startOfDay(for: now)) ?? now.addingTimeInterval(3600)
    guard sharing else {
      return TrainingSnapshot(epoch: epoch, generatedAt: now, expiresAt: midnight, state: .hidden)
    }
    guard let workspace else {
      return TrainingSnapshot(
        epoch: epoch, generatedAt: now, expiresAt: midnight, state: .unavailable)
    }
    let routine = workspace.routines.first { $0.archivedAt == nil }
    let interval = TrainingCalendar.calendar.dateInterval(of: .weekOfYear, for: now)
    let completed = workspace.history.filter {
      let date = TrainingCalendar.completionDate($0.date, startedAt: $0.startedAt)
      guard let interval else { return false }
      return date >= interval.start && date < interval.end && date <= now
    }
    let weekdays = Set(
      completed.map {
        (TrainingCalendar.calendar.component(
          .weekday, from: TrainingCalendar.completionDate($0.date, startedAt: $0.startedAt)) + 5)
          % 7
      })
    let active = workspace.active.map { session in
      TrainingSnapshot.ActiveSummary(
        id: session.id, name: session.name,
        completedSets: session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count },
        totalSets: session.exercises.reduce(0) { $0 + $1.sets.count })
    }
    let empty = routine == nil && active == nil && workspace.history.isEmpty
    return TrainingSnapshot(
      epoch: epoch, revision: workspace.revision, generatedAt: now,
      expiresAt: active == nil ? midnight : min(midnight, now.addingTimeInterval(1800)),
      state: empty ? .empty : .ready,
      routine: routine.map {
        .init(
          id: $0.id, name: $0.name,
          exercises: $0.exercises.count, minutes: $0.minutes)
      }, active: active,
      week: empty
        ? nil
        : .init(
          sessions: completed.count, goal: workspace.profile.goal,
          days: (0..<7).map { weekdays.contains($0) }))
  }
}
