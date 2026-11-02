# Active workout front-end audit (iPhone), 2 November 2026

Slice: `ios/FORMA/Features/WorkoutView.swift` (1,932 lines, read in full), `HoldLogState.swift`,
`WatchSummaryCard.swift`, and the design-system types they use (`FormaTheme`, `FormaMotion`,
`FormaHaptics`, `FormaComponents`, `GlassControls`; `MetricValue` from `ProgressView.swift`).
Worktree `feat/watch-collected-data`. Read-only: no repo file was edited.

**Method and limits.** This is a static source review. Nothing was built or run, and no simulator
was used (the owner tests on device). Any finding about how Liquid Glass renders, how VoiceOver
moves focus, or a disabled toolbar item's appearance is marked **needs device check**. Apple
guidance comes from the live HIG JSON (`developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`)
and SwiftUI DocC `.md` pages, retrieved 2 November 2026. Anything not confirmed from an Apple
source is labelled **unconfirmed**. Before this audit I read the repo's decisions (AGENT.md
"iOS motion system", the 2 Nov "Even workout buttons" entry, `ios/docs/apple-design-2026.md`,
`native-design-review.md`, `full-audit-2026-10-26.md` and `commit-2/*`). Decided items are not
re-reported unless I have new Apple evidence: per-second numeric roll, linear rest ring, the
destructive action in a menu, the duplicate "Finish workout" label, opaque data surfaces, and
`.success` reserved for the receipt.

Skill passes: ui-ux-pro-max `--stack swiftui` (toolbar/navigation, numeric text fields,
timers/Dynamic Type) and `--domain ux` (destructive confirmation, touch targets, haptics,
loading feedback); its `pro-rules.md` Pre-Delivery Checklist is applied in section 1.
frontend-design's critique lens (hierarchy, restraint, copy that says exactly what happens) is
applied to the copy findings.

---

## 1. Pass/fail checklist

| Area | Result | Notes |
|---|---|---|
| Toolbar, iOS 26 Liquid Glass (owner's question) | **Fail (partial)** | Three groups, fixed spacer, one text item kept apart from symbols: correct. The lime label on standard glass contradicts HIG Color › Liquid Glass color and Toolbars (H1). The chevron's custom weight makes the icon items look uneven (L1). |
| Toolbar item sizes | Pass (height) | All three sit on standard glass, so they are the same height. The text capsule is wider than the two circles, as the system draws it. See H1 for a way to make all three identical circles. |
| Bottom bar and safe area | Pass | `safeAreaBar` on iOS 26 and `safeAreaInset` before it (`GlassControls.swift:34-40`). The dock goes compact while typing. |
| Keyboard toolbar | Pass | Done is present for `.numberPad`, which has no return key (`WorkoutView.swift:1202-1209`). No next/previous field (L9). |
| Numeric entry | Pass | Visible caption labels, `.numberPad` for counts and `.decimalPad` for loads, locale-aware parsing, the bad field marked with a message beside the set and focus moved there. |
| Timers and VoiceOver | **Partial** | Spoken durations and announcements are good. No `.updatesFrequently` trait on any of the three clocks (M2). |
| Destructive confirmations | Pass | Discard workout, the hold timer (>10 s) and notes all confirm; destructive roles are set. Copy notes in L4. |
| Alerts and action sheets copy | Partial | Long finish message at large sizes; "Keep training" stands in for "Cancel" (L4). |
| Sheets | **Partial** | Guide sheet puts Done on the leading edge (M3). Notes blocks swipe-to-dismiss without the confirming action sheet (M5). |
| Full-screen modal dismissal (receipt) | **Fail** | No toolbar exit; the only way out is "Keep the feeling." at the bottom of the scroll (H2). |
| Typography and Dynamic Type | Mostly pass | Text styles, scaled display font, `@ScaledMetric`, and reflow in set rows, dock and metrics. The exercise selector label never reflows (L2). |
| Contrast, light/dark | Pass on opaque surfaces | Computed WCAG ratios: secondary 5.75 to 9.65:1, accent 6.23 to 12.91:1, error 6.57 to 10.38:1, field border 3.73 to 5.07:1. Glass areas are not measurable statically (H1, L8). |
| Tap targets (44 pt) | Pass | Every custom control frames to at least 44 × 44. The completion button is 56 × 48. |
| VoiceOver labels and order | Mostly pass | Each set row is one container with a summary, then its fields and a labelled completion with value and hint. Voice Control names miss on the ± buttons (L5). |
| Reduce Motion | Pass | All motion goes through `formaMotion`; spatial motion degrades to a fade or nothing. |
| Haptics after confirmed save | Pass | Complete, undo, add, rest pause/+15/skip and hold logging all fire after `commit` returns true, gated by `hapticsEnabled`. Hold start and length steps change local state only, so they have no save to wait for. |
| Loading and saving feedback | Pass | `LocalSaveStatus`, "Saving timed set…", `SaveFailureBanner` (announced) and inline set errors. |
| Copy and wording | **Partial** | M1, M4, H2, L2, L3, L4. |
| Deprecated APIs | Pass | None found: `NavigationStack`, `@Environment(\.dismiss)`, two-argument `onChange`, `AccessibilityNotification`, `.topBarLeading/.topBarTrailing`. |
| HIG Workouts | Partial | Summary screen present. The Health claim is unconfirmed (M4); brief or empty sessions are saved (L7). |
| Pre-Delivery Checklist (pro-rules.md) | Applied; device items open | Items that can be checked statically pass apart from the findings below. The open items are glass legibility (H1, L8), disabled state (H1), focus order after the receipt appears (L10), and small-phone/landscape layout (device). |

---

## 2. Findings

### High

#### H1. The toolbar's Finish colours its label instead of using the prominent style, against iOS 26 toolbar guidance (the owner's question)

`WorkoutView.swift:1170-1175`
```swift
ToolbarItem(placement: .topBarTrailing) {
  Button(action: finish) {
    Text("Finish").fontWeight(.semibold).foregroundStyle(FormaTheme.accent)
  }
  .modifier(FinishIdentity(busy: busy))
}
```
`FinishIdentity` applies `.disabled(busy)` (`:1212-1221`).

**Apple guidance**
- HIG Color › Liquid Glass color: "**To emphasize primary actions, apply color to the background rather than to symbols or text.**" It also says that on toolbars "symbols and text on these elements follow a monochromatic color scheme, becoming darker when the underlying content is light, and lighter when it's dark", and "Avoid using similar colors in control labels if your app has a colorful background." https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color
- HIG Toolbars (updated 16 Dec 2025 for Liquid Glass): "Use the .prominent style for key actions such as Done or Submit. … Only specify one primary action, and put it on the trailing side." It adds "Reduce the use of toolbar backgrounds and tinted controls" and "Avoid applying a similar color to toolbar item labels and content layer backgrounds." https://developer.apple.com/design/human-interface-guidelines/toolbars

**What goes wrong**
1. A fixed `foregroundStyle` opts "Finish" out of the glass's adaptive monochrome label. Lime is also the content colour of this screen: the "Next exercise"/"Finish workout" button, completed-set fills and the dark-mode accent. When that content scrolls under the bar in dark mode, the label is lime over lime-tinted glass (lime on lime is 1.0:1 before the glass adjusts). The scroll-edge effect softens this, but HIG asks that the resting state stay clearly legible. **Needs device check** in dark mode, scrolled to the last exercise.
2. Finish is the screen's one key action, but it now has no tinted background, so the trailing group's emphasis is a coloured word. HIG reserves colour on glass for the background.
3. With an explicit `foregroundStyle` on the label, `.disabled(busy)` may not dim the button. Toolbar disabled appearance on iOS 26 is reported as unreliable (Apple Developer Forums thread 795478; DTS suggested a `Label` label or another style). **Unconfirmed, needs device check.** `busy` is brief, so the effect is a mismatch rather than a hazard.

**The owner's constraint.** The owner wants every toolbar button the same size (AGENT.md, 2 Nov). That is compatible with HIG, because the prominent style changes colour, not height. Two conforming ways to keep one size:

- **A (closest to the owner's intent, fully HIG-conformant):** keep standard glass and drop the colour. The trailing position, the text label and the `ToolbarSpacer` already set it apart.
  ```swift
  ToolbarItem(placement: .topBarTrailing) {
    Button("Finish", action: finish)          // monochrome label; the glass adapts it
      .fontWeight(.semibold)
      .modifier(FinishIdentity(busy: busy))
  }
  ```
- **B (identical circles plus HIG's primary emphasis):** make Finish a symbol item, so all three are glass circles of the same size, and colour the background:
  ```swift
  ToolbarItem(placement: .topBarTrailing) {
    Button(role: .confirm, action: finish) {           // iOS 26
      Label("Finish workout", systemImage: "checkmark")
    }
    .tint(FormaTheme.lime)                              // background tint; ink glyph stays legible
    .modifier(FinishIdentity(busy: busy))
  }
  ```
  `ButtonRole.confirm` is iOS 26 (https://developer.apple.com/documentation/swiftui/buttonrole/confirm). Community sources say the system draws it as a prominent glass checkmark circle; that is **unconfirmed** from Apple, so check it on the device. If the checkmark reads too much like "Done", use `flag.checkered` with `.buttonStyle(.glassProminent)`.

Either way, avoid lime text on standard glass. Keep `FinishIdentity`'s label, identifier and disabled state, and put a `Label` (not a bare `Text`) inside the button so the disabled state draws.

#### H2. The receipt is a full-screen modal with no toolbar exit, and its only exit is labelled "Keep the feeling."

`WorkoutView.swift:1916-1929`. The receipt is presented inside the workout `fullScreenCover`, and `FORMAApp.swift:120` has `.interactiveDismissDisabled()`.
```swift
Button { model.workoutPresented = false } label: {
  HStack { Text("Keep the feeling."); Spacer(); Image(systemName: "arrow.right") }
}
...
.navigationTitle("Session saved").navigationBarTitleDisplayMode(.inline)
```

**Apple guidance**
- HIG Modality: "Always give people an obvious way to dismiss a modal view. … in iOS … people typically expect to find a button in the top toolbar or swipe down." https://developer.apple.com/design/human-interface-guidelines/modality
- HIG Writing: "Prioritize clarity and avoid the temptation to be too cute or clever with your labels… 'Send' often works better than 'Let's do it!'" and "Make it clear when a flow is complete by using language like 'Done.'" https://developer.apple.com/design/human-interface-guidelines/writing
- HIG Buttons: "consider starting the label with a verb." https://developer.apple.com/design/human-interface-guidelines/buttons

**User impact.** Swipe-down is disabled and the toolbar is empty. The way out sits below the seal, the headline, two to four metrics, the Watch card and a paragraph, so at accessibility text sizes it is several screens down. The label describes a mood, not the action (it closes the receipt and returns to the tab). An arrow implies going forward to something new; nothing new appears.

**Fix.** Add a trailing toolbar Done and rename the bottom button to say what happens:
```swift
.toolbar {
  ToolbarItem(placement: .confirmationAction) {
    if #available(iOS 26.0, *) {
      Button(role: .confirm) { model.workoutPresented = false }
        .accessibilityLabel("Done").accessibilityIdentifier("receipt-done-toolbar")
    } else {
      Button("Done") { model.workoutPresented = false }
    }
  }
}
// bottom: Text("Done") or "Back to Today"; drop the arrow.
```
Keep "Keep the feeling." as body copy if the brand voice wants it, not on the button. The `receipt-done` identifier and the UI tests can stay on the bottom button.

### Medium

#### M1. Workout copy tells people to use "Save & close", a control with no visible name on iOS 26

`WorkoutView.swift:195`
```swift
Text("Widget link queued. Use Save & close to open it.")
```
On iOS 26 that control is an unlabelled `chevron.down` glyph (`:1160-1167`). "Save & close" exists only as its VoiceOver label; only the pre-26 path shows the text (`:1181`).

**Apple guidance.** HIG Alerts: "refer to a button using its exact title." HIG Toolbars: "Make sure the meaning of each control is clear. Don't make people guess or experiment to figure out what a toolbar item does." https://developer.apple.com/design/human-interface-guidelines/alerts , https://developer.apple.com/design/human-interface-guidelines/toolbars

**User impact.** Sighted people on iOS 26 get no visible "Save & close", so the instruction points nowhere. The chevron alone also doesn't say the workout is saved and kept for later.

**Fix.** Refer to the control by what is visible and what it does, and make the action itself available:
```swift
Text("A widget link is waiting. Close the workout to open it; your sets are saved.")
// or add Button("Close and open link") { close() } inside this notice
```
Optionally give the chevron a visible name for Voice Control with `.accessibilityInputLabels(["Save and close", "Close"])` (iOS 14+, https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:)).

#### M2. None of the three live clocks has the `.updatesFrequently` trait

- `WorkoutView.swift:989-995`, hold `Text(WorkoutClock.text(shown…)).accessibilityLabel(…)`
- `:1633-1636`, rest `Text(WorkoutClock.text(remaining…)).accessibilityLabel("… remaining")`
- `:1437-1439`, elapsed `Text(WorkoutClock.text(seconds…)).accessibilityLabel("Elapsed time, …")`

**Apple guidance.** `AccessibilityTraits.updatesFrequently` (iOS 13+): "The accessibility element frequently updates its label or value. Use this trait when you want an assistive technology to poll for changes … for example … the readout of a stopwatch." https://developer.apple.com/documentation/swiftui/accessibilitytraits/updatesfrequently

**User impact.** A VoiceOver user resting on the rest or hold clock hears a stale value until they swipe away and back. The labels also change once a second; without the trait, VoiceOver handles that churn less predictably (**needs device check**).

**Fix.** Put the time in the value, keep a stable label, and add the trait:
```swift
Text(WorkoutClock.text(remaining, locale: locale))
  .accessibilityLabel("Rest remaining")
  .accessibilityValue(WorkoutClock.spoken(remaining, locale: locale))
  .accessibilityAddTraits(.updatesFrequently)
```
Do the same for the hold ("Hold remaining") and elapsed ("Elapsed time") clocks.

#### M3. The guide sheet puts "Done" on the leading edge as a cancellation action

`WorkoutView.swift:1132-1136`
```swift
ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
```

**Apple guidance.** HIG Sheets (iOS): "for sheets with a single view, the Cancel button belongs on the leading edge … When present, the Done button belongs on the trailing edge." HIG Toolbars: "Use the standard Back and Close buttons … the standard Close button closes a modal view. Prefer the standard symbols." `ButtonRole.close` (iOS 26) is documented as "a button that closes the current operation". https://developer.apple.com/design/human-interface-guidelines/sheets , https://developer.apple.com/documentation/swiftui/buttonrole/close

**User impact.** A read-only guide has nothing to confirm, so "Done" on the left mixes two conventions. Placement differs from every other sheet in the app (notes puts Cancel on the left and Save on the right).

**Fix.**
```swift
ToolbarItem(placement: .cancellationAction) {
  if #available(iOS 26.0, *) { Button(role: .close) { dismiss() } }   // standard xmark
  else { Button("Close") { dismiss() } }
}
```

#### M4. The receipt says "Also saved in Apple Health" before the Health save is confirmed

`WatchSummaryCard.swift:38-39`
```swift
Text("Also saved in Apple Health on your iPhone.")
```
The receipt is shown as soon as the journal commit lands (`AppModel.swift:412`); `await watch.end(save: true)` runs after it. `WatchWorkoutCoordinator.end` (`:373-379`) only sends a command and can fail (it then reverts to `.recording`). Nothing on the card reflects whether the Watch saved the workout to Health.

**Apple and project guidance.** HIG Workouts: "A summary screen confirms that a workout is finished and displays the recorded information." https://developer.apple.com/design/human-interface-guidelines/workouts . The repo's own rule (`apple-design-2026.md`, AGENT.md) is that a success message follows the durable result.

**User impact.** If the Watch is unreachable at Finish, the receipt still says the workout is in Health, which is false.

**Fix.** Only say it when it is known. Pass a `healthSaved: Bool?` (from the Watch's end acknowledgement or the final summary arriving) and choose the copy from it: "Saved in Apple Health." / "Saving to Apple Health…" / "Not saved to Apple Health. Open the Watch app to save it." Or soften it to "Your Apple Watch saves this workout to Apple Health."

#### M5. The notes sheet blocks swipe-to-dismiss silently when there are unsaved changes

`WorkoutView.swift:1860`
```swift
.interactiveDismissDisabled(notes != original || model.busy)
```

**Apple guidance.** HIG Sheets: "Support swiping to dismiss a sheet. … If people have unsaved changes in the sheet when they begin swiping to dismiss it, use an action sheet to let them confirm their action." HIG Modality: "if closing the view could result in the loss of user-generated content … explain the situation and give people ways to resolve it."

**User impact.** The swipe rubber-bands and nothing explains why. The confirmation dialog appears only through the Cancel button.

**Fix.** SwiftUI has no hook for an attempted dismiss, so bridge `UIAdaptivePresentationControllerDelegate.presentationControllerDidAttemptToDismiss(_:)` with a small `UIViewControllerRepresentable` that sets `discardConfirmation = true`. Offer "Save notes" as well as "Discard changes" in that dialog, matching the Mail example in HIG Action sheets.

### Low

**L1. The toolbar's two symbol items have different weights.** `:1162` `Image(systemName: "chevron.down").fontWeight(.semibold)` sits beside a default-weight `ellipsis` (`:1196`). HIG Toolbars: "Prefer system-provided symbols … System-provided symbols are familiar, automatically receive appropriate coloring and vibrancy." This works against the owner's "all the same" ask: the circles match but the glyphs don't. Fix: remove `.fontWeight(.semibold)`. Also consider the standard close: `ButtonRole.close` is documented as "Unlike a cancel operation, a close operation doesn't lose progress for a user", which matches Save & close exactly (`Button(role: .close, action: close).accessibilityLabel("Save & close")`). Changing the glyph from chevron to xmark is the owner's call, since the chevron's "minimise" reading is defensible.

**L2. Wrong plurals and a label that doesn't reflow.**
- `:539` `Text("\(completed) sets completed")` reads "1 sets completed".
- `:384` `"\(heldSeconds) seconds held so far"` can read "1 seconds".
- The selector label (`:535-545`) is one `HStack` with no `ViewThatFits` or accessibility-size branch, so at AX sizes "Choose exercise" and the count squeeze into narrow wrapped columns.

Fix: `Text("^[\(completed) set](inflect: true) completed")`, or reuse the file's `setCount()`. Use the same approach for seconds. Wrap the label in `AdaptiveMetricGroup` or switch to a `VStack` when `typeSize.isAccessibilitySize`. HIG Typography recommends stacked layouts at large sizes (already cited in `apple-design-2026.md`).

**L3. The header chrome stacks too many labels, in all caps.** Top to bottom: navigation title "Training", eyebrow "IN YOUR OWN TIME." (`:204`), the session name, then "EXERCISE 1 OF 5" (`:220`) above the exercise name. The receipt adds "THE WORK IS YOURS." (`:1889`). These are literal uppercase strings with tracking. HIG Toolbars: "Provide a useful title … If titling a toolbar seems redundant, you can leave the title area empty." Through the frontend-design lens, the tracked all-caps eyebrow over every heading is template chrome, and four levels above the thing being logged dilute the hierarchy. Fix: use the session name as the navigation title and drop the eyebrow on this screen (keep it on Today if it is brand voice). Write "Exercise 1 of 5" in sentence case. If caps stay, write the source string in sentence case and apply `.textCase(.uppercase)`, so localisation and VoiceOver get normal text (**unconfirmed** that VoiceOver mispronounces these particular strings).

**L4. The finish alert can scroll, and Cancel is renamed.** `finishMessage` (`:627-640`) can be four sentences. HIG Alerts: "avoid displaying an alert that scrolls … including a brief message only when necessary", and "Always use the title 'Cancel' for a button that cancels an alert's action." Both alerts use "Keep training" (`:358`, `:369`). Fix: cut the message to the counts plus one consequence, for example "9 of 12 sets done. Unfinished sets won't count." Move the Watch/Health sentence to the receipt. "Keep training" is a reasonable brand choice, but it differs from HIG wording; record it as a decision or use "Cancel".

**L5. Voice Control names don't contain the visible ± labels.** `:1054` shows "−5" but is labelled "Shorter hold, 25 seconds"; `:1063` likewise; `:1692` shows "+15" but is labelled "Add 15 seconds to rest". Saying "Tap minus 5" or "Tap plus 15" may not match (**unconfirmed**). `accessibilityInputLabels` docs: "Voice Control and Full Keyboard Access use the input labels." Fix: `.accessibilityInputLabels(["Minus \(step)", "Shorter hold"])`, `["Plus \(step)", "Longer hold"]` and `["Plus 15", "Add 15 seconds"]`.

**L6. The Watch card's numbers ignore the reader's locale, and its grid crowds at large text.** `WatchSummaryCard.swift:19-35` builds `"\(average) bpm"` and `"\(energy) kcal"` with plain interpolation, while time uses `WorkoutClock` (locale digits, but its default `.autoupdatingCurrent` rather than the view's `\.locale`). `GridItem(.adaptive(minimum: 130))` keeps two columns at AX sizes, so values wrap mid-number. Fix: use `average.formatted()` and `Measurement`/`.formatted(.measurement(width: .abbreviated))` for kcal, pass `@Environment(\.locale)`, and use one column when `dynamicTypeSize.isAccessibilitySize`.

**L7. Very short or empty sessions are saved, and a short session shows "0 minutes".** The finish alert allows 0 completed sets. The receipt shows `Int((session.duration ?? 0) / 60)` (`:1900`), which is "0" for anything under a minute. HIG Workouts: "Discard extremely brief workout sessions. If a session ends a few seconds after it starts, either discard the data automatically or ask people if they want to record the data as a workout." Fix: when `completedSets == 0`, make the alert's main button "Discard workout" and offer "Save anyway"; show the duration with `WorkoutClock.text`.

**L8. The rest dock's glass uses fixed colours rather than vibrant ones.** `:1583` `.formaControlSurface()` gives regular `glassEffect` (`GlassControls.swift:18-19`), with `FormaTheme.primary/secondary/accent` text on top. HIG Materials: "Help ensure legibility by using vibrant colors on top of materials." The surface is regular glass with an opaque fallback for Reduce Transparency and Increase Contrast, so this is a **device check** rather than a defect: scroll a lime button under the dock in light mode and check "+15"/"Skip" against it.

**L9. The keyboard toolbar has only Done.** Logging a set means tapping field to field (`:1202-1209`). HIG Text fields asks for the right keyboard type, which is met. Next/previous navigation is a UX recommendation, **not an Apple requirement**: add `Button { focusNext() } label: { Image(systemName: "chevron.down") }` and `chevron.up` before the spacer, labelled "Next field" and "Previous field".

**L10. Nothing is announced when the receipt replaces the workout (needs device check).** The receipt swaps in inside the same `NavigationStack` (`FORMAApp.swift:103-109`). The seal plays a success haptic but is `accessibilityHidden`, and nothing posts a screen change, so VoiceOver focus may stay where Finish was. Fix: put an `@AccessibilityFocusState` on `EditorialTitle` and set it in `.onAppear`, or post `AccessibilityNotification.ScreenChanged()`. Also give the "Session saved" label (`:1911`) `.isHeader` so the rotor can reach it.

**L11. The hold keeps running behind the "Your timer is still running" dialog.** The message's `\(heldSeconds)` is captured once (`:384`) while the deadline task can log the hold underneath (`:416-422`). The outcome is handled safely (the hold logs; the buttons then fall through). But the dialog can say "12 seconds held" while 30 are logged. Fix: pause the hold when `holdLeave` is set, and resume it on "Keep training".

**L12. The hold tone uses an undocumented system sound ID.** `:905` calls `AudioServicesPlaySystemSound(1057)`. Apple doesn't publish system sound IDs (**unconfirmed** they are stable across releases). Fix: bundle a short `.caf` and play it through `AudioServicesCreateSystemSoundID`.

---

## 3. Already correct (keep)

- **Toolbar structure** follows HIG Toolbars on iOS 26: three groups at most, a leading navigation-style control, the More menu, and the text item separated from the symbols with `ToolbarSpacer(.fixed)`. Standard symbols without borders (`ellipsis`, not `ellipsis.circle`) on 26, guarded by `#available`. Destructive Discard sits in a menu with `role: .destructive` and is confirmed.
- **Set rows**: one accessibility container per set with a summary label. The completion control has a set-specific label, a Completed/Not completed value and a hint, as the WWDC26-220 purpose/value/action/feedback model asks. 56 × 48 target, no layout shift between states, and the fill animates only after the durable save.
- **Numeric entry**: visible captions, the right keyboard per field, locale parsing, an error message beside the set with the field outlined in a ≥3:1 colour and focus moved there, warning haptic plus announcement. Drafts survive in-flight commits (`retainingUnacknowledgedDrafts`).
- **Timers**: deadline-based, `TimelineView` only while active and counting, ends exactly at zero. Clocks are spoken as full durations, and rest start, rest end and a logged hold are all announced. The screen stays awake only while a rest or hold counts down.
- **Rest dock**: `safeAreaBar` on iOS 26 with an inset fallback, a compact form while typing, a Skip + More menu at accessibility sizes, 44 pt targets, its own accessibility container so identifiers survive, and a medium-impact cue at the end of rest that differs from the light set tap.
- **Hold timer card**: explicit Saving/Retry/Cancel states. Discarding effort of more than 10 s asks first. Retry keeps the original duration (`HoldLogState` claims synchronously before any await).
- **Motion**: every animation goes through `formaMotion`; Reduce Motion and Prefer Cross-Fade drop to fades. The progress bar draws at 30 fps only at full motion and while active.
- **Haptics**: one pattern per meaning, every training haptic after a confirmed commit, all gated by `hapticsEnabled`, with `.success` kept for the receipt seal.
- **Contrast**: the brand tokens meet WCAG AA on opaque surfaces in light and dark, with Increase Contrast variants (ratios in section 1). Ink on lime is 13:1.
- **Save state**: always visible ("Saved on this iPhone" / "Unsaved edits" with an on-screen Save edits); failures appear above the dock and are announced.
- **Notes**: Cancel on the left and Save on the right, a discard confirmation (SwiftUI adds Cancel automatically, per HIG Action sheets), and a 10,000-character guard. The guard's Save is disabled with no reason given; consider colouring the count with `FormaTheme.error` and adding a line saying how much to cut.
- **No deprecated APIs** in the slice.

## Resolution

Fixed on branch `fix/audit-workout` from `ba4e6a7`. I re-checked each finding against the
code before changing it. The build is `xcodebuild build-for-testing`, scheme `FORMA`,
`generic/platform=iOS`, Debug. It succeeded with no new Swift warnings. No simulator or
device run was made, and the unit tests were built but not run. "Device check" names the
step that still needs an iPhone.

| ID | Result | What changed, or the device step |
|---|---|---|
| H1 | Fixed (owner option B). Device check | On iOS 26 Finish is an icon-only `flag.checkered` with `.glassProminent`, tinted lime, with the symbol in ink. It is the same circle size as close and More. The flag matches the bottom Finish button. Option B named a checkmark, so swapping the glyph is one line if the owner prefers it. The name stays "Finish workout" (identifier `finish-workout`), with the Voice Control names "Finish" and "Finish workout". Before iOS 26 it is still the "Finish" text button. **Device:** check Finish in light and dark, enabled and disabled while busy. |
| H2 | Fixed | The receipt has a toolbar Done (`receipt-done-toolbar`; `role: .confirm` on iOS 26) that closes the cover. The bottom button now says "Done" instead of "Keep the feeling.", and both buttons call the same action. |
| M1 | Fixed | The widget notice reads "A widget link is waiting. Close the workout to open it; you can resume it later." It has its own 44 pt "Close and open link" button (`widget-link-close`). That button goes through the same close path, including the running-hold question. The close button also answers "Save and close" and "Close" in Voice Control. |
| M2 | Fixed | Elapsed time, rest remaining and the hold readout each have a stable label ("Elapsed time", "Rest remaining", "Hold remaining" or "Hold length"), the spoken time as `accessibilityValue`, and `.updatesFrequently`. |
| M3 | Fixed | The guide sheet's leading button is `Button(role: .close)` on iOS 26 and "Close" before it, in place of "Done". |
| M4 | Not changed here | The "Also saved in Apple Health" line is the progress slice's fix, as agreed with the lead. |
| M5 | Fixed. Device check | `DismissAttemptObserver` wraps the notes sheet's presentation-controller delegate and forwards every other call to SwiftUI's delegate (the same approach as the plan editor). When a swipe is refused over unsaved notes, a dialog asks "Save your notes?" with "Save notes" (shown only when saving is allowed), "Discard changes" and Cancel. `interactiveDismissDisabled` stays as the gate. **Device:** edit notes, swipe the sheet down, confirm the dialog. Then confirm unedited notes still swipe closed. |
| L1 | Fixed | The close chevron uses the system weight, matching the ellipsis. The chevron stays, since changing it to an xmark is the owner's call. |
| L2 | Fixed | "1 set completed" and "1 second" now use the singular, through `setCount` and a new `secondCount`, in the selector, hold messages and announcements. At accessibility sizes the count moves under "Choose exercise". |
| L3 | Fixed, in part | The "IN YOUR OWN TIME." eyebrow is removed, and the session name is a header. "Exercise 1 of 5" is in sentence case. The receipt's line is written in sentence case and set with `.textCase(.uppercase)`. The navigation title stays "Training", because `TodayLayoutAndWidgetRoutingTests` asserts it. |
| L4 | Fixed | The finish message is the counts plus one consequence, for example "9 of 12 sets done. Unfinished sets won't count.", with "Your Apple Watch recording ends too." only while the Watch records. The journal and Health sentences are gone. Both alerts use "Cancel". |
| L5 | Fixed | The hold's −/+ buttons answer "Minus n"/"Plus n" and "Shorter hold"/"Longer hold" in Voice Control. Rest +15 answers "Plus 15" and "Add 15 seconds". |
| L6 | Not changed here | `WatchSummaryCard.swift` belongs to the progress slice, and its fixer is taking it. |
| L7 | Fixed | With no completed sets, Finish asks "Save a workout with no sets?" and offers "Discard workout" (`finish-discard-empty`), "Save anyway" and Cancel. The receipt shows the time as minutes and seconds with `WorkoutClock.text` (label "Time"), so a short session no longer reads "0". |
| L8 | Device check | No code change. **Device:** in light mode, scroll a lime button under the rest dock and check "+15" and "Skip" against it. |
| L9 | Fixed | The keyboard bar has "Previous field" and "Next field" (`previous-field`, `next-field`) before Done. They walk the open sets' fields in reading order, skip locked sets, and are disabled at either end. `SetRow.fieldNames` is the one ordered list the row and the buttons both use. |
| L10 | Fixed. Device check | VoiceOver focus moves to the receipt's headline after the transition, and "Session saved" is a header. **Device:** finish a workout with VoiceOver on and confirm focus lands on the headline. |
| L11 | Fixed | When the leave question opens, the hold pauses, so the seconds it quotes are the seconds logged. Cancel resumes it. Log and Discard work as before. |
| L12 | Fixed | A bundled `Sounds/hold-tone.caf` is played through `AudioServicesCreateSystemSoundID` (`HoldTone`), in place of system sound 1057. It still follows the ringer switch and the muted setting. |

**Counts:** 16 fixed (L3 in part), three of them with a device check (H1, M5, L10).
L8 is a device check with no code change. M4 and L6 are left to the progress slice.

**Tests:** new in `FORMAAppTests/WorkoutLoggingTests.swift`:
`testFinishMessageIsCountsPlusOneConsequence`, `testAnEmptySessionSaysSoInsteadOfCountingZero`,
`testSetFieldsAreListedInReadingOrder` and `testTheHoldToneShipsInTheAppBundle`. The app
tests run inside the app (`TEST_HOST` is `FORMA.app`), so the tone test checks the real
bundle. The build placed `hold-tone.caf` at the bundle root.

**Files changed:**
- `ios/FORMA/Features/WorkoutView.swift`
- `ios/FORMA/Sounds/hold-tone.caf` (new)
- `ios/FORMAAppTests/WorkoutLoggingTests.swift`

## Sources (retrieved 2 Nov 2026)

- HIG Toolbars: https://developer.apple.com/design/human-interface-guidelines/toolbars (change log: 16 Dec 2025, Liquid Glass)
- HIG Color › Liquid Glass color: https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color
- HIG Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- HIG Modality: https://developer.apple.com/design/human-interface-guidelines/modality
- HIG Sheets: https://developer.apple.com/design/human-interface-guidelines/sheets
- HIG Alerts: https://developer.apple.com/design/human-interface-guidelines/alerts
- HIG Action sheets: https://developer.apple.com/design/human-interface-guidelines/action-sheets
- HIG Buttons: https://developer.apple.com/design/human-interface-guidelines/buttons
- HIG Writing: https://developer.apple.com/design/human-interface-guidelines/writing
- HIG Workouts: https://developer.apple.com/design/human-interface-guidelines/workouts
- HIG Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- HIG Text fields: https://developer.apple.com/design/human-interface-guidelines/text-fields
- SwiftUI `AccessibilityTraits.updatesFrequently`: https://developer.apple.com/documentation/swiftui/accessibilitytraits/updatesfrequently
- SwiftUI `ButtonRole.close` / `.confirm` (iOS 26): https://developer.apple.com/documentation/swiftui/buttonrole/close , https://developer.apple.com/documentation/swiftui/buttonrole/confirm
- SwiftUI `accessibilityInputLabels(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:)
- SwiftUI `sharedBackgroundVisibility(_:)` (iOS 26): https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)
- Apple Developer Forums 795478, disabled toolbar buttons on iOS 26 (user reports plus a DTS reply; not documentation): https://developer.apple.com/forums/thread/795478
