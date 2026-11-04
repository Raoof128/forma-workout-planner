import FORMACore
import Foundation
import Observation

/// The profile draft outlives a local save while an optional account-name request is pending.
/// Keep its acknowledged base separate from newer text so a slow reply cannot dismiss edits.
@MainActor @Observable
final class ProfileEditorState {
  var name = ""
  var goal = 4
  var rest = 90
  private(set) var original: Profile?
  private(set) var saving = false
  private(set) var needsAccountRetry = false
  private(set) var failure: String?
  private var owner: String?

  var changed: Bool {
    guard let original else { return false }
    return name != original.name || goal != original.goal || rest != original.restSeconds
  }

  var invalid: String? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "Enter a display name."
    }
    if name.utf16.count > 50 { return "Use a shorter display name, up to 50 characters." }
    return nil
  }

  func load(_ profile: Profile, owner: String) {
    guard original == nil else { return }
    original = profile
    self.owner = owner
    name = profile.name
    goal = profile.goal
    rest = profile.restSeconds
  }

  /// Returns true only when all submitted work succeeded and no newer draft would be lost.
  /// The name-sync seam lets hosted tests suspend or fail a synthetic remote request.
  func save(
    in model: AppModel,
    syncName: @MainActor (String) async throws -> Void
  ) async -> Bool {
    guard !saving, !model.busy, invalid == nil, let original, let owner else { return false }
    guard owner == model.storeIdentity else {
      failure = "Your training space changed. Reopen your current profile before saving."
      return false
    }
    let submittedName = name
    let updatedName = submittedName.trimmingCharacters(in: .whitespacesAndNewlines)
    let submittedGoal = goal
    let submittedRest = rest
    saving = true
    failure = nil
    defer { saving = false }

    let current = model.workspace?.profile
    var saved =
      current?.name == updatedName && current?.goal == submittedGoal
      && current?.restSeconds == submittedRest
    if !saved {
      saved = await model.commit { value in
        guard value.profile == original else {
          throw AppFailure(
            "Your profile changed while this editor was open. Keep this draft open or reopen your current profile before saving."
          )
        }
        value.profile.name = updatedName
        value.profile.goal = submittedGoal
        value.profile.restSeconds = submittedRest
      }
    }
    // A dismissed owner's queued edit cannot clear an error belonging to the new space.
    guard owner == model.storeIdentity else { return false }
    guard saved, let acknowledged = model.workspace?.profile else {
      failure =
        model.errorMessage ?? "Your profile has not been saved. Keep this draft open and try again."
      // The sheet already shows the failure; do not replay a stale root alert on dismissal.
      model.errorMessage = nil
      return false
    }
    // Advance the conflict base before any network await, including a failed name update.
    // A changed retry must compare against our own acknowledged save, not the old profile.
    self.original = acknowledged
    do {
      try await syncName(updatedName)
    } catch {
      needsAccountRetry = true
      failure =
        "Your training profile was saved, but your account name could not be synced: \(error.accountMessage) Save again to retry."
      return false
    }
    guard owner == model.storeIdentity else { return false }
    needsAccountRetry = false
    guard name == submittedName, goal == submittedGoal, rest == submittedRest else {
      failure = "Newer profile edits are still unsaved. Save again to keep them."
      return false
    }
    name = acknowledged.name
    return true
  }
}
