import SwiftUI
import UIKit
import XCTest

@testable import FORMA

/// The design system's contrast contract, checked on the real colours in all
/// four appearance variants: light, dark, and each with Increase Contrast.
@MainActor
final class FormaDesignSystemTests: XCTestCase {
  private struct Variant {
    let name: String
    let traits: UITraitCollection
  }

  private func traits(_ style: UIUserInterfaceStyle, _ contrast: UIAccessibilityContrast)
    -> UITraitCollection
  {
    UITraitCollection { mutable in
      mutable.userInterfaceStyle = style
      mutable.accessibilityContrast = contrast
    }
  }

  private lazy var variants: [Variant] = [
    Variant(name: "light", traits: traits(.light, .normal)),
    Variant(name: "dark", traits: traits(.dark, .normal)),
    Variant(name: "light, increased contrast", traits: traits(.light, .high)),
    Variant(name: "dark, increased contrast", traits: traits(.dark, .high)),
  ]

  private func rgb(_ color: Color, _ traits: UITraitCollection) -> [Double] {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [Double(red), Double(green), Double(blue)]
  }

  /// WCAG 2.x relative luminance of sRGB components in 0...1.
  private func luminance(_ rgb: [Double]) -> Double {
    let linear = rgb.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
  }

  private func contrast(_ foreground: Color, _ background: Color, _ traits: UITraitCollection)
    -> Double
  {
    let first = luminance(rgb(foreground, traits))
    let second = luminance(rgb(background, traits))
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
  }

  private func assertContrast(
    _ foreground: Color, on background: Color, atLeast minimum: Double, _ label: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    for variant in variants {
      let ratio = contrast(foreground, background, variant.traits)
      XCTAssertGreaterThanOrEqual(
        ratio, minimum, "\(label) in \(variant.name): \(ratio)", file: file, line: line)
    }
  }

  func testTextTokensMeetAAOnBothSurfaces() {
    for (name, color) in [
      ("primary", FormaTheme.primary), ("secondary", FormaTheme.secondary),
      ("accent", FormaTheme.accent), ("error", FormaTheme.error),
    ] {
      assertContrast(color, on: FormaTheme.canvas, atLeast: 4.5, "\(name) on canvas")
      assertContrast(color, on: FormaTheme.surface, atLeast: 4.5, "\(name) on surface")
    }
  }

  func testInkLabelOnLimeMeetsAA() {
    assertContrast(FormaTheme.ink, on: FormaTheme.lime, atLeast: 4.5, "ink on lime")
  }

  /// WCAG 1.4.11: a stroke that carries meaning, and the edge of the lime
  /// button on a light canvas, need 3:1 against what is behind them.
  func testMeaningfulStrokesMeetNonTextContrast() {
    for (name, color) in [("boundary", FormaTheme.boundary), ("button edge", FormaTheme.accent)] {
      assertContrast(color, on: FormaTheme.canvas, atLeast: 3, "\(name) on canvas")
      assertContrast(color, on: FormaTheme.surface, atLeast: 3, "\(name) on surface")
    }
  }

  /// `line` is a decorative hairline. If it ever reaches 3:1 it has stopped
  /// being quiet and the two tokens have merged; keep them distinct.
  func testDecorativeLineStaysQuieterThanBoundary() {
    let traits = variants[0].traits
    XCTAssertLessThan(
      contrast(FormaTheme.line, FormaTheme.canvas, traits),
      contrast(FormaTheme.boundary, FormaTheme.canvas, traits))
  }

  func testHeroPanelColoursMeetAA() {
    assertContrast(FormaTheme.lime, on: FormaTheme.heroInk, atLeast: 4.5, "lime on hero")
    assertContrast(FormaTheme.heroDetail, on: FormaTheme.heroInk, atLeast: 4.5, "detail on hero")
    assertContrast(.white, on: FormaTheme.heroInk, atLeast: 4.5, "white on hero")
  }

  func testPaletteStaysInSyncWithTheTokensBuiltFromIt() {
    let light = variants[0].traits
    let dark = variants[1].traits
    XCTAssertEqual(rgb(FormaTheme.canvas, light), rgb(Color(hex: FormaPalette.canvasLight), light))
    XCTAssertEqual(rgb(FormaTheme.canvas, dark), rgb(Color(hex: FormaPalette.canvasDark), dark))
    XCTAssertEqual(rgb(FormaTheme.accent, dark), rgb(Color(hex: FormaPalette.lime), dark))
    XCTAssertEqual(rgb(FormaTheme.accent, light), rgb(Color(hex: FormaPalette.accentLight), light))
    XCTAssertEqual(
      rgb(FormaTheme.secondary, light), rgb(Color(hex: FormaPalette.secondaryLight), light))
    XCTAssertEqual(
      rgb(FormaTheme.secondary, dark), rgb(Color(hex: FormaPalette.secondaryDark), dark))
  }

  func testSpacingIsOnTheFourPointGridAndRadiiDescend() {
    for step in [
      FormaSpacing.xxs, FormaSpacing.xs, FormaSpacing.sm, FormaSpacing.md, FormaSpacing.lg,
      FormaSpacing.xl, FormaSpacing.xxl,
    ] {
      XCTAssertEqual(step.truncatingRemainder(dividingBy: 4), 0, "\(step)")
    }
    XCTAssertGreaterThan(FormaRadius.hero, FormaRadius.card)
    XCTAssertGreaterThan(FormaRadius.card, FormaRadius.control)
    XCTAssertGreaterThan(FormaRadius.control, FormaRadius.field)
  }

  /// Account outcomes have their own haptics so a sign-in never feels like a
  /// workout starting. The mapping is documented on `FormaHaptic`.
  func testAccountHapticsKeepTheirOwnMeaning() {
    XCTAssertEqual(FormaHaptic.accountSuccess.feedback, .success)
    XCTAssertEqual(FormaHaptic.accountWarning.feedback, .warning)
    XCTAssertEqual(FormaHaptic.accountFailure.feedback, .error)
    let training: [FormaHaptic] = [.started, .stopped, .selected, .undone, .added]
    for account in [FormaHaptic.accountSuccess, .accountSent, .accountRemoved] {
      for other in training {
        XCTAssertNotEqual(account.feedback, other.feedback, "\(account) vs \(other)")
      }
    }
  }

  /// The Today strip is 112pt tall and at most about 430pt wide. A 1536 px
  /// source decoded to roughly 6 MiB for it; the bundled asset must stay
  /// right-sized.
  func testTrainingEditorialIsRightSizedForTheStrip() throws {
    let image = try XCTUnwrap(UIImage(named: "TrainingEditorial", in: .main, compatibleWith: nil))
    XCTAssertLessThanOrEqual(image.size.width * image.scale, 1290)
    XCTAssertLessThanOrEqual(image.size.height * image.scale, 430)
    XCTAssertLessThanOrEqual(image.size.width, 440)
  }
}
