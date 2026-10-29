import AppIntents
import FORMASurfaces
import SwiftUI
import WidgetKit

struct TrainingConfiguration: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Training at a glance"
  static let description = IntentDescription(
    "Choose your next session or this week’s saved progress.")
  @Parameter(title: "Focus", default: .nextSession) var focus: TrainingFocus
}

struct TrainingProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> TrainingEntry {
    TrainingEntry(date: .now, snapshot: .example)
  }

  func snapshot(for configuration: TrainingConfiguration, in context: Context) async
    -> TrainingEntry
  {
    TrainingEntry(
      date: .now, snapshot: context.isPreview ? .example : read(), focus: configuration.focus)
  }

  func timeline(for configuration: TrainingConfiguration, in context: Context) async -> Timeline<
    TrainingEntry
  > {
    let now = Date.now
    let value = read(at: now)
    var entries = [TrainingEntry(date: now, snapshot: value, focus: configuration.focus)]
    if value.state == .ready, value.expiresAt > now {
      entries.append(
        TrainingEntry(
          date: value.expiresAt, snapshot: value.visible(at: value.expiresAt),
          focus: configuration.focus))
    }
    // Predictable expiry is carried by the timeline. Reloads remain a system-managed request.
    return Timeline(
      entries: entries, policy: .after(max(now.addingTimeInterval(1800), value.expiresAt)))
  }

  private func read(at now: Date = .now) -> TrainingSnapshot {
    guard
      let group = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: TrainingSnapshot.group)
    else { return .unavailable(at: now) }
    do {
      let url = group.appendingPathComponent(TrainingSnapshot.filename)
      // Bound the file before mapping it, then validate the independent versioned contract.
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size > 0, size <= 32_768 else { return .unavailable(at: now) }
      return try TrainingSnapshot.decode(Data(contentsOf: url), at: now)
    } catch {
      // Missing, corrupt and protected files all receive a non-personal, actionable fallback.
      return .unavailable(at: now)
    }
  }
}

@main
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
