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
        try render(
          active, family: family, size: size, scheme: scheme, name: "private-\(name)",
          privacy: true)
      }
      for state in [TrainingSnapshot.State.empty, .hidden, .unavailable, .stale] {
        let fallback = TrainingSnapshot(
          epoch: "test", generatedAt: .now, expiresAt: .now, state: state)
        for (family, name, size) in families {
          try render(
            fallback, family: family, size: size, scheme: scheme,
            name: "\(state.rawValue)-\(name)")
        }
      }
      for (family, name, size) in families
      where name == "small" || name == "medium" || name == "large" {
        try render(
          longName, family: family, size: size,
          scheme: scheme, name: "\(name)-accessibility-text", dynamicType: .accessibility3)
        try render(
          longName, family: family, size: size,
          scheme: scheme, name: "\(name)-largest-accessibility-text", dynamicType: .accessibility5)
      }
    }
  }

  private func render(
    _ snapshot: TrainingSnapshot, family: WidgetFamily, size: CGSize,
    scheme: ColorScheme, name: String, focus: TrainingFocus = .nextSession,
    privacy: Bool = false, dynamicType: DynamicTypeSize = .large
  ) throws {
    let view = TrainingWidgetView(
      entry: TrainingEntry(date: .now, snapshot: snapshot, focus: focus), reviewFamily: family
    )
    .environment(\.colorScheme, scheme)
    .environment(\.dynamicTypeSize, dynamicType)
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
  }
}
