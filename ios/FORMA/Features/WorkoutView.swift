import AudioToolbox
import FORMACore
import SwiftUI

/// One hold timer at a time, local to the workout screen as on the web: it is
/// a stopwatch, not workout data. Running while `endsAt` is set; paused with
/// `left` seconds remaining otherwise.
struct ActiveHold: Equatable {
  let id = UUID()
  let sessionID: String
  let entryID: String
  let exerciseID: String
  let setIndex: Int
  let length: Int
  var endsAt: Date?
  var left: Int

  func remaining(at date: Date) -> Int {
    guard let endsAt else { return left }
    return max(0, Int(ceil(endsAt.timeIntervalSince(date))))
  }
}

/// Digits roll from one real value to the next at full motion. Minimal fades an
/// event (a set completing); a per-second tick changes at once unless motion is
/// full, since a fade every second would only be noise. Off changes at once.
private struct NumericChange<Value: Equatable>: ViewModifier {
  @Environment(\.formaMotion) private var motion
  let value: Value
  var countsDown = false
  var perSecond = false

  func body(content: Content) -> some View {
    let transition: ContentTransition =
      switch motion {
      case .full: .numericText(countsDown: countsDown)
      case .minimal: perSecond ? .identity : .opacity
      case .off: .identity
      }
    content
      .contentTransition(transition)
      .animation(
        perSecond && !motion.allowsSpatialMotion ? nil : motion.animation(FormaMotion.state),
        value: value)
  }
}

/// Why the workout could not save or move on. A message about one set names it
/// (`rowKey`, and the `field` to fix) so it shows beside that set; one about the
/// whole screen has neither. Every issue is unique, so repeating the same
/// mistake announces again.
struct DraftIssue: Equatable {
  let id = UUID()
  var rowKey: String?
  var field: String?
  let message: String
}

/// An invalid draft in one set. It carries the set so the screen can say
/// which one, and conforms to `LocalizedError` so a failed commit that wraps
/// it still reads in words.
private struct SetDraftFailure: LocalizedError {
  let rowKey: String
  let field: String?
  let setNumber: Int
  /// The draft's own message, which starts with a capital.
  let reason: String

  var errorDescription: String? {
    "Set \(setNumber): " + reason.prefix(1).lowercased() + reason.dropFirst()
  }
}

extension MeasurementDraft {
  /// The first field whose text won't save, in the order `value(from:)` reads
  /// them, so the screen can mark it and put the keyboard there.
  func invalidField(for original: LoggedSet, locale: Locale) -> String? {
    func parse(_ text: String) -> Double? { MeasurementNumberInput.parse(text, locale: locale) }
    func isCount(_ value: Double) -> Bool { value.rounded() == value && (1...100).contains(value) }
    guard parse(weight) != nil else { return "weight" }
    if original.sides != nil {
      guard let l = parse(left) else { return "left" }
      guard let r = parse(right) else { return "right" }
      if !isCount(l) { return "left" }
      if !isCount(r) || l + r > 100 { return "right" }
    } else {
      guard let count = parse(reps), isCount(count) else { return "reps" }
    }
    if original.durationSeconds != nil, parse(seconds) == nil { return "seconds" }
    if original.distanceMeters != nil, parse(distance) == nil { return "distance" }
    return nil
  }
}

/// One clock format for the hold timer, the rest dock and elapsed time:
/// minutes and seconds ("1:05"), with hours once there are some, in the
/// reader's own digits.
enum WorkoutClock {
  static func text(_ seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
    let duration = Duration.seconds(max(0, seconds))
    if seconds >= 3_600 {
      return duration.formatted(.time(pattern: .hourMinuteSecond).locale(locale))
    }
    return duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1)).locale(locale))
  }

  /// "1 minute, 5 seconds", for VoiceOver.
  static func spoken(_ seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
    Duration.seconds(max(0, seconds)).formatted(
      .units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))
  }
}

/// What Save & close and Finish were doing when a running hold interrupted.
private enum HoldLeave { case close, finish }

private func setCount(_ count: Int) -> String { count == 1 ? "1 set" : "\(count) sets" }

struct WorkoutView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  @State private var selectedExercise = 0
  /// Set once the screen has moved to where the person left off, and while that
  /// move is in flight so it does not play the exercise-change haptic.
  @State private var restoredPosition = false
  @State private var restoringPosition = false
  @State private var drafts: [String: SetDraft] = [:]
  @State private var validation: DraftIssue?
  @State private var finishConfirmation = false
  @State private var discardConfirmation = false
  @State private var guide: Exercise?
  @State private var notesPresented = false
  @State private var feedback = 0
  @State private var hold: ActiveHold?
  @State private var holdLog = HoldLogState()
  @State private var holdLengths: [String: Int] = [:]
  @State private var holdMessage: String?
  @State private var holdLeave: HoldLeave?
  @State private var holdDiscardConfirmation = false
  /// Sets reopened to correct them. Ticking one again keeps a rest that is
  /// already running instead of restarting it.
  @State private var reopened: Set<String> = []
  /// A rest is counting down, so the screen stays on for it.
  @State private var restCounting = false
  @FocusState private var focusedField: String?

  var body: some View {
    if let session = model.workspace?.active {
      ScrollViewReader { reader in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            if model.widgetRoute != nil {
              VStack(alignment: .leading) {
                Text("Widget link queued. Use Save & close to open it.")
                  .font(.footnote).foregroundStyle(FormaTheme.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityElement(children: .contain)
              .accessibilityIdentifier("widget-link-queued")
            }
            AdaptiveMetricGroup {
              VStack(alignment: .leading, spacing: 6) {
                Text("IN YOUR OWN TIME.").font(.caption.weight(.bold)).tracking(1.5)
                  .foregroundStyle(FormaTheme.accent)
                Text(session.name).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
              }
              ElapsedTime(startedAt: session.startedAt)
            }
            saveStatus
            WatchRecordingStrip()
            exerciseSelector(session)

            if session.exercises.indices.contains(selectedExercise) {
              let entry = session.exercises[selectedExercise]
              let exercise = model.exercise(entry.exerciseId)
              VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                  VStack(alignment: .leading, spacing: 6) {
                    Text("EXERCISE \(selectedExercise + 1) OF \(session.exercises.count)")
                      .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(
                        FormaTheme.secondary)
                    Text(exercise?.name ?? entry.exerciseId)
                      .font(.system(.title, design: .default, weight: .bold).width(.condensed))
                      .accessibilityAddTraits(.isHeader)
                  }
                  Spacer(minLength: 4)
                  if let exercise {
                    Button {
                      guide = exercise
                    } label: {
                      Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("Read \(exercise.name) instructions and source")
                  }
                }
                LastSetLabel(exerciseID: entry.exerciseId, sessionID: session.id)
                if let note = entry.note, !note.isEmpty {
                  Text(note).font(.subheadline).foregroundStyle(FormaTheme.secondary)
                }
                if entry.groupId != nil {
                  Label("Superset · rest after the final movement", systemImage: "link")
                    .font(.caption).foregroundStyle(FormaTheme.accent)
                }
                if exercise?.id == "plank" {
                  Text(
                    "This original plank logs 10 seconds per rep. For a 30-second plank, enter 3 reps or run the timer for 30 seconds."
                  )
                  .font(.caption).foregroundStyle(FormaTheme.secondary)
                }
              }
              if let exercise, HoldTimer.isAvailable(for: exercise, entry: entry) {
                holdTimer(session: session, entry: entry, exercise: exercise)
              }
              if let holdMessage {
                Label(holdMessage, systemImage: "checkmark.circle")
                  .font(.subheadline).foregroundStyle(FormaTheme.accent)
                  .accessibilityIdentifier("hold-logged")
              }
              VStack(spacing: 12) {
                ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, set in
                  let key = draftKey(entry: entry, set: index)
                  SetRow(
                    index: index,
                    entryIndex: selectedExercise,
                    exercise: exercise,
                    perSide: entry.perSide,
                    set: set,
                    draft: Binding(
                      get: { drafts[key] ?? SetDraft(set, locale: locale) },
                      set: { drafts[key] = $0 }),
                    pendingChanges: drafts[key] != nil,
                    busy: model.busy,
                    focusedField: $focusedField,
                    key: key,
                    issue: validation?.rowKey == key ? validation : nil,
                    complete: {
                      Task { await complete(sessionID: session.id, entryID: entry.id, set: index) }
                    }
                  )
                  .id(key)
                }
              }
              if let validation, validation.rowKey == nil {
                Label(validation.message, systemImage: "exclamationmark.circle")
                  .font(.subheadline).foregroundStyle(FormaTheme.error).accessibilityAddTraits(
                    .isStaticText
                  )
                  .accessibilityIdentifier("workout-validation")
              }
              HStack(spacing: 16) {
                Button {
                  Task { await addSet() }
                } label: {
                  Label("Add set", systemImage: "plus")
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .disabled(model.busy || entry.sets.count >= 100)
                Spacer()
                Button {
                  notesPresented = true
                } label: {
                  Label("Notes", systemImage: "square.and.pencil")
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .disabled(model.busy)
                .accessibilityIdentifier("session-notes")
              }.font(.subheadline.weight(.semibold))
              VStack(spacing: 12) {
                if selectedExercise + 1 < session.exercises.count {
                  Button {
                    Task {
                      if await showExercise(selectedExercise + 1) {
                        reader.scrollTo("exercise-selector", anchor: .top)
                      }
                    }
                  } label: {
                    HStack {
                      Text("Next exercise")
                      Spacer()
                      Image(systemName: "arrow.right")
                    }
                  }.buttonStyle(PrimaryButtonStyle()).disabled(model.busy)
                } else {
                  Button {
                    requestFinish()
                  } label: {
                    HStack {
                      Text("Finish workout")
                      Spacer()
                      Image(systemName: "flag.checkered")
                    }
                  }
                  .buttonStyle(PrimaryButtonStyle()).disabled(model.busy)
                  .accessibilityIdentifier("finish-workout-bottom")
                }
                if selectedExercise > 0 {
                  Button {
                    Task {
                      if await showExercise(selectedExercise - 1) {
                        reader.scrollTo("exercise-selector", anchor: .top)
                      }
                    }
                  } label: {
                    Label("Previous exercise", systemImage: "arrow.left")
                      .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                  }
                  .buttonStyle(.bordered).disabled(model.busy)
                  .accessibilityIdentifier("previous-exercise")
                }
              }
            }
          }.padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .formaBottomBar {
          VStack(spacing: 0) {
            SaveFailureBanner()
            RestDock(compact: focusedField != nil)
          }
        }
        .background(FormaTheme.canvas)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Save & close") {
              Task {
                if holdIsLive {
                  holdLeave = .close
                } else {
                  await closeWorkout()
                }
              }
            }.disabled(model.busy)
          }
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Discard workout", systemImage: "trash", role: .destructive) {
                discardConfirmation = true
              }
            } label: {
              Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Workout actions")
            .accessibilityIdentifier("workout-actions")
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Finish") { requestFinish() }
              .accessibilityIdentifier("finish-workout")
              .accessibilityLabel("Finish workout")
              .disabled(model.busy)
          }
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { Task { if await saveDrafts() { focusedField = nil } } }
              .disabled(model.busy)
              .accessibilityIdentifier("save-workout-drafts")
          }
        }
        .alert("Finish this workout?", isPresented: $finishConfirmation) {
          Button("Keep training", role: .cancel) {}
          Button("Finish workout") {
            Task {
              guard canLeaveTimedSet() else { return }
              if await saveDrafts() { await model.finish() }
            }
          }.accessibilityIdentifier("finish-confirm")
        } message: {
          Text(finishMessage(session))
        }
        .alert("Discard this workout?", isPresented: $discardConfirmation) {
          Button("Keep training", role: .cancel) {}
          Button("Discard workout", role: .destructive) {
            Task {
              if await model.discardActive() { model.workoutPresented = false }
            }
          }
        } message: {
          Text(discardMessage(session))
        }
        .confirmationDialog(
          "Your timer is still running", isPresented: holdLeaveBinding, titleVisibility: .visible,
          presenting: holdLeave
        ) { leave in
          holdLeaveActions(leave, session: session)
        } message: { _ in
          Text("\(heldSeconds) seconds held so far. Choose what happens to them.")
        }
        .confirmationDialog(
          "Discard this timer?", isPresented: $holdDiscardConfirmation, titleVisibility: .visible
        ) {
          Button("Discard timer", role: .destructive) { discardHold() }
          Button("Keep timing", role: .cancel) {}
        } message: {
          Text("The \(heldSeconds) seconds held won't be logged.")
        }
        .sheet(item: $guide) { exercise in GuideSheet(exercise: exercise).protectWidgetNavigation()
        }
        .sheet(isPresented: $notesPresented) { SessionNotesView().protectWidgetNavigation() }
        // A set was logged: a light, crisp tap. The success pattern is kept for
        // finishing the workout (CompletionSeal), so each pattern means one thing.
        .sensoryFeedback(.impact(weight: .light), trigger: feedback) { _, _ in
          model.hapticsEnabled
        }
        .onChange(of: scenePhase) { _, phase in
          // Canonical sets are already committed. Best effort for valid in-progress edits;
          // OS suspension is never treated as a successful save acknowledgement.
          if phase == .inactive { Task { _ = await saveDrafts() } }
          Task { await syncRestReminder(active: phase == .active) }
        }
        // The countdown is a deadline, so a hold that ends while the app is
        // suspended logs as soon as the app runs again.
        .task(id: hold?.endsAt) {
          guard let current = hold, let endsAt = current.endsAt else { return }
          let wait = endsAt.timeIntervalSinceNow
          if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
          guard !Task.isCancelled, hold == current else { return }
          await logHold(current, seconds: current.length)
        }
        // Open where the person left off, not at the first exercise. Done once,
        // before any tap, so a later choice is never undone.
        .onAppear {
          guard !restoredPosition else { return }
          restoredPosition = true
          let target = WorkoutEngine.resumeIndex(session)
          if target != selectedExercise {
            restoringPosition = true
            selectedExercise = target
          }
        }
        // Only the exercise buttons and menu change this, after the drafts they
        // carry have saved.
        .onChange(of: selectedExercise) { _, _ in
          holdMessage = nil
          if restoringPosition {
            restoringPosition = false
          } else {
            model.haptic(.selected)
          }
        }
        // A refused action names its reason beside the set; the warning and the
        // announcement point to it, and the set scrolls into view.
        .onChange(of: validation) { old, new in
          guard let new, new != old else { return }
          model.haptic(.warning)
          AccessibilityNotification.Announcement(new.message).post()
          if let row = new.rowKey { reader.scrollTo(row, anchor: .center) }
        }
        // A rest is a deadline: keep the screen on while one counts down, so the
        // dock stays readable between sets, and let it sleep again when the rest
        // ends, is paused or skipped.
        .task(id: session.restEnd) {
          guard let end = session.restEnd else {
            restCounting = false
            return
          }
          let wait = end / 1_000 - Date.now.timeIntervalSince1970
          restCounting = wait > 0
          guard wait > 0 else { return }
          try? await Task.sleep(for: .seconds(wait))
          if !Task.isCancelled { restCounting = false }
        }
        // Also keep it on while a hold counts down, as the web does.
        .onChange(of: hold?.endsAt != nil || restCounting) { _, awake in
          UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onChange(of: session.restEnd) { old, new in
          // The first rest is the moment to ask: the reason is on screen.
          if new != nil, new != old {
            Task { await RestReminder.shared.requestAuthorizationIfNeeded() }
          }
          // Skipped, paused or extended while in front: nothing pending.
          Task { await syncRestReminder(active: scenePhase == .active) }
        }
        .onDisappear {
          hold = nil
          UIApplication.shared.isIdleTimerDisabled = false
          RestReminder.shared.cancel()
        }
        .accessibilityIdentifier("workout-screen")
      }
    }
  }

  private func syncRestReminder(active: Bool) async {
    await RestReminder.shared.sync(
      restEnd: model.workspace?.active?.restEnd,
      muted: model.workspace?.profile.muted ?? false, appActive: active)
  }

  /// Edits not yet saved get a visible way to save them, so the status never
  /// points at a control that is off screen.
  @ViewBuilder private var saveStatus: some View {
    if drafts.isEmpty {
      LocalSaveStatus(saving: model.busy)
    } else {
      HStack(spacing: 12) {
        Label("Unsaved edits", systemImage: "pencil.circle")
          .font(.footnote).foregroundStyle(FormaTheme.secondary)
          .accessibilityIdentifier("local-save-status")
        Spacer(minLength: 8)
        Button {
          Task { if await saveDrafts() { focusedField = nil } }
        } label: {
          Text("Save edits").frame(minHeight: 44).contentShape(Rectangle())
        }
        .font(.footnote.weight(.semibold)).disabled(model.busy)
        .accessibilityIdentifier("save-workout-drafts-inline")
      }
    }
  }

  private func exerciseSelector(_ session: WorkoutSession) -> some View {
    let completed = WorkoutEngine.completedSets(session)
    return Menu {
      ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, entry in
        let name = model.exercise(entry.exerciseId)?.name ?? entry.exerciseId
        let progress = WorkoutEngine.setProgress(entry)
        Button {
          Task { _ = await showExercise(index) }
        } label: {
          let title = "\(index + 1). \(name) · \(progress.done)/\(progress.total)"
          if index == selectedExercise {
            Label(title, systemImage: "checkmark")
          } else {
            Text(title)
          }
        }
        .accessibilityLabel(
          "\(index + 1). \(name), \(progress.done) of \(progress.total) sets done"
            + (index == selectedExercise ? ", current" : ""))
      }
    } label: {
      HStack {
        Image(systemName: "list.bullet")
        Text("Choose exercise")
        Spacer()
        Text("\(completed) sets completed")
          .font(.caption)
          .modifier(NumericChange(value: completed))
        Image(systemName: "chevron.down")
      }
      .font(.subheadline.weight(.medium)).padding(16)
      .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    .id("exercise-selector")
    .disabled(model.busy)
  }

  /// Saves the edits in flight, then shows another exercise. False when the
  /// edits could not be saved, in which case nothing moves.
  private func showExercise(_ index: Int) async -> Bool {
    guard await saveDrafts() else { return false }
    focusedField = nil
    selectedExercise = index
    validation = nil
    return true
  }

  private func draftKey(entry: SessionEntry, set: Int) -> String { "\(entry.id)-\(set)" }

  /// A timer that is counting or paused, not yet saving or waiting on a retry.
  private var holdIsLive: Bool { hold != nil && !holdLog.isSaving && !holdLog.needsRetry }

  /// Whole seconds the current timer has run, or the duration a failed save
  /// is holding for its retry.
  private var heldSeconds: Int {
    if let attempt = holdLog.attempt { return attempt.seconds }
    guard let hold else { return 0 }
    return max(0, hold.length - hold.remaining(at: .now))
  }

  private var holdLeaveBinding: Binding<Bool> {
    Binding(get: { holdLeave != nil }, set: { if !$0 { holdLeave = nil } })
  }

  @ViewBuilder
  private func holdLeaveActions(_ leave: HoldLeave, session: WorkoutSession) -> some View {
    let exercise = hold.flatMap { model.exercise($0.exerciseID) }
    let unit = exercise?.holdUnit
    let units = unit.map { HoldTimer.loggedCount(seconds: heldSeconds, unit: $0) } ?? 0
    let verb = leave == .close ? "close" : "finish"
    if let unit, units >= 1, let timer = hold {
      Button("Log \(HoldTimer.loggedText(count: units, unit: unit)) and \(verb)") {
        Task {
          await logHold(timer, seconds: heldSeconds)
          // A failed save keeps the timer for its retry; stay on the screen.
          if hold == nil { await continueLeaving(leave) }
        }
      }
    }
    Button("Discard timer and \(verb)", role: .destructive) {
      discardHold()
      Task { await continueLeaving(leave) }
    }
    Button("Keep training", role: .cancel) {}
  }

  private func continueLeaving(_ leave: HoldLeave) async {
    switch leave {
    case .close: await closeWorkout()
    case .finish: finishConfirmation = true
    }
  }

  private func requestFinish() {
    if holdIsLive { holdLeave = .finish } else { finishConfirmation = true }
  }

  private func closeWorkout() async {
    guard canLeaveTimedSet() else { return }
    if await saveDrafts() {
      // Any earlier failure was already shown inline here; don't
      // replay it as an alert once the workout screen closes.
      model.errorMessage = nil
      model.workoutPresented = false
    }
  }

  private func discardHold() {
    if let timer = hold { holdLog.cancel(timer.id) }
    hold = nil
    model.haptic(.stopped)
  }

  private func finishMessage(_ session: WorkoutSession) -> String {
    let total = WorkoutEngine.totalSets(session)
    let unfinished = WorkoutEngine.unfinishedSets(session)
    var text = "You've completed \(WorkoutEngine.completedSets(session)) of \(setCount(total))."
    if unfinished > 0 {
      text +=
        " The \(unfinished == 1 ? "unfinished set" : "\(unfinished) unfinished sets") won't count towards your totals."
    }
    text += " The workout is saved to your training journal."
    if model.watch.phase == .recording {
      text += " Your Apple Watch recording ends and is saved to Health."
    }
    return text
  }

  private func discardMessage(_ session: WorkoutSession) -> String {
    let done = WorkoutEngine.completedSets(session)
    var text =
      done == 0
      ? "This deletes the workout."
      : "This deletes the workout and its \(setCount(done)) completed."
    if model.watch.phase == .recording {
      text += " The Apple Watch recording is discarded too."
    }
    return text + " Your routines and finished workouts stay saved."
  }

  /// Closing the view would discard its stopwatch state. A failed timed-set
  /// save needs an explicit retry or cancellation before that can happen.
  private func canLeaveTimedSet() -> Bool {
    guard !holdLog.needsRetry, !holdLog.isSaving else {
      flag("Your timed set is not saved. Retry or cancel it before closing or finishing.")
      return false
    }
    return true
  }

  /// Shows why something was refused. A failure in one set marks that set and
  /// puts the keyboard on the field to fix.
  private func flag(_ message: String, in failure: SetDraftFailure? = nil) {
    guard let failure else {
      validation = DraftIssue(message: message)
      return
    }
    validation = DraftIssue(rowKey: failure.rowKey, field: failure.field, message: message)
    if let field = failure.field { focusedField = "\(failure.rowKey)-\(field)" }
  }

  private func flag(_ error: Error) {
    flag(error.localizedDescription, in: error as? SetDraftFailure)
  }

  private func applyDrafts(_ submitted: [String: SetDraft], to value: inout Workspace) throws {
    guard var session = value.active else { throw FormaError.noActiveWorkout }
    for entry in session.exercises.indices {
      for set in session.exercises[entry].sets.indices {
        let key = draftKey(entry: session.exercises[entry], set: set)
        // A text event started before a completion can arrive while SQLite is
        // saving. Its explicit pending draft must remain saveable afterwards;
        // value(from:) preserves the canonical completion flag.
        if let draft = submitted[key] {
          let original = session.exercises[entry].sets[set]
          do {
            session.exercises[entry].sets[set] = try draft.value(from: original)
          } catch {
            throw SetDraftFailure(
              rowKey: key, field: draft.invalidField(for: original, locale: locale),
              setNumber: set + 1, reason: error.localizedDescription)
          }
        }
      }
    }
    value.active = session
  }

  @discardableResult
  private func saveDrafts() async -> Bool {
    guard !drafts.isEmpty else { return !model.busy }
    let submitted = drafts
    do {
      guard var candidate = model.workspace, let sessionID = candidate.active?.id else {
        return false
      }
      try applyDrafts(submitted, to: &candidate)
      // While another transaction is in flight it may still overwrite this
      // value. Queue the captured draft behind it before acknowledging anything.
      if !model.busy, candidate == model.workspace {
        drafts = retainingUnacknowledgedDrafts(drafts, acknowledged: submitted)
        validation = nil
        return true
      }
      if await model.commit(forActiveSession: sessionID, { try applyDrafts(submitted, to: &$0) }) {
        drafts = retainingUnacknowledgedDrafts(drafts, acknowledged: submitted)
        validation = drafts.isEmpty ? nil : newerEditsIssue
        // Programmatic dismissal is allowed even with interactive dismissal
        // disabled, so callers must not close or finish over newer text.
        return drafts.isEmpty
      }
    } catch { flag(error) }
    return false
  }

  private var newerEditsIssue: DraftIssue {
    DraftIssue(message: "Newer edits are still unsaved. Choose Save edits to keep them.")
  }

  private func complete(sessionID: String, entryID: String, set: Int) async {
    guard !model.busy else { return }
    let submitted = drafts
    do {
      guard var candidate = model.workspace, let session = candidate.active,
        session.id == sessionID,
        let entry = session.exercises.firstIndex(where: { $0.id == entryID }),
        session.exercises[entry].sets.indices.contains(set)
      else { return }
      try applyDrafts(submitted, to: &candidate)
      let wasDone = session.exercises[entry].sets[set].done
      let rowKey = draftKey(entry: session.exercises[entry], set: set)
      // A set reopened to fix a value keeps the rest already running.
      let rest: WorkoutEngine.RestTrigger = reopened.contains(rowKey) ? .onlyIfIdle : .always
      let saved = await model.commit(forActiveSession: session.id) { value in
        guard let currentEntry = value.active?.exercises.firstIndex(where: { $0.id == entryID })
        else { throw AppFailure("This exercise has changed. Reopen it before editing its sets.") }
        try applyDrafts(submitted, to: &value)
        value = try WorkoutEngine.toggleSet(
          in: value, entryIndex: currentEntry, setIndex: set, now: AppModel.now,
          catalog: model.catalog, rest: rest)
      }
      if saved {
        drafts = retainingUnacknowledgedDrafts(drafts, acknowledged: submitted)
        // The completed row is now locked, so its field must give up focus. A
        // field the user moved on to while the commit was in flight keeps its
        // keyboard: fields are no longer disabled by `busy`.
        if drafts.isEmpty, focusedField?.hasPrefix(rowKey + "-") == true { focusedField = nil }
        validation = drafts.isEmpty ? nil : newerEditsIssue
        if wasDone {
          reopened.insert(rowKey)
          model.haptic(.undone)
        } else {
          reopened.remove(rowKey)
          feedback += 1
          announceRestStarted(set: set)
        }
      }
    } catch { flag(error) }
  }

  /// VoiceOver gets what the dock shows: a rest began, and for how long.
  private func announceRestStarted(set: Int) {
    guard let session = model.workspace?.active,
      WorkoutEngine.isResting(session, now: AppModel.now)
    else { return }
    let seconds = Int(WorkoutEngine.remainingRest(session, now: AppModel.now))
    AccessibilityNotification.Announcement(
      "Set \(set + 1) done. Rest \(WorkoutClock.spoken(seconds, locale: locale))."
    ).post()
  }

  private func addSet() async {
    guard let session = model.workspace?.active,
      session.exercises.indices.contains(selectedExercise)
    else { return }
    let entryID = session.exercises[selectedExercise].id
    guard await saveDrafts() else { return }
    let added = await model.commit(forActiveSession: session.id) { value in
      guard let index = value.active?.exercises.firstIndex(where: { $0.id == entryID }),
        let last = value.active?.exercises[index].sets.last
      else { throw AppFailure("This exercise has changed. Reopen it before adding a set.") }
      var next = last
      next.done = false
      value.active?.exercises[index].sets.append(next)
    }
    if added { model.haptic(.added) }
  }

  private func holdTimer(session: WorkoutSession, entry: SessionEntry, exercise: Exercise)
    -> some View
  {
    let unit = exercise.holdUnit
    let current = hold.flatMap { $0.sessionID == session.id && $0.entryID == entry.id ? $0 : nil }
    let openSet = entry.sets.firstIndex { !$0.done }
    let length =
      current?.length
      ?? HoldTimer.clamp(
        holdLengths[entry.id] ?? HoldTimer.defaultLength(for: entry, unit: unit), unit: unit)
    return HoldTimerCard(
      name: exercise.name,
      setNumber: (current?.setIndex ?? openSet).map { $0 + 1 },
      length: length, hold: current, unit: unit,
      otherHoldRunning: hold != nil && current == nil,
      saving: current != nil && holdLog.isSaving,
      pendingSeconds: current != nil ? holdLog.attempt?.seconds : nil,
      needsRetry: current != nil && holdLog.needsRetry,
      adjust: { delta in
        holdLengths[entry.id] = HoldTimer.clamp(length + delta, unit: unit)
        model.haptic(delta > 0 ? .increased : .decreased)
      },
      start: {
        guard hold == nil, let openSet else { return }
        holdMessage = nil
        let timer = ActiveHold(
          sessionID: session.id, entryID: entry.id, exerciseID: entry.exerciseId,
          setIndex: openSet, length: length, endsAt: .now.addingTimeInterval(Double(length)),
          left: length)
        guard holdLog.begin(timer.id) else { return }
        hold = timer
        model.haptic(.started)
      },
      pause: {
        guard !holdLog.isSaving, !holdLog.needsRetry,
          var timer = hold, timer.endsAt != nil
        else { return }
        timer.left = timer.remaining(at: .now)
        timer.endsAt = nil
        hold = timer
        model.haptic(.stopped)
      },
      resume: {
        guard !holdLog.isSaving, !holdLog.needsRetry,
          var timer = hold, timer.endsAt == nil
        else { return }
        timer.endsAt = .now.addingTimeInterval(Double(timer.left))
        hold = timer
        model.haptic(.started)
      },
      end: {
        guard !holdLog.isSaving, !holdLog.needsRetry, let timer = hold else { return }
        let held = timer.length - timer.remaining(at: .now)
        guard held >= unit.seconds else { return }
        Task { await logHold(timer, seconds: held) }
      },
      cancel: {
        guard !holdLog.isSaving else { return }
        // Effort worth keeping is confirmed first; a mis-tap seconds in is not.
        if holdLog.needsRetry || heldSeconds > 10 {
          holdDiscardConfirmation = true
        } else {
          discardHold()
        }
      },
      retry: {
        guard let timer = hold, let attempt = holdLog.attempt else { return }
        Task { await logHold(timer, seconds: attempt.seconds) }
      })
  }

  /// Logs the timed set (the first unfinished one if it was ticked meanwhile)
  /// and starts the programmed rest, exactly as ticking it would.
  private func logHold(_ timer: ActiveHold, seconds: Int) async {
    guard hold == timer,
      let attempt = holdLog.claim(holdID: timer.id, seconds: seconds)
    else { return }
    let submitted = drafts
    var logged: (index: Int, count: Int)?
    let saved = await model.commit(forActiveSession: timer.sessionID) { value in
      try applyDrafts(submitted, to: &value)
      let result = try WorkoutEngine.logHold(
        in: value, entryID: timer.entryID, startedOn: timer.setIndex, seconds: attempt.seconds,
        now: AppModel.now, catalog: model.catalog)
      value = result.workspace
      logged = (result.setIndex, result.count)
    }
    guard saved, let logged else {
      // A finished hold must remain retryable when validation or storage fails.
      // Freeze its duration; correcting a draft must not add time to the effort.
      if holdLog.failed(attempt), var current = hold, current.id == timer.id {
        current.endsAt = nil
        current.left = max(0, current.length - attempt.seconds)
        hold = current
      }
      return
    }
    guard holdLog.acknowledged(attempt) else { return }
    if hold?.id == timer.id { hold = nil }
    drafts = retainingUnacknowledgedDrafts(drafts, acknowledged: submitted)
    validation = drafts.isEmpty ? nil : newerEditsIssue
    feedback += 1
    // The web's audible cue: a short tone unless training sounds are muted.
    if model.workspace?.profile.muted == false { AudioServicesPlaySystemSound(1057) }
    let exercise = model.exercise(timer.exerciseID)
    let name = exercise?.name ?? timer.exerciseID
    let detail =
      exercise.map { HoldTimer.loggedText(count: logged.count, unit: $0.holdUnit) }
      ?? "\(attempt.seconds) seconds"
    let message = "\(name) set \(logged.index + 1) logged: \(detail)."
    holdMessage = message
    AccessibilityNotification.Announcement(message).post()
  }
}

/// The "Last time" line scans the whole journal. Keeping that scan in its own
/// view means a keystroke in a set field (which re-runs `WorkoutView.body`)
/// does not repeat it: this body re-runs only when the exercise, the session
/// or the journal itself changes.
private struct LastSetLabel: View {
  @Environment(AppModel.self) private var model
  let exerciseID: String
  let sessionID: String

  var body: some View {
    if let previous = WorkoutEngine.lastCompletedSet(
      for: exerciseID, in: model.history, excluding: sessionID)
    {
      Label(
        "Last time · \(measurementText(previous, exercise: model.exercise(exerciseID)))",
        systemImage: "clock.arrow.circlepath"
      )
      .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
  }
}

private struct HoldTimerCard: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  let name: String
  let setNumber: Int?
  let length: Int
  let hold: ActiveHold?
  let unit: HoldUnit
  let otherHoldRunning: Bool
  let saving: Bool
  let pendingSeconds: Int?
  let needsRetry: Bool
  let adjust: (Int) -> Void
  let start: () -> Void
  let pause: () -> Void
  let resume: () -> Void
  let end: () -> Void
  let cancel: () -> Void
  let retry: () -> Void

  var body: some View {
    Group {
      // One entry per second, ending exactly at the persisted deadline, so the
      // digits change once a second and land on 00:00 when the hold is up. The
      // smooth progress is drawn by its own timeline (HoldProgressBar).
      if let endsAt = hold?.endsAt, scenePhase == .active {
        TimelineView(CountdownSchedule(end: endsAt)) { context in panel(at: context.date) }
          .id(endsAt)
      } else {
        panel(at: .now)
      }
    }
    .padding(16)
    .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Hold timer for \(name)")
    .accessibilityIdentifier("hold-timer")
  }

  private func panel(at date: Date) -> some View {
    let remaining = pendingSeconds.map { max(0, length - $0) } ?? hold?.remaining(at: date)
    let shown = remaining ?? length
    let held = length - (remaining ?? length)
    let units = HoldTimer.loggedCount(seconds: held, unit: unit)
    let step = HoldTimer.step(unit)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Label("Hold timer", systemImage: "timer")
          .font(.subheadline.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
        Spacer(minLength: 8)
        Text(WorkoutClock.text(shown, locale: locale))
          .font(.title.bold().monospacedDigit()).foregroundStyle(FormaTheme.primary)
          .modifier(NumericChange(value: shown, countsDown: true, perSecond: true))
          .accessibilityLabel(
            "\(WorkoutClock.spoken(shown, locale: locale)) \(hold == nil ? "hold" : "remaining")"
          )
          .accessibilityIdentifier("hold-remaining")
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { controls(step: step, units: units) }
        VStack(alignment: .leading, spacing: 10) { controls(step: step, units: units) }
      }
      .font(.subheadline.weight(.semibold))
      HoldProgressBar(
        hold: pendingSeconds == nil ? hold : nil,
        stepped: hold == nil ? 0 : min(1, Double(held) / Double(max(1, length))))
      Text(note).font(.footnote).foregroundStyle(FormaTheme.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private func controls(step: Int, units: Int) -> some View {
    if saving {
      ProgressView("Saving timed set…")
        .frame(minHeight: 44)
        .accessibilityIdentifier("hold-saving")
    } else if needsRetry {
      Button(action: retry) {
        Text("Retry save").frame(minHeight: 44).contentShape(Rectangle())
      }
      .buttonStyle(PrimaryButtonStyle())
      .accessibilityIdentifier("hold-retry")
      Button(action: cancel) {
        Text("Cancel timed set").frame(minHeight: 44).contentShape(Rectangle())
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("hold-cancel")
    } else if let hold {
      let running = hold.endsAt != nil
      Button(action: running ? pause : resume) {
        Label(running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill")
          .frame(minHeight: 44)
      }
      .buttonStyle(.bordered)
      .accessibilityLabel(running ? "Pause hold timer" : "Resume hold timer")
      .accessibilityIdentifier("hold-toggle")
      Button(action: end) {
        Label("End set", systemImage: "stop.fill").frame(minHeight: 44)
      }
      .buttonStyle(.bordered)
      .disabled(units < 1)
      .accessibilityLabel(
        "End set \(hold.setIndex + 1) now and log \(HoldTimer.loggedText(count: units, unit: unit))"
      )
      .accessibilityIdentifier("hold-end")
      Button(action: cancel) {
        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
      }
      .accessibilityLabel("Cancel hold timer without logging")
      .accessibilityIdentifier("hold-cancel")
    } else {
      Button {
        adjust(-step)
      } label: {
        Text("−\(step)").frame(minWidth: 44, minHeight: 44)
      }
      .buttonStyle(.bordered)
      .disabled(length <= HoldTimer.minimum(unit))
      .accessibilityLabel(
        "Shorter hold, \(max(HoldTimer.minimum(unit), length - step)) seconds")
      Button {
        adjust(step)
      } label: {
        Text("+\(step)").frame(minWidth: 44, minHeight: 44)
      }
      .buttonStyle(.bordered)
      .disabled(length >= HoldTimer.maximum(unit))
      .accessibilityLabel("Longer hold, \(min(HoldTimer.maximum(unit), length + step)) seconds")
      Button(action: start) {
        Label("Start", systemImage: "play.fill").frame(minHeight: 44)
      }
      .buttonStyle(PrimaryButtonStyle())
      .disabled(setNumber == nil || otherHoldRunning)
      .accessibilityLabel(
        setNumber.map { "Start \(length)-second hold for \(name) set \($0)" }
          ?? "All \(name) sets are logged"
      )
      .accessibilityIdentifier("hold-start")
    }
  }

  private var note: String {
    if saving { return "Your timed set is being saved. Completion appears after it is saved." }
    if needsRetry, let pendingSeconds {
      return "\(pendingSeconds) seconds held, not saved. Correct any invalid fields, then retry."
    }
    guard let setNumber else { return "Every set is logged." }
    if hold != nil { return "Set \(setNumber) logs itself when time is up." }
    if otherHoldRunning { return "Another hold timer is running. End or cancel it first." }
    return unit.seconds == 1
      ? "Set \(setNumber): logs the time and starts your rest when it ends."
      : "Set \(setNumber): logs a rep for every \(unit.seconds) seconds and starts your rest when it ends."
  }
}

/// The hold's progress. At full motion it draws from the persisted deadline on
/// its own ~30 fps timeline, which runs only while the hold is counting down
/// and the app is active; otherwise (paused, minimal, off) it shows the
/// whole-second value the card already computed, with no easing.
private struct HoldProgressBar: View {
  @Environment(\.formaMotion) private var motion
  @Environment(\.scenePhase) private var scenePhase
  let hold: ActiveHold?
  let stepped: Double

  var body: some View {
    Group {
      if let hold, let endsAt = hold.endsAt, motion.allowsSpatialMotion {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) {
          context in
          let length = Double(max(1, hold.length))
          bar(min(1, max(0, 1 - endsAt.timeIntervalSince(context.date) / length)))
        }
      } else {
        bar(stepped)
      }
    }
    .accessibilityHidden(true)
  }

  private func bar(_ value: Double) -> some View {
    ProgressView(value: value).tint(FormaTheme.accent)
  }
}

private struct GuideSheet: View {
  @Environment(\.dismiss) private var dismiss
  let exercise: Exercise

  var body: some View {
    NavigationStack {
      GuideView(exercise: exercise)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
          }
        }
    }
  }
}

typealias SetDraft = MeasurementDraft

struct SetRow: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.formaMotion) private var motion
  @ScaledMetric(relativeTo: .body) private var minimumColumnWidth = 64.0
  let index: Int
  let entryIndex: Int
  let exercise: Exercise?
  let perSide: Bool
  let set: LoggedSet
  @Binding var draft: SetDraft
  let pendingChanges: Bool
  let busy: Bool
  let focusedField: FocusState<String?>.Binding
  let key: String
  /// Why this set can't be saved, shown under it with the field marked.
  var issue: DraftIssue?
  let complete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Group {
        if typeSize.isAccessibilitySize {
          stackedRow
        } else {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
              setNumber
              measurementFields
              completionButton
            }
            .fixedSize(horizontal: true, vertical: false)
            stackedRow
          }
        }
      }
      if let issue {
        Label(issue.message, systemImage: "exclamationmark.circle")
          .font(.footnote.weight(.medium)).foregroundStyle(FormaTheme.error)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("workout-validation")
      }
    }
    .padding(14).background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    // One summary per set, then its fields and the complete control inside it.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      "Set \(index + 1), \(MeasurementText.summary(set, exercise: exercise)), "
        + (set.done ? "done" : "not done"))
  }

  private var stackedRow: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        setNumber
        Spacer()
        completionButton
      }
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 14) { measurementFields }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 10) { measurementFields }
            .fixedSize(horizontal: true, vertical: false)
          VStack(alignment: .leading, spacing: 14) { measurementFields }
        }
      }
    }
  }

  private var setNumber: some View {
    Text("Set \(index + 1)").font(.subheadline.weight(.semibold).monospacedDigit())
      .foregroundStyle(FormaTheme.secondary).fixedSize()
  }

  @ViewBuilder private var measurementFields: some View {
    if exercise?.metric == "load_reps" || exercise == nil {
      if exercise?.loadType != "none" || set.weight > 0 {
        field(
          exercise?.loadType == "added" ? "Added kg" : "kg", value: $draft.weight, name: "weight")
      }
      if perSide {
        field("Left reps", value: $draft.left, name: "left")
        field("Right reps", value: $draft.right, name: "right")
      } else {
        field("Reps", value: $draft.reps, name: "reps")
      }
    } else {
      if ["duration", "duration_distance"].contains(exercise?.metric ?? "") {
        field("Seconds", value: $draft.seconds, name: "seconds")
      }
      if ["load_distance"].contains(exercise?.metric ?? "")
        || (["duration", "duration_distance"].contains(exercise?.metric ?? "")
          && (exercise?.loadType != "none" || set.weight > 0))
      {
        field(
          exercise?.loadType == "added" ? "Added kg" : "kg", value: $draft.weight, name: "weight")
      }
      if ["duration_distance", "load_distance"].contains(exercise?.metric ?? "") {
        field("Metres", value: $draft.distance, name: "distance")
      }
    }
  }

  /// The symbol replaces itself at full motion and cross-fades at minimal.
  private var symbolTransition: ContentTransition {
    motion.allowsSpatialMotion ? .symbolEffect(.replace) : .opacity
  }

  private var completionButton: some View {
    Button(action: complete) {
      Image(systemName: set.done ? "checkmark" : "checkmark.circle")
        .font(.title3.weight(.semibold))
        .contentTransition(symbolTransition)
        .foregroundStyle(set.done ? FormaTheme.ink : FormaTheme.accent)
        .frame(width: 56, height: 56)
        .contentShape(Rectangle())
        .background(
          set.done ? FormaTheme.lime : FormaTheme.canvas, in: RoundedRectangle(cornerRadius: 14)
        )
        // Always present and faded, so the outline dissolves instead of popping.
        .overlay {
          RoundedRectangle(cornerRadius: 14).stroke(FormaTheme.fieldBorder)
            .opacity(set.done ? 0 : 1)
        }
        // Keyed to the committed value: `done` only flips after the durable save,
        // so the fill and symbol never run ahead of the truth. Same 56 pt frame,
        // so neighbouring fields never move.
        .formaAnimation(FormaMotion.state, value: set.done)
    }
    .buttonStyle(.plain).disabled(busy)
    .accessibilityLabel("\(set.done ? "Undo" : "Complete") set \(index + 1)")
    .accessibilityValue(set.done ? "Completed" : "Not completed")
    .accessibilityHint(
      set.done ? "Makes this set editable again." : "Saves and completes this set on your iPhone."
    )
    .accessibilityIdentifier("complete-set-\(entryIndex)-\(index)")
  }

  private func field(_ label: String, value: Binding<String>, name: String) -> some View {
    let fieldID = "\(key)-\(name)"
    let isFocused = focusedField.wrappedValue == fieldID
    let hasIssue = issue?.field == name
    return VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
      TextField(label, text: value)
        .font(.title3.weight(.semibold).monospacedDigit())
        .keyboardType(["reps", "left", "right"].contains(name) ? .numberPad : .decimalPad)
        .multilineTextAlignment(.center).frame(minHeight: 48)
        .background(FormaTheme.canvas, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10).stroke(
            hasIssue ? FormaTheme.error : isFocused ? FormaTheme.accent : FormaTheme.fieldBorder,
            lineWidth: isFocused || hasIssue ? 2 : 1)
        }
        .focused(focusedField, equals: fieldID)
        // Ordinary completed rows are locked. A late pre-completion text event
        // remains editable until it can be validated and acknowledged. Fields
        // are not disabled while a commit is in flight: a commit applies only
        // the drafts captured when it began, and edits typed meanwhile stay
        // pending (see `retainingUnacknowledgedDrafts`), so keeping the keyboard
        // up cannot lose or double a write. Only the completion button gates.
        .disabled(set.done && !pendingChanges)
        .accessibilityLabel("Set \(index + 1), \(label)")
        .accessibilityIdentifier("set-value-\(entryIndex)-\(index)-\(name)")
    }.frame(minWidth: minimumColumnWidth, maxWidth: .infinity)
  }
}

struct ElapsedTime: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  let startedAt: Double
  var body: some View {
    if scenePhase == .active {
      TimelineView(.periodic(from: .now, by: 1)) { context in elapsed(at: context.date) }
    } else {
      elapsed(at: .now)
    }
  }

  private func elapsed(at date: Date) -> some View {
    let seconds = max(0, Int(date.timeIntervalSince1970 - startedAt / 1_000))
    return Text(WorkoutClock.text(seconds, locale: locale))
      .font(.subheadline.monospacedDigit()).foregroundStyle(FormaTheme.secondary)
      .accessibilityLabel("Elapsed time, \(WorkoutClock.spoken(seconds, locale: locale))")
  }
}

/// One entry per second from now until `end`, then a final entry exactly at
/// `end` so the dock lands on zero; no entries after that.
private struct CountdownSchedule: TimelineSchedule {
  let end: Date

  struct Entries: Sequence, IteratorProtocol {
    var cursor: Date?
    let end: Date

    mutating func next() -> Date? {
      guard let current = cursor else { return nil }
      cursor = current >= end ? nil : Swift.min(current.addingTimeInterval(1), end)
      return current
    }
  }

  func entries(from startDate: Date, mode: Mode) -> Entries {
    Entries(cursor: startDate, end: end)
  }
}

/// What the dock is showing. Presentation only: the engine still derives every
/// value from the persisted deadline.
private enum RestPhase: Equatable {
  case running, paused, over
}

/// Re-arms the end-of-rest cue when the persisted deadline changes or the app
/// leaves and re-enters the foreground.
private struct RestWatch: Equatable {
  let end: Double?
  let active: Bool
}

/// The rest ring: a track and an arc that shrinks toward the persisted
/// deadline. At full motion each per-second update glides over one linear
/// second to the value due at the next tick; at minimal and off it simply steps
/// once a second. Paused is a still, dimmed arc; over is an empty ring with a
/// check. The phases cross-fade.
private struct RestRing: View {
  @Environment(\.formaMotion) private var motion
  let progress: Double
  let phase: RestPhase

  var body: some View {
    ZStack {
      Circle().strokeBorder(FormaTheme.secondary.opacity(0.25), lineWidth: 3)
      Circle().inset(by: 1.5).trim(from: 0, to: progress)
        .stroke(
          phase == .paused ? FormaTheme.secondary : FormaTheme.accent,
          style: StrokeStyle(lineWidth: 3, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        // A round cap would leave a dot at zero length.
        .opacity(progress > 0.001 ? 1 : 0)
        .animation(
          phase == .running && motion.allowsSpatialMotion ? .linear(duration: 1) : nil,
          value: progress)
      if phase == .over {
        Image(systemName: "checkmark").font(.caption2.weight(.bold))
          .foregroundStyle(FormaTheme.accent)
          .transition(motion.transition(.scale(scale: 0.6).combined(with: .opacity)))
      }
    }
    .animation(motion.animation(FormaMotion.state), value: phase)
    .accessibilityHidden(true)
  }
}

/// A save that failed, where the person is looking: above the rest dock, which
/// stays on screen however far the sets have scrolled. It names what happened
/// and is announced; the next successful save clears it.
private struct SaveFailureBanner: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      if let failure = model.errorMessage {
        HStack(alignment: .top, spacing: 10) {
          Label(failure, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.medium)).foregroundStyle(FormaTheme.error)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
          Button {
            model.errorMessage = nil
          } label: {
            Text("Dismiss").font(.footnote.weight(.semibold))
              .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
          }
          .accessibilityIdentifier("workout-save-failure-dismiss")
        }
        .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 2)
        .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(FormaTheme.error, lineWidth: 1) }
        .padding(.horizontal, 16).padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workout-save-failure")
      }
    }
    .task(id: model.errorMessage) {
      if let failure = model.errorMessage { AccessibilityNotification.Announcement(failure).post() }
    }
  }
}

struct RestDock: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.formaMotion) private var motion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.locale) private var locale
  @ScaledMetric(relativeTo: .subheadline) private var ringSize = 22.0
  /// Counts rests that ran out while the dock was on screen. It changes exactly
  /// once per rest, so the haptic cannot fire again on a re-render.
  @State private var restCue = 0
  var compact = false

  var body: some View {
    let session = model.workspace?.active
    let visible = session.map { $0.restEnd != nil || $0.restPaused != nil } ?? false
    let restEnd = session?.restEnd
    let active = scenePhase == .active
    // The container always exists, so the dock can enter and leave inside it;
    // when empty it is zero-sized, exactly as the bare `if` was.
    VStack(spacing: 0) {
      if let session, visible {
        Group {
          // Tick only while a countdown is actually running, and stop at its
          // deadline. A paused or expired rest is static, so it no longer wakes
          // the dock once a second for the rest of the workout.
          if active, let restEnd = session.restEnd {
            TimelineView(CountdownSchedule(end: Date(timeIntervalSince1970: restEnd / 1_000))) {
              context in panel(session, at: context.date)
            }
            .id(restEnd)
          } else {
            panel(session, at: .now)
          }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .formaControlSurface()
        .padding(.horizontal, 16).padding(.vertical, 8)
        .disabled(model.busy)
        .transition(motion.transition(.move(edge: .bottom).combined(with: .opacity)))
      }
    }
    .animation(motion.animation(FormaMotion.reveal), value: visible)
    // The dock sits in the screen's bottom bar, outside the scroll view, so the
    // screen's identifier would otherwise be stamped onto every control here
    // (Pause read as "workout-screen", not "rest-toggle"). Its own container
    // keeps each control's identifier.
    .accessibilityElement(children: .contain)
    // One cue when a rest that was counting down reaches zero in front of the
    // user: a haptic and a VoiceOver announcement. The deadline is the
    // persisted timestamp. A rest that ended while the app was suspended, or
    // that was skipped, paused or extended, cues nothing here; the reminder
    // notification (RestReminder) covers a rest that ends out of sight.
    .task(id: RestWatch(end: restEnd, active: active)) {
      guard active, let restEnd else { return }
      let wait = restEnd / 1_000 - Date.now.timeIntervalSince1970
      guard wait > 0 else { return }
      try? await Task.sleep(for: .seconds(wait))
      guard !Task.isCancelled, Date.now.timeIntervalSince1970 - restEnd / 1_000 < 2 else {
        return
      }
      restCue += 1
      AccessibilityNotification.Announcement("Rest finished").post()
    }
    // Medium, to tell "go" apart from the light tap of logging a set.
    .sensoryFeedback(.impact(weight: .medium), trigger: restCue) { _, _ in model.hapticsEnabled }
  }

  // MARK: Pieces

  private func status(_ text: String, progress: Double, phase: RestPhase) -> some View {
    Label {
      Text(text).contentTransition(.opacity)
    } icon: {
      RestRing(progress: progress, phase: phase)
        .frame(width: ringSize, height: ringSize)
    }
    .animation(motion.animation(FormaMotion.state), value: phase)
    .font(.subheadline.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
    .accessibilityLabel(
      phase == .paused ? "Rest paused" : phase == .over ? "Rest finished" : "Rest timer")
  }

  private func timer(_ remaining: Int, font: Font) -> some View {
    ZStack(alignment: .trailing) {
      Text("10:00").hidden().accessibilityHidden(true)
      Text(WorkoutClock.text(remaining, locale: locale))
        .modifier(NumericChange(value: remaining, countsDown: true, perSecond: true))
        .accessibilityLabel("\(WorkoutClock.spoken(remaining, locale: locale)) remaining")
        .accessibilityIdentifier("rest-remaining")
    }
    .font(font).foregroundStyle(FormaTheme.primary)
  }

  private func pauseOrResume(_ session: WorkoutSession) {
    Task {
      let resuming = session.restPaused != nil
      let saved = await model.commit(forActiveSession: session.id) { value in
        value =
          value.active?.restPaused != nil
          ? try WorkoutEngine.resumeRest(in: value, now: AppModel.now)
          : try WorkoutEngine.pauseRest(in: value, now: AppModel.now)
      }
      if saved { model.haptic(resuming ? .started : .stopped) }
    }
  }

  private func addFifteen(_ session: WorkoutSession) {
    Task {
      let saved = await model.commit(forActiveSession: session.id) {
        $0 = try WorkoutEngine.adjustRest(in: $0, by: 15, now: AppModel.now)
      }
      if saved { model.haptic(.increased) }
    }
  }

  private func skip(_ session: WorkoutSession, haptic: Bool = true) {
    Task {
      let saved = await model.commit(forActiveSession: session.id) {
        $0 = try WorkoutEngine.skipRest(in: $0)
      }
      if saved, haptic { model.haptic(.stopped) }
    }
  }

  /// The controls keep a 44 pt target inside the button's own label, so the
  /// whole square answers a tap, not just the glyph.
  private func pauseButton(_ session: WorkoutSession) -> some View {
    let paused = session.restPaused != nil
    return Button {
      pauseOrResume(session)
    } label: {
      Image(systemName: paused ? "play.fill" : "pause.fill")
        .contentTransition(motion.allowsSpatialMotion ? .symbolEffect(.replace) : .opacity)
        .animation(motion.animation(FormaMotion.state), value: paused)
        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
    .accessibilityLabel(paused ? "Resume rest" : "Pause rest")
    .accessibilityIdentifier("rest-toggle")
  }

  private func addButton(_ session: WorkoutSession) -> some View {
    Button {
      addFifteen(session)
    } label: {
      Text("+15").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
    .accessibilityLabel("Add 15 seconds to rest")
    .accessibilityIdentifier("rest-add")
  }

  private func skipButton(_ session: WorkoutSession) -> some View {
    Button {
      skip(session)
    } label: {
      Text("Skip").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
    .accessibilityLabel("Skip rest")
    .accessibilityIdentifier("rest-skip")
  }

  private func moreMenu(_ session: WorkoutSession) -> some View {
    Menu {
      Button(
        session.restPaused != nil ? "Resume rest" : "Pause rest",
        systemImage: session.restPaused != nil ? "play.fill" : "pause.fill"
      ) { pauseOrResume(session) }
      Button("Add 15 seconds", systemImage: "plus") { addFifteen(session) }
    } label: {
      Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("More rest options")
    .accessibilityIdentifier("rest-more")
  }

  // MARK: Layout

  private func panel(_ session: WorkoutSession, at date: Date) -> some View {
    let now = date.timeIntervalSince1970 * 1_000
    let remaining = Int(ceil(WorkoutEngine.remainingRest(session, now: now)))
    let phase: RestPhase =
      remaining == 0 ? .over : session.restPaused != nil ? .paused : .running
    // Ring value, from the persisted timestamps only. Running at full motion it
    // leads by one second so the linear glide lands on each tick; the length is
    // the rest as last started, and an extension past it keeps the ring full.
    let exact = session.restEnd.map { max(0, ($0 - now) / 1_000) } ?? session.restPaused ?? 0
    let lead = phase == .running && motion.allowsSpatialMotion ? max(0, exact - 1) : exact
    let progress = min(1, lead / Double(max(1, session.restSeconds)))
    let label = phase == .paused ? "Rest paused" : "Rest"
    return Group {
      if phase == .over {
        // A finished rest keeps one compact row and one way to clear it.
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 10) {
            status("Rest done", progress: progress, phase: phase)
            Spacer(minLength: 8)
            dismissButton(session)
          }
          VStack(alignment: .leading, spacing: 4) {
            status("Rest done", progress: progress, phase: phase)
            dismissButton(session)
          }
        }
      } else if compact {
        AdaptiveMetricGroup {
          status("Rest", progress: progress, phase: phase)
          timer(remaining, font: .headline.monospacedDigit())
        }
      } else if typeSize.isAccessibilitySize {
        // The timer and the one action that matters stay; the rest go in a menu.
        VStack(alignment: .leading, spacing: 8) {
          status(label, progress: progress, phase: phase)
          timer(remaining, font: .title.bold().monospacedDigit())
          HStack(spacing: 12) {
            skipButton(session)
            moreMenu(session)
          }
        }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 8) {
            status(label, progress: progress, phase: phase)
            Spacer(minLength: 8)
            timer(remaining, font: .title2.bold().monospacedDigit())
            pauseButton(session)
            addButton(session)
            skipButton(session)
          }
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              status(label, progress: progress, phase: phase)
              Spacer(minLength: 8)
              timer(remaining, font: .title2.bold().monospacedDigit())
            }
            HStack(spacing: 8) {
              pauseButton(session)
              addButton(session)
              skipButton(session)
              Spacer(minLength: 0)
            }
          }
        }
      }
    }
    .font(.subheadline.weight(.semibold)).buttonStyle(.plain)
  }

  private func dismissButton(_ session: WorkoutSession) -> some View {
    Button {
      skip(session, haptic: false)
    } label: {
      Text("Dismiss").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
    .foregroundStyle(FormaTheme.primary)
    .accessibilityIdentifier("rest-dismiss")
  }
}

struct SessionNotesView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var notes = ""
  @State private var original = ""
  @State private var sessionID: String?
  @State private var discardConfirmation = false
  @State private var failure: String?
  var body: some View {
    NavigationStack {
      Form {
        Section("Session notes") {
          TextEditor(text: $notes).frame(minHeight: 200)
            .accessibilityLabel("Session notes")
            .accessibilityIdentifier("session-notes-editor")
          Text("\(notes.utf16.count) / 10,000 characters").font(.caption).foregroundStyle(
            FormaTheme.secondary)
        }
        Text("Keep notes about your training. FORMA doesn't provide medical advice.").font(
          .footnote)
        if let failure { Text(failure).foregroundStyle(FormaTheme.error) }
      }
      .navigationTitle("A note to yourself").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            if notes != original { discardConfirmation = true } else { dismiss() }
          }
          .disabled(model.busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              guard let sessionID else { return }
              let submitted = notes
              failure = nil
              if await model.commit(forActiveSession: sessionID, { $0.active?.notes = submitted }) {
                original = submitted
                if notes == submitted {
                  dismiss()
                } else {
                  failure = "Newer notes are still unsaved. Tap Save to keep them."
                }
              } else {
                failure = model.errorMessage
                model.errorMessage = nil
              }
            }
          }
          .disabled(model.busy || notes.utf16.count > 10_000 || sessionID == nil)
          .accessibilityIdentifier("session-notes-save")
        }
      }
    }
    .interactiveDismissDisabled(notes != original || model.busy)
    .confirmationDialog(
      "Discard these notes?", isPresented: $discardConfirmation, titleVisibility: .visible
    ) {
      Button("Discard changes", role: .destructive) { dismiss() }
    }
    .onAppear {
      sessionID = model.workspace?.active?.id
      original = model.workspace?.active?.notes ?? ""
      notes = original
    }
  }
}

struct WorkoutReceipt: View {
  @Environment(AppModel.self) private var model
  let session: WorkoutSession
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack {
          // Assembles once and plays the single success haptic; the receipt only
          // exists after the workout was saved.
          CompletionSeal()
          Spacer()
          Text(TrainingDate.label(TrainingDate.date(session), template: "d MMM yyyy")).font(
            .caption.weight(.semibold))
        }
        Rectangle().fill(FormaTheme.accent).frame(height: 3).padding(.top, 16)
        Text("THE WORK IS YOURS.").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
          FormaTheme.secondary)
        EditorialTitle(text: "Another session.\nA stronger you.")
        Text(session.name).font(.title3.weight(.semibold))
        // The statistics reveal once, in order. The button below is never held
        // back by it.
        AdaptiveMetricGroup {
          MetricValue(
            value: "\(session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count })",
            label: "Sets completed"
          ).formaReveal(order: 1)
          MetricValue(value: "\(Int((session.duration ?? 0) / 60))", label: "Minutes")
            .formaReveal(order: 2)
        }
        MetricValue(
          value: WorkoutEngine.volume(session, catalog: model.catalog).formatted(
            .number.precision(.fractionLength(0...1))), label: "Lifting volume · kg × reps"
        ).formaReveal(order: 3)
        Divider()
        Label("Session saved on this iPhone", systemImage: "checkmark.shield.fill")
          .font(.headline).foregroundStyle(FormaTheme.accent)
          .formaReveal(order: 4)
        Text("One more page in your training journal. Your completed sets are ready in Progress.")
          .font(.body).foregroundStyle(FormaTheme.secondary)
        Button {
          model.workoutPresented = false
        } label: {
          HStack {
            Text("Keep the feeling.")
            Spacer()
            Image(systemName: "arrow.right")
          }
        }
        .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("receipt-done")
      }.padding(28)
    }
    .background(FormaTheme.canvas)
    .navigationTitle("Session saved").navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("receipt-screen")
  }
}
