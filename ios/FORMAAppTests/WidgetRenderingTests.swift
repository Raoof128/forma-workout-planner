import FORMACore
import FORMASurfaces
import SwiftUI
import UIKit
import WidgetKit
import XCTest

@testable import FORMA

/// Exports the actual shared widget views, not system placement/protection proof.
@MainActor
final class WidgetRenderingTests: XCTestCase {
  func testAllWidgetFamiliesRenderSavedAndFallbackStates() throws {
    let workspace: Workspace = try AppModel.resource("seed-workspace", as: Workspace.self)
    let saved = WidgetSnapshotBridge.project(
      workspace, sharing: true, epoch: "synthetic-render", at: .now)
    let families: [(WidgetFamily, String, CGSize)] = [
      (.systemSmall, "small", CGSize(width: 170, height: 170)),
      (.systemMedium, "medium", CGSize(width: 360, height: 170)),
      (.systemLarge, "large", CGSize(width: 360, height: 376)),
      (.accessoryCircular, "circular", CGSize(width: 76, height: 76)),
      (.accessoryRectangular, "rectangular", CGSize(width: 172, height: 76)),
      (.accessoryInline, "inline", CGSize(width: 240, height: 30)),
    ]
    var active = saved
    active.active = .init(
      id: "synthetic-active", name: "Upper body strength", completedSets: 3, totalSets: 18)
    var completed = saved
    completed.week = .init(
      sessions: 4, goal: 4, days: [true, true, false, true, true, false, false])
    var longName = saved
    longName.routine?.name = "Strength, stability and conditioning for the whole body"
    for scheme in [ColorScheme.light, .dark] {
      for (family, name, size) in families {
        try render(saved, family: family, size: size, scheme: scheme, name: "saved-\(name)")
        try render(active, family: family, size: size, scheme: scheme, name: "active-\(name)")
        try render(
          completed, family: family, size: size, scheme: scheme, name: "completed-\(name)",
          focus: .week)
        try render(
          longName, family: family, size: size, scheme: scheme, name: "long-name-\(name)")
        // Wg-H1: the privacy message must survive system redaction, in every family.
        let privacy = try render(
          active, family: family, size: size, scheme: scheme, name: "private-\(name)",
          privacy: true)
        XCTAssertGreaterThan(
          legibleInk(in: privacy, scheme: scheme), Self.minimumInk,
          "privacy fallback is redacted: \(name) \(scheme)")
      }
      for state in [TrainingSnapshot.State.empty, .hidden, .unavailable, .stale] {
        let fallback = TrainingSnapshot(
          epoch: "test", generatedAt: .now, expiresAt: .now, state: state)
        for (family, name, size) in families {
          let image = try render(
            fallback, family: family, size: size, scheme: scheme,
            name: "\(state.rawValue)-\(name)")
          XCTAssertGreaterThan(
            legibleInk(in: image, scheme: scheme), Self.minimumInk,
            "\(state.rawValue) fallback is blank: \(name) \(scheme)")
        }
      }
      // Wg-H2: the locked-device tile has its own copy and must render too.
      let locked = TrainingSnapshot.unavailable(at: .now)
      for (family, name, size) in families {
        let image = try render(
          locked, family: family, size: size, scheme: scheme, name: "locked-\(name)",
          awaitingUnlock: true)
        XCTAssertGreaterThan(legibleInk(in: image, scheme: scheme), Self.minimumInk, name)
      }
      for (family, name, size) in families
      where name == "small" || name == "medium" || name == "large" {
        let sizes: [(DynamicTypeSize, String)] = [
          (.xLarge, "xlarge"), (.xxLarge, "xxlarge"), (.xxxLarge, "xxxlarge"),
          (.accessibility3, "accessibility-text"),
          (.accessibility5, "largest-accessibility-text"),
        ]
        for (type, label) in sizes {
          try render(
            longName, family: family, size: size,
            scheme: scheme, name: "\(name)-\(label)", dynamicType: type)
          // Wg-M5: fallbacks honour the large sizes too, not only ready content.
          for state in [TrainingSnapshot.State.hidden, .empty, .stale, .unavailable] {
            let image = try render(
              TrainingSnapshot(epoch: "test", generatedAt: .now, expiresAt: .now, state: state),
              family: family, size: size, scheme: scheme,
              name: "\(state.rawValue)-\(name)-\(label)", dynamicType: type)
            XCTAssertGreaterThan(
              legibleInk(in: image, scheme: scheme), Self.minimumInk,
              "\(state.rawValue) \(name) \(label)")
          }
        }
      }
      // Wg-M6: tinted and vibrant renderings keep the full matrix of data states legible.
      for mode in [WidgetRenderingMode.accented, .vibrant] {
        for (family, name, size) in families {
          for (label, value) in [("saved", saved), ("active", active)] {
            let image = try render(
              value, family: family, size: size, scheme: scheme,
              name: "\(label)-\(name)-\(mode)", renderingMode: mode)
            XCTAssertGreaterThan(
              legibleInk(in: image, scheme: scheme), Self.minimumInk, "\(label) \(name) \(mode)")
          }
        }
      }
    }
  }

  /// Proves the harness would catch the original H-1 mistake: content marked privacy sensitive
  /// is drawn as placeholders under `.redacted(reason: .privacy)`, and unmarked content is not.
  func testRendererRedactsOnlyPrivacySensitiveContent() throws {
    for scheme in [ColorScheme.light, .dark] {
      func image(sensitive: Bool) throws -> UIImage {
        let view = Text("Training is private").font(.headline)
          .privacySensitive(sensitive)
          .redacted(reason: .privacy)
          .environment(\.colorScheme, scheme)
          .frame(width: 200, height: 40)
          .background(scheme == .dark ? Color.black : Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
      }
      XCTAssertLessThan(
        legibleInk(in: try image(sensitive: true), scheme: scheme), Self.minimumInk,
        "sensitive content should render as placeholders (\(scheme))")
      XCTAssertGreaterThan(
        legibleInk(in: try image(sensitive: false), scheme: scheme), Self.minimumInk,
        "unmarked content should stay readable (\(scheme))")
    }
  }

  // Strong contrast against the flat test background: glyph strokes, not translucent
  // redaction placeholders. Counted at 3x, so real text is in the hundreds.
  private static let minimumInk = 30

  private func legibleInk(in image: UIImage, scheme: ColorScheme) -> Int {
    guard let cgImage = image.cgImage else { return 0 }
    let width = cgImage.width
    let height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return 0 }
    let background: Double = scheme == .dark ? 0 : 1
    var count = 0
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let luma =
        (0.299 * Double(pixels[offset]) + 0.587 * Double(pixels[offset + 1])
          + 0.114 * Double(pixels[offset + 2])) / 255
      if abs(luma - background) > 0.5 { count += 1 }
    }
    return count
  }

  @discardableResult
  private func render(
    _ snapshot: TrainingSnapshot, family: WidgetFamily, size: CGSize,
    scheme: ColorScheme, name: String, focus: TrainingFocus = .nextSession,
    privacy: Bool = false, dynamicType: DynamicTypeSize = .large,
    awaitingUnlock: Bool = false, renderingMode: WidgetRenderingMode = .fullColor
  ) throws -> UIImage {
    let view = TrainingWidgetView(
      entry: TrainingEntry(
        date: .now, snapshot: snapshot, focus: focus, awaitingUnlock: awaitingUnlock),
      reviewFamily: family
    )
    .environment(\.colorScheme, scheme)
    .environment(\.dynamicTypeSize, dynamicType)
    .environment(\.widgetRenderingMode, renderingMode)
    .redacted(reason: privacy ? .privacy : [])
    .padding(family == .systemSmall || family == .systemMedium || family == .systemLarge ? 16 : 0)
    .frame(width: size.width, height: size.height)
    .background(scheme == .dark ? Color.black : Color.white)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    let image = try XCTUnwrap(renderer.uiImage)
    XCTAssertEqual(image.size, size)
    let attachment = XCTAttachment(
      data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
    attachment.name = "widget-view-\(scheme == .dark ? "dark" : "light")-\(name)"
    attachment.lifetime = .keepAlways
    add(attachment)
    return image
  }
}
