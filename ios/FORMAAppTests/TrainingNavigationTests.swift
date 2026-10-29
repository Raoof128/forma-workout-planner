import FORMACore
import XCTest

@testable import FORMA

final class TrainingNavigationTests: XCTestCase {
  func testAccessibilityMotionSignalsAndExplicitOffRetainTheirPriority() {
    XCTAssertEqual(
      FormaMotionLevel(preference: .system, reduceMotion: false, prefersCrossFade: true), .minimal)
    XCTAssertEqual(
      FormaMotionLevel(preference: .system, reduceMotion: true, prefersCrossFade: false), .minimal)
    XCTAssertEqual(
      FormaMotionLevel(preference: .system, reduceMotion: false, prefersCrossFade: false), .full)
    XCTAssertEqual(
      FormaMotionLevel(preference: .off, reduceMotion: true, prefersCrossFade: true), .off)
    XCTAssertEqual(
      FormaMotionLevel(preference: .minimal, reduceMotion: false, prefersCrossFade: false), .minimal
    )
  }

  func testScrollNeedsSustainedMovementAndReversesBeforeReachingTheTop() {
    var state = TabBarScrollState()
    state.observe(offset: 100, limit: 1_000)
    state.observe(offset: 110, limit: 1_000)
    XCTAssertFalse(state.collapsed)
    state.observe(offset: 135, limit: 1_000)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 130, limit: 1_000)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 118, limit: 1_000)
    XCTAssertFalse(state.collapsed)
  }

  func testOverscrollAtTheBottomDoesNotLookLikeAnUpwardScroll() {
    var state = TabBarScrollState()
    state.observe(offset: 950, limit: 1_000)
    state.observe(offset: 1_000, limit: 1_000)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 1_090, limit: 1_000)
    state.observe(offset: 1_000, limit: 1_000)
    XCTAssertTrue(state.collapsed)
    state.observe(offset: 980, limit: 1_000)
    XCTAssertFalse(state.collapsed)
  }

  func testShortContentAndReturningToTheTopKeepNavigationExpanded() {
    var state = TabBarScrollState()
    state.observe(offset: 50, limit: 1_000)
    state.observe(offset: 100, limit: 1_000)
    state.observe(offset: -50, limit: 1_000)
    XCTAssertFalse(state.collapsed)
    state.observe(offset: 5, limit: 20)
    state.observe(offset: 15, limit: 20)
    XCTAssertFalse(state.collapsed)
  }

  @MainActor
  func testSelectingAnotherTabExpandsNavigationAndDropsTheOldScrollDirection() {
    let navigation = TrainingNavigation()
    navigation.observe(offset: 100, limit: 1_000)
    navigation.observe(offset: 150, limit: 1_000)
    XCTAssertTrue(navigation.collapsed)
    navigation.select(.you)
    XCTAssertEqual(navigation.selection, .you)
    XCTAssertFalse(navigation.collapsed)
    navigation.observe(offset: 200, limit: 1_000)
    XCTAssertFalse(navigation.collapsed)
  }

  @MainActor
  func testReselectingATabWithScreensPushedPopsToTheRootAndDoesNotScroll() {
    let navigation = TrainingNavigation()
    navigation.paths[.plan] = [.routine("push"), .guide("bench-press")]
    navigation.paths[.today] = [.session("s1")]
    navigation.observe(offset: 100, limit: 1_000)
    navigation.observe(offset: 150, limit: 1_000)
    XCTAssertTrue(navigation.collapsed)
    XCTAssertEqual(navigation.reselect(.plan), .poppedToRoot)
    XCTAssertEqual(navigation.paths[.plan], [])
    XCTAssertEqual(navigation.paths[.today], [.session("s1")], "Other tabs keep their screens")
    XCTAssertEqual(navigation.scrollToTopEvents[.plan, default: 0], 0)
    XCTAssertFalse(navigation.collapsed, "Re-tapping a tab brings the full bar back")
  }

  @MainActor
  func testReselectingATabAtItsRootScrollsToTheTop() {
    let navigation = TrainingNavigation()
    navigation.paths[.today] = []
    XCTAssertEqual(navigation.reselect(.today), .scrolledToTop)
    XCTAssertEqual(navigation.reselect(.today), .scrolledToTop)
    XCTAssertEqual(navigation.scrollToTopEvents[.today], 2)
    XCTAssertNil(navigation.scrollToTopEvents[.you], "Other tabs are untouched")
  }

  @MainActor
  func testTheSecondReselectionAfterAPopScrollsToTheTop() {
    let navigation = TrainingNavigation()
    XCTAssertEqual(navigation.reselect(.progress), .scrolledToTop, "No path yet means the root")
    navigation.paths[.progress] = [.session("s1")]
    XCTAssertEqual(navigation.reselect(.progress), .poppedToRoot)
    XCTAssertEqual(navigation.reselect(.progress), .scrolledToTop)
    XCTAssertEqual(navigation.scrollToTopEvents[.progress], 2)
  }

  @MainActor
  func testPoppingEverythingEmptiesEveryTabsPath() {
    let navigation = TrainingNavigation()
    navigation.paths[.today] = [.routine("push")]
    navigation.paths[.you] = [.privacy]
    navigation.popAllToRoot()
    XCTAssertTrue(navigation.paths.values.allSatisfy(\.isEmpty))
  }

  func testCountPhraseAgreesWithTheCount() {
    XCTAssertEqual(countPhrase(0, "routine"), "0 routines")
    XCTAssertEqual(countPhrase(1, "routine"), "1 routine")
    XCTAssertEqual(countPhrase(2, "exercise"), "2 exercises")
    XCTAssertEqual(countPhrase(1, "completed set"), "1 completed set")
  }
}

final class NextRoutineTests: XCTestCase {
  private let push = Routine(id: "push", name: "Push")
  private let pull = Routine(id: "pull", name: "Pull")
  private let legs = Routine(id: "legs", name: "Legs")
  private var rotation: [Routine] { [push, pull, legs] }

  func testWithoutRoutinesThereIsNothingToStart() {
    XCTAssertNil(NextRoutine.select(from: [], preferredID: nil, lastRoutineID: nil))
    XCTAssertNil(NextRoutine.select(from: [], preferredID: "push", lastRoutineID: "pull"))
  }

  func testWithoutHistoryTheFirstRoutineIsNext() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: nil, lastRoutineID: nil)?.id, "push")
  }

  func testTheRoutineAfterTheLastTrainedOneIsNext() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: nil, lastRoutineID: "push")?.id, "pull")
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: nil, lastRoutineID: "pull")?.id, "legs")
  }

  func testTheRotationWrapsAfterTheLastRoutine() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: nil, lastRoutineID: "legs")?.id, "push")
  }

  func testAnUnknownOrArchivedLastRoutineStartsTheRotationAgain() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: nil, lastRoutineID: "gone")?.id, "push")
    XCTAssertEqual(
      NextRoutine.select(from: [pull, legs], preferredID: nil, lastRoutineID: "push")?.id, "pull")
  }

  func testAChosenRoutineBeatsTheRotation() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: "legs", lastRoutineID: "push")?.id, "legs")
  }

  func testAChosenRoutineThatIsGoneFallsBackToTheRotation() {
    XCTAssertEqual(
      NextRoutine.select(from: rotation, preferredID: "gone", lastRoutineID: "push")?.id, "pull")
  }

  func testASingleRoutineIsAlwaysNext() {
    XCTAssertEqual(
      NextRoutine.select(from: [push], preferredID: nil, lastRoutineID: "push")?.id, "push")
  }
}
