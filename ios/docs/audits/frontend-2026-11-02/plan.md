# Plan tab front-end audit (iOS), 2 November 2026

**Scope:** `ios/FORMA/Features/PlanView.swift` (1,084 lines, read in full) on branch
`feat/watch-collected-data`, plus the design-system types it uses: `FormaTheme.swift`,
`FormaComponents.swift`, `FormaMotion.swift`, `FormaHaptics.swift`, `GlassControls.swift`,
and the `formaTabRoot` / `TrainingDestinations` part of `TrainingTabBar.swift`. The screens
covered are the routine list, routine detail, routine editor (sheet), prescription editor,
exercise library and picker (search and filters), technique guide, and training days.

**Method:** This is a static, read-only review. Nothing was built or run, and no repo
file was edited. Findings marked **(device)** need confirmation on an iPhone, because the
owner does no simulator testing. The checklist comes from the ui-ux-pro-max Pre-Delivery
Checklist (`references/pro-rules.md`) and its `--stack swiftui` / `--domain ux` results. I
also applied the frontend-design critique lens: hierarchy, restraint, and copy that says
exactly what happens.

**Apple sources** were fetched today as HIG JSON (`developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`)
and as DocC `.md`. The HIG pages and their latest change-log dates:
- Search fields (8 June 2026)
- Sheets (24 March 2026)
- Toolbars (16 December 2025)
- Lists and tables (21 June 2023)
- Accessibility
- Typography
- Writing
- Entering data
- Text fields
- Feedback
- Motion
- Materials

The SwiftUI and UIKit API pages cited are linked inline.

**Already decided, not re-reported.** These items are in `apple-design-2026.md`,
`native-design-review.md`, `full-audit-2026-10-26.md`,
`audits/frontend-widget-2026-10/SCREEN_REVIEW.md` and `commit-2/FILE_AUDIT.md`:
- The picker navigates inside the editor sheet, so there is never a second sheet.
- Search stays in the library or picker, with no global Search tab.
- The search drawer is always visible (`.navigationBarDrawer(.always)`).
- Typed queries do not animate the results.
- The per-side range, exact-row draft cleanup and duplicate-Save fixes are in.
- A possible flicker on the Training days toggles (FILE_AUDIT) is already noted.

---

## 1. HIG pass/fail checklist (Plan slice)

| Area | Result | Note |
|---|---|---|
| Liquid Glass adoption and fallbacks | **Pass** | Plan uses only system bars, the search field and sheets, with no custom glass in the content layer (HIG Materials: "Don't use Liquid Glass in the content layer"). The `ControlSurface` fallback for Reduce Transparency and Increase Contrast is correct. |
| Toolbar primary action | **Partial** | Save is semibold text, not the iOS 26 prominent style (L1). |
| Sheets: Cancel and Done placement | **Pass** | Cancel is leading and Save is trailing (HIG Sheets, March 2026). |
| Sheets: swipe to dismiss with unsaved changes | **Fail** | The swipe is blocked silently and no action sheet appears (M1). An untouched new routine also counts as changed (H1). |
| Search placement and behaviour | **Pass** | Inline field pinned above the list it searches, results update while typing, and the placeholder names the scope (HIG Search fields: "position an inline search field above the list it searches, and consider pinning it to the top toolbar"). |
| Search: no-results state | **Partial** | Filters with no query still show the search empty state, which has no "Clear filters" action (M6). |
| Search filters (scope bars and tokens) | **Partial** | Muscle and equipment use Picker rows rather than scopes or tokens. This is acceptable, but see L12. |
| List editing (delete, reorder) | **Partial** | The editor supports both. The routine list supports neither, and has no swipe actions or context menu (M5). |
| Destructive confirmation | **Pass** | Delete routine and Discard changes use `confirmationDialog` with `.destructive`. |
| Undo | **Partial** | No undo for deleting a row in the editor or for a silent superset unlink (L10). Cancel discards the whole draft. |
| Typography and Dynamic Type | **Partial** | Text styles throughout, and the header and photo are dropped at accessibility sizes. The picker row crowds and the 50 pt editorial title grows very large in detail and guide (M8). |
| Colour and contrast, light and dark | **Pass (device)** | The `secondary`, `accent` and `error` tokens all clear 4.5:1 on white and on the system dark row colour. Rows use the system grouped background rather than `FormaTheme.surface` (L11). |
| Tap targets of 44 pt | **Partial** | Most controls set `minHeight: 44`. The editor's `EditButton` in the section header is smaller (M3). |
| VoiceOver labels, traits and order | **Partial** | Picker rows, the start button and number fields are good. There is no explicit move alternative (M3). The header row may be tappable as a whole (M4). Target errors are not tied to their field (L13). |
| Reduce Motion | **Pass** | All motion goes through `formaAnimation` and `formaMotion`, with no raw `withAnimation` and no read of `accessibilityReduceMotion`. |
| Haptics | **Pass** | No speculative haptics. `commit` plays `.failed` on failure. HIG Feedback reserves success confirmation for significant tasks. |
| Form validation and error placement | **Fail** | Errors gather at the bottom of the form, and the disabled Save gives no reason (M2). The 100-exercise notice sits at the top of the picker (M7). |
| Copy and wording | **Partial** | See L4 and L5 (perspective switching, jargon, vocabulary drift). |
| Empty states | **Partial** | The routine list's empty state is fine but its action sits outside it. The library empty state is misleading (M6). |
| Large-list performance (1,411 selectable) | **Pass with one risk** | Lazy `List`, a cached index, and debounced off-main search. The animated filter diff is the remaining risk (M9). |
| Deprecated APIs | **Pass** | None found: `NavigationStack` routes, `navigationDestination`, iOS 17 `onChange`, `ContentUnavailableView`, `AccessibilityNotification`, `foregroundStyle`. |

Pre-Delivery Checklist items I could not verify statically: rendered contrast in both themes,
375 pt width and landscape layout, largest text size, and the VoiceOver order on a device.

---

## 2. Findings

### High

#### H1. An untouched new routine counts as changed, so Cancel asks to discard and swipe-down does nothing
`PlanView.swift:297-301, 403-405, 414`
```swift
_draft = State(initialValue: routine ?? Routine(name: "My routine"))
private var changed: Bool { !targetDrafts.isEmpty || (original.map { $0 != draft } ?? true) }
...
Button("Cancel") { if changed { confirmingDiscard = true } else { dismiss() } }
...
.interactiveDismissDisabled(changed || model.busy)
```
When `original == nil`, `changed` is always `true`. So someone who taps **Create a routine**
and then backs out meets "Discard your routine changes?" with nothing changed. Their
swipe-down also rubber-bands with no explanation.

- **Apple guidance:** HIG Sheets says to support swiping to dismiss, and to prompt with an
  action sheet only "If people have unsaved changes"
  (https://developer.apple.com/design/human-interface-guidelines/sheets). HIG Writing says to
  avoid copy that misreports state.
- **Impact:** This happens on every create flow. A false warning teaches people to ignore
  the real one, and the most common dismissal gesture appears broken.
- **Fix:** Compare against the initial draft rather than assuming a new draft is dirty.
  ```swift
  @State private var baseline: Routine
  init(routine: Routine?) {
    original = routine
    let start = routine ?? Routine(name: "My routine")
    _draft = State(initialValue: start)
    _baseline = State(initialValue: start)
  }
  private var changed: Bool { !targetDrafts.isEmpty || draft != baseline }
  ```

### Medium

#### M1. Real unsaved changes block swipe-to-dismiss silently instead of offering the discard action sheet
`PlanView.swift:414` `.interactiveDismissDisabled(changed || model.busy)`

- **Apple guidance:**
  - HIG Sheets: "If people have unsaved changes in the sheet when they begin swiping to
    dismiss it, use an action sheet to let them confirm their action."
    (https://developer.apple.com/design/human-interface-guidelines/sheets)
  - `interactiveDismissDisabled` only prevents dismissal
    (https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:)).
  - UIKit's hook for this case is `presentationControllerDidAttemptToDismiss(_:)`. Its
    documentation says to use the method "to inform the user why the presentation can't be
    dismissed"
    (https://developer.apple.com/documentation/uikit/uiadaptivepresentationcontrollerdelegate/presentationcontrollerdidattempttodismiss(_:)).
- **Impact:** The gesture fails and nothing explains why.
- **Fix:** Add a small `UIViewControllerRepresentable` that sets itself as the presentation
  controller's delegate. In `presentationControllerDidAttemptToDismiss`, set
  `confirmingDiscard = true` so the existing dialog appears. Keep `interactiveDismissDisabled`
  as the gate. Unconfirmed: I found no SwiftUI-only API for dismiss attempts in the iOS 26
  documentation.

#### M2. Validation messages sit at the bottom of the form, and the disabled Save never says why
`PlanView.swift:386-390, 408-411`
```swift
if let validation {
  Section { Label(validation, systemImage: "info.circle").foregroundStyle(FormaTheme.secondary) }
}
...
Button(model.busy ? "Saving…" : "Save") { ... }.disabled(model.busy || validation != nil)
```
"Give your routine a name." and "Use a shorter routine name…" belong to the name field at the
top. They appear below the exercise list, which can be up to 100 rows, so they are often off
screen. The greyed Save gives VoiceOver users no reason. The `failure` section at
`L391-396` has the same placement and is not announced.

- **Apple guidance:**
  - HIG Writing: "display it as close to the problem as possible… be clear about what someone
    can do to fix it"
    (https://developer.apple.com/design/human-interface-guidelines/writing).
  - HIG Entering data: "make sure people understand that they must provide the required data
    before they can proceed"
    (https://developer.apple.com/design/human-interface-guidelines/entering-data).
  - ui-ux-pro-max ux "Error Placement" and "Error Messages must be announced".
- **Impact:** Save looks broken, and the reason is out of sight.
- **Fix:**
  - Split `invalid` by section. Put name and description errors in the footer of the
    "Make it yours" section.
  - Put "Add at least one exercise", the per-side message and the cue-length message in the
    footer of the Exercises section.
  - Add `.accessibilityHint(validation ?? "")` to Save.
  - After a failed save, post `AccessibilityNotification.Announcement(failure)` and scroll to
    the message with `ScrollViewReader`.

#### M3. Reordering in the editor depends on a small, unusually placed Edit button and offers no explicit VoiceOver or Voice Control move action
`PlanView.swift:354-357, 376-380`
```swift
.onMove { source, destination in ... }
...
header: { HStack { Text("Exercises · \(draft.exercises.count)/100"); Spacer(); EditButton().textCase(nil) } }
```
- **Tap target:** An `EditButton` inside a section header gets roughly the header's text
  height as its tap area. That is below the 44 × 44 pt default in HIG Accessibility and
  probably near the 28 pt minimum **(device)**.
- **Move alternatives:** Moves happen only by dragging a handle in edit mode. The project's
  own docs claim "accessible reorder alternatives" (`apple-design-2026.md` table, row
  `Features/PlanView.swift`; FILE_AUDIT: "accessible reorder alternative via Edit"). No
  non-drag alternative exists in code. Whether VoiceOver can operate SwiftUI's reorder handle
  is unconfirmed **(device)**.
- **Apple guidance:**
  - HIG Accessibility: "Offer alternatives to gestures… offer onscreen ways to achieve the
    same outcome" and the 44 × 44 pt default
    (https://developer.apple.com/design/human-interface-guidelines/accessibility).
  - WWDC26 session 220, as cited in `apple-design-2026.md`: named actions as an alternative
    to gestures.
  - `accessibilityAction(named:_:)`:
    https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:).
- **Impact:** Reordering, which also breaks supersets, is hard to discover and hard to
  operate without precise dragging.
- **Fix:**
  - Move `EditButton` into a `ToolbarItem(placement: .bottomBar)`, or give it
    `.frame(minHeight: 44)` with `.contentShape(Rectangle())`.
  - Add named actions to each `RoutineEditorRow` link:
    ```swift
    .accessibilityAction(named: "Move up") { move(entry.id, by: -1) }
    .accessibilityAction(named: "Move down") { move(entry.id, by: 1) }
    ```
    The `move` helper should call `draft.exercises.move` and then `preserveValidGroups()`.
  - Optionally add the same actions to a `.contextMenu`, which also serves Voice Control.

#### M4. The routine detail header row holds a Button plus other content, so the whole row may start the workout (needs device confirmation)
`PlanView.swift:180-217`. A single `List` row contains the photo, the eyebrow, the title,
the description, the meta line and the `Start workout` `Button` with
`.buttonStyle(PrimaryButtonStyle())`.

- **Apple guidance:** HIG Lists and tables says to provide appropriate feedback when people
  select a list item, and in general a row should have one clear action. Whether SwiftUI
  routes a tap anywhere in the row to the Start button depends on the button style. Custom
  `ButtonStyle` conformances are not documented to opt out, so this is **unconfirmed**.
- **Impact if it reproduces:** Tapping the cover photo or the description starts a workout,
  which then waits on the Watch or a save. That is an accidental start of the app's main
  action. Escalate to High if it reproduces.
- **Fix:** Move the Start button into its own `Section` row with clear row insets and
  background. Alternatively, keep the header as non-interactive content and place Start in a
  `.safeAreaInset(edge: .bottom)` bar. To test, tap the photo on a device.

#### M5. The routine list cannot be edited where it is shown: no swipe actions, no context menu, no reorder
`PlanView.swift:39-43`
```swift
ForEach(routines) { routine in
  NavigationLink(value: TrainingRoute.routine(routine.id)) { RoutinePlanRow(routine: routine) }
}
```
Deleting or editing a routine takes three steps: push the detail, scroll to the bottom, tap.
There is no Duplicate, which matters for training variations.

- **Apple guidance:** HIG Lists and tables: "Let people edit a table when it makes sense.
  People appreciate being able to reorder a list"
  (https://developer.apple.com/design/human-interface-guidelines/lists-and-tables).
  `swipeActions(edge:allowsFullSwipe:content:)`:
  https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:).
- **Impact:** Managing several routines is slow.
- **Fix:**
  - Add `.swipeActions(edge: .trailing, allowsFullSwipe: false)` with a `Button(role: .destructive)`.
    It should set a `pendingDelete` and reuse the existing confirmation dialog. Keep
    `allowsFullSwipe` false because there is no undo.
  - Add `.contextMenu { Edit; Duplicate; Delete }`.
  - Reordering changes the order the web reads, so confirm it against the workspace contract
    before adding `onMove`.

#### M6. The library's empty state assumes a text search even when filters caused it, and gives no way out
`PlanView.swift:784-786`
```swift
if matches.isEmpty { ContentUnavailableView.search(text: query) }
```
With an empty query and an impossible muscle and equipment pair, for example Neck and
Barbell, the system search empty state appears. Its default wording points to the query, as
in "check the spelling or try a new search" **(device: confirm the exact system text)**. The
**Clear search & filters** button is above it in the filter section, not in the empty state.

- **Apple guidance:**
  - HIG Writing: "Provide clear next steps on any blank screens."
  - HIG Search fields: "Default to a broader scope and let people refine it."
  - `ContentUnavailableView.search` is described as "expected to be contained within a
    searchable view hierarchy… the search query to be parsed into the view's description"
    (https://developer.apple.com/documentation/swiftui/contentunavailableview/search).
- **Fix:**
  ```swift
  if matches.isEmpty {
    if hasSearchWords { ContentUnavailableView.search(text: query) }
    else {
      ContentUnavailableView {
        Label("No exercises match these filters", systemImage: "line.3.horizontal.decrease.circle")
      } description: { Text("Try another muscle or equipment type.") }
        actions: { Button("Clear filters") { muscle = "All muscles"; equipment = "All equipment" } }
    }
  }
  ```

#### M7. The 100-exercise limit notice appears at the top of the picker, far from the row that was tapped
`PlanView.swift:847-849, 905-907`
```swift
if let addNotice { Text(addNotice).font(.footnote).foregroundStyle(FormaTheme.error) }   // in filterSection, top of list
...
let notice = "This routine already has 100 exercises. Remove one before adding another."
addNotice = notice
```
Someone scrolled deep into 1,411 rows taps "+" and nothing visible happens. The row keeps its
"+" and the notice is off screen. VoiceOver users do get the announcement.

- **Apple guidance:** HIG Writing: display errors "as close to the problem as possible".
  HIG Feedback: people "only need to know when it doesn't" succeed
  (https://developer.apple.com/design/human-interface-guidelines/feedback).
- **Fix:**
  - Disable every add button once the limit is reached, by passing a `canAdd` closure or the
    current count.
  - Show the notice in a `.safeAreaInset(edge: .top)` banner, or as the section header of the
    results.
  - Also play `model.haptic(.warning)`, which is the documented "refused and the screen says
    why" case in `FormaHaptics.swift:45`.

#### M8. Dynamic Type at accessibility sizes: the picker row crowds horizontally, and the 50 pt editorial title grows very large (device)
- **`PlanView.swift:864-896`:** The picker row is a horizontal stack holding the name, muscle
  and equipment; the "Added 3 times" label; and a 44 pt info button. At sizes AX3 to AX5 the
  name column gets squeezed and wraps word by word.
- **`FormaTheme.swift:166`:** `FormaDisplayFont.font(size: 50, relativeTo: .largeTitle)` is
  used in `RoutineDetailView` (L189) and `GuideView` (L955). `PlanView` hides its header at
  accessibility sizes, but these two screens do not. A 50 pt base that scales with Large
  Title (34 → 60 pt at AX5, about ×1.76) reaches roughly 88 pt condensed type. Long exercise
  names then fill most of the first screen **(device)**.
- **Apple guidance:** HIG Typography covers three points
  (https://developer.apple.com/design/human-interface-guidelines/typography):
  - "Consider using a stacked layout where text appears above secondary items"
  - "Prioritize important content when responding to text-size changes"
  - "Keep text truncation to a minimum"
- **Fix:**
  - In `pickerRow`, when `textSize.isAccessibilitySize`, use a vertical stack: the name and
    details, then a row with the Added state and the info button.
  - Cap the display title, for example
    `EditorialTitle(...).dynamicTypeSize(...DynamicTypeSize.accessibility1)`
    (https://developer.apple.com/documentation/swiftui/view/dynamictypesize(_:)). Or switch
    to `.largeTitle` system type at accessibility sizes. The body text keeps scaling fully.

#### M9. Changing a filter animates a diff over up to 1,411 list rows (device: performance)
`PlanView.swift:805` `.formaAnimation(FormaMotion.reveal, value: [muscle, equipment])`
applies to the whole `List`.

- **Problem:** Moving from all 1,411 rows to one muscle animates about 1,400 removals in one
  batch update. On the full-motion path that can hitch, and an animated change of that size
  carries no spatial meaning.
- **Apple guidance:** HIG Motion: "generally avoid adding motion to UI interactions that
  occur frequently" (https://developer.apple.com/design/human-interface-guidelines/motion).
  ui-ux-pro-max ux: decorative-only animation is an anti-pattern.
- **Impact:** Possible dropped frames on filter change. This is unmeasured, and the project
  docs already record that keystroke latency is unmeasured.
- **Fix:**
  - Animate only when the change is small, for example when `abs(old.count - new.count) < 60`.
  - Or animate the count header with `.contentTransition(.numericText())` and swap the rows
    without animation.
  - Measure with Instruments' SwiftUI template on a device before and after.

### Low

#### L1. Save in the editor is not the iOS 26 prominent action
`PlanView.swift:408-411`: `Button(...).fontWeight(.semibold)`.

- **Apple guidance:** HIG Toolbars: "Use the .prominent style for key actions such as Done or
  Submit… Only specify one primary action, and put it on the trailing side"
  (https://developer.apple.com/design/human-interface-guidelines/toolbars).
  `glassProminent` is available from iOS 26.0
  (https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent).
  `ButtonRole.confirm` is available from iOS 26.0
  (https://developer.apple.com/documentation/swiftui/buttonrole/confirm).
- **Fix:** Wrap the button in a modifier that applies `.buttonStyle(.glassProminent)` under
  `if #available(iOS 26.0, *)` and keeps semibold otherwise. Leave it disabled while invalid.

#### L2. The picker shows a "Done (n)" button that only goes back
`PlanView.swift:810-816`. Inside the sheet, the picker already has the system Back button.
"Done" next to Back suggests the whole routine is finished or saved.

- **Apple guidance:** HIG Sheets: "Avoid showing all three buttons — Cancel, Done, and Back —
  together"; "The Back button… isn't intended to dismiss a sheet."
- **Fix:** Drop Done and rely on Back. To keep the count, show it in the title, for example
  `navigationTitle("Add exercise")` with a subtitle on iOS 26 (unconfirmed API), or in the
  results header ("3 added").

#### L3. Navigation titles are generic, and the tab root uses an inline title
- `PlanView.swift:265` `navigationTitle("Routine")`
- `PlanView.swift:1007` `navigationTitle("Technique guide")`
- `PlanView.swift:76-77`: the tab root `"Plan"` is inline, with an editorial header instead
  of a large title.

Once the editorial title scrolls away, the bar does not say which routine or exercise is
open.

- **Apple guidance:** HIG Toolbars: "Provide a useful title for each window"; "Use a large
  title to help people stay oriented as they navigate and scroll."
- **Fix:** Use `navigationTitle(current.name)` and `navigationTitle(exercise.name)` with
  `.navigationBarTitleDisplayMode(.inline)`. The inline root title may be deliberate; if so,
  record that in `apple-design-2026.md`.

#### L4. Template chrome and switching perspective (frontend-design critique)
- **Eyebrows:** All-caps, tracked caption eyebrows sit above titles on three screens: `L21`
  "YOUR TRAINING, YOUR WAY", `L187` "THE SESSION", `L953` "KNOW THE MOVEMENT". They add a
  VoiceOver stop before each real heading and carry no information.
- **Marketing header:** "A little structure. A lot of possibility." (`L23`) sits on a utility
  tab.
- **Pronouns:** The copy switches between "My routines" (`L53`) and "Your workspace…"
  (`L57`) / "YOUR TRAINING".
- **Apple guidance:** HIG Writing: "Use possessive pronouns sparingly… try not to switch
  perspectives"; "Choose a style for each UI element type and use it consistently."
- **Fix:**
  - Remove the eyebrows, or turn them into real metadata, for example "45 min · Intermediate"
    on detail.
  - Rename the section to "Routines".
  - Keep one editorial moment per screen.

#### L5. Copy that does not say exactly what happens
- `L36` "Make room for your first routine". Put the Create action inside the empty state
  using `ContentUnavailableView`'s `actions:`.
- `L60` footer: three unrelated ideas (starter loads, pacing, offline) under the routine
  list.
- `L96` "1,411 movements" against `L783`, where `countPhrase` gives "1411 exercises".
  `countPhrase` (`TodayView.swift:44`) does not group digits, and the noun drifts between
  "movements" and "exercises". Use `count.formatted()` and pick one noun.
- `L647` "Legacy Forearm plank: each rep represents a 10-second hold. Existing units are
  preserved." "Legacy" and "units" are system terms. Suggest "For Forearm plank, each rep
  counts as a 10-second hold."
- `L451` conflict error: "Keep your draft open or reopen the current routine before saving."
  It gives no way forward from inside the sheet. Offer "Replace with my version" or "Discard
  my changes".

#### L6. The Estimated time stepper drifts off the 5-minute grid and allows no direct entry
`PlanView.swift:341-342`: `in: 1...1000, step: 5` starting at 45. Stepping down clamps at 1,
and stepping back up gives 6, 11, 16 and so on. Reaching long sessions takes many taps.

- **Fix:** Use `in: 5...600, step: 5`, or a `TargetNumberField`-style numeric field. HIG
  Entering data: "offer choices instead of requiring text entry" where it helps. A menu
  `Picker` of common lengths also works.

#### L7. The name, description and cue fields rely on placeholders, and the label disappears once someone types
- `PlanView.swift:336-340` `TextField("Routine name", …)` and
  `TextField("What is this session for?", …)`
- `L692-697` `TextField("A cue for your next session", …)`

The accessibility labels are good, but sighted users lose the field's purpose once text is
entered.

- **Apple guidance:** HIG Text fields: "Because placeholder text disappears when people start
  typing, it can also be useful to include a separate label"
  (https://developer.apple.com/design/human-interface-guidelines/text-fields).
- **Fix:** Use `LabeledContent("Name") { TextField(...) }`, or a small caption `Text` above
  each multi-line field. For the 140-character cue, add a live count
  (`"\(n)/140"`) in the footer.

#### L8. The routine detail index uses a monospaced design, against the app's own numeral token
`PlanView.swift:224-226`:
`.font(.system(.title3, design: .monospaced).weight(.semibold))`.
`FormaFont.numeral` (`FormaTheme.swift:114-121`) states "Rounded and monospaced designs are
not used for numerals" and names routine indexes as one of its uses.

- **Fix:** `.font(FormaFont.numeral(.title3, weight: .semibold))`.

#### L9. Exercises missing from the catalogue disappear silently, and in the editor they cannot be deleted
- `PlanView.swift:221` (`if let exercise = model.exercise(entry.exerciseId)`) and `L346`
  drop the row.
- The entry still counts toward "Exercises · n/100", still passes validation, and offers no
  swipe target.
- The `if` inside `ForEach` also gives a variable number of rows per element, which stops
  `List` building rows lazily for that section.
- This is rare, because retired IDs stay in the catalogue, but it is not handled.
- **Fix:** Render a fallback row ("Unavailable exercise", with its ID and a Remove action)
  rather than nothing.

#### L10. Deleting a row and unlinking a superset have no undo
- **Superset:** `preserveValidGroups()` (`L473-482`) silently clears `groupId` when a move
  splits a superset. Only the footer warns about it.
- **Row delete:** `.onDelete` removes an exercise and its targets with no undo, though Cancel
  can discard the whole draft.
- **Fix:**
  - Register undo through `@Environment(\.undoManager)` for delete and move, which supports
    shake to undo.
  - When a move unlinks a group, post an announcement ("Superset unlinked") and show it in
    the footer.

#### L11. Visual inconsistency between screens and system rows
- `TrainingDaysView` (`L1024-1058`) does not apply `.scrollContentBackground(.hidden)` or
  `.background(FormaTheme.canvas)`, unlike every sibling screen.
- Rows elsewhere use the system grouped row colour (`#1C1C1E` in dark) on the green-tinted
  `canvasDark` `#151A17`. Consider `.listRowBackground(FormaTheme.surface)` so tokens and
  rows agree.
- The weekday names are hard-coded English (`L1023`). If localisation is ever planned, map the
  Monday-first index to `Calendar.current.weekdaySymbols`.

#### L12. Filters as Picker rows rather than search scopes or tokens (optional)
`PlanView.swift:837-859`. HIG Search fields: "Use a scope bar to filter among clearly defined
search categories… Use tokens to filter by common search terms." The current pickers scroll
away with the results. `searchScopes(_:activation:_:)` (iOS 16.4+) for muscle would keep the
filter attached to the field. Equipment could become a token via suggestions. This is a
product choice; the current behaviour is correct.

#### L13. Inline target errors are not tied to their field for VoiceOver
`PlanView.swift:567-575`. The error `Label` is a separate element after the `TextField`.
Moving focus to the field reads "Weight, kg" with no error. Add
`.accessibilityValue(drafts[fieldKey]?.error.map { "Invalid. \($0)" } ?? "")` to the
`TextField`. A per-keystroke announcement would be noisy, so do not add one.

#### L14. Deleting a routine may briefly show "This routine was removed" before the pop (device)
`PlanView.swift:258-261, 275-277`. `commit` removes the routine, which makes `current` nil and
re-renders the unavailable state before `dismiss()` runs.

- **Fix:** Call `dismiss()` first and commit afterwards, keeping the routine ID. Or keep the
  last value of `current` in `@State` while a delete is pending.

---

## 3. What is already correct

- **Liquid Glass:**
  - No glass in the content layer.
  - The system nav bar, search and sheet chrome adopt it automatically.
  - `ControlSurface` falls back to opaque `FormaTheme.surface` with Reduce Transparency or
    Increase Contrast, and to `.regularMaterial` before iOS 26, all behind `#available`.
  - `formaBottomBar` falls back from `safeAreaBar` to `safeAreaInset`.
- **Search:**
  - An inline, pinned drawer scoped to the library, matching HIG Search fields (June 2026).
  - Results update while typing, with debounced, detached filtering (`L913-932`).
  - The placeholder states the scope.
  - The query is kept when filters change.
  - The index is built once per catalogue change.
  - Typed queries do not animate the rows.
- **Picker semantics:**
  - Each add button reads "Add X, muscle, equipment" with a value of "Added", "Added 2 times"
    and a hint.
  - The info button is separate, 44 × 44 pt, and labelled "Technique guide for X".
  - Adds post an `AccessibilityNotification`.
  - The info button reveals more about the row's own content, which is how HIG Lists and
    tables intends it.
- **Sheet flow:**
  - One modal; the picker and target editor push inside it.
  - Cancel is leading and Save trailing.
  - A destructive "Discard changes" confirmation exists.
  - Save shows "Saving…" and is guarded against duplicate tasks.
  - The failure is shown inline and the root alert is cleared (`L465-469`).
- **Destructive actions:** Delete routine uses a titled `confirmationDialog` whose message
  states what is kept: active and completed workouts.
- **Number entry:**
  - Locale-aware, full-string parsing.
  - Invalid drafts survive Back.
  - The unit is visible and spoken.
  - `.decimalPad` with a keyboard Done button.
  - Errors appear inline under the field, in primary text with an error-coloured icon, so
    colour is not the only signal.
- **Start action:**
  - Pending progress inside the button.
  - `accessibilityValue("Starting")`.
  - Disabled while busy.
  - Haptic `.started` only after the start is confirmed (`AppModel.swift:360`).
- **Dynamic Type:**
  - System text styles everywhere.
  - The marketing header and routine photos drop at accessibility sizes.
  - `EditorialTitle` uses `relativeTo:` scaling and the header trait.
  - Descriptions truncated in the list (`lineLimit(2)`) appear in full on the detail screen,
    as HIG Typography allows.
- **Motion:**
  - Every animation goes through `FormaMotion` and the environment.
  - `PressableCardStyle` and `PrimaryButtonStyle` degrade to opacity below full motion.
  - No feature view reads `accessibilityReduceMotion`.
- **Contrast tokens:** Increase Contrast variants for primary, secondary, accent, error and
  line. On lime, the label uses ink at 13.2:1 with an accent edge in light mode.
- **Tap targets:** 44 pt minimums on Create, Add exercise, Clear filters, Edit and Delete
  routine, and the picker controls.
- **Empty and limit states:** The routine-limit footer (200) explains itself. The guide
  falls back to text when unavailable and links only to http(s) URLs (`safeWebURL`).
- **APIs:** No deprecated APIs. Navigation is type-safe through `TrainingRoute`.
  `navigationDestination` is never placed inside a lazy container.
