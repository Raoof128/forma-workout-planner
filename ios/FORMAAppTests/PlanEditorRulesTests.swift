import FORMACore
import XCTest

@testable import FORMA

/// The Plan tab's routine editing rules (PlanEditorSupport.swift), checked
/// without a view.
final class PlanEditorRulesTests: XCTestCase {
  private func entry(_ id: String, group: String? = nil) -> Prescription {
    Prescription(exerciseId: "squat", entryId: id, groupId: group)
  }

  private func routine(_ id: String, archived: Bool = false) -> Routine {
    Routine(id: id, name: id, archivedAt: archived ? 1 : nil)
  }

  // MARK: Validation placement

  func testNameProblemsBelongToTheDetailsSection() {
    var draft = Routine(name: "  ", exercises: [entry("a")])
    var issues = RoutineDraftRules.issues(for: draft, targetError: nil) { _ in "load_reps" }
    XCTAssertEqual(issues.details, "Give your routine a name.")
    XCTAssertNil(issues.exercises)
    XCTAssertEqual(issues.first, issues.details)

    draft.name = String(repeating: "a", count: 61)
    issues = RoutineDraftRules.issues(for: draft, targetError: nil) { _ in "load_reps" }
    XCTAssertEqual(issues.details, "Use a shorter routine name, up to 60 characters.")
  }

  func testExerciseProblemsBelongToTheExercisesSection() {
    var draft = Routine(name: "Legs")
    XCTAssertEqual(
      RoutineDraftRules.issues(for: draft, targetError: nil) { _ in nil }.exercises,
      "Add at least one exercise.")

    draft.exercises = [Prescription(exerciseId: "squat", reps: 60, perSide: true)]
    let issues = RoutineDraftRules.issues(for: draft, targetError: nil) { _ in "load_reps" }
    XCTAssertNil(issues.details)
    XCTAssertEqual(
      issues.exercises, "Use up to 50 reps per side so each set totals no more than 100 reps.")

    draft.exercises = [entry("a")]
    XCTAssertEqual(
      RoutineDraftRules.issues(for: draft, targetError: "Squat: Enter a valid weight.") { _ in
        "load_reps"
      }.exercises, "Squat: Enter a valid weight.")
  }

  func testBothSectionsReportAtOnce() {
    let draft = Routine(name: "")
    let issues = RoutineDraftRules.issues(for: draft, targetError: nil) { _ in nil }
    XCTAssertNotNil(issues.details)
    XCTAssertNotNil(issues.exercises)
  }

  func testAValidDraftHasNoIssues() {
    let draft = Routine(name: "Legs", exercises: [entry("a")])
    XCTAssertNil(RoutineDraftRules.issues(for: draft, targetError: nil) { _ in "load_reps" }.first)
  }

  // MARK: Estimated time

  func testMinutesStepOnAFiveMinuteGrid() {
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(45, up: true), 50)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(45, up: false), 40)
    // Off-grid values snap to the next mark instead of drifting.
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(47, up: true), 50)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(47, up: false), 45)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(1, up: true), 5)
    // The floor holds without pushing a smaller stored value up.
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(5, up: false), 5)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(3, up: false), 3)
  }

  func testLongSessionsMoveInQuarterHoursWithinTheSchemaBound() {
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(120, up: true), 135)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(135, up: false), 120)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(120, up: false), 115)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(995, up: true), 1000)
    XCTAssertEqual(RoutineDraftRules.steppedMinutes(1000, up: true), 1000)
  }

  // MARK: Moves and supersets

  func testMoveSwapsOnePlaceAndStopsAtTheEnds() {
    var list = [entry("a"), entry("b"), entry("c")]
    XCTAssertTrue(RoutineDraftRules.move(&list, id: "b", by: -1))
    XCTAssertEqual(list.map(\.id), ["b", "a", "c"])
    XCTAssertFalse(RoutineDraftRules.move(&list, id: "b", by: -1))
    XCTAssertFalse(RoutineDraftRules.move(&list, id: "c", by: 1))
    XCTAssertFalse(RoutineDraftRules.move(&list, id: "missing", by: 1))
  }

  func testSplittingASupersetUnlinksItAndSaysSo() {
    var list = [entry("a", group: "g"), entry("b", group: "g"), entry("c")]
    XCTAssertFalse(RoutineDraftRules.preserveValidGroups(&list))
    RoutineDraftRules.move(&list, id: "b", by: 1)
    XCTAssertTrue(RoutineDraftRules.preserveValidGroups(&list))
    XCTAssertTrue(list.allSatisfy { $0.groupId == nil })
  }

  // MARK: Routine list

  func testDuplicateMatchesTheWeb() {
    var source = Routine(id: "r1", name: String(repeating: "é", count: 70), archivedAt: 5)
    source.exercises = [entry("a", group: "g")]
    let copy = RoutineDraftRules.duplicate(source, id: "r2")
    XCTAssertEqual(copy.id, "r2")
    XCTAssertEqual(copy.name, String(repeating: "é", count: 55) + " copy")
    XCTAssertNil(copy.archivedAt)
    XCTAssertEqual(copy.exercises, source.exercises)
    XCTAssertLessThanOrEqual(copy.name.utf16.count, RoutineDraftRules.maxNameLength)
  }

  func testDuplicateNeverSplitsAUTF16Pair() {
    let source = Routine(name: String(repeating: "💪", count: 40))
    let copy = RoutineDraftRules.duplicate(source)
    XCTAssertEqual(copy.name, String(repeating: "💪", count: 27) + " copy")
  }

  func testReorderKeepsArchivedRoutinesInTheirSlots() {
    let all = [routine("a"), routine("x", archived: true), routine("b"), routine("c")]
    let next = RoutineDraftRules.reorder(all, visibleIDs: ["c", "a", "b"])
    XCTAssertEqual(next?.map(\.id), ["c", "x", "a", "b"])
  }

  func testReorderOfASubsetLeavesTheOthersInPlace() {
    // The web's reorderRoutines: routines outside the moved set keep their slots.
    let all = [routine("a"), routine("b"), routine("c")]
    XCTAssertEqual(RoutineDraftRules.reorder(all, visibleIDs: ["c", "a"])?.map(\.id), ["c", "b", "a"])
  }

  func testReorderRefusesAChangedVisibleSet() {
    let all = [routine("a"), routine("b")]
    XCTAssertNil(RoutineDraftRules.reorder(all, visibleIDs: ["b", "z"]))
    XCTAssertNil(RoutineDraftRules.reorder(all, visibleIDs: ["a", "a"]))
  }

  // MARK: Library filter motion

  func testOnlySmallFilterChangesAnimate() {
    let all = (0..<1_411).map { "e\($0)" }
    let chest = Array(all.prefix(200))
    let back = Array(all.dropFirst(200).prefix(200))
    XCTAssertFalse(LibraryFilterMotion.animates(from: all, to: chest))
    // Equal counts can still swap hundreds of rows.
    XCTAssertEqual(LibraryFilterMotion.changeCount(from: chest, to: back), 400)
    XCTAssertFalse(LibraryFilterMotion.animates(from: chest, to: back))
    XCTAssertTrue(LibraryFilterMotion.animates(from: chest, to: Array(chest.prefix(150))))
  }
}
