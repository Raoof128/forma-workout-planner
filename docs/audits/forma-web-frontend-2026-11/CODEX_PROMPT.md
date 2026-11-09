# FORMA Website: Ultimate Frontend Audit, UI/UX Redesign, Performance Optimisation and Production-Quality Upgrade

## ROLE: CODEX SOL 6.1 MAX

You are **Codex Sol 6.1 operating at the highest available reasoning effort**, functioning simultaneously as:

- Principal frontend engineer specialising in React and modern JavaScript.
- Senior UI/UX product designer.
- Design systems architect.
- Interaction and motion design specialist.
- Web accessibility engineer.
- Browser performance engineer.
- Application security reviewer.
- Senior QA automation engineer.

You have been assigned a complete professional review and improvement of the FORMA website.

**Repository:** [https://github.com/Raoof128/forma-workout-planner](https://github.com/Raoof128/forma-workout-planner)

**Production website:** [https://forma.raoufabedini.dev/](https://forma.raoufabedini.dev/)

**Project:** FORMA

**Brand promise:** *Plan your training. Log every set. See your progress.*

## PRIMARY MISSION

Perform a genuine, exhaustive, file-by-file and line-by-line audit of FORMA's entire website frontend.

Inspect the implementation, identify technical, visual, accessibility, responsiveness, interaction and performance issues, then **directly implement and verify meaningful improvements**.

This is not merely a review.

This is not a request for recommendations without code changes.

This is not permission to replace the current design with a generic template.

Your responsibility is to transform the existing frontend into an exceptionally polished, distinctive and dependable fitness web application while preserving existing features, data contracts, security controls and user expectations.

The finished experience should feel:

- Premium and unmistakably FORMA.
- Beautiful on both desktop and mobile.
- Smooth, responsive and exceptionally well engineered.
- Focused on practical workout planning and logging.
- Visually cohesive with the native iOS app.
- Accessible and comfortable during long training sessions.
- Fast under realistic workloads.
- Reliable for authenticated members and offline guests.
- Suitable for serious external design, engineering and accessibility review.

**Design excellence and engineering correctness are equally important.**

Do not trade speed for visual effects, accessibility for aesthetics or data integrity for convenience.

---

# 1. Mandatory Skills: UI UX Pro Max + Frontend Design

Before changing frontend code, locate, load and fully read BOTH skills.

## Skill A: UI UX Pro Max

Official source:

[https://github.com/nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

Check the available Codex skills environment, including local and global `.agents/skills/` directories.

Read the complete applicable `SKILL.md` and supporting workflow instructions.

If the skill is missing, verify the official installation documentation before installing it.

The documented Codex installation route is:

```
npx ui-ux-pro-max-cli init --ai codex
```

Review any third-party installation commands and their effects before execution.

Use the skill to research and improve:

- Fitness-specific user experience.
- Visual design patterns.
- Colour systems.
- Typography and information hierarchy.
- Component architecture.
- Responsive layouts.
- Interaction design.
- Navigation.
- Data dashboards.
- Accessibility.
- Design-system consistency.
- Visual evaluation and refinement.

Do not blindly apply generated recommendations.

## Skill B: Frontend Design

Official source:

[https://github.com/anthropics/skills/tree/main/skills/frontend-design](https://github.com/anthropics/skills/tree/main/skills/frontend-design)

Locate and read `frontend-design/SKILL.md` in full.

If absent, review its official installation process. A documented installation command is:

```
npx skills add https://github.com/anthropics/skills --skill frontend-design
```

Use the skill to develop a distinctive, deliberate visual direction.

Focus on:

- Original compositions.
- Typography with personality.
- Purposeful visual hierarchy.
- Precise spacing.
- Distinctive brand treatments.
- Thoughtful animation.
- Strong art direction.
- High-quality interactive elements.
- Non-generic, product-specific design choices.

Avoid formulaic AI-generated aesthetics.

## Mandatory skill verification

Before implementation, record:

1. Exact installed skill paths.
2. Versions or source revisions.
3. Instructions read.
4. Relevant workflows.
5. Design decisions influenced by each skill.

If one skill cannot be loaded, report that limitation accurately and continue using verified design guidance.

Resolve conflicting recommendations using this priority:

**Security and data integrity → functionality → accessibility → performance → established FORMA identity → aesthetic preferences.**

---

# 2. Understand the Entire Project

Start by inspecting the actual repository and working tree.

Record:

- Current branch.
- HEAD commit.
- Remote state.
- Existing uncommitted changes.
- Installed Node.js version.
- Installed dependencies.
- Available browser engines.
- Existing test configuration.
- Existing visual and performance evidence.

Do not assume GitHub `main` is newer than the local working tree.

Never overwrite another developer's modifications.

## Read these documents completely

Mandatory:

- `AGENT.md`
- `CHANGELOG.md`
- `README.md`
- `CONTRIBUTING.md`
- `docs/architecture.md`
- `docs/data-model.md`
- `docs/accounts/api.md`
- `docs/member-data-sync.md`
- `docs/security/README.md`
- `docs/testing.md`
- `docs/verification.md`
- `docs/user-guide.md`
- `docs/qa/site-sweep/README.md`
- `docs/audits/forma-runtime-quality-2026-10/FILE_AUDIT.md`
- Relevant frontend release, design, accessibility, performance and regression reports.

Read related documentation discovered through cross-references.

The source of truth is the **current implementation and verified contracts**, not an outdated historical plan.

## Existing technology

The repository currently uses technologies including:

- React 19.
- Vite 8.
- JavaScript and JSX.
- CSS.
- Motion.
- Lucide.
- Playwright.
- axe-core.
- Node.js.
- Better Auth.
- PostgreSQL.
- Cloudflare Workers.
- A private backend.

Inspect the exact installed versions from `package.json` and `package-lock.json`.

Do not perform unnecessary major dependency upgrades during a design audit.

Existing dependency constraints, including the ESLint compatibility rules and narrowly scoped security exceptions recorded in `AGENT.md`, must be respected.

---

# 3. Exhaustive File-by-File and Line-by-Line Audit

This requirement is mandatory.

Inventory every frontend-relevant file using Git, then reconcile that inventory against the completed audit.

Do not inspect only the largest components.

Do not rely on lint results alone.

Do not skip files because they appear visually unimportant.

## Scope A: Application and component source

Audit every file under:

`src/`

Including, but not limited to:

### Application architecture

- `src/App.jsx`
- `src/main.jsx`
- `src/hooks/useNavigation.js`
- `src/hooks/useWorkoutStore.js`

### Navigation and general UI

- `src/components/Navigation.jsx`
- `src/components/UI.jsx`
- `src/components/ActionsMenu.jsx`
- `src/components/Notification.jsx`
- `src/components/Loading.jsx`
- `src/components/ErrorBoundary.jsx`
- `src/components/BrandMark.jsx`

### Workout and exercise experience

- `src/components/Overview.jsx`
- `src/components/Routines.jsx`
- `src/components/RoutineCardOrder.jsx`
- `src/components/RoutinePrescription.jsx`
- `src/components/RoutinePrescriptions.jsx`
- `src/components/RoutinePreview.jsx`
- `src/components/Workout.jsx`
- `src/components/HoldTimer.jsx`
- `src/components/ExercisePicker.jsx`
- `src/components/ExerciseGuide.jsx`
- `src/components/ExerciseMedia.jsx`
- `src/components/ExerciseDemo.jsx`
- `src/components/ExerciseAnimation.jsx`
- `src/components/GuideInstructions.jsx`
- `src/components/Library.jsx`

### History and progress

- `src/components/Insights.jsx`
- `src/components/HistoryEditor.jsx`
- `src/progressSummary.js`

### Settings and accounts

- `src/components/Preferences.jsx`
- `src/components/Account.jsx`
- `src/components/Recovery.jsx`
- `src/account/AccountProvider.jsx`
- `src/account/client.js`
- `src/account/cloudRepository.js`

### Domain and persistence

- `src/storage.js`
- `src/persistence.js`
- `src/data.js`
- `src/workoutSession.js`
- `src/routineProgramming.js`
- `src/exerciseMetrics.js`
- `src/exerciseLoad.js`
- `src/timedHolds.js`

Also inspect every other relevant source file discovered by the inventory.

## Scope B: All CSS

Audit every CSS file, including:

- `src/styles.css`
- `src/account.css`
- `src/brand-motion.css`
- `src/workout-history.css`

Inspect every selector, rule, declaration, media query, animation, keyframe and override.

Pay particular attention to:

- Cascade ordering.
- Specificity conflicts.
- Duplicated declarations.
- Dead selectors.
- Invalid or ineffective declarations.
- Excessive `!important`.
- Magic numbers.
- Hardcoded colours.
- Inconsistent spacing.
- Conflicting breakpoints.
- Overflow.
- Unnecessary repainting.
- Forced heights.
- Typography inconsistencies.
- Focus visibility.
- Hover-only interactions.
- Animation accessibility.

Avoid turning a few global stylesheets into an unmaintainable stack of increasingly specific overrides.

Improve the organisation where genuinely useful, while preserving predictable behaviour.

## Scope C: Frontend integration

Inspect:

- `index.html`
- `vite.config.*`
- `package.json`
- `package-lock.json`
- `playwright.config.*`
- `playwright.production.config.*`
- `wrangler.jsonc`
- Related frontend build scripts.
- Relevant GitHub Actions workflows.
- Frontend-facing Worker configuration.
- Browser resource loading.
- Public assets and fonts.

Read `worker/index.ts` and relevant API contracts where needed to verify that frontend changes preserve existing security and request behaviour.

Do not expand this task into an unrelated backend rewrite.

## Scope D: Assets

Audit:

- Brand marks.
- Hero photography.
- Training artwork.
- Routine imagery.
- Exercise illustrations.
- SVG animations.
- Video clips.
- Posters and thumbnails.
- Fonts.
- Icons.
- Responsive image variants.
- Asset manifests.
- Licensing and attribution.

Do not claim a binary asset was reviewed line by line.

Instead inspect the asset's source, metadata, runtime usage, dimensions, file size, preview/rendering and applicable licence.

Preserve all reviewed artwork provenance and attribution.

Do not regenerate or overwrite generated catalogue assets manually.

## Scope E: Tests

Read all relevant tests under:

- `tests/`
- `unit/`
- `worker/tests/`
- Relevant `server/tests/`

Identify coverage gaps, brittle assertions, redundant tests, accessibility omissions and missing visual regression coverage.

**Do not weaken existing assertions to make the redesign pass.**

---

# 4. Required File Audit Standard

For every human-authored frontend file:

1. Read its full contents.
2. Understand its responsibility.
3. Inspect every component and function.
4. Review every conditional rendering branch.
5. Inspect hooks and effect dependencies.
6. Review state and asynchronous behaviour.
7. Inspect error handling.
8. Review semantic HTML.
9. Inspect accessibility attributes.
10. Review visual styles.
11. Review responsive behaviour.
12. Review performance characteristics.
13. Identify defects and improvement opportunities.
14. Implement justified improvements.
15. Verify affected functionality.

Classify findings:

- **P0:** Security, data loss, crash or critical functional failure.
- **P1:** Major usability, accessibility or reliability issue.
- **P2:** Significant visual, responsive or performance issue.
- **P3:** Minor polish or maintainability improvement.

For every file, record an explicit disposition:

- Changed and verified.
- Inspected, no justified change.
- Generated, validated through source/build.
- Blocked, with exact reason.

Create a full file ledger with exact paths, line counts, hashes, findings, changes and verification evidence.

Every relevant source file must be accounted for.

---

# 5. Research Current 2026 Frontend Standards

Use authoritative and current documentation.

Prioritise:

- React official documentation.
- Vite official documentation.
- Motion official documentation.
- MDN Web Docs.
- W3C WCAG 2.2.
- WAI-ARIA Authoring Practices.
- web.dev.
- Chrome Developers.
- Playwright documentation.
- OWASP ASVS.
- OWASP Cheat Sheet Series.
- Cloudflare developer documentation.

Official starting points:

[https://react.dev/](https://react.dev/)

[https://vite.dev/](https://vite.dev/)

[https://motion.dev/](https://motion.dev/)

[https://developer.mozilla.org/](https://developer.mozilla.org/)

[https://www.w3.org/TR/WCAG22/](https://www.w3.org/TR/WCAG22/)

[https://www.w3.org/WAI/ARIA/apg/](https://www.w3.org/WAI/ARIA/apg/)

[https://web.dev/](https://web.dev/)

[https://playwright.dev/](https://playwright.dev/)

[https://cheatsheetseries.owasp.org/](https://cheatsheetseries.owasp.org/)

Verify API and browser support before introducing new platform features.

Distinguish requirements from recommendations.

Document actual source URLs, publication/revision dates where known, compatibility constraints and their relevance to FORMA.

Do not rely on outdated frontend advice or generic AI-generated checklists.

---

# 6. Redefine FORMA's Premium Web Design Experience

## Product design direction

**FORMA: Precision. Discipline. Progress.**

The website should feel like an athletic performance instrument designed by a serious product team.

Retain the existing FORMA identity and refine it.

The established visual foundation includes:

- Lime accent.
- Ink-coloured typography and surfaces.
- Light neutral canvas.
- Athletic editorial typography.
- Strong numerical emphasis.
- Functional workout imagery.
- Purposeful motion.

Preserve the recognisable brand character.

The intention is not to copy another fitness application or start from zero.

It is to make the current visual identity more refined, expressive and coherent.

## Required visual improvements

Review and improve:

### Typography

- Headline hierarchy.
- Display typography.
- Body typography.
- Numerical typography.
- Exercise names.
- Workout statistics.
- Form labels.
- Captions.
- Line height.
- Tracking.
- Weight distribution.
- Responsive scaling.

The current design uses locally hosted DM Sans and Barlow Condensed fonts.

Evaluate their existing implementation and improve typography without introducing external font requests or unjustified licensing changes.

### Colour system

Review semantic tokens for:

- Background.
- Surface.
- Primary text.
- Secondary text.
- Accent.
- Interactive states.
- Success.
- Warning.
- Error.
- Disabled states.
- Focus.
- Borders.
- Charts.

Avoid hardcoding repeated colours across components.

Verify contrast in rendered states.

### Layout and composition

- Content hierarchy.
- Page width.
- Grid systems.
- Sidebar behaviour.
- Card organisation.
- Vertical rhythm.
- Responsive gutters.
- Section spacing.
- Control placement.
- Dense data display.
- Long text handling.
- Empty space.
- Visual balance.

### Component quality

Every component must feel professionally finished.

Evaluate:

- Buttons.
- Inputs.
- Selects.
- Numeric controls.
- Sliders.
- Menus.
- Modal dialogs.
- Tooltips.
- Toasts.
- Tabs.
- Search fields.
- Exercise cards.
- Routine cards.
- Charts.
- Counters.
- Progress indicators.
- Empty states.
- Error states.
- Loading states.
- Confirmation dialogs.

Build one coherent design system.

Avoid unnecessary duplication.

### Anti-template rule

Do not turn the website into a generic SaaS dashboard.

Avoid:

- Identical rounded cards everywhere.
- Random gradients.
- Excessive blur.
- Decorative glass effects.
- Arbitrary colour accents.
- Generic glowing buttons.
- Unnecessary all-caps labels.
- Repetitive reveal animations.
- Decorative elements without clear purpose.
- Excessive use of shadows.
- Fake user activity or generated progress statistics.

The visual system should communicate athletic performance, not generic technology branding.

---

# 7. Complete Screen-by-Screen Audit

Inspect every page, route, state, overlay and meaningful interaction.

## A. Overview Dashboard

Audit:

- Guest dashboard.
- Signed-in dashboard.
- First-time experience.
- Weekly schedule.
- Next workout.
- Active workout.
- Resume action.
- Training summary.
- Primary CTA.
- Desktop and mobile composition.
- Loading and empty states.

Improve hierarchy and information density.

The main workout action must be immediately clear.

Avoid forcing users through unnecessary navigation.

Use real stored values.

## B. My Routines

Audit:

- Routine grid.
- Create routine.
- Edit routine.
- Duplicate routine.
- Archive routine.
- Restore routine.
- Delete actions.
- Routine ordering.
- Exercise ordering.
- Supersets.
- Repetition ranges.
- RPE targets.
- Per-side programming.
- Rest targets.
- Notes and cues.
- Exercise replacement.
- Preview workflow.
- Template selection.

Improve the visual presentation and interaction ergonomics of routine programming.

Preserve stable identities and all saved data.

### Drag-and-drop requirements

Review the existing Motion-based drag system.

Preserve:

- Correct save order.
- Touch scrolling.
- Long-press behaviour.
- Keyboard/pointer alternatives.
- Escape cancellation.
- Superset semantics.
- Stable row positions.
- Draft values.
- Fast sequential gestures.

Inspect existing historical regression reports before modifying drag mechanics.

Do not introduce new drag timing races or weakened test assertions.

## C. Exercise Library

Audit:

- Exercise search.
- Search ranking.
- Categories.
- Equipment filters.
- Exercise selection.
- Pagination.
- Long exercise names.
- Exercise guides.
- Media previews.
- Placeholder/error states.
- Mobile library usability.
- Search keyboard behaviour.
- Large catalogue performance.

Preserve historical IDs, aliases and unit classifications.

### Exercise media

Preserve the established media order:

1. Original exercise illustration.
2. Reviewed video clip, when available.
3. Animated demonstration, when available.

Retain licence notices and attribution.

Preserve play/pause controls for long-running demonstrations.

Never autoplay videos contrary to existing behaviour.

Respect `prefers-reduced-motion`.

Do not introduce external copyrighted media without reviewing rights.

## D. Active Workout

This is the highest-priority interaction surface.

Audit every element of the workout logging experience.

Include:

- Starting a session.
- Completing sets.
- Editing weight.
- Editing repetitions.
- Left/right repetitions.
- RPE logging.
- Duration logging.
- Distance logging.
- Added-weight exercises.
- No-load exercises.
- Rest countdowns.
- Hold timers.
- Set completion.
- Reopening completed sets.
- Adding sets.
- Removing unfinished sets.
- Adding/replacing exercises.
- Moving exercises.
- Session notes.
- Finish confirmation.
- Discard confirmation.
- Saved workout receipt.

Optimise this screen for gym use.

A person using FORMA may be tired, holding a phone in one hand and moving between sets.

The UI must offer:

- Clear actions.
- Large touch targets.
- Readable numbers.
- Fast entry.
- Reliable keyboard behaviour.
- Predictable scroll position.
- Minimal unnecessary taps.
- Immediate truthful feedback.
- Comfortable one-handed operation.

### Non-negotiable

Never display a saved state before the underlying operation has successfully committed.

Preserve draft input when asynchronous saves complete.

Protect users against double submissions, stale callbacks and accidental loss of completed sets.

Any animation must follow actual state changes.

## E. Workout History

Audit:

- History overview.
- Session grouping.
- Sorting.
- Workout detail.
- Historical exercise data.
- Editing previous workouts.
- Set corrections.
- Notes.
- Dates.
- Historical routine names.
- Volume and measurement presentation.
- Empty states.
- Very large histories.

Ensure corrections do not silently rewrite unrelated training records.

Preserve data-model consistency and backward compatibility.

## F. Progress and Insights

Audit:

- Charts.
- Training frequency.
- Weekly progress.
- Personal bests.
- Volume summaries.
- Strength estimates.
- Session totals.
- Exercise breakdown.
- Empty data.
- Long-term history.
- Date and timezone behaviour.

Improve visualisation and readability.

Use real data exclusively.

Do not animate charts through fabricated values.

Preserve metric distinctions, including load, reps, time, distance and unilateral totals.

Charts must be accessible through meaningful labels and an understandable text alternative.

## G. Settings and Preferences

Audit:

- Profile settings.
- Weekly goals.
- Training preferences.
- Rest preferences.
- Timer sound.
- Set-fill behaviour.
- Schedule editing.
- Import/export.
- Account settings.
- Personal data controls.

Group settings logically and avoid confusing repetition.

## H. Accounts and Authentication

Review every member workflow:

- Registration.
- Consent.
- Email verification.
- Sign-in.
- Password recovery.
- MFA challenge.
- Recovery codes.
- Password changes.
- Email changes.
- Session management.
- Revocation.
- Sign-out.
- Coach-token management.
- Account deletion.
- Offline transitions.
- Sync conflict resolution.
- Member-data import.
- Member-data export.

Improve UI clarity, validation feedback and keyboard accessibility.

Do not bypass or weaken server authentication.

Do not expose sensitive account information unnecessarily.

## I. Legal and Privacy

Audit:

- Privacy Policy.
- Terms of Use.
- Consent wording.
- Account-deletion explanation.
- Data-export explanation.
- Legal navigation.
- Responsive layout.
- Keyboard focus.
- Heading hierarchy.

Preserve the established legal content source of truth.

Do not silently rewrite legal commitments while polishing presentation.

Any material text change must follow the documented review and notice process.

## J. Recovery and Errors

Audit:

- Invalid local data.
- Failed saves.
- Storage quota failures.
- Network failures.
- Offline account state.
- Expired sessions.
- Sync conflicts.
- Imported-data rejection.
- Unavailable exercise media.
- Failed authentication.
- Unexpected component errors.

Every error must tell the user what happened and what they can do next.

No silent data loss.

No indefinite loading screens.

No fake success.

---

# 8. Professional Motion and Microinteraction Upgrade

Use the existing Motion library and FORMA's established animation tokens.

Inspect all animations and transitions.

Improve:

- Navigation transitions.
- Page-entry choreography.
- Routine-card interactions.
- Drag-and-drop.
- Exercise selection.
- Menu expansion.
- Dialog appearance.
- Workout state changes.
- Saved-set acknowledgement.
- Rest timers.
- Hold timers.
- Weekly progress.
- Chart transitions.
- Success receipts.
- Error recovery.

## Motion rules

1. Motion must communicate real state changes.
2. Avoid excessive animation during repetitive workout logging.
3. Keep frequently used controls immediate and responsive.
4. Respect reduced-motion preferences.
5. Do not animate while numeric fields are being edited.
6. Avoid layout shifts.
7. Avoid long main-thread JavaScript animation work.
8. Use CSS transforms and opacity where appropriate.
9. Use Motion only when its capabilities are justified.
10. No unbounded animation loops.
11. Never animate through invented statistics.
12. Never let decorative animations delay a workout action.

Preserve the established drag spring behaviour unless an evidence-backed change improves it.

Avoid increasing bundle size unnecessarily.

A smaller amount of excellent motion is better than a large amount of decorative movement.

---

# 9. Responsive Design: Every Screen Size

Perform a complete responsive audit.

Do not test only one desktop viewport and one mobile viewport.

At minimum include representative widths around:

- 320 px.
- 360 px.
- 375 px.
- 390 px.
- 430 px.
- 540 px.
- 768 px.
- 1024 px.
- 1280 px.
- 1440 px.
- 1920 px.

Also test actual device heights, landscape, touch capabilities, safe areas and browser zoom.

Inspect:

- Navigation collapse.
- Sidebar.
- Mobile drawer.
- Header.
- Content gutters.
- Buttons.
- Routine cards.
- Workout tables.
- Numeric inputs.
- Three-field unilateral rows.
- Modals.
- Menus.
- Long text.
- Charts.
- Media crops.
- Sticky headers.
- Fixed controls.
- Form error messages.
- Footer.
- Legal pages.

Check that:

- Nothing important is clipped.
- No unexpected horizontal scrolling occurs.
- No control becomes unreachable.
- Numeric input remains visible with the keyboard open.
- Focused elements are not hidden beneath sticky navigation.
- Touch scrolling remains natural.
- Modal content fits compact screens.
- Responsive rearrangements preserve logical reading order.

### Physical mobile Safari

Where technically supported, you may use my connected physical iPhone named **Raouf iPhone Air** for Safari-based frontend testing.

Use it to inspect:

- Real touch responsiveness.
- Mobile Safari layout.
- Form entry.
- Keyboard behaviour.
- Scrolling.
- Navigation.
- Animation smoothness.
- Viewport and safe-area handling.

Prefer local or isolated test environments.

Do not alter my existing iPhone data or FORMA member records.

If the phone is not available, use Playwright WebKit and available mobile browser testing, while clearly distinguishing emulation from real-device results.

---

# 10. Accessibility: WCAG 2.2 AA

Audit the website against WCAG 2.2 AA, using automated and manual testing.

Include:

- Semantic HTML.
- Heading order.
- Accessible names.
- Form labels.
- Error descriptions.
- Keyboard navigation.
- Visible focus.
- Focus restoration.
- Focus trapping.
- Escape behaviour.
- Screen-reader announcements.
- Status messages.
- Contrast.
- Text resizing.
- Reflow.
- Target sizes.
- Pointer alternatives.
- Reduced motion.
- Content readability.
- Correct ARIA usage.

Pay particular attention to:

**WCAG 2.2 SC 2.5.7:** Dragging alternatives.

**WCAG 2.2 SC 2.5.8:** Minimum target size.

**WCAG 2.4.11:** Focus not obscured.

**WCAG 1.4.10:** Reflow.

**WCAG 1.4.3:** Contrast minimum.

**WCAG 2.1.1:** Keyboard access.

### Critical interaction patterns

Audit the existing:

- Action menus.
- Routine preview carousel.
- Mobile navigation drawer.
- Modal dialogs.
- Confirmation dialogs.
- Form mode changes.
- Legal navigation.
- Toast notifications.
- Exercise selection.

Preserve correct WAI-ARIA patterns.

Do not add redundant ARIA to native semantic controls.

Use automated axe checks and manual keyboard/screen-reader evaluation.

Do not claim WCAG conformance based on automated scans alone.

The historical runtime audit documented unresolved accessibility findings. Reproduce and classify any that remain in the current implementation, then fix confirmed issues within scope.

---

# 11. Frontend Performance and Core Web Vitals

Optimise using actual performance evidence.

Review:

- Bundle size.
- Initial JavaScript.
- CSS loading.
- Font loading.
- Image loading.
- Video loading.
- Exercise catalogue loading.
- Main-thread work.
- React rendering.
- Expensive calculations.
- Repeated JSON operations.
- Component state ownership.
- Excessive effect execution.
- Search latency.
- Chart recomputation.
- Drag performance.
- Memory retention.
- Navigation speed.
- Route switching.
- Event listener cleanup.
- Layout thrashing.
- Paint costs.
- Caching behaviour.

## Core Web Vitals

Target current recommended good thresholds:

- LCP: ≤2.5 seconds.
- INP: ≤200 milliseconds.
- CLS: ≤0.1.

These are measurement goals, not guaranteed results.

Distinguish laboratory measurements from actual field data.

For meaningful field Core Web Vitals classification, use the appropriate 75th-percentile methodology and separate mobile and desktop where data is available.

Do not claim a production-field improvement from a single Lighthouse run.

## React performance

Inspect:

- Unnecessary rerenders.
- Unstable callback identities.
- Expensive derived state.
- Repeated catalogue transformations.
- Hook dependencies.
- Context update propagation.
- Async work and cancellation.
- Large lists.
- Search input responsiveness.
- Component remounting.
- Stale closures.

Use React DevTools Profiler where available.

Avoid blanket `memo`, `useMemo` or `useCallback` additions.

First identify actual expensive work, then make targeted improvements.

A proposed optimisation must not introduce stale state or incorrect render behaviour.

## Vite and bundling

Inspect the current Vite build output and loading waterfall.

Evaluate code splitting, dynamic imports, assets and build output carefully.

**Important historical constraint:** a previous lazy-route experiment delayed initial workout navigation and broke an offline-first-use scenario.

Do not repeat that regression.

Any route or component split must be shown to improve real-world performance without harming offline training, initial navigation or interaction speed.

Preserve appropriate cache behaviour after new deployments.

## Media optimisation

Review:

- Image dimensions.
- Resource sizes.
- Responsive loading.
- Lazy-loading boundaries.
- Image decode costs.
- Aspect ratios.
- Thumbnail quality.
- Poster images.
- Video preload.
- Animation assets.
- Font subsets and weights.

Preserve visual quality and accurate exercise illustrations.

Do not remove reviewed images merely to improve Lighthouse scores.

---

# 12. Data Integrity and Application Reliability

The frontend is not an isolated marketing website.

It is a workout application handling persistent member data.

Audit all state transitions that could affect training records.

Review:

- Guest `localStorage` persistence.
- Workspace revisions.
- Cross-tab coordination.
- Offline changes.
- Save queues.
- Cloud refreshes.
- Conflict resolution.
- Member switching.
- Sign-out.
- Data import.
- Backup export.
- Stale async responses.
- Duplicate actions.
- Pending edits.
- Session recovery.
- Workout finish/discard.
- History corrections.
- Timed exercise logging.

Preserve workspace schema v2 and all supported historical formats.

Never reinterpret existing measurement units.

Never remove historical exercise IDs.

Preserve the documented limits and validation behaviour.

Ensure that UI changes do not introduce:

- Stale overwrite bugs.
- Lost drafts.
- Duplicate completed sets.
- Incorrect workout totals.
- Silent data replacement.
- Cross-account data leakage.
- Broken backup compatibility.
- Incorrect dates.

Use the established Sydney date/week conventions.

Preserve the current workout session and storage helpers rather than implementing new parallel business logic inside React components.

---

# 13. Security Audit of Frontend Changes

Treat security and privacy as release-blocking concerns.

Preserve:

- Better Auth's existing session model.
- Same-origin cookie authentication.
- Server-derived identity.
- Cloudflare Worker allowlists.
- Existing CSRF/Origin protections.
- Secure redirects.
- MFA flows.
- Rate-limiting behaviour.
- Per-member workspace isolation.
- Sensitive-data boundaries.
- Coach-token permissions.
- Secure account deletion.

Inspect frontend code for:

- Unsafe HTML injection.
- Untrusted URLs.
- Sensitive information in logs.
- Authentication state leakage.
- Unsafe redirects.
- Token exposure.
- Unsafe file imports.
- Missing confirmation of destructive actions.
- Race conditions during sign-in/sign-out.
- Cross-account component state.
- Accidental production API calls in tests.
- Overly broad error disclosure.

Never put server secrets in Vite frontend environment variables.

Do not bypass authentication controls for easier tests.

Use isolated synthetic credentials and disposable testing databases.

Keep production member data untouched.

Do not modify live Cloudflare or DigitalOcean infrastructure as part of this frontend audit.

---

# 14. Full End-to-End Browser Testing

Use the existing Playwright infrastructure.

Test both development and production builds.

Cover:

- Chromium.
- Firefox.
- WebKit.
- Desktop viewports.
- Mobile viewports.
- Touch interactions.
- Keyboard interactions.
- Guest workflows.
- Account workflows.
- Offline and recovery workflows.

## Required user journeys

### Guest

- Open the website.
- Navigate all pages.
- Create a routine.
- Edit prescriptions.
- Reorder exercises.
- Start a workout.
- Complete sets.
- Use rest/hold timers.
- Finish workout.
- Review history.
- Inspect progress.
- Export data.
- Restore validated data.
- Reload and confirm persistence.

### Authenticated member

Using isolated test infrastructure:

- Register.
- Verify email through the test sink.
- Sign in.
- Complete MFA where configured.
- Edit account settings.
- Save workout data.
- Verify sync.
- Open another session.
- Test revision conflicts.
- Export data.
- Review session management.
- Revoke sessions.
- Exercise account deletion in a disposable environment.

### Accessibility

- Navigate without a mouse.
- Open and close every dialog.
- Use every menu.
- Reorder without dragging.
- Inspect error announcements.
- Test reduced motion.
- Check responsive zoom.
- Verify focus return.

### Failure handling

- Simulate network interruption.
- Simulate slow responses.
- Simulate rejected saves.
- Simulate session expiry.
- Simulate invalid imported data.
- Simulate duplicate rapid actions.
- Simulate unavailable media.
- Verify no silent data loss.

Do not rewrite expectations to hide failures.

Investigate browser/CI environment failures separately from application regressions.

Where historical flaky cases exist, read the original investigation before changing the tests.

---

# 15. Visual Regression Testing and Screenshot Audit

Capture real screenshots before and after implementation.

Use deterministic synthetic fixtures and repeatable browser configuration.

Screenshot coverage must include:

- Overview dashboard.
- Routines page.
- Routine detail.
- Routine editor.
- Routine preview.
- Exercise library.
- Exercise guide.
- Active workout.
- Rest timer.
- Hold timer.
- Workout receipt.
- History.
- History editor.
- Progress.
- Settings.
- Account forms.
- Account security.
- Sync conflict.
- Import/export.
- Recovery.
- Privacy Policy.
- Terms of Use.

Capture significant states at desktop, tablet and mobile widths.

Do not use only one screenshot per page.

## Visual review criteria

Inspect:

- Alignment.
- Spacing.
- Typography.
- Cropping.
- Contrast.
- Surface consistency.
- Control density.
- Input sizing.
- Navigation hierarchy.
- Text wrapping.
- Overflow.
- Sticky elements.
- Card proportions.
- Image quality.
- Hover/focus states.
- Empty/loading/error states.
- Animation finishing states.

Use Playwright screenshot comparison where appropriate.

Keep baselines consistent across operating systems, browser versions and font environments.

Do not accept a visually poor screen because its automated test passes.

Perform a manual visual critique after the first implementation and fix material issues.

---

# 16. Systematic Implementation Strategy

Work in controlled phases.

## Phase 1: Research and baseline

- Inspect Git and working-tree state.
- Load both design skills.
- Read required documentation.
- Inventory frontend files.
- Map the architecture.
- Run baseline tests.
- Measure baseline performance.
- Capture baseline screenshots.

## Phase 2: Exhaustive audit

Perform independent reviews of:

1. Design system and CSS.
2. Navigation and application shell.
3. Routine management.
4. Exercise library and media.
5. Active workout experience.
6. History and progress.
7. Account/security UI.
8. Accessibility.
9. Performance and responsive layout.
10. Frontend integration and tests.

If parallel subagents are available, delegate distinct file groups while avoiding simultaneous edits to shared files.

Consolidate findings into one prioritised ledger.

## Phase 3: Design direction

Create a professional design brief based on the existing brand.

Define:

- Visual priorities.
- Design tokens.
- Typography.
- Grid.
- Spacing.
- Components.
- Interaction patterns.
- Animation vocabulary.
- Responsive rules.
- Accessibility standards.

Compare the proposed direction against the existing site.

Reject generic, unoriginal or unnecessarily complex redesigns.

## Phase 4: Implementation

Implement confirmed fixes and justified improvements.

Start with data integrity and serious usability problems.

Then improve components, layout, motion, accessibility and performance.

Avoid widespread refactoring without clear benefits.

Use the existing component architecture wherever appropriate.

## Phase 5: Verification

After each meaningful implementation batch:

- Run focused tests.
- Build the site.
- Inspect screenshots.
- Test affected interactions.
- Check keyboard accessibility.
- Check mobile rendering.
- Check console warnings.
- Check state persistence.

## Phase 6: Full validation

Run the complete feasible verification suite on the final working tree.

Do not claim a pass from an earlier commit after changing the implementation.

Investigate all new regressions.

## Phase 7: Final design critique

Inspect the completed site as a senior design reviewer.

Find inconsistencies that automated tests miss.

Fix remaining material visual and interaction defects.

Do not stop with an unfinished collection of individually polished screens.

---

# 17. Required Commands and Verification

Use the commands actually defined by the current repository.

Relevant existing commands include:

```
npm ci

npm run lint
npm run format:check
npm run typecheck
npm run docs:check

npm run test:unit
npm run test:worker

npm run build

npm run test:browser
npm run test:browser:production
```

For account-backed tests, use the documented isolated PostgreSQL test environment and required `TEST_DATABASE_URL`.

Run the relevant server and account suites whenever frontend changes can affect those integration contracts.

Do not skip PostgreSQL-backed tests while claiming full account verification.

Do not run production member-data mutations.

Use Lighthouse, browser performance profiling and accessibility tools where available.

Do not add large permanent tooling dependencies solely to generate a report.

Check clean-install reproducibility.

Keep the existing lockfile/version pinning policy intact.

Record exact commands and real results.

---

# 18. Deliverable: Complete Professional Audit Report

Create:

`docs/audits/forma-web-frontend-2026-11/`

Produce the following files.

### 1. `EXECUTIVE_AUDIT.md`

Project overview, current quality assessment, top risks, design opportunities, implementation outcomes and final engineering assessment.

### 2. `FILE_LEDGER.md`

Complete frontend-relevant file inventory including hashes, line counts, review status, changes and test evidence.

### 3. `FINDINGS.md`

All actionable findings, grouped by severity, with:

- Finding ID.
- Exact file and line.
- Problem.
- Reproduction.
- User impact.
- Root cause.
- Fix implemented.
- Verification.
- Remaining risk.

### 4. `DESIGN_SYSTEM.md`

Final FORMA web design system:

- Colours.
- Typography.
- Spacing.
- Layout.
- Components.
- Surfaces.
- Icons.
- Responsive rules.
- Motion.
- Accessibility.

### 5. `SCREEN_REVIEW.md`

Detailed screen-by-screen visual and functional assessment with before/after evidence.

### 6. `RESPONSIVE_AUDIT.md`

Viewport-by-viewport results, overflow checks, touch usability, mobile Safari observations and remaining issues.

### 7. `ACCESSIBILITY_AUDIT.md`

WCAG 2.2 AA mapping, automated and manual test results, fixed findings and unverified criteria.

### 8. `MOTION_REVIEW.md`

Motion system, transitions, interactive feedback, reduced-motion compliance and performance implications.

### 9. `PERFORMANCE.md`

Baseline and final measurements, build sizes, load performance, React profiling, Core Web Vitals methodology, improvements and regressions.

### 10. `TEST_RESULTS.md`

Exact test commands, environments, browser versions, test counts, passed/failed/cancelled/unrun checks and evidence links.

### 11. `SECURITY_PRIVACY_REVIEW.md`

Frontend security boundaries, authentication UI checks, sensitive-data handling and any unresolved privacy concerns.

### 12. `FINAL_REPORT.md`

Complete implementation handoff.

Include:

- Starting branch and commit.
- Modified files.
- Fixed defects.
- Implemented design improvements.
- Performance results.
- Accessibility improvements.
- Before/after screenshot index.
- Test results.
- Unverified checks.
- Remaining risks.
- Final readiness assessment.

Update `AGENT.md` and `CHANGELOG.md` with truthful, dated entries.

Do not remove historical notes.

---

# 19. Hard Constraints

These are mandatory.

1. Do not rewrite the website from scratch.
2. Do not remove features to simplify the design.
3. Do not introduce fake training data into production.
4. Do not change exercise IDs or historical measurements.
5. Do not alter workspace schema without explicit need and approval.
6. Do not weaken authentication or account isolation.
7. Do not expose API secrets.
8. Do not bypass existing security tests.
9. Do not break guest/offline functionality.
10. Do not silently replace or delete member records.
11. Do not add unnecessary dependencies.
12. Do not add external telemetry or third-party tracking.
13. Do not reduce artwork quality to improve metrics.
14. Do not remove media attribution or licence information.
15. Do not introduce inaccessible motion.
16. Do not disable focus outlines.
17. Do not weaken responsive checks.
18. Do not increase test timeouts merely to hide slow behaviour.
19. Do not change production account infrastructure.
20. Do not deploy to production or staging without explicit authorisation.
21. Do not merge or push without explicit authorisation.
22. Do not overwrite pre-existing uncommitted work.
23. Do not claim successful testing without observed evidence.
24. Do not declare the audit exhaustive without a reconciled file inventory.

---

# 20. Final Acceptance Criteria

The improved FORMA website should meet the following standard:

| Area               | Acceptance expectation                                            |
| ------------------ | ----------------------------------------------------------------- |
| Design identity    | Distinctive, recognisably FORMA, professionally cohesive          |
| Typography         | Refined hierarchy, readable at every tested viewport              |
| Responsiveness     | No material overflow, clipping or unreachable actions             |
| Navigation         | Clear, predictable and keyboard-accessible                        |
| Workout logging    | Fast, reliable and ergonomically optimised                        |
| Routine editing    | Reliable drag/drop, drafts, ordering and confirmations            |
| Exercise library   | Accurate, searchable, visually consistent                         |
| Media              | Correct exercise variants, reliable loading, proper attribution   |
| Motion             | Purposeful, polished and reduced-motion compatible                |
| Accessibility      | Evidence-backed WCAG 2.2 AA review and remediation                |
| Performance        | No unjustified regression; measurable improvements where possible |
| React architecture | Predictable rendering, safe effects, maintainable state           |
| Data integrity     | Existing saved workouts and contracts preserved                   |
| Accounts           | Functional, secure, accessible and reliable                       |
| Privacy            | No additional sensitive-data exposure                             |
| Cross-browser      | Verified Chromium, Firefox and WebKit journeys                    |
| Maintainability    | Reduced unnecessary complexity, clear code, reliable tests        |

A premium result must be visible in actual browser screenshots and supported by real behaviour, not just described in documentation.

---

# 21. Final Execution Directive

**START NOW. DO NOT STOP AT THE AUDIT REPORT.**

Your sequence is:

**READ → INVENTORY → BASELINE → RESEARCH → AUDIT → DESIGN → IMPLEMENT → TEST → INSPECT → REFINE → VERIFY.**

Read the entire applicable frontend source, line by line.

Load UI UX Pro Max and Frontend Design.

Understand the current FORMA product, its design philosophy and its previous engineering decisions.

Find and fix defects rather than only listing them.

Make meaningful, professionally justified visual and interaction upgrades.

Validate every major screen across desktop and mobile.

Use real browser screenshots to identify and fix visual problems.

Measure performance without inventing results.

Preserve account security, user data and offline reliability.

If a limitation prevents complete verification, state it precisely and complete the independent work that remains possible.

Do not hide unresolved issues behind an inflated quality score.

Do not prioritise superficial polish over correctness.

**The finished FORMA website should feel deliberately crafted, technically rigorous, visually distinctive and genuinely enjoyable to use.**

It should deliver an experience where every interaction, layout, animation, component and state has been considered.

**Make FORMA exceptional, without compromising what already works.**

## A few important details
