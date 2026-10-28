#if DEBUG || FORMA_WIDGET_EXTENSION
  import AppIntents
  import FORMASurfaces
  import SwiftUI
  import WidgetKit

  enum TrainingFocus: String, AppEnum {
    case nextSession, week
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Training focus")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .nextSession: "Next session", .week: "This week",
    ]
  }

  struct TrainingEntry: TimelineEntry {
    let date: Date
    let snapshot: TrainingSnapshot
    var focus: TrainingFocus = .nextSession
    var relevance: TimelineEntryRelevance? {
      // Saved active state is useful for a limited window; never advertise indefinite urgency.
      guard snapshot.state == .ready, snapshot.active != nil else { return nil }
      return TimelineEntryRelevance(
        score: 10, duration: min(1800, max(0, snapshot.expiresAt.timeIntervalSince(date))))
    }
  }

  struct TrainingWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    /// Only the shared-view renderer supplies a family; WidgetKit uses its actual environment.
    private let reviewFamily: WidgetFamily?
    private var family: WidgetFamily { reviewFamily ?? systemFamily }
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.redactionReasons) private var redaction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: TrainingEntry
    init(entry: TrainingEntry, reviewFamily: WidgetFamily? = nil) {
      self.entry = entry
      self.reviewFamily = reviewFamily
    }

    private var value: TrainingSnapshot { entry.snapshot }
    private var weekFocus: Bool { entry.focus == .week }
    private var lime: Color {
      guard renderingMode == .fullColor else { return .primary }
      return colorScheme == .dark
        ? Color(red: 223.0 / 255, green: 247.0 / 255, blue: 128.0 / 255)
        : Color(red: 76.0 / 255, green: 99.0 / 255, blue: 28.0 / 255)
    }
    private var detailColor: Color {
      guard renderingMode == .fullColor else { return .primary }
      return colorScheme == .dark
        ? Color(red: 185.0 / 255, green: 194.0 / 255, blue: 188.0 / 255)
        : Color(red: 89.0 / 255, green: 99.0 / 255, blue: 93.0 / 255)
    }
    private var trainedDaySummary: String {
      let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      let trained = names.enumerated().compactMap { day, name in
        value.week?.days[safe: day] == true ? name : nil
      }
      return trained.isEmpty
        ? "No days recorded this week" : "Trained on " + trained.joined(separator: ", ")
    }
    private var route: WidgetRoute {
      if family == .accessoryCircular, value.state == .ready { return .progress }
      guard value.state == .ready else {
        return value.state == .hidden ? .settings : value.state == .empty ? .plan : .today
      }
      if weekFocus { return .progress }
      if let active = value.active { return .active(id: active.id, epoch: value.epoch) }
      if let routine = value.routine { return .routine(id: routine.id, epoch: value.epoch) }
      return .progress
    }
    private var title: String {
      if weekFocus { return "This week" }
      return value.active?.name ?? value.routine?.name ?? "Your training"
    }
    private var status: String {
      if value.active != nil { return "SAVED WORKOUT" }
      return weekFocus ? "A LITTLE, CONSISTENTLY" : "YOUR NEXT SESSION"
    }
    private var detail: String {
      if let active = value.active, !weekFocus {
        return "\(active.completedSets) of \(active.totalSets) sets saved"
      }
      if let routine = value.routine, !weekFocus {
        return "\(routine.exercises) exercises · \(routine.minutes) min"
      }
      return "\(value.week?.sessions ?? 0) of \(value.week?.goal ?? 4) workouts"
    }

    var body: some View {
      Group {
        if redaction.contains(.privacy) {
          fallback("Training is private", symbol: "lock")
        } else if value.state != .ready {
          fallback(fallbackTitle, symbol: fallbackSymbol)
        } else if dynamicTypeSize.isAccessibilitySize,
          family == .systemSmall || family == .systemMedium || family == .systemLarge
        {
          accessibleSummary
        } else {
          switch family {
          case .accessoryCircular: circular
          case .accessoryRectangular: rectangular
          case .accessoryInline: Text("FORMA · \(detail)").lineLimit(1)
          case .systemSmall: small
          case .systemMedium: medium
          case .systemLarge: large
          default: small
          }
        }
      }
      .privacySensitive()
      .widgetURL(route.url)
      .containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
    }

    private var brand: some View {
      HStack(spacing: 5) {
        Image(systemName: "figure.strengthtraining.traditional").widgetAccentable()
        Text("FORMA").fontWeight(.black).tracking(1.5)
      }
      .font(.caption2).foregroundStyle(lime)
    }
    /// Fixed widget frames cannot scroll. At accessibility sizes keep the useful facts and
    /// destination visible before decoration, with the full title retained for VoiceOver.
    private var accessibleSummary: some View {
      VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 4) {
        Text(title).font(family == .systemSmall ? .caption.weight(.bold) : .headline)
          .lineLimit(family == .systemMedium ? 1 : 2)
        if family == .systemLarge {
          Text(detail).font(.caption).foregroundStyle(detailColor).lineLimit(2)
        }
        Spacer(minLength: 0)
        if family != .systemSmall {
          Text("\(value.week?.sessions ?? 0) of \(value.week?.goal ?? 4) this week")
            .font(.caption2).foregroundStyle(detailColor).lineLimit(1).minimumScaleFactor(0.8)
        }
        Label(family == .systemSmall ? "Open" : "Open FORMA", systemImage: "arrow.up.right")
          .font(.caption2.weight(.semibold)).foregroundStyle(lime)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    private var small: some View {
      VStack(alignment: .leading, spacing: 7) {
        brand
        Spacer(minLength: 0)
        if weekFocus {
          weeklyNumber
        } else {
          Text(title).font(.system(.title3, weight: .bold).width(.condensed)).lineLimit(3)
          Text(detail).font(.caption).foregroundStyle(detailColor).lineLimit(2)
        }
        Spacer(minLength: 0)
        Label(
          weekFocus ? "See progress" : value.active == nil ? "View routine" : "Resume in FORMA",
          systemImage: "arrow.up.right"
        )
        .font(.caption.weight(.semibold)).foregroundStyle(lime).lineLimit(1)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    private var medium: some View {
      HStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 7) {
          brand
          Text(weekFocus ? "A little, consistently." : title)
            .font(.system(.title3, weight: .bold).width(.condensed)).lineLimit(2).fixedSize(
              horizontal: false, vertical: true)
          Text(weekFocus ? "Your saved week, one session at a time." : detail)
            .font(.caption).foregroundStyle(detailColor).lineLimit(2)
          Spacer(minLength: 0)
          Link(destination: route.url) {
            Label(
              weekFocus ? "See progress" : value.active == nil ? "View routine" : "Resume",
              systemImage: "arrow.up.right"
            ).font(.caption.weight(.semibold)).foregroundStyle(lime)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
        Divider()
        Link(destination: WidgetRoute.progress.url) {
          VStack(alignment: .leading, spacing: 9) {
            Text("THIS WEEK").font(.caption2.weight(.bold)).foregroundStyle(detailColor)
            weeklyNumber
            dayMarks
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    private var large: some View {
      VStack(alignment: .leading, spacing: 20) {
        brand
        Text(status).font(.caption2.weight(.bold)).foregroundStyle(detailColor)
        Text(title).font(.system(.largeTitle, weight: .black).width(.condensed)).lineLimit(3)
        Text(detail).font(.subheadline).foregroundStyle(detailColor)
        Spacer(minLength: 0)
        Divider()
        Link(destination: WidgetRoute.progress.url) {
          HStack(alignment: .bottom) {
            weeklyNumber
            Spacer()
            dayMarks
          }
        }
        Link(destination: route.url) {
          Label(
            weekFocus ? "See progress" : value.active == nil ? "View routine" : "Resume in FORMA",
            systemImage: "arrow.up.right"
          ).font(.headline).foregroundStyle(lime)
        }
      }
    }
    private var weeklyNumber: some View {
      VStack(alignment: .leading, spacing: 1) {
        Text("\(value.week?.sessions ?? 0) / \(value.week?.goal ?? 4)")
          .font(.system(.title, weight: .bold).monospacedDigit()).widgetAccentable()
          .foregroundStyle(Color.primary)
          .minimumScaleFactor(0.8).lineLimit(1)
        Text("workouts this week").font(.caption2).foregroundStyle(detailColor).lineLimit(2)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "\(value.week?.sessions ?? 0) of \(value.week?.goal ?? 4) workouts this week")
    }
    private var dayMarks: some View {
      HStack(spacing: 4) {
        ForEach(0..<7) { day in
          let done = value.week?.days[safe: day] ?? false
          Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(done ? lime : .secondary).widgetAccentable()
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        trainedDaySummary)
    }
    private var circular: some View {
      Gauge(
        value: Double(min(value.week?.sessions ?? 0, value.week?.goal ?? 4)),
        in: 0...Double(value.week?.goal ?? 4)
      ) {
        Image(systemName: "figure.strengthtraining.traditional")
      } currentValueLabel: {
        Text("\(value.week?.sessions ?? 0)").monospacedDigit()
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .accessibilityLabel(
        "\(value.week?.sessions ?? 0) of \(value.week?.goal ?? 4) workouts this week. Open FORMA.")
    }
    private var rectangular: some View {
      VStack(alignment: .leading, spacing: 3) {
        Text(weekFocus ? "FORMA · This week" : title).font(.headline).lineLimit(1)
        Text(detail).font(.caption).lineLimit(1)
        if !weekFocus {
          Text(value.active == nil ? "View routine ↗" : "Resume in FORMA ↗").font(.caption2)
        }
      }
    }
    private var fallbackTitle: String {
      switch value.state {
      case .hidden: "Choose what you share"
      case .empty: "Your next chapter"
      case .stale: "Refresh your training"
      default: "Open your training"
      }
    }
    private var fallbackSymbol: String {
      switch value.state {
      case .hidden: "hand.raised"
      case .empty: "plus"
      case .stale: "arrow.clockwise"
      default: "lock"
      }
    }
    @ViewBuilder
    private func fallback(_ title: String, symbol: String) -> some View {
      switch family {
      case .accessoryInline: Label("FORMA · Open app", systemImage: symbol)
      case .accessoryCircular:
        VStack(spacing: 2) {
          Image(systemName: symbol)
          Text("FORMA").font(.system(size: 8, weight: .bold))
        }.accessibilityLabel(title)
      default:
        VStack(alignment: .leading, spacing: 6) {
          Label("FORMA", systemImage: symbol).font(.caption.weight(.bold)).widgetAccentable()
          Text(title).font(.headline).lineLimit(2)
          if family == .systemSmall || family == .systemMedium || family == .systemLarge {
            Text(
              value.state == .hidden
                ? "Enable widgets in You."
                : value.state == .empty
                  ? "Create a routine in Plan." : "Tap to see your current saved training."
            )
            .font(.caption).foregroundStyle(detailColor)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
    }
  }

  extension Collection {
    fileprivate subscript(safe index: Index) -> Element? {
      indices.contains(index) ? self[index] : nil
    }
  }

  extension TrainingSnapshot {
    /// Gallery/previews only. Never used as a fallback for a real timeline.
    static var example: Self {
      Self(
        epoch: "preview", generatedAt: .now, expiresAt: Date.now.addingTimeInterval(3600),
        state: .ready,
        routine: .init(id: "preview", name: "Upper body strength", exercises: 6, minutes: 50),
        week: .init(sessions: 2, goal: 4, days: [true, false, true, false, false, false, false]))
    }
  }

#endif
