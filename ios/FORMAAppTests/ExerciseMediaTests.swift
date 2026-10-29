import UIKit
import XCTest

@testable import FORMA

/// The website's media, bundled by scripts/build-ios-media.py, is present,
/// readable and cut to the right cell.
@MainActor
final class ExerciseMediaTests: XCTestCase {
  func testIndexCoversTheWebsiteMediaAndEveryFileIsBundled() throws {
    let library = ExerciseMediaLibrary.shared
    XCTAssertEqual(library.images.count, 1_411)
    XCTAssertEqual(library.demos.count, 22)
    for name in library.sheets.keys {
      XCTAssertNotNil(ExerciseMediaLibrary.url(name, "heic", in: "sheets"), name)
    }
    for (id, demo) in library.demos {
      XCTAssertNotNil(library.clips[demo.clip], id)
      XCTAssertNotNil(ExerciseMediaLibrary.url(demo.clip, "mp4", in: "demos"), id)
      XCTAssertNotNil(ExerciseMediaLibrary.url(demo.clip, "jpg", in: "demos"), id)
      let clip = try XCTUnwrap(library.clips[demo.clip])
      XCTAssertNotNil(library.sources[clip.source], "\(id) needs a credited source")
    }
  }

  func testAnIllustrationIsCutFromItsSheetAtTheCataloguedSize() async throws {
    let illustration = try XCTUnwrap(ExerciseMediaLibrary.shared.images["bench"])
    let image = await ExerciseIllustrationLoader.load("bench", illustration)
    let cell = try XCTUnwrap(image?.cgImage)
    XCTAssertEqual(Double(cell.width), illustration.width, accuracy: 2)
    XCTAssertEqual(Double(cell.height), illustration.height, accuracy: 2)
  }

  func testTheDisplayFontIsRegistered() {
    XCTAssertNotNil(UIFont(name: FormaDisplayFont.name, size: 17))
  }
}
