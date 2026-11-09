# FORMA: Complete Native iOS Frontend Audit, Redesign and Production-Quality Upgrade

## ROLE AND MISSION

You are **Codex Sol 6.1 at maximum available reasoning effort**, operating as a principal iOS engineer, Apple-platform architect, senior product designer, accessibility specialist, motion designer and independent software quality auditor.

Repository: [https://github.com/Raoof128/forma-workout-planner](https://github.com/Raoof128/forma-workout-planner)

Product: **FORMA**

Brand promise: *Plan your training. Log every set. See your progress.*

**Your mission is to perform a complete, evidence-driven, file-by-file and line-by-line audit of FORMA's existing native Apple frontend, then directly implement, test and verify meaningful improvements.**

Do not stop at a review, design proposal, list of recommendations or superficial cosmetic changes.

The intended outcome is a distinctive, visually exceptional, fluid, accessible, reliable and production-quality fitness application, built around native Apple interaction conventions and FORMA's established brand identity.

The result should feel like a carefully designed, premium iOS product rather than a mobile website or generic AI-generated interface.

The work must actively improve the existing product while preserving its functional correctness, workout history, storage compatibility, account boundaries and existing user expectations.

**Primary scope:** native iPhone app, Apple Watch companion, WidgetKit extensions, Live Activities, shared presentation logic, motion system, visual assets, accessibility and related frontend tests.

**Secondary scope:** the existing React website, only as the behavioural, branding and data-model reference. Do not redesign or deploy the website as part of this task.

---

# 1. Mandatory Design Skills

Before evaluating or editing UI code, locate, load and thoroughly read both skills.

### Skill A: UI UX Pro Max

Official source:

[https://github.com/nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

Locate the existing `ui-ux-pro-max` skill in the Codex environment, including `.agents/skills/` and any configured global skill directory.

Read its `SKILL.md`, relevant iOS design guidance, design-system workflow and available search utilities.

If absent, inspect the official source and its installation instructions before installing. The documented Codex CLI initialisation is:

`npx ui-ux-pro-max-cli init --ai codex`

Review third-party scripts and their effects before executing them. Do not run unrelated installers or introduce new runtime dependencies.

Use this skill for:

- Visual hierarchy and information architecture.
- Fitness-specific UI/UX patterns.
- Colour systems and typography.
- Component consistency.
- Spacing, alignment and visual rhythm.
- Responsive and adaptive screen design.
- Interaction ergonomics.
- Evidence-based design-system decisions.
- Accessibility and design critique.

Generate a FORMA-specific design direction using the skill's supported workflow. Do not blindly apply a generic theme.

### Skill B: Frontend Design

Official source:

[https://github.com/anthropics/skills/tree/main/skills/frontend-design](https://github.com/anthropics/skills/tree/main/skills/frontend-design)

Locate and read the complete `frontend-design/SKILL.md`.

If absent, inspect the source and use its documented skill installation route where permitted:

`npx skills add https://github.com/anthropics/skills --skill frontend-design`

Use its visual design principles to create an unmistakable product identity, including deliberate typography, sophisticated composition, distinctive interactive details and restrained but memorable motion.

This skill is primarily oriented towards frontend visual design. Adapt its principles to **native SwiftUI** rather than translating web CSS, DOM patterns or browser-oriented animation techniques directly into the iOS app.

### Mandatory skill verification

Before implementation:

1. Identify both installed skill paths.
2. Read both instruction files in full.
3. Apply their relevant workflows.
4. Record the skill versions or source revisions used.
5. Record design decisions inspired by each skill.
6. Resolve disagreements using this priority order:

   **Data integrity and security → Apple API correctness and HIG → accessibility → FORMA product identity → skill recommendations.**

Do not claim a skill was loaded unless its instructions were actually read.

---

# 2. Understand the Existing Repository Before Editing

Start by inspecting the actual working tree.

Run the appropriate equivalents of:

- `pwd`
- `git status --short`
- `git branch --show-current`
- `git log -10 --oneline --decorate`
- `git remote -v`
- `git ls-files -z`
- `xcodebuild -version`
- `xcrun simctl list devices available`
- `swift --version`

Record the starting branch, HEAD SHA, modified files, environment, installed Xcode version and available simulators.

Determine whether the working tree contains uncommitted work or changes newer than the remote default branch.

The uploaded development logs include entries dated 4 November 2026, while the GitHub snapshot previously inspected has older entries. Treat any discrepancy as something to reconcile, not permission to overwrite local work.

**Preserve all pre-existing modifications. Never reset, clean, rebase away or overwrite another developer's changes.**

## Read these files completely

Mandatory repository instructions and contracts:

- `AGENT.md`
- `CHANGELOG.md`
- `docs/data-model.md`
- `docs/accounts/api.md`
- `docs/member-data-sync.md`
- `docs/security/README.md`

Native implementation and design references:

- `ios/README.md`
- `ios/project.yml`
- `ios/docs/apple-design-2026.md`
- `ios/docs/app-review-matrix.md`
- `ios/docs/apple-watch.md`
- `ios/docs/verification.md`
- `ios/docs/baseline-evidence.md`
- `ios/docs/native-design-review.md`
- `ios/docs/native-accounts-findings.md`
- `ios/docs/account-review-and-tab-bar-2026-10-28.md`
- `ios/docs/commit-2/MOTION_SPEC.md`
- All available documents in `ios/docs/audits/frontend-widget-2026-10/`
- Existing implementation, privacy, motion, accessibility, performance and historical audit records.

Follow relevant cross-references. Read the actual source when historical documentation has been superseded.

### Critical product facts

FORMA already has:

- Native SwiftUI functionality.
- Four main tabs: Today, Plan, Progress and You.
- Offline-first workout logging.
- Optional account authentication and sync.
- SQLite-backed training storage.
- A workout engine supporting multiple measurement types.
- Timed holds, rest timers and haptics.
- Workout history and progress visualisation.
- Apple Watch workout integration.
- HealthKit functionality.
- Six WidgetKit widget families.
- A Workout Live Activity for the Lock Screen and Dynamic Island.
- A centralised motion system.
- An existing visual design system.

Do not recreate these systems unnecessarily.

Inspect how they actually work before changing their implementation.

The existing design uses FORMA-specific lime, ink and light/dark canvas tokens. Preserve the brand's recognisability and improve its execution.

---

# 3. Exhaustive File-by-File, Line-by-Line Audit

This is a mandatory whole-native-source audit.

Do not use random samples, selected components, a quick repository scan or automated lint results as a substitute for reading the implementation.

Enumerate every relevant tracked file and classify it.

At minimum inspect:

### iPhone application

`ios/FORMA/`

Including:

- `App/`
- `Features/`
- `Account/`
- `DesignSystem/`
- `Resources/`
- Entitlements and configuration files.

### Apple Watch

`ios/FORMAWatch/`

Review Watch views, workout management, HealthKit presentation, communication status, controls, interruptions and accessibility.

### Widgets and Live Activities

- `ios/FORMAWidgets/`
- `ios/WidgetPresentation/`
- `ios/Sources/FORMASurfaces/`

### Core behaviour affecting presentation

- `ios/Sources/FORMACore/`
- `ios/Shared/`

### Tests and integration

- `ios/FORMAUITests/`
- `ios/FORMAAppTests/`
- `ios/Tests/`
- `ios/Fixtures/`
- `ios/Package.swift`
- `ios/project.yml`
- `.github/workflows/ios.yml`
- Relevant scripts in `scripts/`
- Relevant native resource and contract tests in `unit/`.

Inspect referenced assets, images, JSON manifests, font licences, icons, privacy manifests, app groups, build configurations and generated resource dependencies.

### Review standard

For every human-authored source file:

1. Read its complete contents, in manageable chunks where necessary.
2. Understand its responsibility, dependencies, state and lifecycle.
3. Inspect every declaration, property, function and conditional branch.
4. Examine user-facing strings, style modifiers and accessibility configuration.
5. Inspect asynchronous work, actor isolation and state transitions.
6. Identify actual defects, inconsistencies and improvement opportunities.
7. Compare with relevant shared components and design tokens.
8. Determine whether changes are justified.
9. Implement evidence-backed improvements.
10. Verify the affected behaviour.

For generated files, binary artwork and large data assets, inspect source provenance, build dependencies, metadata, declared dimensions, relevant decoded/rendered outputs, integrity and coverage. Do not claim binary files were literally reviewed line by line.

### File ledger

Create:

`ios/docs/audits/native-frontend-2026-11/FILE_LEDGER.md`

Each entry must include:

- Exact path.
- SHA-256 or equivalent content fingerprint.
- Source/generated/binary classification.
- Line count where applicable.
- Target or module.
- Purpose.
- Review status.
- Findings or explicit no-change rationale.
- Severity.
- Changed or retained.
- Related tests and verification.
- Remaining limitations.

Reconcile file counts against the actual repository inventory.

No relevant file may silently disappear from the audit.

---

# 4. Research Current Apple and Design Standards

Use current official documentation available at execution time, with emphasis on changes relevant to 2026.

Prioritise:

1. Apple Human Interface Guidelines.
2. Apple SwiftUI documentation.
3. Apple's Liquid Glass guidance.
4. WWDC 2025 and WWDC 2026 design and engineering sessions.
5. Apple accessibility documentation.
6. Apple WidgetKit and ActivityKit documentation.
7. Apple watchOS design guidance.
8. Apple Xcode and Instruments guidance.
9. Current App Review Guidelines.
10. WCAG 2.2 AA where applicable.

Official starting points:

- [https://developer.apple.com/design/human-interface-guidelines/](https://developer.apple.com/design/human-interface-guidelines/)
- [https://developer.apple.com/design/human-interface-guidelines/materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [https://developer.apple.com/documentation/swiftui/](https://developer.apple.com/documentation/swiftui/)
- [https://developer.apple.com/documentation/widgetkit/](https://developer.apple.com/documentation/widgetkit/)
- [https://developer.apple.com/documentation/activitykit/](https://developer.apple.com/documentation/activitykit/)
- [https://developer.apple.com/documentation/healthkit/](https://developer.apple.com/documentation/healthkit/)
- [https://developer.apple.com/app-store/review/guidelines/](https://developer.apple.com/app-store/review/guidelines/)
- [https://developer.apple.com/documentation/xcode/testing](https://developer.apple.com/documentation/xcode/testing)

Research the actual platform features and availability requirements instead of assuming that an API mentioned in a 2026 WWDC session is available on older deployment targets.

Current project compatibility targets must be respected unless there is a separately justified reason to change them:

- iOS 17+
- watchOS 10+
- Xcode and Swift toolchains compatible with the existing project and CI.
- Availability-gated modern SwiftUI features.

Create an official-source register recording:

- Source URL.
- Title.
- Publication or revision information where available.
- Relevant requirement.
- Affected FORMA component.
- Implementation decision.
- Compatibility considerations.

Avoid unsupported claims that a design technique is required by Apple when it is merely a recommendation.

---

# 5. Establish FORMA's Signature Visual Direction

Treat this as a flagship consumer fitness product.

The design must be visually memorable, but not at the expense of usability.

## Creative direction

**FORMA: Precision meets performance.**

Think refined athletic editorial design, precise numerical instrumentation, sophisticated native controls and beautifully restrained motion.

Retain its recognisable lime/ink identity.

Use the existing central theme and palette as the foundation rather than inventing a disconnected visual system.

Explore improvements in:

- Typography hierarchy and numerical presentation.
- Workout card architecture.
- Purposeful negative space.
- Navigation and toolbar composition.
- Session progress feedback.
- High-quality illustration integration.
- Chart readability.
- Layout rhythm.
- Control emphasis.
- Native surface treatment.
- Button hierarchy.
- Polished light and dark appearances.
- Consistent loading, empty, success and error states.

### Avoid generic design

Do not introduce:

- Identical rounded cards on every screen.
- Decorative gradients without purpose.
- Excessive frosted-glass containers.
- Generic dashboard layouts.
- Arbitrary icons and badges.
- Repeated unnecessary animations.
- Fake metrics or simulated user history.
- Decorative labels that consume valuable space.
- Unnecessary onboarding screens or new product features.
- Web-style navigation disguised as native UI.

Prefer one visually strong signature element per major screen, supported by a quiet and coherent layout.

### Required design system review

Audit and improve the existing system, including:

- `FormaTheme.swift`
- `FormaComponents.swift`
- `FormaMotion.swift`
- `FormaHaptics.swift`
- `GlassControls.swift`
- `TrainingTabBar.swift`
- `BrandPalette.swift`

Create or refine semantic tokens for typography, colours, spacing, radii, surfaces, elevation, strokes, iconography, animation and component states.

Do not create a parallel design-token system.

Document intentional visual decisions and explain why they suit FORMA.

### Liquid Glass

Use Apple-native Liquid Glass where supported and appropriate.

The navigation/control layer may use glass treatment. Training data, charts, forms, dense logs and primary content should remain readable on stable, appropriately opaque surfaces.

Validate real rendered contrast instead of assuming the design passes because the declared foreground and background colours have acceptable ratios.

Provide accessible alternatives for Reduce Transparency and Increase Contrast.

Do not force an iOS 26 aesthetic onto an iOS 17 runtime using brittle imitations.

---

# 6. Full Screen-by-Screen Product Audit and Upgrade

Inspect every major screen, nested screen, sheet, alert, menu, modal, keyboard state, empty state, error state and interaction transition.

## A. Today

Audit:

- Initial launch.
- Guest first-use experience.
- Returning member dashboard.
- Next scheduled workout.
- Routine rotation.
- Active workout and resume state.
- Weekly activity strip.
- Progress summaries.
- Navigation between dashboard and workout.
- Layout at accessibility text sizes.
- Widget consistency.

Improve the first-screen composition, action priority, hierarchy and clarity.

The primary action should be unmissable.

Use actual saved training data. Never invent activity.

## B. Plan

Audit:

- Routine overview.
- Routine cards.
- Routine templates.
- Create, edit, duplicate, archive and restore.
- Exercise selection.
- Search and catalogue filtering.
- Exercise guidance and attribution.
- Routine ordering.
- Set prescriptions.
- Reps, ranges, weight, RPE and rest.
- Unilateral targets.
- Supersets.
- Long exercise names.
- Empty and heavily populated states.

Improve editing ergonomics and discoverability.

Ensure that keyboard, sheet, scroll and focus transitions never hide important controls or discard unsaved input.

## C. Active Workout

Treat this as FORMA's most important experience.

Review every logging interaction:

- Start workout.
- Continue workout.
- Complete set.
- Undo completion.
- Reopen set.
- Add set.
- Remove set.
- Add or replace exercise.
- Finish workout.
- Discard workout.
- Enter notes.
- Fill remaining sets.
- Adjust load and reps.
- Left/right reps.
- Timed holds.
- Distance exercises.
- Bodyweight/no-load movements.
- Legacy plank measurements.
- RPE.
- Rest countdown.
- Pause, resume and skip rest.
- Backgrounding and interruptions.

Optimise for real gym conditions:

- Quick one-handed interactions.
- Large, reliable touch targets.
- Readable numbers at a glance.
- Minimal unnecessary taps.
- Predictable focus.
- Comfortable thumb reach.
- Low cognitive load.
- Clear acknowledgement of saved data.
- Strong visibility of the current exercise and next required action.

**Never sacrifice data integrity for animation.**

A completed set should look completed only after the underlying save has succeeded.

Unsaved drafts must remain visibly distinct from committed data.

Review interruption paths, including application suspension, process termination, storage failure, sign-out and account switching.

## D. Progress

Audit:

- Training history.
- Workout detail.
- Weekly progress.
- Charts.
- Personal bests.
- Strength estimates.
- Training volume.
- Date formatting.
- Long-term history.
- Empty histories.
- Outliers and unusual values.
- Accessibility descriptions of charts.

Upgrade charts to feel like a professional training analytics tool.

Use real data and honest scales.

Preserve measurement distinctions: kg, reps, seconds, metres and per-side totals.

Never animate through invented intermediate training values.

Provide a usable nonvisual description of every chart.

## E. You and Settings

Audit the complete settings hierarchy and member-facing workflows:

- Profile editing.
- Appearance.
- Motion.
- Haptics.
- Training preferences.
- Widget sharing.
- Live Activity preferences.
- Account creation/sign-in.
- Email verification.
- MFA and recovery.
- Session management.
- Coach access.
- Sync status and conflicts.
- Data export.
- Phone-training import.
- Privacy information.
- Account deletion.
- Sign-out and local data removal.

Use clear, calm and consistent language.

Remove confusing duplication or poorly grouped settings without hiding existing functionality.

Treat privacy and destructive actions as deliberate product experiences.

---

# 7. Apple Watch Audit and Polish

Review the complete companion experience.

Inspect:

- Workout handoff.
- Start confirmation.
- Active workout display.
- Heart-rate presentation.
- Elapsed-time presentation.
- Pause and resume.
- Separate controls page.
- Saving and saved states.
- HealthKit permission handling.
- Disconnection.
- Reconnection.
- Recovery after termination.
- Stale readings.
- Battery impact.
- Always On presentation.
- Digital Crown and touch ergonomics.
- Large text and VoiceOver.
- Physical screen sizes.

The Watch interface should be glanceable, direct and calm.

Do not reproduce the iPhone's dense training layout on a smaller display.

Ensure HealthKit failure and delayed save states are represented truthfully.

Do not create duplicate Health workouts on retries.

Do not claim physical-device validation without actually testing on hardware.

---

# 8. WidgetKit and Live Activity Audit

Review the existing widget families and Workout Live Activity in depth.

## WidgetKit

Audit:

- Small Home Screen widget.
- Medium Home Screen widget.
- Large Home Screen widget.
- Circular Lock Screen accessory.
- Rectangular Lock Screen accessory.
- Inline Lock Screen accessory.
- Configuration options.
- Saved snapshot projections.
- Placeholder, preview and empty states.
- Stale and unavailable states.
- Private/locked content handling.
- Tinted and vibrant rendering.
- Deep-link routing.
- Account changes.
- Sharing permission.
- App Group boundaries.

Improve clarity, information hierarchy and brand consistency without turning widgets into cluttered mini-apps.

Preserve opt-in sharing and protected snapshots.

Do not place credentials, Health data, account identifiers or uncommitted drafts into widget payloads.

Do not promise instantaneous WidgetKit updates or removals beyond system scheduling behaviour.

## Live Activity

Audit:

- Lock Screen.
- Dynamic Island compact presentation.
- Dynamic Island expanded presentation.
- Minimal presentation.
- StandBy.
- Supported Watch Smart Stack presentation.
- Workout start.
- State updates.
- Rest timer updates.
- Workout completion.
- Discard.
- Relaunch.
- Account switch.
- Session mismatch.
- User-disabled activity.
- Interactive intents.
- Locked-screen privacy.
- Multiple activities.

Keep ActivityKit state small, bounded, truthful and synchronised with committed workout state.

Avoid excessive updates, duplicated timers and sensitive information exposure.

Inspect narrow Dynamic Island layouts and long routine names carefully.

---

# 9. Purposeful Motion and Microinteractions

Review the complete existing motion system before creating additional animation.

All native feature animation must use FORMA's established motion resolver and tokens.

Preserve:

- System Reduce Motion precedence.
- Existing user motion preferences.
- Prefer Cross-Fade Transitions where supported.
- No uncontrolled infinite decorative loops.
- No animation while typing.
- No animation that falsely implies an unsaved action succeeded.
- No animation through fabricated chart values.

Inspect and refine:

- Screen transitions.
- Tab changes.
- Navigation-bar behaviour.
- Workout activation.
- Card expansion/collapse.
- Exercise transitions.
- Saved-set feedback.
- Rest dock.
- Hold countdown.
- Weekly completion.
- Chart appearance.
- Workout receipt.
- Error recovery.
- Watch state changes.

Use the best available native techniques, including SwiftUI animation, transitions, matched geometry or appropriate platform APIs, only where justified.

No custom animation framework should be introduced unless a concrete need cannot be met by the existing architecture.

### Haptics

Preserve centralised routing through `FormaHaptics` and the current user preference.

Choose appropriate semantic feedback.

Avoid haptic spam, particularly during rapid logging or navigation.

### Animation acceptance

Every animation must:

1. Communicate a real state change.
2. Preserve interaction availability.
3. Avoid layout instability.
4. Respect accessibility preferences.
5. Stop when its purpose has been fulfilled.
6. Avoid excessive energy consumption.
7. Remain smooth on supported hardware.

Beautiful motion should make the application easier to understand, not slower to use.

---

# 10. Adaptive Layout and Accessibility

Perform a complete responsive and accessibility review.

Test representative compact, standard and large iPhones, plus supported Watch sizes.

Cover iOS 17 compatibility and current available iOS simulator runtimes.

Include:

- Light mode.
- Dark mode.
- Increased contrast.
- Reduced transparency.
- Reduced motion.
- Prefer Cross-Fade where available.
- Dynamic Type through largest accessibility categories.
- VoiceOver.
- Voice Control.
- Switch Control.
- Full Keyboard Access where applicable.
- Bold Text.
- Different Content Size Categories.
- Long translated or user-generated strings.
- Keyboard appearance.
- Landscape where supported.
- Safe areas.
- Home indicator.
- Dynamic Island.
- Sheets and confirmation dialogs.
- Low-height screens.

Audit every touch target and interactive element.

Use at least Apple's recommended 44 × 44 pt touch region for ordinary touch controls where appropriate, and favour larger controls for workout interactions.

Inspect visible focus, announcement order, semantic labels, hints, values and headings.

Verify that accessibility does not depend on colour, animation or icon recognition alone.

No horizontal clipping, invisible primary actions, overlapping labels or unreachable controls.

Do not disable Dynamic Type simply to preserve a screenshot's visual appearance.

---

# 11. Performance, Smoothness and Energy

Use measurement rather than assumptions.

Audit:

- Cold launch.
- Warm launch.
- First usable screen.
- Time to start a workout.
- Time to complete and save a set.
- Exercise-library search.
- Large routine rendering.
- Long workout history.
- Chart construction.
- SQLite load/save paths.
- SwiftUI view invalidations.
- Unnecessary recomputation.
- Main-actor blocking.
- Image decoding.
- Asset sizes.
- Memory allocation.
- Retained objects.
- Timer updates.
- Watch connectivity updates.
- Widget timeline updates.
- ActivityKit updates.
- Battery impact.

Use Instruments where available:

- SwiftUI.
- Time Profiler.
- Animation Hitches.
- Allocations.
- Leaks.
- Energy Log.
- Points of Interest.

Inspect performance under realistic datasets, not only an empty guest workspace.

Preserve the established `AppModel.prepareLaunch()` off-main loading path.

Do not move heavy parsing or SQLite operations back to the main actor.

Keep WatchConnectivity launch activation and HealthKit mirroring registration intact where required by the existing implementation.

Reuse the cached exercise metric index instead of rebuilding catalogue structures per view or operation.

### Measurement protocol

1. Capture the original baseline.
2. Record device, OS, build configuration and methodology.
3. Reproduce a measurable problem.
4. Apply an appropriate fix.
5. Repeat under comparable conditions.
6. Record before/after results.
7. Investigate regressions.

Evaluate smoothness at the device's actual available refresh rate.

Do not claim a fixed FPS, p95 latency, battery improvement or speedup unless measured.

Do not weaken existing performance limits to make the tests pass.

Optimise without lowering image quality, removing content or sacrificing correctness.

---

# 12. State Management and Reliability

Audit every path where frontend changes interact with saved training data.

Specifically inspect:

- Swift concurrency and actor isolation.
- Observable state dependencies.
- Unnecessary view refreshes.
- `Task` cancellation.
- Stale asynchronous callbacks.
- Session and exercise identity guards.
- Draft preservation.
- Save acknowledgement ordering.
- Duplicate taps.
- Rapid successive actions.
- Offline operation.
- Revision conflicts.
- Account switching.
- Import/export.
- Database errors.
- App lifecycle changes.
- Background and foreground transitions.
- Widget refresh.
- Live Activity cleanup.
- Watch reconnection.
- Destructive operations.

Use the shared workout engine and storage contracts rather than adding independent write paths.

All user-visible outcomes must reflect genuine persisted results.

No silent data replacement, lost workout sets or double completion.

Write regression tests for all confirmed failures.

---

# 13. Security and Privacy Are Non-Negotiable

The existing backend, gateway and data model are authoritative.

Do not change account ownership rules to simplify frontend implementation.

Preserve the current native account transport:

- HTTPS only.
- Server-derived session identity.
- Secure session persistence in Keychain.
- Correctly isolated guest and per-member stores.
- Refusal of unsafe redirects.
- Existing native client headers.
- No unsupported browser Origin spoofing.
- No client-side embedded secrets.
- No credential leakage through logs, widgets or screenshots.

Maintain the existing Better Auth, Cloudflare Worker and API security boundaries.

A UI change must not weaken or bypass them.

Preserve workspace v2, historical IDs, measurement units, exercise identities, revision checks and migration compatibility.

Never alter an applied migration.

Never use a production account or real member data as a test fixture.

### Health and privacy

Audit:

- HealthKit permission timing.
- Clear purpose descriptions.
- Actual Health data flow.
- App privacy manifests.
- Required-reason API declarations.
- Data export.
- Consent.
- Account deletion.
- Local deletion.
- Sensitive information in notifications and widgets.
- App Group file protection.
- Privacy-policy accuracy.

Health and fitness records must not be repurposed for advertising or silently copied to external systems.

Do not add third-party trackers, analytics providers, remote fonts or unreviewed SDKs.

Changes that introduce new collection or disclosure obligations require corresponding legal/privacy review and truthful documentation.

---

# 14. App Store Review Readiness

Evaluate the frontend against Apple's currently published App Review Guidelines.

At minimum assess:

- Guideline 2.1: App completeness and functionality.
- Guideline 2.5: Platform and technical requirements.
- Guideline 4.2: Minimum functionality and native value.
- Guideline 4.8: Applicable login-service requirements.
- Guideline 5.1.1: Privacy, data collection and account deletion.
- Guideline 5.1.1(ix): Legal-entity considerations for sensitive information.
- Guideline 5.1.3: Health and fitness information.
- Guideline 5.2: Intellectual property and content rights.

For 5.1.1(ix), explicitly assess FORMA's actual fitness-data collection, account-backed functionality, service classification and developer enrolment. Flag any legal-entity uncertainty for review rather than assuming every fitness logger automatically falls under the same requirement.

Verify that users can exercise meaningful guest functionality where appropriate.

Account deletion must be available in-app for accounts created by the app, with a genuine working flow.

Check review access requirements, including a suitable demonstration account or complete demonstration experience.

Audit:

- App icons and variants.
- Bundle identifiers.
- Entitlements.
- HealthKit descriptions.
- App Group configuration.
- Privacy manifests.
- Embedded extensions.
- Watch companion configuration.
- Signed archive configuration.
- App Store-facing privacy claims.
- Metadata and screenshot readiness.
- Any unresolved device-dependent capability.

Generate an evidence-backed GO / NO-GO readiness matrix.

**Do not claim App Store acceptance or submission readiness merely because the app builds.**

Do not upload to TestFlight or App Store Connect.

---

# 15. Full Visual Testing and Screenshot Comparison

A source audit alone is insufficient.

You must inspect actual rendered results wherever the available environment supports it.

Use Xcode Simulator, screenshot-based UI tests and the existing screenshot-tour infrastructure.

Capture BEFORE screenshots on the unchanged baseline, then AFTER screenshots from the modified build.

Cover all main screens and meaningful interactive states.

### Screenshot matrix

Include:

- Today: empty, scheduled, active.
- Plan: populated, editing, searching, long names.
- Workout: untouched, partially completed, rest, hold, errors.
- Progress: empty, populated, chart, history detail.
- You: standard settings and selected account flows.
- Account: sign-in, registration, MFA, sync conflict, privacy.
- Workout receipt.
- Light and dark modes.
- Compact and large iPhones.
- Largest accessibility text sizes.
- Watch screens where supported.
- Widgets in all six families.
- Live Activity available sizes and states.

Use deterministic synthetic data.

Review each screenshot for:

- Visual balance.
- Alignment.
- Typography.
- Spacing.
- Hierarchy.
- Colour consistency.
- Contrast.
- Touch ergonomics.
- Cropping.
- Text truncation.
- Glass legibility.
- Component consistency.
- Realistic content density.

Do not accept a visually poor result just because the screenshot test passed.

Record and fix material visual mismatches.

Keep proof of the original and improved implementations, with dimensions, target runtime and capture method.

Distinguish actual system-hosted widgets and Live Activities from standalone renderer previews.

---

# 16. Implementation Procedure

Work in controlled passes.

## Phase 1: Baseline and discovery

- Read all mandatory repository instructions.
- Load both design skills.
- Inventory every relevant file.
- Review existing audits and open issues.
- Establish the baseline build and tests.
- Capture the original UI.
- Record actual technical and visual problems.

## Phase 2: Full independent audit

Perform separate reviews for:

1. iPhone navigation and primary screens.
2. Workout interaction and logging.
3. Account, privacy and sync.
4. Design system, typography, motion and accessibility.
5. Watch and HealthKit UI.
6. Widgets and Live Activities.
7. Performance and architecture.
8. App Store requirements.

If multiple independent reviewers or parallel subagents are available, use them for clearly separated source ownership.

Do not allow simultaneous edits to the same files.

Reconcile all findings into one prioritised report.

## Phase 3: Design decisions

Produce a coherent design brief explaining:

- The current product's visual strengths.
- Its weaknesses.
- The retained brand identity.
- The intended signature experience.
- Updated tokens.
- Component patterns.
- Motion rules.
- Screen composition improvements.
- Accessibility safeguards.

Choose a direction that fits FORMA's existing product. Do not pursue unnecessary visual experiments that would require a major rewrite.

## Phase 4: Implementation

Implement confirmed fixes and meaningful improvements.

Prioritise:

**P0:** Data loss, crashes, privacy leaks, security weaknesses, unusable core flows.

**P1:** Serious usability defects, inaccessible controls, broken responsive layouts, significant rendering problems, misleading states.

**P2:** High-impact visual polish, motion improvements, design-system consolidation, measurable performance optimisations.

**P3:** Low-value cosmetic changes and speculative enhancements.

Complete P0 and P1 work within the available environment.

Implement justified P2 improvements rather than merely recommending them.

Avoid changing unrelated infrastructure, data models or web code.

Keep diffs focused, understandable and reviewable.

Do not overwrite existing work or remove features to simplify testing.

## Phase 5: Verification

For every implemented change:

1. Rebuild.
2. Execute focused tests.
3. Add a regression test where appropriate.
4. Inspect affected screenshots.
5. Recheck accessibility.
6. Recheck light/dark presentation.
7. Recheck the core workflow.
8. Investigate any new warning or failure.
9. Confirm the change improves the product.
10. Record the result.

Run full available verification after the final implementation pass.

---

# 17. Build and Testing Requirements

## Physical iPhone Testing: Raouf iPhone Air

**Authorisation:** You may use my personal iPhone, named **"Raouf iPhone Air"**, for FORMA development, testing, visual inspection and performance profiling.

When simulator testing is unavailable, insufficient or less representative of real-world behaviour, prioritise using my connected iPhone Air.

Instructions:

1. Detect **Raouf iPhone Air** using Xcode, CoreDevice or `xcrun devicectl`.
2. Verify device connectivity, trust, Developer Mode, signing and OS compatibility.
3. Build and install the appropriate FORMA development or test build on my iPhone.
4. Run supported XCTest/XCUITest journeys, accessibility checks, screenshots and performance profiling directly on the device.
5. Test real-world scrolling, animations, Liquid Glass, haptics, keyboard behaviour, touch responsiveness, thermal performance and memory usage.
6. Capture screenshots and compare the visual results before and after changes.
7. Use physical-device testing to investigate issues that cannot be reproduced reliably in Simulator.
8. Preserve my existing applications, personal data, training records, accounts and device configuration.

**Safety requirements:**

- Do not erase, reset, unpair or factory-reset my phone.
- Do not delete FORMA's existing application data.
- Prefer an isolated development bundle and synthetic test data where practical.
- Never overwrite production training records during testing.
- Do not change device security settings without explicit approval.
- If the device is locked, disconnected or unavailable, report the blocker and use an available simulator.
- Simulator-only tests may still require Simulator. Do not claim physical hardware can execute unsupported simulator operations.
- Record which checks ran on the real iPhone and which ran in Simulator.

**Important:** Do not skip visual verification simply because Simulator is unavailable. Use **Raouf iPhone Air** whenever the required test can safely run on the physical device.

The final audit must include a dedicated **Physical iPhone Verification** section containing actual build results, screenshots, measured performance and any outstanding device-testing limitations.


Discover installed Xcode schemes, test destinations and actual project commands before running them.

Use the existing repository-supported commands, including where applicable:

`xcodegen generate --spec ios/project.yml`

`swift test --package-path ios`

`node scripts/build-ios-resources.mjs --check`

`npm run lint`

`npm run format:check`

`npm run typecheck`

`npm run docs:check`

`npm run test:unit`

`npm run test:worker`

`npm run build`

For native verification, run the appropriate `xcodebuild` build-for-testing and test-without-building steps for the real project and available simulator destinations.

Run:

- FORMACore tests.
- FORMASurfaces tests.
- Hosted application tests.
- XCUITest journeys.
- Widget rendering tests.
- Widget installation and routing tests where supported.
- Live Activity state and intent tests.
- Relevant Watch tests.
- Native-web contract parity tests.
- Resource generation consistency checks.
- Extension/bundle validation.
- Swift formatting and strict-concurrency checks.
- Security and privacy checks affected by the changes.

Use actual existing commands and schemas. Do not guess command arguments when the repository provides a documented alternative.

If tests require PostgreSQL, run against isolated test infrastructure and follow the repository's fail-not-skip policy.

Where full tests cannot run due to unavailable hardware, signing, simulator runtimes or credentials, report the specific blocker and the tests that remain unverified.

Distinguish tests that pass, tests that fail, tests that were not executed and tests that were cancelled.

Never represent an incomplete or interrupted CI job as green.

Do not change assertions or timeouts simply to hide regressions.

---

# 18. Required Deliverables

Create a durable audit directory:

`ios/docs/audits/native-frontend-2026-11/`

Produce the following evidence, using exact observed results.

### A. Executive audit

`EXECUTIVE_AUDIT.md`

Include overall assessment, important findings, product-level improvements, implementation outcomes and known limits.

### B. Complete file ledger

`FILE_LEDGER.md`

Reconcile every relevant file with the initial inventory.

### C. Design system

`DESIGN_SYSTEM.md`

Document current and revised tokens, typography, component patterns, spacing, surface usage, motion and accessibility rules.

### D. Screen-by-screen review

`SCREEN_REVIEW.md`

Document each screen, its states, identified problems, implemented improvements and visual evidence.

### E. Prioritised findings

`FINDINGS.md`

For every finding include:

- ID and severity.
- File and line references.
- Reproduction.
- User impact.
- Root cause.
- Fix.
- Related tests.
- Verification outcome.
- Remaining risk.

### F. Motion and accessibility

`MOTION_ACCESSIBILITY.md`

Include resolved motion patterns, interaction feedback, accessibility matrix and any unverified hardware checks.

### G. Performance

`PERFORMANCE.md`

Include device/build methodology, original baseline, final measurements, variance, optimisations and outstanding performance questions.

### H. Verification

`VERIFICATION.md`

Include exact commands, target runtimes, test counts, passes, failures, skipped/unrun tests and blockers.

### I. Apple review readiness

`APP_STORE_READINESS.md`

Include guideline mapping, current evidence, unresolved policy questions, archive/privacy checks and final GO / NO-GO assessment.

### J. Final handoff

`FINAL_REPORT.md`

Include:

- Original commit and branch.
- Final modified files.
- Major design improvements.
- Fixed defects.
- Performance changes with evidence.
- Test results.
- Screenshot evidence.
- Accessibility improvements.
- Known limitations.
- Unresolved device-only checks.
- App Review risks.
- Remaining prioritised work.

Update `AGENT.md` and `CHANGELOG.md` with accurate entries, retaining historical information and pre-existing changes.

Do not claim a test, benchmark, device review or visual inspection was performed unless it actually occurred.

---

# 19. Hard Constraints

These rules override aesthetic recommendations.

1. Do not rewrite the application from scratch.
2. Do not remove existing working features.
3. Do not change workout measurements, historical IDs or workspace semantics.
4. Do not silently migrate or rewrite member data.
5. Do not weaken authentication, account ownership or Cloudflare gateway security.
6. Do not add external telemetry, unnecessary SDKs or embedded secrets.
7. Do not perform live production testing with real member data.
8. Do not lower minimum OS compatibility without explicit justification.
9. Do not introduce unguarded new-OS APIs.
10. Do not replace native interaction with web-like imitations.
11. Do not introduce decorative motion that reduces usability or accessibility.
12. Do not use fake progress statistics to improve screenshots.
13. Do not disable or weaken tests to claim success.
14. Do not regenerate copyrighted or licensed exercise media without reviewing provenance and rights.
15. Do not introduce new legal/privacy claims without checking actual data flows.
16. Do not modify applied database migrations.
17. Do not bypass existing generated-resource workflows.
18. Do not overwrite unrelated uncommitted changes.
19. Do not commit, push, merge, deploy or submit the application without explicit authorisation.
20. Do not declare the audit complete unless every scoped file is reconciled in the audit ledger.

---

# 20. Final Quality Bar

The finished application should meet these qualitative standards, supported by actual evidence:

| Dimension         | Expected outcome                                                            |
| ----------------- | --------------------------------------------------------------------------- |
| Visual identity   | Distinctive, coherent, recognisably FORMA                                   |
| Native experience | Consistent with Apple's current platform conventions                        |
| Workout usability | Fast, clear and dependable during real training                             |
| Motion            | Purposeful, fluid and accessible                                            |
| Typography        | Legible, intentional and adaptive                                           |
| Components        | Consistent, reusable and maintainable                                       |
| Navigation        | Predictable, ergonomic and reliable                                         |
| Responsiveness    | No material clipping or unreachable content in tested configurations        |
| Accessibility     | Strong semantic and interaction coverage with documented device limitations |
| Performance       | No unjustified regressions and measurable improvements where identified     |
| Data integrity    | Historical records and existing contracts preserved                         |
| Privacy           | No new exposure of personal or fitness information                          |
| Widgets           | Useful, private, glanceable and visually integrated                         |
| Apple Watch       | Focused, reliable, readable and battery-conscious                           |
| Live Activities   | Truthful, responsive, restrained and privacy-conscious                      |
| App Store         | Evidence-backed readiness assessment with explicit remaining gates          |

A beautiful app that loses a workout is not production-quality.

A technically correct app with poor hierarchy, inaccessible controls and unfinished interactions is not production-quality either.

Both engineering and design must pass.

---

# 21. Final Execution Instruction

**Begin immediately. This is an implementation task, not a request for a theoretical audit.**

First, inspect the repository state and load both design skills.

Next, read the complete project instructions, inventory the native files, establish the baseline and capture the initial UI.

Then perform the exhaustive audit, identify material improvements and implement the fixes in controlled batches.

Validate the actual running application and repeat the design review after implementation.

Use official Apple documentation and the existing FORMA contracts as your authority.

Preserve the current product's strengths while meaningfully improving the quality of its execution.

Do not stop after producing a plan.

Do not produce a polished report that hides unfinished work.

When an environment limitation blocks a test, complete independent improvements and mark the relevant verification as outstanding.

If the context or execution budget limits complete implementation, leave a precise file-level checkpoint and truthful status rather than claiming exhaustive completion.

**Your final responsibility is to deliver the best verified version of FORMA's native frontend that the available environment permits.**

The target is a premium, distinctive iOS training experience whose visual polish, reliability, motion, accessibility and performance all reinforce one another.

**Audit thoroughly. Improve deliberately. Implement carefully. Test rigorously. Verify visually. Preserve every workout.**
