# Complete test review

Commit: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`. All 70 manifest files (46 browser tests/helpers, 24 Node unit files; 457,180 source bytes) were read fully. Every file SHA256 was checked against the assigned manifest. Repository sources were unchanged. The separate `tests-review.json` contains exactly one row per assigned file.

No test suite was rerun by this sub-review. The parent audit's fresh 134/134 unit and 30/30 relevant WebKit results remain execution evidence; this document is static coverage/quality analysis. Most suites have strong exact-value persistence, identity, conflict, schema and accessibility assertions. A passing suite does not cover a scenario absent from its fixtures.

## T01 — P1 coverage gap: completion of the same hold target is never replayed across tabs

`tests/no-load-hold-timer.spec.js:105–177` runs a timer in one page. `tests/regressions.spec.js:52–87` races different fields and `:455–479` races finish against profile save; neither races the same set. `tests/accounts-conflicts.spec.js:257–307` proves exact whole-workspace retry and older-read suppression, not idempotence of a new completion command derived from stale state. `tests/accounts-workouts.spec.js:218–333` signs in the second client after completion. `unit/workout-session.test.js` covers set edits and entry changes, but has no completion reducer/replayed completion case; `unit/exercise-load.test.js:78–104` covers only timer eligibility/units.

The parent reproduction already showed two timers intended for Plank set 1 yielding two completed sets. Add a deterministic two-page timer test that starts the same target, lets both expire, and asserts `[true,false,false]`, unchanged values on later sets and one rest transition. Also cover manual completion from one page before the other's timer expires and deletion/reordering of the timer target. This is a missing regression for an observed defect, not a claim that the existing tests fail.

## T02 — P2 coverage gap: automatic completion checks no rest deadline

`tests/no-load-hold-timer.spec.js:128–145` advances slightly past expiry and checks only a completed set plus `restEnd !== null`. `tests/hold-metric-migration.spec.js:66–78` similarly checks saved duration/status only. `tests/workout-release.spec.js:242–290` asserts accurate deadlines for manually started rest, but not rest created by late automatic hold completion.

The parent reproduction delayed a 60-second hold by five minutes and observed a fresh full rest on resume. Exercise delayed callback delivery beyond both the hold and rest duration, assert the exact scheduled transition time/remaining rest, and distinguish manual early-end action time. A non-null deadline assertion allows the reproduced error.

## T03 — P2 coverage gap: navigation verifies the workout, not its active hold

`tests/wake-lock-lifecycle.spec.js:74–92` starts a hold then navigates away only to verify lock release. It never returns. `tests/ui-coverage-gaps.spec.js:333–375` asserts the session ID survives Back/resume but starts no hold. `tests/regressions.spec.js:171–198` covers persisted **rest** state, not the component-local hold state.

The parent reproduced hold loss on navigation. Add running and paused hold cases across another route, reload and remount, asserting timer identity, elapsed/remaining duration and exactly one completion. Do not treat existing rest continuity checks as hold continuity coverage.

## T04 — P2 coverage gap: no sound initialization or cue assertions

`tests/workout-release.spec.js:270–287` covers manual rest pause/resume/expiry only through saved fields and status text. `tests/regressions.spec.js:171–198` exercises manual presets without a sound assertion. Across all assigned files, there is no `AudioContext`, oscillator/start, or audio resume assertion; `muted` is only checked as a default in `tests/ui-controls.spec.js:278,326`.

The prior source audit found that fresh manual rest does not initialize audio. Add a fresh unmuted manual-rest start/resume test with instrumented AudioContext creation/resume and exactly one expiry cue, plus mute/no-cue and rejected-audio cases. This validates browser control wiring; audible behavior after device lock still requires physical-device evidence.

## T05 — P3 test portability defect: fixed development origins bypass configured baseURL

Absolute development navigation appears in `tests/accessibility.spec.js:77`, `tests/no-load-hold-timer.spec.js:4`, `tests/workout-release.spec.js:4`, `tests/persistence.spec.js:3`, `tests/regressions.spec.js:5`, `tests/responsive.spec.js:4`, `tests/security-release.spec.js:4`, `tests/ui-controls.spec.js:5`, `tests/ui-coverage-gaps.spec.js:5` and `tests/workflows.spec.js:8,165`. `tests/routine-preview.spec.js:144` classifies media as external using a fixed `127.0.0.1:5173` prefix; `tests/exercise-media.spec.js:47` uses a hostname prefix rather than the configured origin.

Changing Playwright baseURL alone cannot isolate these tests on a private port or run them against a built preview: they visit the old server or fail, and local assets can be mislabeled external. Use relative paths and derive allowed origins from configured baseURL/page URL; preserve explicit same-origin assertions. This is currently consistent with the default dev server but obstructs trustworthy isolated reruns and matrix expansion.

## T06 — P1 before native release: browser/device emulation cannot validate Watch or actual iPhone behavior

`tests/wake-lock-lifecycle.spec.js:5–23` replaces the WakeLock implementation; `:79–80` dispatches visibility events without a physical background transition. `tests/routine-drag-touch.spec.js:8–25,29` uses Chromium CDP touch injection. `tests/responsive.spec.js:79–128`, `tests/workflows.spec.js:161–197`, `tests/ui-controls.spec.js:405–456`, and `tests/accounts-workouts.spec.js:536–643` cover viewport layout/Axe rather than iOS keyboard/focus zoom, VoiceOver, locked-phone operation or real touch arbitration.

The Playwright production/account mobile projects use an iPhone 13 descriptor. None of the 70 assigned files contains native iOS/watchOS tests, HealthKit recording, WatchConnectivity delivery, workout mirroring, Always-On/haptic or account-bound device outbox validation. This is an evidence boundary and future native release gate, not a defect in using browser tests for web behavior. Record physical iPhone/Ultra 2 and macOS/Xcode evidence separately; do not present WebKit passes as hardware certification.

## T07 — P3 reliability risk: wall-clock bounds include unrelated runner latency

`tests/workout-release.spec.js:292–311` waits for a decrement, sleeps 1.2 seconds, then requires more than 56 seconds remaining, giving only a small budget for all automation delays. Its 2,000-workout case starts timing at `:456`, before seeding/navigation/reload, and demands less than ten seconds at `:495`. `tests/routine-programming.spec.js:115–128` requires narrow live countdown strings around interactions/reload. `unit/redteam-release.test.js:53–55,86–88` imposes 250 ms and five-second wall-clock budgets in the normal parallel unit suite.

These checks may fail from host contention or slow navigation without a product regression. Keep deterministic functional deadline assertions under a controlled clock; use a deliberately separate performance harness/baseline for performance budgets. Retain one real-time smoke with a realistic interaction budget. No new flaky failure was induced in this sub-review; prior AGENT entries already document severe host-load and drag timing sensitivity.

## T08 — P3 assertion gap: recovery-code rotation proves new display, not revocation

`tests/accounts-auth-controls.spec.js:185–207` compares displayed old/new recovery code arrays; it then disables MFA at `:212–230`. It does not attempt an old unconsumed code or a new code on a fresh sign-in challenge after rotation. `tests/accounts-lifecycle.spec.js:192–203` successfully consumes an enrollment code but does not exercise rotation.

Add the old-code rejection/new-code acceptance pair before disabling MFA. Server auth tests already cover a consumed code being single-use (`server/tests/auth.test.ts:456–470`); that is a different property. This report makes no claim that rotation is broken.

## T09 — P3 assertion gap: browser CSRF fixture uses an unsupported write method

`tests/accounts-security.spec.js:172–191` sends hostile-Origin **POST** `/api/workspace`; normal saves use **PUT** (`:164–168`). Its payload also references the revision from before the preceding successful save. The 403 expectation tests the broad origin gate, but does not demonstrate that a valid workspace mutation is rejected specifically for its Origin.

Use a valid current-revision PUT and verify persisted state remains unchanged. The server suite already uses PUT in `server/tests/security.test.ts:308–324`; this is a browser integration fixture weakness, not evidence of an authorization bypass.

## T10 — P1 before native/offline continuity: cloud retry coverage ends with the live repository instance

`unit/cloud-repository.test.js:202–238` retains failed serialized operations and retries on the same repository instance. `unit/cloud-refresh-races.test.js:148–170` tests retry against a late read error in that same instance. Disposal at `unit/cloud-repository.test.js:169–200` deliberately aborts in-flight and queued work. No test recreates the repository/browser process after a failed write and recovers a durable pending operation.

The existing implementation's in-memory retry limit is documented by the parent audit. A future durable account-scoped queue needs restart/termination, offline enqueue, duplicate acknowledgement, account switch/logout and stale-device replay tests. Do not infer restart-safe offline saving from current exact-retry passes.

## T11 — P2 release-matrix gap: hold timer regressions are excluded from built mobile profiles

`playwright.production.config.js:7–15` selects seven specs and omits `no-load-hold-timer`, `hold-metric-migration`, `timed-hold-switch`, and `wake-lock-lifecycle`. The account matrix selects only `accounts*.spec.js`, and its account workout journey has no timed hold. The default development projects are desktop browser profiles.

Consequently the checked-in suite can pass the built iPhone-emulation matrix without exercising hold start/pause/complete/cancel or timed identity switching. The parent's 30/30 WebKit subset is useful extra evidence but does not change the configured release selection. Make the hold specs baseURL-independent and include appropriate built desktop/mobile variants with correct mobile rest-dialog handling; retain hardware validation as a separate gate.
