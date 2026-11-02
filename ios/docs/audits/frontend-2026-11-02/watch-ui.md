# FORMA Watch app: interface, motion and accessibility audit

2 November 2026. Read-only static review of `ios/FORMAWatch/WatchViews.swift`, `ios/FORMAWatch/WatchMotion.swift` and `ios/FORMAWatch/FORMAWatchApp.swift`, with `WorkoutManager.swift` read only for the phases the views show. Worktree `feat/watch-collected-data`. Watch target: watchOS 10.0 (`ios/project.yml:10`), built with the watchOS 26/27 SDK.

**Scope:** this review covers interface, layout, motion and accessibility. It leaves out everything in `ios/docs/audits/watch-battery-audit-2026-11-02.md`: send cadence, the heartbeat timer, the measuring-pulse cap, `prepare()` as a battery question, `Text(timerInterval:)`, the short-workout discard prompt, and debouncing the disconnect haptic.

**Limits:** nothing was run. The repo has no simulator setup (owner rule), and the Watch (reports `Watch7,12`; the case size is unconfirmed, possibly 41 or 42 mm) was not reachable. Every finding below comes from reading the code. Findings that need an on-device check say so.

**Method:** I loaded the `frontend-design` and `ui-ux-pro-max` skills. I ran `search.py --stack swiftui` and `--domain ux` for animation, touch, accessibility and haptics, then applied the `references/pro-rules.md` Pre-Delivery Checklist. I fetched Apple pages as `.md` from developer.apple.com and cross-read the research notes in `apple-watch-research-2026-11-02.md`.

---

## 1. Checklist: HIG areas for this slice

| Area | Result | Notes |
|---|---|---|
| Workout navigation: controls page left, metrics page, horizontal paging like Apple's Workout app | **Pass** | `WatchViews.swift:202-206` uses `TabView(selection:)` with `.page`, controls on the left and metrics as the default page. This is the arrangement the Workouts HIG shows (https://developer.apple.com/design/human-interface-guidelines/workouts). The HIG's general advice is vertical pagination (https://developer.apple.com/design/human-interface-guidelines/page-controls), but horizontal is right for a workout session. A Now Playing page is optional. |
| Distinct look for an active session | Pass (could go further) | A lime live timer and live values. Apple's examples also use a unique layout or background (L8). |
| Controls easy to find and tap; 44 pt targets | Pass, with a spacing caveat | Buttons are at least 48 pt (`:616`), Stop is 44×44 (`:266`) and the start disc is 112 pt. Pause and End are only 8 pt apart (M5). |
| Clear feedback when a session starts or stops | Pass | `sensoryFeedback` `.start`/`.stop`/`.success`/`.error` fires on confirmed phase changes (`:33-41`). `.start` is watchOS 10+ (https://developer.apple.com/documentation/swiftui/sensoryfeedback/start). |
| Countdown, compared with Apple's flow | **Fail** | The countdown runs before the session is created, so it warms nothing up. The Health permission prompt and a second "Starting…" wait come after "1" (H2). |
| Always On: consistent layout, controls shown as unavailable rather than removed | **Fail** | Start, Retry and Discard are removed on a dimmed wrist. The session swaps to a different layout without energy or Stop (M1). |
| Always On: motion settles, sub-second updates removed | Pass, with a regression | Every animation goes through `MotionGate`. Two views do not restart correctly when the wrist is raised (H1, M2). |
| Reduce Motion | Pass | Every effect is gated by `accessibilityReduceMotion` (`WatchMotion.swift:9-15`, `:211-216`). The countdown still counts and the haptic still plays. |
| Motion purpose and budget | Partial | The summary seal plus staggered reveal is a good single moment. The metrics page runs too many concurrent effects (M6). The ripple loops forever (L1). |
| Dynamic Type, largest sizes, 40–42 mm | **Needs a device check, likely fail** | The timer row and metric rows are `lineLimit(1)` with `minimumScaleFactor(0.6)` next to a fixed 44 pt button (M4). |
| Buttons: watchOS capsule, full-width primary, destructive in system red | Partial | Full-width 48 pt buttons with a 24 pt radius (capsule-like) pass. The custom style ignores `role: .destructive` (L3). |
| Liquid Glass on watchOS 26 | Acceptable, one improvement | No glass in the content layer is correct per the HIG. The pinned Done button should be a toolbar `.bottomBar` item so the system draws the glass (L4). `.glassProminent` is watchOS 26+ (https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent) and nothing uses it ungated. |
| Haptics | Pass | `.click` per count matches the HIG meaning: "communicate progress at predefined increments" (https://developer.apple.com/design/human-interface-guidelines/playing-haptics). Mixing `WKInterfaceDevice.play` with `sensoryFeedback` is fine; neither is deprecated. |
| VoiceOver: labels | Pass, with gaps | Live rows, the timer (spoken duration) and Stop have labels and hints, and decorative motion is hidden. Gaps are in L5. |
| VoiceOver: announcements (countdown, phase changes) | **Fail** | No announcements, and the countdown's tap-to-skip has no button trait (M3). |
| Contrast | Pass | Lime on black is 17.8:1. Ink on lime is 13.2:1. Red text on its 28% red fill is about 4.4–4.5:1, which passes as large text since the label is headline weight. Secondary on black is about 6.4:1. Dimmed Done (0.6) is 5.5:1. |
| API availability at watchOS 10 / no deprecated APIs | Pass | `phaseAnimator` (watchOS 10), `symbolEffect` `.bounce`/`.pulse` (watchOS 10, https://developer.apple.com/documentation/symbols/bouncesymboleffect), `numericText(countsDown:)` (watchOS 9), `sensoryFeedback` (watchOS 10), `.snappy`, `@Observable` and `TimelineView` are all within the floor. No `#available` is missing, and no deprecated API was found. `FORMAWatchApp` uses `WKApplicationDelegateAdaptor` (no `WKExtension`). |
| Copy | Pass, with small inconsistencies | The copy is plain and specific, and the Health-off explanations are good. Verbs vary (L9) and headings are hard-coded caps (L6). |

---

## 2. Findings

Severity counts: **High 2 · Medium 6 · Low 9.**

### HIGH

#### H1. The summary numbers and seal disappear if the summary first appears on a dimmed wrist

- **Where:** `WatchMotion.swift:209-225` (`Reveal`), `WatchMotion.swift:178-206` (`SummarySeal`).
- **Evidence:**
  ```swift
  let animates = !reduceMotion && !luminanceReduced
  content
    .opacity(shown || !animates ? 1 : 0)
    .offset(y: shown || !animates ? 0 : 8)
    .onAppear {
      guard animates, !shown else { return }
      withAnimation(.snappy(duration: 0.35).delay(0.45 + Double(order) * 0.12)) { shown = true }
    }
  ```
  `SummarySeal` uses the same pattern (`drawn || !animates`, and `onAppear` returns early when `!animates`).
- **What goes wrong:** say the summary appears while `isLuminanceReduced` is true. That happens when the person taps Finish on the iPhone with the wrist down, which is the normal way to end a FORMA workout (`apple-watch.md` step 4). It also happens if they drop the wrist during "Saving to Health…". `onAppear` runs while `animates == false`, so `shown` and `drawn` stay false and everything is visible. When the wrist is raised, `animates` becomes true, but `onAppear` does not run again. Opacity drops to 0, the time, heart rate and energy rows vanish, and the seal loses its ring and check. Only the headline, the footnote and Done remain. Reduce Motion being turned off while the summary is open does the same.
- **Apple guidance:** Always On HIG says "Maintain a consistent layout. Avoid making distracting interface changes when Always On begins or ends" (https://developer.apple.com/design/human-interface-guidelines/always-on). Workouts HIG says "A summary screen confirms that a workout is finished and displays the recorded information" (https://developer.apple.com/design/human-interface-guidelines/workouts).
- **Impact:** the end-of-workout confirmation shows no numbers. The logic is certain from the code; whether the summary renders while dimmed should be confirmed on the Watch.
- **Fix:** mark the reveal done whenever it cannot animate, so a later wake never hides content:
  ```swift
  .onAppear {
    if animates {
      withAnimation(.snappy(duration: 0.35).delay(0.45 + Double(order) * 0.12)) { shown = true }
    } else {
      shown = true // still states count as "already revealed"
    }
  }
  ```
  Do the same for `SummarySeal` (`drawn = true` in the `else`). Optionally add `.onChange(of: animates)` so the reveal plays on the first lit appearance. With the `else` branch in place, removing the `|| !animates` terms keeps one source of truth.

#### H2. The 3-2-1 countdown runs before the session starts, so the person counts down to a permission prompt and then waits again

- **Where:** `WatchViews.swift:70-79`, `WatchMotion.swift:91-105`, `WorkoutManager.swift:143-182`.
- **Evidence:**
  ```swift
  StartCountdown {
    countingDown = false
    Task { await manager.start() }   // auth, session, beginCollection only now
  }
  ```
  `start()` then calls `requestAuthorization` (the first-run Health sheet), creates the session, and the view shows `WatchLoadingMark(title: "Starting…", detail: "Getting your heart rate ready.")` (`WatchViews.swift:96-97`).
- **What goes wrong:** the countdown is a fixed 3 s delay that warms nothing up. On first run, the person sees 3, 2, 1, then a Health permission sheet. On later runs they see 3, 2, 1, then a second wait while the session and sensors start, and the `.start` haptic arrives some time after "1". Apple uses the countdown to hide sensor start-up: WWDC25 session 322 describes `prepare()`, then a three-second countdown "so on-device sensors start", then `startActivity`, then `beginCollection` (https://developer.apple.com/videos/play/wwdc2025/322/; research notes §2). The battery audit left `prepare()` open as a battery and keep-alive question. This finding is about order and wording.
- **Apple guidance:** Workouts HIG: "provide clear feedback that indicates when a session starts or stops" (https://developer.apple.com/design/human-interface-guidelines/workouts). Motion HIG: "Let people cancel motion… don't make people wait for an animation to complete" (https://developer.apple.com/design/human-interface-guidelines/motion).
- **Impact:** the countdown ends but nothing starts. On first run the person counts down into a permission dialog. Mid-set, that wasted time matters.
- **Fix (in order of effort):**
  1. Ask for authorization before the countdown. Split `start()` into `authorize() async -> Bool` (requestAuthorization plus the `sharingDenied` check) and `begin()`. The disc's action becomes `Task { if await manager.authorize() { countingDown = true } }`.
  2. Run the countdown alongside start-up. Begin session creation when the countdown begins, and call `startActivity`/`beginCollection` when it reaches zero, or immediately on tap-to-skip. If the owner later accepts `prepare()` after the device experiment, it belongs exactly here.
  3. If neither is wanted, drop the countdown. The "Starting…" heart screen already shows the wait truthfully.
  Also keep the countdown on screen until `phase` leaves `.idle`/`.ready` (see L7).

### MEDIUM

#### M1. Always On removes controls and changes the layout instead of dimming it

- **Where:** `WatchViews.swift:99` (`if !luminanceReduced { recoveryActions }`), `:142` (failed-recording buttons), `:159` (start disc / Try again), `:199-200` (session replaced by `AlwaysOnMetrics`), `:324-353` (no energy row, no Stop button, minutes instead of `m:ss`).
- **Evidence:**
  ```swift
  } else if luminanceReduced {
    AlwaysOnMetrics()      // different view tree: time, heart rate, connection only
  } else {
    TabView(selection: $page) { ... }
  ```
- **Apple guidance:** "when Always On begins, prefer transitioning an interactive component to an unavailable appearance — don't just remove it" and "Maintain a consistent layout" (https://developer.apple.com/design/human-interface-guidelines/always-on). Apple's developer article says "any controls in the user interface remain interactive… the system runs the associated action and transitions your app back to the active state" (https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state). The Workouts HIG lists calories burned among the data people care about during a session. The Always On HIG says people "appreciate getting pace and heart rate updates while they're working out".
- **Impact:** every wrist raise reflows the screen: Stop appears, the energy row appears, the timer changes format, and on the start screen the disc pops in. Active energy is never visible at a glance with the wrist down. The summary's Done button already does this correctly (`:572`, dimmed to 0.6).
- **Fix:** keep one view tree and change only the update cadence and emphasis. In `MetricsPage`, read `isLuminanceReduced` and:
  - keep `StopButton`, but `.opacity(0.5)` it and skip its fill when dimmed;
  - keep `EnergyRow`, sampled on the same minute tick (the battery decision stands);
  - render the time with the minute format, but in the same `Text` and slot as the live clock.
  On the start and recovery screens, keep the buttons and dim them, as Done does: `.opacity(luminanceReduced ? 0.5 : 1)`. Leave them tappable, since the system wakes the app and runs the action. If accidental starts are a worry, `.disabled(luminanceReduced)` still keeps the layout stable. Keeping the TabView mounted (only forcing `page = .metrics`) also avoids rebuilding it on every wrist drop.

#### M2. The loading ring stops spinning after the first wrist drop or Reduce Motion change

- **Where:** `WatchMotion.swift:124-147`.
- **Evidence:**
  ```swift
  if animates {
    Circle().trim(from: 0, to: 0.28) ...
      .rotationEffect(.degrees(spinning ? 360 : 0))
      .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spinning)
      .onAppear { spinning = true }
  }
  ```
  `spinning` is view state that is never reset. When the arc is re-inserted after Always On, `onAppear` sets `spinning = true` again. Nothing changes, so the repeat animation never restarts and the arc sits still. "Saving to Health…" is exactly when people drop their wrist.
- **Apple guidance:** Progress indicators HIG: "Keep indicators moving so people know something is happening" (https://developer.apple.com/design/human-interface-guidelines/progress-indicators, quoted in the research notes). The view's own comment says "so the screen never looks frozen".
- **Fix:** let the animation drive itself so re-insertion restarts it:
  ```swift
  Circle().trim(from: 0, to: 0.28)
    .stroke(WatchTheme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
    .phaseAnimator([0.0, 360.0]) { arc, angle in arc.rotationEffect(.degrees(angle)) }
      animation: { angle in angle == 0 ? .linear(duration: 0) : .linear(duration: 1.1) }
  ```
  Alternatively, `.onDisappear { spinning = false }`, or the system indeterminate `ProgressView()` tinted lime (watchOS 7+, https://developer.apple.com/documentation/swiftui/progressview).

#### M3. VoiceOver hears neither the countdown nor the start, pause and save

- **Where:** `WatchMotion.swift:83-110` (countdown), `WatchViews.swift:16-47` (phase changes have haptics only), `WatchMotion.swift:89-90` (tap-to-skip).
- **Evidence:**
  ```swift
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("Starting in \(count)")
  .accessibilityHint("Tap to start now.")
  .accessibilityAddTraits(.updatesFrequently)
  ...
  .contentShape(Rectangle())
  .onTapGesture { complete() }
  ```
  A changed label is spoken only if VoiceOver polls the focused element. The countdown replaces the start screen without a screen-change notification, so focus may not land on it within 3 s. Phase changes (Running, Paused, Saved, Failed) give haptics, but nothing is spoken. The `Paused` label is deliberately hidden from VoiceOver (`:303`), so a VoiceOver user hears "paused" only after finding the timer. The tap-to-skip target has no `.isButton` trait and no named action.
- **Apple guidance:** Motion HIG: "Make motion optional… supplement visual feedback by also using alternatives like haptics and audio" (https://developer.apple.com/design/human-interface-guidelines/motion). `AccessibilityNotification.Announcement` is available from watchOS 10 (https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement).
- **Fix:**
  ```swift
  // StartCountdown, inside the loop after setting count:
  AccessibilityNotification.Announcement("\(step)").post()
  // skip affordance
  .accessibilityAddTraits(.isButton)
  .accessibilityAction(named: "Start now") { complete() }
  // WatchRootView, beside sensoryFeedback:
  .onChange(of: manager.phase) { old, new in
    switch (old, new) {
    case (.starting, .running): AccessibilityNotification.Announcement("Workout started").post()
    case (.running, .paused): AccessibilityNotification.Announcement("Recording paused").post()
    case (.paused, .running): AccessibilityNotification.Announcement("Recording resumed").post()
    case (_, .summary(_, true)): AccessibilityNotification.Announcement("Saved to Health").post()
    default: break
    }
  }
  ```
  Confirm on the Watch with VoiceOver on that the announcements don't collide with the `.click` tone.

#### M4. At large Dynamic Type sizes the timer and metric rows shrink, then truncate, beside a fixed 44 pt button

- **Where:** `WatchViews.swift:237-241`, `:371-374`, `:456-457`.
- **Evidence:**
  ```swift
  HStack(alignment: .center, spacing: 6) {
    ElapsedTimeView()          // .title, .lineLimit(1).minimumScaleFactor(0.6)
    Spacer(minLength: 0)
    StopButton()               // .frame(width: 44, height: 44)
  }
  ```
  `MetricRow` text is `.title3`, `lineLimit(1)`, `minimumScaleFactor(0.6)`, with the icon beside it. "No reading yet" and "1:02:45" are the long cases.
- **Apple guidance:** Accessibility HIG: "give people the option to enlarge text by… 140 percent in watchOS apps" (https://developer.apple.com/design/human-interface-guidelines/accessibility). Workouts HIG: "use large font sizes… so that the most important information is easy to read".
- **Impact:** at accessibility sizes on a 40/41 mm case, the elapsed time can shrink to 60% (smaller than at default size) or truncate. The setting meant to enlarge text makes the main number smaller. Screen widths are about 162–187 pt for 40–42 mm; those point sizes are from memory, since the HIG specification table did not come through in the `.md` fetch (unconfirmed). Check on the Watch at the largest size and at AX sizes.
- **Fix:**
  ```swift
  @Environment(\.dynamicTypeSize) private var size
  ...
  if size.isAccessibilitySize {            // watchOS 8+
    VStack(alignment: .leading, spacing: 6) { ElapsedTimeView(); StopButton() }
  } else {
    HStack { ElapsedTimeView(); Spacer(minLength: 0); StopButton() }
  }
  ```
  Or use `ViewThatFits(in: .horizontal)` with both layouts. For `MetricRow`, allow two lines at accessibility sizes (`.lineLimit(size.isAccessibilitySize ? 2 : 1)`). Shorter strings such as "No reading" also help.

#### M5. On the controls page, Pause and the unconfirmed End button are 8 pt apart

- **Where:** `WatchViews.swift:481-498`.
- **Evidence:** `VStack(spacing: 8) { Button("Pause")… Button("End") { manager.end(save: true) } … }`. End has no confirmation (by design, `:491-492`), and Discard gets `.padding(.top, 8)`.
- **Apple guidance:** Accessibility HIG: "Consider spacing between controls as important as size… about 12 points of padding around elements that include a bezel" (https://developer.apple.com/design/human-interface-guidelines/accessibility). Workouts HIG: controls "easy to find and tap".
- **Impact:** a sweaty or rushed tap meant for Pause can end the recording. It is saved, but it cannot be resumed. Apple's Workout app keeps End and Pause well apart in a 2×2 grid.
- **Fix:** `VStack(spacing: 12)`, and put more space (16–20 pt) between Pause and End than between End and Discard. Or match Apple's layout: Pause on top, then a gap, then End and Discard.

#### M6. Too many simultaneous effects on the metrics page, and the heartbeat stutters

- **Where:** `WatchViews.swift:458-466` (numeric roll on every row, flame bounce on every kilocalorie), `WatchMotion.swift:153-172` (heartbeat).
- **Evidence:**
  ```swift
  .symbolEffect(.bounce.up, value: rollsDigits ? bounceValue ?? 0 : 0)
  ```
  ```swift
  .task(id: animates ? beatsPerMinute : nil) {
    ...
    while !Task.isCancelled { beat &+= 1; try? await Task.sleep(for: .seconds(interval)) }
  }
  ```
- **What goes wrong:**
  - With the wrist raised, the page shows a ticking clock, a heart beating at 60–180 bpm, digits rolling on two rows, and a flame bounce on every kilocalorie (every few seconds for the whole workout).
  - The flame also bounces on every wrist raise, because its effect value jumps from 0 to the energy total when `rollsDigits` turns true.
  - Each heart-rate change restarts the beat task, and the loop increments `beat` before its first sleep. Every new reading forces an immediate extra beat, so the rhythm stutters whenever the number changes.
- **Apple guidance:** Motion HIG: "Don't add motion for the sake of adding motion" and "generally avoid adding motion to UI interactions that occur frequently" (https://developer.apple.com/design/human-interface-guidelines/motion). Apple's own Workout app shows "an animated heart beat" in the BPM row (https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state), so the heartbeat itself is right. `ui-ux-pro-max` UX rule: animate 1–2 key elements per view at most.
- **Fix:**
  - Keep the heartbeat and the numeric roll. Remove the flame `.bounce`, or limit it to whole multiples of 10 kcal using a stable value, not one that flips to 0 when dimmed: `.symbolEffect(.bounce.up, value: (bounceValue ?? 0) / 10)` and gate it with `isActive` on watchOS 11+, or wrap it in `if rollsDigits`.
  - In `HeartbeatSymbol`, keep the phase across rate changes by sleeping first:
    ```swift
    while !Task.isCancelled { try? await Task.sleep(for: .seconds(interval)); beat &+= 1 }
    ```

### LOW

- **L1. The start-disc ripple loops forever and its two rings drift apart.** `WatchMotion.swift:49-63`. Ring 0 repeats every 1.8 s and ring 1 every 2.7 s (its 0.9 s delay is re-applied each cycle), so they never keep a steady stagger. The start screen can stay open for minutes while the iPhone sheet waits. HIG Motion says "Add motion purposefully" and Always On says "Gracefully transition motion to a resting state; don't stop it instantly", but `if animates` removes the rings at once. Fix: offset ring 1 once with `.task { try? await Task.sleep(for: .seconds(0.9)); started = true }` and give both the same period. Stop after about 3 cycles (`phaseAnimator(..., trigger:)` with a counter) or once VoiceOver focuses the disc. Optionally fade the rings out (`.transition(.opacity)`) instead of removing them.
- **L2. The seal's ring and check animate at the same moment, though the comment says they are sequenced.** `WatchMotion.swift:176-202`. The doc says "a lime ring draws itself closed, then the check lands", but one `withAnimation(.easeOut(duration: 0.7))` drives both. Fix: ring with `.easeOut(duration: 0.5)`, check with `.spring(duration: 0.3, bounce: 0.35).delay(0.45)`. Keep the `.success` haptic on the phase change (it already fires then), so the check lands about 0.5 s after the haptic. Consider moving the haptic to the check's landing time so the two feel like one moment.
- **L3. The custom button style ignores the destructive role and has no animated press state.** `WatchViews.swift:604-636`. `Button(role: .destructive) { … } label: { Label("Discard", …) }.buttonStyle(WatchButtonStyle(.quiet))` (`:149-154`) renders white. The Buttons HIG says "a destructive button uses the system red color" (https://developer.apple.com/design/human-interface-guidelines/buttons). `ButtonStyleConfiguration.role` is watchOS 8+ (https://developer.apple.com/documentation/swiftui/buttonstyleconfiguration/role). Fix: `let destructive = configuration.role == .destructive` and use `WatchTheme.error` for the label. Add `.animation(.easeOut(duration: 0.12), value: configuration.isPressed)` so the press is not an instant change (pro-rules: tap feedback within 80–150 ms).
- **L4. On watchOS 26, put the pinned Done button in the toolbar so it gets Liquid Glass.** `WatchViews.swift:569-575` uses `.safeAreaInset(edge: .bottom) { Button("Done")… .background(.black) }`. The Buttons HIG (watchOS) says the system "applies the Liquid Glass appearance to toolbar buttons", and Materials HIG says "Don't use Liquid Glass in the content layer" (https://developer.apple.com/design/human-interface-guidelines/materials). Fix: `.toolbar { ToolbarItem(placement: .bottomBar) { Button("Done") { manager.dismissSummary() } } }`. `.bottomBar` is watchOS 10+ (https://developer.apple.com/documentation/swiftui/toolbaritemplacement/bottombar), so no `#available` is needed. Keep the lime `WatchButtonStyle` for in-content primaries, and don't add `.glass`/`.glassProminent` to content buttons. Check the bottom bar visually on watchOS 10 and on 26.
- **L5. VoiceOver reads abbreviations on the summary; live rows have no value/updates semantics.** `WatchViews.swift:551-557`: `Label("\(…) bpm average", …)` and `Label("\(…) kcal", …)` have no spoken label, unlike the session rows. Those rows put the reading into the label (`:470`), so a VoiceOver user who stays on the heart rate is not told when it changes. Fix: on the summary, use `.accessibilityLabel("Average heart rate")` with `.accessibilityValue("\(n) beats per minute")` (and the same for max and kilocalories). On live rows, split into label and value and add `.accessibilityAddTraits(.updatesFrequently)` (watchOS 6+, https://developer.apple.com/documentation/swiftui/accessibilitytraits/updatesfrequently) to `ElapsedTimeView` and `HeartRateRow`. Also give the summary icons the same red and orange as the live rows, for consistency.
- **L6. Headings are hard-coded in capitals.** `WatchViews.swift:117-122` returns "RESTORING", "COULDN'T RESTORE", "RECORDING STOPPED", "READY" and "FORMA". Use sentence-case strings and `.textCase(.uppercase)` for the look, so VoiceOver and localisation get normal words. Unconfirmed: whether VoiceOver spells out an all-caps word such as "FORMA". The frontend-design guidance also flags all-caps labels as a template tell; consider sentence-case lime text instead.
- **L7. The start disc can flash for a frame between the end of the countdown and Starting.** `WatchViews.swift:72-75`. `countingDown = false` renders `content` while `phase` is still `.ready`, and `Task { await manager.start() }` sets `.starting` only on its next turn. Fix: call `await manager.start()` first, then clear `countingDown` once `phase` has left `.idle`/`.ready`. Or make `countingDown` a derived state with `.onChange(of: manager.phase)`. Check on the Watch.
- **L8. The active session could look more distinct, and an optional media page is missing.** The Workouts HIG says to "use a distinct visual appearance to indicate an active workout" and shows a Now Playing page to the right of metrics. Option: `.containerBackground(WatchTheme.lime.gradient.opacity(0.18), for: .tabView)` on the session pages (watchOS 10+, https://developer.apple.com/documentation/swiftui/view/containerbackground(_:for:), placement `.tabView` watchOS 10+), dimmed or removed in Always On. Optional third page: `NowPlayingView()` (WatchKit). Also check on the Watch that the `.page` dots don't overlap the last row of `MetricsPage` (the `ConnectionRow` footnote).
- **L9. The same actions have different names on different surfaces.** The Stop dialog says "Pause recording" and "End workout". The controls page says "Pause" and "End" (VoiceOver: "Pause workout", "End workout and save to Health"). Discard is "Discard recording" in one dialog and "Discard" on the failed-recording screen. Frontend-design copy rule: an action keeps the same name through the whole flow. Pick one noun ("recording" fits what the Watch controls) and use "Pause recording", "End and save", "Discard recording" everywhere, with VoiceOver labels matching the visible text so Voice Control commands work.

---

## 3. Already correct

- **Motion is gated in one place.** `MotionGate` checks both Reduce Motion and `isLuminanceReduced`, so no effect runs in Always On or with Reduce Motion. The countdown still counts and ticks with Reduce Motion, which matches "Make motion optional" with haptics as the backup.
- **The heartbeat follows Apple's model.** A beating heart while lit and a still heart in Always On is exactly Apple's Workout-app example (https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state). The loop is clamped to 30–220 bpm and is tied to the view's lifetime.
- **The summary is one orchestrated moment.** Seal, then a 0.12 s stagger, finishing in about 1.2 s, together with the `.success` haptic on the confirmed save (once H1 is fixed). This fits the frontend-design principle of one moment over scattered effects, and the HIG summary pattern.
- **Countdown details.** It uses the `.click` haptic per count (HIG meaning), tap-to-skip like Apple's Workout app, a monospaced 68 pt rounded number with `numericText(countsDown: true)`, and a ring that drains linearly in step with each second.
- **Navigation.** Horizontal pages put controls on the left and metrics as the default page, and the TabView returns to metrics when the wrist drops (`:209-212`), as Apple's Workout app does. A Stop button with Pause/End confirmation on the metrics page guards against accidental ends.
- **Feedback follows confirmed state, not taps.** `sensoryFeedback` fires only when HealthKit confirms a phase. Start, stop, success and error are the HIG-defined meanings.
- **Labels and values.** The timer has a spoken duration ("12 minutes, 34 seconds", not a time of day). Paused is shown in text and colour, not colour alone. Decorative motion is hidden from VoiceOver. The heading has the header trait. Stop has a label and hint. Errors appear first so they are never below the fold.
- **Targets and contrast.** Full-width capsule-like buttons are 48 pt or taller with identical heights in vertical stacks (Buttons HIG). Stop is 44 pt. All measured text pairs meet 4.5:1, or 3:1 for large text.
- **Waits are explained.** "Starting… Getting your heart rate ready", "Measuring…", then "No reading yet" with a fit hint, and "Saving to Health… Keep this screen open". This follows the Workouts HIG guidance on explaining missing sensor data.
- **Platform hygiene.** Everything used is available at watchOS 10. Nothing newer needs `#available` (no `.glass`, `.breathe`, `.rotate` or `.drawOn`). No deprecated APIs. `WKApplicationDelegateAdaptor` handles `handle(_:)` and active-workout recovery.

## Needs on-device confirmation

H1 (does the summary render while dimmed after an iPhone Finish), M2 (the arc after a wrist raise during Saving), M3 (VoiceOver focus and announcement timing against the click tone), M4 (40/41/42 mm at the largest and accessibility sizes), L4 (bottom-bar glass on watchOS 26 and its look on 10), L7 (frame flash), L8 (page dots against the last row).
