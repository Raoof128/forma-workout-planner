# Apple research for Commit 2: motion, feedback, charts, Always On

Retrieved 2026-10-27 (Australia/Sydney). This adds to, and does not repeat,
[`../apple-design-2026.md`](../apple-design-2026.md) (62 sources, settled decisions). Its
rules stand: glass only on the control/navigation layer, set completion resolves in
place, no confetti, System Reduce Motion overrides FORMA's System/Minimal/Off
preference, a saved check or success haptic only after a durable local save, charts
never animate through fabricated values.

## 1. Method and limits

- **DocC / HIG JSON.** `https://developer.apple.com/tutorials/data/<path>.json`, reading
  `metadata.platforms`, declarations and `primaryContentSections`. HIG Motion,
  Accessibility and Charts bytes and hashes are identical to the 23 October register,
  so those pages have not changed.
- **WWDC26 transcripts.** Sessions 269, 250 and 220 were retrieved from
  `developer.apple.com/videos/play/wwdc2026/<n>/` (byte lengths equal the register;
  hashes differ, so treat the page markup as per-request). Timestamps are transcript
  times, not frames.
- **Installed SDK (authoritative for "compiles with our toolchain").** Xcode 27.1
  (27A9275). iOS interfaces: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/<Fw>.framework/Modules/<Fw>.swiftmodule/arm64e-apple-ios.swiftinterface`
  (SDK 27.1). watchOS: same shape under `WatchOS.platform/.../WatchOS.sdk/...arm64e-apple-watchos.swiftinterface`
  (SDK 27.0), spot-checked for 13 APIs. Evidence labels: **SUC** SwiftUICore, **SU** SwiftUI,
  **CH** Charts, **SY** Symbols, followed by the declaration line; **W-** prefix = watchOS file.
- **Reading the interface.** `@_originallyDefinedIn(module: "SwiftUI", iOS 26.0)` beside a
  symbol is a module-move marker, not an availability. The `@available` line above it
  is the minimum OS (for example `withAnimation(...completion:)` shows `originallyDefinedIn 26.0`
  but is `@available(iOS 17.0, watchOS 10.0)`).
- Nothing was compiled, run or measured. A declaration proves existence and minimum OS,
  not runtime behaviour.

## 2. Findings that change the plan

1. **`accessibilityPrefersCrossFadeTransitions` is iOS 26.4** (not 26.0). Apple says that when true,
   UI should avoid slide animations and prefer cross-fades; on watchOS it always returns false.
   Gate with `#available(iOS 26.4, *)`; fall back to `accessibilityReduceMotion`.
2. **`navigationTransition(.zoom)` and `matchedTransitionSource` are iOS 18 / watchOS 11**, one release above the floor.
   Gate both ends, fall back to the default push.
3. **`Animation.spring(duration:bounce:)`, `.smooth`, `.snappy`, `.bouncy` are declared `iOS 13` in this SDK**
   (inline `@export(implementation)` bodies; DocC says the same). They need no gate at iOS 17.
   Earlier documentation reported iOS 17 for these (from memory, not re-verified); the lower number
   appears because the implementation ships inside the app. Do not use it to justify a target below 17.
4. **`SensoryFeedback.pathComplete` is iOS 17.5**; the rest of the classic cases are 17.0.
   New iOS 26 `.press(_:)`, `.release(_:)`, `.selection(_:)` overloads exist (gate, optional).
5. **`accessibilityReduceMotion`, `accessibilityReduceTransparency`, `colorSchemeContrast` are get-only** in the
   public interface (only underscored `_accessibility...` setters exist). `.environment(\.accessibilityReduceMotion, true)`
   is a read-only key path, and `.environment(_:_:)` needs a writable one. Previews and tests need a
   FORMA-owned environment key that feeds the same resolver.
   `isLuminanceReduced`, `legibilityWeight` and `accessibilityPrefersCrossFadeTransitions` have setters.
6. **Looping defaults.** `keyframeAnimator(initialValue:repeating: Bool = true, ...)` and `phaseAnimator(_:content:)`
   (no `trigger`) run continuously. Use only the `trigger:` overloads.
7. **No API in the requested list is missing from the SDK.** `Transition` (protocol), `AnyTransition`,
   `.blurReplace`, `.push(from:)`, `.move(edge:)` all exist. `.push(from:)` and `.move(edge:)` are iOS 16 / iOS 13 on `AnyTransition`
   and iOS 17 on `Transition`.
8. HIG Accessibility lists "avoid animating into and out of blurs" among Reduce Motion practices, so
   `.blurReplace` should not run when Reduce Motion is on (see section 7).

## 3. Verified API table

Minimum OS is the `@available` value in the SDK interface (DocC agrees unless noted).
"Gate" means `if #available(...)` with the stated fallback; iOS 17+ rows need none.

### 3a. Animation, content and view transitions

| # | API | iOS | watchOS | SDK evidence | FORMA use | iOS 17 fallback |
|---|---|---|---|---|---|---|
| 1 | `withAnimation(_:completionCriteria:_:completion:)`; `AnimationCompletionCriteria.logicallyComplete / .removed` | 17.0 | 10.0 | SUC:13155, 13169; W-SUC:12966 | Clear transient UI state after a settle animation. Completion fires exactly once, and immediately after `body` if nothing animated (DocC), so the Reduce Motion path (`animation: nil`) still completes | none needed |
| 2 | `Animation.spring(duration:bounce:blendDuration:)` | 13.0 (SDK/DocC) | 6.0 | SUC:17057 | Base for custom settle curves | none needed |
| 3 | `.smooth`, `.snappy`, `.bouncy` and `(duration:extraBounce:)` | 13.0 (SDK/DocC) | 6.0 | SUC:17076-17093 | Presets. Inline bodies: duration 0.5 s default; bounce 0 / 0.15 / 0.30. `interactiveSpring(duration:)` default 0.15 s | none needed |
| 4 | `.animation(_:value:)` | 13.0 | 6.0 | SUC:17185 | Scoped state animation; the default way to attach motion | none |
| 5 | `.animation(_:body:)` | 17.0 | 10.0 | SUC:22724 | Animate only the modifiers inside `body` (keeps text/layout un-animated) | none |
| 6 | `PhaseAnimator`; `.phaseAnimator(_:trigger:content:animation:)`; non-trigger overload loops | 17.0 | 10.0 | SUC:18422, 18453, 18455; W-SUC:18148 | Use only the `trigger:` form, only for rare moments (PR marker on finish). Not on set rows | `animation(_:value:)` |
| 7 | `KeyframeAnimator`; `.keyframeAnimator(initialValue:trigger:content:keyframes:)`; `repeating:` form defaults to `true` | 17.0 | 10.0 | SUC:2898, 2900, 2909; keyframes SUC:18305-18367; W-SUC:2868 | Avoid for logging flows; keep as a tool for a one-off summary reveal. `content` closure is `@Sendable` | `animation(_:value:)` |
| 8 | `.contentTransition(.numericText(value:))`; `numericText(countsDown:)` | value: 17.0; countsDown: 16.0 | 10.0 / 9.0 | SUC:20731, 20729, 20740; W-SUC:20393 | Infrequent number changes (totals on summary, PR delta). Not per-second rest ticks (HIG frequency rule) | `numericText(countsDown:)` (16), or none |
| 9 | `.symbolEffect(_:options:value:)` and `isActive:` forms (Symbols: `.bounce`, `.pulse`) | 17.0 | 10.0 | SUC:16781, 16786; SY:51, 58 | One-shot confirmation on an icon only if it adds meaning | none |
| 10 | `.contentTransition(.symbolEffect(.replace))` | 17.0 | 10.0 | SUC:17003; SY:222, 229 | In-place swap of an empty circle to a check. Fits "resolves in place" | `.opacity` swap |
| 11 | `Transition` protocol (`body(content:phase:)`, `@MainActor @preconcurrency`); `View.transition<T: Transition>(_:)` | 17.0 | 10.0 | SUC:20807, 25465 | Custom reveal transitions typed per phase | `AnyTransition` |
| 12 | `AnyTransition` and `View.transition(_ t: AnyTransition)` | 13.0 | 6.0 | SUC:25460 | Floor-compatible spelling of `.opacity`, `.move`, `.scale` | n/a |
| 13 | `.transition(.blurReplace)` (`BlurReplaceTransition`) | 17.0 | 10.0 | SUC:23806, 23816 | Not recommended; see sections 7 and 10 | `.opacity` |
| 14 | `.push(from:)`: `AnyTransition` / `Transition` | 16.0 / 17.0 | 9.0 / 10.0 | SUC:14489 / 14497 | Slide reveal for non-critical panels; swap to `.opacity` under Reduce Motion | `AnyTransition.push` |
| 15 | `.move(edge:)`: `AnyTransition` / `Transition` | 13.0 / 17.0 | 6.0 / 10.0 | SUC:4369 / 4377 | Sheet-like drawers | `.opacity` |
| 16 | `matchedGeometryEffect(id:in:properties:anchor:isSource:)` | 14.0 | 7.0 | SUC:3660 | In-view morphs (tab underline, chip to expanded). Not across NavigationStack pushes | none |
| 17 | `.navigationTransition(.zoom(sourceID:in:))` (`ZoomNavigationTransition`) | **18.0** | **11.0** | SU:11053, 11076, 11089; W-SU:10958 | Today card to workout, exercise row to guide. macOS unavailable (irrelevant here) | **gate**; default push |
| 18 | `.matchedTransitionSource(id:in:)` | **18.0** | **11.0** | SU:19110; W-SU:18755 | Source half of #17; same namespace on both ends | **gate**; omit |
| 19 | `.scrollTransition(_:axis:transition:)` | 17.0 | 10.0 | SU:7455; W-SU:7393 | History/Plan card fade or scale at edges. Not on logging rows | none, or drop |
| 20 | `.visualEffect { content, proxy in }` | 17.0 | 10.0 | SUC:20959; W-SUC:20621 | Header parallax or scroll-linked dimming; closure is `@Sendable` | none, or drop |
| 21 | Symbol effects `.wiggle`, `.rotate`, `.breathe` | 18.0 | 11.0 | SY:279, 331, 364 | Not planned | gate or omit |
| 22 | Symbol effects `.drawOn`, `.drawOff` | **26.0** | **26.0** | SY:424, 454 | Optional one-off checkmark draw on workout finish; which symbols carry draw annotations is NOT VERIFIED | **gate**; `.replace` |

### 3b. Haptics

| # | API | iOS | watchOS | SDK evidence | FORMA use | iOS 17 fallback |
|---|---|---|---|---|---|---|
| 23 | `.sensoryFeedback(_:trigger:)` | 17.0 | 10.0 | SU:2547; W-SU:2521 | Primary haptic route | none |
| 24 | `.sensoryFeedback(_:trigger:condition:)` (`condition: (old, new) -> Bool`) and `sensoryFeedback(trigger:_:)` closure forms | 17.0 | 10.0 | SU:2549, 2551, 2553; W-SU:2523 | Matches the current `.success` + `hapticsEnabled` gate in `WorkoutView.swift:241`. Flip the trigger only after the durable save returns | none |
| 25 | `SensoryFeedback` `.success .warning .error .selection .increase .decrease .start .stop .alignment .levelChange .impact` | 17.0 | 10.0 | SU:918-931 | Meanings in section 7 | none |
| 26 | `.impact(weight:intensity:)`, `.impact(flexibility:intensity:)` | 17.0 | 10.0 | SU:932, 933 | Light tap for non-semantic presses | none |
| 27 | `.pathComplete` | **17.5** | **10.5** | SU:930 | Not a fit (drawn paths) | omit |
| 28 | `.press(_:)`, `.release(_:)`, `.selection(_:)` with `PressFeedback .button .buttonIconOnly .slider .toggle .tab`, `SelectionFeedback .maximum .minimum .on .off`, `ReleaseFeedback .slider` | **26.0** | **26.0** | SU:948 and following | Custom controls that mimic system press feel. (Implementation decision: set completion moved to `.impact(weight: .light)` so `.success` means only a finished workout; see IMPLEMENTATION_REPORT.md) | **gate**; `.impact(weight: .light)` |

### 3c. Timeline, Charts, environment

| # | API | iOS | watchOS | SDK evidence | FORMA use | iOS 17 fallback |
|---|---|---|---|---|---|---|
| 29 | `TimelineView`; `TimelineSchedule.entries(from:mode:)`; `TimelineScheduleMode .normal/.lowFrequency`; `.periodic`, `.explicit`, `.everyMinute`, `.animation(minimumInterval:paused:)` | 15.0 | 8.0 | SU:29127, 10937; SUC:2559-2629; W-SU:28454 | Rest countdown with a custom schedule (exists as `CountdownSchedule`); watch elapsed time | none |
| 30 | `TimelineView.Context.cadence` (`.live .seconds .minutes`) | 15.0 | 8.0 | SU:29129-29132; W-SU:28456-28459 | Hide sub-second text and animation when cadence drops (Always On) | none |
| 31 | `chartXSelection(value:)`, `(range:)`; `chartYSelection`; `chartAngleSelection` | 17.0 | 10.0 | CH:2963-2971; W-CH:2468 | Scrub a bar to read date/session/volume | tap list rows |
| 32 | `chartScrollableAxes(_:)`, `chartXVisibleDomain(length:)`, `chartScrollPosition(x:)`, `chartScrollTargetBehavior` | 17.0 | 10.0 | CH:1213-1227; W-CH:730 | Weekly/monthly window over history | fixed range |
| 33 | `ChartContent.accessibilityLabel/Value(Text)`, `accessibilityHidden` | 16.0 | 9.0 | CH:1327, 1349, 1381 | Per-bar label: date, session, actual volume | n/a |
| 34 | `accessibilityLabel/Value(KeyPath)` on `VectorizedChartContent` | 18.0 | 11.0 | CH:1340, 1362 | Only for vectorized plots | per-mark labels |
| 35 | `accessibilityChartDescriptor(_:)`, `AXChartDescriptorRepresentable.makeChartDescriptor()` | 15.0 | 8.0 | SU:25697; SUC:7520-7521 | Replace default Audio Graph only if a richer title/summary is needed | default Audio Graph |
| 36 | `accessibilityReduceMotion` (get-only) | 13.0 | 6.0 | SUC:23720 | Input to the motion resolver | n/a |
| 37 | `accessibilityPrefersCrossFadeTransitions` (get/set) | **26.4** | **26.4** | SUC:23728 | Swap slide/push/zoom for opacity when true | **gate**; Reduce Motion |
| 38 | `accessibilityReduceTransparency`, `colorSchemeContrast`, `legibilityWeight`, `accessibilityDifferentiateWithoutColor` | 13.0 | 6.0 | SUC:23713, 24170, 21996, 23706 | Opaque control fallback (settled); weight and contrast for watch | n/a |
| 39 | `isLuminanceReduced` (get/set) | 16.0 | 8.0 | SUC:5527; W-SUC:5388 | Always On layout in `WatchViews.swift:56,78` | n/a |

**Count:** 39 table rows (about 75 individual symbols and overloads) verified against the
installed iOS SDK interfaces. 15 rows (1, 6, 7, 8, 17-20, 23, 24, 29-32, 39) were additionally checked in the watchOS SDK file; the rest
of the watchOS column comes from the same `@available` line in the iOS interface and DocC
`metadata.platforms`.

## 4. iOS 26 and 27 additions for animation and interaction

Keyword scan of `@available(iOS 27` and `anyAppleOS 27.x` declarations in SwiftUI, SwiftUICore,
Charts and Symbols (not exhaustive for macro-generated code). **Charts** gained only builder
conformances at 27.0 (`EmptyView`, `_ConditionalContent`, `TupleContent`: CH:1110-1132). **Symbols** has
no 27 entries. No new `Animation` presets, `SensoryFeedback` cases or content transitions were found.

| API | Availability | Evidence | Worth adopting? | Gate and iOS 17 fallback |
|---|---|---|---|---|
| `NavigationTransition.crossFade` (`CrossFadeNavigationTransition`) | iOS 27.0, watchOS 27.0 (`AnyNavigationTransition` 27.0 too) | SU:11091-11110; DocC sha 3604e1eb | **Yes, narrowly**: the Reduce Motion / cross-fade route for the zoom transition | `if #available(iOS 27, *)`; else `.automatic` push (iOS 17-26) |
| `EnvironmentValues.systemPrefersReducedResourceUsage` | anyAppleOS 27.0 (DocC: iOS 27.0, watchOS 27.0) | SU:10547; DocC sha 69d31363 | **Yes**: drop ornamental motion, glass flourishes and chart reveal when true. Relation to Low Power Mode is NOT VERIFIED | `if #available(iOS 27, *)`; else `ProcessInfo.isLowPowerModeEnabled` (Foundation, not re-fetched) |
| `accessibilityPrefersCrossFadeTransitions` | iOS 26.4 | SUC:23728; DocC sha 8b6e5930 | **Yes** (row 37) | see row 37 |
| `reorderable()`, `reorderContainer(for:...)`, `ReorderDifference` | iOS 27.0, watchOS 27.0 (`reorderDestination` iOS/macOS/visionOS only) | SU:12431-12453, 12466; WWDC26/269 at 15:32-17:09 | **Not now.** Session says SwiftUI handles drag interaction and animation and brings reordering to watchOS. A wider migration than Commit 2 needs | `.onMove` + edit mode (iOS 13, not re-fetched) |
| `swipeActions(...onPresentationChanged:)`, `swipeActionsContainer()` | iOS 27.0, watchOS 27.0 | SU:20944-20955; WWDC26/269 at 17:44-18:22 | No (no custom lazy-stack rows) | existing `swipeActions` |
| `SensoryFeedback.press/.release/.selection(_:)` | iOS 26.0, watchOS 26.0 | SU:948 | Marginal (row 28) | `.impact(weight: .light)` |
| Symbol `.drawOn/.drawOff` | iOS 26.0 | SY:424-461 | Marginal (row 22) | `.replace` |
| `GlassEffectTransition`, `glassEffectID(_:in:)` | iOS 26.0, watchOS 26.0 | SUC:3516, 22663 | Governed by the glass rules in the register; control layer only | opaque control |
| `dismissalConfirmationDialog` | iOS 27.0 (macOS 15) | SU:21221 | NOT VERIFIED on iPhone sheets; skip | existing confirmation flow |

## 5. HIG Motion: guidance that matters here

Source: [Motion](https://developer.apple.com/design/human-interface-guidelines/motion). Paraphrased.

- Add motion for a purpose. Motion that does not support the task is distracting and can make
  people physically uncomfortable.
- Make motion optional: do not use it as the only carrier of important information. Pair it with
  haptics or audio (the page links Playing haptics and Playing audio).
- Feedback motion should follow gestures and expectations. Reveal and dismiss should mirror each other.
- Keep feedback animation brief and precise; short feedback is more informative than prominent motion.
- On frequency, Apple says to "generally avoid adding motion to UI interactions that occur frequently"
  in apps, and notes system components already include subtle animation. This is the basis for the
  settled in-place set completion.
- Do not make people wait for an animation to finish, especially one they see repeatedly.
- SF Symbols animation is the suggested lightweight option, and the SF Symbols HIG asks for
  purposeful, sparing use. Replace swaps one symbol for another; Magic Replace is described as the
  default replace animation, but the OS where it began is NOT VERIFIED here.
- watchOS: SwiftUI animations have built-in start and end easing that cannot be turned off or customized.
- iOS and iPadOS add nothing further to Motion.
- The workout-app expectations in HIG Workouts: clear feedback when a session starts or stops,
  large legible text while moving, controls easy to find and tap.

## 6. Timing guidance

**Apple's HIG gives no numeric durations or easing values** for presses, state changes, reveals,
navigation transitions or completion. Any millisecond range the team picks is a design choice,
not an Apple requirement. What does exist:

| Item | Source | Value |
|---|---|---|
| Default spring duration for `.smooth/.snappy/.bouncy/.spring(duration:)` | SDK inline body (SUC:17057-17093) | 0.5 s, API default |
| Preset bounce | SDK inline body | smooth 0, snappy 0.15, bouncy 0.30 |
| `interactiveSpring(duration:extraBounce:)` default | SDK inline body | 0.15 s |
| VoiceOver value announcements while dragging | WWDC26/220 at 7:27-7:46 | demo throttles to changes at least 0.3 s apart. A sample choice, not a rule |
| Feedback "immediate" | WWDC26/220 at 1:46-2:11; WWDC26/250 at 14:54 | qualitative only |
| Accessibility "tighten springs" under Reduce Motion | HIG Accessibility | qualitative only |

## 7. Reduce Motion, transparency and haptics guidance

**Reduce Motion** (HIG Accessibility, section on fast-moving and blinking animation; SwiftUI docs).
When it is on, reduce automatic and repetitive animation including zooming, scaling and peripheral motion.
Listed practices: tighten springs to reduce bounce; track animation directly to gestures; avoid
animating depth changes; replace x/y/z transitions with fades; avoid animating into and out of blurs.
`accessibilityReduceMotion` DocC says to avoid large animations, especially those simulating the
third dimension. `accessibilityPrefersCrossFadeTransitions` says to prefer cross-fades over slides.

Proposed mapping for FORMA, consistent with the settled precedence (`reduceMotion` first, then the user
preference). The Minimal/System split is a design choice, not an Apple requirement:

| Condition | Motion | Replace with |
|---|---|---|
| Reduce Motion on | none of: zoom, push/move, scale, blur, bounce, parallax, looping symbol effects | state change with `.opacity` or no animation; keep haptic and the visible check |
| Reduce Motion off, FORMA Off | none of FORMA's own decorative motion | system transitions still occur (as the register already states) |
| Reduce Motion off, Minimal / System | gesture-tracked and short fades; springs `.smooth` | no bounce |

**Haptics** (HIG Playing haptics, Feedback; SwiftUI docs):

- Use system patterns for their documented meaning. `.success` = task or action completed (valid after
  durable save). `.warning` / `.error` = warning / failure (save failed). `.selection` = a value
  changing (steppers, pickers, segments). `.increase` / `.decrease` = an important value crossing a
  significant threshold. `.start` / `.stop` = an activity started / stopped. `.alignment` = a dragged item
  aligning. `.levelChange` = movement between discrete pressure levels (not a fit). `.impact` = physical
  metaphor to complement a visual.
- Keep each haptic tied to one cause so people learn it; do not reuse a pattern for a different outcome.
- Match haptic intensity to the accompanying animation. Prefer short haptics for discrete events.
- Avoid overuse; the best haptic is often one people miss when it is off.
- Haptics must be optional (FORMA's `hapticsEnabled` is the control) and the app must work without them.
- HIG Feedback: use more than one channel (color, text, haptic) so VoiceOver or silent-mode users still get it;
  confirm only significant completed actions, since people expect routine actions to succeed.
- Accessibility actions: expose purpose, value, action and feedback (WWDC26/220 at 3:43-3:56, 9:51-10:32);
  the haptic is never the only confirmation.

## 8. Charts guidance

- Provide a descriptive title and a one-sentence summary of the main message; units on axes (HIG Charts).
- Bar charts generally want a zero baseline; a non-zero lower bound suits other marks such as heart rate.
- Every chart must be accessible. Swift Charts supplies a per-mark accessibility element and a default
  Audio Graph. Customise with a title and descriptive summary; if you do not use Audio Graphs, provide an
  overview naming chart type, axes and bounds.
- Labels should carry context (date, session) plus the value, and describe what data means rather than colour.
  Hide visible axis/tick text from assistive technology when labels and Audio Graph already carry it.
- Marks too small to touch: widen the hit target to the plot area and let people scrub. Provide a logical
  order for keyboard, Full Keyboard Access and Switch Control.
- Animating a changed mark or axis can help sighted people notice it, but the change must also be conveyed
  without animation (VoiceOver announcement or visible text); Apple points to accessibility notifications.
- The Swift Charts overview says charts can be animated; **how Charts interpolates mark geometry
  between data states is NOT VERIFIED**. Keep the settled rule: reveal with an opacity change of the
  whole chart or none, never interpolated values.
- Nothing new in the 27.1 SDK for chart animation or selection (section 4). Selection APIs are iOS 17
  / watchOS 10 (rows 31-32). HIG "audio-graphs" slug returned 404 (NOT RETRIEVED); the Charts page text is the source.

## 9. watchOS Always On

Sources: HIG Always On; DocC "Designing your app for the Always On state"; "Updating watchOS apps with timelines".

- Apple states Always On is not available on Apple Watch SE or Series 4 and earlier. The system dims the display
  and updates the interface far less often than in the foreground.
- A frontmost app stays displayed for about two minutes by default (user-configurable, up to one hour).
- An app with a background session (workout) keeps updating, but the system refreshes the UI only about
  once per second. Pause animations, show a final or static state, remove sub-second updates.
- `TimelineView`: use the context date (not `Date.now`) because the system may ask for views up to 5 minutes
  ahead. Check `context.cadence` (`.live`, `.seconds`, `.minutes`); if the schedule is faster than the cadence,
  the system throttles. Inactive frontmost apps generally get `.minutes`; apps with background runtime
  generally `.seconds`. In low frequency mode the schedule may batch future entries.
- `isLuminanceReduced` is the signal to dim secondary content. Keep layout stable: prefer showing an
  interactive control as unavailable rather than removing it, and finish motion gracefully. Hide
  sensitive data with `privacySensitive` / `redactionReasons`.
- HIG Workouts: show time and the metrics people care about, easy-to-tap pause/resume/stop, large legible text.
- Current code (`WatchViews.swift:83`) schedules `.periodic(by: luminanceReduced ? 60 : 1)`. The docs
  support also reading `cadence`, because the system throttles regardless of the requested schedule.
- `accessibilityPrefersCrossFadeTransitions` is always false on watchOS, so Reduce Motion alone drives watch fallbacks.
- Preview with `isLuminanceReduced` and `redactionReasons` set in Xcode; the simulator has a Toggle Always On button.

## 10. Not adopted, and risks

- **`.blurReplace`**: HIG Accessibility says avoid animating into and out of blurs under Reduce Motion;
  it is also a decorative effect on frequent changes. Not adopted.
- **Looping animators**: `phaseAnimator` without `trigger` and `keyframeAnimator(repeating: true)` keep
  running; they break the frequent-action rule and battery. Trigger form only.
- **Motion on set rows**: no zoom, scale, bounce, numeric roll or symbol bounce when logging a set.
  Resolution in place (row 10 or a simple fill) only.
- **Per-second `numericText` on the rest timer**: each tick would animate. Use plain text.
- **Swift 6 closures**: `visualEffect`, `scrollTransition` and `keyframeAnimator content` closures are
  `@Sendable` (SUC:20959, SU:7455, SUC:2898); `Transition` is `@MainActor @preconcurrency` (SUC:20807).
  Capture values, not view or model references. Compile impact is unverified.
- **Get-only accessibility keys** (finding 5): wrap in a FORMA key so tests and previews can drive it.
- **zoom + matchedTransitionSource**: one namespace, both ends, iOS 18 only; the interaction with
  `NavigationStack(path:)` programmatic pushes is NOT VERIFIED. Keep default push on 17.
- **Symbol draw effects**: SF Symbols 7 feature; symbol support varies; NOT VERIFIED for the check we use.
- **Glass on animated content**: still governed by the register; `GlassEffectContainer` spacing can merge shapes.
- **Performance**: effects in lazy lists (`scrollTransition`, `visualEffect`) are unmeasured on device.
- **Charts**: interpolation unknown (section 8); do not animate data.
- **Availability vs SDK**: `#available` does not make an older SDK compile; Xcode 27.1 contains every
  symbol above. Shared code built for iOS and watchOS needs `#available(iOS X, watchOS Y, *)`.

## 11. NOT VERIFIED / NOT RETRIEVED

- NOT RETRIEVED: HIG `audio-graphs` (404). No WWDC session on Charts or motion was requested or read.
- NOT VERIFIED: Charts mark interpolation; Magic Replace start OS; draw-effect symbol coverage;
  `systemPrefersReducedResourceUsage` vs Low Power Mode; `dismissalConfirmationDialog` on iPhone;
  runtime behaviour of any API; `Cadence` ordering semantics; performance and battery.
- Not done: video-frame review, compilation, simulator or device testing, hash-for-hash match of
  the three WWDC pages with the register (lengths match, hashes differ).

## 12. Sources (retrieved 2026-10-27)

HIG (JSON at `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`; sha256 prefix, bytes):

- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) `957268c3` 31,108
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) `be49ec0b` 85,010
- [Charts](https://developer.apple.com/design/human-interface-guidelines/charts) `206a8334` 53,610
- [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) `68bab380` 51,525
- [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) `242973c8` 19,462
- [Always On](https://developer.apple.com/design/human-interface-guidelines/always-on) `c2dc9fe1` 20,645
- [Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) `a44637de` 20,914
- [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) `8150624c` 73,682

DocC (JSON at `https://developer.apple.com/tutorials/data/documentation/<path>.json`):

- [Designing your app for the Always On state](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state) `5a1ff09a` 38,263
- [Updating watchOS apps with timelines](https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines) `2d7818c0` 33,848
- [accessibilityPrefersCrossFadeTransitions](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityprefersCrossFadeTransitions) `8b6e5930`
- [systemPrefersReducedResourceUsage](https://developer.apple.com/documentation/swiftui/environmentvalues/systemprefersreducedresourceusage) `69d31363`
- [NavigationTransition.crossFade](https://developer.apple.com/documentation/swiftui/navigationtransition/crossfade) `3604e1eb`
- Symbol pages read for availability and abstracts (sha prefix in parentheses where noted):
  [withAnimation completion](https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)) (`4b78ddd1`),
  [Animation.spring](https://developer.apple.com/documentation/swiftui/animation/spring(duration:bounce:blendduration:)) (`0d0cfc99`),
  [smooth](https://developer.apple.com/documentation/swiftui/animation/smooth), [snappy](https://developer.apple.com/documentation/swiftui/animation/snappy), [bouncy](https://developer.apple.com/documentation/swiftui/animation/bouncy),
  [animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)), [animation(_:body:)](https://developer.apple.com/documentation/swiftui/view/animation(_:body:)),
  [PhaseAnimator](https://developer.apple.com/documentation/swiftui/phaseanimator), [phaseAnimator(trigger)](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:trigger:content:animation:)),
  [KeyframeAnimator](https://developer.apple.com/documentation/swiftui/keyframeanimator), [keyframeAnimator(trigger)](https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)),
  [numericText(value:)](https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(value:)), [numericText(countsDown:)](https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(countsdown:)),
  [symbolEffect](https://developer.apple.com/documentation/swiftui/view/symboleffect(_:options:value:)), [ContentTransition.symbolEffect](https://developer.apple.com/documentation/swiftui/contenttransition/symboleffect(_:options:)),
  [Transition](https://developer.apple.com/documentation/swiftui/transition), [AnyTransition](https://developer.apple.com/documentation/swiftui/anytransition), [blurReplace](https://developer.apple.com/documentation/swiftui/transition/blurreplace),
  [push(from:)](https://developer.apple.com/documentation/swiftui/anytransition/push(from:)), [move(edge:)](https://developer.apple.com/documentation/swiftui/anytransition/move(edge:)),
  [matchedGeometryEffect](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)),
  [zoom(sourceID:in:)](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)), [matchedTransitionSource](https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:)),
  [sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)), [with condition](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:)), [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback), [press(_:)](https://developer.apple.com/documentation/swiftui/sensoryfeedback/press(_:)),
  [scrollTransition](https://developer.apple.com/documentation/swiftui/view/scrolltransition(_:axis:transition:)), [visualEffect](https://developer.apple.com/documentation/swiftui/view/visualeffect(_:)),
  [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview), [TimelineSchedule](https://developer.apple.com/documentation/swiftui/timelineschedule),
  [chartXSelection](https://developer.apple.com/documentation/swiftui/view/chartxselection(value:)), [chartScrollableAxes](https://developer.apple.com/documentation/swiftui/view/chartscrollableaxes(_:)),
  [accessibilityChartDescriptor](https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)), [AXChartDescriptor](https://developer.apple.com/documentation/accessibility/axchartdescriptor),
  [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), [accessibilityReduceTransparency](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency),
  [colorSchemeContrast](https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast), [legibilityWeight](https://developer.apple.com/documentation/swiftui/environmentvalues/legibilityweight), [isLuminanceReduced](https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced).

WWDC26 (transcripts via the video pages):

- [269 What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/): reorderable containers 15:32-17:09; swipe actions on any view 17:44-18:22; no new animation, haptic or chart API beyond reorder's built-in animation.
- [250 Principles of great design](https://developer.apple.com/videos/play/wwdc2026/250/): responsive, fluid feedback 14:54-15:00; delight is not confetti or late flourishes 16:05-16:24.
- [220 Refine accessibility for custom controls](https://developer.apple.com/videos/play/wwdc2026/220/): purpose, value, action, feedback 3:43-3:56; announcement throttle 7:27-7:46; custom actions 9:51-10:32.

Local SDK: Xcode 27.1 (27A9275), iPhoneOS SDK 27.1, WatchOS SDK 27.0 (paths in section 1).
