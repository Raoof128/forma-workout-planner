import FORMACore
import SwiftUI

struct WorkoutView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  @State private var selectedExercise = 0
  @State private var drafts: [String: SetDraft] = [:]
  @State private var validation: String?
  @State private var finishConfirmation = false
  @State private var discardConfirmation = false
  @State private var guide: Exercise?
  @State private var notesPresented = false
  @State private var feedback = 0
  @FocusState private var focusedField: String?

  var body: some View {
    if let session = model.workspace?.active {
      ScrollViewReader { reader in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            AdaptiveMetricGroup {
              VStack(alignment: .leading, spacing: 6) {
                Text("IN YOUR OWN TIME.").font(.caption.weight(.bold)).tracking(1.5)
                  .foregroundStyle(FormaTheme.accent)
                Text(session.name).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
              }
              ElapsedTime(startedAt: session.startedAt)
            }
            LocalSaveStatus(saving: model.busy, pendingChanges: !drafts.isEmpty)
            if let failure = model.errorMessage {
              Label(failure, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(FormaTheme.error)
            }
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
                if let previous = lastSet(for: entry.exerciseId, before: session.id) {
                  Label(
                    "Last time · \(measurementText(previous, exercise: exercise))",
                    systemImage: "clock.arrow.circlepath"
                  )
                  .font(.subheadline).foregroundStyle(FormaTheme.secondary)
                }
                if let note = entry.note, !note.isEmpty {
                  Text(note).font(.subheadline).foregroundStyle(FormaTheme.secondary)
                }
                if entry.groupId != nil {
                  Label("Superset · rest after the final movement", systemImage: "link")
                    .font(.caption).foregroundStyle(FormaTheme.accent)
                }
                if exercise?.id == "plank" {
                  Text(
                    "This original plank logs 10 seconds per rep. Saved records keep these units."
                  )
                  .font(.caption).foregroundStyle(FormaTheme.secondary)
                }
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
                    complete: {
                      Task { await complete(sessionID: session.id, entryID: entry.id, set: index) }
                    }
                  )
                  .id(key)
                }
              }
              if let validation {
                Label(validation, systemImage: "exclamationmark.circle")
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
                }
                .frame(minHeight: 44).disabled(model.busy || entry.sets.count >= 100)
                Spacer()
                Button {
                  notesPresented = true
                } label: {
                  Label("Notes", systemImage: "square.and.pencil")
                }
                .frame(minHeight: 44).disabled(model.busy)
                .accessibilityIdentifier("session-notes")
              }.font(.subheadline.weight(.semibold))
              if selectedExercise + 1 < session.exercises.count {
                Button {
                  Task {
                    if await saveDrafts() {
                      focusedField = nil
                      selectedExercise += 1
                      validation = nil
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
              }
            }
          }.padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .formaBottomBar { RestDock(compact: focusedField != nil) }
        .background(FormaTheme.canvas)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Save & close") {
              Task { if await saveDrafts() { model.workoutPresented = false } }
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
            Button("Finish") { finishConfirmation = true }
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
              if await saveDrafts() { await model.finish() }
            }
          }.accessibilityIdentifier("finish-confirm")
        } message: {
          Text(
            "Completed sets will be saved to your training journal. Uncompleted sets remain part of the session snapshot."
          )
        }
        .alert("Discard this workout?", isPresented: $discardConfirmation) {
          Button("Keep training", role: .cancel) {}
          Button("Discard workout", role: .destructive) {
            Task {
              if await model.commit(forActiveSession: session.id, { $0.active = nil }) {
                model.workoutPresented = false
              }
            }
          }
        } message: {
          Text(
            "This removes the active session, including its completed sets. Your routines and finished workouts stay saved."
          )
        }
        .sheet(item: $guide) { exercise in GuideSheet(exercise: exercise) }
        .sheet(isPresented: $notesPresented) { SessionNotesView() }
        .sensoryFeedback(.success, trigger: feedback) { _, _ in model.hapticsEnabled }
        .onChange(of: scenePhase) { _, phase in
          // Canonical sets are already committed. Best effort for valid in-progress edits;
          // OS suspension is never treated as a successful save acknowledgement.
          if phase == .inactive { Task { _ = await saveDrafts() } }
        }
        .accessibilityIdentifier("workout-screen")
      }
    }
  }

  private func exerciseSelector(_ session: WorkoutSession) -> some View {
    Menu {
      ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, entry in
        Button {
          Task {
            if await saveDrafts() {
              focusedField = nil
              selectedExercise = index
              validation = nil
            }
          }
        } label: {
          Text("\(index + 1). \(model.exercise(entry.exerciseId)?.name ?? entry.exerciseId)")
        }
      }
    } label: {
      HStack {
        Image(systemName: "list.bullet")
        Text("Choose exercise")
        Spacer()
        Text("\(session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }) sets completed")
          .font(.caption)
        Image(systemName: "chevron.down")
      }
      .font(.subheadline.weight(.medium)).padding(16)
      .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    .id("exercise-selector")
    .disabled(model.busy)
  }

  private func draftKey(entry: SessionEntry, set: Int) -> String { "\(entry.id)-\(set)" }
  private func lastSet(for exercise: String, before sessionId: String) -> LoggedSet? {
    WorkoutEngine.lastCompletedSet(for: exercise, in: model.history, excluding: sessionId)
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
          session.exercises[entry].sets[set] = try draft.value(
            from: session.exercises[entry].sets[set])
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
        validation = drafts.isEmpty ? nil : "Newer edits are still unsaved. Tap Done to save them."
        // Programmatic dismissal is allowed even with interactive dismissal
        // disabled, so callers must not close or finish over newer text.
        return drafts.isEmpty
      }
    } catch { validation = error.localizedDescription }
    return false
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
      let saved = await model.commit(forActiveSession: session.id) { value in
        guard let currentEntry = value.active?.exercises.firstIndex(where: { $0.id == entryID })
        else { throw AppFailure("This exercise has changed. Reopen it before editing its sets.") }
        try applyDrafts(submitted, to: &value)
        value = try WorkoutEngine.toggleSet(
          in: value, entryIndex: currentEntry, setIndex: set, now: AppModel.now,
          catalog: model.catalog)
      }
      if saved {
        drafts = retainingUnacknowledgedDrafts(drafts, acknowledged: submitted)
        if drafts.isEmpty { focusedField = nil }
        validation = drafts.isEmpty ? nil : "Newer edits are still unsaved. Tap Done to save them."
        if !wasDone { feedback += 1 }
      }
    } catch { validation = error.localizedDescription }
  }

  private func addSet() async {
    guard let session = model.workspace?.active,
      session.exercises.indices.contains(selectedExercise)
    else { return }
    let entryID = session.exercises[selectedExercise].id
    guard await saveDrafts() else { return }
    _ = await model.commit(forActiveSession: session.id) { value in
      guard let index = value.active?.exercises.firstIndex(where: { $0.id == entryID }),
        let last = value.active?.exercises[index].sets.last
      else { throw AppFailure("This exercise has changed. Reopen it before adding a set.") }
      var next = last
      next.done = false
      value.active?.exercises[index].sets.append(next)
    }
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
  let complete: () -> Void

  var body: some View {
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
    .padding(14).background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 18))
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

  private var completionButton: some View {
    Button(action: complete) {
      Image(systemName: set.done ? "checkmark" : "checkmark.circle")
        .font(.title3.weight(.semibold))
        .foregroundStyle(set.done ? FormaTheme.ink : FormaTheme.accent)
        .frame(width: 56, height: 56)
        .background(
          set.done ? FormaTheme.lime : FormaTheme.canvas, in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
          if !set.done { RoundedRectangle(cornerRadius: 14).stroke(FormaTheme.fieldBorder) }
        }
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
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
      TextField(label, text: value)
        .font(.title3.weight(.semibold).monospacedDigit())
        .keyboardType(["reps", "left", "right"].contains(name) ? .numberPad : .decimalPad)
        .multilineTextAlignment(.center).frame(minHeight: 48)
        .background(FormaTheme.canvas, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10).stroke(
            focusedField.wrappedValue == "\(key)-\(name)"
              ? FormaTheme.accent : FormaTheme.fieldBorder,
            lineWidth: focusedField.wrappedValue == "\(key)-\(name)" ? 2 : 1)
        }
        .focused(focusedField, equals: "\(key)-\(name)")
        // Ordinary completed rows are locked. A late pre-completion text event
        // remains editable until it can be validated and acknowledged.
        .disabled((set.done && !pendingChanges) || busy)
        .accessibilityLabel("Set \(index + 1), \(label)")
        .accessibilityIdentifier("set-value-\(entryIndex)-\(index)-\(name)")
    }.frame(minWidth: minimumColumnWidth, maxWidth: .infinity)
  }
}

struct ElapsedTime: View {
  @Environment(\.scenePhase) private var scenePhase
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
    return Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
      .font(.subheadline.monospacedDigit()).foregroundStyle(FormaTheme.secondary)
      .accessibilityLabel("Elapsed time, \(seconds / 60) minutes and \(seconds % 60) seconds")
  }
}

struct RestDock: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  var compact = false

  var body: some View {
    if let session = model.workspace?.active, session.restEnd != nil || session.restPaused != nil {
      Group {
        if scenePhase == .active {
          TimelineView(.periodic(from: .now, by: 1)) { context in panel(session, at: context.date) }
        } else {
          panel(session, at: .now)
        }
      }
      .padding(16)
      .formaControlSurface()
      .padding(.horizontal, 16).padding(.vertical, 8)
      .disabled(model.busy)
    }
  }

  private func panel(_ session: WorkoutSession, at date: Date) -> some View {
    let remaining = Int(
      ceil(WorkoutEngine.remainingRest(session, now: date.timeIntervalSince1970 * 1_000)))
    return VStack(alignment: .leading, spacing: compact ? 0 : 12) {
      AdaptiveMetricGroup {
        Label {
          if compact {
            Text("Rest")
          } else {
            ZStack(alignment: .leading) {
              // Reserve the longest status so expiry doesn't move the logger.
              Text("Ready when you are").hidden().accessibilityHidden(true)
              Text(
                remaining == 0
                  ? "Ready when you are" : session.restPaused != nil ? "Rest paused" : "Rest")
            }
          }
        } icon: {
          Image(systemName: "timer")
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        .accessibilityLabel(
          session.restPaused != nil
            ? "Rest paused" : remaining == 0 ? "Rest finished" : "Rest timer")
        ZStack(alignment: .trailing) {
          Text("10:00").hidden().accessibilityHidden(true)
          Text(String(format: "%01d:%02d", remaining / 60, remaining % 60))
            .accessibilityLabel("\(remaining / 60) minutes, \(remaining % 60) seconds remaining")
            .accessibilityIdentifier("rest-remaining")
        }
        .font(compact ? .headline.monospacedDigit() : .title.bold().monospacedDigit())
        .foregroundStyle(.primary)
      }
      if !compact {
        AdaptiveMetricGroup {
          Button {
            Task {
              _ = await model.commit(forActiveSession: session.id) { value in
                value =
                  value.active?.restPaused != nil
                  ? try WorkoutEngine.resumeRest(in: value, now: AppModel.now)
                  : try WorkoutEngine.pauseRest(in: value, now: AppModel.now)
              }
            }
          } label: {
            Label(
              session.restPaused != nil ? "Resume" : "Pause",
              systemImage: session.restPaused != nil ? "play.fill" : "pause.fill"
            )
            .frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel(session.restPaused != nil ? "Resume rest" : "Pause rest")
          .accessibilityIdentifier("rest-toggle")
          Button {
            Task {
              _ = await model.commit(forActiveSession: session.id) {
                $0 = try WorkoutEngine.adjustRest(in: $0, by: 15, now: AppModel.now)
              }
            }
          } label: {
            Label("15 sec", systemImage: "plus").frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel("Add 15 seconds to rest")
          Button("Skip") {
            Task {
              _ = await model.commit(forActiveSession: session.id) {
                $0 = try WorkoutEngine.skipRest(in: $0)
              }
            }
          }.frame(minWidth: 44, minHeight: 44).accessibilityLabel("Skip rest")
        }
        .font(.subheadline.weight(.semibold)).buttonStyle(.plain).foregroundStyle(.primary)
      }
    }
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
            .secondary)
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
          FormaMark().fill(FormaTheme.accent).frame(width: 56, height: 56)
          Spacer()
          Text(TrainingDate.label(TrainingDate.date(session), template: "d MMM yyyy")).font(
            .caption.weight(.semibold))
        }
        Rectangle().fill(FormaTheme.accent).frame(height: 3).padding(.top, 16)
        Text("THE WORK IS YOURS.").font(.caption.weight(.bold)).tracking(2).foregroundStyle(
          FormaTheme.secondary)
        EditorialTitle(text: "Another session.\nA stronger you.")
        Text(session.name).font(.title3.weight(.semibold))
        AdaptiveMetricGroup {
          MetricValue(
            value: "\(session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count })",
            label: "Sets completed")
          MetricValue(value: "\(Int((session.duration ?? 0) / 60))", label: "Minutes")
        }
        MetricValue(
          value: WorkoutEngine.volume(session, catalog: model.catalog).formatted(
            .number.precision(.fractionLength(0...1))), label: "Lifting volume · kg × reps")
        Divider()
        Label("Session saved on this iPhone", systemImage: "checkmark.shield.fill")
          .font(.headline).foregroundStyle(FormaTheme.accent)
        Text("One more page in your training journal. Your completed sets are ready in Progress.")
          .font(.body).foregroundStyle(FormaTheme.secondary)
        Button {
          model.workoutPresented = false
          model.receipt = nil
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
