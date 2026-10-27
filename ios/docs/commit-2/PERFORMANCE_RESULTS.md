# Commit 2 performance results

## What was measured, and what was not

The build Mac ran at a load average of 19 to 47 for the whole session (other
builds and containers), and cold simulator launches spend seconds in dyld
regardless of app code. Timings taken under that load would describe the
machine, not FORMA. So:

| Measurement | Status |
| --- | --- |
| Instruments: SwiftUI, Hitches, Animation Hitches on device | **NOT RUN** (needs an unloaded Mac and the iPhone Air attached to Instruments; see REMAINING_GATES) |
| Launch time (`XCTApplicationLaunchMetric`) | **NOT RUN** for the same reason. Commit 2 changes nothing before the first frame except `FormaLoadingMark`, which draws three static paths |
| Set commit latency | **Not changed**: no FORMACore, store or `AppModel` code was touched. The `7373cf6` numbers in CHANGELOG still apply |
| FORMACore tests | **Run**: 76 tests, 0 failures, 3.05 s |
| UI test wall time | Recorded in TEST_RESULTS.md, but dominated by machine load, not used as a performance signal |

## Work per frame and per second, by inspection

Each row compares the code before and after this commit. "Idle" means nothing
is counting down.

| Surface | Before | After | Net |
| --- | --- | --- | --- |
| Hold timer, counting | Whole card re-rendered at 4 Hz (`TimelineView(.periodic(by: 0.25))`) | Card re-renders at 1 Hz on a schedule that ends at the deadline. At full motion only the progress bar redraws at up to 30 fps (`.animation(minimumInterval: 1/30, paused:)`), paused when the scene is not active. Minimal and off: 1 Hz only | Fewer full-card renders. At full motion, more bar redraws while a hold runs (one small view) |
| Hold timer, idle | Static | Static | Same |
| Rest dock, counting | 1 Hz panel render | 1 Hz panel render; the ring's per-second glide is a linear animation interpolated by the render server, not extra body evaluations | Same body work |
| Rest dock, idle | Static | Static; one sleeping `Task` per rest for the end cue, cancelled when the deadline or scene changes | Negligible |
| Set completion | Instant swap | 180 ms state animation on one 56 pt button; fields not disabled while committing, so the keyboard no longer drops and comes back | Less layout churn per set |
| Today | Body read `workspace?.active` and re-rendered on every logged set (by inspection, FILE_AUDIT) | Body reads `activeWorkoutName`, which changes only when a workout starts or ends | Fewer re-renders during a workout |
| Today entrance | None | Seven one-time reveals (opacity + offset), once per view lifetime | One-time cost |
| Progress chart | Static | One opacity fade on first appearance; `.animation(nil, value:)` stops data changes from animating | One-time cost |
| Watch | Static screens | 160 ms fades between phases; numeric transitions on two readings, disabled when dimmed | Small; none in Always On |

No view loops an animation, so nothing ticks while the app is idle. Every
timeline is either bounded by a deadline or paused outside the active scene.

## Risks to watch on device

- **Hold bar at 30 fps on the 120 Hz iPhone Air.** This is cheap by design. If
  Instruments shows hitches, drop to `.periodic(by: 1/15)`.
- **Rest ring glide.** The glide leads each tick by one second, so it should
  never jump backwards. Confirm visually after Add 15 s and Resume.
