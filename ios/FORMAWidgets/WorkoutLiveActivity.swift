import ActivityKit
import FORMASurfaces
import SwiftUI
import WidgetKit

/// The workout Live Activity: Lock Screen and banner, StandBy, Dynamic Island, and on iOS 18 the
/// compact layout for the Apple Watch Smart Stack and CarPlay. The app starts, updates and ends
/// it (`WorkoutLiveActivityController`); this only draws what the app sent. It reads no storage
/// and has no network or push path.
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration { workoutActivity() }
}

/// The same activity with the compact `.small` layout for the Apple Watch Smart Stack and CarPlay.
/// `supplementalActivityFamilies` is iOS 18, and a widget's `body` cannot choose between two
/// configurations at run time, so `FORMAWidgetBundle` picks this type or the one above.
@available(iOS 18.0, *)
struct WorkoutLiveActivityWithSmallFamily: Widget {
  var body: some WidgetConfiguration {
    workoutActivity().supplementalActivityFamilies([.small])
  }
}

@MainActor
private func workoutActivity() -> some WidgetConfiguration {
  ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
    WorkoutActivityRoot(
      sessionID: context.attributes.sessionID, state: context.state, isStale: context.isStale
    )
    .activityBackgroundTint(WorkoutActivityPalette.backgroundTint)
    .activitySystemActionForegroundColor(WorkoutActivityPalette.systemAction)
  } dynamicIsland: { context in
    DynamicIsland {
      DynamicIslandExpandedRegion(.leading) {
        IslandExpandedLeading(state: context.state)
      }
      DynamicIslandExpandedRegion(.trailing) {
        IslandExpandedTrailing(state: context.state, isStale: context.isStale)
      }
      DynamicIslandExpandedRegion(.center) {
        IslandExpandedCenter(state: context.state)
      }
      DynamicIslandExpandedRegion(.bottom) {
        IslandExpandedBottom(
          sessionID: context.attributes.sessionID, state: context.state, isStale: context.isStale)
      }
    } compactLeading: {
      IslandCompactLeading(state: context.state, isStale: context.isStale)
    } compactTrailing: {
      IslandCompactTrailing(state: context.state, isStale: context.isStale)
    } minimal: {
      IslandMinimal(state: context.state, isStale: context.isStale)
    }
    .keylineTint(WorkoutActivityPalette.lime)
  }
}
