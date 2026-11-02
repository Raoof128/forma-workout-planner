# FORMA iOS front-end audit: app shell, navigation, design system

Date: 2 November 2026. Worktree `worktrees/watch-collected-data` (branch `feat/watch-collected-data`).
Slice: `ios/FORMA/App/FORMAApp.swift` and every file in `ios/FORMA/DesignSystem/`
(`TrainingTabBar.swift`, `FormaTheme.swift`, `FormaMotion.swift`, `FormaHaptics.swift`,
`GlassControls.swift`, `FormaComponents.swift`, `WidgetNavigationGuard.swift`). Each file was read in full.

Method: static read-only review. No build, simulator or device run (device testing is the owner's).
Read first: `forma-workout-planner/CLAUDE.md` "Native iOS and watchOS", the AGENT.md motion/haptics
rules and tab-bar entries (28 to 30 Oct), `ios/docs/apple-design-2026.md`,
`ios/docs/native-design-review.md`, `ios/docs/full-audit-2026-10-26.md` and
`ios/docs/account-review-and-tab-bar-2026-10-28.md`. Skills applied: frontend-design (critique lens) and
ui-ux-pro-max (`--stack swiftui`, `--domain ux`, `references/pro-rules.md` Pre-Delivery Checklist).
Contrast ratios were computed with the WCAG 2 formula from the hex values in `FormaTheme`/`BrandPalette`.
Two existing simulator screenshots in the repo were inspected as evidence (dated 29 Oct 2026, one day
before the 30 Oct overlay rework of the bar, so each finding that relies on them says so).

Apple sources fetched today (the `.md` form of each page):

- HIG Materials (change log: 9 Sep 2025): https://developer.apple.com/design/human-interface-guidelines/materials
- HIG Color, Liquid Glass color (16 Dec 2025): https://developer.apple.com/design/human-interface-guidelines/color
- HIG Tab bars (8 Jun 2026): https://developer.apple.com/design/human-interface-guidelines/tab-bars
- HIG Dark Mode: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- HIG Motion (9 Sep 2025): https://developer.apple.com/design/human-interface-guidelines/motion
- HIG Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- HIG Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Applying Liquid Glass to custom views: https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- `AccessibilityTraits.isTabBar` (iOS 17.0+): https://developer.apple.com/documentation/swiftui/accessibilitytraits/istabbar
- `safeAreaBar(edge:alignment:spacing:content:)` (iOS 26.0+): https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)
- `tabItem(_:)` (availability iOS 13.0 to 27.2, so deprecated in 27.2): https://developer.apple.com/documentation/swiftui/view/tabitem(_:)

---

## 1. Pass/fail checklist (this slice)

| Area | Result | Note |
|---|---|---|
| Liquid Glass adoption behind `#available(iOS 26)` | PASS | `glassEffect`, `GlassEffectContainer`, `safeAreaBar` are all guarded; `.regularMaterial` below 26 |
| Glass only in the control layer | PASS | Tab bar, resume control and bottom bars only; content stays opaque |
| Legibility of text and symbols on glass | **FAIL** | Fixed brand colours on adaptive glass; no scroll-edge effect under the custom bar (H2, M4) |
| Reduce Transparency / Increase Contrast fallback | PASS | Opaque `surface` + `fieldBorder` stroke in `ControlSurface` and `TrainingTabBar.surface` |
| Colour tokens: light, dark, Increase Contrast | PASS | Four variants per token; secondary 5.75:1 (light) and 9.65:1 (dark) on canvas; accent 6.23:1 / 14.89:1 |
| Dark Mode base vs elevated backgrounds | FAIL (minor) | Custom canvas/surface never switch to elevated (L1) |
| Dynamic Type, including accessibility sizes | PASS | Tab labels capped at AX1 with Large Content Viewer; resume label unwraps; `@ScaledMetric` seal; display font is `relativeTo:` |
| Tap targets (44 pt) | PASS | Tabs 56/62 pt tall, collapsed control 52, resume 56, banner close 44x44, primary button 56/44 |
| Safe areas and keyboard | **FAIL** | Floating bar and its clearance sit above the keyboard (H1) |
| Landscape | FAIL (minor) | Bar stretches edge to edge with stacked labels (L2) |
| VoiceOver labels, traits, order | PARTIAL | Labels, selected trait and hints are good; tab bar trait missing (M2) |
| Reduce Motion / Prefer Cross-Fade | PASS | Resolved once at the root; spatial motion becomes a 160 ms fade; Off removes it |
| Haptics | PASS (with decided caveat) | All routed through `FormaHapticRelay` and the You switch; tab-change impact is an owner decision (section 4) |
| Navigation pattern | PASS (with decided caveat) | `TabView` + per-tab `NavigationStack` with value paths; reselect pops/scrolls like the system; custom bar is an owner decision |
| Copy and wording | **FAIL** | One alert title and button for every kind of failure (M1); a widget alert points to the wrong tab (L5) |
| Deprecated APIs | FAIL (minor) | `tabItem(_:)` is deprecated in the 27.2 SDK (L3) |
| Consistency with the repo's own design record | **FAIL** | `apple-design-2026.md` still describes the system tab bar and bottom accessory (M3) |

Pre-Delivery Checklist (pro-rules.md) items that do not pass in this slice: "Safe areas are respected
for ... tab bars" and "Scroll content is not hidden behind fixed/sticky bars" (H1); "Tested on ...
landscape" (L2); "Micro-interaction timing stays in the 150-300 ms range" (the 420 ms tab spring with
0.28 bounce and the 0.74 s Progress chart sweep; see section 4). Every other checklist item passes for
this slice.

---

## 2. Findings

Counts: **2 High, 5 Medium, 11 Low.**

### High

#### H1. The floating tab bar rides above the keyboard, and its clearance is added on top of the keyboard inset

- **Where:** `App/FORMAApp.swift:235-257` (bar overlaid at `.bottom` on the `TabView`),
  `DesignSystem/TrainingTabBar.swift:194-201` (`TrainingBarClearance` adds a `Color.clear` inset of
  `navigation.barInset` to every tab root and pushed screen), `TrainingTabBar.swift:229-231` (applied to every
  `TrainingRoute` destination).
- **Evidence:** there is no keyboard handling for the bar anywhere in the app (`grep -i keyboard` finds only
  keyboard toolbars and `.scrollDismissesKeyboard`). The overlay inherits the keyboard safe area, so it is laid
  out above the keyboard; the clearance inset is likewise placed above the keyboard. The repo's own simulator
  capture `ios/docs/audits/frontend-widget-2026-10/screenshots/after/light-11-library-search.png` (29 Oct)
  shows the whole four-tab capsule sitting on top of the keyboard in Exercise library search, covering the second
  result ("Barbell Guillotine Bench Press" is legible only through the glass behind the "Plan" label). The bar was
  moved from a `safeAreaInset` to an overlay on 30 Oct; neither form ignores the keyboard, so the behaviour should
  persist. Needs a device re-check on the current build.
- **Affected screens (all pushed inside a tab, so the bar stays):** Exercise library search
  (`PlanView.swift:798`, `.searchable`), Change password, Two-step, Account privacy (`SecureField`, "Type DELETE to
  confirm"), Account profile, Routine editor fields if pushed.
- **Apple guidance:** HIG Tab bars: "A tab bar floats above content at the bottom of the screen." The system tab bar
  stays behind the keyboard; it never takes space above it. HIG Accessibility (Mobility) and pro-rules
  "Scroll content is not hidden behind fixed/sticky bars".
- **User impact:** with the resume control showing, about 130 pt above the keyboard are lost; on an iPhone SE-class
  screen, a search shows one or two rows. During sign-in-type flows the focused field can sit right under the bar.
- **Fix:** track keyboard visibility once in `TrainingNavigation` and hide the bar and zero the clearance while it is up.

```swift
// TrainingNavigation
var keyboardVisible = false

// ActiveTrainingAccessory.body
content.overlay(alignment: .bottom) {
  if !navigation.keyboardVisible { GlassGroup(spacing: 2) { ... } }
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
  navigation.keyboardVisible = true
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
  navigation.keyboardVisible = false
}

// TrainingBarClearance
Color.clear.frame(height: navigation.keyboardVisible ? 0 : navigation.barInset)
```

  Alternatively add `.ignoresSafeArea(.keyboard, edges: .bottom)` to the overlay so the bar slides under the
  keyboard like the system bar, and still zero the clearance while the keyboard is visible.

#### H2. Fixed brand colours on adaptive Liquid Glass: tab labels and the resume control can drop to about 2.3–2.8:1 over FORMA's own dark panels

- **Where:** `TrainingTabBar.swift:419` (`.foregroundStyle(FormaTheme.primary)`), `:455`
  (`selected ? FormaTheme.accent : FormaTheme.secondary`), `:485` (`.glassEffect(.regular, in: .capsule)`);
  `FORMAApp.swift:297, 304` (resume control text in `FormaTheme.secondary` / `primary`) on
  `GlassControls.swift:19` (`.glassEffect(.regular, in: .rect(...))`).
- **Apple guidance:** HIG Color, Liquid Glass color: "For smaller elements like toolbars and tab bars, the system can
  adapt Liquid Glass between a light and dark appearance in response to the underlying content. By default, symbols
  and text on these elements follow a monochromatic color scheme, becoming darker when the underlying content is
  light, and lighter when it's dark." HIG Materials: "Help ensure legibility by using vibrant colors on top of
  materials." HIG Materials shows regular glass "appears darker when there is a dark background beneath it."
- **Evidence:** FORMA's content layer includes fixed-ink panels in both appearances: the Today session panel
  (`TodayView.swift:285`, `FormaTheme.heroInk` #151A17) and exercise media (`ExerciseMedia.swift:484`). Both scroll
  under the bar. In light mode the unselected tab colour #59635D measures 2.83:1 against #151A17 and the selected
  olive #4C631C 2.61:1, below the HIG Accessibility table's 4.5:1 for text up to 17 pt (tab labels are `.caption2`,
  11 pt). The 29 Oct landscape capture (`screenshots/after/17-today-compact-landscape.png`) also shows content text
  ("…planned days. Checks show completed workouts") reading through the glass behind the "Plan" label. How far the
  custom `glassEffect` darkens over ink is **unconfirmed**; check it on the device.
- **User impact:** in the gym (bright light, glance reading), labels can wash out exactly when the Today hero or a
  media card is under the bar.
- **Fix:** let the glass drive the foreground. Use hierarchical styles for the neutral parts, and keep colour only on
  the selected indicator's fill, which the HIG recommends ("apply color to the background rather than to symbols or
  text"):

```swift
// unselected
.foregroundStyle(.secondary)          // vibrant on glass, adapts light/dark
// selected: keep the accent capsule, put the glyph and label in .primary
.foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
// resume control
Text("Workout in progress").font(.caption).foregroundStyle(.secondary)
Text(name).foregroundStyle(.primary)
```

  Keep the explicit `FormaTheme` colours in the opaque Reduce Transparency / Increase Contrast branch, where the
  backdrop is known. Verify the 4.5:1 floor on device over the Today hero in light mode.

### Medium

#### M1. One alert title and button for every failure: "Couldn't save this change" / "Keep editing"

- **Where:** `FORMAApp.swift:335-345`.

```swift
.alert("Couldn't save this change", isPresented: ...) {
  Button("Keep editing", role: .cancel) { model.errorMessage = nil }
} message: { Text(model.errorMessage ?? "Your last saved workout has been preserved.") }
```

- **Evidence:** `model.errorMessage` is also set for "Your local training could not be deleted. …"
  (`AppModel.swift:458`), "Your appearance preference could not be saved. …" (`:483`) and "You're signed out, but
  the saved account copy couldn't be fully removed. …" (`AppModel+Account.swift:204`). Each message also appends
  `error.localizedDescription`, so system wording ("The operation couldn't be completed. (NSCocoaErrorDomain…)")
  reaches the person.
- **Apple guidance:** HIG Alerts and Writing ask for titles and buttons that describe the situation and the action.
  (The Alerts page was not re-fetched today; the frontend-design writing rule applies directly: "A CTA says exactly
  what happens when it is used.")
- **User impact:** after a failed sign-out cleanup or a failed delete, the person is told a change wasn't saved and
  offered "Keep editing" when nothing is being edited.
- **Fix:** make the error a value with its own title and action, and keep system detail out of the body.

```swift
struct RootError: Identifiable { let id = UUID(); let title: String; let message: String; let dismiss: String }
// AppModel: rootError = RootError(title: "Couldn't remove the account copy",
//   message: "You're signed out. The copy on this iPhone is still there; remove it from You.", dismiss: "OK")
.alert(item: $model.rootError) { e in Alert(title: Text(e.title), message: Text(e.message), dismissButton: .cancel(Text(e.dismiss))) }
```

  (Or the `presenting:` overload already used for account interruptions at `FORMAApp.swift:348-362`.)

#### M2. The custom tab bar does not carry the tab-bar accessibility trait

- **Where:** `TrainingTabBar.swift:420-422` and `:472-475`.

```swift
.accessibilityElement(children: .contain)
.accessibilityLabel("Training tabs")
...
.accessibilityValue("Tab \((TrainingTab.allCases.firstIndex(of: tab) ?? 0) + 1) of 4")
.accessibilityAddTraits(selected ? [.isSelected] : [])
```

- **Apple guidance:** `AccessibilityTraits.isTabBar`, "The accessibility element is a tab bar." (iOS 17.0+, so no
  availability guard is needed.) HIG Accessibility: "Prefer system gestures and behaviors people are already familiar with."
- **User impact:** VoiceOver users hear a group of buttons with a hand-written "Tab 1 of 4" value instead of the
  system's tab semantics. The hard-coded "of 4" and English string also skip localisation.
- **Fix:** add `.accessibilityAddTraits(.isTabBar)` to the container. Then check on device whether VoiceOver
  already announces position; if it does, drop the manual `accessibilityValue` (**unconfirmed** whether SwiftUI
  synthesises "tab, n of m" for children of an `.isTabBar` container, so verify before removing).

#### M3. The design record still describes a system tab bar and bottom accessory that the code no longer uses

- **Where:** `ios/docs/apple-design-2026.md:58-68` ("FORMA therefore keeps the four system tabs and native
  navigation bars … native tab-view bottom accessory … `.never` minimization") and `:216-231` (adopts
  `tabViewBottomAccessory(isEnabled:)` with a 26.1 guard). `native-design-review.md` also lists FORMAApp.swift as
  "stable native tab/accessory identity". Code: `FORMAApp.swift:79, 176` hide the system bar
  (`.toolbar(.hidden, for: .tabBar)`); no file calls `tabViewBottomAccessory` or `tabBarMinimizeBehavior`.
- **Why it matters:** the 28 Oct owner decision (`account-review-and-tab-bar-2026-10-28.md`) replaced it, and the
  AGENT.md 29 Oct follow-up still lists "the system tab bar" as an open product decision. Agents and reviewers who
  read the design record are told the opposite of what ships, which caused this audit to cross-check.
- **Fix:** add a dated "Superseded 28 Oct 2026" note in `apple-design-2026.md` §"Navigation and glass" and in the
  API table rows for `tabViewBottomAccessory` and `tabBarMinimizeBehavior`, pointing to the tab-bar decision doc.

#### M4. No scroll-edge effect under the custom bar

- **Where:** `TrainingTabBar.swift:194-201` uses `safeAreaInset` for the clearance; the bar itself is an overlay.
- **Apple guidance:** HIG Materials: "Scroll edge effects further enhance legibility by blurring and reducing the
  opacity of background content." `safeAreaBar` "extends the edge effect of any scroll views affected by the inset
  safe area" (iOS 26.0+). The repo already uses it for bottom bars (`GlassControls.swift:33-40`).
- **User impact:** the system bar gets a soft edge that keeps busy rows from fighting its labels; the custom bar
  gets bare content behind it (see the bleed-through in both 29 Oct screenshots).
- **Fix:** on iOS 26, give the clearance through `safeAreaBar` so the scroll view applies its edge effect to that
  band. The clear spacer is enough; the visible bar stays an overlay.

```swift
func body(content: Content) -> some View {
  let spacer = Color.clear.frame(height: navigation.barInset).accessibilityHidden(true)
  if #available(iOS 26.0, *) {
    content.safeAreaBar(edge: .bottom, spacing: 0) { spacer }
  } else {
    content.safeAreaInset(edge: .bottom, spacing: 0) { spacer }
  }
}
```

  Confirm on device that an empty bar region still produces the edge effect (**unconfirmed**); if not, place the
  real bar in `safeAreaBar` on the tab roots instead of the overlay.

#### M5. The resume control is a whole-surface button on non-interactive glass, with an off-token radius

- **Where:** `FORMAApp.swift:242` `.formaControlSurface(cornerRadius: 20)`; `GlassControls.swift:19`
  `.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))`; `FORMAApp.swift:309` `.buttonStyle(.plain)`.
- **Apple guidance:** "Add `interactive(_:)` to custom components to make them react to touch and pointer
  interactions. This applies the same responsive and fluid reactions that `glass` provides to standard buttons."
  (Applying Liquid Glass to custom views.) The repo's own rule (`apple-design-2026.md:81-82`): "Use `.interactive()`
  only for an actual custom interactive control" — this is one. `FormaTheme.swift:91-94` says 20 should map to a
  token (16 or 24).
- **User impact:** the most important shortcut while training gives only a plain-style dim on press, unlike every
  other glass control on iOS 26; its 20 pt corner sits awkwardly above the capsule tab bar.
- **Fix:** add an `interactive` parameter to `formaControlSurface` and pass it here; use `Capsule()` (matching the
  HIG accessory reference and the bar) or `FormaRadius.control`.

```swift
func formaControlSurface(cornerRadius: CGFloat = 24, interactive: Bool = false) -> some View
// iOS 26 branch:
content.glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: cornerRadius))
```

### Low

- **L1. Dark Mode surfaces never become "elevated".** `FormaTheme.swift:59-77` resolves only
  `userInterfaceStyle` and `accessibilityContrast`. HIG Dark Mode: "the background color automatically changes from
  base to elevated when an interface is in the foreground, such as a popover or modal sheet … Using a custom
  background color can make it harder for people to perceive these system-provided visual distinctions." Sheets
  (`StartWorkoutSheet`, editors) painted with `canvas` look identical to the screen beneath them in dark mode.
  Fix: add an elevated variant in `adaptive`, e.g.
  `traits.userInterfaceLevel == .elevated ? elevatedDark : darkColor` for `canvas` and `surface`.
- **L2. Landscape: the bar spans the full width with stacked labels.** `TrainingTabBar.swift:456`
  (`.frame(maxWidth: .infinity, …)`), `FORMAApp.swift:247`. Screenshot `17-today-compact-landscape.png` shows a
  capsule about 800 pt wide. HIG Tab bars: "Tab bar icons appear above tab labels in compact views, whereas in
  regular views, the icons and labels appear side by side." Fix: cap the bar width
  (`.frame(maxWidth: 480)`) and, when `verticalSizeClass == .compact`, lay each tab out as an `HStack` of symbol and label.
- **L3. `tabItem(_:)` is deprecated in the 27.2 SDK.** `FORMAApp.swift:177`. Docs list availability "iOS 13.0 –
  27.2". CI builds on 26.2, so there is no warning yet. The system bar is hidden, so the tab item is only a tag
  carrier: on iOS 18+ use `Tab(value:) { … }`, and keep `tabItem` in an iOS 17 branch.
- **L4. Default motion level is `.full`.** `FormaMotion.swift:75-77`. Any view that reads `formaMotion` outside
  `formaMotionRoot` (previews, a future UIKit host, a scene added later) plays full spatial motion even with Reduce
  Motion on. Default to `.minimal`, which the root overrides anyway.
- **L5. "Link unavailable" alert sends the person to Plan but opens Today.** `FORMAApp.swift:217-220`:
  `openWidgetTab(.today)` then "Choose a current routine in Plan." Open `.plan` instead, or say "on Today".
- **L6. Widget banner wording is system language.** `WidgetNavigationGuard.swift:15`: "Widget link queued. Finish
  editing to open it." Suggest "Save or cancel this edit to open the widget link." (names both exits; drops
  "queued").
- **L7. Re-tapping the current tab buzzes even when nothing happens.** `TrainingTabBar.swift:430-433` plays
  `.tabReturned` after `reselect`, including at the root while already at the top. HIG Playing haptics: "If a
  haptic doesn't reinforce a cause-and-effect relationship, it can be confusing and seem gratuitous." Play it only
  when `reselect` returned `.poppedToRoot`, or when the scroll actually moved.
- **L8. Tab labels: small secondary text below the HIG's custom-colour target.** `.caption2` (11 pt, the HIG
  minimum) in `secondary` is 5.75:1 on light canvas. It passes AA, but HIG Dark Mode says: "For custom foreground and
  background colors, strive for a contrast ratio of 7:1, especially in small text." Resolved for free if H2 moves
  the labels to vibrant `.secondary`.
- **L9. Entrance reveals replay when stacks are rebuilt.** `FormaMotion.swift:132-153`, used seven times on Today.
  `openWidgetTab` (`FORMAApp.swift:181-186`) assigns a new `.id`, and `.id(model.storeIdentity)` rebuilds every tab,
  so the staggered fade-and-lift plays again on each widget open or account switch. HIG Motion: "generally avoid
  adding motion to UI interactions that occur frequently." Key the "shown" state in `TrainingNavigation` per tab, or
  limit the reveal to first launch. (Frontend-design critique: per-section fade-and-slide-up is the generic default;
  one orchestrated moment lands better.)
- **L10. Spacing literals off the 4 pt token scale.** `FormaTheme.swift:102-103` asks for tokens and names 5 and 10
  as values to round, yet `TrainingTabBar.swift:413` `.padding(5)`, `:441` `VStack(spacing: 5)`, `:399` `spacing: 10`,
  `FORMAApp.swift:305` `.padding(.vertical, 10)` remain. Map them to `FormaSpacing.xxs`/`xs`/`sm`.
- **L11. Typographic inconsistency in shell copy.** Straight apostrophes in `FORMAApp.swift:127` ("couldn't") and
  `:336` next to curly ones in model copy ("You’re", `AppModel+Account.swift:204`). Pick curly throughout.

---

## 3. What is already correct

- **Availability discipline.** Every iOS 18 (`onScrollGeometryChange`, `.rotate`, `.wiggle`) and iOS 26
  (`glassEffect`, `GlassEffectContainer`, `safeAreaBar`) call is guarded with a sensible fallback; nothing needs
  iOS 27 (matches CI's 26.2 SDK rule).
- **Glass layering.** The control/content split matches HIG Materials ("Don't use Liquid Glass in the content
  layer"); the resume control and bar share one `GlassEffectContainer` with spacing (2) below the gap (4), exactly
  as Apple's container guidance requires to avoid merging at rest.
- **Opaque fallback.** Reduce Transparency and Increase Contrast swap to `surface` with a 3:1+ `fieldBorder` edge
  (3.73–5.85:1 measured) in both the bar and `ControlSurface`.
- **Colour tokens.** Four variants per token built once (no per-resolve allocation); measured: secondary 5.75 / 9.65,
  accent 6.23 / 14.89, error 6.06 / 10.38 against canvas; the lime button's olive edge makes its boundary visible
  in light mode, with ink-on-lime text. Shared with widgets through `BrandPalette`.
- **Motion system.** One resolved level at the root; System Reduce Motion and Prefer Cross-Fade always win;
  minimal degrades every token to a 160 ms fade; Off removes FORMA's own motion only. Feature views read
  `\.formaMotion`, never `accessibilityReduceMotion` (rule respected throughout this slice). Symbol effects are
  `.nonRepeating` and removed below full motion; the tab highlight fades instead of sliding at minimal.
- **Haptics plumbing.** One relay leaf observes the event, gated by You › Haptics (HIG "Make haptics optional");
  each case maps to one documented pattern with a meaning table; `CompletionSeal` fires `.success` only after the
  saved receipt exists.
- **Dynamic Type.** Tab labels keep showing up to AX1 and provide the Large Content Viewer; the bar never
  collapses at accessibility sizes or under VoiceOver; resume name unwraps at AX sizes; `SectionHeading` and
  `AdaptiveMetricGroup` reflow with `ViewThatFits`; display font scales `relativeTo:`; `@ScaledMetric` seal.
- **Tap targets.** All controls in the slice meet or exceed 44 pt (tabs 56/62, resume 56, primary 56/44, banner
  close 44x44 with `contentShape`).
- **Navigation.** Value-typed per-tab paths; re-tap pops to root then scrolls to top like the system; account
  switches reset every stack so another member's screens never linger; widget links never bypass an open
  workout's Save & close guard and are announced to VoiceOver when queued.
- **Shell states.** Loading continues the launch colour (no white flash); load failure uses
  `ContentUnavailableView` with a direct "Try again"; account interruptions use the `presenting:` alert with a
  clear sign-in action.
- **Labels.** Resume control ("Resume <name>" with hint), collapsed control ("Show all tabs", value "<tab>
  selected"), banner dismiss, decorative marks hidden from VoiceOver.

---

## 4. Decided items: not re-reported as defects, Apple text recorded for the owner

These are owner decisions on record (AGENT.md 28–30 Oct). Listed only so the evidence sits in one place.

- **Custom tab bar instead of the system bar** (`account-review-and-tab-bar-2026-10-28.md`). What it costs per the
  current HIG Tab bars page: the system bar's landscape side-by-side layout (L2), keyboard behaviour (H1), monochrome
  adaptive labels (H2), scroll-edge effect (M4), the native minimised state and `tabViewBottomAccessory`
  (`apple-design-2026.md` had chosen `.never` minimisation for predictable access while training; the custom bar
  collapses after 32 pt of scroll).
- **Firm impact on every tab change** (`FormaHaptics.swift:67`, 30 Oct). HIG Playing haptics: "Avoid overusing
  haptics. Sometimes a haptic can feel just right when it happens occasionally, but become tiresome when it plays
  frequently." Impact patterns are documented for collisions ("a tap when a view snaps into place"); the system tab
  bar plays none.
- **Per-tab symbol effects and a 420 ms / 0.28-bounce highlight spring** (`FormaMotion.swift:66`,
  `TrainingTabBar.swift:282-369`). HIG Motion: "In apps, generally avoid adding motion to UI interactions that occur
  frequently." The pro-rules checklist targets 150–300 ms; the Progress chart sweep runs about 0.74 s.
- **In-app Light/Dark override** (`FORMAApp.swift:160-162`). HIG Dark Mode: "Avoid offering an app-specific
  appearance setting." Already recorded as a deliberate choice in `apple-design-2026.md:137-140`.

---

## 5. Device checks this review cannot settle

1. Current build, Exercise library search and Change password: does the bar sit above the keyboard (H1)?
2. Light mode, Today hero scrolled under the bar: label contrast on the glass (H2), with and without M4.
3. VoiceOver on the bar after adding `.isTabBar`: is position announced twice (M2)?
4. iPhone landscape: bar width and label layout (L2).
5. Dark mode sheet over Today: is the sheet distinguishable from the base screen (L1)?

---

## Resolution

Fixed on branch `fix/audit-shell` (2 November 2026), from audited commit `ba4e6a7`. Each
finding was re-checked against the code first; every one still applied. No simulator was
used; the app and its test targets were compiled with `xcodebuild build-for-testing` for
`generic/platform=iOS` (TEST BUILD SUCCEEDED). The changed files add no warnings; the one Swift
warning in the log is the existing Sendable capture in `TabSymbol` (`TrainingTabBar.swift:387`,
moved from 355 by the added lines). The new unit tests compiled but were not run, since that
needs the iPhone. `docs:check` reports only the media files left out of this sparse checkout.

| ID | Result | What changed |
|---|---|---|
| H1 | Fixed; needs device check | `TrainingNavigation.keyboardVisible` follows the keyboard's will-show and will-hide notifications. While it is up the bar and resume control leave (a fade and slide, a fade at Minimal, nothing when Off) and `bottomClearance` drops to 0, so no tab screen keeps room for a hidden bar. The bar ignores the keyboard safe area, so it leaves from its own place instead of jumping above the keys. Device step: Exercise library search and Change password; the bar should be gone while typing and back when the keyboard closes. |
| H2 | Fixed; needs device check | On glass, tab labels and the resume control use the hierarchical `.primary` / `.secondary` styles (`formaControlForeground`, `ControlForeground`), which follow the material. The selected tab keeps its accent capsule (opacity 0.12 to 0.16, so it still reads with a neutral label) and its filled symbol and bold label. FORMA's own colours stay on the opaque Reduce Transparency / Increase Contrast surface, where the backdrop is known. Device step: light mode, Today's hero panel scrolled under the bar; check the 4.5:1 floor on the labels. |
| M1 | Fixed | `AppModel.reportFailure(_:_:)` gives a failure its own alert title: "Couldn’t delete your training", "Couldn’t save this setting", "Couldn’t remove the account’s training". A title belongs only to the message it was reported with, so a later failure that replaces the message falls back to "Couldn’t save this change". The button is "OK" in every case. System error text is no longer added: `failureMessage` keeps only FORMA's own wording (`AppFailure`, `FormaError`). The four messages in `AppModel.swift` and `AppModel+Account.swift` are rewritten to say what is still true and where to go. `YouView.swift:110, 171` still add `localizedDescription`; that file belongs to the Progress/You slice. |
| M2 | Fixed; needs device check | The bar has `.isTabBar` (not when it is collapsed to one control). The hand-written "Tab n of 4" value is removed. Device step: VoiceOver on the bar; check that each tab announces its position once. If none is announced, put the value back. |
| M3 | Fixed | Dated "Superseded 28 October 2026" notes in `apple-design-2026.md` (the navigation section, the accessory paragraphs and the `tabViewBottomAccessory` / `tabBarMinimizeBehavior` rows and the file table) and in `native-design-review.md`, pointing to the tab-bar decision and this report. |
| M4 | Fixed; needs device check | On iOS 26 the clearance is a `safeAreaBar`, so scroll views apply their edge effect under the bar; `safeAreaInset` below 26. Device step: confirm the soft edge appears under an empty bar region; if not, move the real bar into the `safeAreaBar`. |
| M5 | Fixed | `formaControlSurface` takes a shape (`.capsule` or `.rounded`) and `interactive:`. The resume control is a capsule with `.regular.interactive()` glass, and its tap area is the capsule. The tab bar uses the same modifier (non-interactive). |
| L1 | Fixed; needs device check | `canvas` and `surface` have elevated Dark Mode variants (#1E2420, #29312B), used when `userInterfaceLevel == .elevated`. Text and boundary contrast on them is unit-tested. Device step: a dark sheet over Today. |
| L2 | Fixed; needs device check | The bar is capped at 480 pt. In a compact vertical size class each tab lays out symbol and label side by side, and the bar is 60 pt tall (48 pt tabs). Device step: iPhone landscape. |
| L3 | Fixed | A small `TrainingTabs` view builds the four tabs: `Tab(_:systemImage:value:)` on iOS 18 and later, `tabItem` and `tag` only on iOS 17. `RootView`'s modifier chain is unchanged. |
| L4 | Fixed | The motion environment default is `.minimal`; `formaMotionRoot` sets the real level. |
| L5 | Fixed | "Link unavailable" now opens Plan, where the notice sends the person. |
| L6 | Fixed | The widget banner reads "Save or cancel this edit to open the widget link." The workout's own banner (`WorkoutView.swift:195`) belongs to the workout slice. |
| L7 | Fixed | Each tab root reports whether it is at its top (iOS 18 scroll geometry). A re-tap at the root while already at the top returns `.alreadyAtTop` and plays no haptic; popping or scrolling still does. |
| L8 | Fixed | Covered by H2: the labels are vibrant on glass. |
| L9 | Fixed | `FormaRevealLedger` on `TrainingNavigation` records each reveal by call site, so a stack rebuilt by a widget link or an account switch shows the content at once instead of staggering in again. The receipt has no ledger, so its reveal plays for every new result. |
| L10 | Fixed | The bar's and the resume control's 5 and 10 pt literals are `FormaSpacing` tokens. |
| L11 | Fixed | The shell's alert and failure copy uses curly apostrophes. |

**Tests.** `ios/FORMAAppTests/TrainingNavigationTests.swift`: a re-tap at the top does
nothing, and the keyboard releases the bar's clearance. `FormaDesignSystemTests.swift`:
elevated Dark Mode backgrounds, the opaque-surface rule, and the reveal ledger. New
`RootFailureTests.swift`: system wording is left out, FORMA's own wording is kept, and a
reported title belongs only to its message. UI tests keep their identifiers. UI tests that
type and then tap a tab would now need the keyboard dismissed first; none in the suite does.

**Files changed.**
- `ios/FORMA/App/FORMAApp.swift`
- `ios/FORMA/App/AppModel.swift`, `ios/FORMA/App/AppModel+Account.swift` (the four messages)
- `ios/FORMA/DesignSystem/TrainingTabBar.swift`, `GlassControls.swift`, `FormaTheme.swift`,
  `FormaMotion.swift`, `WidgetNavigationGuard.swift`
- `ios/FORMAAppTests/TrainingNavigationTests.swift`, `FormaDesignSystemTests.swift`,
  `RootFailureTests.swift` (new)
- `ios/docs/apple-design-2026.md`, `ios/docs/native-design-review.md`, this report

**Merge notes.** `FORMAApp.swift` `handleWidgetRoute` (`.unavailable`, L5) sits next to
the widgets slice's Live Activity route. M1 edits `AppModel.swift` (the save, delete and
preference failures) and `AppModel+Account.swift` (sign-out clean-up), which other slices may
also touch.
