import AppIntents
import FORMASurfaces
import SwiftUI
import WidgetKit

struct TrainingConfiguration: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Training at a glance"
  static let description = IntentDescription(
    "Choose your next session or this week’s saved progress.")
  @Parameter(title: "Show", default: .nextSession) var focus: TrainingFocus
}

struct TrainingProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> TrainingEntry {
    TrainingEntry(date: .now, snapshot: .example)
  }

  func snapshot(for configuration: TrainingConfiguration, in context: Context) async
    -> TrainingEntry
  {
    if context.isPreview {
      return TrainingEntry(date: .now, snapshot: .example, focus: configuration.focus)
    }
    return entries(for: configuration, at: .now).entries[0]
  }

  func timeline(for configuration: TrainingConfiguration, in context: Context) async -> Timeline<
    TrainingEntry
  > {
    let plan = entries(for: configuration, at: .now)
    // Predictable expiry is carried by the timeline. Reloads remain a system-managed request.
    return Timeline(entries: plan.entries, policy: .after(plan.reloadAt))
  }

  /// A protected-data failure is a lock, not a fault: it gets a short-lived entry and a retry that
  /// backs off with the time since the app last published (see `TrainingTimelinePlan`), instead of
  /// parking the generic tile for half an hour or spending the reload budget overnight.
  private func entries(for configuration: TrainingConfiguration, at now: Date) -> (
    entries: [TrainingEntry], reloadAt: Date
  ) {
    let plan = TrainingTimelinePlan.make(from: read(at: now), at: now)
    return (
      plan.entries.map {
        TrainingEntry(
          date: $0.date, snapshot: $0.snapshot, focus: configuration.focus,
          awaitingUnlock: $0.awaitingUnlock)
      }, plan.reloadAt
    )
  }

  private func read(at now: Date) -> SnapshotReadResult {
    guard
      let group = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: TrainingSnapshot.group)
    else { return .unavailable }
    return SnapshotReader.read(
      url: group.appendingPathComponent(TrainingSnapshot.filename), at: now)
  }
}

struct TrainingWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: TrainingSnapshot.kind, intent: TrainingConfiguration.self,
      provider: TrainingProvider()
    ) { entry in
      TrainingWidgetView(entry: entry)
    }
    .configurationDisplayName("Training at a glance")
    .description("Open your next routine, resume saved training, or see this week’s progress.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

#Preview(as: .systemSmall) { TrainingWidget() } timeline: {
  TrainingEntry(date: .now, snapshot: .example)
}
#Preview(as: .systemMedium) { TrainingWidget() } timeline: {
  TrainingEntry(date: .now, snapshot: .example)
}
#Preview(as: .accessoryCircular) { TrainingWidget() } timeline: {
  TrainingEntry(date: .now, snapshot: .example)
}
#Preview(as: .accessoryRectangular) { TrainingWidget() } timeline: {
  TrainingEntry(date: .now, snapshot: .example)
}
