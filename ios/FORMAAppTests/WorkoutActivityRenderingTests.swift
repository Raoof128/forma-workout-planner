import FORMASurfaces
import SwiftUI
import UIKit
import XCTest

@testable import FORMA

/// Renders the real Lock Screen view. It proves the 160 pt height budget and that no state is
/// blank; how the system places, tints and redacts the activity is a device gate.
@MainActor
final class WorkoutActivityRenderingTests: XCTestCase {
  private let now = Date.now

  private func state(
    exercise: String = "Incline dumbbell press", rest: Rest = .none, allDone: Bool = false
  ) -> WorkoutActivityState {
    WorkoutActivityState(
      .init(
        sessionID: "s1", title: "Upper body strength", exercise: exercise, exerciseIndex: 1,
        exerciseCount: 5, exerciseDoneSets: allDone ? 4 : 2, exerciseSetCount: 4,
        doneSets: allDone ? 18 : 7, totalSets: 18, startedAt: now.addingTimeInterval(-1_800),
        restEnd: rest == .running ? now.addingTimeInterval(75) : nil,
        restPausedSeconds: rest == .paused ? 45 : nil, restSeconds: 90),
      now: now)
  }

  enum Rest { case none, running, paused }

  private func render(
    _ value: WorkoutActivityState, scheme: ColorScheme, type: DynamicTypeSize = .large,
    stale: Bool = false
  ) throws -> UIImage {
    let view = WorkoutLockScreenView(sessionID: "s1", state: value, isStale: stale)
      .environment(\.colorScheme, scheme)
      .environment(\.dynamicTypeSize, type)
      .frame(width: 360)
      .background(scheme == .dark ? Color.black : Color.white)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    return try XCTUnwrap(renderer.uiImage)
  }

  func testLockScreenCardFitsTheHeightBudgetAtTheDefaultSizeInEveryState() throws {
    let states: [(String, WorkoutActivityState, Bool)] = [
      ("working", state(), false),
      ("resting", state(rest: .running), false),
      ("rest over", state(rest: .running), true),
      ("paused", state(rest: .paused), false),
      ("all done", state(allDone: true), false),
      ("idle stale", state(), true),
      (
        "long name",
        state(exercise: String(repeating: "Romanian deadlift ", count: 8)), false
      ),
    ]
    for scheme in [ColorScheme.light, .dark] {
      for (name, value, stale) in states {
        let image = try render(value, scheme: scheme, stale: stale)
        XCTAssertLessThanOrEqual(
          image.size.height, 160, "\(name) is taller than the Lock Screen allows (\(scheme))")
        XCTAssertGreaterThan(image.size.height, 60, "\(name) rendered empty (\(scheme))")
        let attachment = XCTAttachment(
          data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = "workout-activity-\(scheme == .dark ? "dark" : "light")-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
      }
    }
  }

  func testLargerTextStillRenders() throws {
    for type in [DynamicTypeSize.xxxLarge, .accessibility1, .accessibility5] {
      let image = try render(state(rest: .running), scheme: .dark, type: type)
      XCTAssertGreaterThan(image.size.height, 60, "\(type)")
    }
  }
}
