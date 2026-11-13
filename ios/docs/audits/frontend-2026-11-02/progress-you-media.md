# iOS front-end audit: Progress, You and exercise media

2 November 2026. Branch `feat/watch-collected-data`, worktree
`repository root`. Read-only static
review. Nothing in the repo was edited.

**Read in full:** `ios/FORMA/Features/ProgressView.swift` (400 lines), `YouView.swift` (457),
`ExerciseMedia.swift` (550), `WatchSummaryCard.swift` (99).

**Design-system types read:** `FormaTheme.swift`, `FormaMotion.swift`,
`FormaComponents.swift`, `FormaHaptics.swift`, `AdaptiveMetricGroup` (in
`GlassControls.swift`), `BrandPalette.swift`, `WatchTotals` (`WatchSummary.swift`),
`WorkoutEngine.volume`, `TrainingDate.label`, `countPhrase`, `GuideView` (the host
`List` for the media sections).

**Repo notes read so I don't re-report settled items:** `forma-workout-planner/CLAUDE.md`
"Native iOS and watchOS", `ios/docs/apple-design-2026.md`,
`native-design-review.md` and `full-audit-2026-10-26.md`.

**Method.**
- Skills loaded: frontend-design (critique lens) and ui-ux-pro-max. The searches run were
  `--stack swiftui`, `--domain ux`, `--domain chart` and the pro-rules Pre-Delivery
  Checklist.
- Apple sources were fetched on 2 November 2026 as `.md` from developer.apple.com and
  quoted below.
- Contrast ratios were computed with the WCAG 2.x formula from the hex tokens in
  `FormaTheme`/`BrandPalette`, including the alpha blends the code actually draws.
- Media facts were measured on the bundled files with `sips`, `ffprobe` and `media.json`.

**Limits.**
- No simulator or device was used, so nothing here was rendered, spoken by VoiceOver or
  profiled.
- Findings marked **(device check)** depend on runtime behaviour that the source alone
  cannot settle.

---

## 1. HIG pass/fail checklist for this slice

| Area | Result | Note |
|---|---|---|
| Charts: zero-based bar axis, units, title, overview | **Pass** | `chartYScale(domain: 0...)`, "kg × reps" unit, `SectionHeading` and a readout summary. |
| Charts: interaction is never required for critical information | **Pass** | The readout defaults to the latest workout, and "Read chart values" lists every bar. |
| Charts: Audio Graphs and the VoiceOver overview | **Fail (device check)** | The x-axis plots session UUIDs. There is no `accessibilityChartDescriptor`, and the average line is hidden from VoiceOver (H2). |
| Charts: colour and contrast of marks | **Fail** | Unfocused bars are 1.39–2.01:1 in light mode (H1). |
| Media playback: autoplay | **Partial** | The demo clip is tap-to-play. The animated demonstration autoplays and does not read Auto-Play Video Previews (M1). |
| Media playback: Reduce Motion | **Pass** | The animation starts on its still pose unless `formaMotion == .full`, and Pause/Play is always shown. |
| Media: captions and alt text | **Pass / Low** | The demo clips have no audio track (verified with `ffprobe`), so captions are not needed. Illustration labels are redundant (L3). |
| Image decoding and performance | **Partial** | `MediaDecoder` is sound. The demo poster still decodes synchronously in `body` (M2). |
| Settings patterns (Form, Toggle, Picker, Stepper) | **Partial** | Native `Form`, toggles and menu pickers. The rest stepper spans 118 steps (M9). A footer sends people to Settings without a link (M6). |
| Typography and Dynamic Type | **Pass / Low** | Text styles, `relativeTo:` custom font, `ViewThatFits`, `AdaptiveMetricGroup`. Rounded numerals break the house rule (L1). Chart height is unbounded at accessibility sizes (L9). |
| Contrast, light and dark (text) | **Pass** | Secondary text is 5.75–6.24:1 (light) and 8.37–9.65:1 (dark). Accent text is 6.23:1 or better. The change capsule is 5.50:1 or better. |
| Tap targets | **Pass** | Journal rows are full width, Play is 64 pt, and Pause has `minHeight: 44`. List-row tap ambiguity is a separate issue (M3). |
| VoiceOver structure | **Partial** | Good combined labels and spoken units on the Watch card. Headings are missing in workout details (M7). Bullets are read on their own (L4). |
| Reduce Motion | **Partial** | Everything except the readout's `numericText` goes through `FormaMotion` (M4). |
| Reduce Transparency | **N/A** | There is no glass or material in this slice. All surfaces are opaque tokens. |
| Copy and wording | **Partial** | The empty state has no action (M5). Footers are long and the haptics list is incomplete (M6). Headers are slogans (L5). |
| Empty states | **Partial** | `ContentUnavailableView` on Progress and on a removed workout, but there is no next-step button (M5). |
| Deprecated APIs | **Pass** | None found. The code uses the iOS 17 `onChange(of:) { _, new in }` form, `ContentUnavailableView`, `chartXSelection` (iOS 17) and `foregroundStyle`. There are no Liquid Glass calls in this slice, so no `#available` gating is needed. |

ui-ux-pro-max Pre-Delivery Checklist, applied statically:
- Touch targets ≥44 pt: pass.
- Colour is not the only indicator: pass. The change capsule has an arrow and text.
- Meaningful images labelled: pass.
- Reduced motion and dynamic type without layout breakage: partial (M4, L9).
- Secondary text ≥3:1 in both modes: pass.
- Semantic tokens with no ad-hoc hex: pass, except `Color.white`/`Color.black` on media
  frames, which is intentional.
- 4/8 spacing rhythm: minor drift (L2).
- Native pressed feedback: pass.
- Gesture conflicts: device check (M3, H2 notes).

---

## 2. Findings

### High

#### H1. Unfocused volume bars fail non-text contrast, worst while scrubbing and in light mode

`ios/FORMA/Features/ProgressView.swift:298-306`

```swift
private func barStyle(focused: Bool) -> AnyShapeStyle {
  if focused { … }
  return AnyShapeStyle(FormaTheme.accent.opacity(selectedID == nil ? 0.38 : 0.22))
}
```

Measured against `FormaTheme.surface`, which the chart card draws on:

| Appearance | Bars at 0.38 (resting) | Bars at 0.22 (while touched) |
|---|---|---|
| Light | **1.81:1** | **1.39:1** |
| Light + Increase Contrast | **2.01:1** | **1.46:1** |
| Dark | 3.11:1 | **1.92:1** |

Every bar except one is a data mark carrying a real volume, so each is a graphical object
that people need in order to read the chart.

- **Apple guidance.** HIG Accessibility, "Strive to meet color contrast minimum
  standards… If your app doesn't provide this minimum contrast by default, ensure it at
  least provides a higher contrast color scheme when the system setting Increase Contrast
  is turned on." The Increase Contrast variant here still fails.
  https://developer.apple.com/design/human-interface-guidelines/accessibility.
- **HIG Charts.** "Avoid relying solely on color to differentiate between different
  pieces of data or communicate essential information in a chart."
  https://developer.apple.com/design/human-interface-guidelines/charts.
- **Repo rule.** The repo's own token comment requires ≥3:1 for any stroke that carries
  meaning (`FormaTheme.boundary`, WCAG 1.4.11).
- **User impact.** In light mode, seven of eight bars are barely visible: in sunlight, in
  a gym, or for low-vision users. While scrubbing, every bar except the touched one almost
  disappears.
- **Fix.** Keep every bar at ≥3:1 and mark focus with something other than lightness:

```swift
private func barStyle(focused: Bool) -> AnyShapeStyle {
  focused ? AnyShapeStyle(FormaTheme.accent)            // 6.8:1 / 12.9:1
          : AnyShapeStyle(FormaTheme.boundary)          // 4.05:1 light, 5.07:1 dark
}
// …and give the focused bar a non-colour cue:
.annotation(position: .top) {
  if bar.id == focusID { Image(systemName: "arrowtriangle.down.fill").font(.caption2)
      .foregroundStyle(FormaTheme.accent).accessibilityHidden(true) }
}
```

- **Opacity floors if the accent fill must stay.** The minimum opacities for 3:1 are 0.66
  in light, 0.58 with Increase Contrast and 0.38 in dark. At those floors the focused bar
  is only 2.17:1 against the others in light, so the arrow or outline cue is still needed.

#### H2. The chart's Audio Graph and VoiceOver overview are built on session UUIDs, the chart-level label replaces the descriptor route, and the average is invisible to VoiceOver (device check)

`ProgressView.swift:251-259, 262-269, 171-174`

```swift
BarMark(x: .value("Session", bar.id), …)               // bar.id is UUID().uuidString (Models.swift:415)
…
RuleMark(y: .value("Average", average)) … .accessibilityHidden(true)
…
.accessibilityLabel("Lifting volume over your latest …")
.accessibilityValue(Self.summary(bars, peak: peak))   // latest + highest only
```

**What Apple says:**
- HIG Charts: "When you use Swift Charts to create a chart, you get a default
  implementation of Audio Graphs." It also says "Consider using Audio Graphs… by
  supplying a chart title and descriptive summary." And: "If you don't use Audio Graphs,
  you need to provide an overview… identify the chart's type… explain what each axis
  represents, and describe details like the upper and lower axis bounds."
  https://developer.apple.com/design/human-interface-guidelines/charts.
- The API for the descriptor route is `accessibilityChartDescriptor(_:)`.
  https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:).

**What goes wrong:**
- The per-bar `.accessibilityLabel(Text(bar.title))` fixes per-element VoiceOver.
- The automatically generated Audio Graph is derived from the plotted values. Its
  categorical x-axis is named "Session", and its categories are almost certainly the
  36-character UUIDs. This is **unconfirmed**: Apple does not document exactly which
  strings the automatic descriptor uses, so check it on a device with VoiceOver, Chart
  Details and Audio Graph.
- The chart-level summary states neither the chart type, nor the y-axis range, nor the
  average that sighted users see as a labelled dashed line ("Avg 4.2K").

**User impact.** VoiceOver users exploring the Audio Graph may hear identifiers instead of
dates, and they never get the average that sighted users read at a glance.

**Fix.** Supply an explicit descriptor and keep the per-mark labels:

```swift
struct VolumeChartDescriptor: AXChartDescriptorRepresentable {
  let bars: [Bar]; let average: Double; let peak: Double
  func makeChartDescriptor() -> AXChartDescriptor {
    let x = AXCategoricalDataAxisDescriptor(title: "Workout", categoryOrder: bars.map(\.title))
    let y = AXNumericDataAxisDescriptor(title: "Lifting volume, kilogram repetitions",
      range: 0...max(1, peak), gridlinePositions: []) { "\(Int($0)) kilogram repetitions" }
    let series = AXDataSeriesDescriptor(name: "Lifting volume", isContinuous: false,
      dataPoints: bars.map { .init(x: $0.title, y: $0.volume) })
    return AXChartDescriptor(title: "Lifting volume, last \(bars.count) workouts",
      summary: "Bar chart. Average \(Int(average)). Highest \(Int(peak)).",
      xAxis: x, yAxis: y, additionalAxes: [], series: [series])
  }
}
// chart(bars, peak:) … .accessibilityChartDescriptor(VolumeChartDescriptor(…))
```

Also add the average to `summary(_:peak:)`.

The repo already decided to "preserve" Audio Graphs (`apple-design-2026.md` §Charts).
This finding is new evidence that the default Audio Graph is fed IDs, not a re-litigation
of that decision.

### Medium

#### M1. The animated demonstration autoplays without consulting Auto-Play Video Previews

`ExerciseMedia.swift:343-345, 350-351`

```swift
@State private var playing: Bool?
private var isPlaying: Bool { playing ?? motion.allowsSpatialMotion }
…
if isPlaying, let url = … { LoopingVideo(url: url) }
```

- **Apple guidance.** HIG Accessibility, "Let people control audio and video playback.
  Avoid autoplaying audio and video content without also providing controls… and consider
  global settings that let people opt out of auto-playing all audio and video." The page
  links `UIAccessibility.isVideoAutoplayEnabled`.
  https://developer.apple.com/design/human-interface-guidelines/accessibility.
  https://developer.apple.com/documentation/uikit/uiaccessibility/isvideoautoplayenabled
  (iOS 13+, "whether the Auto-Play Video Previews setting is in an enabled state").
- **User impact.** Someone who turned off Auto-Play Video Previews, but not Reduce Motion,
  still gets a looping video on every guide they open.
- **Fix.** Fold the setting into the default, ideally once in `FormaMotionRoot` as
  another published flag, so feature views keep obeying the "never read accessibility
  settings in a feature view" rule. Refresh it on
  `UIAccessibility.videoAutoplayStatusDidChangeNotification`:

```swift
private var isPlaying: Bool { playing ?? (motion.allowsSpatialMotion && autoplayVideo) }
```

#### M2. The demo poster is decoded synchronously on the main thread during `body`

`ExerciseMedia.swift:294-300`

```swift
if let url = ExerciseMediaLibrary.url(clipID, "jpg", in: "demos"),
  let image = UIImage(contentsOfFile: url.path)
{ Image(uiImage: image).resizable().scaledToFill() … }
```

- **What goes wrong.**
  - This runs on every `body` evaluation and leaves the JPEG undecoded until draw time.
  - The file's own `MediaDecoder` comment (lines 99-104) records that exactly this
    pattern ("decode to the main thread at draw time") hung the app on the CI simulator.
  - The posters are 6–39 KB JPEGs, so the risk is a dropped frame rather than a hang. It
    is still a needless main-thread decode on scroll.
- **Apple guidance.** Not separately confirmed against an Apple page. The rationale is the
  repo's own documented failure.
- **Fix.** Load it the same way as the other bundled pictures:

```swift
@State private var posterImage: UIImage?
… if let posterImage { Image(uiImage: posterImage).resizable().scaledToFill() }
.task(id: clipID) {
  guard let url = ExerciseMediaLibrary.url(clipID, "jpg", in: "demos") else { return }
  posterImage = await MediaDecoder.shared.decode(url)
}
```

#### M3. Several tappable controls share one `List` row in the exercise guide (device check)

`ExerciseMedia.swift:259-292, 302-321, 362-373`. The rows are hosted in `GuideView`'s
`List` (`PlanView.swift:948-962`).

- **What is in the rows.**
  - The demo-clip row holds a `.plain` play `Button`, a `VideoPlayer`, a
    `Link(source.license)` and a `Link("Original video")`, all with default style.
  - The animation row holds the video and a default-style Pause/Play `Button`.
- **What goes wrong.** In a `List`, a default-style button or link makes the whole row
  its hit area, and a row with several of them can fire the wrong one or both. This is
  long-standing SwiftUI behaviour, but Apple does not document it, so treat it as
  **unconfirmed**.
- **User impact.**
  - Tapping the poster just outside the round Play button, or the caption, may open the
    licence page in Safari.
  - Tapping the animation itself toggles playback and grey-highlights the whole row.
- **Apple guidance.** HIG Charts: "Make it easy for everyone to interact with a chart."
  More generally, one primary gesture per region is the ui-ux-pro-max rule "Gesture
  conflict prevention".
- **Fix.** Add `.buttonStyle(.borderless)` to each `Link` and to the Pause/Play `Button`,
  so that only their own frames are tappable. Alternatively, move the credit links into
  their own `Section` row.

#### M4. The chart readout's digit roll bypasses `FormaMotion`

`ProgressView.swift:208-210`

```swift
Text(focus.volume.formatted(…))
  .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
  .contentTransition(.numericText(value: focus.volume))
```

- **The house pattern.** `MetricValue` (lines 100, 106-112) maps the transition by level:
  `.numericText()` at full, `.opacity` at minimal, `.identity` when motion is off.
- **What goes wrong.**
  - The readout always asks for `.numericText`, and `.formaAnimation` at `.minimal` still
    supplies an animation (`FormaMotion.fade`). The rolling digits therefore play for
    people on Minimal or Reduce Motion as they scrub.
  - Apple only says the transition is "nonstandard… tailored to numeric characters that
    count up or down" "in certain environments". Whether it degrades on its own under
    Reduce Motion is **unconfirmed**.
  - https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(countsdown:).
- **Rules violated.**
  - HIG Accessibility: "ensure your app… responds by reducing automatic and repetitive
    animations."
  - The repo rule "All motion goes through FormaMotion".
- **Fix.** Expose `MetricValue.transition(for:)` as an internal helper and use
  `.contentTransition(motion == .full ? .numericText(value: focus.volume) : motion == .minimal ? .opacity : .identity)`.

#### M5. The Progress empty state has no way forward

`ProgressView.swift:14-21`

```swift
ContentUnavailableView {
  Label("Every first set counts.", systemImage: "chart.xyaxis.line")
} description: { Text("Finish your first workout to see your history…") }
```

- **Apple guidance.** HIG Writing: "Provide clear next steps on any blank screens… guide
  people on actions they can take, and give them a button or link to do so if possible."
  https://developer.apple.com/design/human-interface-guidelines/writing.
- **User impact.** A new user lands on a motivational slogan with nothing to tap. The
  title also names a mood rather than the state.
- **Fix.** Use the `actions:` slot of `ContentUnavailableView` (iOS 17), keeping the
  slogan as the description if wanted:

```swift
ContentUnavailableView {
  Label("No workouts yet", systemImage: "chart.xyaxis.line")
} description: {
  Text("Finish a workout to see your history, completed sets and lifting volume.")
} actions: {
  Button("Start a workout") { navigation.select(.today) }.buttonStyle(.formaPrimaryCompact)
}
```

#### M6. You-tab footers: too long, one is incomplete, and one points at Settings without a link

`YouView.swift:63-70, 98-101`

- **Length.** The Motion footer is 46 words and the Haptics footer is 63 words. They are
  the longest text on the screen, under two short controls.
- **Accuracy.** The Haptics footer lists saved set, end of rest, finished workout,
  warnings and errors. But `FormaHaptic` (`FormaHaptics.swift:28-58`) also plays on:
  - every tab change (`tabChanged`, solid impact 0.85),
  - tab re-tap,
  - chart bar selection (`ProgressView.swift:168-170`),
  - steppers,
  - set added or undone,
  - account events.

  So the footer under-describes what the switch controls.
- **Live Activities footer.** "You can also turn Live Activities off for FORMA in
  Settings." gives no link.
- **Apple guidance.** HIG Writing:
  - "Keep settings labels clear and simple… Describe what it does when turned on, and
    people can infer the opposite."
  - "If you need to direct someone to a setting, provide a direct link or button, rather
    than trying to describe its location."

  Also "Be clear… If you can use fewer words, do so."
  https://developer.apple.com/design/human-interface-guidelines/writing.
- **User impact.** People skim past the explanation, believe some haptics (tab changes)
  are not covered, and have to hunt through Settings by hand.
- **Fix.**
  - Haptics: "Taps and pulses that confirm saves, rest, selections and errors. Your
    device's haptic settings still apply."
  - Motion: "System follows Reduce Motion. Minimal uses short fades. Off shows changes
    instantly."
  - Add
    `Button("Open FORMA in Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }`
    under the Live Activity toggle. `openSettingsURLString` is a UIKit API that was not
    re-fetched for this audit.

#### M7. Workout details have no VoiceOver headings for exercises or notes

`ProgressView.swift:374, 389`

```swift
Text(exercise?.name ?? entry.exerciseId).font(.headline)
…
Text("Session notes").font(.headline)
```

- **What goes wrong.** Only the `EditorialTitle` carries `.isHeader`. A long workout is a
  flat run of "Set 1 … Set 2 …" elements. VoiceOver users cannot use the Headings rotor
  to jump between exercises, which sighted users scan by the bold headline.
- **Apple guidance.** HIG Accessibility asks for VoiceOver support of all content
  (https://developer.apple.com/design/human-interface-guidelines/accessibility). The
  specific "use the header trait" guidance was not re-fetched, so it is
  **unconfirmed as a quote**.
- **Repo consistency.** The same file already uses `.accessibilityAddTraits(.isHeader)`
  in `SectionHeading` and `EditorialTitle`.
- **Fix.** Add `.accessibilityAddTraits(.isHeader)` to both texts.
  - Exercises that have no completed sets currently show a heading with nothing under it
    (see L13). Skip them with
    `if entry.sets.contains(where: \.done)`, or add a line such as "No completed sets".

#### M8. The Watch totals card shows "0 Active kcal" when no energy was recorded, and speaks abbreviations

`WatchSummaryCard.swift:92-93`, `WatchSummary.swift:68, 81`

```swift
MetricValue(value: totals.activeEnergyKcal.formatted(), label: "Active kcal")   // Int, 0 when every reading was nil
```

- **What goes wrong.**
  - `WatchTotals.activeEnergyKcal` is a non-optional `Int` that sums `?? 0`, so a Watch
    with no energy samples shows **0 kcal**.
  - That contradicts the card's own contract (`WatchSummaryCard.swift:5`: "Missing
    readings are left out, never shown as zero") and the conditional handling of heart
    rate two lines above.
  - `MetricValue` combines to "312, Average bpm" and "0, Active kcal". The neighbouring
    `WatchValue` deliberately speaks "beats per minute" and "kilocalories".
- **User impact.** People read a false zero. VoiceOver speaks "B P M" and "K cal".
- **Apple guidance.** HIG Charts, on data descriptions: "it's rarely enough to merely
  report a data value unless you also include context". The same principle applies to
  metric summaries. https://developer.apple.com/design/human-interface-guidelines/charts.
- **Fix.**
  - Make `activeEnergyKcal` an `Int?`, set to nil when no workout had a reading, and wrap
    the metric in `if let`.
  - Add a `spoken:` override to `MetricValue`
    (`.accessibilityLabel(label).accessibilityValue(spoken ?? value)`), passing "beats per
    minute" and "kilocalories".

#### M9. The default-rest stepper covers 10–600 s in 5 s steps

`YouView.swift:273`

```swift
Stepper("Default rest: \(rest) seconds", value: $rest, in: 10...600, step: 5)
```

- **What goes wrong.** Going from the default 90 s to 5 min takes 42 taps, and the full
  range is 118. The label also reads "Default rest: 600 seconds" rather than "10 min".
- **Apple guidance.** HIG Steppers: "Steppers work well by themselves for making small
  changes that require a few taps… Consider pairing a stepper with a text field when large
  value changes are likely."
  https://developer.apple.com/design/human-interface-guidelines/steppers.
- **Fix.** Either replace it with a menu `Picker` of common rests (30, 45, 60, 90, 120,
  180, 240 and 300 s), or keep the stepper with a non-linear step. Format the value with
  `Duration.seconds(rest).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))`.

### Low

#### L1. Rounded numerals break the house numeral rule

`ProgressView.swift:95, 209`. `FormaFont.numeral` (`FormaTheme.swift:114-121`) says
"Rounded and monospaced designs are not used for numerals". Yet `MetricValue` and the
chart readout both use `.system(.largeTitle, design: .rounded, weight: .bold)`.

- **Effect.** The Progress numerals look different from Today and Workout.
- **Fix.** Use `FormaFont.numeral(.largeTitle)`.

#### L2. The chart card uses retired radius and padding values

`ProgressView.swift:197` uses
`.padding(20).background(FormaTheme.surface, in: RoundedRectangle(cornerRadius: 20))`.

- `FormaRadius` says "older 10, 14 and 20 values should map to the nearest token". Use
  `FormaRadius.card` (18) and `FormaSpacing.lg`.
- The `WatchSummaryCard` directly below on the detail screen already uses the tokens, so
  the two cards' corners differ.

#### L3. Illustration accessibility labels repeat themselves

`ExerciseMedia.swift:226-231`. The label is
`"Exercise illustration for \(name): \(illustration.title)"`.

- **Measured redundancy.**
  - In 1,192 of 1,411 entries the title equals the exercise name: "Exercise illustration
    for Ab Roller: Ab Roller".
  - In 1,288 entries the visible caption starts with the title again.
- **Apple guidance.** HIG Charts on labels: "Aim to concisely describe the context… without
  repeating information that people can get in other ways."
- **Fix.** Drop `illustration.title` when it equals `name` (case-insensitive). The
  caption is already read as separate text.

#### L4. Privacy notice bullets are separate VoiceOver stops

`YouView.swift:413-418`. `HStack { Text("•"); Text(item) }` makes VoiceOver stop on
"bullet" and then on the item.

- **Fix.** Hide the bullet with `.accessibilityHidden(true)`, or set
  `.accessibilityElement(children: .combine)` on the `HStack`.

#### L5. Settings section headers are slogans and possessives

The headers are "Make it yours", "Feel at home", "Training at a glance", "Yours to keep.
Yours to control.", "Your training journal" and "Your pace.\nYour space.".

- **Apple guidance.** HIG Writing: "Use possessive pronouns sparingly", and "Keep settings
  labels clear and simple… labeling them as practically as possible."
- **Effect.** Scanning a settings form by header becomes guesswork.
- **Fix.** Keep the editorial title as the one brand moment, and use plain headers:
  "Profile", "Appearance & feedback", "Widgets", "Your data" and "Training journal".

#### L6. Read-only "settings" rows show a raw identifier

`YouView.swift:48-49` shows `LabeledContent("Training dates", value: "Australia/Sydney")`.

- **Effect.** The value is an IANA identifier, not a human name, and the row looks like a
  tappable setting but is fixed.
- **Fix.** Use
  `TimeZone(identifier: "Australia/Sydney")?.localizedName(for: .generic, locale: .current)`
  ("Sydney Time" or "Australian Eastern Time"), and add a footer saying the setting cannot
  be changed.

#### L7. Missing duration shows "0 min"

`ProgressView.swift:71, 366` use `Int((session.duration ?? 0) / 60)`.

- **Effect.** A nil or sub-minute duration renders "0 min" or "0 Minutes".
- **Fix.** Omit the value when nil, matching the Watch card's rule, and show "<1 min"
  under 60 s.

#### L8. The animation caption uses an abbreviated unit

`ExerciseMedia.swift:363` reads `"… · \(animation.seconds.formatted()) s loop"`.

- **Effect.** VoiceOver reads "4.3 s loop".
- **Fix.** Use
  `Duration.milliseconds(Int(animation.seconds * 1000)).formatted(.units(allowed: [.seconds], width: .abbreviated, fractionalPart: .show(length: 1)))`
  for the visible text, plus a `.wide` accessibility label.

#### L9. Chart height grows without a limit at accessibility sizes

`ProgressView.swift:120` declares `@ScaledMetric(relativeTo: .body) var chartHeight = 200`.

- **Effect.** At AX5 the chart is roughly 600 pt and pushes the values list off screen.
  Bars carry no text, so they do not need to scale with text.
- **Fix.** `.frame(height: min(chartHeight, 320))`, or scale relative to `.caption2`
  (device check for the exact cap).

#### L10. Demo playback sets an app-wide audio category for silent clips

`ExerciseMedia.swift:328`

```swift
try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
```

- **What goes wrong.**
  - `ffprobe` finds **no audio stream in any bundled demo clip**, so the call has no
    benefit.
  - It changes the process-wide category, which is never restored, on the main thread.
- **Fix.** Delete the call. `isMuted = true` on a track-less asset will not interrupt
  other audio. If audio-bearing clips are added later, set `.playback` while playing and
  restore it afterwards.
- **Apple guidance.** HIG Playing video: "Avoid allowing audio from different sources to
  mix…" https://developer.apple.com/design/human-interface-guidelines/playing-video.

#### L11. Pull-to-refresh on You does nothing for guests

`YouView.swift:164` is `.refreshable { if model.isSignedIn { await model.syncNow() } }`.

- **Effect.** A guest's pull shows a spinner that refreshes nothing.
- **Apple guidance.** `refreshable` is for when "a person requests a refresh" to "initiate
  an update of model data".
  https://developer.apple.com/documentation/swiftui/view/refreshable(action:).
- **Fix.** Attach it only when signed in, through a small conditional modifier. Accept the
  view-identity change, since it happens only on sign-in or sign-out.

#### L12. The Progress hierarchy has three competing large numbers

The Progress tab stacks:
- a 50 pt editorial title,
- two `largeTitle` metrics,
- a third `largeTitle` readout inside the chart card.

- **Critique.** Through the frontend-design lens (one bold element, everything else
  quiet), the chart readout and the metrics compete.
- **Fix.** Drop the readout to `.title` or `FormaFont.numeral(.title)`, so the two summary
  metrics lead and the chart card reads as a detail.

#### L13. The journal row chevron and an empty exercise heading (device check)

`ProgressView.swift:83`. `Image(systemName: "chevron.right")` sits inside the
`NavigationLink` label. SF Symbols carry default labels, so VoiceOver may append
"Forward". This is **unconfirmed**.

- **Fix.** Add `.accessibilityHidden(true)`, since the link trait already says it
  navigates.
- An exercise with no completed sets shows a bare heading on the detail screen (see M7).

---

## 3. Already correct (keep it)

**Charts**
- Real totals only. The y-domain is zero-based with headroom. Bars never grow from zero:
  `.animation(nil, value: bars.map(\.volume))`. A one-time opacity reveal plays only at
  full motion.
- Every bar has a per-mark `accessibilityLabel` and `accessibilityValue`, giving date,
  name and volume.
- "Read chart values" is a text alternative, and its rows adapt to Dynamic Type with
  `ViewThatFits`.
- `chartXSelection(value:)` (iOS 17,
  https://developer.apple.com/documentation/swiftui/view/chartxselection(value:)) uses
  the whole plot area as the hit target. This matches HIG Charts: "consider expanding the
  hit target to include the entire plot area". Releasing the touch returns the readout to
  the latest workout, so no interaction is required.
- The change capsule carries an arrow, a percentage and "Same as before", so colour is
  never the only cue. Its contrast is 5.50:1 or better.
- X-axis labels thin to about four on compact widths or accessibility sizes, always
  keeping the newest.
- The selection haptic (`.selection`) is the documented pattern for "another bar in a
  chart". It is user-togglable, which matches HIG Playing haptics' "Make haptics
  optional".

**Media**
- Demo clips never autoplay. They are muted (and have no audio), loop, and use the system
  `VideoPlayer` controls. The player is torn down `onDisappear`.
- The Play button is 64 pt, ink on lime (13.2:1), with a descriptive label and hint.
- The animation starts on its still pose unless motion is full. Its Pause/Play control is
  always present at 44 pt minimum, satisfying HIG Accessibility's "reducing automatic and
  repetitive animations". `preventsDisplaySleepDuringVideoPlayback = false` is a good
  battery choice.
- `MediaDecoder` decodes fully off the main actor and stores a cropped bitmap instead of
  the whole sheet. Measured sizes:
  - Sheets are 1536×1024 and photos are 512×1024 or 1536×1024, so full-resolution decode
    is proportionate.
  - The caches are bounded to 40 and 24 entries.
- Decorative photos are `accessibilityHidden`. Illustrations and animations are single
  `.isImage` elements with descriptive labels. Licence links accept only `https`.

**You and settings**
- A native `Form` with `Toggle`, menu `Picker` and `LabeledContent`.
- The destructive delete uses an alert with a clear cancel ("Keep my training") and a
  `.destructive` action. It is hidden when signed in.
- Export uses `fileExporter`, releases the personal-data snapshot on dismiss, and uses an
  ISO filename.
- The profile editor puts Cancel on the leading side and Save on the trailing side, as in
  HIG Sheets. It confirms before discarding, blocks interactive dismissal when there are
  changes, shows its error inline, and has a keyboard Done button.
- `YouFocusReveal` moves both scroll position and VoiceOver focus to the widget toggle
  when another screen deep-links there.

**Workout details and the Watch card**
- The removed-workout state uses `ContentUnavailableView` with an honest message.
- The `WatchSummaryCard` speaks full units ("beats per minute", "kilocalories", spoken
  duration), omits missing heart-rate and energy readings, has a header trait, and uses
  `.contain` grouping.

**Colour, motion and typography**
- All text in the slice meets 4.5:1 in both appearances, with explicit Increase Contrast
  variants on every token.
- Motion goes through `FormaMotion` everywhere except M4. The CLAUDE.md rule against
  reading `accessibilityReduceMotion` in feature views holds for this slice.
- Typography uses text styles throughout. The custom display font scales with
  `relativeTo:`, and `AdaptiveMetricGroup` stacks at accessibility sizes.

**Severity counts:** High 2, Medium 9, Low 13.

---

## Resolution

Fixed on branch `fix/audit-progress` (2 November 2026), from audited commit `ba4e6a7`. Each
finding was re-checked against the code first; every one still applied. No simulator was
used; `xcodebuild build-for-testing` for `generic/platform=iOS` (Debug) succeeded with every
change below, with no warnings in the changed files. The tests were built but not run; that
needs a device.

| ID | Result | What changed |
|---|---|---|
| H1 | Fixed | Unfocused bars use `FormaTheme.boundary` (≥3:1 against `surface` in all four variants, per its token contract) instead of accent at 0.38/0.22 opacity, and scrubbing no longer fades the rest. The focused bar is solid `accent` with an `arrowtriangle.down.fill` marker above it, so focus is shown by shape as well as colour. |
| H2 | Fixed; needs device check | Added `VolumeChartDescriptor` (`AXChartDescriptorRepresentable`) through `.accessibilityChartDescriptor`. Its x-axis lists each workout's date and name (numbered when two would read the same), its y-axis speaks "kilogram repetitions", and its summary gives the chart type, average and highest. The chart's spoken value now includes the average. Device step: VoiceOver on the Progress chart, rotor › Audio Graph and Chart Details. Confirm the categories read as dates and names, not identifiers. |
| M1 | Fixed | The animated demonstration starts only when motion is full **and** Auto-Play Video Previews is on (`UIAccessibility.isVideoAutoplayEnabled`, refreshed on `videoAutoplayStatusDidChangeNotification`). This was done in `ExerciseMedia.swift`, not in `FormaMotionRoot`, so `DesignSystem/` is untouched. It is a video setting, not Reduce Motion, so the "never read `accessibilityReduceMotion` in a feature view" rule still holds. |
| M2 | Fixed | The demo poster is decoded by `MediaDecoder` in `.task(id: clipID)` into `@State`, never during `body`. |
| M3 | Fixed; needs device check | `.buttonStyle(.borderless)` on both credit `Link`s and on the animation's Pause/Play button. Device step: in an exercise guide with a demo clip, tap the poster away from Play and tap the caption. Neither should open Safari. Tap the animation; the row should not highlight. |
| M4 | Fixed | `MetricValue.transition(for:value:)` is now internal and the readout uses it: `numericText` at full, `opacity` at minimal, `identity` when off. |
| M5 | Fixed | The empty state reads "No workouts yet" and has a "Go to Today" button (`progress-empty-start`, `formaPrimaryCompact`) that selects the Today tab, where a workout starts. `progress-empty` is kept. `FORMAUITests/TrainingNavigationTests.swift` now matches the new title. |
| M6 | Fixed | The Motion and Haptics footers are now 13 and 17 words, and Haptics covers saves, rest, selections and errors. The Lock Screen section has a "Live Activity settings for FORMA" button that opens `UIApplication.openSettingsURLString`. The widget footer is shorter. |
| M7 | Fixed | Exercise names and "Session notes" carry `.isHeader`. Exercises with no completed set are not listed (see L13). |
| M8 | Fixed | `WatchTotalsCard` takes `energyRecorded` (true when any workout has an energy reading) and leaves Active kcal out otherwise. `MetricValue` gained an optional `spoken:` label and value, which the card uses to say "beats per minute" and "kilocalories". `FORMACore.WatchTotals` is unchanged. |
| M9 | Fixed | Default rest is a menu `Picker` (30 s to 10 min), labelled "1 min 30 sec" and so on. A saved value outside the list is added to the menu, so it is never blank. `profile-rest` is kept. |
| L1 | Fixed | `MetricValue` and the readout use `FormaFont.numeral`. This also changes the receipt metrics in `WorkoutView`, which use `MetricValue`. |
| L2 | Fixed | The chart card uses `FormaSpacing.lg` and `FormaRadius.card`. |
| L3 | Fixed | The illustration label drops the title when it matches the exercise name, ignoring case. |
| L4 | Fixed | The bullet is `accessibilityHidden`, and each item is one combined element. |
| L5 | Fixed | The section headers are now "Profile", "Appearance & feedback", "Widgets", "Your data" and "Training journal". The editorial title is kept. |
| L6 | Fixed | Training dates shows the time zone's localised generic name from `TrainingDate.calendar`. A footer says weights and dates match the website and can't be changed. |
| L7 | Fixed | `durationPhrase` leaves a missing duration out of the journal row and shows "under 1 min" below 60 s. The details screen omits the minutes metric when the duration is nil and shows "<1" (spoken "Under 1 minute") below 60 s. |
| L8 | Fixed | The loop length is formatted with `Duration`: "4.3 sec" on screen and "4.3 seconds" for VoiceOver. |
| L9 | Fixed | The chart height is capped at 320 pt. Device step: at AX5, check that the values list stays reachable. |
| L10 | Fixed | The `AVAudioSession` category call is removed. The player stays muted, and the clips have no audio track. |
| L11 | Fixed | `SyncRefresh` attaches `refreshable` only when signed in. |
| L12 | Fixed | The readout uses `FormaFont.numeral(.title)`, so the two summary metrics lead. |
| L13 | Fixed | The journal chevron is `accessibilityHidden`. Exercises with no completed set are skipped on the details screen. |
| workout.md M4 | Fixed (copy) | The receipt no longer says "Also saved in Apple Health". It now says "Your Apple Watch saves this recording to Apple Health and shows the result there." This is true whether or not the save works. A confirmed "Saved in Apple Health" needs the Watch to report the save. Today the final `WatchMetrics` is identical after `finishWorkout()` succeeds and after it fails (`FORMAWatch/WorkoutManager.swift`), so this needs a protocol change (a `saved` field) outside this slice. |
| workout.md L6 | Fixed | `WatchSummaryCard` formats heart rate with the view's `\.locale` and active energy as a `Measurement<UnitEnergy>` ("kcal" on screen, "kilocalories" for VoiceOver); recorded time passes the same locale to `WorkoutClock`. The grid drops to one column at accessibility text sizes, so values no longer wrap mid-number. `WatchTotalsCard` uses the same formatting. |
| today-start L10, completed in progress slice | Fixed; needs device check | `.accessibilityIgnoresInvertColors()` on `MediaPhoto` (the Today hero photo) and on every other photo and video surface in `ExerciseMedia.swift`: `BundledImage`, the exercise illustration frame, the demo clip (poster and `VideoPlayer`) and the animated demonstration. Device step: turn on Smart Invert in light mode and check the Today hero and an exercise guide's media stay as photographed. |

**Tests.** New `ios/FORMAAppTests/ProgressYouPresentationTests.swift` covers duration
phrasing, the readout transition per motion level, rest choices and formatting, the
illustration label, the chart descriptor's categories, range and summary, and the
off-main poster decode. `FORMAUITests/TrainingNavigationTests.swift` was updated for the
new empty-state title.

**Files changed.**
- `ios/FORMA/Features/ProgressView.swift`
- `ios/FORMA/Features/YouView.swift`
- `ios/FORMA/Features/ExerciseMedia.swift`
- `ios/FORMA/Features/WatchSummaryCard.swift`
- `ios/FORMAAppTests/ProgressYouPresentationTests.swift` (new)
- `ios/FORMAUITests/TrainingNavigationTests.swift`
- This report
