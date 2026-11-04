import FORMACore
import Foundation
import XCTest

@testable import FORMA

/// The root alert names what failed, and never shows system error wording.
@MainActor
final class RootFailureTests: XCTestCase {
  func testSystemErrorWordingIsLeftOut() {
    let system = NSError(domain: NSCocoaErrorDomain, code: 512)
    XCTAssertNil(AppModel.ownWording(system))
    XCTAssertEqual(
      AppModel.failureMessage("This change was not saved.", system), "This change was not saved.")
  }

  func testFormasOwnExplanationIsKept() {
    XCTAssertEqual(
      AppModel.failureMessage(
        "This change was not saved.", AppFailure("Reopen your active session.")),
      "This change was not saved. Reopen your active session.")
    XCTAssertEqual(
      AppModel.failureMessage("This change was not saved.", FormaError.noActiveWorkout),
      "This change was not saved. There is no active workout.")
  }

  func testAReportedTitleBelongsOnlyToItsOwnMessage() {
    let model = AppModel()
    XCTAssertNil(model.errorTitle, "No failure, no title")
    model.reportFailure("Couldn’t delete your training", "Nothing on this iPhone was deleted.")
    XCTAssertEqual(model.errorTitle, "Couldn’t delete your training")
    XCTAssertEqual(model.errorMessage, "Nothing on this iPhone was deleted.")
    // A later save failure replaces the message; the old title must not label it.
    model.errorMessage = "This change was not saved. Your last saved workout is intact."
    XCTAssertNil(model.errorTitle)
    model.errorMessage = nil
    XCTAssertNil(model.errorTitle)
  }
}
