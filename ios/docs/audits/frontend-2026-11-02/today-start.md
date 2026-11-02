# Today tab and workout start flow: front-end audit, 2 November 2026

Slice: `ios/FORMA/Features/TodayView.swift` (518 lines), `ios/FORMA/Features/StartWorkoutSheet.swift` (257 lines, including `WatchRecordingStrip`). I read both files in full, along with the design-system types they use (`FormaTheme`, `FormaComponents`, `GlassControls`, `FormaMotion`, `FormaHaptics`, `PressableCardStyle` in `PlanView.swift`, `MediaPhoto` in `ExerciseMedia.swift`). I also read the presentation and start code in `FORMAApp.swift:84-92`, `AppModel.swift:105-130, 324-380` and `WatchWorkoutCoordinator.swift`.

Worktree: `repository root` (branch `feat/watch-collected-data`). This is a read-only static review: nothing was edited, built or run, and no simulator was used (the project rule is device-only). Every finding about rendered geometry, spoken VoiceOver output or iOS 26 material is marked as needing on-device confirmation.

To avoid repeating decided work, I checked these first: `ios/docs/apple-design-2026.md`, `native-design-review.md`, `full-audit-2026-10-26.md`, `docs/commit-2/MOTION_SPEC.md` and `docs/audits/frontend-widget-2026-10/*`. Some items are already decided and are **not** re-reported here:
- the staggered Today entrance (MOTION_SPEC row "Today entrance");
- Today's Start geometry at accessibility sizes and in landscape (IF-06, covered by `TodayLayoutAndWidgetRoutingTests`);
- calendar rollover (IF-04);
- the delayed-Start owner scoping (IF-03);
- opaque content surfaces with glass reserved for controls.

Contrast ratios below were computed with the WCAG relative-luminance formula from the hex values in `FormaTheme.swift` / `BrandPalette.swift`.

Apple sources used (all fetched 2 November 2026; `.md` suffix used for readable text):
- HIG Sheets (change log: 24 March 2026), https://developer.apple.com/design/human-interface-guidelines/sheets
- HIG Accessibility, https://developer.apple.com/design/human-interface-guidelines/accessibility
- HIG VoiceOver, https://developer.apple.com/design/human-interface-guidelines/voiceover
- HIG Typography (change log: 16 December 2025), https://developer.apple.com/design/human-interface-guidelines/typography
- Adopting Liquid Glass, https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- `ButtonRole.close` (iOS 26.0), https://developer.apple.com/documentation/swiftui/buttonrole/close
- `scrollEdgeEffectStyle(_:for:)` (iOS 26.0), https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)
- `accessibilityIgnoresInvertColors(_:)` (iOS 14.0), https://developer.apple.com/documentation/swiftui/view/accessibilityignoresinvertcolors(_:)
- `AccessibilityNotification`, https://developer.apple.com/documentation/accessibility/accessibilitynotification

---

## 1. HIG checklist for this slice

| Area | Verdict | Note |
|---|---|---|
| Liquid Glass adoption and fallbacks | **Pass**, one caveat | Today's content is opaque, which is correct ("Don't use Liquid Glass in the content layer"). The start sheet paints an opaque canvas over the system sheet and has no partial detent, so it never gets the iOS 26 inset glass sheet (M1). |
| Typography / Dynamic Type | **Partial** | Today reflows well (stacked header, art and slogan dropped, hero action kept above the fold). The start sheet has no equivalent accessibility-size handling (M2). The week circles have a fixed size (L4). |
| Colour / contrast, light and dark | **Pass** | All text pairs in the slice are at least 5.7:1. Lime on hero ink is 14.9:1, hero detail on ink 13.7:1, secondary on canvas 5.75:1 (light) and 9.65:1 (dark), error on surface 6.6:1 and 9.0:1. |
| Increase Contrast | **Pass** | Every adaptive token has high-contrast variants. Hero colours are fixed on a fixed ink panel. |
| Tap targets (44 pt) | **Partial** | Primary 56 pt, Choose-another 44 pt, See-all 44 pt. **Check again** is a default-size `.bordered` button with no minimum height (M3). |
| Spacing / safe areas | **Partial** | The custom tab bar inset is handled by `formaTabRoot`. Spacing literals (22, 5, 6, 10) ignore `FormaSpacing` (L6). Scrolling under the status bar with the navigation bar hidden needs a device check (L8). |
| VoiceOver labels / traits / order | **Fail** | The start sheet loses focus and never announces state changes (H1). The live strip says "Recording" while paused (H2). The screen has no title and its rotor headings are slogans (M6). |
| Reduce Motion | **Pass** | Every animation in the slice goes through `formaAnimation` / `withFormaAnimation` / `motion.transition` / `formaReveal`. No feature view reads `accessibilityReduceMotion` (CLAUDE.md rule met). |
| Reduce Transparency | **Pass (n/a)** | The slice has no custom materials. The only gradient is opaque ink over the photo. |
| Haptics | **Pass** | `.started` plays only after the start commit succeeds (`AppModel.swift:357-361`), and `.failed` plays on a failed commit. The views fire no haptics of their own, which is correct. |
| Navigation patterns | **Pass** | Value-based `NavigationLink(value:)`, a Menu+Picker for the session choice, and See-all switches tab with a hint. |
| Sheet presentation / detents | **Fail** | No detents (large only) for a short decision sheet, and no grabber (M1). Cancel is on the leading edge, which is correct. |
| Copy / wording | **Partial** | The sheet can say "1 exercises", and its eyebrow says "YOUR NEXT SESSION" when the start came from Plan (M4). A few phrases could be plainer (L1, L9). |
| Empty and error states | **Partial** | Errors are inline and announced. The empty Today offers no action and shows a "0 routines" section (M5). |
| Consistency between screens | **Partial** | Hero pending feedback differs between compact and regular layouts (L5). Card edges are treated differently (L7). |
| Deprecated APIs | **Pass** | No deprecated API found. All iOS 17 APIs are used correctly (`ContentUnavailableView`, the two-parameter-free `onChange`, `AccessibilityNotification.Announcement`). |

---

## 2. Findings

### High

#### H1. The Watch start sheet drops VoiceOver focus and announces neither state changes nor notices
**Where:** `StartWorkoutSheet.swift:42-63, 117-143, 29-33, 91-94`

```swift
if model.watch.availability == .ready, model.watch.phase == .idle {
  Button { opening = true; Task { await model.watch.open(routine: routine); opening = false } } ...
```
```swift
// The failure is announced when it appears, since the sheet is modal.
.task(id: model.errorMessage) {
  if let failure = model.errorMessage { AccessibilityNotification.Announcement(failure).post() }
}
```

**What goes wrong:** A VoiceOver user double-taps **Open FORMA on Apple Watch**. The focused button then disappears in every outcome:
- **Success:** `phase` becomes `.waiting`, so the branch at line 42 goes false.
- **Watch unreachable:** `availability = .unreachable` (`WatchWorkoutCoordinator.swift:216`), and the button is replaced by **Check again**.
- **Health refused:** `notice` is set.

VoiceOver focus lands wherever the system puts it, and nothing is spoken:
- the new "Press Start on your Apple Watch" instruction is not announced;
- the changed status sentence is not announced;
- the coordinator's `notice` ("Health access is off for FORMA…") is not announced.

Only `errorMessage` gets an Announcement. On the workout screen, `WatchRecordingStrip` does announce `notice` (lines 186-188), so the two surfaces behave differently.

**Apple guidance:** HIG VoiceOver: "Inform VoiceOver when visible content or layout changes occur… It's crucial to report visible changes so VoiceOver and other assistive technologies can help people update their understanding of the content." (https://developer.apple.com/design/human-interface-guidelines/voiceover)

**User impact:** This is the main start path for every Watch owner. A blind user is told to act on another device, but the phone never tells them that, and they lose their place exactly at that moment.

**Fix:**
```swift
@AccessibilityFocusState private var statusFocused: Bool

status
  .accessibilityFocused($statusFocused)
  ...
.onChange(of: model.watch.phase) { _, phase in
  if case .waiting = phase { statusFocused = true }
}
.onChange(of: model.watch.availability) { _, a in
  if a != .checking && a != .ready { statusFocused = true }
}
.task(id: model.watch.notice) {
  if let notice = model.watch.notice { AccessibilityNotification.Announcement(notice).post() }
}
```
Moving focus to the status element makes VoiceOver read the new instruction. As an alternative, post `AccessibilityNotification.LayoutChanged()` after the change. Confirm the spoken order on a device with VoiceOver.

#### H2. The live Watch strip tells VoiceOver "Recording" while the workout is paused
**Where:** `StartWorkoutSheet.swift:208-212, 242, 245-256`

```swift
if metrics?.state == .paused { Text("Paused").foregroundStyle(FormaTheme.secondary) }
...
.accessibilityElement(children: .combine)
.accessibilityLabel(accessibilityText(metrics))
...
private func accessibilityText(_ metrics: WatchMetrics?) -> String {
  var parts = ["Recording on Apple Watch"]
  // heart rate, energy … no paused state
```

**What goes wrong:** The combined element's label is replaced with `accessibilityText`, which never mentions a pause. The visible "Paused" text is swallowed by `.combine` and overridden, so a VoiceOver user cannot reach it any other way.

**Apple guidance:**
- HIG VoiceOver: "Be sure to keep your descriptions up-to-date as your app's interface and content change."
- HIG Accessibility: "Your interface doesn't rely on any single method to convey information."

**User impact:** A user who paused on the Watch hears that it is recording. They may resume or end incorrectly, or believe heart rate is still being captured.

**Fix:**
```swift
var parts = [metrics?.state == .paused ? "Paused on Apple Watch" : "Recording on Apple Watch"]
```
Also consider `.accessibilityAddTraits(.updatesFrequently)` on the strip, so VoiceOver treats the heart rate as a live value.

### Medium

#### M1. The start sheet has no medium detent and paints over the iOS 26 sheet material
**Where:** `FORMAApp.swift:84-92` (presentation); `StartWorkoutSheet.swift:83`

```swift
.sheet(item: $model.pendingStart, onDismiss: { ... }) { routine in
  StartWorkoutSheet(routine: routine).environment(model)
}
...
.background(FormaTheme.canvas)
```

**What goes wrong:** The sheet holds one decision and two buttons, but it always opens at full height. In iOS 26, only partial-height sheets get the inset Liquid Glass appearance, and the opaque `canvas` background on the `ScrollView` would hide it anyway.

**Apple guidance:**
- HIG Sheets: "In an iPhone app, consider supporting the medium detent to allow progressive disclosure of the sheet's content." It also says: "Include a grabber in a resizable sheet… a grabber also works with VoiceOver."
- Adopting Liquid Glass: "half sheets are inset from the edge of the display to allow content to peek through from beneath them. When a half sheet expands to full height, it transitions to a more opaque appearance." It also says: "Audit the backgrounds of sheets and popovers." (https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)

**User impact:** A large modal for a quick choice hides Today, which works against the "closely related to their current context" purpose. The app also gets none of the 2026 system sheet look that the rest of iOS shows.

**Fix:** Inside `StartWorkoutSheet.body`:
```swift
.presentationDetents([.medium, .large])
.presentationDragIndicator(.visible)
```
Make the opaque background conditional: keep `FormaTheme.canvas` below iOS 26, and on iOS 26 or later drop it, or use `.presentationBackground` only when Reduce Transparency is on. At accessibility sizes the content will not fit at medium; the `.large` detent covers that, and M2's pinned actions keep Start reachable. Confirm the waiting state's three-line copy fits the medium detent on an iPhone Air at default text size.

#### M2. At accessibility text sizes the sheet pushes its actions off screen
**Where:** `StartWorkoutSheet.swift:19-25, 122-132, 41-79`

```swift
Text("YOUR NEXT SESSION")...
EditorialTitle(text: routine.name)           // 50 pt Barlow, relativeTo: .largeTitle
Text("\(routine.exercises.count) exercises · about \(routine.minutes) min")
status                                         // waiting state: 44 pt icon + title3 + 2-sentence paragraph
...
VStack(spacing: 12) { /* the buttons */ }
```

**What goes wrong:** At AX3–AX5, a 50 pt largeTitle-relative title for a two-word routine name already fills most of a screen. In the waiting state, the paragraph and icon come next, so the buttons are several scroll-lengths down. `TodayView` takes explicit care to avoid this (lines 363-369, "Keep the primary action above the fold… at the largest text size"); the sheet does not.

**Apple guidance:** HIG Typography: "Consider adjusting your layout at large font sizes… consider using a stacked layout where text appears above secondary items." It also says: "aim to display as much useful text at the largest accessibility font size as you do at the largest standard font size."

**User impact:** Someone using large text has to scroll to find Start or Open on Watch, and has to scroll again after every state change.

**Fix:** Pin the actions to the bottom with the existing helper:
```swift
ScrollView { /* title, status, notices */ }
  .formaBottomBar { actions.padding(FormaSpacing.xl).background(FormaTheme.canvas) }
```
`formaBottomBar` uses `safeAreaBar` on iOS 26 and so gets the scroll-edge effect; it falls back to `safeAreaInset`. Also hide the eyebrow and the waiting icon at `textSize.isAccessibilitySize`, as Today does. Confirm on a device at AX5.

#### M3. "Check again" is below 44 pt and sits narrow and centred above a full-width button
**Where:** `StartWorkoutSheet.swift:64-72`

```swift
Button { Task { await model.watch.refresh() } } label: {
  Label("Check again", systemImage: "arrow.clockwise")
}
.buttonStyle(.bordered)
```

**What goes wrong:** The button uses default `controlSize(.regular)` and has no `minHeight`, unlike `startOnIPhone`, which sets `.frame(maxWidth: .infinity, minHeight: 44)`. A regular bordered button on iPhone is visibly shorter than 44 pt; the exact rendered height is unconfirmed and should be measured with Accessibility Inspector. The parent `VStack` centres it, so the stack is a narrow pill above a full-width 56 pt primary button.

**Apple guidance:** HIG Accessibility gives 44×44 pt as the iOS default control size. It also says: "Consider spacing between controls as important as size." The project's own rule is ≥44 pt (`apple-design-2026.md`, "Accessibility, data entry and feedback").

**User impact:** The main recovery action for an unreachable Watch is the smallest target on the sheet, used by someone who is often mid-gym and wearing gloves.

**Fix:**
```swift
Label("Check again", systemImage: "arrow.clockwise")
  .frame(maxWidth: .infinity, minHeight: 44)
...
.buttonStyle(.bordered).controlSize(.large)
```

#### M4. Sheet copy can be wrong: "1 exercises", and "YOUR NEXT SESSION" when started from Plan
**Where:** `StartWorkoutSheet.swift:20-24`; caller `PlanView.swift:196-201`

```swift
Text("YOUR NEXT SESSION")...
Text("\(routine.exercises.count) exercises · about \(routine.minutes) min")
```

**What goes wrong:**
- Today uses `countPhrase` (`TodayView.swift:44-46`) for exactly this string; the sheet does not, so a one-exercise routine reads "1 exercises".
- The sheet also opens from Plan's routine detail (`model.requestStart(current)`). That routine may not be the rotation's next session, and Plan's own eyebrow there says "THE SESSION".

**Apple guidance:** The HIG Writing page was not fetched for this audit, so this is not tied to an Apple quote. The frontend-design brief asks that copy says exactly what is true. Today and Plan already pluralise correctly, so the sheet is inconsistent with the app itself.

**User impact:** A visible grammar bug on a primary flow, and a label that misstates which session this is.

**Fix:**
```swift
Text("\(countPhrase(routine.exercises.count, "exercise")) · about \(routine.minutes) min")
```
Better, use automatic grammar agreement:
```swift
Text("^[\(routine.exercises.count) exercise](inflect: true) · about \(routine.minutes) min")
```
For the eyebrow, use a context-neutral label such as `"Ready to start"`, or pass the origin into the sheet.

#### M5. The empty Today gives no way forward
**Where:** `TodayView.swift:124-129, 137-140`

```swift
ContentUnavailableView {
  Label("Your training starts here", systemImage: "dumbbell")
} description: {
  Text("Create a routine in Plan, then make it yours one set at a time.")
}
...
SectionHeading(title: "Your training space", detail: countPhrase(routines.count, "routine"))
```

**What goes wrong:** With no routines, the screen tells people to go to Plan but offers no button. `ContentUnavailableView` has an `actions:` slot for exactly this. Underneath, the "Your training space · 0 routines" heading still renders over an empty list.

**Apple guidance:** `ContentUnavailableView` supports `init(label:description:actions:)` (iOS 17). The frontend-design brief says "An empty screen is an invitation to act."

**User impact:** A new or reset user has to work out the tab bar route alone, and sees a redundant empty section.

**Fix:**
```swift
} actions: {
  Button("Create a routine") { navigation.select(.plan) }.buttonStyle(.formaPrimaryCompact)
}
```
Wrap the routines section in `if !routines.isEmpty`.

#### M6. Today has no screen title, and its rotor headings are slogans
**Where:** `TodayView.swift:81-82, 95, 105-110, 215`; WeekStrip `454-456`

```swift
if textSize.isAccessibilitySize { brand.accessibilityAddTraits(.isHeader) }
else { ViewThatFits { … }.accessibilityElement(children: .combine) }   // no header trait
...
Text("MAKE ROOM FOR")...
Text("Your next stronger.")...accessibilityAddTraits(.isHeader)
...
.toolbar(.hidden, for: .navigationBar)          // and no .navigationTitle
...
SectionHeading(title: "A little, consistently.", ...)
```

**What goes wrong:**
- The screen sets no `navigationTitle`, so VoiceOver has no screen title. Screens pushed from Today (routine, session) also get a generic "Back" button instead of "Today", while Plan sets `.navigationTitle("Plan")`.
- The Headings rotor reads "Your next stronger.", "A little, consistently.", "Your training space", "Last time you showed up". Two of the four describe nothing.
- The header trait moves between sizes. At default sizes the brand row is not a heading and the slogan is; at accessibility sizes the slogan is hidden and the brand becomes the heading.
- "MAKE ROOM FOR" is a separate VoiceOver stop that only makes sense joined to the next line.

**Apple guidance:** HIG VoiceOver: "The title is the first information someone receives from an assistive technology when arriving on a page or screen in your app. Offer unique titles that succinctly describe each page's content and purpose. Likewise, use accurate section headings that help people build a mental model of each page's information hierarchy."

**User impact:** Rotor navigation by heading is the fastest way for VoiceOver users to move around a long scroll view, and on Today it lands on slogans.

**Fix:**
- Add `.navigationTitle("Today")`; the bar stays hidden, but the title feeds the back button and accessibility.
- Give the week section a descriptive heading: `SectionHeading(title: "This week", …)`. The slogan can stay as visible supporting text, or use `.accessibilityLabel("This week")` on the heading if the slogan must stay visible as the title.
- Combine the eyebrow and slogan into one element, and decide on one header element per size.

### Low

#### L1. All-caps strings are hard-coded instead of styled
**Where:** `TodayView.swift:105, 268, 323`; `StartWorkoutSheet.swift:20`

The code writes `Text("MAKE ROOM FOR")`, `"YOUR NEXT SESSION"` and `"IN PROGRESS"` as literal capitals. Use sentence-case strings with `.textCase(.uppercase)`, so VoiceOver, translation and future copy changes get natural casing.

Apple has moved away from forced capitals in its own list section headers: Adopting Liquid Glass says "section headers no longer render entirely in capital letters". That is directional only, since these are custom eyebrows. The frontend-design critique also flags a tracked all-caps eyebrow above every block as template chrome. Today stacks two of them (eyebrow over slogan, and eyebrow inside the hero). Consider keeping only the hero's state label ("In progress" / "Next session"), which carries information.

#### L2. Week strip details are English-only and say "slash"
**Where:** `TodayView.swift:399-402, 456`

- `"\(week.count) / \(goal) this week"` is spoken as "2 slash 4"; prefer `"\(week.count) of \(goal) this week"`.
- The day letters and full names are hard-coded English. `Calendar.veryShortStandaloneWeekdaySymbols` / `standaloneWeekdaySymbols` (rotated to Monday-first) would localise them.
- Monday-first is a decided Sydney semantic (IF-04), so keep the ordering.

#### L3. Today is marked only by letter weight and colour
**Where:** `TodayView.swift:482-483`

```swift
.font(.caption.weight(isToday ? .heavy : .semibold))
.foregroundStyle(isToday ? FormaTheme.primary : FormaTheme.secondary)
```

The difference between heavy and semibold caption weight is slight. HIG Accessibility says "Offer visual indicators, like distinct shapes or icons, in addition to color." Add a shape cue, such as a 2 pt accent underline or a ring on today's circle.

#### L4. Week circles do not scale with text size
**Where:** `TodayView.swift:484-499`

The circles use `.frame(width: 34, height: 34)`, while the day letters and the checkmark (`.caption.bold()`) scale. HIG Typography: "Increase the size of meaningful interface icons as font size increases." Use `@ScaledMetric(relativeTo: .caption) var dot = 34.0`. The accessibility-size layout already switches to text rows, so this only matters for xLarge–xxxLarge.

#### L5. The hero's pending state and Start symbol are inconsistent
**Where:** `TodayView.swift:236, 275, 343-348`

- The compact (landscape) hero shows an `hourglass` glyph while starting; the regular hero shows a `ProgressView`. Use one pending treatment.
- Start uses `arrow.up.right`, which commonly means "opens elsewhere / external link", while Resume uses `play.fill`.
- Recommendation: `play.fill` for both, or a forward chevron for Start. The frontend-design critique also lists an appended arrow on a button as a templated tell.

#### L6. Literal radii and spacing, and the hero button is not concentric
**Where:** `TodayView.swift:80, 210, 285, 361, 372`

- Literals `22`, `24`, `5`, `6`, `10` sit beside `FormaSpacing`. `FormaTheme.swift` says "5, 6, 10, 14 and 22 should round to the nearest step".
- `RoundedRectangle(cornerRadius: 24)` should be `FormaRadius.hero`.
- The hero button has radius 16 and sits 16 pt inside a radius-24 card, so a concentric inner radius would be 8. Adopting Liquid Glass recommends "rounded shapes that are concentric to their containers" via `ConcentricRectangle` (iOS 26, behind `#available`).

This is aesthetic and would need a quick visual check.

#### L7. "Last time" card has no edge; symbol names may be spoken
**Where:** `TodayView.swift:186-196, 154, 188`

- The session card is `FormaTheme.surface` on `canvas`: 1.08:1 in light and 1.15:1 in dark, with no stroke. `WatchRecordingStrip` (line 185) and the sheet use a `FormaTheme.line` hairline, so the two card treatments are inconsistent.
- The decorative `chevron.right` and `checkmark.seal.fill` symbols inside the `NavigationLink` labels are not hidden. SF Symbols carry default accessibility labels, so they may be spoken; this is **unconfirmed** and should be checked with Accessibility Inspector.
- Add `.accessibilityHidden(true)` to the chevrons and the seal, and add `.overlay(RoundedRectangle(cornerRadius: FormaRadius.card).strokeBorder(FormaTheme.line))` to the card.

#### L8. Content scrolls under the status bar with the navigation bar hidden
**Where:** `TodayView.swift:215`

With no navigation bar, routine text scrolls under the clock and battery. Adopting Liquid Glass says "System bars like toolbars adopt this behavior by default". It is **unconfirmed** whether iOS 26 applies the automatic top edge effect when the bar is hidden. Check on a device; if needed, add `if #available(iOS 26, *) { .scrollEdgeEffectStyle(.soft, for: .top) }` (https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)).

#### L9. Strip and sheet copy
**Where:** `StartWorkoutSheet.swift:217-219, 129`

- "Your Apple Watch ended its recording. Check your Watch for Health save status." Suggested: "Recording ended on Apple Watch. Your Watch shows whether it saved to Health."
- The waiting paragraph is good, but it is long for a medium detent. Consider moving the Health sentence to a footnote-sized line.

#### L10. Smart Invert will invert the hero photo
**Where:** `ExerciseMedia.swift:462-485` (`MediaPhoto`), used by `TodayView.swift:299`

No view in the app uses `.accessibilityIgnoresInvertColors()`. Add it to `MediaPhoto`; the API is available from iOS 14. Whether UIKit already excludes this `Image(uiImage:)` is **unconfirmed**; check on a device with Smart Invert on in light mode.

#### L11. Smaller sheet robustness items
**Where:** `StartWorkoutSheet.swift:36-40, 98-104`

- `model.errorMessage` is app-global. If an unrelated failure is still set when the sheet opens, it is shown and announced here as if it were about the start. Clear it on appear, or scope start failures to a sheet-local state.
- Swipe-to-dismiss stays enabled while `starting`. The flow survives this (`presentWorkout` falls through to `workoutPresented = true`), but `.interactiveDismissDisabled(starting)` would make the in-flight start visibly authoritative.

---

## 3. What is already correct

- **Motion discipline.** Every animation and transition in the slice goes through `FormaMotion` (`formaAnimation`, `withFormaAnimation`, `motion.transition`, `formaReveal`). No feature view reads `accessibilityReduceMotion`. The hero keeps one stable container so the reveal plays once, and only the text cross-fades between Start and Resume (`TodayView.swift:116-132, 337, 374`).
- **Committed truth over animation.** WeekStrip's VoiceOver status is built from committed history, not from the animated circles (`TodayView.swift:429-438, 477-480`). The completion emphasis is deferred while the workout cover is up (`442-445`).
- **Haptics.** `.started` plays only after `commit` succeeds and `.failed` on a failed save (`AppModel.swift:304-312, 357-361`). The views add no haptics, which matches CLAUDE.md.
- **Dynamic Type on Today.** The header is a `ViewThatFits` stack. Art, slogan and legend drop at accessibility sizes. The hero detail moves below the action to keep Start above the fold. The week strip becomes a readable list of day and status rows. The Barlow display font scales via `relativeTo:`. All `Text` that can grow uses `fixedSize(horizontal: false, vertical: true)` rather than truncating.
- **Contrast.** Every text pair in the slice passes WCAG AA in light and dark (lowest is 5.75:1). The lime button keeps an ink label (13.2:1) and adds an accent edge in light mode where the fill alone would be 1.09:1 against the canvas. `boundary` strokes on unscheduled days meet 3:1 (4.05:1 on surface).
- **Colour is not the only signal** in the week strip: dashed ring means planned, a checkmark means done, and a written legend explains both.
- **Pending feedback.** Start, Open on Watch and Start on iPhone each show in-button progress, expose `accessibilityValue("Starting"/"Opening")`, and disable re-entry. The Start label is explicit, so the cross-fading text never leaks into VoiceOver (`TodayView.swift:355-358`).
- **Sheet conventions.** A single-view sheet with **Cancel** on the leading edge (`.cancellationAction`), as HIG Sheets (March 2026) specifies. Only one sheet is shown at a time, and the workout cover is deferred until the sheet has dismissed (`AppModel.presentWorkout`). Inline errors appear because the root alert cannot present over a sheet, and they are announced.
- **Truthful Watch states.** Stale heart rate is labelled "Last N bpm" with `heart.slash` and spoken as "not current". The strip never claims a Health save. Recovery copy names the exact Settings path.
- **Session chooser.** `Menu` + `Picker` gives native checkmark selection with a 44 pt label and is disabled while busy. The choice is scoped to the visit, as on the web.
- **No Liquid Glass in the content layer**, consistent with HIG Materials as recorded in `apple-design-2026.md`.
- **No deprecated APIs.** Value-based `NavigationLink`, `ContentUnavailableView`, `sensoryFeedback` (via relay), and `AccessibilityNotification.Announcement` are all valid on the iOS 17 floor.

## Needs on-device confirmation (owner)

- H1: focus behaviour and spoken order in the Watch sheet with VoiceOver.
- M1: fit of the waiting state at the medium detent.
- M2: sheet at AX5.
- M3: rendered height of Check again (Accessibility Inspector).
- L7: whether SF Symbol labels are spoken in the row labels.
- L8: top scroll-edge effect with the navigation bar hidden on iOS 26/27.
- L10: Smart Invert on the hero photo.
