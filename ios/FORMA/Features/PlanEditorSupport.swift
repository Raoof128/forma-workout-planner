import FORMACore
import SwiftUI
import UIKit

/// What stops a routine draft from saving, split by the section that shows it,
/// so each message sits next to the field it is about (HIG Writing: "as close
/// to the problem as possible").
struct RoutineDraftIssues: Equatable {
  /// Name and description problems, shown under "Make it yours".
  var details: String?
  /// Exercise, cue, per-side and target problems, shown under Exercises.
  var exercises: String?
  /// The message Save reads out while it is disabled.
  var first: String? { details ?? exercises }
}

/// Routine editing rules that do not need a view, kept here so they are tested
/// directly (FORMAAppTests/PlanEditorRulesTests).
enum RoutineDraftRules {
  static let maxExercises = 100
  static let maxRoutines = 200
  static let maxNameLength = 60
  static let maxDescriptionLength = 500
  static let maxCueLength = 140
  /// The workspace schema's bound for `Routine.minutes` (`src/storage.js`).
  static let minutesRange = 1...1000

  /// `metric` looks up an exercise's metric; `targetError` is the first invalid
  /// typed target, already prefixed with its exercise.
  static func issues(
    for draft: Routine, targetError: String?, metric: (String) -> String?
  ) -> RoutineDraftIssues {
    var issues = RoutineDraftIssues()
    if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      issues.details = "Give your routine a name."
    } else if draft.name.utf16.count > maxNameLength {
      issues.details = "Use a shorter routine name, up to 60 characters."
    } else if draft.description.utf16.count > maxDescriptionLength {
      issues.details = "Use a shorter description, up to 500 characters."
    }
    if draft.exercises.isEmpty {
      issues.exercises = "Add at least one exercise."
    } else if draft.exercises.contains(where: { ($0.note?.utf16.count ?? 0) > maxCueLength }) {
      issues.exercises = "Exercise cues can contain up to 140 characters."
    } else if draft.exercises.contains(where: {
      $0.perSide && metric($0.exerciseId) == "load_reps"
        && ($0.reps > 50 || ($0.repsMax ?? 0) > 50)
    }) {
      issues.exercises = "Use up to 50 reps per side so each set totals no more than 100 reps."
    } else if let targetError {
      issues.exercises = targetError
    }
    return issues
  }

  /// The Estimated time stepper stays on a 5-minute grid: a value off the grid
  /// (from the web or an older build) snaps to the next mark. Past two hours it
  /// moves in quarter hours so a long session is a few taps, not dozens.
  static func steppedMinutes(_ value: Int, up: Bool) -> Int {
    if up {
      let step = value >= 120 ? 15 : 5
      return min(minutesRange.upperBound, (value / step + 1) * step)
    }
    guard value > 5 else { return value }
    let step = value > 120 ? 15 : 5
    return max(5, ((value - 1) / step) * step)
  }

  /// Clears `groupId` on any superset a move or removal split apart. Returns
  /// true when a group was unlinked, so the screen can say so.
  @discardableResult
  static func preserveValidGroups(_ exercises: inout [Prescription]) -> Bool {
    var unlinked = false
    for group in Set(exercises.compactMap(\.groupId)) {
      let indices = exercises.indices.filter { exercises[$0].groupId == group }
      guard let first = indices.first, let last = indices.last else { continue }
      if indices.count < 2 || last - first + 1 != indices.count {
        for index in indices { exercises[index].groupId = nil }
        unlinked = true
      }
    }
    return unlinked
  }

  /// Moves the entry `id` one place up (`-1`) or down (`1`). The non-drag
  /// alternative for VoiceOver, Voice Control and the context menu.
  @discardableResult
  static func move(_ exercises: inout [Prescription], id: String, by offset: Int) -> Bool {
    guard let index = exercises.firstIndex(where: { $0.id == id }) else { return false }
    let target = index + offset
    guard exercises.indices.contains(target) else { return false }
    exercises.swapAt(index, target)
    return true
  }

  /// The web's duplicate (`duplicateRoutine` in src/App.jsx): a deep copy with
  /// a new ID, the name cut to 55 UTF-16 units plus " copy", never archived.
  static func duplicate(_ routine: Routine, id: String = UUID().uuidString) -> Routine {
    var copy = routine
    copy.id = id
    var name = ""
    for character in routine.name {
      guard name.utf16.count + String(character).utf16.count <= 55 else { break }
      name.append(character)
    }
    copy.name = "\(name) copy"
    copy.archivedAt = nil
    return copy
  }

  /// The web's reorder (`reorderRoutines` in src/App.jsx): only the visible
  /// routines trade places, and archived ones keep their slots. Nil when the
  /// visible set changed underneath the move.
  static func reorder(_ routines: [Routine], visibleIDs: [String]) -> [Routine]? {
    let moving = Set(visibleIDs)
    let slots = routines.indices.filter { moving.contains(routines[$0].id) }
    guard slots.count == visibleIDs.count, moving.count == visibleIDs.count else { return nil }
    let byID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
    var result = routines
    for (slot, id) in zip(slots, visibleIDs) {
      guard let routine = byID[id] else { return nil }
      result[slot] = routine
    }
    return result
  }
}

/// Exercise library filter motion. A filter change animates only when few rows
/// move; swapping hundreds of rows in one animated batch carries no spatial
/// meaning and risks dropped frames on a 1,411-row list (HIG Motion).
enum LibraryFilterMotion {
  static let animatedChangeLimit = 60

  /// Rows removed plus rows inserted between two result lists.
  static func changeCount(from old: [String], to new: [String]) -> Int {
    let overlap = Set(old).intersection(new).count
    return old.count + new.count - 2 * overlap
  }

  static func animates(from old: [String], to new: [String]) -> Bool {
    changeCount(from: old, to: new) <= animatedChangeLimit
  }
}

/// Save in a sheet is the one primary action: the iOS 26 prominent glass style
/// (HIG Toolbars), lime with an ink label like `PrimaryButtonStyle` (ink on
/// lime is 13.2:1; the system's white label on lime would be 1.2:1). Earlier
/// systems keep the semibold text button.
struct ProminentConfirmation: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.buttonStyle(.glassProminent).tint(FormaTheme.lime).foregroundStyle(FormaTheme.ink)
    } else {
      content.fontWeight(.semibold)
    }
  }
}

/// Reports a swipe-down that `interactiveDismissDisabled` refused, so the sheet
/// can offer its discard choice instead of rubber-banding with no explanation
/// (HIG Sheets; UIKit `presentationControllerDidAttemptToDismiss(_:)`). SwiftUI
/// has no dismiss-attempt API, so this wraps the presentation controller's
/// delegate and forwards everything else to SwiftUI's own.
struct SheetDismissAttemptObserver: UIViewControllerRepresentable {
  let onAttempt: () -> Void

  func makeUIViewController(context: Context) -> ObserverController {
    ObserverController(onAttempt: onAttempt)
  }

  func updateUIViewController(_ controller: ObserverController, context: Context) {
    controller.onAttempt = onAttempt
    controller.install()
  }

  final class ObserverController: UIViewController {
    var onAttempt: () -> Void {
      didSet { proxy?.onAttempt = onAttempt }
    }
    private var proxy: DismissAttemptProxy?

    init(onAttempt: @escaping () -> Void) {
      self.onAttempt = onAttempt
      super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func loadView() {
      let view = UIView()
      view.isUserInteractionEnabled = false
      view.isAccessibilityElement = false
      self.view = view
    }

    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      install()
    }

    /// Wraps whatever delegate SwiftUI set; re-wraps if SwiftUI replaced it.
    func install() {
      guard let presentation = presentationController else { return }
      if let proxy, presentation.delegate === proxy { return }
      let proxy = DismissAttemptProxy(original: presentation.delegate, onAttempt: onAttempt)
      self.proxy = proxy
      presentation.delegate = proxy
    }
  }
}

/// Forwards every delegate call to SwiftUI's delegate, which it keeps alive
/// (the presentation controller holds its delegate weakly), and adds the
/// dismiss-attempt callback.
@MainActor
final class DismissAttemptProxy: NSObject, UIAdaptivePresentationControllerDelegate {
  // Read only on the main thread by UIKit's delegate dispatch; nonisolated so
  // the Objective-C forwarding overrides below can reach it.
  nonisolated(unsafe) private let original: (any UIAdaptivePresentationControllerDelegate)?
  var onAttempt: () -> Void

  init(original: (any UIAdaptivePresentationControllerDelegate)?, onAttempt: @escaping () -> Void) {
    self.original = original
    self.onAttempt = onAttempt
  }

  nonisolated override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || (original?.responds(to: selector) ?? false)
  }

  nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
    if let original, original.responds(to: selector) { return original }
    return super.forwardingTarget(for: selector)
  }

  func presentationControllerDidAttemptToDismiss(_ controller: UIPresentationController) {
    original?.presentationControllerDidAttemptToDismiss?(controller)
    onAttempt()
  }
}
