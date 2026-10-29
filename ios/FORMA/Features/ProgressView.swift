import Charts
import FORMACore
import SwiftUI

struct ProgressViewScreen: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let history = model.history
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        EditorialTitle(text: "The work adds up.").id(TabScrollAnchor.top)
        if history.isEmpty {
          ContentUnavailableView {
            Label("Every first set counts.", systemImage: "chart.xyaxis.line")
              .accessibilityIdentifier("progress-empty")
          } description: {
            Text(
              "Finish your first workout to see your history, completed sets and lifting volume here."
            )
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
          LazyVStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Your training journal", detail: "Latest first")
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
          "\(countPhrase(completedSets(in: session), "completed set")) · \(Int((session.duration ?? 0) / 60)) min"
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(FormaTheme.secondary)
    }
    .padding(.vertical, 16).contentShape(Rectangle())
  }
}

struct MetricValue: View {
  @Environment(\.formaMotion) private var motion
  let value: String
  let label: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
        .foregroundStyle(FormaTheme.primary)
        // A new real total replaces the old one digit by digit at full motion,
        // cross-fades at minimal and swaps at once when off. Nothing between
        // the two values is ever drawn.
        .contentTransition(Self.transition(for: motion))
        .formaAnimation(FormaMotion.state, value: value)
      Text(label).font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }.accessibilityElement(children: .combine)
  }

  private static func transition(for level: FormaMotionLevel) -> ContentTransition {
    switch level {
    case .full: .numericText()
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
    VStack(alignment: .leading, spacing: 16) {
      SectionHeading(
        title: "Lifting volume",
        detail: sessions.count == 1 ? "Latest workout" : "Last \(sessions.count) workouts")
      readout(bars)
      chart(bars, peak: peak)
        .frame(height: chartHeight)
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
        .accessibilityValue(Self.summary(bars, peak: peak))
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
    .padding(20).background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 20))
  }

  /// The value above the chart: the touched bar, or the latest workout, with
  /// its change from the workout before it. Every number is a real total.
  @ViewBuilder private func readout(_ bars: [Bar]) -> some View {
    let focus = bars.first { $0.id == selectedID } ?? bars.last
    if let focus {
      let previous = focus.index > 0 ? bars[focus.index - 1].volume : nil
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(focus.volume.formatted(.number.precision(.fractionLength(0))))
            .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
            .contentTransition(.numericText(value: focus.volume))
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

  private func chart(_ bars: [Bar], peak: Double) -> some View {
    let average = bars.isEmpty ? 0 : bars.map(\.volume).reduce(0, +) / Double(bars.count)
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

  /// The focused bar (touched, or the latest) is solid lime-to-accent; the
  /// others step back so the eye lands on one value.
  private func barStyle(focused: Bool) -> AnyShapeStyle {
    if focused {
      return AnyShapeStyle(
        LinearGradient(
          colors: [FormaTheme.accent, FormaTheme.accent.opacity(0.72)],
          startPoint: .top, endPoint: .bottom))
    }
    return AnyShapeStyle(FormaTheme.accent.opacity(selectedID == nil ? 0.38 : 0.22))
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

  /// One spoken overview of the real values: the newest bar and the highest.
  /// Each bar is still reachable on its own with its date, name and volume.
  private static func summary(_ bars: [Bar], peak: Double) -> Text {
    guard let latest = bars.last else { return Text("No completed lifting sets") }
    let newest = latest.volume.formatted(.number.precision(.fractionLength(0...2)))
    let highest = peak.formatted(.number.precision(.fractionLength(0...2)))
    return Text("Latest, \(latest.title), \(newest). Highest, \(highest). Kilogram repetitions.")
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
          MetricValue(value: "\(Int((session.duration ?? 0) / 60))", label: "Minutes")
          MetricValue(
            value: WorkoutEngine.volume(session, catalog: model.catalog).formatted(
              .number.precision(.fractionLength(0...1))), label: "Volume · kg × reps")
        }
        ForEach(session.exercises) { entry in
          let exercise = model.exercise(entry.exerciseId)
          VStack(alignment: .leading, spacing: 12) {
            Text(exercise?.name ?? entry.exerciseId).font(.headline)
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
        if !session.notes.isEmpty {
          Text("Session notes").font(.headline)
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
