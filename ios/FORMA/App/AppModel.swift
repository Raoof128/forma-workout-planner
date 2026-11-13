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
      syncLiveActivity(workspaceClosed: oldValue != nil && workspace == nil)
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
  /// The title the root alert gives `errorMessage`, kept with the message it
  /// was reported for: once another failure replaces the message, this title
  /// no longer applies and the alert falls back to its generic one.
  private var reportedFailure: ReportedFailure?
  var loadFailure: String? {
    // The workspace will not open, so nothing can vouch for a running activity.
    didSet { if loadFailure != nil { syncLiveActivity() } }
  }
  var workoutPresented = false
  var receipt: WorkoutSession?
  /// The latest haptic-worthy event; `FormaHapticRelay` plays it.
  private(set) var hapticEvent: FormaHapticEvent?
  var hapticsEnabled = true { didSet { savePreferences() } }
  /// "Show workout on Lock Screen". Local to this iPhone, like the other presentation
  /// preferences. Turning it off ends a running activity at once.
  var liveActivityEnabled = true {
    didSet {
      savePreferences()
      if liveActivityEnabled != oldValue { syncLiveActivity(force: true) }
    }
  }
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
  /// The finished workout, and whose store it is in, that the Watch's final
  /// reading still belongs to. Cleared once that reading is stored.
  private var watchSummaryTarget: (sessionID: String, owner: String)?
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
    watch.onRecordingEnded = { [weak self] summary in
      guard let self else { return }
      Task { await self.storeFinalWatchSummary(summary) }
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
    forActiveSession expectedSessionID: String? = nil,
    forOwnerEpoch expectedOwnerEpoch: String? = nil,
    _ change: (inout Workspace) throws -> Void
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
    // Live Activity actions can also outlive a reset or consent change without a member switch.
    // Recheck their epoch after the queue, before touching either canonical or persisted data.
    if let expectedOwnerEpoch {
      guard !expectedOwnerEpoch.isEmpty, expectedOwnerEpoch == widgets.epoch else { return false }
    }
    do {
      if let expectedSessionID, candidate.active?.id != expectedSessionID {
        throw AppFailure("This workout has changed. Reopen your active session before editing it.")
      }
      let revision = candidate.revision
      try change(&candidate)
      // Duplicate/stale external intents are harmless no-ops, not another durable revision.
      if expectedOwnerEpoch != nil, candidate == workspace { return false }
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
      errorMessage = Self.failureMessage(
        "This change was not saved. Your last saved workout is intact.", error)
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
    // The latest Watch reading goes in with the workout; the final one, sent
    // when the Watch stops, replaces it if it arrives later.
    let summary = watch.summary
    if await commit(
      forActiveSession: id,
      { value in
        value = try WorkoutEngine.finish(value, now: Self.now, catalog: catalog, watch: summary)
      })
    {
      receipt = workspace?.history.first { $0.id == id }
      let recording = watch.phase == .recording || watch.phase == .ending
      watchSummaryTarget = recording ? (id, storeIdentity) : nil
      // The Watch ends its recording and saves it to Apple Health.
      await watch.end(save: true)
    }
  }

  /// Stores the Watch's final reading on the workout it belongs to. Nothing is
  /// written when the workout is gone, the store changed, or nothing differs.
  func storeFinalWatchSummary(_ summary: WorkoutWatchSummary) async {
    guard let target = watchSummaryTarget, target.owner == storeIdentity else { return }
    watchSummaryTarget = nil
    guard let session = workspace?.history.first(where: { $0.id == target.sessionID }),
      session.watch != summary
    else { return }
    if await commit({ value in
      value = try WorkoutEngine.attachWatchSummary(
        summary, toFinished: target.sessionID, in: value)
    }), receipt?.id == target.sessionID {
      receipt = workspace?.history.first { $0.id == target.sessionID }
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
      // The reset is one transaction, so a failure leaves everything in place.
      reportFailure(
        "Couldn’t delete your training", "Nothing on this iPhone was deleted. Try again from You.")
    }
  }

  private func loadPreferences() {
    guard let preferencesURL, let data = try? Data(contentsOf: preferencesURL),
      let preferences = try? JSONDecoder().decode(PresentationPreferences.self, from: data)
    else { return }
    loadingPreferences = true
    defer { loadingPreferences = false }
    hapticsEnabled = preferences.hapticsEnabled
    liveActivityEnabled = preferences.liveActivityEnabled ?? true
    motion = preferences.motion
    appearance = preferences.appearance
  }

  private func savePreferences() {
    guard !loadingPreferences, let preferencesURL else { return }
    do {
      let preferences = PresentationPreferences(
        hapticsEnabled: hapticsEnabled, liveActivityEnabled: liveActivityEnabled, motion: motion,
        appearance: appearance)
      try JSONEncoder().encode(preferences).write(
        to: preferencesURL, options: [.atomic, .completeFileProtection])
    } catch {
      reportFailure(
        "Couldn’t save this setting",
        "The change applies now, but FORMA may go back to the previous setting the next time it opens. Try changing it again."
      )
    }
  }
}

extension AppModel {
  /// The root alert's title for the current `errorMessage`, or nil for the
  /// generic "Couldn’t save this change".
  var errorTitle: String? {
    guard let reportedFailure, reportedFailure.message == errorMessage else { return nil }
    return reportedFailure.title
  }

  /// Reports a failure the root alert shows with its own title, for a failure
  /// that is not a change being saved (a deletion, a setting, a sign-out).
  func reportFailure(_ title: String, _ message: String) {
    reportedFailure = ReportedFailure(title: title, message: message)
    errorMessage = message
  }

  /// `summary`, followed by the error's own explanation when FORMA wrote it.
  /// A system error's wording ("The operation couldn’t be completed.
  /// (NSCocoaErrorDomain …)") explains nothing to the person, so it is left out.
  nonisolated static func failureMessage(_ summary: String, _ error: any Error) -> String {
    guard let detail = ownWording(error), !detail.isEmpty, detail != summary else { return summary }
    return "\(summary) \(detail)"
  }

  /// The explanation of an error FORMA defines, or nil for a system error.
  nonisolated static func ownWording(_ error: any Error) -> String? {
    if let failure = error as? AppFailure { return failure.message }
    if let failure = error as? FormaError { return failure.errorDescription }
    return nil
  }
}

/// A failure reported with its own alert title.
struct ReportedFailure: Equatable {
  let title: String
  let message: String
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
  /// Absent in files written before the Live Activity existed, which means on.
  var liveActivityEnabled: Bool?
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
