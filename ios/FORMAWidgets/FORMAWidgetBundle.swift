import SwiftUI
import WidgetKit

/// Everything the extension offers: the Training widget and the workout Live Activity.
///
/// A bundle's `body` cannot branch on the OS version (`WidgetBundleBuilder` has `#available`
/// without `else`), and the iOS 18 `.small` Live Activity family needs a different widget type, so
/// there are two bundles and `main` picks one. They differ only in that widget.
struct FORMAWidgetBundle: WidgetBundle {
  var body: some Widget {
    TrainingWidget()
    WorkoutLiveActivity()
  }
}

@available(iOS 18.0, *)
struct FORMAWidgetBundleWithSmallFamily: WidgetBundle {
  var body: some Widget {
    TrainingWidget()
    WorkoutLiveActivityWithSmallFamily()
  }
}

@main
enum FORMAWidgetsMain {
  static func main() {
    if #available(iOS 18.0, *) {
      FORMAWidgetBundleWithSmallFamily.main()
    } else {
      FORMAWidgetBundle.main()
    }
  }
}
