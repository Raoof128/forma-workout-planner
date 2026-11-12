# Apple Watch app audit: battery and watchOS practice

2 November 2026. An independent read-only review of `FORMAWatch/`, `Shared/WatchWorkout.swift`
and the iPhone's `WatchWorkoutCoordinator`, checked against Apple's current HealthKit,
watchOS and Human Interface Guidelines pages. Every finding was confirmed in the code
before it was fixed. Nothing here is a measured battery number.

## Fixed

| Finding                                                                                                                                                                                         | Fix                                                                                                                                                                                                   |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The final snapshot was sent after `session.end()`, so the iPhone, which stops listening on `.ended`, could drop the workout's final average and highest heart rate, energy and the discard flag | The Watch awaits delivery of the final snapshot (at most 2 s) before ending the session, on both the saved and failed-save paths; the iPhone also accepts a snapshot from the session that just ended |
| Snapshots carried no send time, so a batch delivered late after suspension looked fresh                                                                                                         | `WatchMetrics.sentAt`; the iPhone judges freshness from it and ignores older snapshots that arrive late                                                                                               |
| About one Bluetooth send a second for the whole workout, because whole-bpm heart rate changes almost every sample                                                                               | Ordinary sends are at least 2 s apart and only when heart rate moves 2 bpm or more, energy by a kilocalorie, or the state changes; state changes and the final snapshot still go at once              |
| The 20 s heartbeat had no timer: a paused or still workout could look like a lost link after 60 s                                                                                               | A heartbeat task while a recording is open, cancelled at End                                                                                                                                          |
| Basal energy was requested from Health but never read                                                                                                                                           | Removed from the requested read types                                                                                                                                                                 |
| The heart-rate pulse repeated for as long as no reading arrived                                                                                                                                 | It stops after 15 s and says "No reading yet"                                                                                                                                                         |
| A failure reported while collection was starting was overwritten by Running                                                                                                                     | `start()` only moves to Running from Starting                                                                                                                                                         |
| An iPhone End arriving while the Watch was already ending marked the summary "ended from iPhone"                                                                                                | `end(save:)` reports whether it ran; only then is it marked                                                                                                                                           |
| Pause and Resume had no phase guard; recovery did not refresh the Health-off flags                                                                                                              | Guarded; refreshed                                                                                                                                                                                    |
| Stop had no VoiceOver hint; the screen heading was not a header                                                                                                                                 | Added                                                                                                                                                                                                 |

## Considered and left

- **`HKWorkoutSession.prepare()` at open time, mirroring before `startActivity`.** Apple's
  flow warms the sensors during a countdown, but a prepared session keeps the app alive
  until it is ended or times out, and mirroring first would hold Start on a slow link.
  Worth a device experiment, not a blind change.
- **`Text(timerInterval:)` for the elapsed clock.** It would let the system draw the
  seconds, but VoiceOver's reading of it is unverified and the current clock is one
  `Text` per second with its own spoken duration.
- **Short-workout discard prompt (HIG Workouts)** is a product decision.
- **No Cancel while starting / timeout while saving**, and debouncing the
  "iPhone disconnected" haptic on a flapping link: small, not yet seen on hardware.
- `UncheckedSendable` around HealthKit objects is kept; Swift 6 builds clean.

## Already in line with guidance

Workout processing background mode and companion bundle ID; specific Health usage
strings; rounded, change-only observed values with each reading in its own view; Always
On at one update a minute with no animation; delegate filtering before the main-actor hop;
stop, end collection, finish, end in Apple's order with no double save; haptics only on
confirmed state; 44 pt or larger targets.

## Verification

iPhone and Watch device build with no warnings; `FORMAAppTests` 125/125 on the iPhone Air
(not the simulator); `swift test`. Battery effect and the end-of-workout delivery are not
yet measured on the Watch.
