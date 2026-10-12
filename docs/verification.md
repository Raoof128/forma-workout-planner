# Verification record

## Current release-readiness audit — 12 October 2026

**NO-GO.** See the [current release report](qa/release-readiness.md), [interaction matrix](qa/interaction-matrix.json), [function matrix](qa/function-matrix.json), and [execution summaries](qa/verification-results.json).

The current cloud audit passed 31 unit tests, 79 development cases in system Chromium 154, and eight actual-production-build cases across desktop/mobile Chromium emulation, with zero retries. Clean dependency installation, lint, formatting, build, production dependency audit (zero reported advisories), local documentation checks and patch whitespace checks passed. Twenty repeated concurrent profile/session scenarios passed, but a historical intermittent failure remains unexplained.

This runtime could not install or launch pinned Chromium, Firefox or WebKit because downloads are blocked. Two hosted runs on `64dd74d1e061a7e472fe6825f28808ba89bbbec7` passed 237 development checks across pinned Chromium, Firefox and WebKit and 20 production checks across five desktop/mobile projects. See [hosted evidence](qa/hosted-ci-evidence.json). Two earlier hosted development failures remain unexplained; raw hosted artifact downloads are blocked. Together with explicit coverage gaps and the historical concurrency failure, these unresolved items prevent release acceptance. The older Chromium/Firefox results below belong to earlier work and are preserved as historical evidence, not results rerun during this audit.

## Data-layer audit — 12 October 2026

- `npm run lint`, `npm run format:check`, and `npm run build`: passed.
- `npm test`: **21 unit tests and 86 browser tests passed** (43 browser scenarios in Chromium and Firefox).
- Additional cross-tab stress run: **16 tests passed**, repeating both the existing independent-edit regression and a new 12-round simultaneous profile/session scenario four times per browser.
- Final production-build smoke tests in Chromium and Firefox: start → complete set → finish → reload passed, with persisted history and no page errors.
- `npm audit --omit=dev`: zero known production dependency advisories reported.
- Repository Markdown local-link check and `git diff --check`: passed.

The final run includes the existing accessibility and responsive checks. New tests cover lock API rejection, temporary-state revisions, preservation of both saved and unsaved originals, stale recovery, same-millisecond recovery IDs, invalid history/timestamps, backup byte limits, secure-context ID fallback, fractional weights, bounded timer pause, stale routine starts, and repeated concurrent updates. The additional snapshot-adapter unit test checks storage task boundaries while the lock remains held.

During verification, one fixture was corrected to wait for initial storage creation before simulating quota denial. A separate intermittent Firefox concurrent-write failure was reproduced before remediation; task boundaries within the lock were added and the repeated stress tests passed afterward. No automatic retries were used to hide these failures. See the [data-layer audit](backend-audit.md) for findings and scope.

## Earlier frontend design pass

Verified 12 October 2026 (Sydney) using Playwright Chromium and Firefox against the frontend-design polish.

## Automated results

- `npm run lint`: passed, including React Hooks and JSX accessibility checks.
- `npm run format:check`: passed.
- `npm run build`: passed; production React/Vite bundle generated.
- `npm test`: **72 tests passed** (36 scenarios in each browser). A subsequent timestamp-ordering refinement passed **4 targeted tests** across both browsers, including a new mixed-precision timestamp regression. The final suite contains 37 scenarios per browser.
- Production preview smoke test in Chromium and Firefox: start → complete set → save → reload passed with one persisted workout and no page errors.
- axe WCAG 2 A/AA, 2.1 AA, and 2.2 AA scans: **zero violations across 48 browser/page/dialog combinations**: 12 states at 1536px and 390px in both browsers. Scans wait for fonts and entry animation to settle.

Tests are in `tests/workflows.spec.js`, `tests/regressions.spec.js`, and `tests/accessibility.spec.js`, and `tests/responsive.spec.js`.

## Verified behavior

The full create/edit routine → log sets → pause/skip rest → reload → finish → history → progress workflow passes. Two sets of 8 reps at 50 kg produce 800 kg volume and 63.3 kg estimated 1RM. A single rep at 100 kg correctly reports 100 kg. Correcting a logged set to 80 kg × 5 updates volume to 400 kg and estimated 1RM to 93.3 kg; deleting the workout removes its contribution.

Concurrent-tab tests cover independent profile/session updates, independent fields in the same workout, finishing a session while updating preferences, and stale routine edits. The newest unrelated data survives. Invalid JSON, invalid nested profile data, and unknown exercise IDs are preserved without overwriting; original-data downloads match byte for byte. Export/import round trips and recovery from a valid backup pass. Blocked storage remains usable with explicit temporary-state copy and data export. A later storage-read failure preserves the existing session; recovery reports a storage-write failure separately from an invalid backup and leaves the original untouched.

Rapid typing retains every character. Rest duration, deadline, and paused remainder survive navigation/reload, and chosen duration is reused after the next set. Dialog focus remains on the selected button across timer ticks, wraps on Tab/Shift+Tab, and restores on Escape. Hidden mobile navigation is inert; open navigation traps focus and closes on Escape.

Routine drafts survive attempted dismissal. Renames preserve duration, exercise reordering preserves values, and removing/re-adding an exercise retains its prescriptions. The hero identifies the active session, and a different routine cannot silently replace it. Hash navigation, bookmarks, and browser Back work.

## Responsive and visual checks

- Maximum 60-character routine title retains a visible start action at 320, 390, 768, 1024, and 1536px.
- Eight progress bars fit inside the panel at 320px. Weekly zero-count bars have zero height.
- All seven main pages, routine detail/editor, and history detail/editor pass container-overflow checks at 320, 390, 540, 768, 1024, 1440, and 1920px in both browsers. Fixtures include long unbroken names/notes, 999.5 kg inputs, 100 reps, 12 sets, and eight high-volume sessions.
- At 667×375, the open navigation drawer scrolls to Settings and closes correctly.
- Local fonts load without third-party font requests, and reduced-motion preference suppresses entry animation.
- At 320px, mobile rest controls remain reachable while scrolling the workout. Detailed timer controls and exercise instructions work.
- Fresh desktop/mobile screenshots were reviewed for dashboard hierarchy, readable labels, flexible hero layout, workout controls, chart spacing, and narrow routine-editor fields. Automated captures are written to `<system temp>/forma-qa/<browser>/`; set `FORMA_ARTIFACT_DIR` to override the root.

The original `design-concept.png`, `desktop-preview.png`, and `mobile-preview.png` are historical design/build artifacts, not screenshots of the remediated build. The implemented fonts are locally served Barlow Condensed and DM Sans, with bundled OFL licenses. The hero now grows to fit its content rather than relying on the old fixed-height constraint.

## Limits

These results establish the tested Chromium and Firefox behavior. WebKit was downloaded but could not launch because this host lacks its Linux system libraries; Safari and physical iOS/Android devices were not verified. Physical assistive-technology testing was not run. Automated accessibility scans supplement the keyboard and visual checks and do not establish complete WCAG conformance. Local data remains tied to this browser; downloadable backups are the recovery path after site data is cleared. Persistent writes require Web Locks and available browser storage; unsupported or blocked saving uses the documented temporary mode.

See [audit-fixes.md](audit-fixes.md) for the initial functional remediation and [frontend-design-audit.md](frontend-design-audit.md) for the current design review and complete source-file coverage.
