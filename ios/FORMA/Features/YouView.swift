import FORMACore
import SwiftUI
import UniformTypeIdentifiers

struct YouView: View {
  @Environment(AppModel.self) private var model
  @State private var profilePresented = false
  @State private var exporting = false
  @State private var document: WorkspaceDocument?
  @State private var deleteConfirmation = false
  @State private var backupFilename = "forma-backup"

  var body: some View {
    @Bindable var model = model
    Form {
      Section {
        VStack(alignment: .leading, spacing: 14) {
          FormaMark().fill(FormaTheme.accent).frame(width: 48, height: 48)
          EditorialTitle(text: "Your pace.\nYour space.")
          Text(model.workspace?.profile.name ?? "Guest").font(.title3.weight(.semibold))
          Label("On-device training", systemImage: "iphone.and.arrow.forward")
            .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        }
        .padding(.vertical, 16).listRowBackground(Color.clear)
      }

      Section("Make it yours") {
        Button {
          profilePresented = true
        } label: {
          LabeledContent(
            "Profile & weekly goal", value: "\(model.workspace?.profile.goal ?? 4) workouts")
        }
        NavigationLink("Training days") { TrainingDaysView() }
        LabeledContent("Weights", value: "Kilograms")
        LabeledContent("Training dates", value: "Australia/Sydney")
      }

      Section {
        Picker("Appearance", selection: $model.appearance) {
          ForEach(AppearancePreference.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("Motion", selection: $model.motion) {
          ForEach(MotionPreference.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Toggle("Set confirmation haptics", isOn: $model.hapticsEnabled)
      } header: {
        Text("Feel at home")
      } footer: {
        Text(
          "System Reduce Motion always takes precedence. Haptics follow your device settings and are paired with a visible check."
        )
      }

      Section {
        Button {
          do {
            document = WorkspaceDocument(data: try model.exportData())
            backupFilename = Self.backupFilename()
            exporting = true
          } catch { model.errorMessage = error.localizedDescription }
        } label: {
          Label("Export training backup", systemImage: "square.and.arrow.up")
        }
        .disabled(model.busy)
        NavigationLink {
          NativePrivacyView()
        } label: {
          Label("Privacy & your data", systemImage: "hand.raised")
        }
        NavigationLink {
          ExerciseLibraryView()
        } label: {
          Label("Exercise sources & licences", systemImage: "text.book.closed")
        }
        Button("Delete training data on this iPhone", role: .destructive) {
          deleteConfirmation = true
        }
        .disabled(model.busy)
      } header: {
        Text("Yours to keep. Yours to control.")
      } footer: {
        Text(
          "This native build stores training locally. Export a copy before uninstalling the app or changing phones. An exported file may contain personal information; you choose where it goes."
        )
      }

      Section {
        Link(destination: URL(string: "mailto:raoof.r12@gmail.com?subject=FORMA%20iOS%20support")!)
        {
          Label("Contact FORMA", systemImage: "envelope")
        }
        Text(
          "Train within your ability. Stop if an exercise causes pain. FORMA is a personal training log and does not provide medical advice."
        )
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
        Text("FORMA · \(Self.buildDescription)")
          .font(.caption).foregroundStyle(FormaTheme.secondary)
      }
    }
    .scrollContentBackground(.hidden).background(FormaTheme.canvas)
    .navigationTitle("You").navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $profilePresented) { ProfileEditor() }
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: backupFilename
    ) { result in
      if case .failure(let error) = result {
        model.errorMessage = "The backup couldn't be exported. \(error.localizedDescription)"
      }
    }
    .onChange(of: exporting) { _, presented in
      // The system sets this to false after finishing or cancelling the export.
      // Release the temporary personal-data snapshot in either case.
      if !presented { document = nil }
    }
    .alert("Delete local training data?", isPresented: $deleteConfirmation) {
      Button("Keep my training", role: .cancel) {}
      Button("Delete training data", role: .destructive) {
        Task { await model.deleteLocalData() }
      }
    } message: {
      Text(
        "This deletes your routines, workouts, active session and profile from this app. Export a backup first if you want to keep them. Copies you exported elsewhere are not removed."
      )
    }
  }

  private static func backupFilename() -> String {
    // A localized date template can insert slashes, which are path separators.
    // Keep the training date in Sydney while giving Files a portable filename.
    let dateStyle = Date.ISO8601FormatStyle(
      dateSeparator: .dash, timeZone: TrainingDate.calendar.timeZone
    ).year().month().day()
    return "forma-backup-\(Date.now.formatted(dateStyle))"
  }

  /// The bundle's version never changes while the app runs, so read it once
  /// instead of on every render of this form.
  private static let buildDescription: String = {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Development"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "\(version) (\(build))"
  }()
}

struct ProfileEditor: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var goal = 4
  @State private var rest = 90
  @State private var original: Profile?
  @State private var confirmingDiscard = false
  @State private var failure: String?
  @FocusState private var nameFocused: Bool

  private var changed: Bool {
    guard let original else { return false }
    return name != original.name || goal != original.goal || rest != original.restSeconds
  }

  private var invalid: String? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "Enter a display name."
    }
    if name.utf16.count > 50 { return "Use a shorter display name, up to 50 characters." }
    return nil
  }

  var body: some View {
    // Trimming and counting the name allocates; do it once per keystroke, not
    // once for each of the three places that read the result.
    let problem = invalid
    NavigationStack {
      Form {
        Section("Your training profile") {
          TextField("Display name", text: $name).textContentType(.nickname)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { nameFocused = false }
            .accessibilityIdentifier("profile-name")
          Stepper("Weekly goal: \(goal) workouts", value: $goal, in: 1...7)
            .accessibilityIdentifier("profile-goal")
          Stepper("Default rest: \(rest) seconds", value: $rest, in: 10...600, step: 5)
            .accessibilityIdentifier("profile-rest")
        }
        if let problem {
          Section { Text(problem).font(.footnote).foregroundStyle(FormaTheme.primary) }
        }
        if let failure {
          Section {
            Label {
              Text(failure).foregroundStyle(FormaTheme.primary)
            } icon: {
              Image(systemName: "exclamationmark.circle").foregroundStyle(FormaTheme.error)
            }
            .font(.subheadline).accessibilityIdentifier("profile-save-error")
          }
        }
        Text("Your name and preferences are stored on this iPhone.").font(.footnote)
      }
      .disabled(model.busy)
      .navigationTitle("Your profile").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            if changed { confirmingDiscard = true } else { dismiss() }
          }
          .disabled(model.busy).accessibilityIdentifier("cancel-profile")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await save() }
          }
          .disabled(model.busy || problem != nil || !changed)
          .accessibilityIdentifier("save-profile")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { nameFocused = false }
        }
      }
    }
    .interactiveDismissDisabled(changed || model.busy)
    .confirmationDialog(
      "Discard your profile changes?", isPresented: $confirmingDiscard, titleVisibility: .visible
    ) {
      Button("Discard changes", role: .destructive) { dismiss() }
        .accessibilityIdentifier("discard-profile-changes")
    }
    .onAppear {
      if original == nil, let profile = model.workspace?.profile {
        original = profile
        name = profile.name
        goal = profile.goal
        rest = profile.restSeconds
      }
    }
  }

  private func save() async {
    guard !model.busy, invalid == nil, let original else { return }
    let updatedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if await model.commit({ value in
      guard value.profile == original else {
        throw AppFailure(
          "Your profile changed while this editor was open. Keep this draft open or reopen your current profile before saving."
        )
      }
      value.profile.name = updatedName
      value.profile.goal = goal
      value.profile.restSeconds = rest
    }) {
      dismiss()
    } else {
      failure =
        model.errorMessage ?? "Your profile has not been saved. Keep this draft open and try again."
      // Shown inline above; the root alert can't present over this sheet and
      // would otherwise replay the same error after it closes.
      model.errorMessage = nil
    }
  }
}

struct WorkspaceDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.data = data
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

struct NativePrivacyView: View {
  @State private var notice: LegalNotice?
  @State private var unavailable = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let notice {
          Text(notice.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
          Text("Version \(notice.version) · \(notice.effective)").font(.caption).foregroundStyle(
            FormaTheme.secondary)
          Text(notice.summary).font(.headline)
          ForEach(Array(notice.blocks.enumerated()), id: \.offset) { _, block in
            if let heading = block.h ?? block.h3 {
              Text(heading).font(.title3.bold()).padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            }
            if let paragraph = block.p { Text(paragraph) }
            if let items = block.ul {
              ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                  Text("•")
                  Text(item)
                }
              }
            }
          }
        } else if unavailable {
          Text(
            "This build couldn't open the bundled privacy notice. Your training is stored locally; no account sync, advertising or analytics runs in this native build. Contact raoof.r12@gmail.com for help."
          )
        } else {
          ProgressView("Opening privacy notice…")
        }
      }.padding(24).textSelection(.enabled)
    }
    .background(FormaTheme.canvas)
    .navigationTitle("Privacy & your data").navigationBarTitleDisplayMode(.inline)
    .task {
      do {
        guard let url = Bundle.main.url(forResource: "legal", withExtension: "json") else {
          throw AppFailure("Missing privacy notice")
        }
        notice = try JSONDecoder().decode(LegalBundle.self, from: Data(contentsOf: url))
          .nativeGuestNotice
      } catch { unavailable = true }
    }
  }
}

private struct LegalBundle: Decodable { var nativeGuestNotice: LegalNotice }
private struct LegalNotice: Decodable {
  var title: String
  var version: String
  var effective: String
  var summary: String
  var blocks: [LegalBlock]
}
private struct LegalBlock: Decodable {
  var h: String?
  var h3: String?
  var p: String?
  var ul: [String]?
}
