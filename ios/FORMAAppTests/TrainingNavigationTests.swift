import XCTest

@testable import FORMA

final class TrainingNavigationTests: XCTestCase {
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
}
