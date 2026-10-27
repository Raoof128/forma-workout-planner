# Commit 2 implementation report

Branch `feat/ios-commit2-premium-experience`, base `7373cf6`. Rules:
[MOTION_SPEC.md](MOTION_SPEC.md). Rationale: [DESIGN_REVIEW.md](DESIGN_REVIEW.md).
Results: [TEST_RESULTS.md](TEST_RESULTS.md),
[PERFORMANCE_RESULTS.md](PERFORMANCE_RESULTS.md),
[ACCESSIBILITY_MATRIX.md](ACCESSIBILITY_MATRIX.md).

Nothing in FORMACore, the workspace v2 contract, local storage, the Watch
HealthKit boundary (`WorkoutManager.swift`) or `Shared/` changed. No analytics,
no WebView, no new settings. iOS 17 remains the floor; the only newer API used
(`accessibilityPrefersCrossFadeTransitions`, iOS 26.4) is behind `#available`.

## Motion system (new)

| File | What it adds |
| --- | --- |
| `FORMA/DesignSystem/FormaMotion.swift` | `FormaMotionLevel` (full / minimal / off) resolved once at the root from You › Motion, Reduce Motion and, on iOS 26.4+, Prefer Cross-Fade Transitions. Timing tokens (`press`, `state`, `reveal`, `navigation`, `emphasis`, `fade`, `stagger`). Helpers: `formaMotionRoot`, `formaAnimation(_:value:)`, `formaReveal(order:)` (once per view lifetime), `withFormaAnimation` |
| `FORMA/DesignSystem/FormaComponents.swift` | `FormaLoadingMark` (the three facets assemble once while the store opens) and `CompletionSeal` (receipt seal with the single success haptic) |
| `FORMA/DesignSystem/FormaTheme.swift` | `FormaMark(facet:)` and `facetCount`; `PrimaryButtonStyle` now presses with the motion level instead of a 1% scale tied to one preference case |
| `FORMA/App/FORMAApp.swift` | Publishes the level at the root and into the workout cover; loading cross-fades to the tabs; workout hands off to the receipt with `navigation` timing, keyed to the saved receipt |

## Screens

**Workout (`WorkoutView.swift`)**
- Set completion animates fill, outline and symbol (`.symbolEffect(.replace)`)
  within the 56 pt button, keyed to the committed `set.done`. The set counter
  rolls numerically.
- Text fields are no longer disabled while a commit is in flight. A commit
  applies only the drafts captured when it began; edits typed meanwhile stay
  pending (`retainingUnacknowledgedDrafts`). The completion and finish buttons
  still gate on `busy`. Focus is cleared only when it was in the row that just
  locked.
- Rest dock: enters and leaves with a transition. The timer icon is now a ring
  shrinking toward the persisted deadline, with running / paused / over states
  cross-fading. Digits roll at full motion. Pause/Resume reserves its width.
  When a rest counting down in front of the user reaches zero: one medium
  haptic and a VoiceOver announcement, "Rest finished". A rest that ended
  while suspended, or was skipped, paused or extended, cues nothing.
- Hold timer: digits change once a second on a schedule ending exactly at the
  deadline (was 4 Hz). At full motion the bar is drawn smoothly from the
  persisted deadline by a 30 fps timeline that runs only while counting down
  and the app is active.
- Receipt: `CompletionSeal` replaces the static mark; metrics reveal once,
  staggered.

**Today (`TodayView.swift`)**
- Header, title, hero, week, routines, last session and save status reveal
  once, staggered, on stable containers (tab switches do not replay it).
- Start and Resume share one hero; only text cross-fades. The button label is
  explicit so UI tests and VoiceOver never read the outgoing text.
- The Start tap is acknowledged at once with in-button progress while the
  Watch check and first save run.
- Week strip: a newly completed day fills with `emphasis` once, when the
  workout cover has closed. Today is marked (heavier, darker letter). Every day
  has a spoken status built from committed history.
- The body reads `activeWorkoutName` instead of the whole active session, so it
  no longer re-renders on every logged set.

**Plan (`PlanView.swift`) and Start sheet (`StartWorkoutSheet.swift`)**
- `PressableCardStyle` for cards outside a List (Today rows, last-session
  card). List rows keep the system highlight.
- Routine detail Start shows in-button progress. Library filter changes animate;
  typed search never does.
- Start sheet buttons show in-button progress; watch status cross-fades.

**Progress (`ProgressView.swift`)**
- Chart fades in once at full motion, opacity only; bars never grow from zero
  or tween between workouts (`.animation(nil, value:)`). Totals roll from one
  real value to the next. The chart has a spoken summary (latest, highest).

**You (`YouView.swift`)**
- The Motion and Haptics footer now says what each level and each haptic does.

**Watch (`WatchViews.swift`)**
- Phase screens cross-fade (160 ms), still when the display is dimmed.
- `.start` haptic when HealthKit confirms the workout is running; `.success`
  when the summary is saved. Neither fires on a tap, a recovery or a discard.
- Heart rate and energy roll numerically only with Reduce Motion off and the
  display fully lit. The elapsed clock does not roll.

## Haptic map

| Event | Feedback | Gate |
| --- | --- | --- |
| Set saved | `.impact(weight: .light)` | You › Set confirmation haptics |
| Hold logged | `.impact(weight: .light)` | same |
| Rest reached zero (once per rest) | `.impact(weight: .medium)` | same |
| Workout finished and saved (receipt) | `.success`, once | same |
| Watch workout running (confirmed) | `.start` | watchOS haptic settings |
| Watch summary saved | `.success` | watchOS haptic settings |

Decision: before this commit, set completion used `.success`. It is now a
light impact, so `.success` means exactly one thing, a finished workout, and
the most repeated action gets the least intrusive feedback.

## Tests

- New `FORMAUITests/MotionExperienceTests.swift`: Motion Off still shows every
  final state; completing a set does not move its row; the receipt waits for the
  confirmed finish.
- New `FORMAUITests/ScreenshotTourTests.swift`: walks nine primary screens and
  attaches named screenshots (used for before/after evidence).
- `OfflineWorkoutTests.swift`: the finish alert button is found by its unique
  identifier `finish-confirm` (the toolbar button shares the label "Finish
  workout", which caused the "multiple matching elements" failures on the
  iOS 27 simulator); waits raised from 5 s to 15 s for loaded simulators.

## Reviewed and changed during integration

- Removed `PressableCardStyle` from the Plan List rows an agent had added it
  to: a custom style there would replace the native List highlight.
- The You footer's haptics sentence was corrected to match the actual map.
