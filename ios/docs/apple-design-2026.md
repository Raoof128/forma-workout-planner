# Apple design research and native implementation decisions

Retrieved 23 October 2026, Australia/Sydney. This review uses Apple's official
Human Interface Guidelines (HIG), SwiftUI API documentation and five actual
WWDC26 session transcripts. It covers the design topics relevant to FORMA's
native guest app; it does not claim to have reviewed every page on Apple's
developer website.

The evidence is text and API metadata. No video-frame inspection, iOS compilation,
simulator screenshot, physical-device accessibility assessment or performance
measurement is implied by reading it. Living documentation can change; the
retrieval register below records hashes of the exact responses inspected.

## What is genuinely from 2026

These dates are visible in the retrieved source, rather than inferred from the
date of the user-supplied plans:

- **HIG Layout:** 9 September 2026, updated current best practices.
- **HIG Tab bars:** 8 June 2026, updated terminology and art.
- **HIG Sheets:** 24 March 2026, updated button-placement guidance.
- **WWDC26 session 251:** *Communicate your brand identity on iOS*.
- **WWDC26 session 250:** *Principles of great design*.
- **WWDC26 session 220:** *Refine accessibility for custom controls*.
- **WWDC26 session 292:** *Design intuitive search experiences*.
- **WWDC26 session 269:** *What's new in SwiftUI*.

Liquid Glass itself and the APIs adopted here were introduced in iOS 26 in 2025.
For example, the retrieved HIG Materials change log lists September and June 2025
Liquid Glass updates; Typography lists December 2025 and March 2025 updates.
Reading those pages in 2026 does not make those changes new in 2026.

The WWDC26 SwiftUI transcript describes additional Xcode 27 features, calling
their target the “2027 releases.” These include toolbar visibility priorities,
new overflow and pinned-placement APIs, general reorderable containers, and new
document APIs. Their presence in a 2026 talk does not establish iOS 26 availability.
FORMA's adopted calls are checked against their individual API metadata below.
The refinement pass requires an iOS 26.1-or-later SDK so it can use the dynamic
accessory API while retaining the iOS 17 deployment target. No native SDK build
has been performed in this Linux environment.

## Source-grounded decisions

### Navigation and glass belong above content

HIG Materials states: **“Don't use Liquid Glass in the content layer.”** Its
Liquid Glass section describes a functional layer for controls and navigation,
above the content. The adoption guide says standard bars, sheets, popovers and
controls gain the material automatically when rebuilt with current SDKs; custom
backgrounds can interfere with that appearance and with scroll-edge effects.

WWDC26 session 251 at **2:36–3:19** separates native navigation/actions from the
content where brand identity belongs. At **9:39–10:42**, it recommends moving
brand color into scrollable content instead of painting solid toolbar/tab-bar
backgrounds. At **15:59–16:24**, it cautions that repeated logos consume space
better used for information.

FORMA therefore keeps the four system tabs and native navigation bars. Today,
the routine title, the original F and the training artwork carry the identity.
Workout fields, exercise guides, history, chart data and receipts retain stable
opaque content surfaces. The saved state must remain clear without translucency.

A persistent active-workout resume control is appropriate as a native tab-view
bottom accessory. It is an action attached to navigation, not an invented fifth
tab. On the iOS 26.1+ accessory path the tab bar uses `.never` minimization for
predictable access while training; earlier systems keep their standard tab-bar
behavior. Apple's scrolling minimization is optional, not a rule that every app
must enable.

### Custom glass is restrained and has an opaque alternative

The custom-view guide recommends `GlassEffectContainer` when **multiple custom
glass effects** coexist, both for rendering performance and coordinated shapes.
Its spacing is meaningful: a threshold larger than the actual gap can cause
surfaces to merge even at rest. Set-row geometry must not merge or move because
of a decorative effect.

Use either a single regular-glass rest-control pane with ordinary child controls,
or separately coordinated glass controls. Do not stack glass on glass or add
`glassEffect` on top of a button already using `.glass`. Apply the effect after
the frame/padding and other appearance modifiers. Use `.interactive()` only for
an actual custom interactive control, not a non-tappable container.

Regular glass is the candidate for text-bearing functional controls. HIG Materials
limits clear glass to visually rich media backgrounds and warns about legibility;
it is unsuitable for FORMA's numeric logger. Native system glass adapts to system
accessibility settings automatically. FORMA additionally chooses an opaque custom
control surface when Reduce Transparency or Increase Contrast is enabled. That
explicit fallback is a product decision, not a claim that Apple requires replacing
all native glass manually.

### Toolbar, sheets and search remain native

HIG Toolbars recommends standard recognizable symbols, logical grouping, minimal
background customization and separation between unrelated text/icon groups.
`ToolbarSpacer(.fixed, placement: ...)` is available on iOS 26 for that separation.
Keep destructive actions in a clearly labelled menu with native destructive roles.
Do not make a destructive action visually prominent merely to showcase glass.

HIG Sheets, updated in March 2026, puts Cancel/Close on the leading side and
Done/Save on the trailing side for a single-view sheet. It also states:
**“Display only one sheet at a time from the main interface.”** A routine editor's
exercise picker should navigate within that editing flow rather than create a
stack of modal sheets. A supplementary guide sheet needs a visible dismissal
control as well as its native dismissal gesture. Unsaved edits need an explicit
cancel/discard path.

WWDC26 session 292 at **3:41–4:01** explains that search placement communicates
scope; at **7:04–7:40**, it supports inline search for a specific tab or collection.
FORMA searches the exercise library inside Plan/the picker. A global Search tab
would suggest capabilities the app does not provide. Retain the system search
icon, query field, clear/cancel behavior, appropriate filters and a real no-results
state. Filtering must preserve the query and match the current catalogue's units
and IDs.

### Typography and layout adapt across the whole app

HIG Typography recommends system text styles, legible weights, minimal typeface
mixing and Dynamic Type. It explicitly recommends stacked layouts and fewer
columns at large sizes rather than truncating important information. WWDC26
session 251 at **12:14–13:10** reinforces scaling and reflow; at **13:25–14:10**,
it shows that system font widths and rounded variants can express a distinctive
identity without sacrificing native behavior.

FORMA uses the system font, condensed editorial headings sparingly, and tabular
numerals for measurements and elapsed/rest time. Numeric inputs keep their unit
labels visible. Large text must reflow Today headers, metric groups, receipt,
section headings and rest controls as well as the set rows. A fixed target size
is a minimum interaction area, not a reason to clip a growing label.

HIG Layout recommends size classes, safe areas and actual available space rather
than branching only on device model/orientation. Background imagery may scale and
crop while preserving aspect ratio; essential controls and text must stay inside
safe areas. Preview the narrowest and widest supported layouts, landscape,
Display Zoom and large text before accepting the result.

HIG Dark Mode recommends following the system appearance. The supplied FORMA plan
also allows an explicit System/Light/Dark preference. If that override remains,
System stays the default and a user-selected override must be clear and reversible.
This is a documented design choice, not a prohibited App Store feature.

### Accessibility, data entry and feedback preserve control

WWDC26 session 220 at **3:43–3:56** defines four requirements for a custom control:
purpose, value, available action and feedback. At **9:51–10:32**, it demonstrates
named accessibility actions as an alternative to gestures. FORMA's completion
control needs an explicit set number, completed/not-completed value and undo
action; a lime fill or haptic alone is insufficient.

HIG Buttons recommends a **44 × 44 pt hit region as a general rule**. The current
Accessibility HIG separately lists 44 × 44 pt as the iOS default and 28 × 28 pt
as a minimum. FORMA deliberately adopts the stronger project targets: at least
44 pt for ordinary controls and 56 pt for set completion where feasible. These
are interface acceptance criteria, not a statement that a particular size is an
App Store law.

HIG Entering data and Text fields recommend persistent explanatory labels,
appropriate keyboards, reasonable defaults, validation at a useful point and
locale-aware numeric formatting. An unfinished string draft must not silently
change an already saved number. Inline errors should explain what to fix; a
successful local transaction precedes a saved check or success haptic.

HIG Motion recommends purposeful, brief and optional animation, and generally
avoiding extra motion for frequently repeated actions. WWDC26 session 250 at
**2:41–3:00** emphasizes forgiveness and confirmation for destructive actions;
at **16:05–16:24**, it rejects confetti or last-minute flourishes as a substitute
for considered design. Set completion therefore resolves in place. System Reduce
Motion always takes precedence over custom preferences. FORMA's Off setting
removes its own decorative motion; it does not promise to disable every native
system transition.

### Charts communicate actual records accessibly

HIG Charts recommends a descriptive title, meaningful units, appropriate axes,
clear values and an overview of the main message. Bar charts generally need a
zero lower bound so relative heights remain meaningful. Data should never move
through fabricated values to create a reveal animation.

Swift Charts supplies default mark accessibility and Audio Graphs. Preserve that
experience instead of hiding the entire chart from assistive technologies.
Describe each workout sample with its date, session and actual lifting volume;
retain a text values list as an additional route. If Audio Graphs is replaced,
the replacement needs an overview explaining the chart type, axes and range.
Critical information must not require scrubbing a small chart mark.

## Verified API baseline

All availability values below are the **iOS introductions** in the retrieved
Apple DocC metadata. The minimum app deployment remains iOS 17. An availability
guard does not let an older SDK compile a symbol it does not know; build with an
SDK containing every referenced symbol.

| API | iOS | Verified declaration or shape | FORMA decision |
| --- | --- | --- | --- |
| `View.glassEffect(_:in:)` | 26.0 | `nonisolated func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View` | Custom functional surfaces only; opaque fallback |
| `GlassEffectContainer` | 26.0 | `@MainActor @preconcurrency struct GlassEffectContainer<Content> where Content: View` | Group multiple custom effects, not all content |
| Container initializer | 26.0 | `init(spacing: CGFloat? = nil, @ContentBuilder content: () -> Content)` | Keep spacing tied to intentional geometry |
| `Glass.interactive(_:)` | 26.0 | `func interactive(_ isEnabled: Bool = true) -> Glass` | Actual custom controls only |
| `Glass.tint(_:)` | 26.0 | `func tint(_ color: Color?) -> Glass` | Sparse emphasis; verify contrast |
| `.buttonStyle(.glass)` | 26.0 | `static var glass: GlassButtonStyle { get }` | Native navigation/control actions where appropriate |
| `.buttonStyle(.glassProminent)` | 26.0 | `@MainActor static var glassProminent: GlassProminentButtonStyle { get }` | One clearly primary functional action when useful |
| `tabBarMinimizeBehavior(_:)` | 26.0 | `func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View` | `.never` for stable access |
| `TabBarMinimizeBehavior.never` | 26.0 | `static let never: TabBarMinimizeBehavior` | Adopted stability policy |
| `TabBarMinimizeBehavior.onScrollDown` | 26.0 | `static let onScrollDown: TabBarMinimizeBehavior` | Optional alternative; minimization supported only on iPhone |
| `tabViewBottomAccessory(content:)` | 26.0 | `func tabViewBottomAccessory<Content>(@ContentBuilder content: () -> Content) -> some View where Content: View` | Documented predecessor; not selected for dynamic show/hide |
| `tabViewBottomAccessory(isEnabled:content:)` | **26.1** | Same generic function with `isEnabled: Bool` | Adopted with an explicit 26.1 runtime guard and 26.1-or-later SDK requirement |
| `tabViewBottomAccessoryPlacement` | 26.0 | `var tabViewBottomAccessoryPlacement: TabViewBottomAccessoryPlacement? { get }` | Needed only if supporting the accessory's inline minimized layout |
| `ToolbarSpacer` | 26.0 | `nonisolated struct ToolbarSpacer` | Separate unrelated toolbar groups |
| `safeAreaBar` vertical overload | 26.0 | `func safeAreaBar(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ContentBuilder content: () -> some View) -> some View` | Bottom rest controls; adjusts safe area and scroll edge |
| `scrollEdgeEffectStyle(_:for:)` | 26.0 | `func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View` | Prefer system automatic effect; override only for a demonstrated readability need |
| `accessibilityReduceTransparency` | 13.0 | `var accessibilityReduceTransparency: Bool { get }` | Opaque custom control fallback when true |
| `colorSchemeContrast` | 13.0 | `var colorSchemeContrast: ColorSchemeContrast { get }` | Increased-contrast custom colors and control fallback |
| `ChartContent.accessibilityLabel(_:)` (Text overload) | 16.0 | `nonisolated func accessibilityLabel(_ label: Text) -> some ChartContent` | Each bar names the real session and date |
| `ChartContent.accessibilityValue(_:)` (Text overload) | 16.0 | `nonisolated func accessibilityValue(_ valueDescription: Text) -> some ChartContent` | Each bar reports its actual lifting volume |

FORMA selects the iOS 26.1 enabled accessory variant to show or hide the real
active-session resume control without conditionally rebuilding the whole TabView.
Tab selection is root-owned; accessory visibility uses the native enabled
parameter instead of branching around the TabView and its NavigationStacks. Test starting,
closing, resuming and finishing from every tab. This design explicitly requires
an SDK that contains the 26.1 declaration; an `#available` guard alone cannot make
an older SDK understand the symbol.

On iOS 17 through 26.0, the resume control uses a safe-area inset instead of the
26.1 accessory. The same training remains available. Standard system navigation
automatically uses its platform appearance, including native glass on iOS 26.0.
Custom rest bars use the separately guarded iOS 26.0 `safeAreaBar` API, with
`safeAreaInset` on older systems. Custom control surfaces use standard
`.regularMaterial` before iOS 26, and an opaque adaptive surface when Reduce
Transparency or Increase Contrast is enabled. Training data surfaces remain
opaque. Glass is not a feature gate for workout data.

## File review and evidence requirements

These are the source-based review decisions for the refinement pass; the final
change log records which edits and checks actually completed.

| File or area | Design review requirement |
| --- | --- |
| `App/FORMAApp.swift` | Root-owned tab/navigation state; standard native tab glass; truthful active-session accessory; no custom bar background |
| `App/AppModel.swift` | Persistence before success; protected local files; expose real active state; no presentation-driven mutations |
| `DesignSystem/FormaTheme.swift` | Light/dark/high-contrast palette; Dynamic Type; opaque reduced-transparency fallback; finite optional effects |
| `Features/TodayView.swift` | One dominant next action, real schedule/history, restrained logo/art, readable reflow |
| `Features/PlanView.swift` | Native scoped search, filters, stable IDs, one modal editing flow, accessible reorder alternatives, guide attribution |
| `Features/WorkoutView.swift` | Stable opaque fields, explicit units, clear completion/undo, native toolbar, safe-area rest controls, explicit guide dismissal |
| `Features/ProgressView.swift` | Actual volume only, zero-based bars, readable accessible chart and data list, useful empty state |
| `Features/YouView.swift` | Native grouped preferences, explicit destructive confirmation, genuine export, readable privacy and local status |
| `Sources/FORMACore` | Presentation-independent measurement/date/persistence contracts; no changes solely for glass |
| Resource catalogue/legal/artwork | Preserve deterministic source/rights metadata and current claims; do not invent workouts or instructional anatomy |
| Project, CI and UI tests | SDK availability enforcement; test navigation stability, dynamic text, accessibility preferences and interruption recovery |

Before visual acceptance, build with Xcode and inspect iOS 17 and iOS 26+ on
narrow/wide iPhones, portrait/landscape, light/dark, large accessibility text,
Reduce Motion, Reduce Transparency and Increase Contrast separately and together.
Check the keyboard and rest controls together. Exercise VoiceOver, Voice Control,
Switch Control, hardware keyboard navigation and accessible reorder. Measure
rendering and battery on devices; repeated glass effects are not free.

This environment is Linux, so those native visual/device checks remain explicit
open gates unless separately recorded with actual Mac/device evidence. Source
research, syntax parsing, Linux package tests and UI test authoring are useful
evidence for their own scope; they do not establish a running native interface or
App Store approval.

## Retrieval register

The following entries are official Apple responses successfully retrieved for this
review. Hashes are SHA-256 over the response bytes, before text extraction. DocC
entries link to the normal documentation page; the retrieved JSON endpoint is
`https://developer.apple.com/tutorials/data` plus that page path plus `.json`.
Raw responses and extracted working text were retained in the session scratch
directory `/tmp/forma-apple-design-research`, not bundled with the app. Hashes pin
this review and do not promise that Apple's live response will remain identical.

The attempted HIG `/liquid-glass` standalone page returned 404; its authoritative
guidance is in HIG Materials. An exploratory video URL `/wwdc2026/10001/` returned
the event index rather than a session, so it was rejected as session evidence.
No claims in this review rely on that response.

| Source | SHA-256 | Response bytes |
| --- | --- | --- |
| [Materials](<https://developer.apple.com/design/human-interface-guidelines/materials>) | `597da170985715de4bd8446df12e3604595e634a790b5da0ce6673d2b2327ed5` | 76,600 |
| [Accessibility](<https://developer.apple.com/design/human-interface-guidelines/accessibility>) | `be49ec0b34397f356a1e3fd8c7ad323713198515523947097913cb9c57da699b` | 85,010 |
| [Tab bars](<https://developer.apple.com/design/human-interface-guidelines/tab-bars>) | `b2f48f79d3f8a5bd00f2e3b462a19debd0a557ea0113ed8e573907bb06513f07` | 53,333 |
| [Toolbars](<https://developer.apple.com/design/human-interface-guidelines/toolbars>) | `4f1147642ab0561dcb2d4b074be970a537e2072be41e061314d1e234b4cdc6f7` | 72,799 |
| [Sheets](<https://developer.apple.com/design/human-interface-guidelines/sheets>) | `3e1a1accb148d23db5a74907b56438de35cdafdb1aafcc12722c7097d7829459` | 56,812 |
| [Layout](<https://developer.apple.com/design/human-interface-guidelines/layout>) | `d41f32ddf76c597f0edd54eac361fa294a8736cfc4ccc627d1709fe092ed7267` | 84,939 |
| [Adopting Liquid Glass](<https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass>) | `a41d1485f9815b51d040d2f723e7372e066eacbbda02b81493f21f6fee52ad47` | 152,124 |
| [Applying Liquid Glass to custom views](<https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views>) | `5ceb483599a015780e9a0718cb555529bf9bc190e20215ff50e019ee34ade69c` | 40,112 |
| [glassEffect(_:in:)](<https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)>) | `c5af879e0691c0fedef3c1f360ddb54d021b92dd79fa62263b0b79989e2b24ce` | 21,542 |
| [GlassEffectContainer](<https://developer.apple.com/documentation/swiftui/glasseffectcontainer>) | `b729b1b80e1e53363f2ec22a8f864d1bbb38df8274a8e06c1392740690d3c2bc` | 20,643 |
| [Glass](<https://developer.apple.com/documentation/swiftui/glass>) | `f97eccc155affb099be84e7d99da56fe07ddae9aed455029b5b5ef17403c3508` | 22,623 |
| [glass](<https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass>) | `26bebb71cdbbc400441f335205798e789a30db04066c4e2000b901cccff02e87` | 21,655 |
| [glassProminent](<https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent>) | `1bc930e7910d769cfbf33a674eb8f20cb0ab684cbd38d34f8efedb21f1b76734` | 22,256 |
| [tabBarMinimizeBehavior(_:)](<https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)>) | `80f8ee52102c69f1e94c8e8b3db3766c683947b9e0c2390abed574d224eb34b8` | 18,294 |
| [tabViewBottomAccessory(content:)](<https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory(content:)>) | `fbb605014b04665492ac0ca38398d9305a06c2cb31ed92cd4b4b1db96622d6d2` | 21,682 |
| [ToolbarSpacer](<https://developer.apple.com/documentation/swiftui/toolbarspacer>) | `1776a4125c15949699b893549782eebec8d5852c3785482e907ca014961eadbe` | 13,294 |
| [scrollEdgeEffectStyle(_:for:)](<https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)>) | `834a69cc7e970d196986d4a9a046e0f3f624b1cd9052b968032fb7ead7f12193` | 11,469 |
| [accessibilityReduceTransparency](<https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency>) | `93594bc91dd9ba5d1d60874556aed8fe971a5fb6082defbe68021d26bf3092e9` | 8,030 |
| [colorSchemeContrast](<https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast>) | `207f5ce8de8b6946d937e65bccbd0ce33521c43a90a4e5d6c371f64fe2d08faf` | 11,757 |
| [Liquid Glass](<https://developer.apple.com/documentation/technologyoverviews/liquid-glass>) | `6bb5642ad84c2450b12b82417c5b00e17eb7163adf688b64fed7c5240f26c87f` | 22,716 |
| [safeAreaBar(edge:alignment:spacing:content:)](<https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)>) | `3d8ea882f39e4d5706b6c8239c0ccbf3c331d513b3ac8fb6dcde2b627d3bb4d6` | 21,962 |
| [tabViewBottomAccessory(isEnabled:content:)](<https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory(isenabled:content:)>) | `c8f83147c44d1db45d6efc78ec9f7cbb475c792a8c0736f90a3bac3a5bd819a5` | 23,317 |
| [init(spacing:content:)](<https://developer.apple.com/documentation/swiftui/glasseffectcontainer/init(spacing:content:)>) | `5fb72f6c5ae011c43eaafe9ed76613a1d001e2a56e420a5b6078726221772b8c` | 7,890 |
| [interactive(_:)](<https://developer.apple.com/documentation/swiftui/glass/interactive(_:)>) | `00f1c042a21e05bb5b9a94ded67f3051b553c7bd2e064f6836ee747119828e77` | 16,297 |
| [tint(_:)](<https://developer.apple.com/documentation/swiftui/glass/tint(_:)>) | `2a846133357fa2661048aaa94ba90ece2a50f4b4940559c5d0db3cd85cd0c096` | 5,219 |
| [clear](<https://developer.apple.com/documentation/swiftui/glass/clear>) | `517519045f92327898cb2a08da823fe279e501467da355bce490b782afef16d4` | 5,191 |
| [hard](<https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/hard>) | `c68b2b9b892689a14296ac0cee9e7988f339c1c844b8c7c2ee6ac905b00b8c99` | 7,045 |
| [soft](<https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/soft>) | `e73c508e8d89dcb0cf1f2de4d8b5620b70d692a185696b325aaecad4a7e18344` | 7,039 |
| [Color](<https://developer.apple.com/design/human-interface-guidelines/color>) | `262ce33cb88d41ac0238bf1e3f59b7957e8ddb030379c41b35a6cbdb9ab11a39` | 182,037 |
| [Buttons](<https://developer.apple.com/design/human-interface-guidelines/buttons>) | `fb450f96dd7a201a0203852782252942ee6d72978e0baaec1cb4c400568fed91` | 70,324 |
| [safeAreaBar(edge:alignment:spacing:content:)](<https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)-9hwgb>) | `c4e4252feae5f907fa7403bddab7fd18a3143fe9d1a31a4ce985d0c33ff434b8` | 19,567 |
| [never](<https://developer.apple.com/documentation/swiftui/tabbarminimizebehavior/never>) | `dffcfdfbb193410675b9f846a6a8849dd9752033cef59523de2ab595eb41b8e9` | 4,452 |
| [onScrollDown](<https://developer.apple.com/documentation/swiftui/tabbarminimizebehavior/onscrolldown>) | `9ba7b8efe7cdffa3b53c3d3cde371b0b423a701a86793c3e88f56c6ed2024112` | 4,792 |
| [tabViewBottomAccessoryPlacement](<https://developer.apple.com/documentation/swiftui/environmentvalues/tabviewbottomaccessoryplacement>) | `cae2cc2af41f7a3b9b1b5d364f3ec04e0a4285f986f9d86feb7f70aaf0cfb723` | 6,066 |
| [Typography](<https://developer.apple.com/design/human-interface-guidelines/typography>) | `85bf7dc78d41a6e5e16d4055f3bdadf7bac4f7d5cb2206514c8b82d5d24631ed` | 281,141 |
| [Motion](<https://developer.apple.com/design/human-interface-guidelines/motion>) | `957268c323af4617dabb6c0449d0920248c995159d54f76c691aa180ceb72a61` | 31,108 |
| [Entering data](<https://developer.apple.com/design/human-interface-guidelines/entering-data>) | `0c430bb7e33382add2b6c602261f719b7b39b1406dfcedb653755ebcb1116a09` | 21,929 |
| [Charts](<https://developer.apple.com/design/human-interface-guidelines/charts>) | `206a83349e8a0bfcdd9ba647b995988ca7d464f8554c7fe93b7044dd8ced2ec5` | 53,610 |
| [VoiceOver](<https://developer.apple.com/design/human-interface-guidelines/voiceover>) | `859dc02ab9ba87dc545952d8f8077cf94936cd9f49f491d2e765c2425a6c76e5` | 36,439 |
| [Lists and tables](<https://developer.apple.com/design/human-interface-guidelines/lists-and-tables>) | `7abfc703aad0db86267b53942594c48f9ffde84a8d76646220524193a47e19db` | 33,074 |
| [Text fields](<https://developer.apple.com/design/human-interface-guidelines/text-fields>) | `18324cc7181a498b9324a1980231260785ee427eb9ae48f775bfa06a96153d40` | 25,637 |
| [Dark Mode](<https://developer.apple.com/design/human-interface-guidelines/dark-mode>) | `cf352a73655e616568441efefb295802ade3e7f34980f33c35f0ee778cf4f3e7` | 38,687 |
| [Progress indicators](<https://developer.apple.com/design/human-interface-guidelines/progress-indicators>) | `76a299d47f154a13b38568a52054f96d5f784739a6aecfe1a82d6ff3a042aa7c` | 27,214 |
| [wwdc26-brand](<https://developer.apple.com/videos/play/wwdc2026/251/>) | `a559f76c2f240daa810d888cd0e90052daac8479adecd75a97df1d49b5c6b591` | 148,994 |
| [wwdc26-principles](<https://developer.apple.com/videos/play/wwdc2026/250/>) | `6e95ce24ddfe5ea7aa9ab33cc062f7cc29d9eaf043292d98e28ec4dc350bcd01` | 152,362 |
| [wwdc26-accessibility](<https://developer.apple.com/videos/play/wwdc2026/220/>) | `32382ea083cf0f496921f76ab7d62183ea58eca8473fd4618002014ce4e4b247` | 152,842 |
| [wwdc26-swiftui](<https://developer.apple.com/videos/play/wwdc2026/269/>) | `75739ee9a970b7b6c2979c879f5a93a802f7919bacf16fc6159ed218198b1c7a` | 208,688 |
| [wwdc26-search](<https://developer.apple.com/videos/play/wwdc2026/292/>) | `d679be15451caa979dbca2aeb60565e7a55fab98e782208b989f237b644d093b` | 145,059 |

Additional API declaration checks during final source review:

| Source | SHA-256 | Response bytes |
| --- | --- | --- |
| [ChartContent](<https://developer.apple.com/documentation/charts/chartcontent>) | `eb095930154940e1905cc4e01a21ab56581cc663f78c40eafc3ac7c1c1bd7677` | 81,306 |
| [ChartContent accessibilityLabel(Text)](<https://developer.apple.com/documentation/charts/chartcontent/accessibilitylabel(_:)-28985>) | `845368dd4f569a73691e98506f26dcaf60d26e61ac22fcb7736c076d8cd4dcf0` | 14,465 |
| [ChartContent accessibilityValue(Text)](<https://developer.apple.com/documentation/charts/chartcontent/accessibilityvalue(_:)-5g7o4>) | `ef94d6bfdb93966c57e31b132854ebae282357af91a1e9ce291e06099592971b` | 14,478 |
| [ButtonStyle makeBody(configuration:)](<https://developer.apple.com/documentation/swiftui/buttonstyle/makebody(configuration:)>) | `460ad622d580f961879cad0d9b205d249e0cde9626130bd6fa12885e6f4a0fa6` | 10,070 |

The current ButtonStyle declaration marks `makeBody` as `@MainActor`, consistent
with reading the main-actor app model in the custom button style. The generic
Charts accessibility URLs returned 404 because these symbols have multiple
overloads; the table pins the actual Text overload pages rather than treating a
failed lookup as a missing API.

Five WWDC26 sessions were read through their complete published transcripts.
Their timestamps above refer to the transcript, not a frame-by-frame video review.

## Official visual references inspected

Three HIG reference PNGs were downloaded and visually inspected in this session.
They are Apple design references, not screenshots of FORMA, and are retained only
under `/tmp/forma-apple-design-images`; none is redistributed in the app.

| Reference | SHA-256 | Observed design implication |
| --- | --- | --- |
| [Regular glass over light content](https://developer.apple.com/tutorials/images/com.apple.HIG/materials-ios-liquid-glass-over-light@2x.png) | `0588973994e6cdf252335e1577556a38616e8132af4df6d372f12f2facfc33a0` | Material separates the functional surface from a detailed backdrop; no imitation blur is needed |
| [Regular glass over dark content](https://developer.apple.com/tutorials/images/com.apple.HIG/materials-ios-liquid-glass-over-dark@2x.png) | `4858c57ca7ce2ec3a4af5fb0b7d532e9da5ce9b0b746f6a430d2c6846668d0ee` | Material appearance responds to context; use semantic foregrounds for glass controls |
| [Expanded tab accessory](https://developer.apple.com/tutorials/images/com.apple.HIG/tab-bar-with-accessory-expanded@2x.png) | `45190eb2eb44dc36bb85d4a19e38f7249e36ecd6a3d31e6da976d86d3979e484` | The active-item accessory sits above the tabs as a distinct native control; preserve system geometry |

The 52 refinement sources above and these three visual references form a
bounded, relevant source map. They do not amount to every Apple documentation
page or every video frame, and they do not establish FORMA's rendered fidelity.

## Additional sources for the full bug audit

Retrieved and read on 23 October 2026. These eight living Apple documentation
pages supplement the 52 refinement sources; they are not claims of eight new
2026 APIs. The same DocC JSON retrieval convention applies. The ISO formatter
and initializer metadata both specify iOS 15, below FORMA's deployment floor.

| Source | SHA-256 | Response bytes |
| --- | --- | --- |
| [ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase) | `d8934fdc00e4f24e479dcd6582dcbe72dc3b1d995f885f9e2489be19859b47d3` | 19,327 |
| [ScenePhase.inactive](https://developer.apple.com/documentation/swiftui/scenephase/inactive) | `f96693f0d62f1181a3fce05e5af468f2eb4b11cd7729aae53bf2def64d5a234d` | 6,319 |
| [ScenePhase.background](https://developer.apple.com/documentation/swiftui/scenephase/background) | `b2a0273d2c9a8902c2324df1e51d46cf846c5e043e66e825136178b21ef73cde` | 6,221 |
| [DateFormatter.setLocalizedDateFormatFromTemplate(_:)](<https://developer.apple.com/documentation/foundation/dateformatter/setlocalizeddateformatfromtemplate(_:)>) | `e4aa27149d182d07ee8ecb9c0c3e937eb621cd83cf77e3389dd7de02794e432f` | 22,391 |
| [interactiveDismissDisabled(_:)](<https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:)>) | `99df362a3f05e719bc3983baa2e3cb7157f32787aaa98e0d17ce73c173e4b97f` | 15,060 |
| [FileProtectionType.complete](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete) | `09807d1b05913d11247cb0e211de71378c3c1f13d72f41a263cf79bf502b2d57` | 12,223 |
| [Date.ISO8601FormatStyle](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle) | `f2df023003e8c3c4c30b42e7cbdd986dcee904adc09b265fe735e9882ba640ab` | 62,504 |
| [ISO8601FormatStyle initializer](<https://developer.apple.com/documentation/foundation/date/iso8601formatstyle/init(dateseparator:datetimeseparator:timeseparator:timezoneseparator:includingfractionalseconds:timezone:)>) | `c89ee0d1f9a5e8a5988b2c5756090d10b3e27d2c5ba989095ad5475a8edfa522` | 17,473 |

Audit implications:

- Localized date templates follow the formatter's locale. They are suitable for
  display; a backup filename instead uses a Sydney date with fixed ISO separators.
- Disabling interactive dismissal does **not** prevent programmatic dismissal.
  A save action must keep an editor open if newer, unacknowledged text remains.
- Inactive scenes pause unnecessary work; a background transition can precede
  termination. Valid draft saving is best effort, never a durability promise.
- Complete file protection prevents reads and writes while locked or booting.
  A failed protected-file operation must preserve the previous commit and report
  an error rather than acknowledge an unsaved change.

Two additional export-lifecycle/privacy declarations were checked before
releasing the temporary backup and finalizing the source privacy inventory:

| Source | SHA-256 | Response bytes |
| --- | --- | --- |
| [fileExporter(isPresented:document:contentType:defaultFilename:onCompletion:)](<https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)>) | `caf9d496baa6a8aaaa71d3a0bf0ef870a0369562a07054afe9a0a3206ab4dde6` | 39,144 |
| [Required-reason API category definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) | `0d7433b45081771a4d1d886e1b753746d678e158f8705a159db6979bc46ecae9` | 49,889 |

This FileDocument overload is available from iOS 14. Apple states the presentation
binding becomes false before completion, and cancellation changes that binding
without calling completion. Clearing temporary export data when presentation
ends therefore covers cancellation too. The living documentation marks this
overload deprecated in iOS 27.2; the newer WritableDocument overload requires
iOS 27. Those future declarations do not justify using APIs absent from the
chosen SDK 26.1 baseline.

The current required-reason API lists were also checked against recovery-copy
deduplication. The new URL file-size, regular-file and symbolic-link metadata
keys are absent from those direct API lists. No manifest reason was invented for
them. The linked SQLite/Foundation implementation and the final archive still
need the binary-level privacy inspection recorded in the privacy inventory.

Scratch responses are retained under `/tmp/forma-audit-docs`,
`/tmp/forma-date-iso8601-*.json` and `/tmp/forma-file-exporter-completion.json`.
The combined register now contains **62** text/API/session sources and the same
three official reference images.
