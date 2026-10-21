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

| Evidence  | Desktop                          | Phone                              |
| --------- | -------------------------------- | ---------------------------------- |
| Before    | [Screenshot](desktop-before.png) | [Screenshot](phone-before.png)     |
| During    | [Screenshot](desktop-during.png) | [Screenshot](phone-during.png)     |
| After     | [Screenshot](desktop-after.png)  | [Screenshot](phone-after.png)      |
| Animation | [Recording](desktop-drag.webm)   | [Touch recording](phone-drag.webm) |

[Machine-readable visual checks](visual-checks.json) contain synthetic fixture
results only. Twelve drag/editor scenarios run in all three development engines and all
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

| Restoration     | Desktop                                     | Phone                                     |
| --------------- | ------------------------------------------- | ----------------------------------------- |
| Lime loading    | [Screenshot](desktop-lime-loading.png)      | [Screenshot](phone-lime-loading.png)      |
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
three drags without waiting for Save between gestures. All saved-field assertions
remain exact. The final rapid-release and original duplication cases passed
three repeats in all three development engines (18 checks); follow-up review
found no remaining actionable issue.

A later full run passed 389/390 cases and exposed a WebKit catch-up gap: a
170px move over about 45ms reached its physical destination, but order advanced
only one neighbor and stayed there while held. Motion checks one neighbor per
rendered order update and stops when pointer velocity reaches zero. The existing
RAF collision check now continues in the last pointer direction even without
scrolling; actual scroll direction takes precedence, and pointer reversal
updates the stored direction. DOM identity guards still permit one rendered
neighbor at a time. The Escape scenario retains its exact cancellation and superset assertions; a
new fast two-slot save case checks exact order and superset normalization.
Log review of 36 repeated scenarios also exposed a missing-neighbor exception
at the list boundary, despite their data assertions passing. An explicit neighbor
existence guard fixes it; a page-error check now applies to every drag scenario
and reproduced that exception before the guard.

The subsequent production matrix passed 141/143 cases. Both failures were the
new multi-slot save scenario releasing below the normal 664px phone viewport;
the app correctly cancelled those drops. That specific scenario now retains the
phone width with a 1100px viewport so the complete fast jump fits, and asserts
its release point is inside the viewport/dialog. Normal-height edge scrolling
and trusted-touch coverage remain in their original profiles. The corrected
multi-slot case passed three repeats in all five profiles (15 checks), completing
coverage of the 143 unique production cases. Final CI runs the complete matrix.

The superseded CI also exposed an immediate-release miss in the original
one-slot duplicate test. Six local repeats reproduced it once before the next
fix. A valid release now resolves its destination synchronously using the release
coordinate, pointer anchor captured on pointer-down and virtual row heights
keyed by entry ID. Capturing the visible row avoids assuming a preceding spring
has finished.
This handles a pending preview commit or snap-back transform without depending
on another animation frame. Cancellation bypasses this calculation. The rapid
three-gesture regression now requires an explicit expected saved order, rather
than deriving its expectation from the displayed order. Source and target use
stable exercise identities: positional locators could resolve the previous first
row before its queued drop committed and accidentally drag it onto itself.
Follow-up review found
no actionable issue in the resolver. All 36 repeated regressions and the complete
143-case production matrix then passed with page-error checks enabled.

A final CI run exposed an existing legal-page keyboard race. Its trace shows
`legal-title` without `tabindex` after load, then gaining it while the test
focused the contents link: the page-entry passive effect stole focus before
Enter activated the link. The existing navigation title/focus work now runs in
`useLayoutEffect`, before paint in this client-rendered application. The original
focus assertion is retained, with no delay, retry or larger timeout. Independent
review found no actionable concern. All 72 repeated legal/navigation/keyboard
checks passed across three engines before the full final-head verification.

A subsequent CI run passed all 393 development cases and 142/143 production
cases. The remaining mobile Escape fixture moved from y=232.59375 to
y=790.59375 in a 390×664 viewport, then expected two preview swaps while held
outside the viewport. Bounded edge/collision continuation intentionally runs
inside the visible dialog. This Escape fixture now uses the same 1100px phone
height as the two-slot save fixture, and explicitly checks the held pointer is
inside the viewport/dialog. It retains the exact two-slot preview, Escape,
original order and superset assertions. Normal-height phone edge and trusted
touch tests are unchanged. Independent review found no actionable concern;
all 25 repetitions across the five production profiles passed with zero retries.

The next push CI passed 392/393 development cases; the independent PR run
passed all 393 development and 143 production cases on the same application.
The failing rapid-drag trace shows `dragTo` pressing during a spring hit-target
interception, then retrying without releasing the button. An isolated WebKit
reproduction confirms that sequence emits only a pointer-down on the interceptor
and none on the intended source. The rapid regression now resolves the handle
with hover, sends exactly one trusted mouse-down/move/up per gesture and verifies
all three native presses reached the intended handle. It still releases
immediately, waits for no Save between gestures and requires the same exact
saved order and every prescription value. No application change or test retry
was added for this automation issue.

The explicit-input fixture next caught offscreen phone centers. It now aligns
the list below the sticky header before each press, fits the rapid phone-width
sequence onscreen and asserts visible release coordinates. Other phone edge
and trusted-touch cases retain normal viewport heights. With all three
intended native presses verified, the old bundle failed 11/20 rapid-scroll cases
across engines: scrolling before Motion's queued end callback changed the
geometry used to resolve the preceding release, altering saved order and
sometimes splitting the superset. The application now freezes the resolved
slot at native window pointer-up/cancel capture, before the queued callback.
Each immutable snapshot belongs to its press, pointer ID and start timestamp;
one release is accepted per press. The anchor is measured before focus, and
the later commit still checks cancellation, event time, membership and latest
field values. All 12 repeated rapid-scroll checks then passed across three
engines; independent review found no actionable issue. Full local and CI
matrices verify the complete change before frontend deployment. A full local
production attempt also exposed a default account-mode build used for guest
expectations; subsequent builds explicitly set `VITE_ACCOUNT_MODE=guest`. Its
stationary top-edge release showed why a scroll-advanced preview must be
retained when the pointer has not moved: the original anchor no longer
describes that displayed slot. This release now freezes the current preview
when RAF edge scrolling advanced it at the same pointer coordinates. All 30
rapid/top-edge repetitions across the five production profiles passed, followed
by the complete 143-case production matrix. Final review also clears the
stationary marker whenever the pointer moves, so returning to an old coordinate
cannot reuse it; focused checks and final-head CI verify that cleanup.

Focused WebKit instrumentation then reproduced a pre-release edge stall even
without another suite running. The page remained visible and focused; median
animation-frame intervals were 213–275ms. The old 100ms elapsed cap moved only
44px per frame at this edge, discarding most elapsed time and slowing the drag.
The cap is now a bounded 500ms, covering measured active intervals. Collision
continuation walks every crossed original-layout neighbor center and commits
one preview per frame. Unvisited neighbor positions remain valid across these
swaps; DOM-key guards reject pending layout/order mismatches. Independent
review found no actionable issue. Timeouts, progress assertions and retries
remain unchanged. All 60 rapid, fast-multi-row and top/bottom-edge repetitions
then passed across the five production profiles, followed by the complete
143-case production matrix on this final code.

## Parallel-load reliability (21 October 2026)

Three tests flaked under CI and local parallel load. Each was traced before
any change.

- **Returning from the library.** `<form hidden>` collapses every row to a
  zero box, and Motion springs each row towards it. Motion discards zero-size
  snapshots, so the reveal never animates, but the hide does. Per-frame
  instrumentation on the phone profile showed rows starting at
  `translate3d(35px, 764px)`. They were still 70–220 px off when the editor
  came back, so `scrollIntoView` and the drag helper measured moving rows.
  Three of five traced presses hit the sticky header and selected text
  instead of dragging. Layout transitions are now instant while the editor is
  hidden. A new regression case samples six frames after returning; it failed
  16 of 20 runs before the fix.
- **Rapid releases on CI WebKit.** The CI trace shows the third press aimed
  while the second gesture was still being processed. Motion delivers drag
  start and end on later frames, and on that runner they arrived about 700 ms
  apart. Playwright's hover found the handle stable between stalled frames,
  and the late commit then moved the row handle under the hovered point.
  Delaying only the page's `requestAnimationFrame` callbacks by 120 ms
  reproduces this locally; Chromium CPU throttling does not. App logs showed
  every gesture beginning and finishing with a valid release. The test now
  waits until the previous drop has landed at its expected slot and every row
  is at rest, then hovers and presses. With the lag, the old logic failed 11
  of 32 runs and the new logic passed 32 of 32.
- **Top-edge hold.** CI saved exactly the displayed order. The drop at slot 1
  landed between the two superset entries and correctly ungrouped both, which
  the expectation only allowed for the bottom direction. Releasing at slot 1
  on purpose failed the old expectation and passed the new one in all four
  production projects.
- **Holding until the list stops scrolling.** At load averages of 70–90 the
  same case failed 10 of 160 runs. Traces announce "Move cancelled" on
  release: the 2.3 s hold let edge scrolling reach the end of the list, so
  the form above it, or the Save row below it, sat under the stationary
  pointer, and the release counted as a drop outside the list. A stationary
  edge-scroll release is now checked against the dialog's visible area.
  Holding at each edge until scrolling stops, then releasing, failed 4 of 4
  runs before the fix and drops in the first or last slot after it. The
  advance case also measures the slot reachable without scrolling before the
  pointer moves; its old reading could arrive after scrolling had finished.

## Final verification

The final CI matrix contains 393 development, 143 production-bundle, 65 account
and 65 production-account browser cases (666 total), with zero configured
retries. Final-head CI links, production/staging Worker versions and live asset
and boundary receipts are recorded in [PR #9](https://github.com/Raoof128/forma-workout-planner/pull/9).
