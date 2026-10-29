# Commit 2 design review: where FORMA felt unfinished, and what changed

Scope: the native iOS app and its Watch companion at base commit `7373cf6`.
Evidence comes from [FILE_AUDIT.md](FILE_AUDIT.md) (every native file read in
full), the before screenshots described in
[TEST_RESULTS.md](TEST_RESULTS.md), and the Apple guidance in
[APPLE_RESEARCH.md](APPLE_RESEARCH.md). The rules adopted here are in
[MOTION_SPEC.md](MOTION_SPEC.md).

## The brief, restated

FORMA is used mid-workout, one-handed, often with chalky or sweaty hands and
little attention to spare. A premium experience here is not more animation. It
is the app confirming each real action at once and in place, staying out of the
way while the user types, and marking real progress once, clearly.

## What the base build got right

- Local-first truth: a set reads "Completed" only after the SQLite commit.
- Identifiers and accessibility values are stable enough for XCUITest.
- Visual language: canvas, lime accent and the condensed editorial title read
  as one product; glass is already limited to controls.
- The launch fix (`7373cf6`) removed the white flash and moved catalogue
  decoding off the main thread.

## Where it felt unfinished

| # | Moment | Base behaviour | Why it matters |
| --- | --- | --- | --- |
| 1 | Completing a set | Symbol and fill swap with no transition; the only haptic in the app is a success haptic shared with hold logging | The most repeated action had the least craft |
| 2 | Rest between sets | Dock appears and vanishes with a hard cut; nothing happens at zero | The user looks away during rest; the end needs a cue |
| 3 | Hold timer | Progress bar steps four times a second | Reads as stutter on a 120 Hz display |
| 4 | Motion setting | Changed only a 1% press scale on one button style | A visible setting that did nothing |
| 5 | Opening | Static mark and spinner, then a hard cut to tabs | First impression was a jump |
| 6 | Workout to receipt | Hard cut inside the same cover; no entrance, no reward | The finish is the emotional peak and had no moment |
| 7 | Today hero | Start and Resume swap with a hard cut | The screen's main control changed meaning without signal |
| 8 | Progress | Chart and totals simply appear; totals change with a cut | Fine, but no sense of the number moving |
| 9 | Watch | No haptics; phase screens cut | Wrist feedback is the point of a Watch |
| 10 | UI tests | 5 of 8 failed on the iOS 27.0 simulator, mostly from a duplicated "Finish workout" label | Evidence for any change was weak |

## Decisions

1. **One motion resolver.** Views read a single `FormaMotionLevel` from the
   environment. System Reduce Motion (and, on iOS 26.4+, Prefer Cross-Fade
   Transitions) always wins over You › Motion. This makes the setting real and
   makes accessibility the default path, not an afterthought.
2. **Truth before motion.** Every animation and haptic is keyed to committed
   state (`set.done`, a saved receipt, a confirmed Watch phase), never to the
   tap. A failed save shows no success.
3. **In place, short, interruptible.** Set completion animates within the
   button's own frame in 180 ms. A UI test asserts the row does not move.
4. **One reward, once.** The receipt seal assembles once with the single
   success haptic. No confetti, no looping animation anywhere.
5. **Charts show only real values.** Marks fade in once; bars never grow from
   zero or tween between workouts.
6. **Always On is still.** On watchOS, dimmed displays show static states.
7. **No new settings, no analytics.** The existing Motion and haptics controls
   now do what they say; their footer explains them.

## Rejected ideas

- **Zoom navigation transitions** (`navigationTransition(.zoom)`): iOS 18+ only,
  and pushing a routine is not a moment that needs it. Default push kept.
- **Symbol draw effects** (`.drawOn`): iOS 26 only, and draw-on adds latency to
  the most repeated action.
- **Confetti, particle bursts or looping celebratory loaders**: contradict the
  settled design rules and Reduce Motion guidance.
- **A countdown sound at rest end**: FORMA has no muted-state UI on iOS, so a
  sound could not be turned off from the app. A haptic is used instead.
- **Glass on cards or the receipt**: glass stays on the control layer.

## Screen-by-screen outcome

See [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) for the file-level
changes and [ACCESSIBILITY_MATRIX.md](ACCESSIBILITY_MATRIX.md) for how each
moment behaves under every motion level.
