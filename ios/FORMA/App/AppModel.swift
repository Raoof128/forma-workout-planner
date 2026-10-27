import FORMACore
import Foundation
import Observation
import os

@MainActor @Observable
final class AppModel {
  var workspace: Workspace? {
    didSet {
      // Active-set, rest and profile commits retain the same history and
      // routines buffers, so these comparisons hit Array's identity fast path
      // (O(1)). Avoid reparsing every saved date on those frequent updates.
      if oldValue?.history != workspace?.history { rebuildHistory() }
      if oldValue?.routines != workspace?.routines {
        routines = workspace?.routines.filter { $0.archivedAt == nil } ?? []
      }
      // Narrow facts for the root views. Each is written only when it changes,
      // so logging a set doesn't invalidate views that only need these.
      let ready = workspace != nil
      if ready != hasWorkspace { hasWorkspace = ready }
      let activeName = workspace?.active?.name
      if activeName != activeWorkoutName { activeWorkoutName = activeName }
    }
  }
  /// True once a workspace has loaded. Read by the root view instead of
  /// `workspace`, which changes on every logged set.
  private(set) var hasWorkspace = false
  /// The active workout's name, or nil. The tab accessory only needs this.
  private(set) var activeWorkoutName: String?
  private(set) var catalog: [Exercise] = []
  /// Cached with the catalogue: filtering 1,700 rows on each access was
  /// repeated by every Plan render and filter keystroke.
  private(set) var selectableExercises: [Exercise] = []
  private var exercisesByID: [String: Exercise] = [:]
  private var pendingMutations = 0
  var busy: Bool { pendingMutations > 0 }
  var errorMessage: String?
  var loadFailure: String?
  var workoutPresented = false
  var receipt: WorkoutSession?
  /// The latest haptic-worthy event; `FormaHapticRelay` plays it.
  private(set) var hapticEvent: FormaHapticEvent?
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

  /// Cached when the routines change; views read it several times per render.
  private(set) var routines: [Routine] = []
  private(set) var history: [WorkoutSession] = []
  static var now: Double { Date.now.timeIntervalSince1970 * 1_000 }

  func exercise(_ id: String) -> Exercise? { exercisesByID[id] }

  private func rebuildHistory() {
    history = (workspace?.history ?? []).map { (session: $0, date: TrainingDate.date($0)) }
      .sorted { $0.date > $1.date }.map(\.session)
  }

  nonisolated static func resource<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
      throw AppFailure(
        "A bundled training resource is missing. Rebuild the app resources; your saved data has not been replaced."
      )
    }
    return try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  /// Everything the first screen needs, prepared away from the main thread.
  private struct LaunchPayload: Sendable {
    let catalog: [Exercise]
    let selectable: [Exercise]
    let exercisesByID: [String: Exercise]
    let store: WorkspaceStore
    let workspace: Workspace
    let directory: URL
  }

  /// Startup work shows in Instruments under Points of Interest.
  nonisolated private static let signposter = OSSignposter(
    subsystem: "dev.raoufabedini.forma", category: .pointsOfInterest)

  func load() async {
    guard !loading, workspace == nil else { return }
    loading = true
    defer { loading = false }
    loadFailure = nil
    do {
      // Decoding the catalogue and opening SQLite took about half a second on
      // the main thread, blocking the first frame. Apple's launch guidance:
      // keep the main thread free to draw, and prepare data elsewhere.
      let payload = try await Self.prepareLaunch()
      preferencesURL = payload.directory.appendingPathComponent("presentation.json")
      loadPreferences()
      exercisesByID = payload.exercisesByID
      catalog = payload.catalog
      selectableExercises = payload.selectable
      store = payload.store
      workspace = payload.workspace
      // WatchConnectivity activation isn't needed for the first frame.
    } catch {
      loadFailure =
        "FORMA couldn't open the local training store. No existing data has been replaced. \(error.localizedDescription)"
    }
  }

  @concurrent
  nonisolated private static func prepareLaunch() async throws -> LaunchPayload {
    let state = signposter.beginInterval("Prepare training space")
    defer { signposter.endInterval("Prepare training space", state) }
    let catalog: [Exercise] = try resource("catalog", as: [Exercise].self)
    let seed: Workspace = try resource("seed-workspace", as: Workspace.self)
    let directory = try dataDirectory()
    let store = try WorkspaceStore(
      url: directory.appendingPathComponent("workspace.sqlite"), catalog: catalog)
    let workspace = try await store.load(seed: seed)
    try protectFiles(in: directory)
    return LaunchPayload(
      catalog: catalog,
      selectable: catalog.filter(\.selectable),
      exercisesByID: Dictionary(
        catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
      store: store, workspace: workspace, directory: directory)
  }

  nonisolated private static func dataDirectory() throws -> URL {
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

  nonisolated private static func protectFiles(in directory: URL) throws {
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
      // Skip the write when already nil: it would invalidate every view that
      // reads the message (the root alert) on each logged set.
      if errorMessage != nil { errorMessage = nil }
      return true
    } catch {
      errorMessage =
        "This change was not saved. Your last saved workout is intact. \(error.localizedDescription)"
      haptic(.failed)
      return false
    }
  }

  /// Plays `kind` once, if haptics are on. Call it after the change it
  /// confirms has happened, never before.
  func haptic(_ kind: FormaHaptic) {
    hapticEvent = FormaHapticEvent(kind: kind)
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
      haptic(.started)
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
      let date = parseUTC(text) ?? fractional.date(from: text) ?? whole.date(from: text)
    else {
      return Date(timeIntervalSince1970: session.startedAt / 1_000)
    }
    return date
  }
  /// Reads the exact shapes FORMA writes, `YYYY-MM-DDTHH:MM:SS.mmmZ` (native)
  /// and `YYYY-MM-DDTHH:MM:SSZ`, with integer arithmetic. `ISO8601DateFormatter`
  /// costs tens of microseconds per call, which adds up across a 10,000-session
  /// rebuild. Anything else, or any out-of-range field, returns nil so the
  /// formatter decides, exactly as before.
  nonisolated static func parseUTC(_ text: String) -> Date? {
    var text = text
    return text.withUTF8 { bytes -> Date? in
      let count = bytes.count
      guard count == 20 || count == 24, bytes[count - 1] == 0x5A,
        bytes[4] == 0x2D, bytes[7] == 0x2D, bytes[10] == 0x54, bytes[13] == 0x3A,
        bytes[16] == 0x3A, count == 20 || bytes[19] == 0x2E
      else { return nil }
      func digits(_ start: Int, _ length: Int) -> Int? {
        var value = 0
        for index in start..<start + length {
          let byte = bytes[index]
          guard byte >= 0x30, byte <= 0x39 else { return nil }
          value = value * 10 + Int(byte - 0x30)
        }
        return value
      }
      guard let year = digits(0, 4), let month = digits(5, 2), let day = digits(8, 2),
        let hour = digits(11, 2), let minute = digits(14, 2), let second = digits(17, 2),
        let millis = count == 24 ? digits(20, 3) : 0,
        (1900...2999).contains(year), (1...12).contains(month), hour < 24, minute < 60,
        second < 60
      else { return nil }
      let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
      let monthLength =
        month == 2 ? (leap ? 29 : 28) : (month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31
      guard day >= 1, day <= monthLength else { return nil }
      // Days since 1970-01-01 (proleptic Gregorian, Hinnant's civil algorithm).
      let shiftedYear = month <= 2 ? year - 1 : year
      let era = shiftedYear / 400
      let yearOfEra = shiftedYear - era * 400
      let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
      let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
      let days = era * 146_097 + dayOfEra - 719_468
      let seconds = days * 86_400 + hour * 3_600 + minute * 60 + second
      return Date(timeIntervalSince1970: Double(seconds) + Double(millis) / 1_000)
    }
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
