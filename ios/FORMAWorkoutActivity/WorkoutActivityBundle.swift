import SwiftUI
import WidgetKit

/// The workout Live Activity's own extension. It is apart from the Training widget on purpose:
/// that extension has Complete data protection, and an Apple engineer confirmed on the developer
/// forums (thread 806236) that a widget extension with `NSFileProtectionComplete` gets no runtime
/// while the device is locked, which is exactly when a workout card is looked at. This extension
/// reads no storage, so it has no App Group and no data-protection entitlement.
///
/// A bundle's `body` cannot branch on the OS version (`WidgetBundleBuilder` has `#available`
/// without `else`), and the iOS 18 `.small` family needs a different widget type, so there are
/// two bundles and `main` picks one.
struct WorkoutActivityBundle: WidgetBundle {
  var body: some Widget {
    WorkoutLiveActivity()
  }
}

@available(iOS 18.0, *)
struct WorkoutActivityBundleWithSmallFamily: WidgetBundle {
  var body: some Widget {
    WorkoutLiveActivityWithSmallFamily()
  }
}

@main
enum WorkoutActivityMain {
  static func main() {
    if #available(iOS 18.0, *) {
      WorkoutActivityBundleWithSmallFamily.main()
    } else {
      WorkoutActivityBundle.main()
    }
  }
}
