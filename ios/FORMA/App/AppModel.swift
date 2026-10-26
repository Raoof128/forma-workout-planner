import FORMACore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
  var workspace: Workspace? {
    didSet {
      // Active-set, rest and profile commits retain the same history value.
      // Avoid reparsing every saved date on those frequent updates.
      if oldValue?.history != workspace?.history { rebuildHistory() }
    }
  }
  var catalog: [Exercise] = [] {
    didSet {
      exercisesByID = Dictionary(
        catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
  }
  private var exercisesByID: [String: Exercise] = [:]
  private var pendingMutations = 0
  var busy: Bool { pendingMutations > 0 }
  var errorMessage: String?
  var loadFailure: String?
  var workoutPresented = false
  var receipt: WorkoutSession?
  var hapticsEnabled = true { didSet { savePreferences() } }
  var motion: MotionPreference = .system { didSet { savePreferences() } }
  var appearance: AppearancePreference = .system { didSet { savePreferences() } }
  private var store: WorkspaceStore?
  private var loading = false
  private var preferencesURL: URL?
  private var loadingPreferences = false
  private let mutationGate = SerializedMutationGate()
  let watch = WatchWorkoutCoordinator()
  /// The routine waiting on the Apple Watch start sheet.
  var pendingStart: Routine?
  private var presentWorkoutAfterSheet = false

  init() {
    watch.onWatchStarted = { [weak self] routineID in
      guard let self, let routine = self.workspace?.routines.first(where: { $0.id == routineID })
      else { return }
      Task { await self.start(routine) }
    }
  }

  var selectableExercises: [Exercise] { catalog.filter(\.selectable) }
  var routines: [Routine] { workspace?.routines.filter { $0.archivedAt == nil } ?? [] }
  private(set) var history: [WorkoutSession] = []
  static var now: Double { Date.now.timeIntervalSince1970 * 1_000 }

  func exercise(_ id: String) -> Exercise? { exercisesByID[id] }

  private func rebuildHistory() {
    history = (workspace?.history ?? []).map { (session: $0, date: TrainingDate.date($0)) }
      .sorted { $0.date > $1.date }.map(\.session)
  }

  func resource<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
      throw AppFailure(
        "A bundled training resource is missing. Rebuild the app resources; your saved data has not been replaced."
      )
    }
    return try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  func load() async {
    guard !loading, workspace == nil else { return }
    loading = true
    defer { loading = false }
    loadFailure = nil
    do {
      let loadedCatalog: [Exercise] = try resource("catalog", as: [Exercise].self)
      let seed: Workspace = try resource("seed-workspace", as: Workspace.self)
      let directory = try dataDirectory()
      preferencesURL = directory.appendingPathComponent("presentation.json")
      loadPreferences()
      let repository = try WorkspaceStore(
        url: directory.appendingPathComponent("workspace.sqlite"), catalog: loadedCatalog)
      let saved = try await repository.load(seed: seed)
      try protectFiles(in: directory)
      catalog = loadedCatalog
      store = repository
      workspace = saved
    } catch {
      loadFailure =
        "FORMA couldn't open the local training store. No existing data has been replaced. \(error.localizedDescription)"
    }
  }

  private func dataDirectory() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var directory = support.appendingPathComponent("FORMA", isDirectory: true)
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
        directory = support.appendingPathComponent("FORMA-UITests", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("--reset-workspace"),
          FileManager.default.fileExists(atPath: directory.path)
        {
          try FileManager.default.removeItem(at: directory)
        }
      }
    #endif
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    return directory
  }

  private func protectFiles(in directory: URL) throws {
    for file in try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    {
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path)
    }
  }

  @discardableResult
  func commit(
    forActiveSession expectedSessionID: String? = nil, _ change: (inout Workspace) throws -> Void
  ) async -> Bool {
    pendingMutations += 1
    await mutationGate.acquire()
    defer {
      mutationGate.release()
      pendingMutations -= 1
    }
    guard var candidate = workspace, let store else { return false }
    do {
      if let expectedSessionID, candidate.active?.id != expectedSessionID {
        throw AppFailure("This workout has changed. Reopen your active session before editing it.")
      }
      let revision = candidate.revision
      try change(&candidate)
      let committed = try await store.save(candidate, expectedRevision: revision)
      workspace = committed
      errorMessage = nil
      return true
    } catch {
      errorMessage =
        "This change was not saved. Your last saved workout is intact. \(error.localizedDescription)"
      return false
    }
  }

  /// Start buttons come here. With a paired Apple Watch the start sheet waits
  /// for its Start button; without one, the workout starts on this iPhone.
  func requestStart(_ routine: Routine) async {
    if workspace?.active != nil {
      receipt = nil
      workoutPresented = true
      return
    }
    watch.reset()
    await watch.refresh()
    if watch.availability.hasPairedWatch {
      pendingStart = routine
    } else {
      await start(routine)
    }
  }

  func start(_ routine: Routine) async {
    if workspace?.active != nil {
      receipt = nil
      presentWorkout()
      return
    }
    if await commit({ value in
      if value.active == nil {
        value.active = try WorkoutEngine.start(
          routine: routine, now: Self.now, restSeconds: value.profile.restSeconds, catalog: catalog)
      }
    }) {
      receipt = nil
      presentWorkout()
    }
  }

  /// A full-screen cover can't present while the start sheet is still
  /// dismissing, so it opens once the sheet has gone.
  private func presentWorkout() {
    if pendingStart != nil {
      presentWorkoutAfterSheet = true
      pendingStart = nil
    } else {
      workoutPresented = true
    }
  }

  func startSheetDismissed() {
    watch.cancelWaiting()
    if presentWorkoutAfterSheet {
      presentWorkoutAfterSheet = false
      workoutPresented = true
    }
  }

  /// Discarding the FORMA workout discards the Watch recording too.
  func discardActive() async -> Bool {
    guard let id = workspace?.active?.id else { return false }
    guard await commit(forActiveSession: id, { $0.active = nil }) else { return false }
    await watch.end(save: false)
    return true
  }

  @discardableResult
  func toggleSet(entry: Int, set: Int) async -> Bool {
    guard let id = workspace?.active?.id else { return false }
    return await commit(forActiveSession: id) { value in
      value = try WorkoutEngine.toggleSet(
        in: value, entryIndex: entry, setIndex: set, now: Self.now, catalog: catalog)
    }
  }

  func finish() async {
    guard let id = workspace?.active?.id else { return }
    if await commit(
      forActiveSession: id,
      { value in
        value = try WorkoutEngine.finish(value, now: Self.now, catalog: catalog)
      })
    {
      receipt = workspace?.history.first { $0.id == id }
      // The Watch ends its recording and saves it to Apple Health.
      await watch.end(save: true)
    }
  }

  func exportData() throws -> Data {
    guard let workspace else { throw AppFailure("Your workspace is still opening.") }
    return try WorkspaceExport.encode(workspace)
  }

  func deleteLocalData() async {
    pendingMutations += 1
    await mutationGate.acquire()
    defer {
      mutationGate.release()
      pendingMutations -= 1
    }
    guard let workspace, let store else { return }
    do {
      self.workspace = try await store.reset(expectedRevision: workspace.revision)
      receipt = nil
      workoutPresented = false
      errorMessage = nil
      await watch.end(save: false)
    } catch {
      errorMessage = "Your local training could not be deleted. \(error.localizedDescription)"
    }
  }

  private func loadPreferences() {
    guard let preferencesURL, let data = try? Data(contentsOf: preferencesURL),
      let preferences = try? JSONDecoder().decode(PresentationPreferences.self, from: data)
    else { return }
    loadingPreferences = true
    defer { loadingPreferences = false }
    hapticsEnabled = preferences.hapticsEnabled
    motion = preferences.motion
    appearance = preferences.appearance
  }

  private func savePreferences() {
    guard !loadingPreferences, let preferencesURL else { return }
    do {
      let preferences = PresentationPreferences(
        hapticsEnabled: hapticsEnabled, motion: motion, appearance: appearance)
      try JSONEncoder().encode(preferences).write(
        to: preferencesURL, options: [.atomic, .completeFileProtection])
    } catch {
      errorMessage = "Your appearance preference could not be saved. \(error.localizedDescription)"
    }
  }
}

struct AppFailure: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

enum MotionPreference: String, CaseIterable, Codable {
  case system = "System"
  case minimal = "Minimal"
  case off = "Off"
}
enum AppearancePreference: String, CaseIterable, Codable {
  case system = "System"
  case light = "Light"
  case dark = "Dark"
}
private struct PresentationPreferences: Codable {
  var hapticsEnabled: Bool
  var motion: MotionPreference
  var appearance: AppearancePreference
}

/// Formatters are expensive to create, and history rebuilds and journal rows
/// call these once per session, so they are created once on the main actor.
@MainActor
enum TrainingDate {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
    return calendar
  }()
  static func date(_ session: WorkoutSession) -> Date {
    // Native finishes always write fractional seconds; try that form first.
    guard let text = session.date,
      let date = fractional.date(from: text) ?? whole.date(from: text)
    else {
      return Date(timeIntervalSince1970: session.startedAt / 1_000)
    }
    return date
  }
  private static let whole = ISO8601DateFormatter()
  private static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private static var labelFormatters: [String: DateFormatter] = [:]
  static func label(_ date: Date, template: String = "d MMM") -> String {
    if let formatter = labelFormatters[template] { return formatter.string(from: date) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_AU")
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate(template)
    labelFormatters[template] = formatter
    return formatter.string(from: date)
  }
  static func completedThisWeek(_ history: [WorkoutSession]) -> [WorkoutSession] {
    guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
    return history.filter { interval.contains(date($0)) }
  }
}
