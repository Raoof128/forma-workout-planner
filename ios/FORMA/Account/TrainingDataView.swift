import FORMACore
import SwiftUI

/// Counts, sync status, export, and "Bring your phone training".
struct TrainingDataView: View {
  @Environment(AppModel.self) private var model
  @State private var exporting = false
  @State private var document: WorkspaceDocument?
  @State private var error: String?
  @State private var message: String?
  @State private var offer: PhoneTrainingOffer = .none
  @State private var phone: Workspace?
  @State private var reviewing = false

  var body: some View {
    let workspace = model.workspace
    Form {
      if let display = model.syncDisplay {
        Section {
          NavigationLink {
            SyncDetailsView()
          } label: {
            LabeledContent {
              Text(display.title).foregroundStyle(
                display.needsAttention ? FormaTheme.error : FormaTheme.secondary)
            } label: {
              Label("Workout data", systemImage: display.symbol)
            }
          }
        } header: {
          Text("Routines and completed sessions saved to your member account.")
            .textCase(nil)
        }
      }

      Section {
        LabeledContent("Routines", value: "\(workspace?.routines.count ?? 0)")
        LabeledContent("Workouts", value: "\(workspace?.history.count ?? 0)")
        LabeledContent("Training days", value: "\(workspace?.schedule.count ?? 0)")
      }
      .accessibilityIdentifier("training-counts")

      Section {
        Button {
          exportCopy()
        } label: {
          Label("Export my data", systemImage: "square.and.arrow.up")
        }
        .disabled(workspace == nil)
        .accessibilityIdentifier("training-export")
        if let message { FormNotice(text: message, tone: .success) }
        if let error { FormNotice(text: error, tone: .error) }
      }

      switch offer {
      case .none: EmptyView()
      case .importedHere:
        Section {
          Text(
            "This iPhone’s local training is assigned to this account. Check Sync for any changes waiting to send."
          )
        }
      case .importedElsewhere:
        Section {
          Text(
            "This iPhone’s local training was already brought into another account, so it is not offered again."
          )
        }
      case .reservedElsewhere:
        Section {
          Text(
            "An import of this iPhone’s training was started for another account. It can only be reviewed and retried in that account."
          )
        }
      case .unavailable(let message):
        Section { FormNotice(text: message, tone: .error) }
      case .available(let summary), .reservedHere(let summary):
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Bring your phone training").font(.headline)
            if case .reservedHere = offer {
              Text(
                "An earlier import is reserved for this account and may already have changed its training. Save a fresh account copy and review the counts before retrying."
              )
              .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            }
            Text(
              "This iPhone has training recorded before you signed in. Review the counts before bringing it into this account. The training on this iPhone stays in place."
            )
            .font(.subheadline).foregroundStyle(FormaTheme.secondary)
            Text(
              "\(summary.routines) routines · \(summary.workouts) workouts"
                + (summary.workoutInProgress ? " · 1 in progress" : "")
            )
            .font(.subheadline.weight(.semibold))
          }
          Button("Review phone training") { reviewing = true }
            .accessibilityIdentifier("phone-training-review")
        } header: {
          Text("Training found on this iPhone")
        }
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Training data").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .task { await loadOffer() }
    .navigationDestination(isPresented: $reviewing) {
      if let summary = reviewSummary, let phone {
        PhoneTrainingReview(summary: summary, phone: phone) {
          reviewing = false
          message = "Your phone training was brought into your account."
          Task { await loadOffer() }
        }
      }
    }
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: "forma-account-export"
    ) { result in
      if case .failure(let failure) = result {
        error = "The export couldn’t be saved. \(failure.localizedDescription)"
      } else {
        message = "Your account data export is ready."
      }
    }
    .onChange(of: exporting) { _, presented in if !presented { document = nil } }
  }

  private func loadOffer() async {
    let result = await model.loadPhoneTraining()
    offer = result.offer
    phone = result.workspace
  }

  private var reviewSummary: PhoneTrainingSummary? {
    switch offer {
    case .available(let summary), .reservedHere(let summary): summary
    default: nil
    }
  }

  private func exportCopy() {
    error = nil
    message = nil
    do {
      document = WorkspaceDocument(data: try model.exportData())
      exporting = true
    } catch {
      self.error = error.localizedDescription
    }
  }
}

/// Counts, a saved copy of the account's current data, a confirmation, then the
/// replacement: the website's import, step for step.
struct PhoneTrainingReview: View {
  @Environment(AppModel.self) private var model
  let summary: PhoneTrainingSummary
  let phone: Workspace
  let finished: () -> Void

  @State private var exporting = false
  @State private var document: WorkspaceDocument?
  @State private var savedCopyRevision: Int?
  @State private var copyReady = false
  @State private var acknowledged = false
  @State private var confirming = false
  @State private var working = false
  @State private var error: String?

  private var canSave: Bool {
    if case .idle = model.syncStatus { return model.workspace != nil }
    return false
  }

  var body: some View {
    Form {
      Section {
        Text(
          "This replaces the current cloud training copy with the training on this iPhone. The training on this iPhone stays unchanged."
        )
        LabeledContent("Routines", value: "\(summary.routines)")
        LabeledContent("Workouts", value: "\(summary.workouts)")
        if summary.workoutInProgress {
          LabeledContent("Workout in progress", value: "1")
        }
      } header: {
        Text("Confirm training data")
      }

      Section {
        Button {
          Task { await saveCopy() }
        } label: {
          Label(
            copyReady ? "Account copy saved" : "Save a copy of my account data first",
            systemImage: copyReady ? "checkmark.circle" : "square.and.arrow.down")
        }
        .disabled(!canSave || working)
        .accessibilityIdentifier("phone-training-save-copy")
      } footer: {
        if !canSave {
          Text(
            "Your account must be up to date before it can be copied. Open Sync to finish saving first."
          )
        } else {
          Text("Keep this file somewhere safe. It is the only way back if you change your mind.")
        }
      }

      Section {
        Toggle(isOn: $acknowledged) {
          Text("I reviewed the counts and saved a copy of my current cloud training data.")
        }
        .toggleStyle(CheckboxToggleStyle())
        .accessibilityIdentifier("phone-training-acknowledge")
        if let error { FormNotice(text: error, tone: .error) }
        SubmitButton(
          title: "Import to account", working: working, identifier: "phone-training-import"
        ) {
          confirming = true
        }
        .disabled(!acknowledged || !copyReady || working)
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Bring your phone training").navigationBarTitleDisplayMode(.inline)
    .protectWidgetNavigation()
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: "forma-account-copy-before-import"
    ) { result in
      switch result {
      case .success: copyReady = true
      case .failure(let failure):
        copyReady = false
        error = "The copy couldn’t be saved. \(failure.localizedDescription)"
      }
    }
    .onChange(of: exporting) { _, presented in if !presented { document = nil } }
    .confirmationDialog(
      "Replace your account’s training with this iPhone’s?", isPresented: $confirming,
      titleVisibility: .visible
    ) {
      Button("Replace account training", role: .destructive) { Task { await bringIn() } }
        .accessibilityIdentifier("phone-training-confirm")
    } message: {
      Text("Your account’s current routines and workouts will be replaced. You saved a copy first.")
    }
  }

  /// The copy and the revision it was taken at go together: the import is
  /// pinned to that revision and refuses if the account has moved on since.
  private func saveCopy() async {
    error = nil
    copyReady = false
    guard let revision = await model.reviewedAccountRevision() else {
      error = "Your account has not been downloaded on this device yet."
      return
    }
    do {
      document = WorkspaceDocument(data: try model.exportData())
      savedCopyRevision = revision
      exporting = true
    } catch {
      self.error = error.localizedDescription
    }
  }

  private func bringIn() async {
    guard !working else { return }
    working = true
    defer { working = false }
    error = nil
    let status = await model.bringPhoneTraining(phone, reviewedRevision: savedCopyRevision)
    switch status {
    case .idle:
      model.haptic(.added)
      finished()
    case .waiting:
      // Replaced here; the upload waits for a connection.
      model.haptic(.added)
      finished()
    case .failed(let message):
      error = message
      copyReady = false
      acknowledged = false
      model.haptic(.warning)
    case .conflict:
      error = "Your account changed on another device. Review it in Sync, then try again."
      model.haptic(.warning)
    case .saving, .signedOut:
      error = "Your training could not be brought into the account. Try again."
      model.haptic(.failed)
    }
  }
}
