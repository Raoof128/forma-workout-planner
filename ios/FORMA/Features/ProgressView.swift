import Charts
import FORMACore
import SwiftUI

struct ProgressViewScreen: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let history = model.history
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        EditorialTitle(text: "The work adds up.")
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
            MetricValue(value: "\(history.count)", label: "Workouts")
            MetricValue(value: "\(sets)", label: "Completed sets")
          }
          VolumeChart(sessions: Array(history.prefix(8).reversed()))
          LazyVStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Your training journal", detail: "Latest first")
            ForEach(history) { session in
              NavigationLink {
                SessionDetailView(session: session)
              } label: {
                JournalRow(session: session)
              }
              Divider()
            }
          }
        }
      }.padding(24)
    }
    .navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
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
          "\(completedSets(in: session)) completed sets · \(Int((session.duration ?? 0) / 60)) min"
        )
        .font(.subheadline).foregroundStyle(FormaTheme.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right").foregroundStyle(FormaTheme.secondary)
    }
    .padding(.vertical, 16)
  }
}

struct MetricValue: View {
  let value: String
  let label: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
        .foregroundStyle(FormaTheme.primary)
      Text(label).font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }.accessibilityElement(children: .combine)
  }
}

struct VolumeChart: View {
  @Environment(AppModel.self) private var model
  @ScaledMetric(relativeTo: .body) private var chartHeight = 200.0
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
      SectionHeading(title: "Lifting volume", detail: "kg × reps")
      Chart(bars) { bar in
        BarMark(
          x: .value("Session", bar.index),
          y: .value("Lifting volume, kg times reps", bar.volume)
        )
        .foregroundStyle(FormaTheme.accent).cornerRadius(4)
        .accessibilityLabel(Text(bar.title))
        .accessibilityValue(Text("\(bar.volume.formatted()) kilogram repetitions"))
      }
      .chartXAxis {
        AxisMarks(values: Array(bars.indices)) { value in
          AxisValueLabel {
            if let index = value.as(Int.self), bars.indices.contains(index) {
              Text(bars[index].date).font(.caption2)
            }
          }
        }
      }
      .chartYAxis { AxisMarks(position: .leading) }
      .chartYScale(domain: 0...max(1, peak * 1.1))
      .frame(height: chartHeight)
      .accessibilityLabel("Lifting volume over your latest \(sessions.count) workouts")
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
}

struct SessionDetailView: View {
  @Environment(AppModel.self) private var model
  private let sessionID: String
  private var current: WorkoutSession? { model.history.first { $0.id == sessionID } }

  init(session: WorkoutSession) {
    sessionID = session.id
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
