import SwiftUI
import WidgetKit

/// The Training widget's extension. It reads the App Group snapshot under Complete data
/// protection. The workout Live Activity has its own extension (`FORMAWorkoutActivity`) so the
/// lock that hides this widget's data never hides the workout card.
@main
struct FORMAWidgetBundle: WidgetBundle {
  var body: some Widget {
    TrainingWidget()
  }
}
