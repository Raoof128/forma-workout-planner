import Accessibility
import Charts
import FORMACore
import SwiftUI

struct ProgressViewScreen: View {
  @Environment(AppModel.self) private var model
  @Environment(TrainingNavigation.self) private var navigation

  var body: some View {
    let history = model.history
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        EditorialTitle(text: "The work adds up.").id(TabScrollAnchor.top)
        if history.isEmpty {
          // An empty screen points somewhere: workouts start from Today.
          ContentUnavailableView {
            Label("No workouts yet", systemImage: "chart.xyaxis.line")
              .accessibilityIdentifier("progress-empty")
          } description: {
            Text("Finish a workout to see your history, completed sets and lifting volume here.")
          } actions: {
            Button("Go to Today") { navigation.select(.today) }
              .buttonStyle(.formaPrimaryCompact)
              .accessibilityHint("Start a workout from your next routine.")
              .accessibilityIdentifier("progress-empty-start")
          }
        } else {
          let sets = history.reduce(0) { $0 + completedSets(in: $1) }
          AdaptiveMetricGroup {
            MetricValue(
              value: "\(history.count)", label: history.count == 1 ? "Workout" : "Workouts")
            MetricValue(value: "\(sets)", label: sets == 1 ? "Completed set" : "Completed sets")
          }
          .formaReveal(order: 0)
          VolumeChart(sessions: Array(history.prefix(8).reversed()))
          let watchTotals = WatchTotals(history)
          if watchTotals.workouts > 0 {
            WatchTotalsCard(
              totals: watchTotals,
              energyRecorded: history.contains { $0.watch?.activeEnergyKcal != nil })
          }
          LazyVStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Training journal", detail: "Latest first")
            ForEach(history) { session in
              NavigationLink(value: TrainingRoute.session(session.id)) {
                JournalRow(session: session)
              }
              Divider()
            }
          }
        }
      }.padding(24)
    }
    .navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
    .formaTabRoot(.progress)
    .background(FormaTheme.canvas)
  }
}

/// Counts completed sets without allocating a filtered array per exercise.
private func completedSets(in session: WorkoutSession) -> Int {
  session.exercises.reduce(0) { total, entry in
    total + entry.sets.reduce(0) { $0 + ($1.done ? 1 : 0) }
  }
}

/// A workout's length for a journal row: nil when it was never recorded, so
/// the row leaves it out rather than claiming "0 min".
func durationPhrase(_ seconds: Double?) -> String? {
  guard let seconds, seconds >= 0 else { return nil }
  return seconds < 60 ? "under 1 min" : "\(Int(seconds / 60)) min"
}

/// One journal row. As its own view it re-evaluates only when its session
/// changes, not whenever the whole history list is rebuilt.
private struct JournalRow: View {
  let session: WorkoutSession

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text(TrainingDate.label(TrainingDate.date(session))).font(
          .caption.weight(.semibold)
        ).foregroundStyle(FormaTheme.secondary)
        Text(session.name).font(.headline).foregroundStyle(FormaTheme.primary)
        Text(
          [countPhrase(completedSets(in: session), "completed set"), durationPhrase(session.duration)]
            .compactMap { $0 }.joined(separator: " · ")
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        if let watch = session.watch {
          Label(
            watch.averageHeartRate.map { "Apple Watch · \($0) bpm average" } ?? "Apple Watch",
            systemImage: "applewatch"
          )
          .font(.caption.weight(.semibold)).foregroundStyle(FormaTheme.accent)
        }
      }
      Spacer()
      // The link trait already says this row opens something.
      Image(systemName: "chevron.right").foregroundStyle(FormaTheme.secondary)
        .accessibilityHidden(true)
    }
    .padding(.vertical, 16).contentShape(Rectangle())
  }
}

struct MetricValue: View {
  @Environment(\.formaMotion) private var motion
  let value: String
  let label: String
  /// What VoiceOver says instead of an abbreviated label and value, such as
  /// "Average heart rate" and "128 beats per minute" for "128 / Average bpm".
  var spoken: (label: String, value: String)? = nil
  var body: some View {
    let metric = VStack(alignment: .leading, spacing: 6) {
      Text(value).font(FormaFont.numeral(.largeTitle))
        .foregroundStyle(FormaTheme.primary)
        // A new real total replaces the old one digit by digit at full motion,
        // cross-fades at minimal and swaps at once when off. Nothing between
        // the two values is ever drawn.
        .contentTransition(Self.transition(for: motion))
        .formaAnimation(FormaMotion.state, value: value)
      Text(label).font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
    if let spoken {
      metric.accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.label).accessibilityValue(spoken.value)
    } else {
      metric.accessibilityElement(children: .combine)
    }
  }

  /// How a changing number is replaced at each motion level; `value` lets
  /// the full-motion roll count in the right direction.
  static func transition(for level: FormaMotionLevel, value: Double? = nil) -> ContentTransition {
    switch level {
    case .full: value.map { .numericText(value: $0) } ?? .numericText()
    case .minimal: .opacity
    case .off: .identity
    }
  }
}

struct VolumeChart: View {
  @Environment(AppModel.self) private var model
  @Environment(\.formaMotion) private var motion
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var textSize
  @ScaledMetric(relativeTo: .body) private var chartHeight = 200.0
  /// The bars carry no text, so past this they only push the values list off
  /// screen at the largest text sizes.
  private static let maximumChartHeight = 320.0
  /// Flips once, when the chart first has data on screen. Only the chart's
  /// opacity follows it; bar heights are always the real volumes.
  @State private var marksShown = false
  /// The bar being touched, by session id. Touching a bar reads its value out
  /// above the chart; letting go returns to the latest workout.
  @State private var selectedID: String?
  let sessions: [WorkoutSession]

  /// Everything a session contributes to the chart, worked out once per render.
  /// `WorkoutEngine.volume` indexes the whole exercise catalogue on each call,
  /// and the chart, its axis, scale and value list used to call it (and parse
  /// the date) several times per session.
  private struct Bar: Identifiable {
    let id: String
    let index: Int
    let title: String
    let date: String
    let volume: Double
  }

  var body: some View {
    let catalog = model.catalog
    let bars: [Bar] = sessions.indices.map { index in
      let session = sessions[index]
      let date = TrainingDate.label(TrainingDate.date(session))
      return Bar(
        id: session.id, index: index, title: "\(date) · \(session.name)", date: date,
        volume: WorkoutEngine.volume(session, catalog: catalog))
    }
    let peak = bars.map(\.volume).max() ?? 0
    let average = bars.isEmpty ? 0 : bars.map(\.volume).reduce(0, +) / Double(bars.count)
    VStack(alignment: .leading, spacing: 16) {
      SectionHeading(
        title: "Lifting volume",
        detail: sessions.count == 1 ? "Latest workout" : "Last \(sessions.count) workouts")
      readout(bars)
      chart(bars, peak: peak, average: average)
        .frame(height: min(chartHeight, Self.maximumChartHeight))
        // Bars are never grown from zero or tweened when a new workout lands:
        // data changes draw the real values at once. Only the highlight moves.
        .animation(nil, value: bars.map(\.volume))
        .formaAnimation(FormaMotion.state, value: selectedID)
        // First data fades in once at full motion; minimal and off show it now.
        .opacity(marksShown || motion != .full ? 1 : 0)
        .onAppear {
          guard !marksShown else { return }
          withFormaAnimation(motion, FormaMotion.reveal) { marksShown = true }
        }
        .onChange(of: selectedID) { _, id in
          if id != nil { model.haptic(.selected) }
        }
        .accessibilityLabel(
          "Lifting volume over your latest \(countPhrase(sessions.count, "workout"))"
        )
        .accessibilityValue(Self.summary(bars, peak: peak, average: average))
        // Audio Graphs and Chart Details read this, not the plotted session
        // ids: workout names on the x-axis, spoken units on the y-axis.
        .accessibilityChartDescriptor(
          VolumeChartDescriptor(
            categories: Self.categories(bars), volumes: bars.map(\.volume), peak: peak,
            average: average))
        .accessibilityIdentifier("lifting-volume-chart")
      Text("Completed lifting sets only. Time, distance and carries are excluded.")
        .font(.caption).foregroundStyle(FormaTheme.secondary)
      DisclosureGroup("Read chart values") {
        ForEach(bars) { bar in
          let value =
            "\(bar.volume.formatted(.number.precision(.fractionLength(0...2)))) kg × reps"
          ViewThatFits(in: .horizontal) {
            HStack {
              Text(bar.title)
              Spacer()
              Text(value)
                .monospacedDigit()
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
              Text(bar.title)
              Text(value).monospacedDigit()
            }
          }.font(.subheadline).padding(.vertical, 6).accessibilityElement(children: .combine)
        }
      }.font(.subheadline)
    }
    .padding(FormaSpacing.lg)
    .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: FormaRadius.card))
  }

  /// The value above the chart: the touched bar, or the latest workout, with
  /// its change from the workout before it. Every number is a real total.
  @ViewBuilder private func readout(_ bars: [Bar]) -> some View {
    let focus = bars.first { $0.id == selectedID } ?? bars.last
    if let focus {
      let previous = focus.index > 0 ? bars[focus.index - 1].volume : nil
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          // A detail under the summary metrics, so a step smaller than them.
          Text(focus.volume.formatted(.number.precision(.fractionLength(0))))
            .font(FormaFont.numeral(.title))
            .contentTransition(MetricValue.transition(for: motion, value: focus.volume))
          Text("kg × reps").font(.subheadline.weight(.semibold))
            .foregroundStyle(FormaTheme.secondary)
        }
        HStack(spacing: 8) {
          Text(selectedID == nil ? "Latest · \(focus.date)" : focus.title)
            .lineLimit(1)
          if let previous, previous > 0 {
            change(from: previous, to: focus.volume)
          }
        }
        .font(.footnote.weight(.medium)).foregroundStyle(FormaTheme.secondary)
      }
      .formaAnimation(FormaMotion.state, value: focus.id)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("lifting-volume-readout")
    }
  }

  /// The change from the workout before, as a small capsule: an arrow and a
  /// whole percentage, never colour alone.
  private func change(from previous: Double, to current: Double) -> some View {
    let ratio = (current - previous) / previous
    let percent = Int((abs(ratio) * 100).rounded())
    let up = ratio >= 0
    return Label(
      percent == 0 ? "Same as before" : "\(percent)% vs previous",
      systemImage: percent == 0 ? "equal" : up ? "arrow.up.right" : "arrow.down.right"
    )
    .labelStyle(.titleAndIcon)
    .font(.caption.weight(.bold))
    .foregroundStyle(up ? FormaTheme.accent : FormaTheme.secondary)
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background((up ? FormaTheme.accent : FormaTheme.secondary).opacity(0.14), in: Capsule())
  }

  private func chart(_ bars: [Bar], peak: Double, average: Double) -> some View {
    let focusID = selectedID ?? bars.last?.id
    return Chart {
      ForEach(bars) { bar in
        BarMark(
          x: .value("Session", bar.id),
          y: .value("Lifting volume, kg times reps", bar.volume),
          width: .ratio(0.62)
        )
        .foregroundStyle(barStyle(focused: bar.id == focusID))
        .cornerRadius(6, style: .continuous)
        // Focus is marked by shape as well as colour.
        .annotation(position: .top, spacing: 2) {
          if bar.id == focusID {
            Image(systemName: "arrowtriangle.down.fill").font(.caption2)
              .foregroundStyle(FormaTheme.accent).accessibilityHidden(true)
          }
        }
        .accessibilityLabel(Text(bar.title))
        .accessibilityValue(Text("\(bar.volume.formatted()) kilogram repetitions"))
      }
      if bars.count > 1, average > 0 {
        RuleMark(y: .value("Average", average))
          .foregroundStyle(FormaTheme.secondary.opacity(0.7))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
          .annotation(position: .top, alignment: .leading, spacing: 2) {
            Text("Avg \(average.formatted(.number.notation(.compactName)))")
              .font(.caption2.weight(.semibold)).foregroundStyle(FormaTheme.secondary)
          }
          .accessibilityHidden(true)
      }
    }
    .chartXSelection(value: $selectedID)
    .chartXAxis {
      AxisMarks(values: labelledBars(bars)) { value in
        AxisValueLabel {
          if let id = value.as(String.self), let bar = bars.first(where: { $0.id == id }) {
            Text(bar.date).font(.caption2)
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
          .foregroundStyle(FormaTheme.line)
        AxisValueLabel {
          if let volume = value.as(Double.self) {
            Text(volume.formatted(.number.notation(.compactName))).font(.caption2)
          }
        }
      }
    }
    .chartYScale(domain: 0...max(1, peak * 1.15))
  }

  /// The focused bar (touched, or the latest) is the accent with a marker
  /// above it; the others are `boundary`. Every bar is a real value, so each
  /// keeps at least 3:1 against the card in all four appearance variants
  /// (WCAG 1.4.11); focus is never shown by fading the rest.
  private func barStyle(focused: Bool) -> Color {
    focused ? FormaTheme.accent : FormaTheme.boundary
  }

  /// The bars that get a date under them: at most about four on a narrow screen
  /// or at large text sizes, always including the newest, so labels don't collide.
  private func labelledBars(_ bars: [Bar]) -> [String] {
    let count = bars.count
    let crowded = horizontalSizeClass == .compact || textSize.isAccessibilitySize
    guard crowded, count > Self.maximumLabels else { return bars.map(\.id) }
    let step = (count + Self.maximumLabels - 1) / Self.maximumLabels
    return stride(from: count - 1, through: 0, by: -step).reversed().map { bars[$0].id }
  }

  private static let maximumLabels = 4

  /// One spoken overview of the real values: the newest bar, the highest and
  /// the average line. Each bar is still reachable on its own with its date,
  /// name and volume.
  private static func summary(_ bars: [Bar], peak: Double, average: Double) -> Text {
    guard let latest = bars.last else { return Text("No completed lifting sets") }
    let newest = latest.volume.formatted(.number.precision(.fractionLength(0...2)))
    let highest = peak.formatted(.number.precision(.fractionLength(0...2)))
    let mean = average.formatted(.number.precision(.fractionLength(0)))
    return Text(
      "Bar chart. Latest, \(latest.title), \(newest). Highest, \(highest). Average, \(mean). Kilogram repetitions."
    )
  }

  /// The x-axis categories for assistive technologies: each bar's date and
  /// name, numbered when two workouts would otherwise read the same.
  private static func categories(_ bars: [Bar]) -> [String] {
    var seen: [String: Int] = [:]
    for bar in bars { seen[bar.title, default: 0] += 1 }
    return bars.map { bar in
      seen[bar.title, default: 0] > 1 ? "\(bar.title), workout \(bar.index + 1)" : bar.title
    }
  }
}

/// The volume chart as Audio Graphs and Chart Details describe it. Swift
/// Charts would otherwise build one from the plotted values, whose x-axis is
/// the sessions' ids.
struct VolumeChartDescriptor: AXChartDescriptorRepresentable {
  let categories: [String]
  let volumes: [Double]
  let peak: Double
  let average: Double

  func makeChartDescriptor() -> AXChartDescriptor {
    let spoken: @Sendable (Double) -> String = {
      "\($0.formatted(.number.precision(.fractionLength(0)))) kilogram repetitions"
    }
    let x = AXCategoricalDataAxisDescriptor(title: "Workout", categoryOrder: categories)
    let y = AXNumericDataAxisDescriptor(
      title: "Lifting volume", range: 0...max(1, peak), gridlinePositions: [],
      valueDescriptionProvider: spoken)
    let series = AXDataSeriesDescriptor(
      name: "Lifting volume", isContinuous: false,
      dataPoints: zip(categories, volumes).map { AXDataPoint(x: $0, y: $1) })
    return AXChartDescriptor(
      title: "Lifting volume, \(countPhrase(categories.count, "workout"))",
      summary:
        "Bar chart of completed lifting sets, oldest first. Average \(spoken(average)). Highest \(spoken(peak)).",
      xAxis: x, yAxis: y, additionalAxes: [], series: [series])
  }
}

struct SessionDetailView: View {
  @Environment(AppModel.self) private var model
  private let sessionID: String
  private var current: WorkoutSession? { model.history.first { $0.id == sessionID } }

  init(session: WorkoutSession) {
    sessionID = session.id
  }

  init(sessionID: String) {
    self.sessionID = sessionID
  }

  var body: some View {
    Group {
      if let current {
        details(current)
      } else {
        ContentUnavailableView(
          "This workout was removed", systemImage: "clock.arrow.circlepath",
          description: Text("It is no longer stored in your training history on this iPhone.")
        )
        .accessibilityIdentifier("removed-workout-detail")
      }
    }
    .background(FormaTheme.canvas)
    .navigationTitle("Workout details").navigationBarTitleDisplayMode(.inline)
  }

  private func details(_ session: WorkoutSession) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(TrainingDate.label(TrainingDate.date(session), template: "EEEE d MMMM yyyy"))
          .font(.subheadline).foregroundStyle(FormaTheme.secondary)
        EditorialTitle(text: session.name)
        AdaptiveMetricGroup {
          // A workout with no recorded length leaves the metric out, never "0".
          if let duration = session.duration, duration >= 0 {
            MetricValue(
              value: duration < 60 ? "<1" : "\(Int(duration / 60))",
              label: duration >= 60 && duration < 120 ? "Minute" : "Minutes",
              spoken: (
                "Duration", duration < 60 ? "Under 1 minute" : countPhrase(Int(duration / 60), "minute")
              ))
          }
          MetricValue(
            value: WorkoutEngine.volume(session, catalog: model.catalog).formatted(
              .number.precision(.fractionLength(0...1))), label: "Volume · kg × reps")
        }
        // Only exercises with a completed set: a heading with nothing under it
        // says nothing. Each name is a heading for the VoiceOver rotor.
        ForEach(session.exercises.filter { $0.sets.contains(where: \.done) }) { entry in
          let exercise = model.exercise(entry.exerciseId)
          VStack(alignment: .leading, spacing: 12) {
            Text(exercise?.name ?? entry.exerciseId).font(.headline)
              .accessibilityAddTraits(.isHeader)
            ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, set in
              if set.done {
                VStack(alignment: .leading, spacing: 6) {
                  Text("Set \(index + 1)").foregroundStyle(FormaTheme.secondary)
                  Text(measurementText(set, exercise: exercise))
                    .monospacedDigit()
                }.font(.subheadline).accessibilityElement(children: .combine)
              }
            }
            Divider()
          }
        }
        if let watch = session.watch { WatchSummaryCard(summary: watch) }
        if !session.notes.isEmpty {
          Text("Session notes").font(.headline).accessibilityAddTraits(.isHeader)
          Text(session.notes).font(.body).textSelection(.enabled)
        }
        LocalSaveStatus(saving: false)
      }.padding(24)
    }
  }
}

func measurementText(_ set: LoggedSet, exercise: Exercise?) -> String {
  MeasurementText.summary(set, exercise: exercise)
}
