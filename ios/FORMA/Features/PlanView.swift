import FORMACore
import SwiftUI

struct PlanView: View {
  @Environment(AppModel.self) private var model
  @State private var creating = false

  var body: some View {
    // `routines` filters the workspace on every read; read it once per render.
    let routines = model.routines
    let storedRoutineCount = model.workspace?.routines.count ?? 0
    List {
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Text("YOUR TRAINING, YOUR WAY").font(.caption.weight(.bold)).tracking(2)
            .foregroundStyle(FormaTheme.accent)
          EditorialTitle(text: "A little structure.\nA lot of possibility.")
            .foregroundStyle(FormaTheme.primary)
          Text(
            "Build a session that fits you. Every routine and technique guide stays available offline."
          )
          .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        }
        .padding(.vertical, 14)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      }

      Section {
        ExerciseLibraryLink()
        NavigationLink {
          TrainingDaysView()
        } label: {
          Label("Training days", systemImage: "calendar")
            .padding(.vertical, 8)
        }
      }

      Section {
        if routines.isEmpty {
          ContentUnavailableView(
            "Make room for your first routine", systemImage: "square.stack",
            description: Text("Choose your exercises, set your targets, and make it yours."))
        }
        ForEach(routines) { routine in
          NavigationLink {
            RoutineDetailView(routine: routine)
          } label: {
            RoutinePlanRow(routine: routine)
          }
        }
        Button {
          creating = true
        } label: {
          Label("Create a routine", systemImage: "plus")
            .frame(minHeight: 44)
        }
        .disabled(model.busy || storedRoutineCount >= 200)
        .accessibilityIdentifier("create-routine")
      } header: {
        Text("My routines · \(routines.count)")
      } footer: {
        if storedRoutineCount >= 200 {
          Text("Your workspace holds up to 200 routines. Remove one before adding another.")
        } else {
          Text(
            "Starter loads are editable examples. Choose a comfortable load and progress at your own pace."
          )
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $creating) {
      NavigationStack { RoutineEditorView(routine: nil) }
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
    NavigationLink {
      ExerciseLibraryView()
    } label: {
      Label {
        VStack(alignment: .leading, spacing: 4) {
          Text("Exercise library").font(.headline)
          Text("\(movementCount.formatted()) movements. Find your next one.")
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
  let routine: Routine
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(routine.name).font(.title3.bold()).foregroundStyle(FormaTheme.primary)
      if !routine.description.isEmpty {
        Text(routine.description).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          .lineLimit(2)
      }
      Label(
        "\(routine.exercises.count) exercises · \(routine.minutes) min",
        systemImage: "square.stack.3d.up"
      )
      .font(.caption).foregroundStyle(FormaTheme.accent)
    }
    .padding(.vertical, 10)
  }
}

struct RoutineDetailView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  private let routineID: String
  @State private var editing: Routine?
  @State private var confirmingDelete = false
  /// True while `requestStart` waits on the Watch check or the first save, so
  /// the tap is acknowledged at once.
  @State private var starting = false
  private var current: Routine? { model.workspace?.routines.first { $0.id == routineID } }

  init(routine: Routine) {
    routineID = routine.id
  }

  var body: some View {
    Group {
      if let current {
        List {
          Section {
            VStack(alignment: .leading, spacing: 14) {
              Text("THE SESSION").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
                FormaTheme.accent)
              EditorialTitle(text: current.name)
              if !current.description.isEmpty {
                Text(current.description).foregroundStyle(FormaTheme.secondary)
              }
              Text("\(current.minutes) min · \(current.level)").font(.subheadline)
                .foregroundStyle(FormaTheme.secondary)
              let startTitle =
                model.workspace?.active == nil ? "Start workout" : "Resume active workout"
              Button {
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
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
          }
          Section("Exercise by exercise") {
            ForEach(Array(current.exercises.enumerated()), id: \.element.id) { index, entry in
              if let exercise = model.exercise(entry.exerciseId) {
                NavigationLink {
                  GuideView(exercise: exercise)
                } label: {
                  HStack(alignment: .top, spacing: 14) {
                    Text(String(format: "%02d", index + 1))
                      .font(.system(.title3, design: .monospaced).weight(.semibold))
                      .foregroundStyle(FormaTheme.accent)
                      .accessibilityHidden(true)
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
              }
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
      } else {
        ContentUnavailableView(
          "This routine was removed", systemImage: "square.stack",
          description: Text("Your completed workouts are still in Progress."))
      }
    }
    .scrollContentBackground(.hidden)
    .background(FormaTheme.canvas)
    .navigationTitle("Routine")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editing) { routine in
      NavigationStack { RoutineEditorView(routine: routine) }
    }
    .confirmationDialog(
      "Delete this routine?", isPresented: $confirmingDelete, titleVisibility: .visible
    ) {
      Button("Delete routine", role: .destructive) {
        Task {
          if await model.commit({ value in value.routines.removeAll { $0.id == routineID } }) {
            dismiss()
          }
        }
      }
    } message: {
      Text("This removes the plan only. Active and completed workouts will be kept.")
    }
  }
}

private struct RoutineEditorView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  let original: Routine?
  @State private var draft: Routine
  @State private var choosingExercise = false
  @State private var failure: String?
  @State private var confirmingDiscard = false
  @State private var targetDrafts: [String: TargetInputDraft] = [:]

  init(routine: Routine?) {
    original = routine
    _draft = State(initialValue: routine ?? Routine(name: "My routine"))
  }

  private var changed: Bool { !targetDrafts.isEmpty || (original.map { $0 != draft } ?? true) }
  private var invalid: String? {
    if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "Give your routine a name."
    }
    if draft.name.utf16.count > 60 { return "Use a shorter routine name, up to 60 characters." }
    if draft.description.utf16.count > 500 {
      return "Use a shorter description, up to 500 characters."
    }
    if draft.exercises.isEmpty { return "Add at least one exercise." }
    if draft.exercises.contains(where: { ($0.note?.utf16.count ?? 0) > 140 }) {
      return "Exercise cues can contain up to 140 characters."
    }
    if draft.exercises.contains(where: {
      $0.perSide && model.exercise($0.exerciseId)?.metric == "load_reps"
        && ($0.reps > 50 || ($0.repsMax ?? 0) > 50)
    }) {
      return "Use up to 50 reps per side so each set totals no more than 100 reps."
    }
    if let target = targetDrafts.keys.sorted().compactMap({ targetDrafts[$0] }).first(where: {
      $0.error != nil
    }),
      let error = target.error
    {
      return "\(target.context): \(error)"
    }
    return nil
  }

  var body: some View {
    // `invalid` walks the whole draft (and sorts the target drafts); the body
    // and the toolbar both need it, so evaluate it once per render.
    let validation = invalid
    Form {
      Section("Make it yours") {
        TextField("Routine name", text: $draft.name).accessibilityLabel("Routine name")
          .accessibilityIdentifier("routine-name")
        TextField("What is this session for?", text: $draft.description, axis: .vertical)
          .lineLimit(2...5).accessibilityLabel("Routine description")
          .accessibilityIdentifier("routine-description")
        Stepper(
          "Estimated time: \(draft.minutes) min", value: $draft.minutes, in: 1...1000, step: 5)
      }
      Section {
        ForEach($draft.exercises) { $entry in
          if let exercise = model.exercise(entry.exerciseId) {
            NavigationLink {
              PrescriptionEditor(entry: $entry, exercise: exercise, targetDrafts: $targetDrafts)
            } label: {
              RoutineEditorRow(entry: entry, exercise: exercise)
            }
          }
        }
        .onMove { source, destination in
          draft.exercises.move(fromOffsets: source, toOffset: destination)
          preserveValidGroups()
        }
        .onDelete { offsets in
          let removed = Set(offsets.map { draft.exercises[$0].id })
          draft.exercises.remove(atOffsets: offsets)
          targetDrafts = targetDrafts.filter { key, _ in
            // Saved entry IDs may contain "|". Remove only that exact row's
            // fields, keeping another row's invalid input and validation intact.
            guard let separator = key.lastIndex(of: "|") else { return true }
            return !removed.contains(String(key[..<separator]))
          }
          preserveValidGroups()
        }
        Button {
          choosingExercise = true
        } label: {
          Label("Add exercise", systemImage: "plus").frame(minHeight: 44)
        }
        .disabled(draft.exercises.count >= 100)
      } header: {
        HStack {
          Text("Exercises · \(draft.exercises.count)/100")
          Spacer()
          EditButton().textCase(nil)
        }
      } footer: {
        Text(
          "Tap an exercise to set its targets. Use Edit to move or remove exercises. Moving a superset apart unlinks that group."
        )
      }
      if let validation {
        Section {
          Label(validation, systemImage: "info.circle").foregroundStyle(FormaTheme.secondary)
        }
      }
      if let failure {
        Section {
          Text(failure).foregroundStyle(FormaTheme.error).accessibilityIdentifier(
            "routine-save-error")
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
          .fontWeight(.semibold).disabled(model.busy || validation != nil)
          .accessibilityIdentifier("save-routine")
      }
    }
    .interactiveDismissDisabled(changed || model.busy)
    .confirmationDialog(
      "Discard your routine changes?", isPresented: $confirmingDiscard, titleVisibility: .visible
    ) {
      Button("Discard changes", role: .destructive) { dismiss() }
    }
    .navigationDestination(isPresented: $choosingExercise) {
      ExerciseLibraryView { exercise in
        guard draft.exercises.count < 100 else { return }
        let defaults = exercise.defaults
        draft.exercises.append(
          Prescription(
            exerciseId: exercise.id, entryId: UUID().uuidString,
            sets: defaults.sets, reps: defaults.reps, weight: defaults.weight,
            durationSeconds: defaults.durationSeconds, distanceMeters: defaults.distanceMeters,
            perSide: defaults.perSide
          ))
        choosingExercise = false
      }
    }
  }

  private func save() async {
    guard !model.busy else { return }
    guard invalid == nil else {
      failure = invalid
      return
    }
    var candidate = draft
    candidate.name = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let saved = await model.commit { workspace in
      if let original {
        guard let index = workspace.routines.firstIndex(where: { $0.id == original.id }),
          workspace.routines[index] == original
        else {
          throw AppFailure(
            "This routine changed while you were editing. Keep your draft open or reopen the current routine before saving."
          )
        }
        workspace.routines[index] = candidate
      } else {
        guard workspace.routines.count < 200 else {
          throw AppFailure("Your workspace already has 200 routines.")
        }
        workspace.routines.append(candidate)
      }
    }
    if saved {
      dismiss()
    } else {
      failure =
        model.errorMessage ?? "Your routine has not been saved. Keep your draft open and try again."
      // Shown inline above; the root alert can't present over this sheet and
      // would otherwise replay the same error after it closes.
      model.errorMessage = nil
    }
  }

  private func preserveValidGroups() {
    let groups = Set(draft.exercises.compactMap(\.groupId))
    for group in groups {
      let indices = draft.exercises.indices.filter { draft.exercises[$0].groupId == group }
      guard let first = indices.first, let last = indices.last else { continue }
      if indices.count < 2 || last - first + 1 != indices.count {
        for index in indices { draft.exercises[index].groupId = nil }
      }
    }
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
          .accessibilityIdentifier("routine-target-\(fieldKey)")
        Text(unit).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          .accessibilityHidden(true)
      }
      if let error = drafts[fieldKey]?.error {
        Label {
          Text(error).foregroundStyle(FormaTheme.primary)
        } icon: {
          Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
        }
        .font(.footnote)
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
      Section {
        Stepper("Sets: \(entry.sets)", value: $entry.sets, in: 1...12)
        if showsLoad {
          TargetNumberField(
            title: exercise.loadType == "added" ? "Added load" : "Weight",
            unit: "kg", value: $entry.weight, range: 0...1000,
            fieldKey: "\(entry.id)|weight", context: exercise.name,
            drafts: $targetDrafts, focus: $focusedTarget)
        }
        if usesReps {
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
            Text(
              "Legacy Forearm plank: each rep represents a 10-second hold. Existing units are preserved."
            )
            .font(.footnote).foregroundStyle(FormaTheme.secondary)
          }
        }
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
      Section {
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
        TextField(
          "A cue for your next session",
          text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }),
          axis: .vertical
        )
        .lineLimit(2...4).accessibilityLabel("Exercise cue, up to 140 characters")
        if (entry.note?.utf16.count ?? 0) > 140 {
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
  var onSelect: ((Exercise) -> Void)? = nil
  @State private var query = ""
  @State private var muscle = "All muscles"
  @State private var equipment = "All equipment"
  @State private var index: LibraryIndex?
  @State private var hits: SearchHits?

  /// Same rule as `Exercise.matches(query:)`: a query with no words matches all.
  private var hasSearchWords: Bool { query.contains { !$0.isWhitespace } }

  private func visibleExercises(in index: LibraryIndex) -> [Exercise] {
    // While a search is debouncing or running off the main thread, keep showing
    // the previous hits (already narrowed by the current filters) instead of
    // blocking the keystroke on 1,700 Unicode folds.
    let base = hasSearchWords ? (hits?.exercises ?? index.exercises) : index.exercises
    guard muscle != "All muscles" || equipment != "All equipment" else { return base }
    return base.filter { exercise in
      (muscle == "All muscles" || muscle == exercise.muscle)
        && (equipment == "All equipment" || equipment == exercise.equipment)
    }
  }

  var body: some View {
    let index = self.index ?? LibraryIndex(catalog: model.catalog)
    let matches = visibleExercises(in: index)
    List {
      Section {
        Picker("Muscle", selection: $muscle) {
          Text("All muscles").tag("All muscles")
          ForEach(index.muscles, id: \.self) { Text($0).tag($0) }
        }
        Picker("Equipment", selection: $equipment) {
          Text("All equipment").tag("All equipment")
          ForEach(index.equipmentTypes, id: \.self) { Text($0).tag($0) }
        }
        if muscle != "All muscles" || equipment != "All equipment" || !query.isEmpty {
          Button("Clear search & filters") {
            query = ""
            muscle = "All muscles"
            equipment = "All equipment"
          }
          .frame(minHeight: 44)
        }
      }
      Section("\(matches.count.formatted()) \(matches.count == 1 ? "exercise" : "exercises")") {
        if matches.isEmpty {
          ContentUnavailableView.search(text: query)
        }
        ForEach(matches) { exercise in
          if let onSelect {
            HStack(alignment: .center, spacing: 12) {
              NavigationLink {
                GuideView(exercise: exercise)
              } label: {
                ExerciseLibraryRow(exercise: exercise)
              }
              Button {
                onSelect(exercise)
              } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
                  .frame(minWidth: 44, minHeight: 44)
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Add \(exercise.name)")
            }
          } else {
            NavigationLink {
              GuideView(exercise: exercise)
            } label: {
              ExerciseLibraryRow(exercise: exercise)
            }
          }
        }
      }
    }
    .searchable(text: $query, prompt: "Name, muscle or equipment")
    // Filter changes animate; typed queries never do. Results arrive after a
    // debounce while the person is still typing, and moving rows under the
    // keyboard would be both janky and distracting.
    .formaAnimation(FormaMotion.reveal, value: [muscle, equipment])
    .accessibilityIdentifier(onSelect == nil ? "exercise-library" : "exercise-picker")
    .navigationTitle(onSelect == nil ? "Exercise library" : "Add exercise")
    .navigationBarTitleDisplayMode(.inline)
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
          Text("KNOW THE MOVEMENT").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
            FormaTheme.accent)
          EditorialTitle(text: exercise.name)
          Text("\(exercise.muscle) · \(exercise.equipment)").font(.subheadline).foregroundStyle(
            FormaTheme.secondary)
        }
        .padding(.vertical, 10)
        .listRowBackground(Color.clear)
      }
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
    .navigationTitle("Technique guide")
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
  private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
  var body: some View {
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
