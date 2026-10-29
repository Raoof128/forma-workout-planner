#if DEBUG || FORMA_WIDGET_EXTENSION
  import AppIntents
  import FORMASurfaces
  import SwiftUI
  import WidgetKit

  enum TrainingFocus: String, AppEnum {
    case nextSession, week
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Show")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .nextSession: "Next session", .week: "This week",
    ]
  }

  struct TrainingEntry: TimelineEntry {
    let date: Date
    let snapshot: TrainingSnapshot
    var focus: TrainingFocus = .nextSession
    /// The file could not be read because the device is locked; a retry is already scheduled.
    var awaitingUnlock = false
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
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.redactionReasons) private var redaction
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: TrainingEntry
    init(entry: TrainingEntry, reviewFamily: WidgetFamily? = nil) {
      self.entry = entry
      self.reviewFamily = reviewFamily
    }

    private var model: TrainingPresentation {
      TrainingPresentation(
        snapshot: entry.snapshot, weekFocus: entry.focus == .week,
        awaitingUnlock: entry.awaitingUnlock)
    }
    private var weekFocus: Bool { model.weekFocus }
    private func color(_ token: BrandPalette.Token) -> Color {
      let hex = token.hex(dark: colorScheme == .dark, highContrast: contrast == .increased)
      return Color(
        red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255)
    }
    /// Tinted, clear and vibrant renderings replace colour, so emphasis falls back to the
    /// primary style and hierarchy comes from `detailColor` being secondary.
    private var accent: Color {
      renderingMode == .fullColor ? color(BrandPalette.accent) : .primary
    }
    private var detailColor: Color {
      renderingMode == .fullColor ? color(BrandPalette.secondaryText) : .secondary
    }
    /// Small stays on the full layout only while its title, detail and action fit; the others
    /// switch at the sizes where their fixed frames start to clip.
    private var usesCompactLayout: Bool {
      switch family {
      case .systemSmall: dynamicTypeSize >= .xxLarge
      case .systemMedium: dynamicTypeSize >= .xxxLarge
      case .systemLarge: dynamicTypeSize.isAccessibilitySize
      default: false
      }
    }
    private var route: WidgetRoute { model.route(progressOnly: family == .accessoryCircular) }

    var body: some View {
      let layout = model.layout(
        privacyRedacted: redaction.contains(.privacy), compact: usesCompactLayout)
      content(layout)
        // Only personal content is redacted. The generic privacy and fallback messages carry
        // no data and must stay readable on the Lock Screen and in StandBy.
        .privacySensitive(layout.containsPersonalContent)
        .widgetURL(route.url)
        .containerBackground(for: .widget) { Color(uiColor: .secondarySystemBackground) }
    }

    @ViewBuilder
    private func content(_ layout: TrainingPresentation.Layout) -> some View {
      switch layout {
      case .privacyFallback: fallback(TrainingPresentation.privacyFallback)
      case .fallback: fallback(model.fallback)
      case .compactSummary: accessibleSummary
      case .data:
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:
          ViewThatFits {
            Text(model.inlineText).lineLimit(1)
            Text(model.inlineShortText).lineLimit(1)
          }
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
      }
    }

    private var brand: some View {
      HStack(spacing: 5) {
        Image(systemName: "figure.strengthtraining.traditional").accessibilityHidden(true)
        Text("FORMA").fontWeight(.black).tracking(1.5)
      }
      .font(.caption2).foregroundStyle(accent).widgetAccentable()
    }
    private func action(_ short: Bool = false, font: Font = .caption.weight(.semibold))
      -> some View
    {
      Label(model.actionLabel(short: short), systemImage: "arrow.up.right")
        .font(font).foregroundStyle(accent).widgetAccentable().lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    /// Fixed widget frames cannot scroll. At large text sizes keep the useful facts and
    /// destination visible before decoration, with the full title retained for VoiceOver.
    private var accessibleSummary: some View {
      VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 4) {
        Text(model.title).font(family == .systemSmall ? .caption.weight(.bold) : .headline)
          .lineLimit(family == .systemMedium ? 1 : 2).widgetAccentable()
        if family == .systemLarge {
          Text(model.detail).font(.caption).foregroundStyle(detailColor).lineLimit(2)
        }
        Spacer(minLength: 0)
        if family != .systemSmall {
          Text("\(model.sessions) of \(model.goal) this week")
            .font(.caption2).foregroundStyle(detailColor).lineLimit(1).minimumScaleFactor(0.8)
        }
        action(family == .systemSmall, font: .caption2.weight(.semibold))
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
          Text(model.title).font(.system(.title3, weight: .bold).width(.condensed)).lineLimit(3)
            .minimumScaleFactor(0.8).widgetAccentable()
          Text(model.detail).font(.caption).foregroundStyle(detailColor).lineLimit(2)
        }
        Spacer(minLength: 0)
        action()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    private var medium: some View {
      HStack(spacing: 18) {
        VStack(alignment: .leading, spacing: 7) {
          brand
          Text(weekFocus ? "A little, consistently." : model.title)
            .font(.system(.title3, weight: .bold).width(.condensed)).lineLimit(2).fixedSize(
              horizontal: false, vertical: true
            ).widgetAccentable()
          Text(weekFocus ? "Your saved week, one session at a time." : model.detail)
            .font(.caption).foregroundStyle(detailColor).lineLimit(2)
          Spacer(minLength: 0)
          Link(destination: route.url) { action(true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
        Divider()
        Link(destination: WidgetRoute.progress.url) {
          VStack(alignment: .leading, spacing: 9) {
            Text("THIS WEEK").font(.caption2.weight(.bold)).foregroundStyle(detailColor)
            weeklyNumber
            dayMarks(letters: true)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    private var large: some View {
      VStack(alignment: .leading, spacing: 20) {
        brand
        Text(model.status).font(.caption2.weight(.bold)).foregroundStyle(detailColor)
        Text(model.title).font(.system(.largeTitle, weight: .black).width(.condensed))
          .lineLimit(3).widgetAccentable()
        Text(model.detail).font(.subheadline).foregroundStyle(detailColor)
        Spacer(minLength: 0)
        Divider()
        Link(destination: WidgetRoute.progress.url) {
          HStack(alignment: .bottom) {
            weeklyNumber
            Spacer()
            dayMarks(letters: true)
          }
        }
        Link(destination: route.url) { action(font: .headline) }
      }
    }
    private var weeklyNumber: some View {
      VStack(alignment: .leading, spacing: 1) {
        Text("\(model.sessions) / \(model.goal)")
          .font(.system(.title, weight: .bold).monospacedDigit()).widgetAccentable()
          .foregroundStyle(Color.primary)
          .minimumScaleFactor(0.8).lineLimit(1)
        Text("workouts this week").font(.caption2).foregroundStyle(detailColor).lineLimit(2)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(model.weeklyLabel)
    }
    private func dayMarks(letters: Bool) -> some View {
      let initials = TrainingPresentation.weekdayInitials()
      return HStack(spacing: 4) {
        ForEach(0..<7, id: \.self) { day in
          let done = model.isTrained(day: day)
          VStack(spacing: 2) {
            if letters {
              Text(initials[day]).font(.caption2).foregroundStyle(detailColor)
                .lineLimit(1).minimumScaleFactor(0.6)
            }
            // A text style (not a point size) so the mark scales with the reader's setting.
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(done ? accent : detailColor).widgetAccentable()
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(model.trainedDaySummary())
    }
    private var circular: some View {
      Gauge(
        value: Double(min(model.sessions, model.goal)),
        in: 0...Double(model.goal)
      ) {
        Image(systemName: "figure.strengthtraining.traditional")
      } currentValueLabel: {
        Text("\(model.sessions)").monospacedDigit()
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .accessibilityLabel("\(model.weeklyLabel). Open FORMA.")
    }
    private var rectangular: some View {
      VStack(alignment: .leading, spacing: 3) {
        Text(weekFocus ? "FORMA · This week" : model.title).font(.headline).lineLimit(1)
          .minimumScaleFactor(0.8).widgetAccentable()
        Text(model.detail).font(.caption).lineLimit(1)
        if !weekFocus {
          Label(model.actionLabel(), systemImage: "arrow.up.right").font(.caption2).lineLimit(1)
        }
      }
    }
    @ViewBuilder
    private func fallback(_ content: TrainingPresentation.Fallback) -> some View {
      switch family {
      case .accessoryInline: Label(content.inline, systemImage: content.symbol)
      case .accessoryCircular:
        VStack(spacing: 2) {
          Image(systemName: content.symbol)
          Text("FORMA").font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(content.title)
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Label("FORMA", systemImage: content.symbol).font(.caption2.weight(.bold))
            .widgetAccentable()
          Text(content.title).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
          Text(content.detail).font(.caption).lineLimit(2)
        }
      default:
        // Fixed frames cannot scroll: at large sizes keep the title and the next step only.
        let large = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 6) {
          Label("FORMA", systemImage: content.symbol).font(.caption.weight(.bold))
            .widgetAccentable()
          Text(content.title).font(.headline).lineLimit(large ? 3 : 2).minimumScaleFactor(0.7)
            .widgetAccentable()
          Text(content.detail).font(.caption).foregroundStyle(detailColor)
            .lineLimit(large ? 2 : 3).minimumScaleFactor(0.8)
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
