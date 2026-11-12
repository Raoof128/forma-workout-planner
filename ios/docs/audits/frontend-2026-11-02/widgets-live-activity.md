# Widgets and workout Live Activity: front-end audit, 2 November 2026

**Slice:** `ios/FORMAWidgets/` (bundle, `TrainingWidget`, `WorkoutLiveActivity`, entitlements),
`ios/WidgetPresentation/` (`TrainingWidgetView`, `WorkoutActivityViews`, `WorkoutActivityIntents`,
`WorkoutActivityAttributes`), plus `Sources/FORMASurfaces/{TrainingPresentation,WorkoutActivityState,BrandPalette,WidgetRoute}.swift`
and `FORMA/App/WorkoutLiveActivityController.swift`. Branch `feat/watch-collected-data`.

**Method:** static review only. I read every view file in full and checked it against Apple's current
HIG and WidgetKit/ActivityKit documentation. I fetched these pages on 2 November 2026 as `.md`, and
the HIG Live Activities change log shows an update on 13 October 2026. I computed the contrast ratios
with the WCAG formula. I read the repo's audit docs (`WIDGETKIT_ARCHITECTURE.md`, source register, executive audit,
`full-audit-2026-10-26.md`, `apple-design-2026.md`) so that items already decided are not re-raised without new
evidence. **Nothing was run on a device or simulator.** Every rendering-mode, Lock Screen, StandBy, Watch and CarPlay
statement below needs on-device confirmation. I list the open questions for each finding.

Skills applied: frontend-design (copy and typographic restraint), ui-ux-pro-max (`--stack swiftui`, `--domain ux`,
`references/pro-rules.md` Pre-Delivery Checklist; results folded into the checklist below).

---

## 1. Pass/fail checklist (HIG areas for this slice)

| Area | Result | Notes |
| --- | --- | --- |
| Widget families: small/medium/large/circular/rectangular/inline composed per family | PASS | Distinct composition per family; compact layouts at large text. |
| Full-color rendering, light and dark | PASS | Semantic container background; contrast ≥5.5:1 (table in §3). |
| Accented/tinted and iOS 26 clear (Liquid Glass) | PASS (source), device-unverified | `widgetRenderingMode` switches to `.primary`/`.secondary`; `widgetAccentable` groups; no full-color images. |
| Vibrant (Lock Screen, StandBy Night Mode) | PASS (source), device-unverified | Hierarchical `.primary`/`.secondary` grays, no colour-only meaning. |
| Removable background (StandBy, CarPlay) | PASS | `containerBackground(for: .widget)`, removable by default. |
| Widget privacy / redaction | PASS | `.privacy` → generic fallback; `privacySensitive` only on personal layouts; Complete data protection. |
| Widget deep links | PASS | One `widgetURL` and extra `Link`s only in medium and large. The route grammar is validated. |
| Widget Dynamic Type (Large to AX5) | PARTIAL | Home families adapt; scale factors push some text below 11 pt (L1); rectangular fallback is dense (L8). |
| Live Activity: tap opens the right place | **FAIL** | No `widgetURL` on any presentation (H1). |
| Live Activity: visible while locked | **AT RISK (unconfirmed)** | It shares an extension with `NSFileProtectionComplete` (H2). |
| Live Activity: sensitive info | PASS (source), device-unverified | Neutral title; names marked `privacySensitive`; in-app off switch. |
| Dynamic Island compact / minimal / expanded | PARTIAL | Compact leading carries the meaning alone. The trailing timer does not fit the 28 pt limited-width circle on iOS 27 (M3), and minimal shows only the logo when not resting (L4). |
| Lock Screen layout (84–160 pt, 14 pt margins) | PARTIAL | `ViewThatFits` handles height. Margins are 16/12 pt rather than 14 (L2). |
| Lock Screen colours, Dark Mode, Always On | PASS (contrast), device-unverified | Brand pairs 5.3–15.6:1; `isLuminanceReduced` not read (L5). |
| Dismiss button colour | PASS | `activitySystemActionForegroundColor` set per appearance. |
| Key line tint | PASS | `.keylineTint(lime)`. |
| StandBy (Live Activity) | PARTIAL | No `isActivityFullscreen` handling; Night Mode tint unverified (L5). |
| Apple Watch Smart Stack / CarPlay `.small` | PARTIAL | Correctly has no buttons; palette hard-coded dark (M2). |
| Timers | PASS | `Text(timerInterval:)` / `ProgressView(timerInterval:)` from saved dates; stale date → "Rest over". The circular ring is a known device gate. |
| Interactivity (intents) | PARTIAL | `LiveActivityIntent` with unlock; two adjacent 40 pt buttons (M4). |
| VoiceOver | PARTIAL | Elapsed timer label hides the time (M1); duplicate "FORMA workout" (L3). |
| Touch targets ≥44 pt (pro-rules) | PARTIAL | 40 pt buttons: above Apple's 28 pt minimum, below the 44 pt default (M4). |
| Colour not the only indicator | PASS | Day marks change shape (filled check vs ring); rest state is labelled with words. |
| Deprecated APIs | PASS | `ActivityContent`-based request/update/end and `containerBackground`. No deprecated `contentState:` calls. |
| iOS 17 floor / newer APIs gated | PASS | iOS 18 `.small` gated by the dual bundle. No iOS 27-only API. |

---

## 2. Findings

### High

#### H1. Tapping the Live Activity never opens the workout (no deep link on any presentation)

- **Where:** `ios/FORMAWidgets/WorkoutLiveActivity.swift:26-55` (no `widgetURL` on the Lock Screen root or on
  `DynamicIsland`). Related: `FORMA/App/AppModel+WidgetRouting.swift:27-29` and `FORMA/App/FORMAApp.swift:213-216`.
- **Evidence:**
  ```swift
  ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
    WorkoutActivityRoot(sessionID: ..., state: context.state, isStale: context.isStale)
    .activityBackgroundTint(WorkoutActivityPalette.backgroundTint)
    ...
  } dynamicIsland: { context in DynamicIsland { ... } ... .keylineTint(WorkoutActivityPalette.lime) }
  ```
  The only workout route is gated on the widget consent, which is a separate setting:
  ```swift
  case .active(let id, let epoch):
    guard widgets.sharing, epoch == widgets.epoch, workspace?.active?.id == id else { return .unavailable }
  ```
- **Apple guidance:** HIG Live Activities: "Make sure tapping the Live Activity opens your app at the right
  location. Take people directly to related details and actions". For the compact presentation it adds "Link to
  relevant app content … Ensure both leading and trailing elements link to the same screen."
  <https://developer.apple.com/design/human-interface-guidelines/live-activities>. WidgetKit: "By default, tapping …
  your widget or Live Activity opens its corresponding app … add the `widgetURL(_:)` modifier"
  <https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity>.
- **User impact:** A tap on the Lock Screen card, compact, minimal or StandBy presentation opens FORMA wherever it was
  left. After a cold launch that is Today with the resume bar, not the workout. The "Open FORMA to update" stale copy
  sends people to a screen that is not the workout. Reusing `.active(id:epoch:)` as-is would be worse: a person
  with widget sharing off would get "That saved item is no longer available".
- **Fix:** add a Live Activity route that is not gated on widget sharing and is checked only against the active
  session and owner epoch (the attributes already carry both). Apply it once per hierarchy.
  ```swift
  // WidgetRoute: case workout(id: String, epoch: String)  -> forma://widget/workout?id=…&epoch=…
  ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
    WorkoutActivityRoot(...)
      .widgetURL(WidgetRoute.workout(id: context.attributes.sessionID,
                                     epoch: context.attributes.ownerEpoch).url)
      ...
  } dynamicIsland: { context in
    DynamicIsland { ... } compactLeading: { ... } compactTrailing: { ... } minimal: { ... }
      .widgetURL(WidgetRoute.workout(id: context.attributes.sessionID,
                                     epoch: context.attributes.ownerEpoch).url)
      .keylineTint(WorkoutActivityPalette.lime)
  }
  // AppModel.widgetDestination: case .workout(let id, let epoch):
  //   guard epoch == widgets.epoch, workspace?.active?.id == id else { return .today }
  //   return .active
  ```
  Extend `check-ios-widget-bundle.py` and the route tests to cover the new path.

#### H2. The Live Activity may be hidden while the iPhone is locked, because it shares the widget extension's Complete data protection (unconfirmed; verify on a device first)

- **Where:** `ios/FORMAWidgets/FORMAWidgets.entitlements:5-6`; `ios/FORMAWidgets/FORMAWidgetBundle.swift:9-22`
  (`WorkoutLiveActivity` lives in the same extension as `TrainingWidget`).
- **Evidence:**
  ```xml
  <key>com.apple.developer.default-data-protection</key>
  <string>NSFileProtectionComplete</string>
  ```
- **Apple guidance:** "Creating a widget extension › Hide sensitive content": "`NSFileProtectionComplete`: WidgetKit
  hides widget content when the device is locked … Until a person unlocks their device … WidgetKit displays a
  placeholder instead of the widget content"
  <https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension>. Apple does not say whether this
  extension-wide policy also applies to an `ActivityConfiguration` in the same extension: **unconfirmed**. A developer
  forum report says that once the Data Protection capability is added, "everything on the widget gets redacted"
  <https://developer.apple.com/forums/thread/716031>. That report is about widgets, not Live Activities.
- **User impact (if it applies):** the Lock Screen card, StandBy and possibly the Island show a placeholder exactly
  when the phone is locked on the bench. That is the main use case, so the feature and its buttons would be mostly
  invisible. The existing gate list checks the opposite risk ("a locked phone shows nothing private"), not this one.
- **Fix:** first test it. Lock a passcode iPhone mid-workout and look at the card, StandBy and the Island. If it is
  redacted, move the Live Activity into its own widget extension without `default-data-protection` and without the
  App Group, since the activity reads no storage. Keep `TrainingWidget` in the Complete-protected extension. Keep
  `privacySensitive` on the routine and exercise names so the system's "Allow access when locked" setting still
  applies. Each extension then has a single `@main` bundle, which also removes the dual-bundle dispatch for the
  Training widget.

### Medium

#### M1. VoiceOver hears "Elapsed time" but not the time (label overrides the timer text)

- **Where:** `WidgetPresentation/WorkoutActivityViews.swift:291-293` (Lock Screen header) and `:374-375` (compact
  trailing).
- **Evidence:**
  ```swift
  WorkoutTimer(range: state.elapsedRange, countsDown: false, maxWidth: 72)
    .font(.caption.weight(.semibold)).foregroundStyle(palette.primary)
    .accessibilityLabel("Elapsed time")
  ```
  `accessibilityLabel` on a `Text` replaces its spoken content. The expanded trailing view does this correctly
  (`Text("Elapsed")` plus the timer under `.accessibilityElement(children: .combine)`, lines 419-424).
- **Apple guidance:** the HIG Accessibility page asks that every element have a descriptive label, and the value is
  what a timer is for <https://developer.apple.com/design/human-interface-guidelines/accessibility>. The pro-rules
  checklist also asks for "interactive labels are descriptive".
- **User impact:** a VoiceOver user cannot hear how long the workout has run, either in the Island or on the Lock
  Screen.
- **Fix:** keep the label and give the timer as the value, then confirm on a device that VoiceOver reads the live
  value:
  ```swift
  .accessibilityLabel("Elapsed time")
  .accessibilityValue(Text(timerInterval: state.elapsedRange, countsDown: false))
  ```
  If the value does not read live on the device, reuse the expanded-trailing pattern: a `Text("Elapsed")` (visually
  hidden in the compact view) combined with the timer.

#### M2. The `.small` (Apple Watch Smart Stack / CarPlay) view hard-codes the dark palette

- **Where:** `WidgetPresentation/WorkoutActivityViews.swift:311-341`, especially `:314`
  (`private let palette = WorkoutActivityPalette.dark`) and `:326-328` (exercise name with no explicit foreground).
- **Evidence:** the ring and mark use `palette.accent`, which is lime `#DFF780`. The secondary text uses `#B9C2BC`.
  The name falls back to `.primary`, which adapts to the appearance.
- **Apple guidance:** HIG Live Activities: "Your Live Activity design applies to both CarPlay and Apple Watch, so
  design for both contexts". The same page says to match "your app's visual aesthetic … in both dark and light
  appearances" <https://developer.apple.com/design/human-interface-guidelines/live-activities>. ActivityKit:
  `.small` is the custom layout for Apple Watch and CarPlay
  <https://developer.apple.com/documentation/activitykit/creating-custom-views-for-live-activities>. Whether CarPlay
  renders `.small` with a light colour scheme or with the `activityBackgroundTint` is **unconfirmed**.
- **User impact:** if CarPlay or another host renders `.small` light, the lime ring and mark measure 1.18:1 on
  white. On the lime tint they measure 1.00:1. The name and mark would be in mixed palettes. The Watch Smart Stack,
  which is black, is fine.
- **Fix:** derive the palette from the environment, as the Lock Screen view does, and give the name an explicit
  style. Then check in the CarPlay Simulator in both appearances, and on the Watch.
  ```swift
  @Environment(\.colorScheme) private var colorScheme
  private var palette: WorkoutActivityPalette { .init(isDark: colorScheme == .dark) }
  Text(state.exercise).font(.headline).foregroundStyle(palette.primary)
  ```

#### M3. The compact trailing timer does not fit the iOS 27 limited-width Island (28 pt)

- **Where:** `WidgetPresentation/WorkoutActivityViews.swift:345-381` (`WorkoutTimer(... maxWidth: 48)` at `:369`
  and `:374`).
- **Evidence:** the comment says the leading view "carries the meaning on its own", but the trailing view is
  never empty.
- **Apple guidance (new since the repo's decision):** the HIG change log for 13 October 2026 adds: "adapt your
  compact and minimal presentations to fit inside a 28pt-diameter circle … If limited width versions of both …
  don't make sense … adopt a leading view only and leave the trailing view empty; the system automatically hides
  the trailing view" <https://developer.apple.com/design/human-interface-guidelines/live-activities>.
  `isDynamicIslandLimitedInWidth` is iOS 27.0+, and its documentation mentions "iPhone in landscape orientation
  or on iPhone Duo" <https://developer.apple.com/documentation/swiftui/environmentvalues/isdynamicislandlimitedinwidth>.
- **User impact:** on iOS 27 in landscape, or on iPhone Duo, a 48 pt "1:23" is squeezed into 28 pt and will be
  truncated or scaled until it is unreadable. The system hides the trailing view only when it is empty.
- **Fix:** keep the iOS 26.2 CI SDK working by gating on the compiler. Xcode 27 ships Swift 6.4, as recorded in
  `full-audit-2026-10-26.md`.
  ```swift
  #if compiler(>=6.4)
  @available(iOS 27.0, *)
  private struct LimitedAwareTrailing: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    var state: WorkoutActivityState; var isStale: Bool
    var body: some View { if !limited { IslandCompactTrailing(state: state, isStale: isStale) } }
  }
  #endif
  ```
  Use this view from `compactTrailing` behind `if #available(iOS 27, *)`, and update the bundle checker's
  "no `isDynamicIslandLimitedInWidth`" assertion so it allows the compiler-gated use.

#### M4. Two adjacent 40 pt intent buttons while resting (accidental-tap risk)

- **Where:** `WidgetPresentation/WorkoutActivityViews.swift:149-166` (`minHeight: 40`) and `:176-194`
  (`HStack(spacing: 8)` with "Complete set" and "Skip rest").
- **Apple guidance:** HIG Live Activities: "If you offer interactivity, prefer limiting it to a single element to
  help people avoid accidentally tapping the wrong control" <https://developer.apple.com/design/human-interface-guidelines/live-activities>.
  HIG Accessibility gives 44x44 pt as the default control size (28 pt minimum)
  <https://developer.apple.com/design/human-interface-guidelines/accessibility>.
- **User impact:** mid-set, with sweaty hands or gloves, a miss between "Complete set" and "Skip rest" commits the
  wrong change after Face ID. Both intents require authentication, so the error is not caught before it is saved.
- **Fix:** show one context-dependent action: "Skip rest" while resting, "Complete set" otherwise. Make it at least
  44 pt high. If both must stay, use `minHeight: 44` and `spacing: 12`, and check the expanded Island stays within
  its 160 pt height.

### Low

- **L1. Text can shrink below 11 pt.** `TrainingWidgetView.swift:219-220` scales the weekday initials (caption2) by
  `minimumScaleFactor(0.6)`, which is about 6.6 pt. The same factor is used at `:261` and in
  `WorkoutActivityViews.swift:113` (caption timer to about 7 pt). HIG Widgets: "display text using fonts at 11 points
  or larger" <https://developer.apple.com/design/human-interface-guidelines/widgets>. Fix: floor at 0.85 for
  caption2/caption, or drop the letters (`dayMarks(letters: false)`) when they do not fit, using `ViewThatFits`.
- **L2. Lock Screen margins are 16/12 pt, not the standard 14.** `WorkoutActivityViews.swift:247-248`. HIG: "The
  standard layout margin for Live Activities on the Lock Screen is 14 points." Fix: `.padding(14)`. This also
  gives about 4 pt more height inside the 160 pt cap at AX1.
- **L3. Duplicate VoiceOver announcement.** `WorkoutMark` (`:85`, labelled "FORMA workout") sits next to
  `Text("FORMA workout")` in the header (`:281-285`). Fix: `.accessibilityHidden(true)` on the mark in the header.
  It stays labelled in the Island, where it stands alone.
- **L4. Minimal presentation shows only the logo when not resting.** `:383-395`. HIG: "If possible, display updated
  information rather than just a logo." Fix: when not resting, show the elapsed minutes in the minimal view, with
  `caption2` and `monospacedDigit` at 36 pt or less wide. This is optional.
- **L5. Always On and StandBy are not adapted.** `isLuminanceReduced` and `isActivityFullscreen` are never read. The
  ActivityKit documentation says Always On renders Lock Screen Live Activities "as if in Dark Mode" and recommends
  `isLuminanceReduced`. The HIG says "Consider using the default background color in StandBy" and "Verify your
  design in Night Mode"
  (<https://developer.apple.com/documentation/activitykit/creating-custom-views-for-live-activities>,
  <https://developer.apple.com/documentation/swiftui/environmentvalues/isactivityfullscreen>). The current dark
  pairs already pass contrast, so this is polish. The fix is to scale up the timer when `isActivityFullscreen` is
  true and check Night Mode on a device.
- **L6. Brand chrome and filler copy in the widget.** The "FORMA" brand row appears in every Home family
  (`TrainingWidgetView.swift:111-117`). Hard-coded all-caps strings appear at `:175` "THIS WEEK" and at
  `TrainingPresentation.swift:80-81` "A LITTLE, CONSISTENTLY". Slogan copy in the week focus repeats the count
  (`:163`, `:167`). HIG Widgets: "people seldom need your logo … a small logo in the top-right corner is sufficient".
  frontend-design: avoid all-caps labels and filler. Fix: drop or shrink the brand row on small, write sentence-case
  strings and use `.textCase(.uppercase)` only if the style is wanted, and replace the slogans with facts (for
  example the next session name).
- **L7. Forced left-to-right in the `.small` view.** `WorkoutActivityViews.swift:331`
  `.environment(\.layoutDirection, .leftToRight)` breaks a right-to-left locale. Fix: remove it, and use
  `.multilineTextAlignment(.leading)` on `RestReadout` for this family.
- **L8. The rectangular Lock Screen fallback is dense.** `TrainingWidgetView.swift:264-270` stacks a label, a
  headline and two lines of caption (for example "Your saved training is safe. This refreshes shortly after you
  unlock.") in roughly 72 pt. The data layout at `:244-253` stacks three lines. HIG: widgets support Dynamic Type
  up to AX5. Whether Lock Screen accessory text scales that far is unconfirmed. Fix: use
  `ViewThatFits(in: .vertical)` with a two-line variant (title plus `content.inline`).
- **L9. Elapsed time with `showsHours: false`.** `:110`. Past 60 minutes the timer reads "75:03" in a 48 pt slot.
  Fix: use `showsHours: true` in expanded and Lock Screen views, and keep the compact slot width-capped.
- **L10. The circular accessory fallback has no `AccessoryWidgetBackground`.** `TrainingWidgetView.swift:258-262`.
  The gauge state has its own track, but the symbol-plus-"FORMA" fallback floats with no disc
  <https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background>. Fix:
  `ZStack { AccessoryWidgetBackground(); … }`.
- **L11. No Dynamic Type bound on the Island and `.small` views (unconfirmed).** Only the Lock Screen view caps
  text at `.accessibility1`. Whether the system clamps text size in the Island and the Smart Stack is not documented
  on the pages I checked. Fix: if a device run shows clipping, add `.dynamicTypeSize(...DynamicTypeSize.xxLarge)`
  to the compact, minimal and `.small` roots.

---

## 3. Already correct (keep)

- **Contrast (WCAG ratios computed from `BrandPalette`):**

  | Pair | Ratio |
  | --- | --- |
  | Lock Screen light: ink on lime | 13.2 |
  | Lock Screen light: `#59635D` on lime | 5.3 |
  | Lock Screen dark: white on ink | 15.6 |
  | Lock Screen dark: `#B9C2BC` on ink | 8.5 |
  | Lock Screen dark: lime on ink | 13.2 |
  | Island: `#B9C2BC` on black | 11.5 |
  | Island: lime on black | 17.8 |
  | Widget light: accent `#4C631C` on `#F2F2F7` | 6.1 |
  | Widget light: secondary `#59635D` on `#F2F2F7` | 5.6 |
  | Widget dark: lime on `#1C1C1E` | 14.4 |
  | Widget dark: `#B9C2BC` on `#1C1C1E` | 9.3 |

  Increase Contrast tokens are used in the widget.
- **Rendering modes:** `widgetRenderingMode` swaps brand colours for `.primary` and `.secondary` outside full
  colour. `widgetAccentable` marks title, count, brand and action. There are no full-color images, so nothing needs
  `widgetAccentedRenderingMode`. This matches "Optimizing your widget for accented rendering mode and Liquid Glass"
  <https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass>.
- **Widget privacy:** under `.privacy` redaction the view switches to a generic fallback, and that fallback is not
  marked `privacySensitive`, so "Training is private" stays readable. Complete data protection is on the Training
  widget, and gallery data is synthetic only.
- **Widget links:** one `widgetURL` per hierarchy. `Link`s appear only in medium and large. The circular gauge goes
  to Progress. The parser rejects unknown hosts, schemes, ports, fragments and duplicate keys.
- **Timeline:** expiry entries, a backed-off locked retry, and relevance capped at 30 minutes. There is no polling.
- **Live Activity lifecycle** follows the HIG's "Update … only when new content is available" and "Always end … immediately":
  - it updates only when the mapped state changes;
  - timers are system-driven from saved dates;
  - the stale date makes it show "Rest over" instead of 0:00;
  - it ends with `.immediate` and reconciles orphans after relaunch;
  - only one activity exists at a time, with `pushType: nil` and a payload under 1 KB.
- **Live Activity presentation:**
  - the neutral "FORMA workout" title, with routine and exercise names `privacySensitive`;
  - the logo mark has no container, per the HIG;
  - `activitySystemActionForegroundColor` is tuned per appearance, per the HIG's "Verify the generated color of the dismiss button";
  - `keylineTint` is set;
  - `ViewThatFits` keeps the card within 160 pt;
  - the `.small` family has no buttons, per the HIG's CarPlay guidance.
- **Intents:** `LiveActivityIntent`s run in the app's process. They are `isDiscoverable = false`, require unlock
  (consistent with the Complete-protected store), and ignore a stale session.
- **Settings and availability:** an in-app switch, "Show workout on Lock Screen", matches the HIG's "make it easy to
  turn off in your app". The iOS 17 floor is respected with iOS 18 `.small` behind the dual bundle. No deprecated
  ActivityKit or WidgetKit API is used.

## 4. Device checks this audit could not do

In priority order:

1. H2: Live Activity on a locked passcode iPhone (card, StandBy, Island).
2. H1: cold-launch tap routing after the fix.
3. M1: VoiceOver reading the live elapsed value.
4. M2: `.small` view in the CarPlay Simulator, light and dark.
5. M3: iOS 27 landscape Island.
6. Circular `ProgressView(timerInterval:)` rendering as a ring rather than a spinner (already a repo gate).
7. Tinted, clear, vibrant and StandBy Night Mode captures of the Training widget (already a repo gate).

## 5. Resolution (branch `fix/audit-widgets`)

Static fixes, compiled for a device (`generic/platform=iOS`) and covered by `swift test` and the app tests where a
test can see the behaviour. Nothing here was run on the iPhone Air or the Watch, so every device check in §4 is
still open.

| # | Status | Change |
| --- | --- | --- |
| H1 | Fixed | New `WidgetRoute.workout(id:epoch:)` (`forma://widget/workout?id=…&epoch=…`). Both Live Activity hierarchies (Lock Screen root and `DynamicIsland`) carry one `widgetURL` to it. `AppModel.widgetDestination` opens the workout when the session and owner epoch match, without the widget-sharing gate, and goes to Today otherwise. Route round trip, malformed-link and routing tests added; the bundle checker asserts both links. Cold-launch tap still needs the device (§4 item 2). |
| H2 | Fixed, device check open | The Live Activity moved to its own extension, `FORMAWorkoutActivity.appex` (`dev.raoufabedini.forma.workoutactivity`), with no App Group and no data-protection entitlement. `FORMAWidgets.appex` keeps the Training widget, the App Group and `NSFileProtectionComplete`, and is now a single `@main` bundle. New evidence that settled the "unconfirmed": an Apple engineer on the developer forums (thread 806236) says that with `NSFileProtectionComplete` the widget extension gets no runtime while the device is locked. The checker now validates both extensions and fails if the activity extension gains an App Group, data protection, HealthKit or a storage read. Still verify on a locked passcode iPhone (§4 item 1). |
| M1 | Fixed, device check open | The elapsed timer keeps the label "Elapsed time" and passes the running time as `accessibilityValue` (Lock Screen header and compact trailing). Confirm VoiceOver reads the live value. |
| M2 | Fixed, device check open | `.small` derives its palette from the colour scheme; the exercise name and set line have explicit styles. CarPlay Simulator check in both appearances still open. |
| M3 | Fixed, device check open | Compact trailing goes through `IslandCompactTrailingSlot`: on iOS 27, when `isDynamicIslandLimitedInWidth` is true, it is empty so the system hides it. Gated by `#if compiler(>=6.4)` so the iOS 26.2 SDK still builds; the checker allows the symbol only inside that gate. |
| M4 | Fixed | One action at a time: "Skip rest" while a rest is on screen, otherwise "Complete set" (or the all-sets-done note). Buttons are 44 pt high. |
| L1 | Fixed | Weekday initials no longer scale; `ViewThatFits` drops them when they do not fit. Timer and circular fallback floors are 0.85 or fixed size. |
| L2 | Fixed | Lock Screen padding is 14 pt. |
| L3 | Fixed | The header mark is hidden from VoiceOver next to "FORMA workout". |
| L4 | Not changed | Optional. A self-updating minutes-only clock that fits 36 pt has no system text style (`Text(timerInterval:)` always shows seconds), so minimal keeps the mark when not resting. |
| L5 | Partly fixed | In StandBy (`isActivityFullscreen`) the rest timer uses `.largeTitle`. Always On already renders the passing dark pairs; Night Mode needs the device. |
| L6 | Fixed | Sentence-case labels ("Weekly goal", "Saved workout", "Your next session", "This week" / "Days trained"); the slogans are gone and the week view says what is left (`weekDetail`, "2 more workouts to reach 4"). The brand row is dropped from the small widget. |
| L7 | Fixed | The forced left-to-right is gone; `RestReadout` and `WorkoutTimer` take a leading alignment in `.small`. |
| L8 | Fixed | Rectangular data and fallback layouts use `ViewThatFits(in: .vertical)` with a two-line variant. |
| L9 | Fixed | `showsHours: true` on the Lock Screen header and the expanded Island; the compact slot keeps its capped width. |
| L10 | Fixed | The circular fallback sits on `AccessoryWidgetBackground()`. |
| L11 | Not changed | The audit's fix is conditional on a device run showing clipping; capping Dynamic Type without that evidence would cost readers text size for nothing. |
