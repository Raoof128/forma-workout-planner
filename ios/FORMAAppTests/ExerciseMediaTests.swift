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

  func testEveryAnimationHasItsVideoAndStillAndThePhotosAreBundled() throws {
    let library = ExerciseMediaLibrary.shared
    XCTAssertEqual(library.animations.count, 32)
    for id in library.animations.keys {
      XCTAssertNotNil(ExerciseMediaLibrary.url(id, "mp4", in: "animations"), id)
      XCTAssertNotNil(ExerciseMediaLibrary.url(id, "heic", in: "animations"), id)
    }
    let photos = try XCTUnwrap(library.photos)
    XCTAssertEqual(photos.routines.count, 3)
    for photo in [photos.hero] + photos.routines {
      XCTAssertNotNil(ExerciseMediaLibrary.url(photo.file, "heic", in: "photos"), photo.file)
    }
    // Routine image indexes wrap like the web's three photo classes.
    XCTAssertEqual(library.routinePhoto(4)?.file, "routine-1")
    XCTAssertEqual(library.routinePhoto(-1)?.file, "routine-2")
  }

  /// Plan asks for all three routine photos at once; each must come back as a
  /// decoded bitmap of its full size, never left to decode when drawn.
  func testPhotosRequestedTogetherAllDecode() async throws {
    let photos = try XCTUnwrap(ExerciseMediaLibrary.shared.photos)
    let names = ([photos.hero] + photos.routines).map(\.file)
    let images = await withTaskGroup(of: (String, UIImage?).self) { group in
      for name in names {
        group.addTask { await (name, BundledImageCache.load("photos", name)) }
      }
      var images: [String: UIImage] = [:]
      for await (name, image) in group { images[name] = image }
      return images
    }
    for name in names {
      let image = try XCTUnwrap(images[name]?.cgImage, name)
      XCTAssertGreaterThanOrEqual(image.width, 512, name)
      XCTAssertNotNil(image.dataProvider?.data, "\(name) should already be a bitmap")
    }
  }

  func testTheDisplayFontIsRegistered() {
    XCTAssertNotNil(UIFont(name: FormaDisplayFont.name, size: 17))
  }
}
