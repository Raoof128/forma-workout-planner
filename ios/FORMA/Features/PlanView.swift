import FORMACore
import SwiftUI

/// "1,411 exercises": grouped digits and one noun for the catalogue everywhere
/// on this tab (`countPhrase` does not group).
private func exerciseCount(_ count: Int) -> String {
  count == 1 ? "1 exercise" : "\(count.formatted()) exercises"
}

struct PlanView: View {
  @Environment(AppModel.self) private var model
  @State private var creating = false
  @State private var editing: Routine?
  @State private var pendingDelete: Routine?
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  private var showsHeader: Bool { !textSize.isAccessibilitySize && verticalSizeClass != .compact }

  var body: some View {
    // `routines` filters the workspace on every read; read it once per render.
    let routines = model.routines
    let full = (model.workspace?.routines.count ?? 0) >= RoutineDraftRules.maxRoutines
    List {
      // The session task comes first on a small or large-text screen, as on
      // Today: the header gives way and the routines start at the top.
      if showsHeader {
        Section {
          EditorialTitle(text: "Plan your\ntraining.")
            .padding(.top, 4).padding(.bottom, 8)
            .id(TabScrollAnchor.top)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
      }
      routineSection(routines, full: full)
      Section {
        ExerciseLibraryLink()
        NavigationLink(value: TrainingRoute.trainingDays) {
          Label("Training days", systemImage: "calendar")
            .padding(.vertical, 8)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .formaTabRoot(.plan)
    .background(FormaTheme.canvas)
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $creating) {
      NavigationStack { RoutineEditorView(routine: nil) }.protectWidgetNavigation()
    }
    .sheet(item: $editing) { routine in
      NavigationStack { RoutineEditorView(routine: routine) }.protectWidgetNavigation()
    }
    .confirmationDialog(
      "Delete this routine?",
      isPresented: Binding(
        get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible, presenting: pendingDelete
    ) { routine in
      Button("Delete routine", role: .destructive) { delete(routine) }
    } message: { _ in
      Text("This removes the plan only. Active and completed workouts will be kept.")
    }
  }

  private func routineSection(_ routines: [Routine], full: Bool) -> some View {
    Section {
      if routines.isEmpty {
        ContentUnavailableView {
          Label("No routines yet", systemImage: "square.stack")
        } description: {
          Text("Choose exercises and set targets for each session you train.")
        } actions: {
          createButton(full: full)
        }
      } else {
        ForEach(Array(routines.enumerated()), id: \.element.id) { position, routine in
          routineRow(routine, position: position, ids: routines.map(\.id), full: full)
        }
        .onMove { source, destination in
          var ids = routines.map(\.id)
          ids.move(fromOffsets: source, toOffset: destination)
          Task { await reorder(ids) }
        }
        createButton(full: full)
      }
    } header: {
      Text("Routines · \(routines.count)")
        .id(showsHeader ? "plan.routines" : TabScrollAnchor.top)
    } footer: {
      if full {
        Text("You can keep up to 200 routines. Delete one before adding another.")
      } else {
        Text("Starter loads are examples. Change them to a load you can control.")
      }
    }
  }

  /// Edit, duplicate, move and delete where the list is (HIG Lists and tables),
  /// not three screens down. Delete always confirms: there is no undo.
  private func routineRow(_ routine: Routine, position: Int, ids: [String], full: Bool)
    -> some View
  {
    NavigationLink(value: TrainingRoute.routine(routine.id)) {
      RoutinePlanRow(routine: routine)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      // No destructive role: that role removes the row before the confirmation.
      Button("Delete", systemImage: "trash") { pendingDelete = routine }
        .tint(FormaTheme.error)
    }
    .contextMenu {
      Button("Edit", systemImage: "pencil") { editing = routine }
      Button("Duplicate", systemImage: "plus.square.on.square") {
        Task { await duplicate(routine) }
      }
      .disabled(full)
      if position > 0 {
        Button("Move up", systemImage: "arrow.up") { Task { await move(position, by: -1, in: ids) } }
      }
      if position < ids.count - 1 {
        Button("Move down", systemImage: "arrow.down") {
          Task { await move(position, by: 1, in: ids) }
        }
      }
      Divider()
      Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = routine }
    }
    .accessibilityAction(named: "Edit") { editing = routine }
    .accessibilityAction(named: "Move up") { Task { await move(position, by: -1, in: ids) } }
    .accessibilityAction(named: "Move down") { Task { await move(position, by: 1, in: ids) } }
  }

  private func createButton(full: Bool) -> some View {
    Button {
      creating = true
    } label: {
      Label("Create a routine", systemImage: "plus")
        .frame(minHeight: 44)
    }
    .disabled(model.busy || full)
    .accessibilityIdentifier("create-routine")
  }

  private func delete(_ routine: Routine) {
    let id = routine.id
    Task { await model.commit { workspace in workspace.routines.removeAll { $0.id == id } } }
  }

  private func duplicate(_ routine: Routine) async {
    let copy = RoutineDraftRules.duplicate(routine)
    let saved = await model.commit { workspace in
      guard workspace.routines.first(where: { $0.id == routine.id }) == routine else {
        throw AppFailure("This routine changed. Reopen it before duplicating.")
      }
      guard workspace.routines.count < RoutineDraftRules.maxRoutines else {
        throw AppFailure("Your workspace already has 200 routines.")
      }
      workspace.routines.append(copy)
    }
    if saved { AccessibilityNotification.Announcement("Duplicated as \(copy.name)").post() }
  }

  private func move(_ position: Int, by offset: Int, in ids: [String]) async {
    let target = position + offset
    guard ids.indices.contains(position), ids.indices.contains(target) else { return }
    var reordered = ids
    reordered.swapAt(position, target)
    await reorder(reordered)
  }

  /// Same contract as the web's `reorderRoutines`: the workspace order is the
  /// order every client shows, and archived routines keep their slots.
  private func reorder(_ ids: [String]) async {
    await model.commit { workspace in
      guard let next = RoutineDraftRules.reorder(workspace.routines, visibleIDs: ids) else {
        throw AppFailure("Your routines changed. Try moving it again.")
      }
      workspace.routines = next
    }
  }
}

/// Own view so the catalogue count is recomputed only when the catalogue
/// changes, not on every workspace commit that re-renders `PlanView`.
private struct ExerciseLibraryLink: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    // Lazy count: no 1,700-element array copy just to read `count`.
    let movementCount = model.catalog.lazy.filter(\.selectable).count
    NavigationLink(value: TrainingRoute.exerciseLibrary) {
      Label {
        VStack(alignment: .leading, spacing: 4) {
          Text("Exercise library").font(.headline)
          Text("\(exerciseCount(movementCount)), each with a technique guide.")
            .font(.footnote).foregroundStyle(FormaTheme.secondary)
        }
      } icon: {
        Image(systemName: "figure.strengthtraining.traditional")
          .foregroundStyle(FormaTheme.accent).frame(width: 32)
      }
      .padding(.vertical, 8)
    }
  }
}

/// Press feedback for tappable cards and rows outside a List (a List row keeps
/// the system highlight): a 0.98 scale at full motion, opacity alone at minimal
/// and off. Leaves the label's own colours and layout alone, unlike `.plain`
/// which gives no feedback at all.
struct PressableCardStyle: ButtonStyle {
  @Environment(\.formaMotion) private var motion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.85 : 1)
      .scaleEffect(configuration.isPressed && motion.allowsSpatialMotion ? 0.98 : 1)
      .animation(motion.animation(FormaMotion.press), value: configuration.isPressed)
  }
}

private struct RoutinePlanRow: View {
  @Environment(\.dynamicTypeSize) private var textSize
  let routine: Routine
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      // The website's routine photo; dropped at accessibility sizes so the
      // text keeps the full row.
      if !textSize.isAccessibilitySize,
        let photo = ExerciseMediaLibrary.shared.routinePhoto(routine.image)
      {
        MediaPhoto(photo: photo)
          .frame(width: 64, height: 84)
          .clipShape(RoundedRectangle(cornerRadius: FormaRadius.field))
      }
      details
    }
    .padding(.vertical, 10)
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(routine.name).font(.title3.bold()).foregroundStyle(FormaTheme.primary)
      if !routine.description.isEmpty {
        Text(routine.description).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          .lineLimit(2)
      }
      Label(
        "\(exerciseCount(routine.exercises.count)) · \(routine.minutes) min",
        systemImage: "square.stack.3d.up"
      )
      .font(.caption).foregroundStyle(FormaTheme.accent)
    }
  }
}

struct RoutineDetailView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  private let routineID: String
  @State private var editing: Routine?
  @State private var confirmingDelete = false
  /// True from a confirmed delete until the pop, so the screen does not flash
  /// "This routine was removed" in between.
  @State private var removing = false
  /// True while `requestStart` waits on the Watch check or the first save, so
  /// the tap is acknowledged at once.
  @State private var starting = false
  private var current: Routine? { model.workspace?.routines.first { $0.id == routineID } }

  init(routine: Routine) {
    routineID = routine.id
  }

  init(routineID: String) {
    self.routineID = routineID
  }

  var body: some View {
    let current = self.current
    Group {
      if let current {
        List {
          Section {
            header(current)
              .padding(.vertical, 8)
              .listRowBackground(Color.clear)
              .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
          }
          // Start is its own row: a tap on the photo or the text never starts
          // a workout.
          Section {
            startButton(current)
              .listRowBackground(Color.clear)
              .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
          }
          Section("Exercise by exercise") {
            ForEach(Array(current.exercises.enumerated()), id: \.element.id) { index, entry in
              exerciseRow(index: index, entry: entry)
            }
          }
          Section {
            Button("Edit routine") { editing = current }.frame(minHeight: 44)
              .accessibilityIdentifier("edit-routine")
            Button("Delete routine", role: .destructive) { confirmingDelete = true }
              .frame(minHeight: 44).disabled(model.busy)
          } footer: {
            Text(
              "Editing or deleting a routine leaves your active workout and completed history intact."
            )
          }
        }
      } else if removing {
        Color.clear
      } else {
        ContentUnavailableView(
          "This routine was removed", systemImage: "square.stack",
          description: Text("Your completed workouts are still in Progress."))
      }
    }
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .navigationTitle(current?.name ?? "Routine")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editing) { routine in
      NavigationStack { RoutineEditorView(routine: routine) }.protectWidgetNavigation()
    }
    .confirmationDialog(
      "Delete this routine?", isPresented: $confirmingDelete, titleVisibility: .visible
    ) {
      Button("Delete routine", role: .destructive) {
        removing = true
        Task {
          if await model.commit({ value in value.routines.removeAll { $0.id == routineID } }) {
            dismiss()
          } else {
            removing = false
          }
        }
      }
    } message: {
      Text("This removes the plan only. Active and completed workouts will be kept.")
    }
  }

  private func header(_ current: Routine) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      if let photo = ExerciseMediaLibrary.shared.routinePhoto(current.image) {
        // The web's routine cover.
        MediaPhoto(photo: photo).frame(height: 180)
          .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card))
      }
      // Capped so a long name at the largest sizes leaves room for the
      // session below it; the body text keeps scaling.
      EditorialTitle(text: current.name)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
      if !current.description.isEmpty {
        Text(current.description).foregroundStyle(FormaTheme.secondary)
      }
      Text("\(current.minutes) min · \(current.level)").font(.subheadline)
        .foregroundStyle(FormaTheme.secondary)
    }
  }

  private func startButton(_ current: Routine) -> some View {
    let startTitle = model.workspace?.active == nil ? "Start workout" : "Resume active workout"
    return Button {
      starting = true
      Task {
        await model.requestStart(current)
        starting = false
      }
    } label: {
      HStack(spacing: 10) {
        if starting { ProgressView().tint(FormaTheme.ink) }
        Text(startTitle)
      }
    }
    .buttonStyle(PrimaryButtonStyle())
    .disabled(model.busy || starting)
    .accessibilityLabel(startTitle)
    .accessibilityValue(starting ? "Starting" : "")
    .accessibilityIdentifier("start-routine-workout")
  }

  /// One row per entry, always: an exercise missing from the catalogue shows
  /// as unavailable instead of vanishing while it still counts.
  @ViewBuilder
  private func exerciseRow(index: Int, entry: Prescription) -> some View {
    let number = Text(String(format: "%02d", index + 1))
      .font(FormaFont.numeral(.title3, weight: .semibold))
      .foregroundStyle(FormaTheme.accent)
      .accessibilityHidden(true)
    if let exercise = model.exercise(entry.exerciseId) {
      NavigationLink(value: TrainingRoute.guide(exercise.id)) {
        HStack(alignment: .top, spacing: 14) {
          number
          VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name).font(.headline)
            Text(PrescriptionText.summary(entry, exercise: exercise))
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            if let note = entry.note, !note.isEmpty {
              Text(note).font(.footnote).foregroundStyle(FormaTheme.secondary)
            }
            if entry.groupId != nil {
              Label("Superset", systemImage: "link").font(.caption)
                .foregroundStyle(FormaTheme.accent)
            }
          }
        }
        .padding(.vertical, 8)
      }
    } else {
      HStack(alignment: .top, spacing: 14) {
        number
        UnavailableExerciseText(entry: entry, advice: "Edit the routine to remove it.")
      }
      .padding(.vertical, 8)
    }
  }
}

/// An entry whose exercise is not in this build's catalogue.
private struct UnavailableExerciseText: View {
  let entry: Prescription
  let advice: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Unavailable exercise").font(.headline).foregroundStyle(FormaTheme.primary)
      Text("This app doesn't include \u{201C}\(entry.exerciseId)\u{201D}. \(advice)")
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

/// A removal or a superset unlink the editor can put back. Shown only while
/// the exercise list is still exactly what the change left.
private struct EditorUndo {
  let message: String
  let before: [Prescription]
  let after: [Prescription]
  let removedDrafts: [String: TargetInputDraft]
}

private struct RoutineEditorView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.formaMotion) private var motion
  let original: Routine?
  @State private var draft: Routine
  /// What the draft started as. Cancel and swipe-down compare against it, so
  /// an untouched new routine closes without asking to discard anything.
  @State private var baseline: Routine
  @State private var choosingExercise = false
  @State private var failure: String?
  /// The failure is a save conflict, so it offers Replace and Discard.
  @State private var conflict = false
  @State private var confirmingDiscard = false
  @State private var targetDrafts: [String: TargetInputDraft] = [:]
  @State private var lastChange: EditorUndo?

  private static let failureID = "routine-editor-failure"

  init(routine: Routine?) {
    original = routine
    let start = routine ?? Routine(name: "My routine")
    _draft = State(initialValue: start)
    _baseline = State(initialValue: start)
  }

  private var changed: Bool { !targetDrafts.isEmpty || draft != baseline }

  private var issues: RoutineDraftIssues {
    let target = targetDrafts.keys.sorted().compactMap { targetDrafts[$0] }
      .first { $0.error != nil }
    return RoutineDraftRules.issues(
      for: draft,
      targetError: target.flatMap { draft in draft.error.map { "\(draft.context): \($0)" } },
      metric: { model.exercise($0)?.metric })
  }

  var body: some View {
    // `issues` walks the whole draft (and sorts the target drafts); the body
    // and the toolbar both need it, so evaluate it once per render.
    let issues = self.issues
    ScrollViewReader { proxy in
      Form {
        if let failure { failureSection(failure) }
        detailsSection(issues.details)
        exercisesSection(issues.exercises)
      }
      .onChange(of: failure) { _, message in
        guard let message else { return }
        AccessibilityNotification.Announcement(message).post()
        withFormaAnimation(motion, FormaMotion.navigation) {
          proxy.scrollTo(Self.failureID, anchor: .top)
        }
      }
    }
    .disabled(model.busy)
    .navigationTitle(original == nil ? "New routine" : "Edit routine")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          if changed { confirmingDiscard = true } else { dismiss() }
        }
        .disabled(model.busy)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(model.busy ? "Saving…" : "Save") { Task { await save() } }
          .modifier(ProminentConfirmation())
          .disabled(model.busy || issues.first != nil)
          .accessibilityHint(issues.first ?? "")
          .accessibilityIdentifier("save-routine")
      }
    }
    .interactiveDismissDisabled(changed || model.busy)
    .background {
      // A refused swipe-down asks, as Cancel does (HIG Sheets).
      SheetDismissAttemptObserver {
        if changed && !model.busy { confirmingDiscard = true }
      }
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
    }
    .confirmationDialog(
      "Discard your routine changes?", isPresented: $confirmingDiscard, titleVisibility: .visible
    ) {
      Button("Discard changes", role: .destructive) { dismiss() }
    }
    .navigationDestination(isPresented: $choosingExercise) {
      ExerciseLibraryView(
        onSelect: { exercise in
          guard draft.exercises.count < RoutineDraftRules.maxExercises else { return false }
          let defaults = exercise.defaults
          draft.exercises.append(
            Prescription(
              exerciseId: exercise.id, entryId: UUID().uuidString,
              sets: defaults.sets, reps: defaults.reps, weight: defaults.weight,
              durationSeconds: defaults.durationSeconds, distanceMeters: defaults.distanceMeters,
              perSide: defaults.perSide
            ))
          // The picker stays open so several exercises can be added in one visit.
          return true
        },
        canAdd: { draft.exercises.count < RoutineDraftRules.maxExercises })
    }
  }

  private func failureSection(_ message: String) -> some View {
    Section {
      Label {
        Text(message).foregroundStyle(FormaTheme.primary)
          .accessibilityIdentifier("routine-save-error")
      } icon: {
        Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
      }
      if conflict {
        Button("Replace with my version") { Task { await save(replacing: true) } }
          .frame(minHeight: 44)
        Button("Discard my changes", role: .destructive) { dismiss() }
          .frame(minHeight: 44)
      }
    }
    .id(Self.failureID)
  }

  private func detailsSection(_ issue: String?) -> some View {
    Section {
      LabeledField("Name") {
        TextField("Routine name", text: $draft.name).accessibilityLabel("Routine name")
          .accessibilityIdentifier("routine-name")
      }
      LabeledField("Description") {
        TextField("What is this session for?", text: $draft.description, axis: .vertical)
          .lineLimit(2...5).accessibilityLabel("Routine description")
          .accessibilityIdentifier("routine-description")
      }
      Stepper {
        Text("Estimated time: \(draft.minutes) min")
      } onIncrement: {
        draft.minutes = RoutineDraftRules.steppedMinutes(draft.minutes, up: true)
      } onDecrement: {
        draft.minutes = RoutineDraftRules.steppedMinutes(draft.minutes, up: false)
      }
    } header: {
      Text("Make it yours")
    } footer: {
      if let issue { IssueText(issue, identifier: "routine-details-issue") }
    }
  }

  private func exercisesSection(_ issue: String?) -> some View {
    Section {
      ForEach($draft.exercises) { $entry in
        editorRow($entry)
      }
      .onMove { source, destination in
        let before = draft.exercises
        draft.exercises.move(fromOffsets: source, toOffset: destination)
        noteUnlink(before: before)
      }
      .onDelete { offsets in remove(at: offsets) }
      Button {
        choosingExercise = true
      } label: {
        Label("Add exercise", systemImage: "plus").frame(minHeight: 44)
      }
      .disabled(draft.exercises.count >= RoutineDraftRules.maxExercises)
      if let lastChange, lastChange.after == draft.exercises {
        HStack {
          Text(lastChange.message).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          Spacer(minLength: 8)
          Button("Undo") { undo(lastChange) }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint(lastChange.message)
        }
      }
    } header: {
      HStack {
        Text("Exercises · \(draft.exercises.count)/100")
        Spacer()
        EditButton().textCase(nil)
          .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
      }
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        if let issue { IssueText(issue, identifier: "routine-exercises-issue") }
        Text(
          "Tap an exercise to set its targets. Touch and hold it, or use Edit, to move or remove it. Moving a superset apart unlinks it."
        )
      }
    }
  }

  /// Exactly one row per entry, so the section builds lazily and every entry,
  /// even one missing from the catalogue, can be moved or removed.
  private func editorRow(_ entry: Binding<Prescription>) -> some View {
    let value = entry.wrappedValue
    let position = draft.exercises.firstIndex { $0.id == value.id } ?? 0
    let name = model.exercise(value.exerciseId)?.name ?? "Unavailable exercise"
    return Group {
      if let exercise = model.exercise(value.exerciseId) {
        NavigationLink {
          PrescriptionEditor(entry: entry, exercise: exercise, targetDrafts: $targetDrafts)
        } label: {
          RoutineEditorRow(entry: value, exercise: exercise)
        }
      } else {
        UnavailableExerciseText(entry: value, advice: "Swipe or touch and hold to remove it.")
          .padding(.vertical, 6)
      }
    }
    .contextMenu {
      if position > 0 {
        Button("Move up", systemImage: "arrow.up") { move(value.id, name: name, by: -1) }
      }
      if position < draft.exercises.count - 1 {
        Button("Move down", systemImage: "arrow.down") { move(value.id, name: name, by: 1) }
      }
      Button("Remove", systemImage: "minus.circle", role: .destructive) {
        remove(at: IndexSet(integer: position))
      }
    }
    .accessibilityAction(named: "Move up") { move(value.id, name: name, by: -1) }
    .accessibilityAction(named: "Move down") { move(value.id, name: name, by: 1) }
    .accessibilityAction(named: "Remove") { remove(at: IndexSet(integer: position)) }
  }

  private func move(_ id: String, name: String, by offset: Int) {
    let before = draft.exercises
    guard RoutineDraftRules.move(&draft.exercises, id: id, by: offset),
      let position = draft.exercises.firstIndex(where: { $0.id == id })
    else { return }
    let unlinked = noteUnlink(before: before)
    if !unlinked {
      AccessibilityNotification.Announcement(
        "\(name), position \(position + 1) of \(draft.exercises.count)"
      ).post()
    }
  }

  /// After a move: unlinks any split superset and, if one was, says so and
  /// offers Undo.
  @discardableResult
  private func noteUnlink(before: [Prescription]) -> Bool {
    guard RoutineDraftRules.preserveValidGroups(&draft.exercises) else { return false }
    let message = "Superset unlinked."
    lastChange = EditorUndo(message: message, before: before, after: draft.exercises, removedDrafts: [:])
    AccessibilityNotification.Announcement(message).post()
    return true
  }

  private func remove(at offsets: IndexSet) {
    let before = draft.exercises
    let names = offsets.map { model.exercise(before[$0].exerciseId)?.name ?? "an exercise" }
    let removed = Set(offsets.map { before[$0].id })
    draft.exercises.remove(atOffsets: offsets)
    // Saved entry IDs may contain "|". Remove only that exact row's fields,
    // keeping another row's invalid input and validation intact.
    let isRemoved: (String) -> Bool = { key in
      guard let separator = key.lastIndex(of: "|") else { return false }
      return removed.contains(String(key[..<separator]))
    }
    let removedDrafts = targetDrafts.filter { isRemoved($0.key) }
    targetDrafts = targetDrafts.filter { !isRemoved($0.key) }
    let unlinked = RoutineDraftRules.preserveValidGroups(&draft.exercises)
    var message = names.count == 1 ? "Removed \(names[0])." : "Removed \(names.count) exercises."
    if unlinked { message += " Superset unlinked." }
    lastChange = EditorUndo(
      message: message, before: before, after: draft.exercises, removedDrafts: removedDrafts)
    AccessibilityNotification.Announcement(message).post()
  }

  private func undo(_ change: EditorUndo) {
    draft.exercises = change.before
    targetDrafts.merge(change.removedDrafts) { current, _ in current }
    lastChange = nil
    AccessibilityNotification.Announcement("Undone.").post()
  }

  private func save(replacing: Bool = false) async {
    guard !model.busy else { return }
    if let issue = issues.first {
      failure = issue
      return
    }
    var candidate = draft
    candidate.name = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
    var conflicted = false
    let saved = await model.commit { workspace in
      if let original {
        let index = workspace.routines.firstIndex { $0.id == original.id }
        if let index, replacing || workspace.routines[index] == original {
          workspace.routines[index] = candidate
        } else if replacing {
          // Deleted elsewhere: keeping my version puts it back.
          guard workspace.routines.count < RoutineDraftRules.maxRoutines else {
            throw AppFailure("Your workspace already has 200 routines.")
          }
          workspace.routines.append(candidate)
        } else {
          conflicted = true
          throw AppFailure("This routine changed while you were editing.")
        }
      } else {
        guard workspace.routines.count < RoutineDraftRules.maxRoutines else {
          throw AppFailure("Your workspace already has 200 routines.")
        }
        workspace.routines.append(candidate)
      }
    }
    if saved {
      dismiss()
      return
    }
    conflict = conflicted
    failure =
      conflicted
      ? "This routine changed on another screen or device while you were editing. Replace it with your version, or discard your changes."
      : model.errorMessage ?? "Your routine has not been saved. Keep your draft open and try again."
    // Shown inline above; the root alert can't present over this sheet and
    // would otherwise replay the same error after it closes.
    model.errorMessage = nil
  }
}

/// A caption that stays above a text field once its placeholder is gone (HIG
/// Text fields). The field keeps its own accessibility label.
private struct LabeledField<Field: View>: View {
  let title: String
  let field: Field

  init(_ title: String, @ViewBuilder field: () -> Field) {
    self.title = title
    self.field = field()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(FormaTheme.secondary)
        .accessibilityHidden(true)
      field
    }
    .padding(.vertical, 2)
  }
}

/// A validation message under the section it is about. Primary text with an
/// error-coloured icon, so colour is not the only signal.
private struct IssueText: View {
  let message: String
  let identifier: String

  init(_ message: String, identifier: String) {
    self.message = message
    self.identifier = identifier
  }

  var body: some View {
    Label {
      Text(message).foregroundStyle(FormaTheme.primary)
    } icon: {
      Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
    }
    .accessibilityIdentifier(identifier)
  }
}

/// Row label for the editor list. Its inputs are Equatable values, so typing in
/// the name or description fields (which re-renders the editor) skips rebuilding
/// the prescription summary for every unchanged exercise row.
private struct RoutineEditorRow: View {
  let entry: Prescription
  let exercise: Exercise

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(exercise.name).font(.headline)
      Text(PrescriptionText.summary(entry, exercise: exercise))
        .font(.caption).foregroundStyle(FormaTheme.secondary)
      if entry.groupId != nil {
        Label("Superset", systemImage: "link").font(.caption)
          .foregroundStyle(FormaTheme.accent)
      }
    }
    .padding(.vertical, 6)
  }
}

private struct TargetInputDraft {
  var text: String
  var context: String
  var error: String?
}

// MARK: - Target number parsing
// Foundation's formatted numeric parser can accept only a valid prefix of an
// invalid string. Consume every character before creating a canonical value.
private typealias TargetNumberInput = MeasurementNumberInput
// MARK: - Target number field

private struct TargetNumberField: View {
  @Environment(\.locale) private var locale
  let title: String
  let unit: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let fieldKey: String
  let context: String
  @Binding var drafts: [String: TargetInputDraft]
  let focus: FocusState<String?>.Binding

  private var input: Binding<String> {
    Binding(
      get: { drafts[fieldKey]?.text ?? TargetNumberInput.display(value, locale: locale) },
      set: { text in
        let error: String?
        if let number = TargetNumberInput.parse(text, locale: locale) {
          if range.contains(number) {
            value = number
            error = nil
          } else {
            error =
              "Use a value from \(range.lowerBound.formatted()) to \(range.upperBound.formatted()) \(unit)."
          }
        } else {
          error =
            "Enter a valid \(title.lowercased()). Use a decimal point or comma without thousands separators."
        }
        // The routine editor owns drafts so an invalid edit survives Back.
        drafts[fieldKey] = TargetInputDraft(text: text, context: context, error: error)
      }
    )
  }

  var body: some View {
    let error = drafts[fieldKey]?.error
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.subheadline)
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        TextField(title, text: input)
          .keyboardType(.decimalPad)
          .font(.title3.monospacedDigit())
          .multilineTextAlignment(.trailing)
          .frame(minHeight: 44)
          .focused(focus, equals: fieldKey)
          .accessibilityLabel("\(title), \(unit)")
          // The error is read with the field when focus lands on it, not
          // announced on every keystroke.
          .accessibilityValue(error.map { "\(input.wrappedValue). Invalid. \($0)" } ?? input.wrappedValue)
          .accessibilityIdentifier("routine-target-\(fieldKey)")
        Text(unit).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          .accessibilityHidden(true)
      }
      if let error {
        Label {
          Text(error).foregroundStyle(FormaTheme.primary)
        } icon: {
          Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
        }
        .font(.footnote)
        .accessibilityHidden(true)
        .accessibilityIdentifier("routine-target-error-\(fieldKey)")
      }
    }
    .padding(.vertical, 4)
  }
}

private struct PrescriptionEditor: View {
  @Environment(AppModel.self) private var model
  @Binding var entry: Prescription
  let exercise: Exercise
  @Binding var targetDrafts: [String: TargetInputDraft]
  @FocusState private var focusedTarget: String?
  private var usesReps: Bool { exercise.metric == "load_reps" }
  private var usesTime: Bool { ["duration", "duration_distance"].contains(exercise.metric) }
  private var usesDistance: Bool {
    ["load_distance", "duration_distance"].contains(exercise.metric)
  }
  private var showsLoad: Bool { exercise.loadType != "none" || entry.weight > 0 }

  var body: some View {
    Form {
      Section {
        NavigationLink {
          GuideView(exercise: exercise)
        } label: {
          Label("Technique & source", systemImage: "book")
        }
      } header: {
        Text(exercise.name)
      } footer: {
        Text("\(exercise.muscle) · \(exercise.equipment)")
      }
      targetsSection
      cuesSection
    }
    .disabled(model.busy)
    .navigationTitle("Exercise targets")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedTarget = nil }
      }
    }
  }

  private var targetsSection: some View {
    Section {
      Stepper("Sets: \(entry.sets)", value: $entry.sets, in: 1...12)
      if showsLoad {
        TargetNumberField(
          title: exercise.loadType == "added" ? "Added load" : "Weight",
          unit: "kg", value: $entry.weight, range: 0...1000,
          fieldKey: "\(entry.id)|weight", context: exercise.name,
          drafts: $targetDrafts, focus: $focusedTarget)
      }
      if usesReps { repsTargets }
      if usesTime {
        TargetNumberField(
          title: "Duration", unit: "seconds",
          value: Binding(
            get: { entry.durationSeconds ?? 60 }, set: { entry.durationSeconds = $0 }),
          range: 1...86400, fieldKey: "\(entry.id)|durationSeconds", context: exercise.name,
          drafts: $targetDrafts, focus: $focusedTarget)
      }
      if usesDistance {
        TargetNumberField(
          title: "Distance", unit: "metres",
          value: Binding(
            get: { entry.distanceMeters ?? 100 }, set: { entry.distanceMeters = $0 }),
          range: 1...1_000_000, fieldKey: "\(entry.id)|distanceMeters", context: exercise.name,
          drafts: $targetDrafts, focus: $focusedTarget)
      }
    } header: {
      Text("Targets")
    } footer: {
      Text("Enter a number directly. Use a decimal point or comma, without thousands separators.")
    }
  }

  @ViewBuilder
  private var repsTargets: some View {
    Stepper(
      entry.perSide ? "Reps per side: \(entry.reps)" : "Reps: \(entry.reps)",
      value: $entry.reps, in: 1...max(entry.reps, entry.perSide ? 50 : 100)
    )
    .onChange(of: entry.reps) { _, value in
      if let max = entry.repsMax, max < value { entry.repsMax = value }
    }
    Toggle("Reps per side", isOn: $entry.perSide)
      .onChange(of: entry.perSide) { _, perSide in
        if perSide {
          entry.reps = min(entry.reps, 50)
          if let max = entry.repsMax { entry.repsMax = min(max, 50) }
        }
      }
    Toggle(
      "Use a rep range",
      isOn: Binding(
        get: { entry.repsMax != nil }, set: { entry.repsMax = $0 ? entry.reps : nil }))
    if entry.repsMax != nil {
      Stepper(
        "Maximum reps: \(entry.repsMax ?? entry.reps)",
        value: Binding(get: { entry.repsMax ?? entry.reps }, set: { entry.repsMax = $0 }),
        in: entry.reps...max(entry.reps, entry.repsMax ?? 0, entry.perSide ? 50 : 100))
    }
    if entry.perSide && (entry.reps > 50 || (entry.repsMax ?? 0) > 50) {
      Text("Reduce this target to 50 reps per side or fewer before saving.")
        .font(.footnote).foregroundStyle(FormaTheme.error)
    }
    if exercise.id == "plank" {
      Text("For Forearm plank, each rep counts as a 10-second hold.")
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
    }
  }

  private var cuesSection: some View {
    let cueLength = entry.note?.utf16.count ?? 0
    return Section {
      Toggle(
        "Set a target RPE",
        isOn: Binding(get: { entry.rpe != nil }, set: { entry.rpe = $0 ? 7 : nil }))
      if entry.rpe != nil {
        Stepper(
          "Target RPE: \((entry.rpe ?? 7).formatted()) / 10",
          value: Binding(get: { entry.rpe ?? 7 }, set: { entry.rpe = $0 }), in: 1...10, step: 0.5)
      }
      Toggle(
        "Custom rest",
        isOn: Binding(
          get: { entry.restSeconds != nil }, set: { entry.restSeconds = $0 ? 90 : nil }))
      if entry.restSeconds != nil {
        Stepper(
          "Rest: \(entry.restSeconds ?? 90) sec",
          value: Binding(get: { entry.restSeconds ?? 90 }, set: { entry.restSeconds = $0 }),
          in: 10...600, step: 5)
      }
      LabeledField("Cue") {
        TextField(
          "A cue for your next session",
          text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }),
          axis: .vertical
        )
        .lineLimit(2...4).accessibilityLabel("Exercise cue, up to 140 characters")
        Text("\(cueLength)/\(RoutineDraftRules.maxCueLength)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(
            cueLength > RoutineDraftRules.maxCueLength ? FormaTheme.error : FormaTheme.secondary
          )
          .frame(maxWidth: .infinity, alignment: .trailing)
          .accessibilityLabel("\(cueLength) of 140 characters")
      }
      if cueLength > RoutineDraftRules.maxCueLength {
        Text("Shorten this cue to 140 characters before saving the routine.").foregroundStyle(
          FormaTheme.error)
      }
    } header: {
      Text("Training cues")
    } footer: {
      Text(
        "RPE is your perceived effort from 1 to 10. Leave it off when you don't need a target.")
    }
  }
}

/// Catalogue facts the library screen needs, built once instead of on every
/// keystroke (filtering 1,700 rows and sorting two Sets per render).
private struct LibraryIndex: Sendable {
  let exercises: [Exercise]
  let muscles: [String]
  let equipmentTypes: [String]
  /// Size of the catalogue this was built from, to detect a reload.
  let catalogCount: Int

  init(catalog: [Exercise]) {
    catalogCount = catalog.count
    let selectable = catalog.filter(\.selectable)
    exercises = selectable
    muscles = Set(selectable.map(\.muscle)).sorted()
    equipmentTypes = Set(selectable.map(\.equipment)).sorted()
  }
}

/// Text-search hits over the whole selectable catalogue for one query.
/// Muscle and equipment filters are applied on top, so changing them never
/// re-runs the text search.
private struct SearchHits: Sendable {
  let query: String
  let exercises: [Exercise]
}

struct ExerciseLibraryView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @Environment(\.dynamicTypeSize) private var textSize
  /// Picker mode: choosing an exercise calls this, which returns whether it was
  /// added. The screen stays open, so several can be added in one visit; Back
  /// returns to the routine.
  var onSelect: ((Exercise) -> Bool)? = nil
  /// Picker mode: false once the routine holds its 100 exercises, which
  /// disables every add button and shows why.
  var canAdd: () -> Bool = { true }
  /// How many times each exercise was added during this visit to the picker.
  @State private var added: [String: Int] = [:]
  @State private var guideExercise: Exercise?
  @State private var query = ""
  @State private var muscle = Self.allMuscles
  @State private var equipment = Self.allEquipment
  @State private var index: LibraryIndex?
  @State private var hits: SearchHits?

  private static let allMuscles = "All muscles"
  private static let allEquipment = "All equipment"

  /// Same rule as `Exercise.matches(query:)`: a query with no words matches all.
  private var hasSearchWords: Bool { query.contains { !$0.isWhitespace } }
  private var filtersActive: Bool { muscle != Self.allMuscles || equipment != Self.allEquipment }

  private func visibleExercises(
    in index: LibraryIndex, muscle: String? = nil, equipment: String? = nil
  ) -> [Exercise] {
    let muscle = muscle ?? self.muscle
    let equipment = equipment ?? self.equipment
    // While a search is debouncing or running off the main thread, keep showing
    // the previous hits (already narrowed by the current filters) instead of
    // blocking the keystroke on 1,700 Unicode folds.
    let base = hasSearchWords ? (hits?.exercises ?? index.exercises) : index.exercises
    guard muscle != Self.allMuscles || equipment != Self.allEquipment else { return base }
    return base.filter { exercise in
      (muscle == Self.allMuscles || muscle == exercise.muscle)
        && (equipment == Self.allEquipment || equipment == exercise.equipment)
    }
  }

  var body: some View {
    let index = self.index ?? LibraryIndex(catalog: model.catalog)
    let matches = visibleExercises(in: index)
    let full = onSelect != nil && !canAdd()
    List {
      filterSection(index)
      Section {
        if matches.isEmpty { emptyState(index) }
        ForEach(matches) { exercise in
          if let onSelect {
            pickerRow(exercise, onSelect: onSelect, full: full)
          } else {
            NavigationLink(value: TrainingRoute.guide(exercise.id)) {
              ExerciseLibraryRow(exercise: exercise)
            }
          }
        }
      } header: {
        Text(resultsHeader(matches.count)).contentTransition(.numericText())
      }
    }
    .searchable(
      text: $query, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Name, muscle or equipment"
    )
    // Typed queries never animate: results arrive after a debounce while the
    // person is still typing, and moving rows under the keyboard would be both
    // janky and distracting. Filter changes animate only when few rows move
    // (`applyFilters`).
    .safeAreaInset(edge: .top, spacing: 0) {
      if full { limitBanner }
    }
    .accessibilityIdentifier(onSelect == nil ? "exercise-library" : "exercise-picker")
    .navigationTitle(onSelect == nil ? "Exercise library" : "Add exercise")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(
      isPresented: Binding(get: { guideExercise != nil }, set: { if !$0 { guideExercise = nil } })
    ) {
      if let guideExercise { GuideView(exercise: guideExercise) }
    }
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .task(id: model.catalog.count) {
      // `.task` restarts whenever the screen reappears (e.g. back from a guide);
      // keep the index and hits unless the catalogue actually changed.
      guard self.index?.catalogCount != model.catalog.count else { return }
      self.index = LibraryIndex(catalog: model.catalog)
      hits = nil
    }
    .task(id: query) { await refreshHits() }
  }

  private func resultsHeader(_ count: Int) -> String {
    let total = added.values.reduce(0, +)
    guard onSelect != nil, total > 0 else { return exerciseCount(count) }
    return "\(exerciseCount(count)) · \(total) added"
  }

  /// Pinned under the search field, so it is in view wherever the list is
  /// scrolled when the routine fills up.
  private var limitBanner: some View {
    Label {
      Text("This routine has 100 exercises. Remove one before adding another.")
        .foregroundStyle(FormaTheme.primary)
    } icon: {
      Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
    }
    .font(.footnote)
    .padding(.horizontal, FormaSpacing.md).padding(.vertical, FormaSpacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(FormaTheme.surface)
    .overlay(alignment: .bottom) { Rectangle().fill(FormaTheme.line).frame(height: 1) }
    .accessibilityIdentifier("exercise-picker-full")
  }

  @ViewBuilder
  private func emptyState(_ index: LibraryIndex) -> some View {
    if hasSearchWords && !filtersActive {
      ContentUnavailableView.search(text: query)
    } else {
      ContentUnavailableView {
        Label(
          hasSearchWords ? "No exercises match this search and these filters" : "No exercises match these filters",
          systemImage: "line.3.horizontal.decrease.circle")
      } description: {
        Text("Try another muscle or equipment type.")
      } actions: {
        Button("Clear filters") {
          applyFilters(muscle: Self.allMuscles, equipment: Self.allEquipment, in: index)
        }
      }
    }
  }

  // Rows and filters are their own functions so the list body type-checks
  // quickly on the CI toolchain.
  private func filterSection(_ index: LibraryIndex) -> some View {
    Section {
      Picker(
        "Muscle",
        selection: Binding(
          get: { muscle },
          set: { applyFilters(muscle: $0, equipment: equipment, in: index) })
      ) {
        Text(Self.allMuscles).tag(Self.allMuscles)
        ForEach(index.muscles, id: \.self) { Text($0).tag($0) }
      }
      Picker(
        "Equipment",
        selection: Binding(
          get: { equipment },
          set: { applyFilters(muscle: muscle, equipment: $0, in: index) })
      ) {
        Text(Self.allEquipment).tag(Self.allEquipment)
        ForEach(index.equipmentTypes, id: \.self) { Text($0).tag($0) }
      }
      if filtersActive || !query.isEmpty {
        Button("Clear search & filters") {
          query = ""
          applyFilters(muscle: Self.allMuscles, equipment: Self.allEquipment, in: index)
        }
        .frame(minHeight: 44)
      }
    }
  }

  /// Animates a filter change only when few rows move: a 1,400-row batch
  /// update has no spatial meaning and can drop frames.
  private func applyFilters(muscle newMuscle: String, equipment newEquipment: String, in index: LibraryIndex) {
    guard newMuscle != muscle || newEquipment != equipment else { return }
    let before = visibleExercises(in: index).map(\.id)
    let after = visibleExercises(in: index, muscle: newMuscle, equipment: newEquipment).map(\.id)
    let apply = {
      muscle = newMuscle
      equipment = newEquipment
    }
    if LibraryFilterMotion.animates(from: before, to: after) {
      withFormaAnimation(motion, FormaMotion.reveal, apply)
    } else {
      apply()
    }
  }

  /// The whole row adds; the technique guide is the trailing control. At
  /// accessibility sizes the row stacks so the name keeps the full width.
  private func pickerRow(
    _ exercise: Exercise, onSelect: @escaping (Exercise) -> Bool, full: Bool
  ) -> some View {
    let stacked = textSize.isAccessibilitySize
    let layout =
      stacked
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(alignment: .center, spacing: 4))
    return layout {
      Button {
        add(exercise, using: onSelect)
      } label: {
        addLabel(exercise, stacked: stacked)
          .frame(minHeight: 44).contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .disabled(full)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Add \(exercise.name), \(exercise.muscle), \(exercise.equipment)")
      .accessibilityValue(
        added[exercise.id].map { $0 == 1 ? "Added" : "Added \($0) times" } ?? ""
      )
      .accessibilityHint(full ? "This routine has 100 exercises." : "Adds it to this routine.")
      Button {
        guideExercise = exercise
      } label: {
        Image(systemName: "info.circle").font(.title3)
          .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Technique guide for \(exercise.name)")
    }
  }

  @ViewBuilder
  private func addLabel(_ exercise: Exercise, stacked: Bool) -> some View {
    let status = Group {
      if let count = added[exercise.id] {
        Label(count == 1 ? "Added" : "Added \(count) times", systemImage: "checkmark")
          .font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.accent)
      } else {
        Image(systemName: "plus.circle.fill").font(.title2)
          .foregroundStyle(FormaTheme.accent)
      }
    }
    if stacked {
      VStack(alignment: .leading, spacing: 4) {
        ExerciseLibraryRow(exercise: exercise)
        status
      }
    } else {
      HStack(spacing: 12) {
        ExerciseLibraryRow(exercise: exercise)
        Spacer(minLength: 0)
        status
      }
    }
  }

  private func add(_ exercise: Exercise, using onSelect: (Exercise) -> Bool) {
    if onSelect(exercise) {
      added[exercise.id, default: 0] += 1
      let message =
        canAdd()
        ? "Added \(exercise.name)"
        : "Added \(exercise.name). This routine now has 100 exercises."
      AccessibilityNotification.Announcement(message).post()
    } else {
      // Refused, and the pinned banner says why.
      model.haptic(.warning)
      AccessibilityNotification.Announcement(
        "This routine already has 100 exercises. Remove one before adding another."
      ).post()
    }
  }

  /// Debounced, off-main text search. Results equal the former inline
  /// `filter`: same `matches(query:)`, same catalogue order.
  private func refreshHits() async {
    guard hasSearchWords else {
      if hits != nil { hits = nil }
      return
    }
    let current = query
    if hits?.query == current { return }
    // First keystroke runs immediately; follow-ups wait for a typing pause.
    if hits != nil {
      try? await Task.sleep(for: .milliseconds(120))
      if Task.isCancelled { return }
    }
    let pool = index?.exercises ?? model.selectableExercises
    let found = await Task.detached(priority: .userInitiated) {
      // Folds the query once for the whole catalogue; same hits, same order.
      Exercise.filter(pool, matching: current)
    }.value
    if Task.isCancelled { return }
    hits = SearchHits(query: current, exercises: found)
  }
}

private struct ExerciseLibraryRow: View {
  let exercise: Exercise
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(exercise.name).font(.headline).foregroundStyle(FormaTheme.primary)
      Text("\(exercise.muscle) · \(exercise.equipment)").font(.caption).foregroundStyle(
        FormaTheme.secondary)
    }
    .padding(.vertical, 8)
  }
}

struct GuideView: View {
  let exercise: Exercise
  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 14) {
          // Capped like the routine title: the guide text below keeps scaling.
          EditorialTitle(text: exercise.name)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
          Text("\(exercise.muscle) · \(exercise.equipment)").font(.subheadline).foregroundStyle(
            FormaTheme.secondary)
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.clear)
      }
      ExerciseMediaSection(exercise: exercise)
      Section("Technique") {
        if exercise.guideUnavailable
          || exercise.guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
          Text(
            "A reviewed technique guide isn't available for this saved exercise. Ask a qualified trainer for guidance before trying a movement you don't know."
          )
          .foregroundStyle(FormaTheme.secondary)
        } else {
          Text(exercise.guide).font(.body).lineSpacing(6).textSelection(.enabled)
            .padding(.vertical, 8)
        }
      }
      Section("Train with care") {
        Text(
          "Use a comfortable range of motion and a load you can control. Stop if you feel pain, dizziness or unusual discomfort. These guides are general fitness information, not medical advice."
        )
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
      }
      if let source = exercise.source {
        Section("Guide credits") {
          if let title = source.title { Text(title).font(.headline) }
          if let author = source.author, !author.isEmpty { Text("By \(author)") }
          if let url = safeWebURL(source.url) { Link("Original source", destination: url) }
          if let license = source.license {
            if let url = safeWebURL(source.licenseUrl) {
              Link(license, destination: url)
            } else {
              Text(license)
            }
          }
          if let modified = source.modified, !modified.isEmpty {
            Text(modified).font(.footnote).foregroundStyle(FormaTheme.secondary)
          }
        }
      }
      if !exercise.references.isEmpty {
        Section("Additional references") {
          ForEach(Array(exercise.references.enumerated()), id: \.offset) { _, reference in
            if let url = safeWebURL(reference.url) { Link(reference.title, destination: url) }
          }
        }
      }
    }
    .navigationTitle(exercise.name)
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
  }

  private func safeWebURL(_ text: String?) -> URL? {
    guard let text, let url = URL(string: text),
      ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil
    else { return nil }
    return url
  }
}

struct TrainingDaysView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.calendar) private var calendar

  /// Monday-first, as the workspace stores them (0 is Monday), in the
  /// person's language. `weekdaySymbols` starts on Sunday.
  private var days: [String] {
    let symbols = calendar.standaloneWeekdaySymbols
    return (0..<7).map { symbols[($0 + 1) % symbols.count] }
  }

  var body: some View {
    let days = self.days
    Form {
      Section {
        ForEach(days.indices, id: \.self) { day in
          Toggle(
            days[day],
            isOn: Binding(
              get: { model.workspace?.schedule.contains(day) ?? false },
              set: { selected in
                Task {
                  await model.commit { workspace in
                    workspace.schedule.removeAll { $0 == day }
                    if selected {
                      workspace.schedule.append(day)
                      workspace.schedule.sort()
                    }
                  }
                }
              }
            )
          )
          .disabled(model.busy)
        }
      } header: {
        Text("Make space for training")
      } footer: {
        Text(
          "A plan is a guide, not a demand. Rest or move a session when you need to. Training days don't schedule notifications."
        )
      }
      Section { LocalSaveStatus(saving: model.busy) }
    }
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .navigationTitle("Training days")
    .navigationBarTitleDisplayMode(.inline)
  }
}

enum PrescriptionText {
  static func summary(_ entry: Prescription, exercise: Exercise) -> String {
    var parts = ["\(entry.sets) ×"]
    switch exercise.metric {
    case "duration": parts.append("\((entry.durationSeconds ?? 0).formatted()) sec")
    case "duration_distance":
      parts.append(
        "\((entry.durationSeconds ?? 0).formatted()) sec · \((entry.distanceMeters ?? 0).formatted()) m"
      )
    case "load_distance": parts.append("\((entry.distanceMeters ?? 0).formatted()) m")
    default:
      let reps = entry.repsMax.map { "\(entry.reps)–\($0)" } ?? "\(entry.reps)"
      parts.append("\(reps) reps\(entry.perSide ? " per side" : "")")
    }
    if exercise.loadType != "none" || entry.weight > 0 {
      parts.append(
        "· \(entry.weight.formatted(.number.precision(.fractionLength(0...2)))) kg\(exercise.loadType == "added" ? " added" : "")"
      )
    }
    if let rest = entry.restSeconds { parts.append("· \(rest)s rest") }
    if let rpe = entry.rpe { parts.append("· RPE \(rpe.formatted())") }
    return parts.joined(separator: " ")
  }
}
