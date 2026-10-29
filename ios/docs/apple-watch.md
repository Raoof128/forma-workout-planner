# Apple Watch workouts

Added 26 October 2026. FORMA's Watch app records a workout with HealthKit while
the iPhone logs the sets. Requirement IDs refer to the
[Apple Watch requirements matrix](https://github.com/Raoof128/forma-workout-planner/blob/audit/apple-watch-readiness-2026-10-26/docs/audits/apple-watch-readiness-2026-10-26/APPLE_WATCH_REQUIREMENTS.md)
(AP01–AP37).

## What the person sees

1. **Start on the iPhone** (Today or a routine). FORMA first checks for a Watch:
   Health availability, a paired Watch and FORMA installed on it.
   - No Watch paired, or no Health support: the workout starts on the iPhone
     straight away, exactly as before.
   - Watch paired but FORMA isn't installed or the Watch can't be reached: a
     sheet explains how to fix it, with **Check again** and **Start on iPhone only**.
   - Watch ready: FORMA asks for Health permission, opens on the Watch with the
     routine name, and the sheet says **Press Start on your Apple Watch**.
2. **Press Start on the Watch.** The Watch starts a Traditional Strength Training
   `HKWorkoutSession` and `HKLiveWorkoutBuilder` (heart rate, active and basal
   energy, all the live data its sensors provide) and mirrors the session to the
   iPhone. The iPhone starts the FORMA workout at that moment.
3. **During the workout** the Watch shows elapsed active time, heart rate and
   active energy, with Pause and End. The iPhone's workout screen shows the live
   heart rate and calories it receives.
4. **Finish on the iPhone**: the Watch stops, ends collection and saves the
   workout to Apple Health. **Discard** on the iPhone discards it on the Watch
   too. Ending on the Watch saves it to Health; the sets stay on the iPhone.

The Watch can also start a strength workout by itself; the iPhone then shows it
as recording without inventing a FORMA workout.

## Data boundaries

Heart rate and energy go only into Apple Health. They never enter the FORMA
workspace, so the web data contract, exports and validators are unchanged. The
privacy notice, [privacy inventory](privacy-inventory.md) and
[App Review matrix](app-review-matrix.md) describe this. Nothing is sent off
the devices.

## Implementation

| Part | File | Requirements met in code |
| --- | --- | --- |
| Shared configuration and messages | `Shared/WatchWorkout.swift` | Strength configuration; requested Health types; Codable metrics/commands |
| iPhone: check, open, follow | `FORMA/App/WatchWorkoutCoordinator.swift` | AP05–AP07 activation, switching and pairing/install checks; AP12–AP13 authorization; AP17 `startWatchApp(toHandle:)`; AP18–AP20 mirroring handler registered at launch, reconnect keeps one logical workout, batched data |
| iPhone: start sheet and live strip | `FORMA/Features/StartWorkoutSheet.swift`, `AppModel.requestStart` | Explicit start waits for the Watch; fallback to iPhone only |
| Watch: recording | `FORMAWatch/WorkoutManager.swift` | AP15–AP16 session and live builder; AP18 `startMirroringToCompanionDevice`; AP22 `recoverActiveWorkoutSession`; AP23 stop, wait for stopped, end collection, `finishWorkout` (nil/nil is a locked-device success, never re-saved), end |
| Watch: lifecycle and UI | `FORMAWatch/FORMAWatchApp.swift`, `WatchViews.swift` | AP29 `WKApplicationDelegate` (no `WKExtension`); AP33 Always On drops controls and updates once a minute |
| Capabilities | `FORMA/FORMA.entitlements`, `FORMAWatch/FORMAWatch.entitlements`, both `Info.plist` files | HealthKit entitlement, purpose strings, `WKCompanionAppBundleIdentifier`, `workout-processing` background mode, privacy manifests |

The phone stays on its iOS 17 target. Mirroring works from iOS 17 / watchOS 10.
The phone doesn't call `associatedWorkoutBuilder` (iOS 26 only on iPhone): the
Watch sends a metrics message about once a second instead. The Watch target is
watchOS 10. The device build contains `arm64` and `arm64_32` (AP28).

## Verified here, and not

Built on macOS with Xcode 27.1 (iOS 27.1 / watchOS 27.0 SDKs): iPhone + embedded
Watch app, Debug and Release, simulator and device, Swift 6 strict concurrency,
no warnings. Core tests and the web contract pass.

**Not verified**: nothing ran on a simulator or a paired iPhone and Watch. Apple's
multi-device workout sample requires physical devices (AP35). Before relying on
it, test on the actual iPhone and Ultra 2:

- Watch detection states, permission prompts on both devices, and starting from
  the iPhone sheet and from the Watch alone.
- Live heart rate and energy on both screens, with the phone locked and the Watch
  wrist-down, and after walking out of range and back (reconnect).
- Finish, discard and Watch-side End: exactly one workout in Apple Health (none
  for discard), including with the iPhone locked.
- Force-quit during a workout (recovery), a second Watch (switching), and battery.
- A developer-forum report (FB24834050, unconfirmed by Apple) says watchOS 27
  workouts record almost no heart-rate samples on Series 10. Check sample density
  on Ultra 2.

A development team, bundle IDs `dev.raoufabedini.forma` and
`dev.raoufabedini.forma.watchkitapp`, and the HealthKit capability must be set
up in the developer account before the apps can be signed and installed.
