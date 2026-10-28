import FORMACore
import SwiftUI

/// How syncing is going, "Sync now", and the website's two choices when the
/// account changed somewhere else.
struct SyncDetailsView: View {
  @Environment(AppModel.self) private var model
  @State private var working = false
  @State private var acknowledged = false
  @State private var confirmKeepLocal = false
  @State private var exporting = false
  @State private var document: WorkspaceDocument?
  @State private var error: String?

  var body: some View {
    Form {
      if let display = model.syncDisplay {
        Section {
          Label(display.title, systemImage: display.symbol)
            .font(.headline)
            .foregroundStyle(display.needsAttention ? FormaTheme.error : FormaTheme.primary)
            .accessibilityIdentifier("sync-status-title")
          Text(display.detail).font(.subheadline).foregroundStyle(FormaTheme.secondary)
          if let error { FormNotice(text: error, tone: .error) }
        }

        if case .conflict = model.syncStatus {
          conflict
        } else {
          Section {
            Button {
              Task {
                working = true
                await model.syncNow()
                working = false
              }
            } label: {
              HStack {
                Text("Sync now")
                if working { ProgressView() }
              }
            }
            .disabled(working)
            .accessibilityIdentifier("sync-now")
          } footer: {
            Text(
              "Every change is saved on this iPhone first, then sent to your account. Changes made offline wait and send when you’re back online. Changes from the website arrive when the app opens or you sync."
            )
          }
        }
      } else {
        Section { Text("You’re not signed in.") }
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("Sync").navigationBarTitleDisplayMode(.inline)
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: "forma-unsynced-changes"
    ) { result in
      if case .failure(let failure) = result {
        error = "The file couldn’t be saved. \(failure.localizedDescription)"
      }
    }
    .onChange(of: exporting) { _, presented in if !presented { document = nil } }
    .confirmationDialog(
      "Replace your account with this iPhone’s copy?", isPresented: $confirmKeepLocal,
      titleVisibility: .visible
    ) {
      Button("Keep my version", role: .destructive) {
        Task {
          working = true
          await model.resolveConflictKeepingLocal()
          working = false
          model.haptic(.selected)
        }
      }
      .accessibilityIdentifier("sync-confirm-keep-local")
    } message: {
      Text(
        "Changes made on the other device since you last synced will be replaced by what’s on this iPhone."
      )
    }
  }

  @ViewBuilder
  private var conflict: some View {
    Section {
      Text(
        "Training data changed on another device. Reloading will replace your unsynced edits with the cloud copy."
      )
      Button {
        do {
          document = WorkspaceDocument(data: try model.exportData())
          exporting = true
        } catch {
          self.error = error.localizedDescription
        }
      } label: {
        Label("Export my unsynced changes", systemImage: "square.and.arrow.up")
      }
      .accessibilityIdentifier("sync-export-unsynced")
      Toggle(isOn: $acknowledged) {
        Text("I understand reloading replaces my unsynced edits.")
      }
      .toggleStyle(CheckboxToggleStyle())
      .accessibilityIdentifier("sync-acknowledge")
      Button("Reload cloud data", role: .destructive) {
        Task {
          working = true
          await model.resolveConflictUsingAccount()
          working = false
          acknowledged = false
          model.haptic(.selected)
        }
      }
      .disabled(!acknowledged || working)
      .accessibilityIdentifier("sync-reload-cloud")
    } header: {
      Text("Choose which copy to keep")
    }
    Section {
      Button("Keep my version…") { confirmKeepLocal = true }
        .disabled(working)
        .accessibilityIdentifier("sync-keep-local")
    } footer: {
      Text("Sends this iPhone’s copy to your account instead, after you confirm.")
    }
  }
}
