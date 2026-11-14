# Apple Watch workouts

Added 26 October 2026. FORMA's Watch app records a workout with HealthKit while
the iPhone logs the sets. Requirement IDs refer to the
[Apple Watch requirements matrix](https://github.com/Raoof128/forma-workout-planner/blob/main/docs/audits/apple-watch-readiness-2026-10-26/APPLE_WATCH_REQUIREMENTS.md)
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
   active energy on one page, with a Stop button that asks **Pause recording**
   (or Resume) or **End workout**; Pause, End and Discard recording are also on a
   separate controls page, as in Apple's Workout app. A pulsing heart shows while
   the session starts, restores or saves, and "Measuring…" until the first
   heart-rate reading. The Watch controls only its own recording, never the
   iPhone's sets, holds or rest timers. Paused is shown in text. The iPhone's workout screen shows the live
   heart rate and calories it receives.
4. **Finish on the iPhone**: the Watch stops, ends collection and saves the
   workout to Apple Health. **Discard** on the iPhone discards it on the Watch
   too, if the Watch is connected and still recording. Ending on the Watch saves it to Health; the sets stay on the iPhone.

The Watch can also start a strength workout by itself; the iPhone then shows it
as recording without inventing a FORMA workout.

## Data boundaries

Individual heart-rate and energy readings go only into Apple Health. Since
2 November 2026 the finished FORMA workout keeps a **summary** of what the Watch
recorded (`watch`: time, average and highest heart rate, active energy; see the
[data model](../../docs/data-model.md)). The iPhone stores the latest reading at
Finish and replaces it with the Watch's final one if that arrives later; a
discarded recording keeps none. The summary is part of the training records and
exports and, signed in, syncs to the account, so the website shows it in the
workout details, the journal and Progress. This supersedes the earlier rule
that nothing leaves the devices. The Privacy Policy (1.4), the native notice,
[privacy inventory](privacy-inventory.md) and
[App Review matrix](app-review-matrix.md) describe it. Release the API first:
older images reject the field.

## Implementation

| Part | File | Requirements met in code |
| --- | --- | --- |
| Shared configuration and messages | `Shared/WatchWorkout.swift` | Strength configuration; requested Health types; Codable metrics/commands |
| iPhone: check, open, follow | `FORMA/App/WatchWorkoutCoordinator.swift` | AP05–AP07 activation, switching and pairing/install checks; AP12–AP13 authorization; AP17 `startWatchApp(toHandle:)`; AP18–AP20 mirroring handler registered at launch, reconnect keeps one logical workout, batched data |
| iPhone: start sheet and live strip | `FORMA/Features/StartWorkoutSheet.swift`, `AppModel.requestStart` | Explicit start waits for the Watch; fallback to iPhone only |
| Watch: recording | `FORMAWatch/WorkoutManager.swift` | AP15–AP16 session and live builder; AP18 `startMirroringToCompanionDevice`; AP22 `recoverActiveWorkoutSession`; AP23 stop, wait for stopped, end collection, `finishWorkout` (nil/nil is a locked-device success, never re-saved), end |
| Watch: lifecycle and UI | `FORMAWatch/FORMAWatchApp.swift`, `WatchViews.swift` | AP29 `WKApplicationDelegate` (no `WKExtension`); AP33 Always On drops controls, shows whole minutes only and updates once a minute |
| Capabilities | `FORMA/FORMA.entitlements`, `FORMAWatch/FORMAWatch.entitlements`, both `Info.plist` files | HealthKit entitlement, purpose strings, `WKCompanionAppBundleIdentifier`, `workout-processing` background mode, privacy manifests |

The phone stays on its iOS 17 target. Mirroring works from iOS 17 / watchOS 10.
The phone doesn't call `associatedWorkoutBuilder` (iOS 26 only on iPhone): the
Watch sends a metrics message about once a second instead. The Watch target is
watchOS 10. The device build contains `arm64` and `arm64_32` (AP28).

## Verified here, and not

Built on macOS with Xcode 27.1 (iOS 27.1 / watchOS 27.0 SDKs): iPhone + embedded
Watch app, Debug and Release, simulator and device, Swift 6 strict concurrency,
no warnings. Core tests and the web contract pass.

**Device status:** on 13 November 2026 a signed 1.0 build was installed on the
owner's iPhone and Apple Watch Ultra 3. The hands-on checks below have not been
recorded yet; the [submission checklist](app-store-submission.md) tracks them.
Apple's multi-device workout sample requires physical devices (AP35):

- Watch detection states, permission prompts on both devices, and starting from
  the iPhone sheet and from the Watch alone.
- Live heart rate and energy on both screens, with the phone locked and the Watch
  wrist-down, and after walking out of range and back (reconnect).
- Finish, discard and Watch-side End: exactly one workout in Apple Health (none
  for discard), including with the iPhone locked.
- Force-quit during a workout (recovery), a second Watch (switching), and battery.
- A developer-forum report (FB24834050, unconfirmed by Apple) says watchOS 27
  workouts record almost no heart-rate samples on Series 10. Check sample density
  on the owner's Watch.

The development team, the bundle IDs `dev.raoufabedini.forma` and
`dev.raoufabedini.forma.watchkitapp`, and the HealthKit capability are set up in
the developer account; the 13 November build was signed and installed with them.
