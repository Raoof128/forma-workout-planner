import ActivityKit
import FORMASurfaces

/// The workout Live Activity's immutable identity. Compiled into the app (which starts and ends
/// the activity) and the widget extension (which draws it); the two must agree on this type.
///
/// Nothing here names a person. `ownerEpoch` is the widget bridge's opaque per-owner token, so an
/// activity left by another owner (sign-out, account switch, reset) never matches the current one
/// and is ended on the next reconcile.
struct WorkoutActivityAttributes: ActivityAttributes {
  typealias ContentState = WorkoutActivityState

  var sessionID: String
  var ownerEpoch: String
}
