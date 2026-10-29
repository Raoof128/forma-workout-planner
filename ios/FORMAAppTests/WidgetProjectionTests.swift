import FORMACore
import FORMASurfaces
import Foundation
import XCTest

@testable import FORMA

@MainActor
final class WidgetProjectionTests: XCTestCase {
  private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
  private func session(_ id: String, _ text: String) -> WorkoutSession {
    WorkoutSession(
      id: id, name: "Private name", startedAt: date(text).timeIntervalSince1970 * 1000,
      notes: "PRIVATE NOTE NEVER SHARED", exercises: [], date: text)
  }

  func testSydneyMondayBoundaryFutureAndDuplicateTrainingDays() {
    // Sydney daylight time: Monday starts at Sunday 13:00 UTC.
    let now = date("2026-10-05T14:00:00Z")
    let history = [
      session("before", "2026-10-04T12:59:59Z"),
      session("monday", "2026-10-04T13:00:00Z"),
      session("same-day", "2026-10-04T14:00:00Z"),
      session("next-week", "2026-10-11T13:00:00Z"),
      session("future", "2026-10-06T13:00:00Z"),
    ]
    let workspace = Workspace(
      revision: 1, history: history, profile: Profile(name: "PRIVATE PROFILE", goal: 4))
    let snapshot = WidgetSnapshotBridge.project(workspace, sharing: true, epoch: "test", at: now)
    XCTAssertEqual(snapshot.week?.sessions, 2)
    XCTAssertEqual(snapshot.week?.days, [true, false, false, false, false, false, false])
    let before = date("2026-10-04T12:59:59Z")
    XCTAssertEqual(TrainingDate.completedThisWeek(history, at: before).map(\.id), ["before"])
  }

  func testDSTExpiryUsesCalendarMidnightRatherThan24Hours() {
    // Spring-forward day in Sydney lasts23 hours, fall-back day25.
    for (start, expected) in [
      ("2026-10-03T14:00:00Z", "2026-10-04T13:00:00Z"),
      ("2026-04-04T13:00:00Z", "2026-04-05T14:00:00Z"),
    ] {
      let snapshot = WidgetSnapshotBridge.project(
        nil, sharing: false, epoch: "test", at: date(start))
      XCTAssertEqual(snapshot.expiresAt, date(expected))
    }
  }

  func testProjectionExcludesProfileNotesHistoryHealthAndArchivedRoutines() throws {
    let now = date("2026-10-05T14:00:00Z")
    var workspace = Workspace(
      revision: 9,
      routines: [
        .init(id: "archived", name: "Hidden routine", archivedAt: 1),
        .init(id: "legacy/تمرین?&✓", name: "Next routine", minutes: 30),
      ],
      history: [session("history-private-id", "2026-10-04T13:00:00Z")],
      profile: Profile(name: "PRIVATE PROFILE", goal: 5))
    workspace.active = WorkoutSession(
      id: "active", name: "In progress", startedAt: 1,
      notes: "PRIVATE ACTIVE NOTE",
      exercises: [
        .init(
          exerciseId: "PRIVATE EXERCISE", note: "PRIVATE ENTRY NOTE",
          sets: [.init(done: true), .init(done: false)])
      ])
    let value = WidgetSnapshotBridge.project(workspace, sharing: true, epoch: "test", at: now)
    XCTAssertEqual(value.revision, 9)
    XCTAssertEqual(value.routine?.id, "legacy/تمرین?&✓")
    XCTAssertEqual(value.active?.completedSets, 1)
    XCTAssertEqual(value.active?.totalSets, 2)
    XCTAssertEqual(value.week?.goal, 5)
    let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    for secret in [
      "PRIVATE", "history-private-id", "Hidden routine", "heartRate", "email", "cookie", "token",
    ] {
      XCTAssertFalse(encoded.contains(secret), secret)
    }
    let hidden = WidgetSnapshotBridge.project(workspace, sharing: false, epoch: "test", at: now)
    XCTAssertEqual(hidden.state, .hidden)
    XCTAssertNil(hidden.routine)
    XCTAssertNil(hidden.active)
    XCTAssertNil(hidden.week)
    let reset = WidgetSnapshotBridge.project(
      Workspace(revision: 10, profile: Profile(name: "Guest", goal: 4)),
      sharing: true, epoch: "test", at: now)
    XCTAssertEqual(reset.state, .empty)
    XCTAssertNil(reset.active)
    XCTAssertEqual(
      WidgetSnapshotBridge.project(nil, sharing: true, epoch: "test", at: now).state, .unavailable)
  }

  func testOwnerEpochAndDeletedTargetsRejectOldWidgetLinks() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let model = AppModel()
    model.workspace = Workspace(
      revision: 0, routines: [.init(id: "legacy/تمرین?&✓", name: "Routine")],
      profile: Profile(name: "Test", goal: 4))
    model.widgets.configure(directory: directory, owner: "first")
    model.widgets.setSharing(true, workspace: model.workspace)
    let route = WidgetRoute.routine(id: "legacy/تمرین?&✓", epoch: model.widgets.epoch)
    XCTAssertEqual(model.widgetDestination(for: route), .routine("legacy/تمرین?&✓"))
    model.workspace?.routines = []
    XCTAssertEqual(model.widgetDestination(for: route), .unavailable)
    model.widgets.selectOwner("second")
    XCTAssertFalse(model.widgets.sharing)
    XCTAssertEqual(model.widgetDestination(for: route), .unavailable)
    XCTAssertEqual(model.widgetDestination(for: .plan), .plan)
  }

  func testFailedConsentRevocationDeletesOldOptInBeforeRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = WidgetSnapshotBridge()
    original.configure(directory: directory, owner: "test")
    original.setSharing(true, workspace: nil)
    XCTAssertTrue(original.sharing)
    let failedWrite = WidgetSnapshotBridge(writeConsent: { _, _ in
      throw CocoaError(.fileWriteNoPermission)
    })
    failedWrite.configure(directory: directory, owner: "test")
    failedWrite.setSharing(false, workspace: nil)
    XCTAssertFalse(failedWrite.sharing)
    let relaunched = WidgetSnapshotBridge()
    relaunched.configure(directory: directory, owner: "test")
    XCTAssertFalse(relaunched.sharing, "An earlier opt-in must not survive the deletion fallback")
  }

  func testDoubleConsentIOFailureReportsActualPersistedState() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = WidgetSnapshotBridge()
    original.configure(directory: directory, owner: "test")
    original.setSharing(true, workspace: nil)
    let failed = WidgetSnapshotBridge(
      writeConsent: { _, _ in
        throw CocoaError(.fileWriteNoPermission)
      }, removeConsent: { _ in throw CocoaError(.fileWriteNoPermission) })
    failed.configure(directory: directory, owner: "test")
    failed.setSharing(false, workspace: nil)
    XCTAssertTrue(
      failed.sharing, "Do not report a durable opt-out when neither disk operation succeeded")
    XCTAssertTrue(failed.status?.contains("couldn’t be turned off") == true)
    let relaunched = WidgetSnapshotBridge()
    relaunched.configure(directory: directory, owner: "test")
    XCTAssertTrue(relaunched.sharing)
  }
}
