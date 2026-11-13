import FORMACore
import SwiftUI

/// What the Apple Watch recorded for one finished workout: on the receipt and
/// in the workout's details. Missing readings are left out, never shown as zero.
struct WatchSummaryCard: View {
  let summary: WorkoutWatchSummary
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var textSize

  /// One column at accessibility sizes, so a value never wraps mid-number.
  private var columns: [GridItem] {
    textSize.isAccessibilitySize
      ? [GridItem(.flexible(), alignment: .leading)]
      : [GridItem(.adaptive(minimum: 130), alignment: .leading)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      Label("Collected by Apple Watch", systemImage: "applewatch")
        .font(.headline).foregroundStyle(FormaTheme.primary)
        .accessibilityAddTraits(.isHeader)
      LazyVGrid(columns: columns, alignment: .leading, spacing: FormaSpacing.md) {
        WatchValue(
          value: WorkoutClock.text(summary.elapsedSeconds, locale: locale),
          label: "Recorded time", symbol: "stopwatch",
          spoken: WorkoutClock.spoken(summary.elapsedSeconds, locale: locale))
        if let average = summary.averageHeartRate {
          let bpm = WatchFormat.number(average, locale: locale)
          WatchValue(
            value: "\(bpm) bpm", label: "Average heart rate", symbol: "heart.fill",
            spoken: "\(bpm) beats per minute")
        }
        if let maximum = summary.maxHeartRate {
          let bpm = WatchFormat.number(maximum, locale: locale)
          WatchValue(
            value: "\(bpm) bpm", label: "Highest heart rate", symbol: "arrow.up.heart.fill",
            spoken: "\(bpm) beats per minute")
        }
        if let energy = summary.activeEnergyKcal {
          WatchValue(
            value: WatchFormat.energy(energy, width: .abbreviated, locale: locale),
            label: "Active energy", symbol: "flame.fill",
            spoken: WatchFormat.energy(energy, width: .wide, locale: locale))
        }
      }
      // The Watch saves to Health after this card appears, and nothing tells
      // the iPhone whether that save worked (the final reading looks the same
      // either way). So this says where the result shows, not that it saved.
      Text("Your Apple Watch saves this recording to Apple Health and shows the result there.")
        .font(.footnote).foregroundStyle(FormaTheme.secondary)
        .accessibilityIdentifier("watch-summary-health-note")
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
/// Absent until at least one has been. Like the workout card, a reading the
/// Watch never took is left out rather than shown as zero.
struct WatchTotalsCard: View {
  let totals: WatchTotals
  /// Whether any recorded workout has an active-energy reading. `WatchTotals`
  /// sums missing readings as 0, so the total alone can't tell.
  let energyRecorded: Bool
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: FormaSpacing.md) {
      SectionHeading(
        title: "From your Apple Watch",
        detail: totals.workouts == 1 ? "1 workout recorded" : "\(totals.workouts) workouts recorded"
      )
      AdaptiveMetricGroup {
        if let average = totals.averageHeartRate {
          let bpm = WatchFormat.number(average, locale: locale)
          MetricValue(
            value: bpm, label: "Average bpm",
            spoken: ("Average heart rate", "\(bpm) beats per minute"))
        }
        if let highest = totals.highestHeartRate {
          let bpm = WatchFormat.number(highest, locale: locale)
          MetricValue(
            value: bpm, label: "Highest bpm",
            spoken: ("Highest heart rate", "\(bpm) beats per minute"))
        }
        if energyRecorded {
          MetricValue(
            value: WatchFormat.number(totals.activeEnergyKcal, locale: locale),
            label: "Active kcal",
            spoken: (
              "Active energy",
              WatchFormat.energy(totals.activeEnergyKcal, width: .wide, locale: locale)
            ))
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watch-totals")
  }
}

/// Watch readings in the reader's own digits and units ("1,250 kcal",
/// "1.250 kcal", "1 250 kilocalories"), following the view's locale.
enum WatchFormat {
  static func number(_ value: Int, locale: Locale) -> String {
    value.formatted(.number.locale(locale))
  }

  static func energy(
    _ kilocalories: Int, width: Measurement<UnitEnergy>.FormatStyle.UnitWidth, locale: Locale
  ) -> String {
    Measurement(value: Double(kilocalories), unit: UnitEnergy.kilocalories)
      .formatted(.measurement(width: width, usage: .asProvided).locale(locale))
  }
}
