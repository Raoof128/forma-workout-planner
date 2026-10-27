# Commit 2 accessibility matrix

How each changed moment behaves at each motion level, and what assistive
technology receives. "Level" is resolved once at the root
(`FormaMotionLevel`): System Reduce Motion, or Prefer Cross-Fade Transitions on
iOS 26.4+, forces `minimal`; You › Motion › Minimal is `minimal`; Off is `off`.

Status column: **Code** = verified by reading the code; **UI test** = covered
by an XCUITest (see [TEST_RESULTS.md](TEST_RESULTS.md)); **Device** = needs a
person to check on hardware, listed in [REMAINING_GATES.md](REMAINING_GATES.md).

## Motion levels

| Moment | Full | Minimal | Off | Status |
| --- | --- | --- | --- | --- |
| Opening mark | Facets lift and fade in, staggered, once | Fade | Static mark | Code |
| Loading → tabs | 300 ms cross-fade | 160 ms fade | Instant | Code |
| Today entrance | Staggered lift and fade, once per view lifetime | Shown at once | Shown at once | Code |
| Hero Start ↔ Resume | Text cross-fade | Fade | Instant | Code |
| Week day completes | Fill and check scale in (`emphasis`) | Fade | Instant | Code |
| Card press | 0.98 scale + opacity | Opacity | Opacity, no animation | Code |
| Set completes | Fill, outline, symbol replace (180 ms) in place | Fade | Instant | UI test (Off; frame unchanged) |
| Set counter | Numeric roll | Fade | Instant | Code |
| Rest dock in/out | Slide up + fade | Fade | Instant | Code |
| Rest ring | Linear 1 s glide per tick | Steps per second | Steps per second | Code |
| Rest / hold digits | Numeric roll | Change at once | Change at once | Code |
| Hold bar | 30 fps from persisted deadline | Steps per second | Steps per second | Code |
| Workout → receipt | Scale 0.98 + fade (380 ms) | Fade | Instant | UI test (Off) |
| Receipt seal | Ring draws, scale 0.7 → 1 (`emphasis`) | Fade | Shown complete | UI test (Off) |
| Progress chart | Fades in once; values never interpolated | Shown | Shown | Code |
| Progress totals | Numeric roll between real values | Fade | Instant | Code |
| Watch phase screens | 160 ms fade; none when dimmed | Same fade (watch reads Reduce Motion directly) | n/a on watch | Code |
| Watch readings | Numeric roll unless Reduce Motion or dimmed | Instant | n/a | Code |

No animation loops. No view waits on an animation before accepting input.

## Haptics

All iPhone haptics are gated by You › Set confirmation haptics and follow the
device's haptic settings. Each haptic fires after a committed or confirmed
state and is paired with a visible change. See the haptic map in
[IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md). Watch haptics follow the
watchOS haptic settings only (the iPhone preference is not synced to the
Watch; see REMAINING_GATES).

## VoiceOver

| Element | What is spoken | Status |
| --- | --- | --- |
| Set button | "Complete set N" / "Undo set N"; value "Completed" / "Not completed" (unchanged) | UI test |
| Rest end | Announcement "Rest finished", once per rest | Device |
| Rest dock ring | Hidden; digits and status already spoken | Code |
| Week strip day | "Today, not yet trained" / "Tuesday, completed" / "Friday, planned training day", from committed history even while the circle animates | Code |
| Hero button | Explicit "Start workout" / "Resume workout"; value "Starting" while the start is pending | UI test (label) |
| Start buttons (routine, sheet) | Value "Starting" / "Opening" while pending | Code |
| Progress chart | Label plus summary value (latest and highest volume); each bar still has its own label; text list unchanged | Code |
| Loading mark, completion seal | Hidden (decorative); the progress label and receipt text carry meaning | Code |

## Other settings

| Setting | Behaviour | Status |
| --- | --- | --- |
| Dynamic Type | New ring uses `@ScaledMetric`; seal uses `@ScaledMetric`; Pause/Resume reserves width at every size | Code; Device at AX sizes |
| Reduce Transparency | No new translucent surfaces; glass stays on controls | Code |
| Increase Contrast | No new colours; existing tokens | Code |
| Dark mode | Screenshot tour runs in both appearances | UI test |
| Always On (watchOS) | No decorative motion while `isLuminanceReduced` | Code; Device |
