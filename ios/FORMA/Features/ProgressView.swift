import Charts
import FORMACore
import SwiftUI

struct ProgressViewScreen: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        EditorialTitle(text: "The work adds up.")
        if model.history.isEmpty {
          ContentUnavailableView {
            Label("Every first set counts.", systemImage: "chart.xyaxis.line")
              .accessibilityIdentifier("progress-empty")
          } description: {
            Text(
              "Finish your first workout to see your history, completed sets and lifting volume here."
            )
          }
        } else {
          let sets = model.history.reduce(0) {
            $0 + $1.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }
          }
          AdaptiveMetricGroup {
            MetricValue(value: "\(model.history.count)", label: "Workouts")
            MetricValue(value: "\(sets)", label: "Completed sets")
          }
          VolumeChart(sessions: Array(model.history.prefix(8).reversed()))
          LazyVStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Your training journal", detail: "Latest first")
            ForEach(model.history) { session in
              NavigationLink {
                SessionDetailView(session: session)
              } label: {
                HStack(spacing: 16) {
                  VStack(alignment: .leading, spacing: 5) {
                    Text(TrainingDate.label(TrainingDate.date(session))).font(
                      .caption.weight(.semibold)
                    ).foregroundStyle(FormaTheme.secondary)
                    Text(session.name).font(.headline).foregroundStyle(FormaTheme.primary)
                    Text(
                      "\(session.exercises.reduce(0) { $0 + $1.sets.filter(\.done).count }) completed sets · \(Int((session.duration ?? 0) / 60)) min"
                    )
                    .font(.subheadline).foregroundStyle(FormaTheme.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").foregroundStyle(FormaTheme.secondary)
                }
                .padding(.vertical, 16)
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

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionHeading(title: "Lifting volume", detail: "kg × reps")
      Chart(Array(sessions.enumerated()), id: \.element.id) { index, session in
        BarMark(
          x: .value("Session", index),
          y: .value(
            "Lifting volume, kg times reps", WorkoutEngine.volume(session, catalog: model.catalog))
        )
        .foregroundStyle(FormaTheme.accent).cornerRadius(4)
        .accessibilityLabel(
          Text("\(TrainingDate.label(TrainingDate.date(session))) · \(session.name)")
        )
        .accessibilityValue(
          Text(
            "\(WorkoutEngine.volume(session, catalog: model.catalog).formatted()) kilogram repetitions"
          ))
      }
      .chartXAxis {
        AxisMarks(values: Array(sessions.indices)) { value in
          AxisValueLabel {
            if let index = value.as(Int.self), sessions.indices.contains(index) {
              Text(TrainingDate.label(TrainingDate.date(sessions[index]), template: "d MMM")).font(
                .caption2)
            }
          }
        }
      }
      .chartYAxis { AxisMarks(position: .leading) }
      .chartYScale(
        domain:
          0...max(
            1, (sessions.map { WorkoutEngine.volume($0, catalog: model.catalog) }.max() ?? 0) * 1.1)
      )
      .frame(height: chartHeight)
      .accessibilityLabel("Lifting volume over your latest \(sessions.count) workouts")
      .accessibilityIdentifier("lifting-volume-chart")
      Text("Completed lifting sets only. Time, distance and carries are excluded.")
        .font(.caption).foregroundStyle(FormaTheme.secondary)
      DisclosureGroup("Read chart values") {
        ForEach(sessions) { session in
          ViewThatFits(in: .horizontal) {
            HStack {
              Text("\(TrainingDate.label(TrainingDate.date(session))) · \(session.name)")
              Spacer()
              Text(
                "\(WorkoutEngine.volume(session, catalog: model.catalog).formatted(.number.precision(.fractionLength(0...2)))) kg × reps"
              )
              .monospacedDigit()
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
              Text("\(TrainingDate.label(TrainingDate.date(session))) · \(session.name)")
              Text(
                "\(WorkoutEngine.volume(session, catalog: model.catalog).formatted(.number.precision(.fractionLength(0...2)))) kg × reps"
              ).monospacedDigit()
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
          VStack(alignment: .leading, spacing: 12) {
            Text(model.exercise(entry.exerciseId)?.name ?? entry.exerciseId).font(.headline)
            ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, set in
              if set.done {
                VStack(alignment: .leading, spacing: 6) {
                  Text("Set \(index + 1)").foregroundStyle(FormaTheme.secondary)
                  Text(measurementText(set, exercise: model.exercise(entry.exerciseId)))
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
