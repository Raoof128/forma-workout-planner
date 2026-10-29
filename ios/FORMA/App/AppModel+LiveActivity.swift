import FORMACore
import FORMASurfaces
import Foundation
import UIKit

/// The workout Live Activity (see `WorkoutLiveActivityController`) and the buttons on it.
extension AppModel {
  /// What the Lock Screen should show for the saved workspace right now, or nil for nothing.
  private var liveActivityTarget: WorkoutLiveActivityController.Target? {
    guard liveActivityEnabled, let session = workspace?.active else { return nil }
    return .init(
      sessionID: session.id, ownerEpoch: widgets.epoch,
      state: WorkoutLiveActivityMapping.state(
        for: session, exerciseName: { exercise($0)?.name }, now: .now))
  }

  /// A workspace that has not opened yet is not "no workout": on a cold launch the scene becomes
  /// active while `load()` is still running, and ending the activity then would only restart it.
  /// A workspace that closes (sign-out, account switch) or fails to open does end it.
  func syncLiveActivity(force: Bool = false, workspaceClosed: Bool = false) {
    if workspace == nil, loadFailure == nil, !workspaceClosed { return }
    liveActivity.sync(liveActivityTarget, force: force)
  }

  /// A press on the Lock Screen or Dynamic Island. The system runs the intent in this process,
  /// possibly in a launch that never showed a window, so the saved workspace may still be opening.
  /// A press for a workout that is no longer the active one does nothing.
  func perform(_ action: LiveActivityAction) async {
    await finishOpening()
    guard let session = workspace?.active else { return }
    switch action {
    case .completeSet(let id):
      guard id == session.id else { return }
      // The same engine path as the in-app tick, on the set the workout screen would show next.
      let entry = WorkoutEngine.resumeIndex(session)
      guard session.exercises.indices.contains(entry),
        let set = session.exercises[entry].sets.firstIndex(where: { !$0.done })
      else { return }
      guard await toggleSet(entry: entry, set: set) else { return }
    case .skipRest(let id):
      guard id == session.id, WorkoutEngine.isResting(session, now: Self.now) else { return }
      guard await commit(forActiveSession: id, { $0 = try WorkoutEngine.skipRest(in: $0) })
      else { return }
    }
    // The workout screen may not be open, so the rest-end notification is brought in line here.
    await RestReminder.shared.sync(
      restEnd: workspace?.active?.restEnd, muted: workspace?.profile.muted ?? false,
      appActive: UIApplication.shared.applicationState == .active)
  }

  /// Waits (briefly) for the workspace when a button press launched the app.
  private func finishOpening() async {
    if workspace == nil { await load() }
    var waited = 0
    while workspace == nil, loading, waited < 100 {
      try? await Task.sleep(for: .milliseconds(100))
      waited += 1
    }
  }
}
