# Whole-row routine dragging

Follow-up in PR #9, approved by the owner on 17 October 2026 (Australia/Sydney).
The handle starts the gesture; the complete exercise row follows the pointer
or finger, nearby rows slide aside, and the row settles on release. Editable
prescriptions, expanded notes, arrow alternatives and native scrolling outside
the handle remain available. Reduced motion retains direct manipulation and
settles immediately.

## Current official documentation

Consulted on 17 October 2026. These are current living documents, not claims
that every design guideline was first published in 2026.

- [Motion Reorder](https://motion.dev/docs/react-reorder): single-axis lists,
  handle controls, layout animation and positioned rows for stacking.
- [Motion changelog](https://motion.dev/changelog?lib=motion): Motion 14.3.0,
  released 15 October 2026, pinned exactly with normal React 19 peer checks.
- [Drag controls](https://motion.dev/docs/react-use-drag-controls): handle-only
  activation, distance threshold, cancellation and `touch-action` on the handle.
- [Motion accessibility](https://motion.dev/docs/react-accessibility): respect
  the user's reduced-motion preference while preserving usable drag geometry.
- [Atlassian drag-and-drop guidelines](https://atlassian.design/components/pragmatic-drag-and-drop/design-guidelines):
  clear source and destination feedback and alternative controls.
- [Atlassian platform constraints](https://atlassian.design/components/pragmatic-drag-and-drop/web-platform-design-constraints/):
  native drag previews have platform-dependent limits. Its historical Windows
  measurements were not reproduced here or presented as a new 2026 finding.
- [Apple drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop):
  continuous feedback, auto-scroll, cancellation and alternative actions.
- [WCAG 2.2 dragging movements](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements):
  retain click/tap arrow controls as an alternative to dragging.

## Implementation and review

Motion is imported by the lazy prescription editor, rather than the initial
application bundle. Entry keys preserve each exercise's editable values during
reordering. Preview changes only the displayed order; superset normalization
runs once after a valid drop. Escape, pointer cancellation, window blur and
an outside drop restore the committed order. Escape is captured by the dialog
even after keyboard focus moves outside the row group; its regression first
failed with focus on Cancel and then passed twice in all five profiles. Saving and structural changes
are blocked during a gesture. No API, schema, migration or member-data change
is needed for this follow-up.

Independent review identified two issues before commit. Stationary edge
scrolling needed collision checks as newly revealed rows pass the held row;
Motion's pointer-driven check stops when pointer velocity is zero. Structural
controls also needed to stay disabled while preview indices differ from the
committed order. Both have explicit regressions. Auto-scroll uses elapsed time to retain its speed
at lower browser frame rates, with a bounded step to prevent resume jumps. The original whole-row test
failed against the native drag implementation before production code changed;
the edge and structural regressions also failed before their fixes.

Tests wait for the final dragged row geometry and active gesture before release
or measuring progress. This avoids a WebKit frame race without loosening saved
data comparisons, increasing timeouts or enabling retries.

## Visual evidence

The Browser plugin's JavaScript/REPL tool was unavailable in this environment;
the repository's Playwright setup was used. Runtime versions: Node 24.19.0,
Playwright 1.64.0, Chromium 156, Firefox 157 and WebKit 27.2. Standard suites use
two guest workers or one account worker, zero retries and unchanged performance
budgets. Matching browser builds used the environment's installed shared
libraries; host requirement validation was disabled because those libraries are
provided outside the system paths.

Reviewed at 1536 × 1024 desktop and 390 × 664 phone viewports. Both pages had the
title `My routines · FORMA`, visible populated dialogs, no error overlay,
horizontal overflow, page exceptions or console errors. The phone recording
uses trusted Chromium touch input through CDP. Mobile WebKit is browser
emulation, not a claim of testing on a physical iPhone.

| Evidence | Desktop | Phone |
| --- | --- | --- |
| Before | [Screenshot](desktop-before.png) | [Screenshot](phone-before.png) |
| During | [Screenshot](desktop-during.png) | [Screenshot](phone-during.png) |
| After | [Screenshot](desktop-after.png) | [Screenshot](phone-after.png) |
| Animation | [Recording](desktop-drag.webm) | [Touch recording](phone-drag.webm) |

[Machine-readable visual checks](visual-checks.json) contain synthetic fixture
results only. Eleven drag/editor scenarios run in all three development engines and all
five production profiles. Three additional trusted-touch scenarios run only in
Chromium mobile: drag/save, touch cancellation and native scrolling outside the
handle. A real-account journey verifies exact server-saved order and values
after reload in all five account profiles.

## Library selection and lime loading background

The owner also reported a missing routine-library selection shortcut and lime
loading backdrop. Public production asset hashes matched the recorded
`27e3728` deployment exactly; see the [comparison](live-build-investigation.json).
Neither behavior was found in the deployed source or reachable committed
history, so a specific revert could not be identified.

The editor now offers **Browse exercise library**. Its full search, activity,
equipment and muscle filters and reviewed thumbnails support selecting
movements. Back, Escape and the library close button return to the same draft;
name, duration, unsaved rep text, notes, supersets, expanded options, focus and
scroll position are preserved. The main library continues to open exercise
guides. Two browser scenarios verify selection/save/reload and returning with
unsaved values followed by a successful drag.

Actual session/workspace loading uses the existing lime palette behind the
graphite loading card. Local tests hold the real session request path pending,
check the backdrop and reduced-motion behavior, then release it and verify the
page appears without a forced delay. Product code adds no loading timer.

| Restoration | Desktop | Phone |
| --- | --- | --- |
| Lime loading | [Screenshot](desktop-lime-loading.png) | [Screenshot](phone-lime-loading.png) |
| Library chooser | [Screenshot](desktop-library-selection.png) | [Screenshot](phone-library-selection.png) |

[Restoration visual checks](restored-visual-checks.json) record both viewport
sizes, the computed lime color, populated dialogs and zero overflow, overlays
or browser errors.

The full development run exposed one Firefox click race: Save was enabled
while lazy-loaded prescription fields appeared and moved its target. A
controlled slow-load regression reproduced the enabled-button problem before
the fix. Save now waits for the fields to mount, including in its submit
handler; empty-editor validation remains available. The slow-load and original
stale-draft cases passed three repeats in every engine (18 checks).

The expanded-note test also exposed a delayed-drop race: resolving keys through
an old row snapshot could overwrite a note edited immediately after release.
Drop now submits keys and resolves them inside a functional update of the
latest parent state, preserving edits on either side of the callback. The
exact saved-note comparison remains unchanged.

## Local verification and test isolation

The complete production browser matrix passed 133 cases. The delayed-note
regression passed 15 repeats across five profiles; the slow-load and original
stale-draft regressions passed 18 repeats across three engines. The final dialog
Escape change passed ten focused checks across all five production profiles.
Unit (89), PostgreSQL API (49), Worker (21), and operations (14) checks passed.
The full development matrix initially exposed the lazy-loading race described
above; final-head CI reruns the entire expanded matrix rather than treating a
focused rerun as a complete development result.

A shared-server account run passed 62 of 65 cases before its synthetic members
exhausted Better Auth's rolling in-memory request bucket. Each browser profile
now starts its own existing test server and isolated database schema through
`scripts/test-account-browsers.mjs`. Production authentication limits, trusted
headers and test assertions are unchanged. The wrapper preserves CLI project
selection, output artifacts, failure exit status and signal handling. Discovery
and invalid-selection/failing-child checks were exercised before the full
isolated account matrix. All 65 cases then passed across five freshly isolated
browser profiles, with no failed project. Independent review found no important
remaining issues.

A subsequent complete development run caught a fast-release lifecycle race in
an existing duplicate/drag journey. A new four-gesture rapid-release regression
also reproduced the null reference in its first two attempts. The active state
now retains the gesture object, and the effect checks that exact identity before
installing listeners, scrolling or cleaning up. A finished gesture cannot read a
cleared ref or cancel a newer one. Event timestamps also reject an older queued
release/start/move after a later gesture begins. The rapid regression performs
four drags without waiting for Save between gestures. All saved-field assertions
remain exact. The final rapid-release and original duplication cases passed
three repeats in all three development engines (18 checks); follow-up review
found no remaining actionable issue.

## Final verification

The final CI matrix contains 390 development, 138 production-bundle, 65 account
and 65 production-account browser cases (658 total), with zero configured
retries. Final-head CI links, production/staging Worker versions and live asset
and boundary receipts are recorded in [PR #9](https://github.com/Raoof128/forma-workout-planner/pull/9).
