import FORMACore
import SwiftUI

/// What the Apple Watch recorded for one finished workout: on the receipt and
/// in the workout's details. Missing readings are left out, never shown as zero.
struct WatchSummaryCard: View {
  let summary: WorkoutWatchSummary

  var body: some View {
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      Label("Collected by Apple Watch", systemImage: "applewatch")
        .font(.headline).foregroundStyle(FormaTheme.primary)
        .accessibilityAddTraits(.isHeader)
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading,
        spacing: FormaSpacing.md
      ) {
        WatchValue(
          value: WorkoutClock.text(summary.elapsedSeconds),
          label: "Recorded time", symbol: "stopwatch",
          spoken: WorkoutClock.spoken(summary.elapsedSeconds))
        if let average = summary.averageHeartRate {
          WatchValue(
            value: "\(average) bpm", label: "Average heart rate", symbol: "heart.fill",
            spoken: "\(average) beats per minute")
        }
        if let maximum = summary.maxHeartRate {
          WatchValue(
            value: "\(maximum) bpm", label: "Highest heart rate", symbol: "arrow.up.heart.fill",
            spoken: "\(maximum) beats per minute")
        }
        if let energy = summary.activeEnergyKcal {
          WatchValue(
            value: "\(energy) kcal", label: "Active energy", symbol: "flame.fill",
            spoken: "\(energy) kilocalories")
        }
      }
      Text("Also saved in Apple Health on your iPhone.")
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
    }
    .padding(FormaSpacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: FormaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: FormaRadius.card).strokeBorder(FormaTheme.line)
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watch-summary")
  }
}

private struct WatchValue: View {
  let value: String
  let label: String
  let symbol: String
  let spoken: String

  var body: some View {
    VStack(alignment: .leading, spacing: FormaSpacing.xxs) {
      Label {
        Text(value).font(.title3.weight(.semibold)).monospacedDigit()
          .foregroundStyle(FormaTheme.primary)
      } icon: {
        Image(systemName: symbol).foregroundStyle(FormaTheme.accent)
      }
      Text(label).font(.subheadline).foregroundStyle(FormaTheme.secondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(spoken)
  }
}

/// Progress's Apple Watch card: totals across every workout the Watch recorded.
/// Absent until at least one has been.
struct WatchTotalsCard: View {
  let totals: WatchTotals

  var body: some View {
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      SectionHeading(
        title: "From your Apple Watch",
        detail: totals.workouts == 1 ? "1 workout recorded" : "\(totals.workouts) workouts recorded"
      )
      AdaptiveMetricGroup {
        if let average = totals.averageHeartRate {
          MetricValue(value: "\(average)", label: "Average bpm")
        }
        if let highest = totals.highestHeartRate {
          MetricValue(value: "\(highest)", label: "Highest bpm")
        }
        MetricValue(
          value: totals.activeEnergyKcal.formatted(), label: "Active kcal")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watch-totals")
  }
}
