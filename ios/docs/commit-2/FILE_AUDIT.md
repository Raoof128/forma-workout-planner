# Commit 2 file audit ledger

Prepared 27 October 2026 (Australia/Sydney) on branch `feat/ios-commit2-premium-experience`, based on commit `7373cf6`. Scope: all **1,544** tracked files (`git ls-files`). Commit 2 is a native motion and polish milestone and must not change production web, server or infrastructure files. Line numbers cite the files as committed at this base; no tracked file had been modified when they were read (`git status` showed only untracked `ios/FORMAUITests/ScreenshotTourTests.swift` and this directory).

## 1. Method

### Evidence reused, not re-derived

- `ios/docs/native-design-review.md` (23 Oct, 80 files): per-file dispositions and the finding that rendered glass, keyboard and safe-area behaviour needed a Mac. Its SHA-256 ledger `ios/docs/native-file-review.json` was compared with today's files: **51 of 80 hashes still match, 29 differ, 0 are missing** (all differences are later legitimate edits).
- `ios/docs/full-audit-2026-10-26.md` (26 Oct): the compile defect, receipt-cover fix, stale-error replay fix, date-formatter and catalogue-index speedups, and the Apple Watch claim checks. Cited per row, not repeated.
- `CHANGELOG.md`, top entry (27 Oct, commit `7373cf6`): off-main launch, the six-auditor performance review of every Swift file, FORMACore 76/76 tests, UI tests 3/8 passing on the iOS 27.0 simulator (the same 5 fail on unchanged code). This is the source for the performance and UI-test statements below. I did not re-run Swift tests or Instruments.

### How each class of file was examined

| Class | Files | How examined |
| --- | --- | --- |
| (a) Native authored files | 81 | Read completely now with line numbers (Swift, plists, entitlements, asset `Contents.json`, SVG, Python, Markdown, YAML, the two scripts and two JS tests, the hand-authored boundary fixture and `asset-checksums.json`). A concrete observation is recorded per file. Long Markdown table lines were read to 400-500 columns; the generator's long prose strings were read in full separately. |
| (b) Generated or binary native files | 10 | Validated programmatically, not read line by line: JSON parse and record counts; SHA-256 and byte length against `resource-manifest.json` and `ios/design/asset-checksums.json`; `sips` pixel size and alpha for the 3 PNGs (two of them also viewed); `node scripts/build-ios-resources.mjs --check`; the 23 Oct ledger compared hash by hash. |
| (c) Everything else (production web, server, Worker, ops, docs, assets) | 1,453 | **Not read line by line.** Classified by path and role from `git ls-files` with a script (Section 3). They are out of scope for a native-only commit and Commit 2 leaves them unchanged. The only interaction with them was hash checks of the 15 `src/` files the native generator pins and the JS tests that import those files. |

Total: 81 + 10 + 1,453 = 1,544. The 91 native rows are the 86 files under `ios/` plus `.github/workflows/ios.yml`, `scripts/build-ios-resources.mjs`, `scripts/check-ios-contracts.mjs`, `unit/ios-resources.test.js` and `unit/ios-validation-boundaries.test.js`. Authored Swift in those rows: 43 files, 8,101 lines.

### Checks run for this ledger (nothing was fixed)

| Check | Result |
| --- | --- |
| `git ls-files` count; files under `ios/` | 1,544; 86 |
| `node scripts/build-ios-resources.mjs --check` (this worktree has `node_modules`) | `Verified 6 native resources: 1711 accepted IDs, 1411 selectable.` exit 0 |
| `ios/FORMA/Resources/catalog.json` parse | **1,711 records, 1,411 with `selectable: true`**, 1,711 unique ids (expected 1,711 / 1,411: met) |
| `resource-manifest.json` | 16 of 16 source hashes match; 5 of 5 output hashes and byte lengths match |
| `ios/design/asset-checksums.json` | 3 of 3 files match on SHA-256 and bytes (SVG, iPhone icon, editorial art) |
| Other generated JSON | notices 1,711 entries; seed v2 with 3 routines, 0 history, `active` null; parity 12 cases; boundaries 38 records (28/6/4) |
| JSON in `ios/` and `.github/` | 15 of 15 parse |
| `plutil -lint` on 2 Info.plist, 2 entitlements, 2 privacy manifests | 6 of 6 OK |
| `sips` on the 3 PNGs | iPhone icon 1024x1024, Watch icon 1024x1024, editorial art 1536x1024; all `hasAlpha: no`; the two icons are byte-identical (same SHA-256) |
| SVG XML parse; `build-icon.py` syntax parse | OK; OK |
| `node --test --test-isolation=none unit/ios-resources.test.js unit/ios-validation-boundaries.test.js` | **17 of 17 pass** (14 + 3), about 247 s |
| Swift test functions counted by `grep` (13 files) | 76 (matches the CHANGELOG's 76/76; not executed here) |
| **NOT RUN** | `swift test`, any `xcodebuild`, XCUITest, `FORMAContractProbe` plus `check-ios-contracts.mjs`, `build-icon.py --check` (Pillow not installed), Instruments, any device or simulator work |

### Limits

- Findings marked "by inspection" come from reading source, not from running the app. No rendering, frame-rate, VoiceOver or device behaviour was observed.
- Other agents were editing Swift files concurrently. The base commit is the reference; later edits are outside this ledger.
- A new file under `ios/` is picked up only after `xcodegen generate` (the Xcode project is gitignored).

### Priority findings for the motion and polish work

- **Set completion has no motion and weak feedback.** The check swaps symbol and fill instantly (WorkoutView L714-734). The app's only haptic is `.sensoryFeedback(.success)` (L241), on complete and on a logged hold, never on undo, add set, hold start/pause, rest end or Finish. `busy` disables every field during each commit (L754), the keyboard drops after a commit (L368) and the rest dock then changes height with no animation (L174).
- **Rest and hold timers are silent and abrupt.** The rest dock appears and disappears without a transition (L807), digits have no numeric transition, and at zero it shows "Ready when you are" with no haptic or sound. The hold progress bar steps four times a second (L535). The hold chime depends on `Profile.muted`, which has no UI.
- **The Motion setting does nothing yet.** `model.motion` is read only by the 1% press scale in `PrimaryButtonStyle` (FormaTheme L97). There is no shared motion helper, so new animation must go through one resolver combining system Reduce Motion with System / Minimal / Off (YouView L43).
- **Hard cuts at the app's seams.** Loading to tabs (FORMAApp L27/L70), hero Start to Resume (TodayView L39-61), and workout to receipt inside the same cover (FORMAApp L50-55). The receipt has no entrance and no finish haptic. The week strip has no marker for today.
- **Responsiveness floor.** A set tap waits for whole-workspace validation (twice), a full JSON encode and a `synchronous=FULL` SQLite write (WorkoutEngine L65, WorkspaceStore L89-117), with `busy` true throughout; timings in the CHANGELOG are for a small workspace. Start waits on a Watch availability check with no feedback (AppModel L204-217). Today, Plan and Workout bodies depend on the whole `workspace` and re-render per commit by inspection.
- **Guard rails.** Design doc: no confetti, completion resolves in place, success haptic only after commit, no animated fabricated chart data. Privacy inventory: no notifications or `UserDefaults`. UI tests key on specific identifiers and accessibility values. The generator hashes 15 web files plus itself.
- **Test seam.** The only unit-test target is FORMACore; app-target logic is testable only through XCUITest (3 of 8 passing on iOS 27.0 simulator).
- **Watch.** No haptics in the Watch target, phase switch un-animated, Stop saves on one tap with no confirmation, and the Watch icon is not pinned by `asset-checksums.json`.

## 2. Native files

One row per tracked native path (91). Classification counts: improve 13, preserve 59, validate 19. Rows with a Commit 2 action pending: 13.

| Path | Purpose and dependencies | Classification | Evidence and finding | Commit 2 action |
| --- | --- | --- | --- | --- |
| `ios/.gitignore`<br>6 lines · 7d3fab67 | Ignores `.build/`, `.swiftpm/`, `FORMA.xcodeproj/`, DerivedData, `*.xcresult/`, `*.xcuserstate`. | preserve | Read in full. `FORMA.xcodeproj/` is ignored, so every new Swift file under `FORMA/` or `FORMAWatch/` only enters the build after `xcodegen generate`; the project is never committed. | none planned |
| `ios/FORMA/App/AppModel.swift`<br>437 lines · a3529553 | `@Observable` app state: load, commit gate, workout start/finish, Watch hand-off, presentation preferences, Sydney-date helpers. Uses FORMACore, WatchWorkoutCoordinator. | improve | Read in full (437 lines). `commit` (L173-200) shows state only after the gate, whole-workspace validation (twice, see WorkoutEngine/WorkspaceStore rows), JSON encode, a `synchronous=FULL` SQLite write and an actor hop, while `busy` is true throughout; that `busy` disables set fields and the completion button (WorkoutView L727, L754). The CHANGELOG timings (toggle 0.003 ms, small save 0.10 ms) are for a small workspace; cost is O(workspace) and was not measured near the 10,000-session / 20 MiB ceiling. `requestStart` (L204-217) awaits `watch.refresh()` before anything appears and never sets `busy`, so the Start tap has no immediate feedback while WatchConnectivity activates. `hapticsEnabled`, `motion` and `appearance` persist to `presentation.json` (L310-331) but `motion` is consumed in only one place (FormaTheme L97). Launch work is already off-main with a signpost (L97-138). | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/App/FORMAApp.swift`<br>155 lines · 6ed315a9 | App entry and `RootView`: loading / failure / tab states, tab accessory, start sheet, workout full-screen cover, error alert. Uses AppModel, StartWorkoutSheet, WorkoutView, WorkoutReceipt. | improve | Read in full (155 lines). Loading state (L70-75) is a static `FormaMark` plus a `ProgressView` label over `canvas`; the swap loading -> tabs (L27/L60/L70) and the cover's WorkoutView -> WorkoutReceipt swap (L50-55) have no transition or `withAnimation`, so both are hard cuts. Colour continuity from launch is already correct (LaunchBackground = canvas). The tab bar, sheet and cover use system motion only; `model.motion` is not read at the root, so no single place applies the user's Motion setting. `hasWorkspace` / `activeWorkoutName` keep the root from re-rendering per set (good). `ResumeTrainingControl` (L123-154) is a plain-style button with no pressed feedback; the `.disabled(model.busy)` blinks it on every commit. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/App/WatchWorkoutCoordinator.swift`<br>281 lines · 0c20bad4 | iPhone side of the Watch workout: availability checks, open Watch app, mirrored session follow, pause/resume/end messages. | preserve | Read in full (281 lines). No UI or motion code; it publishes `availability`, `phase`, `metrics` and `notice` that StartWorkoutSheet and WatchRecordingStrip render. `refresh()` sets `availability = .checking` on every call (L85), which flashes the sheet's progress label. WCSession activates in `init` (kept deliberately per CHANGELOG). Metrics arrive at most about 1 Hz and are de-duplicated (L175-185). Any animation belongs in the views that read these properties. | none planned |
| `ios/FORMA/DesignSystem/FormaTheme.swift`<br>146 lines · 20bc7503 | Colour tokens, `FormaMark` shape, `EditorialTitle`, `PrimaryButtonStyle`, `LocalSaveStatus`, `SectionHeading`. Used by every screen. | improve | Read in full (146 lines). `PrimaryButtonStyle` (L85-99) is the only motion in the app: pressed = opacity 0.85 and scale 0.99 (about half a point on a 56 pt button), applied with no `animation` modifier so it snaps. It is the only branded button style; every other control is system `.bordered`, `.plain` or `.borderless`. Reduce-motion logic (`reduceMotion` and `model.motion == .system`) lives only here; there is no shared motion token (durations, springs) or helper. `FormaMark` (L53-72) holds three static facet polygons, so per-facet reveal is possible. `LocalSaveStatus` (L101-118) swaps label and symbol on every commit with no transition. Colour tokens have light, dark and high-contrast variants, built once (L21-39). `EditorialTitle` scales from 48 pt with `@ScaledMetric` and has no minimum scale factor. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/DesignSystem/GlassControls.swift`<br>61 lines · af28527b | `formaControlSurface` (glass, material or opaque), `formaBottomBar`, `AdaptiveMetricGroup`. | improve | Read in full (61 lines). Glass is applied non-interactively with `.regular` (L19) and no `GlassEffectContainer`; the only consumers are `RestDock` and the pre-26.1 resume inset. The opaque Reduce Transparency / Increase Contrast fallback is correct. L43 states a design rule: `AdaptiveMetricGroup` has no transition or geometry animation so data-entry targets stay still; Commit 2 motion must respect it. Any dock appear/disappear or morph must avoid stacking glass on glass (apple-design-2026.md). | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/FORMA.entitlements`<br>10 lines · e1d613e0 | HealthKit entitlement with an empty access array. | preserve | Read in full; `plutil -lint` OK. Nothing here relates to motion. | none planned |
| `ios/FORMA/Features/PlanView.swift`<br>958 lines · 3f6e9337 | Plan tab: routine list, detail, editor, target editor, exercise library/picker, technique guide, training days, `PrescriptionText`. | improve | Read in full (958 lines). Library search is debounced and off-main (L786-807) with `ContentUnavailableView.search`. Picker add (L751-758, L367-379) appends and immediately pops with no haptic, highlight or scroll-to, so the add is invisible. Row insert/move/delete and the Create-routine sheet use system defaults with no authored motion. `TrainingDaysView` toggles (L901-919) read from the model but write through an async `commit`, so each Toggle can render its old value until the save publishes (possible flicker; verify on device). `PlanView` reads `model.workspace?.routines.count` (L11) and `RoutineDetailView.current` reads the workspace (L133), so both re-render per commit. Whole `Form` is `.disabled(model.busy)` during saves (L345, L655). Strong accessibility: 44 pt targets, inline validation, discard confirmation, accessible reorder alternative via Edit. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Features/ProgressView.swift`<br>233 lines · 5d6d6818 | Progress tab: totals, volume chart (last 8), journal list, session detail, `MetricValue`. | improve | Read in full (233 lines). Chart bars appear without an entrance and `MetricValue` numbers change without `contentTransition(.numericText)`. apple-design-2026.md allows reveal motion only on real values with a zero baseline. Chart keeps per-bar accessibility label/value plus a text list (L126-161). Empty state is correct. `SessionDetailView.current` scans `model.history` per body (L171). Journal rows are `NavigationLink`s with the default pressed dim. `VolumeChart` recomputes volume for 8 sessions per render (cheap). | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Features/StartWorkoutSheet.swift`<br>148 lines · f32fbd73 | Sheet shown only when a Watch is paired; also `WatchRecordingStrip` shown inside the workout. | improve | Read in full (148 lines). Status changes (checking, waiting, ready, notice) swap without transition. The waiting icon (L79) is static, with no `symbolEffect`. Buttons here use `.bordered` while the primary Start-on-Watch uses `PrimaryButtonStyle`, so styling is mixed. `WatchRecordingStrip` appears and updates heart rate and energy as plain text changes; the numbers have no numeric transition. `.task` auto-opens the Watch app when ready (L66-70). | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Features/TodayView.swift`<br>262 lines · 6622a622 | Today tab: header, editorial title, hero card (Start or Resume), week strip, routine rows, last-session card. | improve | Read in full (262 lines). Body reads `model.workspace?.active` (L39), `.schedule` and `.profile.goal` (L207-211), so it is invalidated on every commit by inspection (not measured). Hero Start/Resume swap (L39-61) is un-animated. `WeekStrip` (L177-261) marks trained and scheduled days but has no indicator for today, and the check fill is static. Routine rows use `.buttonStyle(.plain)` (L84), which removes pressed feedback. The date label (L172) is computed at render and never refreshes past midnight (no timeline). `LocalSaveStatus(saving: model.busy)` (L114) flips text on every commit. Hero start button gives no feedback while `requestStart` waits on the Watch check (see AppModel). Hero uses the 1.5 MP PNG with `scaledToFill`; minimum height 290 does not grow with Dynamic Type. Good: `ViewThatFits` header, accessibility-size week list, combined VoiceOver labels. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Features/WorkoutView.swift`<br>1,020 lines · 478cc3ad | Active workout: exercise selector, set rows, hold timer card, rest dock, notes sheet, receipt. Uses AppModel, HoldTimer, SetDraft. | improve | Read in full (1,020 lines). SET COMPLETION: the check button (L714-734) swaps symbol and fill instantly, no animation or symbol effect; the only haptic in the whole app is `.sensoryFeedback(.success)` at L241, fired after commit only on complete (L370) and on a logged hold (L452), never on undo, add set, hold start/pause, rest end, Finish or Discard. `complete` drops taps while `busy` (L349). Every field is `.disabled(set.done && !pendingChanges \|\| busy)` (L754), so each commit briefly disables the focused field; after a commit with no drafts `focusedField = nil` (L368) dismisses the keyboard, and `RestDock(compact: focusedField != nil)` (L174) then changes height with no animation. REST: dock appears and disappears with no transition (L807); countdown text has no `contentTransition(.numericText)`; at zero it shows `Ready when you are` silently, with no haptic, sound or notification. HOLD: 0.25 s `TimelineView` (L502), `ProgressView(value:)` steps 4 times a second (L535), no start or pause haptic; chime (sound 1057) only on log and only if `profile.muted == false`, and `muted` has no UI. EXERCISE CHANGE: `selectedExercise += 1` and `scrollTo` (L157-159) are un-animated. RECEIPT (L973-1020): static, no entrance, and no success haptic on Finish because the haptic state lives in the view being replaced. `WorkoutView.body` depends on the whole workspace (L41); every keystroke rebuilds `SetDraft` for undrafted rows (L116). Strong accessibility: labelled values, announcements (L458), Dynamic Type reflow. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Features/YouView.swift`<br>345 lines · c6e25efd | You tab: profile, preferences (appearance, motion, haptics), export, privacy, delete, support, `ProfileEditor`, `NativePrivacyView`. | improve | Read in full (345 lines). The Motion picker (System / Minimal / Off, L43-45) currently changes only the 1% press scale in `PrimaryButtonStyle`, so it is effectively a no-op until Commit 2 routes new motion through it; the haptics toggle gates only the single success haptic. The footer promises System Reduce Motion wins and haptics are paired with a visible check (L50-52). Export shows no progress or success confirmation (only failure surfaces, L108-111). Editors correctly block interactive dismissal with unsaved changes and show inline errors. `NativePrivacyView` decodes `legal.json` on the main actor in `.task` (L320-328); small (21 KB) so low priority. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMA/Info.plist`<br>48 lines · c121d575 | iPhone app plist: Health purpose strings, `UILaunchScreen` colour `LaunchBackground`, portrait plus both landscapes, single scene. | preserve | Read in full; `plutil -lint` OK. Landscape is enabled on iPhone, so any motion or layout change to the workout screen must hold in landscape. No `UIBackgroundModes`, no `NSSupportsLiveActivities` and no notification keys, which matches the privacy inventory; a Live Activity or local notification for rest would need a new target, keys and inventory changes. No `CADisableMinimumFrameDurationOnPhone`, which matters only for custom Core Animation or CADisplayLink drawing, not SwiftUI animation. | none planned |
| `ios/FORMA/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`<br>14 lines · a2e60d3e | Single universal 1024 icon entry. | preserve | Read in full; parses. References `app-icon.png`. | none planned |
| `ios/FORMA/Resources/Assets.xcassets/AppIcon.appiconset/app-icon.png`<br>17 KB · f05271fb | 1024 px opaque icon: the three-facet F on lime. | validate | Binary. `sips`: 1024 x 1024, no alpha. sha256 b006d525… and 17,399 bytes match `ios/design/asset-checksums.json`. Viewed: the F is centred with generous margin. `build-icon.py --check` NOT RUN (Pillow is not installed here). | none planned |
| `ios/FORMA/Resources/Assets.xcassets/Contents.json`<br>3 lines · 319a86bd | Asset catalogue root. | preserve | Read in full; parses. | none planned |
| `ios/FORMA/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`<br>20 lines · 8601dee5 | Launch-screen colour: light F5F6F3, dark 151A17. | preserve | Read in full; parses. Both values equal `FormaTheme.canvas` light and dark (FormaTheme L7), so launch screen to loading view is colour-continuous. This is the fixed starting point for any loading-state animation. | none planned |
| `ios/FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/Contents.json`<br>4 lines · 353ff812 | Single universal image entry for the Today hero. | preserve | Read in full; parses. One universal image with no 2x or 3x variants. | none planned |
| `ios/FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/training-editorial.png`<br>2.19 MB · 9927d4c0 | Original AI-assisted hero art used by `TodayView.trainingHero`. | validate | Binary. `sips`: 1536 x 1024, no alpha. sha256 c7d72e4f… and 2,187,502 bytes match `asset-checksums.json`. Viewed: dark negative space on the left, barbell plate on the right. The hero uses `scaledToFill` in a box of minimum height 290, so on a narrow phone the centre crop trims the plate's right edge; the title sits on the dark lower-left, which keeps text legible. Decoded size is about 6.3 MB (1536 x 1024 x 4). Any parallax should move this layer only. | none planned |
| `ios/FORMA/Resources/PrivacyInfo.xcprivacy`<br>14 lines · 2009fb7a | No tracking, no collected data types, no required-reason API categories. | preserve | Read in full; `plutil -lint` OK. `AudioServicesPlaySystemSound` (WorkoutView L454) and `UIApplication.isIdleTimerDisabled` are not required-reason APIs. Adding `UserDefaults`, file-timestamp or uptime APIs for Commit 2 would require a manifest reason. | none planned |
| `ios/FORMA/Resources/README.md`<br>52 lines · 1f788326 | Provenance and rights notes for the generated resources. | preserve | Read in full (52 lines). States the catalogue/selectable counts (1,711 / 1,411) that match the parse above. | none planned |
| `ios/FORMA/Resources/catalog.json`<br>3.68 MB · a5054b26 | Generated 1,711-record exercise catalogue (3.68 MB) bundled with the app. | validate | Generated, not read line by line. Parsed now: 1,711 records, 1,711 unique ids, 1,411 with `selectable: true`. sha256 and byte length match `resource-manifest.json`. At launch it is decoded off the main thread (AppModel L121-138). | none planned |
| `ios/FORMA/Resources/catalogue-notices.json`<br>1.43 MB · f8819804 | Generated per-entry rights inventory. | validate | Generated. Parsed: 1,711 entries. sha256 and bytes match the manifest. | none planned |
| `ios/FORMA/Resources/legal.json`<br>388 lines · 1b2ae23f | Generated web privacy/terms plus `nativeGuestNotice` (read by NativePrivacyView). | validate | Generated. Parses (21,254 bytes) and matches the manifest hash; `nativeGuestNotice` key present. NativePrivacyView decodes it inside `.task` on first appearance. | none planned |
| `ios/FORMA/Resources/native-privacy.md`<br>46 lines · df2e4216 | Human-readable native privacy notice. | preserve | Read in full (46 lines). Says there is no notification, location or analytics use; Commit 2 must not add any. One long unwrapped sentence in the Health paragraph is cosmetic. | none planned |
| `ios/FORMA/Resources/resource-manifest.json`<br>100 lines · 5568340e | Generated provenance: 16 source hashes and 5 output hashes. | validate | Generated. All 16 source sha256 values match the current files; all 5 output hashes and byte lengths match. `node scripts/build-ios-resources.mjs --check` passes (6 resources including this manifest). | none planned |
| `ios/FORMA/Resources/seed-workspace.json`<br>267 lines · c25d3f0f | Generated empty-history v2 workspace with three starter routines. | validate | Generated. Parsed: version 2, 3 routines, 0 history, `active` null. Hash matches the manifest. | none planned |
| `ios/FORMAUITests/OfflineWorkoutTests.swift`<br>276 lines · ad1c95a0 | Eight XCUITest journeys: empty progress, completion survives termination, resume accessory, decimal entry, invalid drafts, notes, delete-clears-detail. | improve | Read in full (276 lines). Depends on these stable hooks that Commit 2 must keep: identifiers `start-workout` (label flips Start/Resume), `complete-set-E-S` with accessibility value `Completed` / `Not completed` (5 s wait), `rest-toggle` label, `finish-workout`, `receipt-done`, `resume-workout-accessory`, `workout-validation`, `local-save-status`, `progress-empty`, and alert buttons queried through `app.alerts`. Animation must not delay the accessibility value. CHANGELOG: 3/8 pass on the iOS 27.0 simulator and the same 5 fail on the unchanged code (duplicate Finish matches, keyboard focus, launch timeouts). An untracked `ScreenshotTourTests.swift` now exists beside it (outside the 1,544 tracked paths). | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMAWatch/Assets.xcassets/AppIcon.appiconset/Contents.json`<br>14 lines · 974a0f57 | Single universal watchOS 1024 icon entry. | preserve | Read in full; parses. | none planned |
| `ios/FORMAWatch/Assets.xcassets/AppIcon.appiconset/app-icon.png`<br>17 KB · f05271fb | Watch icon (same artwork as the iPhone icon). | validate | Binary. `sips`: 1024 x 1024, no alpha. Byte-identical to the iPhone icon (same sha256 b006d525…), but it is not listed in `asset-checksums.json`, which covers only three files, so no test pins it. | none planned |
| `ios/FORMAWatch/Assets.xcassets/Contents.json`<br>3 lines · 319a86bd | Watch asset catalogue root. | preserve | Read in full; parses. | none planned |
| `ios/FORMAWatch/FORMAWatch.entitlements`<br>10 lines · e1d613e0 | HealthKit entitlement, empty access array (Watch). | preserve | Read in full; `plutil -lint` OK. | none planned |
| `ios/FORMAWatch/FORMAWatchApp.swift`<br>26 lines · fb05553f | Watch `@main` and `WKApplicationDelegate` (start from iPhone, workout recovery). | preserve | Read in full (26 lines). Uses `WKApplicationDelegateAdaptor` (current API) and routes both callbacks to `WorkoutManager`. No UI. | none planned |
| `ios/FORMAWatch/Info.plist`<br>36 lines · 3ed6674d | Watch app plist: `WKApplication`, companion bundle id, `workout-processing` background mode, Health purpose strings. | preserve | Read in full; `plutil -lint` OK. Companion id matches `project.yml`. | none planned |
| `ios/FORMAWatch/PrivacyInfo.xcprivacy`<br>14 lines · 2009fb7a | Watch privacy manifest: no tracking, no collected types, no API reasons. | preserve | Read in full; `plutil -lint` OK. Identical in content to the iPhone manifest. | none planned |
| `ios/FORMAWatch/WatchViews.swift`<br>179 lines · bef5614d | Watch UI: root phase switch, Start, session (elapsed, heart rate, energy, controls), summary. | improve | Read in full (179 lines). The root `switch` on phase (L10-17) has no transition. Colours `lime` and `ink` are redeclared locally (L3-4) rather than shared with the iPhone theme (values match). Stop (L147-153) ends and saves on a single tap with no confirmation. Pause/Stop are icon-only buttons with labels. No haptic anywhere in the Watch target (grep: no `WKInterfaceDevice` or `sensoryFeedback`), so start, pause, resume and end rely on system defaults. Always On is handled: controls hide and the clock updates once a minute (L54-101). Heart rate and energy show `-- bpm` until the first sample. No rest or set information on the Watch. Summary is a plain scroll with a Done button. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/FORMAWatch/WorkoutManager.swift`<br>343 lines · 1d4590f7 | Watch HealthKit session, live builder, mirroring, recovery, throttled metric send. | preserve | Read in full (343 lines). Publishes rounded heart rate and energy only when they change and sends at most once per second (10 s when unchanged), per the 27 Oct audit. Phase changes (`.starting`, `.running`, `.ending`) are immediate state flips that views can animate; a failed save sets `.failed` and skips the summary (L210, L220). No haptic calls. HealthKit behaviour is unverified on hardware (apple-watch.md). | none planned |
| `ios/Fixtures/parity.json`<br>4,387 lines · 9aaa97b1 | Generated: 12 synthetic web-validated workspaces with expected totals (used by GoldenParityTests and the JS boundary test). | validate | Generated, not read line by line. Parsed: 12 cases. Listed in `resource-manifest.json` outputs: sha256 and byte length match. Fictional data only. | none planned |
| `ios/Fixtures/validation-boundaries.json`<br>210 lines · d225c541 | Hand-authored 38-record corpus: 28 history dates, 6 routine measurements, 4 active-completion cases. | validate | Read in full (about 4.7 KB). 38 records confirmed by parse (28/6/4). Consumed by both ValidationBoundaryTests (Swift) and the JS boundary test. | none planned |
| `ios/Package.swift`<br>18 lines · badbb257 | SwiftPM manifest: FORMACore library, FORMAContractProbe executable, CSQLite system library, test target; Swift 6 language mode, iOS 17 / macOS 14. | preserve | Read in full (18 lines). The package has the only unit-test target (`FORMACoreTests`). Decision logic added to the app target (for example a motion or haptic policy) has no unit-test home; it is testable only through XCUITest unless it lives in FORMACore. | none planned |
| `ios/README.md`<br>119 lines · d5ca9cbe | Mac build, Watch, hold timer, scope and verification boundaries for the native app. | preserve | Read in full (119 lines). Accurate on build steps and on the DEBUG-only `--ui-testing` / `--reset-workspace` arguments; has no section on motion or haptics. Statement that numeric drafts are not durable until committed is a hard constraint for any motion that touches the logger. | none planned |
| `ios/Shared/WatchWorkout.swift`<br>60 lines · c03bea79 | Shared Health types, application-context keys and the Codable mirrored-session messages (compiled into both apps). | preserve | Read in full (60 lines). `WatchMetrics` and `WatchWorkoutMessage` are an on-the-wire contract between two app versions; keep Codable shape stable. | none planned |
| `ios/Sources/CSQLite/module.modulemap`<br>5 lines · 0a291b5e | System-library module for SQLite. | preserve | Read in full (5 lines). | none planned |
| `ios/Sources/CSQLite/shim.h`<br>1 lines · f52e1f09 | Includes `sqlite3.h`. | preserve | Read in full (1 line). | none planned |
| `ios/Sources/FORMAContractProbe/main.swift`<br>68 lines · ee2d168c | Dev-only CLI: start, complete and finish a synthetic workout for each of 1,711 ids and emit JSON for the JS checker. | preserve | Read in full (68 lines). Not linked into the iPhone binary. Not run now. | none planned |
| `ios/Sources/FORMACore/DraftAcknowledgement.swift`<br>12 lines · 59f62878 | `retainingUnacknowledgedDrafts`: clears only the draft values a save acknowledged. | preserve | Read in full (12 lines). Used by every WorkoutView save path (L332, L337, L367, L450). The motion work must not change when drafts are cleared. | none planned |
| `ios/Sources/FORMACore/ExerciseSearch.swift`<br>84 lines · 9a9f6a3d | Folded-word substring search with an ASCII fast path. | preserve | Read in full (84 lines). Empty query returns the input unchanged; the library calls it from a detached task (PlanView L801). No UI concern. | none planned |
| `ios/Sources/FORMACore/HoldTimer.swift`<br>97 lines · 220ad4fd | Hold-timer rules (length clamp, default, logged count, target set) and `WorkoutEngine.logHold`. | preserve | Read in full (97 lines). Min 5 s, max 3,600 s, step 5. `logHold` finds the exercise by a linear scan of the catalogue (L75), once per hold, negligible. Logs through `toggleSet`, so rest starts exactly as ticking a set does. | none planned |
| `ios/Sources/FORMACore/LastCompletedSet.swift`<br>13 lines · 44bb5df6 | Newest completed set for an exercise across history. | preserve | Read in full (13 lines). Called from `LastSetLabel` each time its inputs change. | none planned |
| `ios/Sources/FORMACore/MeasurementDraft.swift`<br>64 lines · 06bd19de | String drafts for set fields with locale-aware parse and validation. | preserve | Read in full (64 lines). Builds six formatted strings per `init`; WorkoutView constructs one for every undrafted set on each body evaluation (L116). | none planned |
| `ios/Sources/FORMACore/MeasurementNumberInput.swift`<br>37 lines · 6e013413 | Full-string locale-aware number parser and display. | preserve | Read in full (37 lines). Rejects grouping separators; shared by routine targets and workout fields. | none planned |
| `ios/Sources/FORMACore/MeasurementText.swift`<br>28 lines · f226d90f | Summary text for a set that keeps units visible. | preserve | Read in full (28 lines). Used by journal, last-time hint and chart lists. | none planned |
| `ios/Sources/FORMACore/Models.swift`<br>486 lines · 57714dab | Codable workspace v2 model (`Workspace`, `Routine`, `Prescription`, `WorkoutSession`, `LoggedSet`, `Exercise`, `Profile`, errors). | preserve | Read in full (486 lines). Keys mirror the web contract, so none may change. `Profile.muted` and `Profile.fillSets` exist in the workspace but only `muted` is read (WorkoutView L454) and neither has a native control. `Exercise.searchKey` is derived and excluded from the stored format. | none planned |
| `ios/Sources/FORMACore/SerializedMutationGate.swift`<br>33 lines · c4e41fcb | Main-actor FIFO gate serialising local commits. | preserve | Read in full (33 lines). Non-reentrant; acquisition ignores cancellation on purpose. This gate plus the SQLite write is what `AppModel.busy` reports. | none planned |
| `ios/Sources/FORMACore/WorkoutEngine.swift`<br>505 lines · 46919b8f | Pure workout rules (start, toggle, finish, rest, volume, 1RM) and whole-workspace validation. | preserve | Read in full (505 lines). `toggleSet` re-validates the entire workspace (L65, `validateStructure` walks every history session) and `WorkspaceStore.save` validates again; rest pause/adjust/skip validate too. No 'rest finished' event exists: remaining time is derived from `restEnd`, so any end-of-rest cue must come from the view timeline. The per-side range check matches the web (L23-27). | none planned |
| `ios/Sources/FORMACore/WorkspaceExport.swift`<br>15 lines · ebbac14b | Compact canonical JSON export within the 20 MiB cap. | preserve | Read in full (15 lines). | none planned |
| `ios/Sources/FORMACore/WorkspaceStore.swift`<br>328 lines · 6a901436 | Actor-isolated SQLite store: WAL, `synchronous=FULL`, revision compare-and-swap, previous snapshot, corruption preservation, reset. | preserve | Read in full (328 lines). Every save rewrites the whole snapshot BLOB and copies the old one into `previous_snapshot` (L106-111), so a set tap writes about twice the workspace size with an fsync. This is the latency floor of persisted completion feedback and is a deliberate durability trade-off (verification.md scores durability 7/10); do not weaken it for animation. Statements are finalised and transactions roll back on every path. | none planned |
| `ios/Tests/FORMACoreTests/DraftAcknowledgementTests.swift`<br>29 lines · 95a09b0a | 3 tests for `retainingUnacknowledgedDrafts`. | preserve | Read in full (29 lines). Pins that newer edits and new keys survive an acknowledged save. | none planned |
| `ios/Tests/FORMACoreTests/ExerciseSearchTests.swift`<br>79 lines · 53887c5c | 7 tests: word matching, folding, empty/emoji queries, ASCII-equals-Unicode for all 128 scalars, batch filter equals per-item on the real catalogue. | preserve | Read in full (79 lines). Loads `catalog.json` by `#filePath`-relative path, so it needs the generated resource present. | none planned |
| `ios/Tests/FORMACoreTests/GoldenParityTests.swift`<br>94 lines · eccbd171 | 3 tests: 1,711 / 1,411 / unique ids, every default starts and finishes, 12 golden cases. | validate | Read in full (94 lines). Hard-codes 1,711 and 1,411; matches the parse above. | none planned |
| `ios/Tests/FORMACoreTests/HoldTimerTests.swift`<br>151 lines · 0e5975e8 | 8 tests for clamp, default length, availability, logging and the legacy plank. | preserve | Read in full (151 lines). Hard-codes 214 hold-timer exercises in the generated catalogue; a web catalogue change would need this updated. | none planned |
| `ios/Tests/FORMACoreTests/LastCompletedSetTests.swift`<br>43 lines · ffea9f47 | 3 tests for duplicate-exercise and excluded-session precedence. | preserve | Read in full (43 lines). | none planned |
| `ios/Tests/FORMACoreTests/MeasurementDraftTests.swift`<br>102 lines · c99c664d | 8 tests: precision, dot/comma, rejection, per-side, Arabic and French locales. | preserve | Read in full (102 lines). | none planned |
| `ios/Tests/FORMACoreTests/MeasurementNumberInputTests.swift`<br>57 lines · f3e88a28 | 5 tests: locale digits, rejection, signs/exponents, round trip, no grouping. | preserve | Read in full (57 lines). | none planned |
| `ios/Tests/FORMACoreTests/MeasurementTextTests.swift`<br>78 lines · e623a884 | 7 tests for unit-preserving summaries. | preserve | Read in full (78 lines). | none planned |
| `ios/Tests/FORMACoreTests/SerializedMutationGateTests.swift`<br>110 lines · cdde0d93 | 3 tests: single owner and FIFO for 20 tasks, failure release, cancelled waiter still commits. | preserve | Read in full (110 lines). | none planned |
| `ios/Tests/FORMACoreTests/ValidationBoundaryTests.swift`<br>83 lines · f074d558 | 3 groups over the 38 shared boundary records. | validate | Read in full (83 lines). | none planned |
| `ios/Tests/FORMACoreTests/WorkoutEngineTests.swift`<br>215 lines · 2ab90767 | 12 engine tests plus the shared `Fixtures` used by four other files. | preserve | Read in full (215 lines). Covers rest deadline, pause/resume/adjust/skip and superset rest, but nothing about what the UI shows at rest expiry, and nothing at view level; no test exercises motion, haptics or any SwiftUI view. | none planned |
| `ios/Tests/FORMACoreTests/WorkspaceExportTests.swift`<br>27 lines · 762d4c9f | 1 test: 150,000 sets export within 20 MiB and round-trip. | preserve | Read in full (27 lines). | none planned |
| `ios/Tests/FORMACoreTests/WorkspaceStoreTests.swift`<br>315 lines · f812dbff | 13 tests: persistence, two writers, injected SQLite abort, corruption, schema, reset, oversize, duplicate recovery files. | preserve | Read in full (315 lines). | none planned |
| `ios/design/app-icon.svg`<br>1 lines · b25dcbcc | Source vector for the icon (three facets on lime). | validate | Read in full; well-formed XML. sha256 2c8c3294… and 302 bytes match `asset-checksums.json`. | none planned |
| `ios/design/artwork-provenance.md`<br>44 lines · 38cf86b1 | Provenance of the hero art and icon, and reproduction steps. | preserve | Read in full (44 lines). States both PNG hashes that match the programmatic check. | none planned |
| `ios/design/asset-checksums.json`<br>20 lines · 03a3d58f | sha256 and byte length for three durable assets. | validate | Read in full. All three entries verified now (hash and size). Does not cover the Watch icon. | none planned |
| `ios/design/build-icon.py`<br>102 lines · f0d81d28 | Pillow 12.3.0 rasterizer that reproduces the icon and checks pixels. | preserve | Read in full (102 lines); syntax parses. `--check` NOT RUN: Pillow is not installed in this environment. | none planned |
| `ios/docs/app-review-matrix.md`<br>59 lines · ae85fce2 | Engineering gates for App Review (4.2, 5.1.x, accessibility, encryption). | preserve | Read in full (59 lines). Accessibility row lists VoiceOver, Dynamic Type, contrast and motor testing as still open; motion work should not claim to close it. | none planned |
| `ios/docs/apple-design-2026.md`<br>420 lines · a755b601 | 62-source Apple research register and design decisions. | preserve | Read in full (420 lines). Binding constraints for Commit 2: motion is purposeful, brief and optional; set completion resolves in place and confetti is rejected (WWDC26 session 250); a saved check or success haptic follows a committed local transaction; chart reveals may not animate fabricated values; System Reduce Motion always wins and the app's Off removes only its own decorative motion; use a single glass container and never stack glass. | none planned |
| `ios/docs/apple-watch.md`<br>79 lines · b56222ac | Watch workout flow, data boundaries, implementation map and unverified list. | preserve | Read in full (79 lines). Hardware behaviours (mirroring, heart-rate density, reconnect) remain unverified; no UI motion requirements beyond Always On. | none planned |
| `ios/docs/baseline-evidence.md`<br>58 lines · 85258186 | 23 Oct baseline: commit, counts, drift notes, decisions. | preserve | Read in full (58 lines). Historical; its 1,711 / 1,411 counts still match. | none planned |
| `ios/docs/full-audit-2026-10-26.md`<br>108 lines · 5357451d | 26 Oct audit: 5 defects fixed, perf fixes, Watch claim checks, verification. | preserve | Read in full (108 lines). Source cited for the compile fix, the receipt-cover fix, the stale-error fix and the Watch claim table. | none planned |
| `ios/docs/implementation-plan.md`<br>52 lines · 3cdaa303 | First-slice plan and follow-on gates. | preserve | Read in full (52 lines). Item 4 lists Reduced Motion as part of the design; follow-on table gates accounts and import, not motion. | none planned |
| `ios/docs/native-design-review.md`<br>159 lines · 10708276 | 23 Oct file-by-file review (80 files) with per-file dispositions. | preserve | Read in full (159 lines). Its per-file table is a snapshot: 29 of the 80 recorded files have changed since (see native-file-review.json row). | none planned |
| `ios/docs/native-file-review.json`<br>1,118 lines · 5c3df6b7 | 23 Oct SHA-256 ledger for 80 files. | validate | Parsed (not read line by line). Compared all 80 recorded hashes with today's files: 51 match, 29 differ, 0 missing. The 29 are the files edited by later commits (AppModel, the five feature views, FORMAApp, FormaTheme, Models, WorkoutEngine, WorkspaceStore, project.yml, Info.plist and others). No test enforces it; superseded by full-audit-2026-10-26.md. | none planned |
| `ios/docs/privacy-inventory.md`<br>78 lines · 21073b54 | Data and capability inventory with required evidence. | preserve | Read in full (78 lines). Says no `UserDefaults`, notification, location or other capability is required. Any Commit 2 change that adds one must update this file and the manifest. | none planned |
| `ios/docs/verification.md`<br>284 lines · 69b2f4a2 | Chronological verification record (23 Oct to 26 Oct). | improve | Read in full (284 lines, with the longest table lines read to 500 columns). Ends at the 26 Oct Watch entry; the 27 Oct performance audit (76/76 Swift tests, UI 3/8) is only in the CHANGELOG. Scorecard still lists Visual/interaction craft 5/10. | pending — see IMPLEMENTATION_REPORT.md |
| `ios/project.yml`<br>106 lines · 02529aad | XcodeGen spec: FORMA (iPhone, device family 1), FORMAWatch (watchOS 10, family 4), FORMAUITests; Swift 6 strict concurrency; iOS 17 deployment. | preserve | Read in full (116 lines). Source folders are globbed, so new files need no spec edit. There is no app unit-test target, only `FORMAUITests` (`parallelizable: false`, random order). `MARKETING_VERSION 0.1.0`, `CURRENT_PROJECT_VERSION 1`. Build settings already compile the iOS 26.1 accessory and glass APIs behind `#available`. | none planned |
| `.github/workflows/ios.yml`<br>212 lines · 0093dfea | macOS CI: Node resource check, `swift test`, contract probe, pinned XcodeGen 2.44.1, simulator selection, `xcodebuild test` (FORMA scheme) plus optional iOS 17 and 26.0 runs. | preserve | Read in full (212 lines). Triggers on any `ios/**` PR change, so Commit 2 will exercise it. Has never run remotely (full-audit-2026-10-26.md). It reports missing runtimes as NOT RUN and fails outright if no Xcode 26.1+ is installed on `macos-15`. The UI suite it runs is 3/8 passing on the iOS 27.0 simulator per the CHANGELOG, so a first red run is expected and pre-existing. No separate FORMAWatch test step (the Watch app is built only as an embedded dependency). | none planned |
| `scripts/build-ios-resources.mjs`<br>381 lines · 46352e5a | Deterministic generator for catalog, seed, legal, notices, parity fixtures and the manifest; imports 14 web `src/` files and hashes itself. | validate | Read in full (381 lines). `--check` run now: `Verified 6 native resources: 1711 accepted IDs, 1411 selectable.` exit 0 (node_modules present in this worktree). Any edit to this script or to the 15 hashed `src/` sources changes `resource-manifest.json` and fails the drift test, so Commit 2 must not touch them. | none planned |
| `scripts/check-ios-contracts.mjs`<br>92 lines · e81c88c4 | Validates `FORMAContractProbe` output (1,711 Swift-generated workouts) against strict web validation and default measurements. | validate | Read in full (92 lines). Not run now: it needs `swift run FORMAContractProbe` output and no Swift toolchain run was in scope. Its seven schema-valid-corruption rejections are exercised in JavaScript by `unit/ios-resources.test.js`. | none planned |
| `unit/ios-resources.test.js`<br>409 lines · 4a4f79ee | 14 Node tests: checksums, import-graph provenance, catalogue/guide/legal/seed parity, byte-for-byte regeneration and drift rejection. | validate | Read in full (409 lines). Run now together with the boundaries test: 17/17 pass (14 + 3). The run took about 247 s with `--test-isolation=none`, so it is slow; the generator is rebuilt several times inside it. | none planned |
| `unit/ios-validation-boundaries.test.js`<br>48 lines · a2717011 | 3 Node test groups checking the 38 shared boundary records against strict `validateData`. | validate | Read in full (48 lines). Passes (counted in the 17/17 above). Reads `ios/Fixtures/validation-boundaries.json` and `parity.json`; both must stay byte-identical. | none planned |

## 3. Appendix: every other tracked path

Generated by `/private/tmp/claude-501/-Users-raoof-r12-Desktop-Raouf-FORMA/6579168c-3de8-48aa-af7f-14684a9fc609/scratchpad/gen.py` from `git ls-files`. 1,453 paths, each with a classification and a reason derived from its path and role. These files were **not** read line by line.

### Root files and repository configuration (21)

| Path | Classification | Reason |
| --- | --- | --- |
| `.env.example` | not relevant | web/server environment template; no native use; unchanged |
| `.github/dependabot.yml` | not relevant | dependency update policy for the web project; unchanged |
| `.github/workflows/ci.yml` | not relevant | web/server CI; no `ios/` reference (grep); unchanged |
| `.gitignore` | preserve | repository ignore rules; ios has its own `ios/.gitignore`; unchanged |
| `.gitleaksignore` | not relevant | secret-scan allowlist for the production repo; unchanged |
| `AGENT.md` | preserve | repository operating protocol and change history; not edited by this audit (the lead appends the Commit 2 entry at commit time) |
| `CHANGELOG.md` | preserve | change log; its 27 Oct entry is the performance-audit evidence cited above; not edited by this audit |
| `CONTRIBUTING.md` | not relevant | contributor guide for the web project; unchanged |
| `README.md` | not relevant | root project README (production web); unchanged |
| `SECURITY.md` | not relevant | security policy for the production service; unchanged |
| `eslint.config.js` | not relevant | web lint config; does not lint Swift; unchanged |
| `index.html` | not relevant | Vite web entry page; unchanged |
| `package-lock.json` | preserve | npm lockfile keying CI cache and `npm ci` for native resource checks; unchanged |
| `package.json` | preserve | dependency and script manifest; `npm ci` source for the generator and native JS tests; unchanged |
| `playwright.accounts.config.js` | not relevant | web account browser-test config; unchanged |
| `playwright.config.js` | not relevant | web browser-test config; unchanged |
| `playwright.production.config.js` | not relevant | production-build browser-test config; unchanged |
| `tsconfig.json` | not relevant | web TypeScript config; unchanged |
| `tsconfig.server.json` | not relevant | server TypeScript build config; unchanged |
| `vite.config.js` | not relevant | web build config; unchanged |
| `wrangler.jsonc` | not relevant | Cloudflare Worker production config; must not change in a native commit |

### `src/` (production web source) (63)

| Path | Classification | Reason |
| --- | --- | --- |
| `src/App.jsx` | not relevant | production web application source or stylesheet; outside native scope; unchanged |
| `src/account.css` | not relevant | production web account/cloud-sync code; native app is guest-only; unchanged |
| `src/account/AccountProvider.jsx` | not relevant | production web account/cloud-sync code; native app is guest-only; unchanged |
| `src/account/client.js` | not relevant | production web account/cloud-sync code; native app is guest-only; unchanged |
| `src/account/cloudRepository.js` | not relevant | production web account/cloud-sync code; native app is guest-only; unchanged |
| `src/brand-motion.css` | preserve | web brand motion styles, the web counterpart of native motion; read-only parity reference; unchanged |
| `src/catalog/animations.json` | not relevant | web catalogue data/helper not consumed by the native generator; unchanged |
| `src/catalog/curation.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/curation.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/demos.json` | not relevant | web catalogue data/helper not consumed by the native generator; unchanged |
| `src/catalog/equipment-corrections.json` | not relevant | web catalogue data/helper not consumed by the native generator; unchanged |
| `src/catalog/exercises.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/instructions.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/logging-review.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/machine-exercises.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/media.json` | not relevant | web catalogue data/helper not consumed by the native generator; unchanged |
| `src/catalog/programming-aliases.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/catalog/search.js` | not relevant | web catalogue data/helper not consumed by the native generator; unchanged |
| `src/catalog/unilateral.json` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/components/Account.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ActionsMenu.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/BrandMark.jsx` | preserve | source of the three-facet F that `FormaMark` and the icon reproduce; read-only parity reference; unchanged |
| `src/components/ErrorBoundary.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ExerciseAnimation.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ExerciseDemo.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ExerciseGuide.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ExerciseMedia.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/ExercisePicker.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/GuideInstructions.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/HistoryEditor.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/HoldTimer.jsx` | preserve | web hold timer that `HoldTimer.swift` mirrors; read-only parity reference; unchanged |
| `src/components/Insights.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Legal.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Library.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Loading.jsx` | preserve | web loading state, the web counterpart of the native loading screen; read-only parity reference; unchanged |
| `src/components/Navigation.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Notification.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Overview.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Preferences.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Recovery.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/RoutineCardOrder.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/RoutinePrescription.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/RoutinePrescriptions.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/RoutinePreview.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Routines.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/SavedField.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/UI.jsx` | not relevant | production web UI component; outside native scope; unchanged |
| `src/components/Workout.jsx` | preserve | web workout screen whose rules the native logger mirrors; read-only parity reference; unchanged |
| `src/data.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/exerciseLoad.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/exerciseMetrics.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/hooks/useNavigation.js` | not relevant | production web React hook; outside native scope; unchanged |
| `src/hooks/useWorkoutStore.js` | not relevant | production web React hook; outside native scope; unchanged |
| `src/legal/content.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/main.jsx` | not relevant | production web application source or stylesheet; outside native scope; unchanged |
| `src/persistence.js` | not relevant | production web application source or stylesheet; outside native scope; unchanged |
| `src/routineProgramming.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/storage.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/styles.css` | not relevant | production web application source or stylesheet; outside native scope; unchanged |
| `src/timedHolds.js` | preserve | shared web contract module reviewed on 23 Oct but not hash-pinned by the generator; read-only parity reference; unchanged |
| `src/workout-history.css` | not relevant | production web application source or stylesheet; outside native scope; unchanged |
| `src/workoutSession.js` | validate | input hash-pinned in `resource-manifest.json` (hash verified now); web source of truth for the native catalogue and contract; unchanged |
| `src/workoutTemplates.js` | not relevant | production web application source or stylesheet; outside native scope; unchanged |

### `server/` (Fastify and PostgreSQL) (32)

| Path | Classification | Reason |
| --- | --- | --- |
| `server/app.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/auth.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/coachRoutes.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/coachTokens.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/config.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/email-template.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/email.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/index.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/migrate.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/migrations/0001-auth.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/migrations/0002-workspace.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/migrations/0003-security-throttle.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/migrations/0004-routine-programming.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/migrations/0005-coach-tokens.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/migrations/0006-coach-token-scope.sql` | not relevant | PostgreSQL migration for the production API; must not change in a native commit |
| `server/schema.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/securityEvents.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/tests/auth.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/coach-summary.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/coach.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/email-template.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/email.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/programming-migration.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/programming.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/redteam.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/security-events.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/security.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/session-step-up.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/tests/workspace.test.ts` | not relevant | Fastify/PostgreSQL server test; outside native scope; unchanged |
| `server/throttle.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/workspace.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |
| `server/workspaceRoutes.ts` | not relevant | production API server source (Fastify/PostgreSQL); must not change in a native commit |

### `worker/` (Cloudflare Worker) (4)

| Path | Classification | Reason |
| --- | --- | --- |
| `worker/index.ts` | not relevant | production Cloudflare Worker source; must not change in a native commit |
| `worker/tests/coach.test.ts` | not relevant | Cloudflare Worker test; outside native scope; unchanged |
| `worker/tests/gateway.test.ts` | not relevant | Cloudflare Worker test; outside native scope; unchanged |
| `worker/tests/redteam.test.ts` | not relevant | Cloudflare Worker test; outside native scope; unchanged |

### `ops/` (operations) (21)

| Path | Classification | Reason |
| --- | --- | --- |
| `ops/Dockerfile` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/Dockerfile.dockerignore` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/account-operations.py` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/backup-postgres.sh` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/bootstrap-db-roles.sh` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/bootstrap-db-roles.sql` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/compose.production-host.yaml` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/compose.small-host.yaml` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/compose.yaml` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/dashboard-client.js` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/dashboard-page.mjs` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/dashboard.mjs` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/dashboard.test.mjs` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/edge-monitor.mjs` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/edge-monitor.test.mjs` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/grant-runtime-access.sh` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/grant-runtime-access.sql` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/restore-postgres.sh` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/test_operations.py` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/wrangler.dashboard.jsonc` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |
| `ops/wrangler.monitor.jsonc` | not relevant | production operations tooling (containers, backups, monitors, dashboard); must not change in a native commit |

### `scripts/` (web tooling) (21)

| Path | Classification | Reason |
| --- | --- | --- |
| `scripts/accounts-test-server.ts` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/audit-exercise-equipment.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/build-catalog-curation.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/build-dashboard.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/build-exercise-demos.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/build-exercise-media.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/check-docs.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/check-exercise-media.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/deploy-public.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/exercise-measurement.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/exercise-svg/build.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/core.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/exercises.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/legs.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/legs_b.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/rig.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/exercise-svg/upper_b.py` | not relevant | web exercise-illustration build script (Python); unchanged |
| `scripts/import-exercises.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/register-exercise-atlas.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/snapshot-current-exercises.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |
| `scripts/test-account-browsers.mjs` | not relevant | web build, catalogue, deploy or test tooling; not used by the native generator; unchanged |

### `tests/` (Playwright) (42)

| Path | Classification | Reason |
| --- | --- | --- |
| `tests/accessibility.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-auth-controls.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-auth-focus.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-coach.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-conflicts.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-lifecycle.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-loading.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-security.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-sign-out.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-ui.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/accounts-workouts.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/catalog-alias-editor.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/catalog-quality.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/catalog.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/exercise-media.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/helpers.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/hold-metric-migration.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/keyboard-focus.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/legal.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/navigation-release.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/no-load-hold-timer.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/persistence-release.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/persistence.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/production.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/regressions.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/responsive.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-archive.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-card-drag.helpers.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-card-drag.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-drag-touch.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-drag.helpers.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-drag.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-library.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-preview.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/routine-programming.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/security-release.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/timed-hold-switch.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/ui-controls.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/ui-coverage-gaps.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/workflows.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/workout-editing.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |
| `tests/workout-release.spec.js` | not relevant | Playwright browser test for the web app; outside native scope; unchanged |

### `unit/` (Node tests) (20)

| Path | Classification | Reason |
| --- | --- | --- |
| `unit/catalog-curation.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/catalog.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/cloud-export.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/cloud-repository.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/docs-check.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/domain-release.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/exercise-animations.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/exercise-demos.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/exercise-import.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/exercise-load.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/exercise-previews.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/hold-metric-migration.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/persistence-release.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/persistence.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/redteam-release.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/routine-programming.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/security-release.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/storage.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/timed-hold-switch.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |
| `unit/workout-session.test.js` | not relevant | Node unit test for web/server code; outside native scope; unchanged |

### `docs/` excluding research and QA (60)

| Path | Classification | Reason |
| --- | --- | --- |
| `docs/accounts-infrastructure.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/accounts/README.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/api.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/backup-public-keys/production.pem` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/backup-public-keys/staging.pem` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/backup-restore-evidence.json` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/container-evidence.json` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/database.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-domain-onboarding.json` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-previews/README.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-previews/change-email.html` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-previews/delete-account.html` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-previews/reset-password.html` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/email-previews/verify-email.html` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/handoff.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/mail-delivery-test.json` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/operations.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/production-launch.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/release-readiness.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/runtime-role-evidence.json` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/accounts/sources.md` | not relevant | production accounts documentation or evidence; unchanged |
| `docs/architecture.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/audit-fixes.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/backend-audit.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/cloud-environment.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/cloud-ssh-access.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/data-model.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/deployment.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/design-concept.png` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/desktop-preview.png` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/frontend-design-audit.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/getting-started.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/legal/README.md` | not relevant | web legal documentation; unchanged |
| `docs/live-catalog-release.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/member-data-sync.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/mobile-preview.png` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/research.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/routine-programming-v2.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/security/README.md` | not relevant | production security documentation; unchanged |
| `docs/security/asvs-l2-mapping.csv` | not relevant | production security documentation; unchanged |
| `docs/security/authentication.md` | not relevant | production security documentation; unchanged |
| `docs/security/authorisation.md` | not relevant | production security documentation; unchanged |
| `docs/security/cloudflare.md` | not relevant | production security documentation; unchanged |
| `docs/security/database-security.md` | not relevant | production security documentation; unchanged |
| `docs/security/deployment-record.md` | not relevant | production security documentation; unchanged |
| `docs/security/droplet-hardening.md` | not relevant | production security documentation; unchanged |
| `docs/security/incident-response.md` | not relevant | production security documentation; unchanged |
| `docs/security/penetration-test-report.md` | not relevant | production security documentation; unchanged |
| `docs/security/privacy.md` | not relevant | production security documentation; unchanged |
| `docs/security/release-security-verdict.md` | not relevant | production security documentation; unchanged |
| `docs/security/security-coverage-matrix.csv` | not relevant | production security documentation; unchanged |
| `docs/security/standards-and-scope.md` | not relevant | production security documentation; unchanged |
| `docs/security/supply-chain.md` | not relevant | production security documentation; unchanged |
| `docs/security/threat-model.md` | not relevant | production security documentation; unchanged |
| `docs/superpowers/plans/2026-10-12-release-readiness.md` | not relevant | web accounts planning document; unchanged |
| `docs/superpowers/plans/2026-10-12-self-hosted-accounts.md` | not relevant | web accounts planning document; unchanged |
| `docs/superpowers/specs/2026-10-12-accounts-design.md` | not relevant | web accounts planning document; unchanged |
| `docs/testing.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/user-guide.md` | not relevant | production web/server/ops documentation or preview image; unchanged |
| `docs/verification.md` | not relevant | production web/server/ops documentation or preview image; unchanged |

### `docs/research/` (264)

| Path | Classification | Reason |
| --- | --- | --- |
| `docs/research/README.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/brand-motion.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/catalog-import.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/catalog-quality-summary.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/catalog-quality.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/current-wger-additions.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/equipment-catalog.csv` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-candidates.csv` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-logging-review.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-logging-review.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-media-free-fetches.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-media-free-review.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photo-expanded-fetches.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photo-expanded-inventory.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photo-inventory.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photo-source-fetches.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photos-more.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-photos.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-quality-review.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-videos.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/exercise-videos/registry.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/implementation-roadmap.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/machine-coverage.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/machine-source-fetches.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/original-art/README.md` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-a-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-a-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-b-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-b-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-c-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-c-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-d-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/authored-guide-replacements.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/cable-config-01.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/cardio-01.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-004.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-005.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-006.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-007.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-008.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-009.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-010.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-011.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-012.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-013.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-014.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-015.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-016.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-017.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-018.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-019.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-020.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-021.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-022.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-023.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-024.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-025.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-026.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-027.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-028.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-029.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-030.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-031.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-032.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-033.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-034.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-035.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-036.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-037.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-038.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-039.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-040.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/corrections-041.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/coverage.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/equipment-compatibility-reviews.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-a-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-a-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-a-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-a-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-b-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-b-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-b-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-b-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-c-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-c-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-c-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-d-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-d-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-d-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-e-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-e-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-e-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-f-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-f-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-f-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-f-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-grip-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-grip-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-grip-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-laterality-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-001-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-002-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-004-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-004.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-005-retry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-solo-005.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/finish-source-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/foundations-01.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/generation-queue.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/machines-03.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/machines-04.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/machines-05.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-004.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-005.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-006.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-007.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-008.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-009.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-010.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-011.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-012.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-013.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-014.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-015.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-016.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-017.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-018.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-019.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-020.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-021.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-022.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-023.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-024.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-025.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-026.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-027.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-028.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-029.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-030.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-031.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-032.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-033.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-034.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-035.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-036.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-037.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-038.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-039.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-040.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-041.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-042.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-043.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-044.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-045.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-046.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-047.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-048.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-049.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-050.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-051.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-052.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-053.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-054.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-055.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-056.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-057.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-058.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-059.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-060.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-061.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-062.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-063.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-064.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-065.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-066.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-067.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-068.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-069.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-070.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-071.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-072.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-073.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-074.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-075.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-076.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-077.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-078.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-079.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-080.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-081.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-082.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-083.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-084.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-085.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-086.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-087.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-088.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-089.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-090.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-091.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-092.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-093.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-094.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-095.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-096.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-097.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-098.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/movements-099.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-a-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-a-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-a-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-a-004.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-b-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-b-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-b-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-b-004.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-c-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-c-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-c-003.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-d-001.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-d-002.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-decline-040.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/recovery-state.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/registry.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata-followup.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata-recovery.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-00eae665-ff78-4373-9c43-f44a4a1b43e0.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-12a80404-8684-4ff0-a473-d80b4ad8cd5e.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-148f2ffc-05e2-486b-874f-2a401337a1c6.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-33a55e1a-ff83-4c34-b056-887a121b0978.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-346634cf-3896-4c10-bd66-28fb69d02573.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-36a309ba-7dd1-43c9-9efc-788c7cd9fbd6.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-4b23738a-67a8-41af-996d-abc53a7c3f97.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-4c317795-c301-4081-9f96-6036682f80c1.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-5ed12527-c8be-4e86-8f2a-cf9dd4781f5b.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-5edf07a8-cca2-4199-96a5-9988369be985.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-671568f9-6653-4e11-ac71-3f34c74329a0.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-77c98954-b50d-46f0-9912-3981f856d5a6.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-7870ad8d-a0c1-4e3a-a4fe-a237908eba9b.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-81dd44b3-67b3-4198-9e57-c2a80b3c4102.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-a94c635d-096c-45a8-a68c-64941d0b6ba4.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-abdd2b41-0c30-4ec1-8d14-f6dc5deb3561.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-ca514fad-c6ce-47b0-93a0-dc73a3507099.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-caccd791-ff30-452a-816e-790edadb78cd.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-d015a276-02ad-4c28-9d36-aedfbb431f53.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-d27a93fa-7066-477c-a475-c6b6170831db.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-d561c00c-436d-47d9-b647-222e7b637abd.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/original-art/source-metadata/wger-eaa7927e-6ea0-4fd5-bbcd-525fe90a184b.api.json` | not relevant | web original-art research record or metadata; unchanged |
| `docs/research/reviewed-guide-repairs.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/reviewed-machine-additions.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/runtime-catalog.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/site-visuals/routine-photos.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/site-visuals/training-hero.json` | not relevant | web research or provenance record; unchanged |
| `docs/research/sources.md` | not relevant | web research or provenance record; unchanged |
| `docs/research/workout-formats.md` | not relevant | web research or provenance record; unchanged |

### `docs/qa/` (186)

| Path | Classification | Reason |
| --- | --- | --- |
| `docs/qa/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-auth-research.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-independent-review.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-guest-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-guest-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-privacy-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-privacy-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-security-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-security-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-training-data-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/account-training-data-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/mail-change-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/mail-delete-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/mail-verify-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/privacy-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/privacy-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/profile-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/profile-320.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/security-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/security-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/training-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-screenshots/training-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-security.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/accounts-ui-inventory.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/artwork-recovery-checks.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/coach-tokens/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/coach-tokens/deployment.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/control-crosswalk.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/defects.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/function-matrix.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/holds-timer/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/holds-timer/api-release.sh` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/hosted-ci-evidence.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/independent-review.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/interaction-matrix.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/progress.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/release-readiness.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/reproduction-evidence.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-programming-v2/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-programming-v2/deployment.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-programming-v2/gateway-checks.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-programming-v2/live-asset-hashes.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-programming-v2/live-browser-layouts.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-after.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-before.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-drag.webm` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-during.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-library-selection.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/desktop-lime-loading.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/live-build-investigation.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-after.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-before.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-drag.webm` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-during.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-library-selection.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/phone-lime-loading.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/restored-visual-checks.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/routine-row-drag/visual-checks.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/runtime-controls.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/sign-out/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/sign-out/deployment.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accessibility-audit.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accessibility-green.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accessibility-red.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accessibility-repairs.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accessibility-sources.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/account-import-focus.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/captures.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/checks.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/report.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-login.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-profile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-register.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-reset.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-security.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-desktop-workspace.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-login.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-profile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-register.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-reset.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-security.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/site-sweep-accounts-mobile-workspace.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/accounts/summary.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after-captures.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/account-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/account-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/active-workout-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/active-workout-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/guide-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/guide-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/history-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/history-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/library-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/library-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/privacy-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/privacy-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/progress-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/progress-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/settings-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/settings-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/terms-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/terms-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/workout-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/after/workout-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/auth-focus-fixture-green.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/auth-focus-green.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/auth-focus-red.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before-captures.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/account-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/account-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/active-workout-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/active-workout-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/guide-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/guide-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/history-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/history-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/overview-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/overview-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/privacy-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/privacy-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/progress-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/progress-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/routines-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/routines-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/settings-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/settings-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/terms-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/terms-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/workout-desktop.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/before/workout-mobile.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/browser-baseline.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/browser-baseline.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/build.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/guide-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/guide-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/home-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/home-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/live-asset-hashes.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/live-smoke.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/live-smoke.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/production-final.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/production-initial.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/signup-1536.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/signup-390.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/staging-final.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/staging-initial.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/worker-green.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/deployment/worker-red.log` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/docs.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/format.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/functional-review.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/guest-replay.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/guest-summary.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/guest-system-browser-run.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/image-after.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/image-baseline.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/legal-final.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/legal-phone-geometry-before.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/legal-phone-visibility-red.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/lint.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/media-strict.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/performance-audit.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/performance-sources.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/playwright-source.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/preview-measurements.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/production.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/summary.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/types.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/unit.txt` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/desktop-detail-0-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/desktop-detail-2-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/desktop-overview-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/desktop-routines-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/mobile-detail-0-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/mobile-detail-2-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/mobile-overview-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/mobile-routines-refined.png` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/visuals/results.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/site-sweep/watcher-after.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/source-inventory.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/verification-results.json` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/workout-coach/README.md` | not relevant | web QA screenshot or evidence file; unchanged |
| `docs/qa/workout-coach/deployment.json` | not relevant | web QA screenshot or evidence file; unchanged |

### `assets/` (213)

| Path | Classification | Reason |
| --- | --- | --- |
| `assets/exercise-artwork/authored-a-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-a-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-b-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-b-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-c-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-c-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/authored-d-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/cable-config-01.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/cardio-01.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-004.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-005.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-006.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-007.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-008.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-009.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-010.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-011.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-012.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-013.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-014.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-015.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-016.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-017.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-018.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-019.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-020.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-021.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-022.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-023.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-024.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-025.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-026.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-027.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-028.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-029.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-030.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-031.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-032.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-033.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-034.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-035.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-036.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-037.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-038.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-039.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-040.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/corrections-041.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-a-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-a-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-a-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-a-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-b-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-b-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-b-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-b-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-c-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-c-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-c-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-d-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-d-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-d-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-e-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-e-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-e-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-f-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-f-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-f-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-f-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-grip-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-grip-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-grip-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-laterality-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-001-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-002-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-004-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-004.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-005-retry.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-solo-005.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/finish-source-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/foundations-01.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/machines-03.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/machines-04.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/machines-05.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-004.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-005.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-006.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-007.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-008.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-009.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-010.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-011.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-012.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-013.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-014.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-015.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-016.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-017.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-018.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-019.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-020.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-021.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-022.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-023.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-024.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-025.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-026.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-027.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-028.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-029.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-030.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-031.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-032.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-033.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-034.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-035.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-036.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-037.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-038.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-039.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-040.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-041.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-042.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-043.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-044.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-045.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-046.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-047.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-048.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-049.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-050.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-051.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-052.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-053.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-054.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-055.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-056.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-057.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-058.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-059.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-060.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-061.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-062.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-063.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-064.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-065.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-066.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-067.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-068.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-069.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-070.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-071.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-072.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-073.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-074.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-075.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-076.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-077.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-078.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-079.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-080.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-081.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-082.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-083.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-084.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-085.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-086.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-087.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-088.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-089.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-090.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-091.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-092.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-093.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-094.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-095.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-096.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-097.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-098.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/movements-099.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-a-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-a-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-a-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-a-004.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-b-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-b-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-b-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-b-004.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-c-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-c-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-c-003.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-d-001.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-d-002.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-artwork/recovery-decline-040.png` | not relevant | web exercise artwork source; unchanged |
| `assets/exercise-svg/README.md` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/exercise-svg/core/key-poses.png` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/exercise-svg/legs-a/key-poses.png` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/exercise-svg/legs-b/key-poses.png` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/exercise-svg/upper-a/key-poses.png` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/exercise-svg/upper-b/key-poses.png` | not relevant | web exercise-illustration source SVG; unchanged |
| `assets/site-visuals/routine-photos-original.png` | not relevant | web site-visual source asset; unchanged |
| `assets/site-visuals/routine-photos-unmarked.png` | not relevant | web site-visual source asset; unchanged |
| `assets/site-visuals/routine-photos.webp` | not relevant | web site-visual source asset; unchanged |
| `assets/site-visuals/training-hero-original.png` | not relevant | web site-visual source asset; unchanged |
| `assets/site-visuals/training-hero.webp` | not relevant | web site-visual source asset; unchanged |

### `public/` (506)

| Path | Classification | Reason |
| --- | --- | --- |
| `public/exercise-animations/ab-roller-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/ab-roller.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-bench-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-bench-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-hip-thrust-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-hip-thrust.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-step-ups-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/barbell-step-ups.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/bicycle-crunch-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/bicycle-crunch.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/cable-rope-overhead-triceps-extension-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/cable-rope-overhead-triceps-extension.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/cross-body-hammer-curl-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/cross-body-hammer-curl.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-goblet-squat-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-goblet-squat.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-lateral-raise-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-lateral-raise.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-reverse-lunge-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-reverse-lunge.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-side-bend-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/dumbbell-side-bend.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/face-pull-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/face-pull.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/incline-dumbbell-curl-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/incline-dumbbell-curl.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/incline-dumbbell-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/incline-dumbbell-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-extensions-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-extensions.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-presses-wide-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leg-presses-wide.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leverage-decline-chest-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leverage-decline-chest-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leverage-shoulder-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/leverage-shoulder-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/lying-leg-curls-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/lying-leg-curls.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/machine-bench-press-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/machine-bench-press.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/one-arm-dumbbell-row-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/one-arm-dumbbell-row.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/plank-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/plank.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/plate-loaded-lat-pulldown-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/plate-loaded-lat-pulldown.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/romanian-deadlift-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/romanian-deadlift.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-barbell-twist-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-barbell-twist.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-cable-row-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-cable-row.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-calf-raise-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-calf-raise.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-leg-curl-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/seated-leg-curl.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/split-squat-with-dumbbells-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/split-squat-with-dumbbells.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/standing-calf-raise-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/standing-calf-raise.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/wide-grip-lat-pulldown-still.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-animations/wide-grip-lat-pulldown.svg` | not relevant | production web asset: exercise animation; unchanged |
| `public/exercise-demos/army-combat-fitness-test-3-repetition-maximum-deadlift-mdl-e.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/army-combat-fitness-test-3-repetition-maximum-deadlift-mdl-e.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/army-combat-fitness-test-standing-power-throw-spt-event-2.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/army-combat-fitness-test-standing-power-throw-spt-event-2.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/bench-press-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/bench-press-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/bent-over-row-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/bent-over-row-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/conditional-drill-tuck-jump.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/conditional-drill-tuck-jump.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/deadlift-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/deadlift-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/hip-sled-calf-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/hip-sled-calf-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/hip-sled-how-to-perform-a-45-degree-leg-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/hip-sled-how-to-perform-a-45-degree-leg-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/incline-press-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/incline-press-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-bicep-curls.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-bicep-curls.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-overhead-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-overhead-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-superman.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-home-superman.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-back-extension.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-back-extension.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-chest-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-chest-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-leg-curl.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-leg-curl.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-leg-extension.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-leg-extension.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-overhead-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-overhead-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-row-machine.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/muscle-strengthening-at-the-gym-row-machine.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/pull-ups-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/pull-ups-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/shoulder-press-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/shoulder-press-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/squat-exercise-demonstration-video.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/squat-exercise-demonstration-video.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/strength-training-circuit-overhead-push-press.jpg` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-demos/strength-training-circuit-overhead-push-press.mp4` | not relevant | production web asset: exercise demo; unchanged |
| `public/exercise-media/original/authored-a-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-a-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-b-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-b-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-c-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-c-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/authored-d-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/cable-config-01.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/cardio-01.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-004.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-005.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-006.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-007.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-008.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-009.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-010.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-011.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-012.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-013.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-014.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-015.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-016.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-017.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-018.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-019.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-020.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-021.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-022.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-023.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-024.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-025.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-026.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-027.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-028.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-029.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-030.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-031.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-032.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-033.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-034.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-035.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-036.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-037.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-038.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-039.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-040.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/corrections-041.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-a-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-a-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-a-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-a-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-b-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-b-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-b-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-b-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-c-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-c-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-c-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-d-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-d-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-d-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-e-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-e-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-e-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-f-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-f-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-f-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-f-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-grip-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-grip-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-grip-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-laterality-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-001-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-002-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-004-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-004.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-005-retry.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-solo-005.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/finish-source-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/foundations-01.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/machines-03.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/machines-04.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/machines-05.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/mobility-01.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-004.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-005.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-006.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-007.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-008.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-009.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-010.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-011.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-012.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-013.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-014.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-015.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-016.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-017.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-018.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-019.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-020.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-021.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-022.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-023.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-024.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-025.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-026.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-027.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-028.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-029.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-030.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-031.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-032.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-033.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-034.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-035.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-036.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-037.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-038.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-039.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-040.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-041.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-042.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-043.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-044.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-045.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-046.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-047.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-048.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-049.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-050.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-051.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-052.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-053.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-054.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-055.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-056.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-057.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-058.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-059.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-060.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-061.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-062.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-063.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-064.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-065.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-066.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-067.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-068.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-069.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-070.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-071.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-072.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-073.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-074.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-075.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-076.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-077.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-078.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-079.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-080.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-081.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-082.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-083.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-084.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-085.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-086.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-087.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-088.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-089.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-090.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-091.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-092.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-093.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-094.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-095.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-096.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-097.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-098.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/movements-099.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-a-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-a-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-a-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-a-004.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-b-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-b-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-b-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-b-004.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-c-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-c-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-c-003.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-d-001.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-d-002.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/recovery-decline-040.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/specialist-machines-01.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/original/specialist-machines-02.png` | not relevant | production web asset: original exercise media; no web photographs are bundled natively; unchanged |
| `public/exercise-media/previews/authored-a-001-7a9ea285cb29df52.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/authored-a-001-retry-11584f1d40205695.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/authored-b-001-9489e35d1c4b5f36.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/authored-b-001-retry-e13250547580ec63.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/authored-c-001-retry-26d4d35ce665fb6c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/authored-d-001-15f155b162b97a8d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/cable-config-01-1ae906d3c7aba136.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/cardio-01-5c38f1ac06c14b8d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-001-d8f73f2ae7c3ccac.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-002-bd45875b554129c7.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-003-21933c3822621ed5.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-004-9a386c44d5e68db6.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-005-95b4da7f1f1f29d5.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-006-f3dd3a20d88dcf24.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-007-340f157de6e0b24b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-008-c96ffce317cb0e6f.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-009-8edb6abaa484ea4f.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-010-4724753fb4452391.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-011-ab470c2515602a15.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-012-a1816bc550a3fa51.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-013-17c45ffa627a2766.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-014-5d737d12b92b4bb2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-015-5151f2c91724acd2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-016-e0cdf6b1cd6c5ca2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-017-7a3d916c2e59e5b7.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-018-4bd41cba6cb08048.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-019-6f53ded4593356b5.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-020-577d0b0145faee3b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-021-1f0d0f531f19ecd3.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-022-84335791c17f819d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-023-0fb965e47cbfd5d9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-024-17db4cfd393e7942.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-025-f4716bc144d53d0b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-026-aa4f844c5aaca7ec.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-027-0b5f26a283e504be.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-028-902a8be142d385da.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-029-08959f94fefe2baf.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-030-0fe1c58de0eef1c2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-031-89f00d399790da8a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-032-3f72d4124d464e14.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-033-590153bc3c2a0432.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-034-705fda3e8d4f6de0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-035-c5ad4bec7afd40d1.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-036-d1a247e2c52180b0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-037-443dc0404e8e1688.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-038-0a569d98978a8025.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-039-7fe91c6f901067f6.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-040-3824add5d40e939a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/corrections-041-69a4e9ab598668ae.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-a-001-8c40ffd12cab34c4.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-a-001-retry-ca409ee6f2a9202b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-a-002-f92a4aa16350a09f.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-a-002-retry-025b79e15148a078.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-b-001-07363809c230f621.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-b-001-retry-c4371e6e6814e609.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-b-002-27461702eab4637e.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-b-002-retry-11dab6c5c3efb04c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-c-001-d8d98569b777155b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-c-002-834dc8dd1f0167c6.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-c-002-retry-c2ddc7fb27ea2e50.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-d-001-82441ca88f779557.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-d-002-7e228af2d9c7d175.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-d-002-retry-af33733ba3fd4b60.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-e-001-cb070cfffcaecb0c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-e-001-retry-fce95115d68afce2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-e-002-ab9f83be5e78c429.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-f-001-b62c16aaca33c976.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-f-002-retry-63792097573fe538.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-grip-001-528e1330cfd428cb.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-grip-002-retry-70eebfd33b4e4e2f.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-laterality-001-0e19348848fc51d9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-solo-001-retry-20ef2b5ecc9188c0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-solo-002-retry-a34cc78cd9724c80.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-solo-003-1e2b19b7b48a957e.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-solo-004-retry-65bed2132fc603cb.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-solo-005-retry-62a36931a5fa624b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/finish-source-001-54bce32c842c58c8.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/foundations-01-d3c7fa204e498922.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/machines-03-988892f417205330.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/machines-04-e1095f31c69951f0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/machines-05-947e43ec890a46cb.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/mobility-01-141a68d883c6178a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-001-76e92487b9f2bd81.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-002-7dde04a79fbf6152.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-003-a6ce13c5e6060df5.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-004-ff86fb57eace6bac.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-005-4ad37f7c3e6d67b9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-006-a2897eb6c83fe202.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-007-4f269d0919bf990a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-008-010bc0ce2e4b0d44.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-009-013b7c93a1b375af.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-010-6fc26a4d2d06dc43.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-011-94e7e53b16217c67.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-012-fcf00a71824d5abc.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-013-dba2148a2a20bcb0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-014-f4b9166a5c0ec6e3.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-015-0321956c8ab8db67.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-016-eed742844a788a2d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-017-b15149e83c4a02bf.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-018-95290cdcf0660d8c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-019-91778cf30dc2e14c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-020-08a990bc753ff8b9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-021-be4271167b4fc45d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-022-deb6342a28180e62.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-023-cea901efd069d343.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-024-d8cc649fe6a33e2b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-025-e1a3f9ee5b8a4cb8.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-026-db4e45c075c5cbcd.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-027-82d5a68257a25023.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-028-1b7c1c6ba15380e9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-029-956a55c0fa79d2ff.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-030-935c2a205a603da1.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-031-dec300744899614b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-032-f07a18503673d2e2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-033-f00743369b43649a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-034-6f9dba311fb7b97d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-035-9c9d5f47316e7711.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-036-c3b9c61a09e9369f.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-037-b3eb1a189924b8e9.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-038-9fa0f4e63a0a4417.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-039-d4eb386b6d444bbe.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-040-ccd9d4260a0b5133.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-041-c7bc72a22484afb3.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-042-39496a4afed9956d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-043-49a1cabff9876876.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-044-71172476cc7ad670.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-045-930880fa79a4710a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-046-b31c5e0547918a8a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-047-57e6bb9b81d4607b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-048-f68942ee2edf142a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-049-d243d596440c9c37.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-050-d6c877c7775d8aaa.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-051-fd3b2b6613453ac2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-052-adc590f22287dc60.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-053-deb8caa7d56c5516.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-054-7d24a0f68053a73d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-055-da09038460d1713a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-056-c5c29101e2cdd31c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-057-1a86593670c972b3.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-058-fc6c5aad4b670454.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-059-8d04d12e6a9cea61.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-060-0821ed1a155ff108.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-061-fbf7af2b431cad61.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-062-b73d32db35d46f10.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-063-0fa7b2b2a53f309d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-064-34bc25816194a2fc.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-065-bb5f341f4696a26e.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-066-dc50816424ccb3ea.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-067-606df93cc44482cc.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-068-f2e675161f7a323a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-069-6a54eb2dd26ace85.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-070-7d45b4685848e499.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-071-5a1b03dfd661e6dc.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-072-897c1dfff2a96af2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-073-7c6b64ef0fe1ce29.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-074-20029a3e18f5d109.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-075-e4383e4c25b03416.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-076-c051302a025b7626.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-077-9c3776b4777123be.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-078-332cc3cf40a9c99d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-079-372eb8c582a4fc3c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-080-76f0addca17a415a.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-081-dd6e0dcaa5c6c86d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-082-32b11e175542d05b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-083-70015d9bb0c30435.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-084-cff942e592496b3d.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-085-65ede4b15083d337.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-086-01cdac927bc05cb6.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-087-fa767745b65ec918.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-088-f644441ec95dbf26.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-089-adb5e2e529fa3f5c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-090-ce3e7987849cf751.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-091-2ed25223b684f250.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-092-023185ab7fdbfe08.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-093-edb60e6fd3623c24.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-094-81fa33f86de439ab.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-095-43b64f400ceed82c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-096-a74aeeb3f5376d37.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-097-c622bc4f7f60086b.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-098-fdb4e47ff86c59d6.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/movements-099-2345c30711f30f87.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/recovery-b-004-501910d3c5659f9c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/recovery-c-002-8d2530eb54a17a6c.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/recovery-d-001-a4bc2a7dee7b9ee2.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/specialist-machines-01-8f32dba667820fa0.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/exercise-media/previews/specialist-machines-02-e911692dc8b19857.webp` | not relevant | production web asset: exercise preview image; unchanged |
| `public/favicon.svg` | not relevant | production web static asset served by the Worker; unchanged |
| `public/fonts/barlow-condensed-700.woff2` | not relevant | production web font; native app uses system fonts; unchanged |
| `public/fonts/barlowcondensed-OFL.txt` | not relevant | production web font; native app uses system fonts; unchanged |
| `public/fonts/dm-sans-variable.woff2` | not relevant | production web font; native app uses system fonts; unchanged |
| `public/fonts/dmsans-OFL.txt` | not relevant | production web font; native app uses system fonts; unchanged |
| `public/images/routine-photos.webp` | not relevant | production web static asset served by the Worker; unchanged |
| `public/images/training-hero.webp` | not relevant | production web static asset served by the Worker; unchanged |

## 4. Completeness check

Every path in `git ls-files` (1,544) appears exactly once in Section 2 (91) or Section 3 (1,453): 91 + 1,453 = 1,544. The script re-reads this file after writing it, extracts the backticked path from the first cell of every table row in Sections 2 and 3, and compares that set with `git ls-files`. The result is reported in the hand-off for this task. This file itself is new and untracked, so it is not in the count.
