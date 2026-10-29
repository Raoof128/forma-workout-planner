import FORMACore
import FORMASurfaces
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
      widgets.publish(workspace)
      // The one place the Lock Screen activity follows the workout: every start, set, rest
      // change, finish, discard, reset and sign-out passes through this observer.
      syncLiveActivity()
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
  var pendingMutations = 0
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
  /// The store the screens are editing: the guest store, or a signed-in
  /// member's own saved copy (see AppModel+Account.swift).
  var store: WorkspaceStore?
  private(set) var loading = false
  private var preferencesURL: URL?
  private var loadingPreferences = false
  let mutationGate = SerializedMutationGate()
  let watch = WatchWorkoutCoordinator()
  let widgets = WidgetSnapshotBridge()
  let liveActivity: WorkoutLiveActivityController
  var widgetRoute: WidgetRoute?
  var widgetNotice: String?
  var widgetEditingCount = 0
  /// A foreground/day tick; avoids stale guest weeks without observing all workout commits.
  var trainingNow = Date.now
  private(set) var checkingWatchForStart = false

  // MARK: Accounts (see AppModel+Account.swift)
  let account = AccountModel()
  /// The member whose saved copy is the open store, or nil while it is the guest store.
  var activeMember: String?
  var isSignedIn: Bool { activeMember != nil }
  /// What the sync engine last reported for the open member store.
  var syncStatus: SyncStatus = .idle
  /// Set while a signed-in member's copy has not been downloaded yet.
  var accountGate: AccountGate?
  @ObservationIgnored var guestStore: WorkspaceStore?
  @ObservationIgnored var sync: AccountSync?
  @ObservationIgnored var syncGeneration = 0
  @ObservationIgnored var syncObserver: Task<Void, Never>?
  @ObservationIgnored var retryTask: Task<Void, Never>?
  @ObservationIgnored var retryAttempt = 0
  @ObservationIgnored var lastForegroundSync = Date.distantPast
  @ObservationIgnored var connectivity: ConnectivityMonitor?
  @ObservationIgnored var accountEnvironment: AccountEnvironment?
  @ObservationIgnored var dataDirectory: URL?
  @ObservationIgnored var seedWorkspace: Workspace?
  /// Nothing may be edited, signed in or signed out while this is held.
  var canSwitchAccount: Bool {
    workspace?.active == nil && pendingStart == nil && !checkingWatchForStart
  }
  /// The routine waiting on the Apple Watch start sheet.
  var pendingStart: Routine?
  private var presentWorkoutAfterSheet = false

  init(liveActivity: WorkoutLiveActivityController = .makeDefault()) {
    self.liveActivity = liveActivity
    account.app = self
    watch.onWatchStarted = { [weak self] routineID in
      guard let self, self.pendingStart?.id == routineID,
        let routine = self.workspace?.routines.first(where: { $0.id == routineID })
      else { return }
      let owner = self.storeIdentity
      Task {
        guard owner == self.storeIdentity else { return }
        await self.start(routine)
      }
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
    let guestStore: WorkspaceStore
    /// The store the first screen edits: the guest store, or the member's.
    let store: WorkspaceStore
    /// Nil only for a signed-in member whose copy has not been downloaded yet.
    let workspace: Workspace?
    let seed: Workspace
    let account: AccountEnvironment?
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
      guestStore = payload.guestStore
      store = payload.store
      seedWorkspace = payload.seed
      dataDirectory = payload.directory
      accountEnvironment = payload.account
      account.attach(payload.account)
      if let restored = payload.account?.restored {
        activeMember = restored.id
        accountGate = payload.workspace == nil ? .loading : nil
        startSync(profile: restored, store: payload.store, initial: false)
      }
      widgets.configure(directory: payload.directory, owner: widgetOwnerIdentity)
      workspace = payload.workspace
      // WatchConnectivity activation isn't needed for the first frame.
    } catch {
      widgets.publishUnavailable()
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
    let guestStore = try WorkspaceStore(
      url: directory.appendingPathComponent("workspace.sqlite"), catalog: catalog)
    #if DEBUG
      let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    #else
      let testing = false
    #endif
    let account = await AccountEnvironment.make(directory: directory, testing: testing)
    var store = guestStore
    var workspace: Workspace?
    if let account, let restored = account.restored {
      // Signed in at the last launch: open the member's own saved copy, offline.
      let opened = try await openMemberStore(
        directory: account.storage.directory, member: restored.id, catalog: catalog)
      store = opened.store
      workspace = opened.downloaded ? opened.workspace : nil
    } else {
      workspace = try await guestStore.load(seed: seed)
    }
    try protectFiles(in: directory)
    return LaunchPayload(
      catalog: catalog,
      selectable: catalog.filter(\.selectable),
      exercisesByID: Dictionary(
        catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
      guestStore: guestStore, store: store, workspace: workspace, seed: seed, account: account,
      directory: directory)
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

  nonisolated static func protectFiles(in directory: URL) throws {
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
    let owner = storeIdentity
    pendingMutations += 1
    await mutationGate.acquire()
    defer {
      mutationGate.release()
      pendingMutations -= 1
    }
    // A task created by a dismissed guest/member screen can be queued behind
    // a store switch. It must never apply its edit to the next owner's data.
    guard owner == storeIdentity, var candidate = workspace, let store else { return false }
    do {
      if let expectedSessionID, candidate.active?.id != expectedSessionID {
        throw AppFailure("This workout has changed. Reopen your active session before editing it.")
      }
      let revision = candidate.revision
      try change(&candidate)
      // A signed-in store records "not yet sent" in the same transaction.
      let committed = try await store.save(
        candidate, expectedRevision: revision, markingDirty: activeMember != nil)
      workspace = committed
      // Skip the write when already nil: it would invalidate every view that
      // reads the message (the root alert) on each logged set.
      if errorMessage != nil { errorMessage = nil }
      // Saved on the phone first; sending to the account never delays this.
      sendAfterCommit()
      return true
    } catch {
      if case FormaError.conflictingRevision = error {
        // The account's newer copy replaced this store while the screen held an
        // older revision: show the current copy before anything else is saved.
        Task { await reloadWorkspaceFromStore() }
      }
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
    guard !checkingWatchForStart else { return }
    let owner = storeIdentity
    if workspace?.active != nil {
      receipt = nil
      workoutPresented = true
      return
    }
    watch.reset()
    checkingWatchForStart = true
    defer { checkingWatchForStart = false }
    await watch.refresh()
    guard owner == storeIdentity,
      let current = workspace?.routines.first(where: { $0.id == routine.id && $0.archivedAt == nil }
      )
    else { return }
    if watch.availability.hasPairedWatch {
      pendingStart = current
    } else {
      await start(current)
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
    // Signed in, the open store is the member's synced copy: resetting it would
    // empty the account. Deleting an account's data goes through account deletion.
    guard activeMember == nil, let workspace, let store else { return }
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
  static let calendar = TrainingCalendar.calendar
  static func date(_ session: WorkoutSession) -> Date {
    TrainingCalendar.completionDate(session.date, startedAt: session.startedAt)
  }
  nonisolated static func parseUTC(_ text: String) -> Date? {
    TrainingCalendar.parseUTC(text)
  }
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
  static func completedThisWeek(_ history: [WorkoutSession], at now: Date = .now)
    -> [WorkoutSession]
  {
    guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
    return history.filter {
      let date = date($0)
      return date >= interval.start && date < interval.end && date <= now
    }
  }
}
