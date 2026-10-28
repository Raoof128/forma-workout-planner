# Changelog

Notable changes are recorded here. Dates use Australia/Sydney. No versioned release tags have been published by this documentation update.

## Unreleased

### Raouf: 2026-10-28 — Native account fixes and animated navigation

- **Scope:** finish the local account app review and the owner's chosen SwiftUI
  Liquid Glass bar with icon bounce and scroll collapse.
- **Summary:** preserve edits during downloads and store switches; reject old
  session replies; stop abandoned sync engines; check durable unsent data at
  sign-out; isolate account origins and restrict Debug staging credentials.
- **Files:** native account/app/core/navigation code, app/core/UI tests,
  project, CI, README and `ios/docs/account-review-and-tab-bar-2026-10-28.md`.
- **Verification:** core 138/138, hosted app 13/13, final account UI 3/3 and the
  other 13 UI journeys pass; JS 151/151, Worker 35/35, static/resource checks and
  added-line secret scan pass. Signed Release installed and launched on iPhone.
- **Follow-ups:** live staging/production tests need usable FORMA credentials;
  the Watch rejects the Mac connection and needs companion USB pairing repair.
  No push, backend deployment or store submission.

### Raouf: 2026-10-28 — iOS: native accounts and sync (app half)

- **Account screens:** You › Account offers Sign in and Create account (name,
  email, 15+ character password, the website's two consents), email
  verification with resend, two-step code or recovery code, and forgot
  password (the reset finishes on the website). Signed in: profile (name,
  weekly goal, change email), security (change password, two-step on/off with
  recovery codes, active sessions, coach access), training data and privacy &
  account (sign out, delete account by emailed link).
- **Sync:** the account's workspace downloads on sign-in; every change saves on
  the iPhone first and is then sent. Offline changes wait and retry. A change
  on another device while the iPhone holds unsent edits shows the website's two
  choices (reload cloud data, or keep this iPhone's copy).
- **Phone training:** never merged silently. "Bring your phone training" shows
  counts, requires a saved copy of the account's data, then replaces the
  account's training (the website's import).
- **Storage and privacy:** session cookies live in the Keychain
  (this device only); each member has a separate saved copy; HTTPS only. The
  bundled privacy notice, privacy inventory and privacy manifest describe the
  account data (email, name, workout records and user ID, linked, app
  functionality, no tracking).
- **Not done:** backup-file import (the app has no file reader), live end-to-end
  against production (owner to run after the server release).

### Raouf: 2026-10-27 — iOS haptics for every action that needs one

- **Coverage:** every iOS action that warrants feedback now has a haptic, each
  using the system pattern whose documented meaning fits (HIG Playing
  haptics):
  - `.start` / `.stop` for workouts, holds and rest;
  - `.increase` / `.decrease` for stepped values;
  - `.selection` for changing exercise;
  - a soft or solid impact for reopening or adding a set;
  - `.warning` when an action is refused with a visible reason;
  - `.error` when a change cannot be saved.
- **Routing:** everything goes through one relay (`FormaHaptics.swift`), so
  each haptic is gated by You › Set confirmation haptics and plays only after
  its change has saved.
- **Watch:** now also confirms pause and resume.
- **Still silent:** navigation, tabs, toggles and routine saves, as the HIG
  advises.
- **Sign-in:** native sign-in across web and app has been mapped in
  `ios/docs/native-accounts-findings.md`. Nothing was built yet: it needs a
  new native auth route on the server and owner decisions.
- **Verification:** iPhone and Watch build with no errors.

### Raouf: 2026-10-27 — iOS: purposeful motion (Commit 2)

- **Motion system:** new `FormaMotion` resolves one level (full, minimal or
  off) from You › Motion and the system's Reduce Motion. On iOS 26.4+ it also
  honours Prefer Cross-Fade Transitions. The level comes with shared timing
  tokens. The Motion setting previously changed only a 1% button scale.
- **Workout:**
  - Set completion animates in place after the save commits.
  - The keyboard no longer drops while a set saves.
  - The rest dock slides in and shows a ring counting toward the saved
    deadline. When a rest ends on screen you get one haptic and a VoiceOver
    announcement.
  - The hold bar is smooth, and its digits change once a second instead of
    four times.
  - The receipt has a one-time seal and is the only place the success haptic
    plays. A saved set now gets a light tap.
- **Today, Plan, Progress, You, Watch:**
  - Entrances play once.
  - Start and Resume cross-fade, and Start shows progress at once.
  - Newly completed days fill in the week strip, and today is marked.
  - The chart fades in without ever drawing invented values.
  - The You footer explains each setting.
  - On the Watch, haptics fire when HealthKit confirms the workout has
    started or has been saved, and screens stay still in Always On.
- **Fixes found by the tests:**
  - **Rest dock:** its controls inherited the screen's accessibility
    identifier.
  - **UI tests:** the 5 baseline failures came from a duplicate "Finish
    workout" label, lazy list rows, and dropped simulator deletes. The tests
    were corrected without weakening any assertion.
- **Verification:**
  - **Builds:** iPhone and Watch passed in Debug (simulator) and in signed
    Release (iPhone Air).
  - **FORMACore:** 76 of 76 tests pass.
  - **UI tests:** all 12 pass on the final code. Two needed a rerun after
    stalls on the loaded Mac; the baseline was 3 of 8.
  - **Screenshots:** before and after for 9 screens in light and dark.
  - **Not run:** Instruments and on-device VoiceOver. See
    `ios/docs/commit-2/`.

### Raouf: 2026-10-27 — iOS launch and smoothness audit

- **Launch:** the launch screen was an empty `UILaunchScreen`, so iOS showed
  plain white until the first frame. It now uses a `LaunchBackground` colour
  matching FORMA's canvas in light and dark. `AppModel.load()` decoded the
  3.5 MB catalogue, opened SQLite and built the exercise index on the main
  thread (about 0.5 s in a debug build); that work now runs in a
  `@concurrent` task and the results are published once, following Apple's
  "Reducing your app's launch time" guidance. A Points of Interest signpost
  ("Prepare training space") marks it in Instruments. The loading screen now
  fills the window, removing a white frame around it.
- **Audit:** every Swift file in the iPhone app, the Watch app and
  `FORMACore` was reviewed by six parallel Sonnet 5.5 auditors, each owning
  separate files, then reviewed and integrated:
  - Core: a cached exercise-metric index instead of copying the 1,711-row
    catalogue per engine call; `save` skips re-decoding its own last write;
    precomputed search keys and `Exercise.filter(_:matching:)`. Release
    timings: toggle a set 0.79 ms → 0.003 ms, save a small workspace 2.7 ms
    → 0.10 ms, search per keystroke about 7 ms → 0.3 ms.
  - App: off-main, debounced library search; narrower observation
    (`hasWorkspace`, `activeWorkoutName`, cached routines and selectable
    exercises); a fast UTC date parser checked against
    `ISO8601DateFormatter` on 300,000 strings with no mismatch; cheaper
    week, volume-chart and "last time" calculations; the rest timer stops
    ticking once a rest is paused or over.
  - Watch: the 1 s timeline now redraws only the elapsed time; heart rate
    and energy publish only when the rounded value changes; unchanged
    readings go to the iPhone every 10 s instead of every second.
  - Kept as Apple documents it: WatchConnectivity still activates at
    launch (an auditor's deferral was reverted).
- **Verification:** iPhone and Watch builds with no warnings; FORMACore
  76/76 (71 existing plus 5 new; the suite now runs in 1.8 s instead of
  246 s). UI tests: 3/8 pass on the iOS 27.0 simulator; the same 5 also fail
  on the unchanged code, so they predate this work (duplicate "Finish
  workout" matches, keyboard focus and launch timeouts on that simulator).
- **Simulator note:** cold launches on this Mac's iOS 27.0 simulator spend
  seconds in `dyld` loading system frameworks; Apple's Settings app shows
  the same, so it is the simulator, not FORMA.

### Raouf: 2026-10-27 — cloudflared 2026.10.4 security upgrade

- Upgraded the tunnel connector from 2026.9.3 to 2026.10.4 (digest-pinned) in
  response to Cloudflare's eMudhra certificate advisory; versions before
  2026.10.2 trust compromised intermediates.
- Applied to staging then production by recreating only `cloudflared`; both
  report 2026.10.4 with four registered edge connections. API and database
  containers were not restarted.

### Raouf: 2026-10-26 — Runtime audit deployed

- Merged PR #30 (`10942dc`) and released the audited API then account website
  to staging and production. Both APIs run Node 26.12.1/Undici 8.12.2; deployed
  HTML and all four assets match the audited account build.
- Both environments passed 38 HTTP checks and 15 responsive functional states;
  backups, health, unchanged counts/other containers and zero observed API
  error lines were recorded. The same 30 baseline accessibility node findings
  remain follow-ups, without new or changed findings.
- CI security and non-browser checks passed. At 05:50 UTC, development
  browser CI had passed and later browser suites were unfinished. Temporary
  release-access cleanup completed at 05:48:47 UTC; deployment credentials
  were revoked. See [the release record](docs/qa/runtime-quality-2026-10-26/README.md)
  for exact versions, image identity and verification limits.

### Raouf: 2026-10-26 — Release preparation and scanner false positive

- **Scope:** prepare the owner-requested commit, push and redeployment of the
  completed audit; source commit `d770a6c` is published in PR #30.
- **Change:** reword one descriptive session-lifetime ledger sentence and add
  only its exact historical fingerprint to `.gitleaksignore`. The scanner
  matched the same ordinary prose twice; no credential material was present.
  Application code, dependencies and tested build inputs are unchanged.
- **Verification:** the original redacted report identifies the single ledger
  line and fingerprint. Recheck the complete history and documentation before
  release; do not broaden the rule or path allowlist.
- **Follow-up:** release the verified API image before the account frontend,
  staging before production, and record observed hosted outcomes separately.

### Raouf: 2026-10-26 — Full runtime and file audit

- Reviewed all 550 applicable human-maintained files and individually validated
  903 generated/imported/binary files: all 1,453 baseline paths accounted for.
  Added the six requested audit reports, exhaustive file ledger and targeted
  regressions under the existing source/test conventions.
- Fixed cloud refresh/write recovery races, a conflict-reload edit window,
  late wake-lock leaks, stale import reviews, cross-tab replacement crashes,
  imported-ID focus errors, overrange per-side targets, Sydney date/week
  inconsistencies, coach unilateral strength totals and invisible export errors.
- Aggregate Progress records in one pass; cache unchanged catalog search text;
  compute the captured guest fingerprint once per mount. Established workspace
  reads use one owner-filtered SELECT while retaining validation, transactional
  first creation and revisioned writes. The API survives idle database-client
  loss, and the gateway preserves the documented bearer challenge.
- Patch four transitive fast-uri lockfile records and use a scoped Miniflare
  Undici 7.30.1 override after advisory checks. Pin Node 26.12.1 with bundled
  Undici 8.12.2 in both Docker stages; direct library pins stay unchanged.
  Correct schema/auth/operations
  documentation and unsafe rollback instructions without rewriting historical
  release receipts. No migration, visual redesign or asset-quality reduction.
- Verification: lint, formatting, types, docs and builds pass; unit 134/134,
  server 67/67 on Node 26.12.1, Worker 27/27 and operations 14/14. Full npm
  audit reports zero vulnerabilities. All 902 browser cases have passing
  coverage: the original 901-pass/1-timeout run was investigated, and the
  affected 22-case profile passed unchanged at its original budget. Matched
  performance and screenshot evidence are recorded in the audit reports.
- The training lazy-load experiment was rejected after slower first navigation
  and an offline regression. Cold startup remains a documented opportunity.
  Changes are local and uncommitted; no deployment or production data change.
  See `docs/audits/forma-runtime-quality-2026-10/` for findings, exact metrics,
  test results, screenshot evidence and release-review limits.

### Raouf: 2026-10-22 — Dependency updates from Dependabot #15–#17

- One branch off `main` replaces the three stale Dependabot PRs: the API's
  Node base image digest (#15); better-auth 1.7.10, fastify 5.12.7,
  lucide-react 1.58.0, react and react-dom 19.3.1, zod 4.6.7 (#16);
  @playwright/test 1.64.1 and wrangler 4.151.1 (#17). ESLint stays at 9.39.5
  (#17's ESLint 10 breaks `npm ci`), and `.github/dependabot.yml` now ignores
  ESLint major versions. Exact version pins are kept.
- Verification: unit 117/117, worker 26/26, server 63/63 on PostgreSQL 18.4,
  operations, lint, Prettier, types, docs, web and server builds, full
  Chromium suite 164/164. The API image changes, so a release needs the API
  first.
- CI: the production-dependency audit retries up to three times when npm's
  advisory service errors (it returned 503 on `main`'s run of `93ea947`); a
  reported vulnerability still fails at once. `security-release.spec.js:35`
  waits for the restore's saves to settle before reloading (a pending save
  raised the leave-page prompt in WebKit and cancelled the reload).

### Raouf: 2026-10-22 — Hold timer and timed holds released

- Owner-approved release of PRs #20–#25, merged into `main` (`c4b3b2b`).
  API image `forma-api:holds-timer-20261022-316c5d9` on staging then
  production (schema 0006, no migration), then the websites: staging Worker
  `2b97ab5f-…`, production `28ef859c-…`; both one-hour tokens revoked.
- Production serves `index-DbISlD_R.js`, matching the local build of `main`;
  health 200, anonymous workspace 401, row counts and unrelated containers
  unchanged, no API error lines.
- Incident: the first production run omitted `-p forma-production`, and since
  both `compose.yaml` files are named `forma-staging`, the staging database
  container was recreated from production's config. Data and network were
  staging's, nothing migrated, production untouched; restored from staging's
  own files within minutes. Record: `docs/qa/holds-timer/`.
- `tests/exercise-media.spec.js:16` now waits for the first guide to close
  before searching again; it timed out once in Firefox on CI.

### Raouf: 2026-10-22 — CI fixes across the open PR stack

- `tests/routine-preview.spec.js` now waits for the animation SVG to decode
  (`toHaveJSProperty("naturalWidth", 960)`) instead of reading the width once;
  it failed on #21 and #24 under CI load. Fixed on `feat/exercise-animations`
  (`ceea460`, 10/10 in Chromium and WebKit) and merged forward through #21–#24.
- PR #19 merged into `main` (`c120eda`), bringing the 70-minute Verify limit;
  PR #20 retargeted to `main`. PR #25 had been cancelled at `main`'s old
  45-minute limit, not failed. #20's earlier failure was a WebKit focus flake
  (`legal.spec.js:111`) and #23's the drag flake that #25 fixes.

### Raouf: 2026-10-21 — Switch a routine hold to its timed version

- **What changed:** a routine that still counts a hold in reps (Hollow Hold,
  the L-sits, levers, Deadhang, Wall-sit, Parallel Bar Hold, Plate Pinch and
  the other timed aliases) shows **Use the timed version** under that hold in
  the routine editor. Pressing it keeps the hold's sets, load, RPE, rest,
  note, superset and place, and gives it a 60-second target the member can
  change before saving; workouts started from the routine then use the hold
  timer. In a running workout the hold's ⋯ menu has the same option, which
  asks first if it would discard completed sets and keeps the note, RPE and
  each set's load.
  The confirmation no longer reads "Replace L-sit with L-sit?".
- **Saved data:** nothing changes until the member presses the button and
  saves. Past workouts keep the rep ID and their reps. The switched entry
  keeps its old ID as `entryId`, which the schema already allows; no schema,
  validator or API change, so this needs no API deploy beyond the hold
  migration it builds on.
- **Not offered:** the legacy plank (10-second reps with its own timer) and
  seconds-and-metres exercises such as Battle Ropes, which already log time.
- **Files:** new `src/timedHolds.js`; `src/components/RoutinePrescription.jsx`,
  `RoutinePrescriptions.jsx`, `Routines.jsx`, `Workout.jsx`;
  `src/workoutSession.js` (`replaceEntry` keeps note, RPE and set load for
  the same movement); `src/styles.css`; `docs/user-guide.md`,
  `docs/research/exercise-logging-review.md`; new
  `unit/timed-hold-switch.test.js` and `tests/timed-hold-switch.spec.js`.
- **Verification:** unit 116/116 with 6 new tests (the routine switch keeps
  every field and its key and validates, history is untouched, a weighted
  hold keeps its load on the workout card). New browser spec 4/4 in Chromium
  and WebKit. Under heavy machine load the full development suite passed
  256/320 at first; rerun serially, 58 of the 64 failures passed and the
  remaining six WebKit keyboard-focus cases fail identically on the base
  commit. Production guest build: 124/160, with 31 Firefox launch failures
  (Firefox does not start in this sandbox) and 5 timeouts that passed 8/8
  when rerun. Lint, Prettier, types, docs and worker 26/26 pass. PostgreSQL
  server and account suites not run locally (Docker off); CI runs them.
  Not deployed.

### Raouf: 2026-10-21 — More holds and balances log seconds

- **What changed:** 15 more holds, balances and isometrics that were counted
  in reps now log seconds, with the hold timer, when they are added to a
  routine or workout. Loaded holds keep **WEIGHT (KG)** beside the seconds:
  Crucifix, Axe Hold, Incline Static Hold, Hercules Pillars and Dynamic side
  hold. Hip Raise, Lying keeps **ADDED (KG)**. No load: Balance Board,
  Downward Facing Balance, Frog stand balance, Single-leg BOSU balance,
  Single-Leg Balance with Eyes Closed, Kneeling Superman, Standing Pancake,
  Recruitment Pulls and Double-Leg Abdominal Press. The timer is now on 200
  of the 213 timed exercises.
- **Kept in reps after reading the guide:** Seated Knee Extension with
  Overpressure, Chin tuck and Single-Leg Soft-Landing Holds repeat a short
  hold for reps; Back bridge pushes up and lowers without a hold;
  Estiramiento de brazos y cuello describes no position to time; "Rest (for timed workouts)" is a placeholder, not a hold.
- **Saved data:** unchanged, as in the first review: each hold gets
  `forma-<saved ID>`, and the saved ID stays an alias in reps. The five
  one-side-at-a-time holds keep their side under the new ID.
- **Deploying:** API before frontend in each environment, staging first; do
  not roll back once a timed hold is saved. Not deployed.
- **Files:** `docs/research/exercise-quality-review.json` (15 reviewed
  `measurementCorrections`, 6 exclusions); regenerated
  `src/catalog/curation.json`, `src/catalog/machine-exercises.json`,
  `docs/research/catalog-quality-summary.json`, `src/catalog/media.json` and
  `docs/research/original-art/coverage.json`; `src/catalog/logging-review.json`;
  `src/catalog/unilateral.json`; `docs/research/original-art/registry.json`;
  `docs/research/exercise-logging-review.{md,json}`,
  `docs/research/catalog-quality.md`, `docs/user-guide.md`;
  `unit/hold-metric-migration.test.js` and
  `tests/hold-metric-migration.spec.js`.
- **Verification:** unit 111/111, including the extended
  `unit/hold-metric-migration.test.js` (5 tests; the identity and timed-set
  tests fail on the base catalogue). The hold browser spec passes 6/6 in
  Chromium and WebKit, including a new loaded-hold case (weight column,
  timer, seconds). Development suite on a private port at load average ~125:
  286/318 on the first pass. 26 of the 32 failures passed on a one-worker
  rerun; the six left are WebKit keyboard-focus cases that fail the same way
  on `feat/hold-metric-migration`. Production suite on a guest build: 129/129
  on Chromium and WebKit, desktop and mobile; Firefox does not launch in this
  sandbox. Lint, Prettier, types, docs, build, server build, worker 26/26 and
  operations 14/14 pass. The equipment audit is clean, artwork coverage is
  1,411/1,411, both catalogue builders rebuild byte for byte, and the
  compiled API accepts the timed IDs and rejects rep sets on them. The
  PostgreSQL server and account suites were not run locally (Docker off); CI
  runs them. An independent review of the 21 guide calls moved Back bridge to
  reps and tightened three reasons.
- **Follow-ups:** a guide repair for Estiramiento de brazos y cuello; a
  decision on the rest placeholder; Fast Skipping, Flutter Kicks, Mountain
  Climbers, Jumping Jacks, Foam Roller Anterior tibialis and 90/90 Breathing
  are timed intervals stored as reps, not holds, and were not reviewed here.

### Raouf: 2026-10-21 — Calisthenics holds log seconds with the hold timer

- **What changed:** 15 holds that were counted in reps now log seconds, with
  the hold timer, when they are added to a routine or workout: Hollow Hold;
  L-sit and its foot-supported, straddle and tuck versions; Front Lever and
  Front lever tuck; Back Lever; Planche Lean Hold; elbow lever; Ring Support
  Hold; Handstand; Deadhang (keeps **ADDED (KG)**); Sloper hanging; Sphinx.
  Each guide was checked first. Arch Hang stays in reps because its guide
  says "Hold it for time/reps". The timer is now on 185 of the 198 timed
  exercises.
- **Saved data:** each hold gets a new timed ID, `forma-<saved ID>`, with the
  same name, guide, licence and illustration, and the saved ID becomes an
  alias that keeps its rep units (the route the 14 October timed identities
  took). Sets, routines and backups saved in reps validate, show ("12 reps")
  and count toward volume as before, and a routine that lists one of these
  holds keeps counting reps until the hold is replaced. No schema, validator
  or stored-data change. Options weighed are in
  [the logging review](docs/research/exercise-logging-review.md#hold-metric-migration).
- **Deploying:** the API bundles the catalogue and rejects exercise IDs it
  does not know, so deploy the API before the frontend in each environment,
  staging first. Once anyone has saved a timed hold, fix forward rather than
  rolling back: an older API or frontend cannot read that data. Not deployed.
- **Files:** `docs/research/exercise-quality-review.json` (15 reviewed
  `measurementCorrections`; Arch Hang under `excludedMeasurementCorrections`);
  regenerated `src/catalog/curation.json`, `src/catalog/machine-exercises.json`
  and `docs/research/catalog-quality-summary.json`;
  `src/catalog/logging-review.json`; `docs/research/original-art/registry.json`
  with regenerated `src/catalog/media.json` and `coverage.json` (assets
  unchanged); `docs/research/exercise-logging-review.{md,json}`,
  `docs/research/catalog-quality.md`, `docs/user-guide.md`; new
  `unit/hold-metric-migration.test.js` and `tests/hold-metric-migration.spec.js`;
  a comment on `guideExercise` in `src/data.js`.
- **Verification:** unit 110/110, including 4 new tests: the identity and
  timed-set tests failed on the base catalogue first, and the saved-reps test
  fails if any hold gains a programming alias. The new browser spec passes
  4/4 in Chromium and WebKit; it failed on the base catalogue first. Full
  development suite, Chromium and WebKit on a private port: 309/316. All
  seven failures were in WebKit. The concurrent-tabs case passed on rerun,
  and six keyboard-focus cases fail the same way with the base catalogue.
  Production suite on a guest build (Chromium and WebKit, desktop and mobile):
  127/129. Both failures were the drag-timing test
  `routine-library.spec.js:78`, which failed 2 of 6 runs on the base
  catalogue and passed 6/6 on this branch at the same load. Lint, Prettier,
  types, docs, build, server build, worker 26/26 and operations 14/14 pass.
  The equipment audit is clean, artwork coverage is 1,411/1,411, both
  catalogue builders rebuild byte for byte, and the compiled API validates
  the new IDs. Firefox does not launch in this sandbox, and the PostgreSQL
  server and account suites were not run locally: Docker was off and another
  session was loading the machine. CI runs them. After the review fixes
  (tests, docs and a comment), the unit suite and the new spec were run
  again.
- **Follow-ups:** a one-tap "switch to the timed version" for routines that
  list a migrated hold (it would also cover the 14 October timed identities);
  about 20 other holds flagged in `docs/research/exercise-logging-review.json`
  (Crucifix, Axe Hold, Incline Static Hold, balance holds, Back bridge and
  others) are still stored as reps and need the same review.

### Raouf: 2026-10-21 — No weight column for no-load exercises, and a hold timer

- **Load review:** all 1,411 selectable exercises were read by name,
  equipment and guide and classified (`src/catalog/logging-review.json`;
  method, counts and flags in `docs/research/exercise-logging-review.md`).
  787 log a kg load; 57 are bodyweight with an optional added load and label
  the column **ADDED (KG)**; 567 carry no external load (the ab roller, the
  plank, most push-up variations, stretches, band work) and no longer show a
  weight column in the workout, the history editor, the routine editor or the
  guide. A set that already carries weight keeps the column, so older logs
  stay visible. Timed exercises no longer show a "1 reps" target, and history
  drops "0 kg" for no-load sets.
- **Hold timer:** 170 of the 183 exercises measured in seconds (13
  rep-prescribed drills are excluded) show a settable countdown at the top
  of their card: −5/+5 s, Start, Pause/Resume, End set (logs the time held)
  and Cancel (logs nothing). At zero it logs and completes the set and starts
  the programmed rest, as ticking it would. While running it holds a screen
  wake lock (requested again when the page is shown) and it ends with the
  existing cue: a beep unless muted, and a vibration where supported. The
  starter Forearm plank keeps its units: 10-second steps, one rep for every
  full 10 seconds, at most 100 reps, and no timer while it logs each side.
- **Display only:** stored sets keep `weight` (0 when nothing is added), so
  `src/exerciseMetrics.js`, `src/storage.js`, the API and saved data are
  unchanged and no API deploy is needed. The timer is local state and is not
  saved.
- **Docs read:** MDN Screen Wake Lock API (updated 11 Sep 2026), Page
  Visibility API, Vibration API (not available on iOS Safari), WCAG 2.2
  SC 2.2.1 (a timer the member starts and can pause is not a time limit).
- **Files:** `src/exerciseLoad.js`, `src/catalog/logging-review.json`,
  `src/components/HoldTimer.jsx`, `unit/exercise-load.test.js`,
  `tests/no-load-hold-timer.spec.js` and
  `docs/research/exercise-logging-review.{md,json}` (new); `Workout.jsx`,
  `RoutinePrescription.jsx`, `HistoryEditor.jsx`, `Insights.jsx`,
  `ExerciseGuide.jsx`, `src/styles.css`, the user guide, README and AGENT.md.
- **Verification:** unit 106/106; the new spec 10/10 in Chromium and WebKit;
  full Chromium suite 155/155, then the workout, UI and workflow specs 26/26
  after the legacy-plank timer; production build in Chromium and WebKit,
  desktop and mobile, 126/129. Of the three failures, the concurrent-tabs
  test passed 3/3 on rerun, and the library drag test
  (`routine-library.spec.js:78`) is timing-flaky in Chromium mobile on the
  base commit too (2 of 6 runs fail there; its rows render unchanged). Lint,
  Prettier, types, docs and build pass; checked by hand at 375 px. Not
  deployed.
- **Follow-ups:** about 15 genuine holds are stored as reps (Hollow Hold,
  L-sits, Front and Back Lever, Handstand, Deadhang), so they get no timer
  until a reviewed metric migration; 75 equipment labels are misleading
  (mostly machine or cable lifts labelled Bodyweight).

### Raouf: 2026-10-21 — Routine-editor drag tests reliable under parallel load

- **Fix:** routine rows no longer slide back into place after you close the
  exercise library. Hiding the editor made every row spring towards an empty
  box. If you returned within about 400 ms, the rows reappeared mid-spring,
  70–220 px off, and a press could land on the header or a moving handle.
  Layout changes now settle instantly while the editor is hidden.
- **Fix:** holding a row at the top or bottom edge until the list stops
  scrolling now drops it in the first or last slot, as the preview shows.
  Scrolling moved the list away from the held pointer, and the release was
  treated as a drop outside the list and cancelled.
- **Tests:** the new case `returning from the library shows the exercise rows
at rest` failed 16/20 before the fix. The rapid-release case now waits, before
  aiming each press, until the previous drop has landed at its expected slot
  and every row is at rest. That also checks each intermediate landing. The
  edge-hold case derives the expected superset from the final order, because
  a top-edge drop can land between the superset's two entries, and it measures
  the slot reachable without scrolling before the pointer moves. New cases
  hold at each edge until scrolling stops; both failed 4/4 before the fix.
- **Root causes:** `routine-library.spec.js:78` pressed rows still sliding
  after the library closed; three of five traced failures hit the sticky
  header. The CI WebKit failure of `routine-drag.spec.js:77` aimed its third
  press before the previous drop had been committed. Motion delivers drag
  start and end on later frames, and those frames lagged about 700 ms. The CI
  failure at `:321` (now `:408`) saved the displayed order exactly; the drop at
  slot 1 correctly ungrouped the superset, which the old expectation did not
  allow. Under heavier load the same case also cancelled drops: a longer hold
  let scrolling reach the end of the list before the release.
- **Files:** `src/components/Routines.jsx`, `RoutinePrescriptions.jsx`,
  `RoutinePrescription.jsx`, `tests/routine-drag.spec.js`,
  `tests/routine-library.spec.js`, `docs/qa/routine-row-drag/README.md`,
  `AGENT.md`.
- **Verification:** 20 repeats of each of the seven affected cases, one suite
  at a time at the default two workers: 560/560 in the production Chromium
  and WebKit desktop and mobile projects, 280/280 in development Chromium and
  WebKit. Full production suite 141/141; editor-related development specs
  205/210, the five failures being WebKit focus cases that fail the same way
  on unmodified `main` on this Mac. Lint, format, types, docs and 98 unit
  tests pass. Firefox cannot launch here; CI covers it.

### Raouf: 2026-10-21 — CI time limit for the Verify job

- Raised the `Verify application` job limit from 45 to 70 minutes. The
  development browser suite now takes about 23 minutes and the account
  integration steps were being cancelled at the limit: on `main` (`307b3ea`,
  19 Oct) and on PR #19, where step 22 was cut off after the earlier suites
  passed. A cancelled step is not a pass, so PRs are merged only after a full
  green run.

### Raouf: 2026-10-21 — Card animations released

- Owner-approved deploy of `7079e21` (`feat/exercise-animations`, PR #20):
  staging Worker version `9814b283-9b12-4418-b3ad-c724ce27a4f0`, production
  `5fa82b05-afea-4dee-94f9-613a67e0f043` (68 new assets, including the 64
  animated and still SVGs); both one-hour tokens were revoked.
- **Live check on forma.raoufabedini.dev:** in the Push day template preview
  the bench press card shows the cover illustration, the video, then the
  animation, which loads at 960 px and pauses to its still; no console errors.

### Raouf: 2026-10-21 — Animated demonstrations in the exercise cards

- **What changed:** the 32 animated SVG demonstrations now appear at the top
  matching exercise cards in the routine preview, the single-exercise card
  and the exercise guide (library and active workouts). Order in a card:
  cover illustration, then the video clip when there is one, then the
  animation (directly under the illustration when there is no video). They loop with phase captions; a Play/Pause
  button below each one swaps to a still start pose, and they start paused
  when the device asks for reduced motion.
- **Files:** `src/components/ExerciseAnimation.jsx` (new),
  `RoutinePreview.jsx`, `ExerciseGuide.jsx`, `src/styles.css`,
  `src/catalog/animations.json` (new), `public/exercise-animations/` (new,
  animated and still SVGs; the duplicate copies in `assets/exercise-svg/`
  were removed, leaving the review sheets), `scripts/exercise-svg/build.py`
  and `rig.py` (still mode, ID manifest), `unit/exercise-animations.test.js`
  (new), `tests/routine-preview.spec.js`, README and user guide.
- **Verification:** unit 100/100; routine-preview spec 14/14 in Chromium and
  WebKit (playback, pause to still, keyboard focus, reduced motion);
  media, UI, accessibility, keyboard, catalog, responsive, regression,
  workflow, editing and programming specs 86/86 in Chromium; lint, Prettier,
  types, docs and build pass; checked by hand at desktop and 375 px. The
  build output is byte-stable. Not deployed.

### Raouf: 2026-10-21 — Production release of the preview and demo work

- Owner-approved production deploy of `846919b` with
  `npm run worker:deploy:production`: Worker
  `forma-workout-planner-production`, version
  `c0778873-1a38-482e-8971-0bd15b0b4231`, the same 48 new assets as staging;
  the one-hour deploy token was revoked. Frontend only; the API is unchanged.
- **Live checks on forma.raoufabedini.dev:** home 200; bundle
  `index-u60d_fDw.js` (identical to staging) contains the preview and demo
  code; the bench press clip and poster return 200 as `video/mp4` and
  `image/jpeg` under the unchanged CSP. In a browser, the Push day template
  preview opened on "1 of 4: Barbell bench press" and the clip played with
  its CC BY credit; no console errors.

### Raouf: 2026-10-21 — Staging release of the preview and demo work

- Pushed `feat/routine-preview-demos` and opened
  [PR #19](https://github.com/Raoof128/forma-workout-planner/pull/19).
- Owner-authorised staging deploy of `27a43e9` with
  `npm run worker:deploy:staging`: Worker `forma-workout-planner-staging`,
  version `85e28324-f611-487e-b9a6-773fe4dda76e`, 48 new assets including the
  22 demonstration clips; the one-hour deploy token was revoked. Frontend
  only, no API or schema change. Staging is behind Cloudflare Access, so the
  live check from the agent stopped at the Access redirect.
- **Not yet in production:** the production deploy was blocked by the agent
  session's permission policy and is waiting for the owner to run
  `npm run worker:deploy:production`. Merge PR #19 after CI so `main` matches
  what is deployed.

### Raouf: 2026-10-21 — Romanian deadlift demo polished

- The arms now stay straight and the bar position is solved where straight
  arms meet the front of the legs, so it slides down the thighs and shins to
  the knees. A dotted flat-back guide shows at the hamstring stretch, followed
  by a red rounded-back outline with a cross ("Never let the back round").
  Checked in Chromium and WebKit.

### Raouf: 2026-10-21 — Animated demos for Legs B

- Five more animated SVG demos in `assets/exercise-svg/legs-b/`: dumbbell
  goblet squat (front and side views), Romanian deadlift (soft knees, hips
  back, bar sliding down the legs to a hamstring stretch), leg press
  (standard stance, hips stay down), dumbbell reverse lunge and barbell hip
  thrust (chin tucked, one-second squeeze). The routine's seated leg curl and
  standing calf raise reuse existing demos.
- Verified by reviewing start, middle and end frames in Chromium, two demos
  in WebKit, and a byte-identical rebuild of all 33 files.

### Raouf: 2026-10-21 — Animated demos for Upper B

- Six more animated SVG demos in `assets/exercise-svg/upper-b/`: incline
  dumbbell press, wide-grip lat pulldown and face pull (front and side views
  together), seated cable row, cable rope overhead triceps extension (rope
  from the low pulley lowered behind the head to a full stretch, per the
  FORMA guide) and incline dumbbell curl. The routine's lateral raise reuses
  the existing core-set demo.
- Verified by reviewing start, middle and end frames in Chromium, the two
  dual-view demos in WebKit, and a byte-identical rebuild of all 28 files.

### Raouf: 2026-10-21 — Animated SVG exercise demonstrations

- **What changed:** 22 self-contained animated SVGs show how to perform the
  exercises in three routines (upper body, legs, core) without video: a figure
  moves through each rep at its tempo with phase captions, a progress bar,
  the bar or handle path, working-muscle highlights, and fault outlines for
  the ab roller and plank. Twisting moves use a 3D camera; the lateral raise
  shows front and side views together. About 100–160 KB each, fonts embedded.
- **Tooling:** `scripts/exercise-svg/` (Python, standard library only)
  rebuilds `assets/exercise-svg/` deterministically; see
  [the README](assets/exercise-svg/README.md).
- **Verification:** start, middle and end frames of every demo reviewed in
  Chromium, spot-checked in WebKit; all files are valid XML and a rebuild is
  byte-identical. Not shown in the app yet.

### Raouf: 2026-10-21 — Demonstration clips and single-exercise card

- **Single exercise:** selecting an exercise name in a routine overview now
  opens only that exercise's card (illustration, prescription, demonstration
  and guide) with **Back to overview**, instead of the whole workout preview.
  **Preview workout** still steps through every exercise.
- **Demonstration clips:** 22 exercises gain a short, silent, looping video in
  the preview and in the exercise library guide: barbell bench press, incline
  bench press, back squat, deadlift, trap-bar deadlift, standing military
  press, pull-up, bent-over row, 45-degree leg press, calf press on the leg
  press, seated leg curl, leg extension, machine chest press, machine shoulder
  press, seated machine row, seated back extension, dumbbell shoulder press,
  dumbbell biceps curl, superman, double kettlebell push press, knee tuck jump
  and backward medicine-ball throw. Sources: CDC and U.S. Army (public domain)
  and FitnessScape (CC BY 3.0), credited under each clip. Each was reviewed
  frame by frame against the exact FORMA variant; 16 uncertain matches are
  held back. Clips are self-hosted (5 MB in total), never autoplay and load
  only when played.
- **Tooling:** `docs/research/exercise-videos/registry.json` records every
  candidate, licence, checksum, review and trim;
  `scripts/build-exercise-demos.mjs` rebuilds `public/exercise-demos/` and
  `src/catalog/demos.json`; `unit/exercise-demos.test.js` guards them.
- **Files:** `src/components/ExerciseDemo.jsx`, `RoutinePreview.jsx`
  (`PreviewSlide`), `Routines.jsx`, `ExerciseGuide.jsx`, `UI.jsx`,
  `src/styles.css`, `src/catalog/demos.json`, `public/exercise-demos/` (new),
  `scripts/build-exercise-demos.mjs` (new), `unit/exercise-demos.test.js`
  (new), `tests/routine-preview.spec.js`, `tests/ui-controls.spec.js`,
  `docs/user-guide.md`, `docs/research/exercise-videos.md`.
- **Verification:** preview spec 10/10 in Chromium and WebKit, including clip
  playback in both and no external media requests; unit 99/99; lint,
  Prettier, type check, docs check and build pass; 15 affected Chromium specs
  94/95, the failure being the focus-trap test that assumed nothing focusable
  between Close and Got it (updated, then 49/50 across both engines for the
  UI, keyboard and accessibility specs). The remaining WebKit failure,
  account-import focus, also fails on `main`. Firefox cannot launch in this
  environment. Not committed or deployed.

### Raouf: 2026-10-21 — Preview a routine or template without starting it

- **What changed:** routines can be looked through exercise by exercise before
  training. **Preview workout** sits in the routine overview and in each
  routine card's **⋯** menu, and each exercise name in the overview opens the
  preview at that exercise. Every workout template has a **Preview** button,
  so it can be checked before **Add to my routines**. Each step shows the
  FORMA illustration, sets × reps or measurement, RPE, rest, notes, muscle and
  equipment, and the full technique guide with its credits. Previewing never
  starts a workout or changes saved data.
- **Accessibility:** follows the WAI-ARIA APG carousel pattern: labelled
  carousel and slides ("2 of 6: …"), Previous/Next keep focus and stay
  focusable at the ends, a polite one-line announcement per step, and an
  exercise strip for jumping (current item `aria-current="step"`). Focus moves
  to **Back to overview** on entry and returns to the opener on exit. On
  screens under 480 px Previous/Next show arrows only.
- **Demonstration videos:** researched, not shipped. Open-licence clips that
  can be self-hosted (CDC and US Army public domain, FitnessScape CC BY, wger
  CC BY-SA) cover roughly 2–5% of the catalogue; see
  [the research note](docs/research/exercise-videos.md). The preview has an
  empty video slot (`ExerciseDemo`, `src/catalog/demos.json`) for reviewed
  clips.
- **Files:** `src/components/RoutinePreview.jsx`, `GuideInstructions.jsx`,
  `ExerciseDemo.jsx`, `src/catalog/demos.json` (new); `Routines.jsx`,
  `RoutineCardOrder.jsx`, `ExerciseGuide.jsx`, `src/App.jsx`,
  `src/styles.css`; `tests/routine-preview.spec.js` (new);
  `docs/user-guide.md`, `docs/research/exercise-videos.md` (new).
- **Verification:** new spec 6/6 in Chromium and WebKit; preview, responsive
  and accessibility specs 62/62 across both engines after the narrow-screen
  fix; 15 affected Chromium specs 96/99 on the first run, with the three
  failures (history order, reduced-motion drag outline, personal training
  workflow) passing on rerun; unit 98/98; lint, Prettier, type check and docs
  check pass. Firefox could not launch in this environment, on any spec.
  Checked by hand in the dev preview at desktop width, 375 px and 316 px. Not
  committed or deployed.

### Raouf: 2026-10-19 — Per-exercise ⋯ menu in a running workout

- **What changed:** the single **Edit workout** dialog on the active workout
  is replaced by a **⋯** menu on each exercise card (Move up, Move down,
  Replace exercise, Remove exercise) and an **Add exercise** button below the
  last card, matching how mainstream workout loggers place these actions.
- **Replace** is new: the replacement takes the slot, superset and rest of
  the old exercise and keeps every set when both log the same fields;
  otherwise it starts the same number of fresh sets and asks first if
  completed sets would be lost.
- **Accessibility:** `ActionsMenu` follows the WAI-ARIA APG menu button
  pattern (`aria-haspopup="menu"`, `aria-expanded`, roving focus, arrows
  wrap, Home/End, Escape returns focus, Tab and outside clicks close).
  Unavailable actions stay listed with `aria-disabled`, and the menu opens on
  the first available one. After a move, add, replace or remove, focus
  returns to the affected card's ⋯ button and the change is announced. The
  confirm dialog focuses **Keep** first.
- **Files:** `src/components/ActionsMenu.jsx` and `ExercisePicker.jsx` (new),
  `WorkoutEditor.jsx` (removed), `Workout.jsx`, `src/workoutSession.js`
  (`replaceEntry`, `setsLostByReplacing`), `src/styles.css`,
  `tests/workout-editing.spec.js`, `unit/workout-session.test.js`,
  `docs/user-guide.md`.
- **Verification:** unit 98/98; the editing spec 10/10 in Chromium and WebKit
  and 15/15 over three Chromium repeats; accessibility, responsive,
  keyboard-focus, workout and regression specs 69/70 in Chromium, the one
  failure being the known intermittent empty-overview case. Checked by hand
  in the dev preview with mouse and keyboard, and at 390 px.

### Raouf: 2026-10-19 — Workout and coach release deployed

- Owner-authorised release of PR #14 (`98f853d`) to private staging and
  production: workout editing, fill-remaining-sets, left/right reps and
  full-access coach tokens.
- **Fix found while releasing:** the API image lacked the two shared
  catalogue files the server now imports, so it would not have started. CI's
  image step caught it as a build error; `98f853d` adds them to
  `ops/Dockerfile`, and CI now imports every server module inside the image.
- API image `forma-api:workout-coach-20261019-98f853d` with migration 0006 on
  both environments. Production Worker `a09aec75-…`, staging Worker
  `27deb76c-…`. Encrypted backups before and after each API switch; row
  counts and unrelated containers unchanged. Production's three existing
  coach tokens are read-only; mint a full-access token to let a coach edit.
- Live checks passed; see [the release record](docs/qa/workout-coach/README.md).

### Raouf: 2026-10-19 — Full-access coach tokens

- **What changed:** coach tokens gain a scope chosen when they are minted.
  **Read only** (the default, and every existing token) keeps the training
  summary. **Full access: read and edit** can also read the whole workspace
  and change any part of it: routines, the active workout, history, profile
  and schedule. Account › Security offers the choice, labels each token's
  scope and resets to read-only after each mint.
- **New bearer routes:** `GET /api/coach/exercises` searches the catalogue
  (IDs, logged fields, per-side defaults) for any token.
  `GET /api/coach/workspace/data` returns `{ data, revision, updatedAt }` and
  `PATCH /api/coach/workspace/data` replaces named sections, for `full`
  tokens only. The summary now reports `access` and includes per-set RPE and
  left/right `sides`.
- **Safety:** edits use the member save path (row lock, revision check,
  idempotent `operationId`, the shared strict validator) and return field
  `issues` on refusal. Removing logged workouts needs `removesSessions` equal
  to the count removed. 60 edits per token per hour. The edit needs no
  browser `Origin`, but a foreign `Origin` or a cross-site request is
  refused. No token can reach email, password, sessions, 2-step
  verification, coach tokens or account deletion. New security events:
  `coach_scope_denied`, `coach_token_rate_limited`, `coach_workspace_write`.
  Threat T-25 and coverage row API2-06 added.
- **Internals:** `putWorkspace` and the new `patchWorkspace` share one
  `writeWorkspace` transaction. Migration `0006-coach-token-scope` adds the
  checked `scope` column with default `read`; no grant change is needed.
- **Files:** `server/coachRoutes.ts`, `server/coachTokens.ts`,
  `server/workspace.ts`, `server/schema.ts`, `server/app.ts`,
  `server/securityEvents.ts`, `server/migrations/0006-coach-token-scope.sql`
  (new), `worker/index.ts`, `src/components/Account.jsx`,
  `src/account/AccountProvider.jsx`, `src/account.css`, tests in
  `server/tests/coach.test.ts`, `server/tests/coach-summary.test.ts`,
  `worker/tests/coach.test.ts`, `tests/accounts-coach.spec.js`, and the API,
  security, database and user docs.
- **Verification:** on a local PostgreSQL 18.4 container (the CI image), the
  full server suite passes 63/63, including the new full-access test; the
  account browser suite passes 18/18 in Chromium and 18/18 in WebKit,
  including the new full-access journey; Worker tests 26/26 (new COACH-05);
  type check, lint, Prettier and docs check pass. Not deployed: the API needs
  migration 0006 before the frontend and Worker ship.

### Raouf: 2026-10-19 — Edit a running workout, fill remaining sets, left/right logging

- **Edit workout (mid-session):** the active workout page gains **Edit
  workout**, a dialog that adds an exercise from the searchable library, moves
  one earlier or later, or removes one. Each change saves immediately like
  adding a set does. Removing an exercise with completed sets asks a second
  time and says how many sets it drops; the last exercise cannot be removed.
  Added exercises get a fresh `entryId`, so the same movement can appear twice.
  An unfinished last set can now be removed with **Remove set**.
- **Fill remaining sets:** a weight, rep, time or distance typed into a set
  also fills the later unfinished sets of that exercise that still show the
  value just replaced; a set changed on purpose, or already completed, keeps
  its value. The profile preference `fillSets` (default on) controls it from
  the workout side panel and Settings.
- **Left and right reps:** all 1,681 catalogue rows were reviewed one by one
  for one-side-at-a-time movements. `src/catalog/unilateral.json` records 408
  of them with the limb they are logged per (177 arm, 158 leg, 73 side);
  alias rows inherit their canonical verdict. Those exercises default to
  **Reps per leg/arm/side**, and a per-side load/reps entry logs **Left** and
  **Right** fields; the set's `reps` holds the total (each side 1–50) and
  volume counts it, while personal-best estimates use the reps one side
  performed. History shows `10 kg × 12 L / 9 R` and the history editor
  corrects each side. Sets logged before this change stay valid as they are.
  The three starter routines now mark their lunge, one-arm row and dead bug
  per side.
- **Files:** `src/components/WorkoutEditor.jsx` and `src/workoutSession.js`
  (new), `src/catalog/unilateral.json` (new), `src/components/Workout.jsx`,
  `HistoryEditor.jsx`, `Insights.jsx`, `Preferences.jsx`,
  `RoutinePrescription.jsx`, `src/App.jsx`, `src/data.js`,
  `src/exerciseMetrics.js`, `src/routineProgramming.js`, `src/storage.js`,
  `src/styles.css`, `unit/workout-session.test.js` (new),
  `tests/workout-editing.spec.js` (new), `server/tests/programming.test.ts`,
  `docs/user-guide.md`, `docs/routine-programming-v2.md`.
- **Verification:** lint, Prettier, `tsc`, docs check and the production
  build pass. Unit 97/97 (8 new). `server/tests/programming.test.ts` 2/2 with
  the new `sides` and `fillSets` assertions; worker tests pass. Chromium:
  137/143 on the first full run, then the 6 failures triaged: two Settings
  profile snapshots and the duplicate-routine count now expect `fillSets` and
  the one-arm row's "per arm" text; the alias-editor save and the rest-timer
  deadline were read before the storage lock's checkpoints wrote them and now
  poll (they failed 1-in-3 and 2-in-3 here against 0 on the untouched tree,
  with the same 20–70 ms click-to-write window on both); the empty-overview
  case is the known intermittent one and fails on the untouched tree too.
  After the fixes the touched specs passed 24/24 over four Chromium
  repetitions and 16/16 in WebKit. The new browser spec `workout-editing`
  covers fill, left/right logging through history, the editor and starting a
  per-side routine. `server/tests/programming-migration.test.ts` needs
  PostgreSQL and was not run; Firefox was not run. Live checks in the dev
  preview: fill propagation, left/right completion and total volume, the
  editor's add/move/remove flow, and a 540 px layout for three-field rows.
- **Known, pre-existing:** at 540 px the bilateral set row's 34 px done column
  holds a 44 px button, so each row reports 10 px of horizontal overflow; the
  new three-field rows fit. Not changed here.

### Raouf: 2026-10-18 — Operations dashboard runbook link

- The private operations dashboard linked its recovery runbook through the
  deleted `release/complete-live-catalog` branch (404). It now links to
  `main`. Every other link to this repository or the FORMA sites was checked:
  all resolve (the API origin's 403 is expected).
- `npm run worker:deploy:dashboard` builds and deploys the dashboard Worker with
  the same one-hour scoped token flow as the site (`deploy-public.mjs
--dashboard`). Deployed as version `b2911e08-…`; Access still guards it.

### Raouf: 2026-10-18 — Sign-out release deployed

- Owner-authorised release of PR #11 (`746fdf8`) to private staging and
  production: working "Sign out everywhere", password step-up for signing out
  other devices, and the sidebar account menu.
- API image `forma-api:signout-20261018-ea2dc4b` on both environments; staging
  also received migration 0005 and the current runtime grants. Production
  Worker `4b87caa9-…`, staging Worker `712219ca-…`. Encrypted backups before
  and after each API switch; row counts and unrelated containers unchanged.
- Live checks passed; see [the release record](docs/qa/sign-out/README.md).

### Raouf: 2026-10-18 — Sidebar sign out and working session sign-out

- **Fix:** "Sign out everywhere" failed for anyone who had signed in more
  than 5 minutes earlier. The API returned `403 reauthentication_required`,
  and the screen showed that raw code. It now works at any time, because it
  also ends the session that asks, so a stolen session cannot use it to keep
  access.
- **Step-up:** "Sign out other devices" and revoking one device keep the
  5-minute rule. An older sign-in now confirms the password, plus the 2-step
  code when enabled, in a prompt in the sessions panel. The server checks them
  in the same request using the existing password-check throttle and TOTP
  replay table. No session or cookie changes. Their errors now appear in the
  sessions panel in plain words; previously some went to the password form.
- **Sidebar:** the signed-in profile row opens an account menu with
  **Manage account** and **Sign out**. It follows the WAI-ARIA menu button
  pattern (arrow keys, Home/End, Escape returns focus) and works in the phone
  drawer. Guests keep the direct link to Account.
- **Toasts:** messages raised while signing in or out, such as "You’ve signed
  out.", were lost when the workspace remounted for the new account. Toasts
  now live above that boundary.
- **Row overflow:** the editor-row drag surface (from the 2026-10-17 drag
  animation) extended 10px past each row, so every row reported 6px of
  horizontal overflow. The responsive guard caught this only when it measured
  after rows loaded. The side bleed is now a shadow spread, which adds no
  overflow; the lifted look is unchanged.
- **Files:** `server/app.ts`, `src/App.jsx`, `src/account/AccountProvider.jsx`,
  `src/components/Account.jsx`, `src/components/Navigation.jsx`,
  `src/styles.css`, `server/tests/session-step-up.test.ts`,
  `tests/accounts-sign-out.spec.js`, `docs/security/*`.

### Raouf: 2026-10-18 — Coach tokens deployed to production

- Owner-authorised production release of the read-only coach token API on top
  of routine programming v2. API image `forma-api:coach-20261018-a831507`
  (source tree identical to `25154af`, Node 26.11.1, amd64), built on the
  owner's Mac, transferred as a checksum-verified archive and loaded on the
  host. Migration `0005-coach-tokens.sql` applied through the one-shot migrate
  service; `ops/grant-runtime-access.sql` updated on the host and re-run, so
  `forma_runtime` has DML on `member_coach_token`. API recreated and healthy;
  database, connector and every unrelated container kept their IDs.
- Production Worker version `4005f27c-03ea-427c-b087-7173d62c804b` deployed
  with the one-hour scoped-token helper (`npm run worker:deploy:production`).
  Live checks: home 200 with `no-transform`, CSP and HSTS; health 200;
  anonymous workspace 401; `/api/coach/workspace` 401 JSON without and with an
  invalid bearer; session null; unknown route 404 JSON. Live HTML and JS hashes
  match the local account build.
- Encrypted, signed off-host backups before (`…20261018T021730Z`) and after
  (`…20261018T022111Z`) migration; row counts unchanged (1 user, 1 workspace,
  21 operations, 2 sessions, 0 coach tokens). Rollback targets: Worker
  `64806558-cb0d-40dc-a029-3767586b456b`, API image
  `forma-api:routine-v2-20261017-cca9b07`. Private staging was not updated.
  See [the deployment record](docs/qa/coach-tokens/README.md).

### Raouf: 2026-10-18 — Read-only coach access tokens

- Members can mint up to five read-only coach tokens in Account › Security.
  `GET /api/coach/workspace` accepts `Authorization: Bearer forma_coach_…` and
  returns routines, recent sessions, personal bests and weekly totals for the
  token's owner only, without email, member reference, revision or operation
  data. Tokens expire after 90 days and can be revoked; minting requires a
  session less than five minutes old.
- Migration `0005-coach-tokens` stores HMAC-SHA-256 digests only; the runtime
  role gains DML on `member_coach_token`. Bearer failures are budgeted per
  client (20 per 15 minutes) and reads per token (120 per hour), with
  `coach_token_failure` and `coach_token_lockout` security events.
- The Worker forwards `Authorization` only to `/api/coach/workspace` and
  withholds cookies and the member reference there. New Worker and real
  PostgreSQL regressions cover isolation, revocation, expiry, cascade and
  budgets; documentation, threat model (T-24) and coverage matrix updated.

### Raouf: 2026-10-18 — Drag animation deployed

- Owner-authorised frontend-only redeploy of `57bd68d` (routine row and card
  drag animation). API, database and Worker secrets unchanged.
- Production Worker version `64806558-cb0d-40dc-a029-3767586b456b`; staging
  `c299adb6-8e4d-4dcb-9e39-9e6a13eb5716`. Live `index-Cdbv3-NY.js` matches the
  local account-mode build and contains the new drag code.
- Live checks: home 200 with `no-transform` and no beacon, health 200,
  anonymous workspace 401, session null, staging Access 302. A headless drag
  on the live guest workspace lifted and reordered a card; no member data used.
- Deployed with the owner's local Wrangler login rather than the one-hour
  token script (no management token on this host). See AGENT.md.

### Raouf: 2026-10-17 — Professional drag animation for routine rows and cards

- **Scope:** routine editor exercise rows (existing drag) and the My routines
  card grid (new drag to reorder), on `feat/routine-programming-v2`.
- **Motion:** a dragged item lifts on a raised surface with a two-layer shadow
  and lime outline, springs in with the Material 3 Expressive fast-spatial
  curve, stays raised until it lands, then shows a 700 ms lime confirmation
  (Atlassian drop pattern). No tilt. Neighbours slide with the existing layout
  spring. Reduced motion keeps the shadow/outline but drops scale and flash.
- **Cards:** mouse/pen drags after 6 px; touch needs a 400 ms hold so swipes
  still scroll; the page auto-scrolls near the edges and Escape cancels.
  **Move earlier / Move later** in each card's ⋯ menu give a single-pointer,
  keyboard-friendly alternative (WCAG 2.2 SC 2.5.7) with spoken position.
  Order saves through the normal workspace change; archived routines keep
  their slots, and clicking a card without dragging still opens it.
- **Files:** `src/components/RoutineCardOrder.jsx` (new), `Routines.jsx`,
  `RoutinePrescription(s).jsx`, `src/App.jsx`, `src/styles.css`,
  `tests/routine-card-drag.*`, `tests/routine-drag*.spec.js`,
  `docs/user-guide.md`.
- **Verification:** 3 new row and 5 new card tests failed first, then passed
  in Chromium and WebKit; 2 new touch tests pass on mobile Chromium. Lint,
  format, types, docs, build and 89 unit tests pass. The full Chromium+WebKit
  run matches an untouched checkout of the branch except for fixes made here.
  Remaining failures also occur on that checkout: 7 WebKit focus cases, one
  routine-library case and an intermittent empty-overview case. Firefox
  Nightly does not start on this Mac and was not run.

### Raouf: 2026-10-14 — Artwork deployment and edge privacy

- Owner authorised deploying the completed 1,414-exercise artwork and site fixes.
  Public and private staging frontends retain account mode and the existing API.
- Live browser verification caught an automatically injected Cloudflare beacon
  blocked by CSP. HTML now sets `Cache-Control: no-transform`, preventing edge
  injection while retaining cache directives and the existing security policy.
  A regression checks HTML defaults, existing directives and unchanged JS caching.
- All 21 Worker tests and live desktop/mobile checks pass. Both targets are
  redeployed, temporary tokens revoked, and deployment receipts/screenshots pushed.
  Anonymous gateway boundaries and private staging Access remain verified.

### Raouf: 2026-10-14 — Complete artwork and whole-site review

- Completed and pushed reviewed original illustrations for all 1,414 selectable
  exercises, preserving historical identities and measurement units. Replaced
  unusable movement sources with clearly attributed, independently authored
  guides as requested; archived source text and review decisions.
- Whole-site review covers desktop/mobile routes and workflows using current
  React, Vite, MDN and WCAG documentation. Fixes add compact artwork previews,
  keyboard focus and reduced-motion support for legal navigation, and visible
  account backup-import focus. Exercise counts now use the singular when needed.
- Registration, recovery and MFA mode changes now focus their visible form
  heading. Four regressions failed before the correction; desktop/mobile
  real-app checks pass. Authentication methods and data ownership are unchanged.
- Original generated hero and routine photography replace images whose
  redistribution terms were undocumented. Sources and prompts are preserved.
  Phone legal headings also remain visible below the sticky navigation header.
- Verified 62 unit cases, all 112 unique guest cases across the full run and
  failed-case replay, 18 isolated account journeys plus four form-focus checks,
  and 40 production cases across Chromium, Firefox and WebKit. Strict artwork
  coverage, lint, formatting, types, docs and build pass. See
  [the completed site review](docs/qa/site-sweep/README.md). Subsequent owner-authorised
  deployment is recorded above.

### Raouf: 2026-10-14 — Roman-chair guide correction

- Replaced a selectable save-error placeholder with a clear secured-foot
  dumbbell hip-hinge guide. Preserved its saved identity, measurement units
  and searchable earlier name; all 1,414 movements remain selectable.
- Added a regression for imported save-error text. Both targeted checks
  failed before the correction, and all 61 unit tests passed afterward.
  Artwork review and the whole-site sweep remain in progress.

### Raouf: 2026-10-14 — Original exercise illustrations in progress

- Building original AI-assisted FORMA artwork for all 1,414 selectable movements,
  with individual pose/equipment reviews and a strict complete-coverage gate.
  Progress and held corrections are recorded in
  [the original-art registry](docs/research/original-art/README.md).
- Added local library thumbnails and guide imagery with lazy loading, preserved
  proportions, readable attribution and an image-error fallback. Six focused
  Chromium cases passed. Full generation/review and release remain pending;
  existing live accounts and backend data are unchanged.
- Corrected clipping on uneven atlas rows using reviewed pixel bounds. Fifteen
  focused browser cases passed across Chromium, Firefox and WebKit. Archived
  generated source sheets in the repository for recovery after session loss;
  unreviewed sheets remain outside runtime mappings.

### Raouf: 2026-10-14 — More exercise photo sources

- Found 25 freely offered exercise demonstrations with photo thumbnail URLs and
  inspected 12 Commons files. Twenty thumbnails were visually reviewed, yielding
  preferred candidates for 10 distinct exercise IDs without publication approval.
- Recorded per-file credits, licence conflicts and equipment/variation mismatches;
  documented further commercial sources. No media was deployed or subscription
  purchased. See [expanded photo research](docs/research/exercise-photos-more.md).

### Raouf: 2026-10-14 — Exercise photo research and live catalog record

- Recorded live API/frontend versions and public/private catalog checks. Removed
  an internal ID from the fan-bike guide note without changing logging units.
- Audited photo candidates for every selectable exercise; linked images cover
  205 movements, with 106 attributed non-AI-flagged declared-photo candidates.
  Visual checks caught mislabelled drawings and mismatched variations. No exercise
  photos were deployed or automatically approved.
- Documented asset-specific rights, Free Exercise DB's unresolved photo provenance
  and current AscendAPI subscription/caching/weekly URL-rotation requirements.
  See [photo research](docs/research/exercise-photos.md).

### Raouf: 2026-10-14 — Exercise duplicates and machine coverage

- Consolidated 240 duplicate entries in 180 reviewed groups, with aliases in
  browsing and routine selection. The library offers 1,414 usable movements;
  all 1,661 existing IDs and historical measurements remain compatible.
- Added 15 distinct machine movements, six original guide repairs and five new
  timed identities. Fixed machine/cable metadata, ambiguous Air Bike naming and
  boilerplate guide admission. Archived entries stay outside browsing.
- Reviewed all 76 earlier equipment families plus five additional machine
  families. Preserved meaningful variants and documented unsupported specialty
  measurements. See [catalog evidence](docs/research/catalog-quality.md).
- Preserved all alias prescriptions when toggling an existing routine group;
  corrected overbroad machine inference for barbell, band and floor movements.
- Validation: 60 unit, 46 API, 20 gateway tests and 57 affected browser cases
  across three engines passed; compiled non-root Node 26 image passed new-ID
  validation. Existing member data remains on its private host.

### Raouf: 2026-10-13 — Consolidate release branches

- Integrated the production release and all five Dependabot branches into main.
  Updated pinned checkout/setup-node/upload-artifact actions and the pinned
  Node 26 API container base.
- Retained ESLint and `@eslint/js` 9.39.5: the proposed ESLint 10 update fails
  clean installation because the latest React/accessibility plugins exclude it
  from their peer ranges. Do not bypass dependency checks to install that update.
  The Dependabot commit remains in history with this compatibility correction.
- Classified the scanner's exact historical dashboard audience finding as a
  public JWT application identifier. Added its single fingerprint exception;
  credentials and all other history continue to be scanned.
- Replaced offline exercise-measurement regex classification with string
  matching; regression checks preserve all 1,645 published imported labels and
  timed/carry/plank precedence. The generated catalog and live data are unchanged.
- Validation: 51 unit and 46 API tests under Node 26, 20 gateway tests and 14
  operations checks passed. Browser matrix: 256 passed; the two cases interrupted
  by sandbox network changes passed three repetitions each after container setup.
  The Node 26 image built and passed a read-only, non-root health check.
- Pinned CI scanners passed: gitleaks history scan, OSV lockfile scan and
  Semgrep (226 rules, 81 files, zero findings). Formatting, type checks and
  documentation checks passed before publishing the combined main branch.

### Raouf: 2026-10-13 — Brand, loading motion and journals

- After final hosted checks, cleared all production accounts and linked data at
  the owner's explicit request; verified all nine tables empty and rotated the
  signing secret. Staging and unrelated services stayed unchanged. Registration
  is ready; no replacement test account was created. Existing encrypted backups
  retain their 34-day expiry.

- Added an original FORMA mark and coordinated accessible loading animation to
  real pending states, with stable action labels and reduced-motion support.
- Refined workout history with actual totals, grouped entries and unit preserving
  details. Added an owner-only dashboard for sanitized health/backup observations.
- Fixed standard JWT audience-string handling and unsupported Workers redirect
  mode; signatures and exact scope remain required. Removed diagnostics and QA
  access after live verification.
- Validation: 258 development and 40 production guest browser cases; 40 account
  cases plus all five affected migration rechecks; 18 history cases across three
  engines. Live public/staging/dashboard checks passed, with zero dashboard axe
  violations or mobile overflow. Operations checks passed 6 Python and 8 Node
  tests. See [the launch record](docs/accounts/production-launch.md).

### Raouf: 2026-10-13 — Public account launch controls

- Provisioned a separate production account backend with bounded containers,
  private database roles, independent credentials and an Access-protected Tunnel.
  No backend ports were published; unrelated containers retained their IDs.
- Added separate private R2 buckets, bucket-scoped credentials, daily signed and
  encrypted backups, verified off-host restores and 34-day lifecycle deletion.
  Recovery keys stay off-host in envelopes encrypted to the operator's SSH key.
- Added host monitoring, bounded security-event logs and an independent edge
  health/backup monitor. The approved owner inbox received provider-accepted
  delivery tests; synthetic staging records verified the threshold pipeline.
  Rotated staging Access credentials and revoked the old token.
- Updated Privacy Policy 1.2 to disclose encrypted Cloudflare backups. Production
  deployment now builds account assets and uses its real protected origin.
  See [launch evidence and remaining limits](docs/accounts/production-launch.md).
- Validation: 46 server, 49 unit, 20 Worker, 4 Python operations, 2 edge-monitor
  tests and 9 legal browser checks passed. Final operations checks increased to
  6 Python and 5 edge cases after independent review; both environments restored
  successfully without a live database, using signed backup-time snapshots.
- Public accounts are deployed and the real owner-confirmed canary passed
  verified sign-in, private timed workout saves, reload/two-session persistence,
  export and owner-binding denial. Corrected non-root Tunnel token ownership
  discovered during activation. The test's synthetic workout was removed.

### Raouf: 2026-10-13 — Expanded catalog and public planner

- Added 1,645 sourced exercises to the 16 existing movements, with individual
  licence attribution, full text guides, alias search and paginated browsing.
  Current wger API coverage and excluded incomplete descriptions are recorded
  in [catalog research](docs/research/runtime-catalog.md).
- Added 12 editable workout templates and validated time/distance/carry logging,
  history corrections and backups without counting these units as lifting volume.
  Preserved legacy exercise IDs, plank units and aggregate workspace bounds.
- Replaced the fake guest name and unavailable public account forms with working
  local workspace controls; removed the fake production backend hostname.
- Fixed rest timer deadlines beginning late in an asynchronous save queue.
  Fixed URL hash changes missed between initial render and listener setup,
  verified with a deterministic browser regression in three engines.
  Updated Privacy Policy to version 1.1 for time and distance fields.
- Included the shared catalog and measurement helper in the API image build.
  Added a short-lived Cloudflare deployment-token helper and reusable environment
  startup/networking instructions. Private staging remains unchanged while
  sandbox SSH is unavailable; public accounts retain their release gates.
  Published network version 5 and the official 2026 Cloudflare Access SSH method
  now permit secured maintenance. An encrypted on-host staging backup and isolated
  restore were verified before updating the API; no member data was exported.
- Validation and live deployment evidence: [release record](docs/live-catalog-release.md).
- Released source `d821632` to the public guest Worker and matching private
  staging API/frontend. Live checks verified the 1,661-entry catalog, guides,
  time/distance history, backup download, mobile layout and account gateway.
  Every unrelated running container retained its ID. Final production browser
  matrices passed 40 guest and 45 member cases; all deployment and maintenance
  credentials were short-lived and revoked after use.
- Deployment npm commands now force the correct guest/account build and use
  the scoped one-hour token helper; unsupported flags fail before any API call.

### Raouf: 2026-10-13 — Privacy Policy and Terms of Use

- **Scope:** professional legal pages for FORMA, drafted from official sources (OAIC APP guidelines, Privacy Act, Australian Consumer Law, GDPR/EDPB, Cloudflare and DigitalOcean DPAs). Not legal advice; recommend lawyer review before accounts open to the public.
- **Summary:** in-app `#privacy` and `#terms` pages rendered from a single source (`src/legal/content.js`), linked from every page and the sign-up form. Sign-up now requires agreement to the Terms (16+, or 13–15 with permission) and separate express consent for workout data that may be health information, with an APP 5 collection notice. Liability wording keeps all Australian Consumer Law rights (no void s 64A cap). Fixed a date-dependent calendar test that failed every Tuesday.
- **Files:** `src/legal/content.js`, `src/components/Legal.jsx`, `src/App.jsx`, `src/hooks/useNavigation.js`, `src/components/Navigation.jsx`, `src/components/Account.jsx`, `src/styles.css`, `src/account.css`, `tests/legal.spec.js`, `tests/accounts-*.spec.js`, `tests/ui-controls.spec.js`, `docs/legal/README.md`.
- **Verification:** legal page tests 9/9 (Chromium, Firefox, WebKit, axe WCAG 2.2 AA), account browser suite 45/45, unit 43/43, lint and format clean; CI green on `9031373` (sidebar legal links laid out in a row). Deployed to both Workers on 2026-10-13 and checked live in a headless browser (both pages render, 360 px without overflow).
- **Follow-ups:** lawyer review; keep the operational commitments listed in `docs/legal/README.md` (30-day responses, 35-day backup deletion, 14 days' notice of changes).

### Raouf: 2026-10-13 — Safe deployment: public guest site and private account staging

- **Scope:** first deployment of FORMA on Cloudflare and the shared DigitalOcean Droplet.
- **Summary:** public guest-mode Worker at `forma.raoufabedini.dev` with no API credentials (all `/api` fail closed); private account staging at `forma-staging.raoufabedini.dev` behind Cloudflare Access (owner email via one-time PIN), with the API on the Droplet reachable only through an Access-protected Tunnel and strict service tokens. The Worker now forwards only FORMA cookies upstream (EDGE-09). Added `ops/compose.small-host.yaml` for the shared 2 GB host. Short-lived scoped API tokens were used for deployment and revoked afterwards.
- **Files:** `worker/index.ts`, `worker/tests/redteam.test.ts`, `worker/tests/gateway.test.ts`, `wrangler.jsonc`, `ops/compose.small-host.yaml`, `docs/security/deployment-record.md`, `docs/security/release-security-verdict.md`, `docs/security/README.md`, `AGENT.md`.
- **Verification:** live Access/Tunnel probes (S09), no host listeners (S10), full member lifecycle with real email delivery through the deployed chain (S18), isolated restore drill (S14 partial); Worker tests 20/20. Verdict remains NO-GO for real members (S16 alerting, off-host backups).
- **Follow-ups:** off-host backups, alerting, DigitalOcean firewall review, Droplet maintenance window, remove stale password from the Portfolio `.env`.

### Raouf: 2026-10-12 — Red-team security hardening

- **Scope:** authorised red-team assessment of the account stack (API, Worker gateway, frontend sync, PostgreSQL roles, ops, CI) with independent reviewers and two independent retests of the fixes. Local environment only. Commits `6f26a09` and `2f8407c`.
- **Summary:** fixed 27 findings (1 High, 11 Medium, 14 Low, 1 Info). Highlights: deny-by-default API gateway check; Better Auth endpoint allowlist and JSON-only bodies; same-origin auth redirects; atomic per-account and per-member password-attempt limits; per-recipient mail and per-member write budgets; 30-day absolute sessions; no sessions minted from email links; workspace size bounds checked before parsing; Worker header, cookie and body allowlists with API security headers; data-loss fixes in sync and restore; tighter database role; pinned images; fail-closed CI security scans. Verdict: **NO-GO for real members** until live Cloudflare/Droplet checks, restore drill and alerting are done.
- **Files:** `server/app.ts`, `server/auth.ts`, `server/throttle.ts`, `server/workspace.ts`, `server/workspaceRoutes.ts`, `server/migrations/0003-security-throttle.sql`, `worker/index.ts`, `src/storage.js`, `src/App.jsx`, `src/account/AccountProvider.jsx`, `src/account/cloudRepository.js`, `src/components/Account.jsx`, `ops/*`, `wrangler.jsonc`, `.github/workflows/ci.yml`, `.github/dependabot.yml`, new tests (`server/tests/redteam.test.ts`, `worker/tests/redteam.test.ts`, `unit/redteam-release.test.js`), `docs/security/*`, `AGENT.md`.
- **Verification:** server 44/44 (real PostgreSQL), Worker 19/19, unit 43/43, guest production browsers 20/20, account production browsers 45/45; npm audit, OSV, gitleaks and Semgrep clean; each behavioural regression fails on the baseline. Details and exceptions in [the release verdict](docs/security/release-security-verdict.md).
- **Follow-ups:** sign backups and run a restore drill; security alerting; breached-password blocklist; MFA and recovery-code policy; live Access/Tunnel/Droplet verification; branch protection for `main`; independent human penetration test.

- Added an initial self-hosted account implementation with Better Auth, PostgreSQL member workspaces, optimistic revision sync, account management UI, and a Cloudflare Worker API gateway. This work remains a release candidate: real Cloudflare/DigitalOcean staging, provider email, and off-host backup/restore are not verified. See [account release readiness](docs/accounts/release-readiness.md) before treating it as deployable.
- Added private-host Compose configuration, database role and migration tooling, encrypted backup/isolated-restore scripts, and account operations/API/source documentation. These scripts are implemented but production infrastructure and recovery drills remain owner tasks.

- Add development/production browser matrices, focused interaction/domain/security regressions, release traceability, and a pinned least-privilege CI workflow.
- Validate local documentation links and npm commands, including inline-code heading anchors.

- Added sourced gym-equipment and workout research: 76 equipment families, 236 exercise candidates, workout formats, content-rights review, and a migration-first implementation roadmap. These are planning documents; the runtime library remains 16 exercises.

- Added setup, user, architecture, data-model, deployment, testing, and contribution documentation.
- Extracted a directly testable persistence repository and added data-layer unit tests.
- Added task boundaries within storage locks to address an intermittent Firefox cross-tab lost-update failure.
- Fixed rejected Web Locks, temporary-state revisions, stale recovery, preservation of unsaved originals, and recovery-key collisions.
- Validated backup size, timestamp bounds, completed-history invariants, and active/history ID conflicts.
- Added an ID fallback for temporary use on HTTP origins, stale-routine start protection, fractional-weight editing, and bounded paused rest timers.
- Ignore stale asynchronous backup reads when a newer file has been selected, preserving the latest preview and suppressing errors from an older invalid file.

## 2026-10-12 — Frontend audit and polish

- Added original athletic editorial typography with locally served fonts.
- Consolidated responsive styles and improved phone inputs and landscape navigation.
- Fixed imported-history ordering, storage-failure feedback, and recovery errors.
- Added Chromium and Firefox regression coverage, responsive checks, and accessibility scans.

## 2026-10-12 — Initial public implementation

- Added routine planning, exercise library, workout logging, rest timers, history, progress, and preferences.
- Added browser-local persistence, cross-tab coordination, validated backup restore, and corrupt-data recovery.
- Published the personal-use application and reference research.

## 2026-10-14 — Workout artwork cloud recovery

- Fetched and restored the pushed 1,341-match checkpoint after the cloud restored an older 958-match checkout.
- Preserved new original sheets, full prompts and cell reviews; only newly covered IDs replace pending mappings.
- Clarified standing hip raise, band-guide hip abduction, supine rotation, neutral-grip pulldown and bodyweight lateral-step identities without changing saved IDs or units.
- Keep pushing complete assets and recovery logs after each reviewed batch; consult `docs/research/original-art/recovery-state.json` before resuming.

### Raouf: 2026-10-17 — Routine programming v2

- **Scope:** all requested routine programming features in one PR, including
  supersets, duplication, drag handles and accessible arrow reordering.
- **Summary:** schema v2 adds rep ranges, target/actual RPE, exercise rest,
  per-side targets and plain-text cues. Timestamp timers support automatic rest,
  skip, pause/resume, ±15 seconds, vibration and mute-aware sound. Picker and
  saved metadata agree; 24 equipment corrections and incline press/fly aliases
  preserve separate prescription/history rows and original measurement units.
- **Files:** `src/storage.js`, `src/routineProgramming.js`, routine/workout/history
  and preferences components, catalog metadata/audit, shared API validation,
  `ops/Dockerfile`, tests and data/API/migration documentation. Privacy Policy
  1.3 discloses the optional programming and exertion fields.
- **Migration:** `server/migrations/0004-routine-programming.sql`; back up and
  pause old API writers, then run `npm run server:migrate` with migration-role
  `DATABASE_URL` and deploy the matching API before the v2 frontend. Browser
  `forma-v1` data and v1 imports migrate idempotently; invalid old unfinished
  numeric drafts retain their original values for correction and export.
- **Verification:** 88 unit, 49 API, 21 Worker, 14 operations, 348 development,
  55 account and 45 production browser cases pass; lint, formatting, types, docs,
  server/frontend builds, equipment audit and strict 1,411-exercise artwork
  coverage pass. Browser results include exact replays after a test-server exit
  and an isolated 4.4-second performance check with its 10-second limit unchanged.
- **Follow-ups:** coordinated deployment, backup and any privacy notice required
  before rollout. No requested feature is deferred; no deployment or merge here.

### Raouf: 2026-10-17 — Deployment packaging verification

- **Scope:** owner requested full E2E verification, commit, push and redeploy in
  the existing routine programming PR.
- **Summary:** CI exposed the Dockerfile-specific build-context allowlist
  excluding the new shared routine helper and alias JSON. Added both explicit
  inclusions; no application behavior or security boundary changes.
- **Files:** `ops/Dockerfile.dockerignore`, `AGENT.md`, `CHANGELOG.md`.
- **Verification:** the previous CI image build failed at COPY with the helper
  missing. Rebuilding the actual pinned Node 26 image and rerunning CI before
  deployment; existing complete local browser matrices remain recorded above.
- **Follow-ups:** staging/production backups, v2 migration, API/frontend rollout
  and hosted verification under the owner's current deployment authorization.

### Raouf: 2026-10-17 — Hosted and responsive routine verification

- **Scope:** full E2E verification for the owner-authorised routine deployment.
- **Summary:** hosted latency exposed a transitional duplicate-heading selector;
  target the active workout h1. Phone journeys open their rest panel and accept
  the card's responsive separator. Add routine programming to the production
  browser matrix; retain exact saved-data, timer and independence assertions.
- **Files:** `tests/routine-programming.spec.js`,
  `playwright.production.config.js`, `AGENT.md`, `CHANGELOG.md`.
- **Verification:** 12 focused desktop cases pass across three engines; the
  expanded production suite passes 65 cases across five desktop/phone projects.
  Hosted staging passes all 12 Chromium/WebKit desktop/phone programming cases.
  Staging backups/migration and stored-v2 validation pass; other container IDs
  are unchanged. Firefox hosted TLS was blocked by proxy certificate trust;
  local Firefox production coverage passes with certificate checks unchanged.
- **Follow-ups:** complete CI and the production rollout, then record final
  versions and hosted evidence. Runtime application source remains `c491889`.

### Raouf: 2026-10-17 — Preserve live routine archive compatibility

- **Scope:** production validation during the owner-authorised v2 rollout found
  existing routine `archivedAt` timestamps absent from this checkout's schema.
- **Summary:** retain the bounded optional timestamp in strict validation and
  backups; keep archived routines out of overview/start defaults, with Active /
  Archived views and stale-checked restore/archive actions. Editing preserves the
  timestamp; duplication creates an active copy. Stack the card actions visibly.
- **Files:** shared storage/programming helpers, `App.jsx`, `Routines.jsx`,
  `styles.css`, unit/API/SQL parity and archive browser regressions, production
  browser configuration, data/migration/release documentation and both logs.
- **Verification:** regression failed before the schema correction; 89 unit,
  49 real-PostgreSQL API and 15 focused development browser cases pass. The new
  image validates every stored production workspace on the private host with
  archive metadata intact. All 70 unique production cases are verified, including
  25 programming/archive replays after fixing two menu-interception failures.
  The API matrix also passes under Node 26. Applied migration 0004 is unchanged.
- **Follow-ups:** deploy the matching compatibility image/frontends, verify
  hosted archive/programming journeys and retain the final deployment receipts.
  Production writers remain paused until the coordinated release is ready.

### Raouf: 2026-10-17 — Guard private workspace initialization

- **Scope:** final production-built account verification after archive support.
- **Summary:** account/legal routes intentionally render before the private
  workspace arrives. Derive active routines from an empty list while data is
  null, preserving those routes and the existing private loading boundary.
- **Files:** `src/App.jsx`, `AGENT.md`, `CHANGELOG.md`.
- **Verification:** the existing real-account control and conflict journeys
  exposed the null read before this fix; both now pass against production-built
  assets. Lint, formatting and type checks pass. Backend schema/image is unchanged.
- **Follow-ups:** deploy the frontend correction and complete the full account
  matrix plus final hosted verification; retain failed traces in private scratch.

### Raouf: 2026-10-17 — Verified routine v2 redeployment

- **Scope:** completed owner-authorised commit/push/redeployment in PR #9.
- **Summary:** production and staging serve frontend `27e3728` with matching API
  `cca9b07`. Verified encrypted signed backups bracket SQL 0004; stored workspaces
  and legacy archive timestamps validate, with record counts preserved. No member
  data was exported/deleted and no applied migration or unrelated service changed.
- **Files:** `scripts/deploy-public.mjs`, deployment/gateway/asset/layout receipts
  under `docs/qa/routine-programming-v2`, this log and `CHANGELOG.md`. Control-plane
  requests use `no-store` after a stale/transient permission lookup failed; the
  fresh lookup and final staging deployment succeeded without widening access.
- **Verification:** 89 unit, 49 Node 26 API, 21 Worker, 14 operations, 70 unique
  production browser cases and a fresh 55-case production account matrix pass.
  Hosted production and staging each pass 15 programming/archive journeys. Live
  assets match the build; desktop/phone layouts have no overflow/browser errors.
  Health/anonymous boundaries, private ports and existing memory limits pass.
- **Release:** production `e6ea40f3-dbc8-46ee-a7d6-5fc9eb5205ce`; staging
  `29a7cfc6-0caf-428f-9ba8-58803b287573`. Temporary maintenance access and scoped
  deploy credentials were removed/revoked. Both APIs are healthy.
- **Follow-ups:** preflight candidate validators against live workspace shapes
  on the host before future schema migrations; keep nullable account-loading
  routes covered. Full CI reruns on pushed commits; no requested feature remains
  deferred, and the PR is not merged by this deployment.

### Raouf: 2026-10-17 — Review deployment-label scan findings

- **Scope:** complete the final-head security checks for PR #9.
- **Finding:** the pinned history scanner classified the public deployment image
  label as a generic key in two release receipts. Neither value authenticates
  a request or grants access. The findings were reproduced locally.
- **Files:** `.gitleaksignore` records only the two exact commit/path/rule/line
  fingerprints; this log and `CHANGELOG.md` document the review. No general rule
  or path exception was added, and no credential material was exempted.
- **Verification:** rerun the unchanged pinned full-history scan, docs and patch
  checks before push; final GitHub security/application matrices remain required.
  Deployed frontend/API bundles and saved member data are unchanged.

### Raouf: 2026-10-17 — Await archive edit save acknowledgement

- **Scope:** resolve the final CI production browser failure in PR #9.
- **Evidence:** both runs passed 351 development cases and both 55-case account
  matrices; production passed 69/70. The Chromium trace shows reload while
  `data-saving` is true and the editor displays its busy Save control, before
  the pending browser write completes. A fresh local 70-case matrix passed.
- **Change:** `tests/routine-archive.spec.js` now waits for the editor to close
  after the successful save before reloading. All range/archive persistence and
  duplicate assertions remain, with no sleep, retry or larger timeout added.
- **Verification:** the full 70-case production matrix and nine archive replays
  across three engines pass; final CI remains required. Runtime sources and deployed
  versions remain unchanged; no further member-data operation is needed.

### Raouf: 2026-10-17 — Animate complete routine rows and restore draft selection

- **Scope:** owner-approved follow-up in PR #9; keep the existing branch and PR.
- **Change:** pin Motion 14.3.0 and lazy-load handle-driven whole-row ordering,
  neighbor animation, bounded edge scrolling, cancel and reduced-motion support.
  Preserve editable values with stable keys and latest-state drop commits; block
  structural actions during dragging and Save until lazy fields are ready.
  Restore the routine's full exercise-library chooser with draft/focus retention
  and the lime session-loading backdrop without adding a loading delay.
- **Files:** routine/editor/library components and styles, package manifests,
  browser configurations and regression helpers/specs, the isolated account
  browser runner, `docs/qa/routine-row-drag`, this log and `CHANGELOG.md`.
- **Evidence:** current official Motion/design/accessibility documentation and
  reviewed desktop/touch recordings are linked in QA. Live assets matched the
  recorded release; reachable history did not identify a specific UI revert.
  Regressions reproduced lazy-save, delayed-note and dialog-Escape races before
  fixes. Account profiles now own fresh test servers instead of sharing a
  synthetic rate bucket; production authentication limits remain unchanged.
- **Verification:** 133 production browser cases; 18 lazy/stale-draft, 15 saved-note
  and 10 dialog-Escape checks; 89 unit, 49 API, 21 Worker and 14 operations cases
  passed, as did all 65 isolated account cases. Final CI runs 650 browser cases
  with zero retries. Final production-account, security/CI and hosted deployment
  receipts are retained in PR #9.
- **Follow-ups:** publish this frontend to staging and production only after
  final-head checks pass; verify hosted behavior/assets and remove temporary
  staging access. No API/schema/member-data change or PR merge is required.

### Raouf: 2026-10-17 — Use literal account project filtering

- **Scope:** resolve the final-head static-analysis finding in PR #9.
- **Finding:** Semgrep flagged the account runner's generated wildcard regular
  expression for possible excessive backtracking. Replace it with literal
  segment matching; only `*` is special and no dynamic regex is constructed.
- **Files:** `scripts/test-account-browsers.mjs`, this log and `CHANGELOG.md`.
- **Verification:** eight CLI discovery/selection checks pass, including exact,
  prefix/suffix/multiple wildcards, literal punctuation and mixed invalid filters.
  Lint, formatting and the unchanged pinned Semgrep scan pass with zero findings.
  Final CI reruns all checks; application sources, authentication limits and
  browser assertions are unchanged.

### Raouf: 2026-10-17 — Bind drag effects to their gesture

- **Scope:** fix the fast-release crash caught by complete development testing.
- **Evidence:** the existing duplicate/drag journey hit a null scroller reference;
  a new rapid-release regression reproduced it in both initial attempts.
- **Change:** retain the gesture object in active state and check its identity
  before installing effects, scrolling or cleanup. An ended gesture cannot read
  a cleared reference or cancel a newer gesture. Reject older queued gesture
  events by timestamp, including a release after a fast restart. Preserve exact
  saved values.
- **Files:** `src/components/RoutinePrescriptions.jsx`,
  `tests/routine-drag.spec.js`, QA notes, this log and `CHANGELOG.md`.
- **Verification:** rerun rapid-release and original duplication regressions
  across engines: all 18 repeated checks pass. Independent review has no further
  actionable finding; lint, formatting, types and docs pass. Complete the full
  matrices on the final head (658 browser cases, zero retries).
- **Follow-ups:** deploy both frontends only after final checks pass; record
  hosted verification in PR #9. API, schema and member data remain unchanged.

### Raouf: 2026-10-17 — Continue collision checks after fast pointer movement

- **Scope:** close the last issue found by the complete 390-case local run.
- **Evidence:** 389 cases passed; WebKit reached the physical two-slot target
  after a roughly 45ms move but its preview remained one slot behind for seconds.
  Motion advances one neighbor per rendered update and stops at zero velocity.
- **Change:** continue the existing RAF collision check in the last pointer
  direction while held. Update direction on reversal; actual scrolling takes
  precedence. Retain neighbor layout centers, DOM identity guards and bounded
  scrolling. Preserve the failing test and add an exact multi-slot save case.
  Guard absent boundary neighbors; every drag scenario now fails on page errors,
  exposing an exception that saved-data assertions alone had not caught.
- **Files:** both prescription components, drag regression spec, QA notes,
  this log and `CHANGELOG.md`.
- **Verification:** run repeated rapid-release, multi-slot, Escape and original
  duplication regressions across engines. Production covered 141 cases in the
  full run; two offscreen phone test drops were corrected to use a tall phone-width
  viewport, then the exact multi-slot case passed 15 repeats across five profiles.
  Final CI runs all 666 browser cases with zero retries and exact data checks.
- **Follow-ups:** deploy both frontends after final-head verification, then
  check hosted behavior and assets. No API/schema/member-data change is needed.

### Raouf: 2026-10-17 — Resolve the drop slot synchronously on release

- **Scope:** handle release before the next preview collision frame in PR #9.
- **Evidence:** the superseded CI duplicate/drag journey retained its original
  slot; six local repeats reproduced one failure before this fix.
- **Change:** save the pointer anchor and resolve valid releases against virtual
  row positions built from entry-keyed heights. Derive direction from the final
  coordinate and walk adjacent centers. Capture the anchor at pointer-down to
  account for visible spring positions. Cancelled gestures bypass resolution;
  latest-state commits continue preserving editable values and supersets.
- **Files:** `src/components/RoutinePrescriptions.jsx`, drag regression spec,
  `src/components/RoutinePrescription.jsx`, QA notes, this log and `CHANGELOG.md`.
- **Verification:** strengthen the rapid three-gesture test to an explicit known
  saved order using stable exercise identities across pending drops. Independent
  review found no actionable resolver issue. All 36 repeated regressions and
  the complete 143-case production matrix pass, with no page errors. Lint,
  formatting, types and docs pass. Final CI runs 666 browser cases without retries
  before deployment, retaining exact data and performance assertions.
- **Follow-ups:** redeploy both frontends after clean verification and retain
  hosted assets/boundary receipts in PR #9. No backend/data change is needed.

### Raouf: 2026-10-17 — Complete page-entry focus before paint

- **Scope:** resolve the remaining WebKit legal-keyboard failure in final CI.
- **Evidence:** the trace shows the legal heading without its navigation tabindex
  after load, then gaining it during the test's contents-link focus operation.
  The delayed page-entry effect stole focus before Enter could activate the link.
- **Change:** run the existing title/page-heading focus in `useLayoutEffect` so
  it completes before paint in this client-rendered app. Preserve the original
  keyboard assertion and navigation behavior; add no timer or test retry.
- **Files:** `src/hooks/useNavigation.js`, QA notes, this log and `CHANGELOG.md`.
- **Verification:** independent review found no actionable concern. Run repeated
  legal, navigation and keyboard checks: all 72 pass across three engines. Lint,
  formatting, types and docs pass. Complete final-head CI before deployment;
  browser assertions and performance budgets remain intact.
- **Follow-ups:** retain the CI trace privately, finish both frontend deployments
  and record live verification in PR #9. No backend/schema change is needed.

### Raouf: 2026-10-17 — Keep the Escape preview gesture onscreen

- **Scope:** correct the mobile fixture exposed by final CI in PR #9.
- **Evidence:** development passed 393/393; production passed 142/143. The
  failing Escape trace moved the pointer to y=790.59375 in a 664px viewport,
  then expected another in-bounds preview collision while held offscreen.
- **Change:** give this two-slot phone gesture the same 1100px height as the
  multi-slot save case and assert its held pointer is inside the viewport and
  dialog. Preserve exact preview, Escape, original-order and superset checks.
  Normal-height edge scrolling, touch tests and application code are unchanged.
- **Files:** `tests/routine-drag.spec.js`, QA notes, this log and `CHANGELOG.md`.
- **Verification:** all 25 repeated Escape cases pass across five production
  profiles, without retries. Independent review has no actionable finding;
  lint, formatting, types, documentation and whitespace checks pass. Complete
  the full production matrix and final-head CI before redeploying both frontends.
- **Follow-ups:** record final CI and hosted receipts in PR #9; no API, schema,
  member-data change or merge is required.

### Raouf: 2026-10-17 — Verify trusted presses in the rapid drag regression

- **Scope:** fix the rapid-drag driver issue exposed by final CI in PR #9.
- **Evidence:** push development passed 392/393 while independent PR development
  and production passed 393/393 and 143/143 on the same application. The failing
  trace shows Playwright pressing an animated interceptor, then retrying without
  releasing the mouse. An isolated WebKit reproduction emits no source press.
- **Change:** resolve handle hit-testing with hover, then send one trusted
  mouse-down/move/up per gesture and assert all three native handle presses.
  Retain immediate releases, no Save waits between gestures and exact saved
  order and field assertions. Application code and retry settings are unchanged.
- **Files:** `tests/routine-drag.spec.js`, QA notes, this log and `CHANGELOG.md`.
- **Verification:** all 15 repeated rapid gestures pass across three engines;
  lint and formatting pass. Independent review found no actionable concern.
  Complete full production and final-head CI before frontend deployment.
- **Follow-ups:** record CI/live receipts in PR #9; no backend, schema,
  member-data change or merge is required.

### Raouf: 2026-10-17 — Freeze drop geometry at native pointer release

- **Scope:** preserve the released slot when the next gesture scrolls immediately.
- **Evidence:** the explicit-input phone fixture first exposed offscreen target
  centers. Align the list below the header before each press, fit the phone-width
  rapid sequence onscreen and assert visible release coordinates. With all three intended
  native presses verified, the old bundle failed 11/20 valid rapid-scroll cases
  across engines, changing saved order and sometimes splitting the superset.
- **Change:** snapshot the resolved order in window pointer-up/cancel capture,
  before Motion's delayed end callback or subsequent scrolling changes geometry.
  Bind the snapshot to the native press, pointer ID and start timestamp, capture
  the visible anchor before focus and accept only one release per press. The
  eventual commit still validates cancellation, timestamp, keys and latest values.
  Preserve the current preview when stationary edge scrolling has advanced it,
  instead of resolving that release against the original pointer anchor. Clear
  this marker whenever the pointer moves, so a return does not reuse it.
  Measured visible/focused WebKit frames took roughly 200–300ms: the old 100ms
  scroll cap discarded elapsed time. Preserve elapsed time up to a bounded
  500ms and cross all reached neighbor centers in one preview commit, retaining
  DOM-key guards, speed and exact data assertions without larger test budgets.
- **Files:** both prescription components, rapid-drag regression, QA notes,
  this log and `CHANGELOG.md`.
- **Verification:** 12 repeated rapid-scroll regressions pass across three
  development engines, then all 30 rapid/top-edge repeats pass across five
  production profiles with an explicit guest build. Independent review found
  no actionable issue. Lint, formatting, types, documentation and whitespace
  checks pass. All 60 rapid, fast-multi-row and top/bottom-edge repeats then pass
  across five production profiles after elapsed-time and collision catch-up fixes.
  The complete production matrix then passes 143/143. Complete the remaining
  development matrix and final-head CI before deployment, with zero retries
  and unchanged exact data, cancellation and performance assertions.
- **Follow-ups:** publish both frontends and retain final CI/live receipts in
  PR #9; no backend, schema, member-data change or merge is required.


### Raouf: 2026-10-23 — Native iPhone offline training foundation

- **Scope:** Start the supplied iOS master/motion plans in an isolated `ios/`
  SwiftUI project. Current source wins over stale plan examples: workspace v2,
  1,711 accepted exercise IDs, 1,411 selectable movements and website policy v1.3.
- **Summary:** Added four native tabs, routine editing/search/attributed guides,
  measurement-aware set completion/undo, persistent rest, notes, receipt and real
  empty-first progress; SQLite actor transactions/recovery/revisions, explicit
  export/logical reset, protected backup-excluded storage, appearance/motion/haptic
  preferences, original decorative art/icon and pinned macOS verification workflow.
  Saved feedback follows COMMIT; unfinished numeric drafts are labelled unsaved.
  Native account transport/import, production services and publication are absent.
- **Files:** `ios/` app/core/tests/resources/project/docs/design; native resource
  generator and contract-check scripts; `unit/ios-resources.test.js`;
  `.github/workflows/ios.yml`; root README, AGENT and CHANGELOG.
- **Verification:** Swift 6.2 package 30/30; JS unit 127/127; actual Swift-generated
  workout exports 1,711/1,711 pass strict web validation; deterministic resources,
  lint, Prettier, TypeScript, docs, existing web build, native syntax/format,
  plist/JSON/YAML and whitespace pass. Restored stale installed dependencies with
  the unchanged lockfile. Native SwiftUI typecheck/simulator/device checks were
  not possible on Linux. Evidence: `ios/docs/verification.md`.
- **Follow-ups:** Build/run the native scheme on Mac; complete keyboard/accessibility,
  device interruption/protection and performance evidence, native auth/import and
  App Review/legal/rights/signing gates. No push, deployment or store submission.


### Raouf: 2026-10-23 — Apple design and Liquid Glass refinement

- **Scope:** Read the native app file by file and refine it against 52 official
  Apple text/API/session sources (including five complete WWDC26 transcripts) and three
  inspected HIG reference images. The source register distinguishes living docs,
  2026 changes and API availability; no whole-Apple-website claim is made.
- **Summary:** Added guarded native resume accessories and a single functional
  glass rest pane, semantic glass foregrounds, opaque accessibility alternatives,
  high-contrast tokens and narrow/large-text reflow. Kept data surfaces opaque.
  Added direct strict locale-aware target entry, protected profile/notes drafts,
  an in-sheet picker journey, native chart accessibility and direct Finish.
  Serialized local writes, rechecked queued session identities, preserved unequal
  side values and bounded SQLite BLOBs before Data allocation. Completed source
  provenance, reproducible unchanged icon tooling and Xcode/SDK 26.1 CI gates.
- **Files:** Native app/theme/core/tests, project/CI, generated source manifest,
  resource generator/tests, design provenance/tooling, source/file-review docs,
  README, AGENT and CHANGELOG. Per-file hashes and dispositions:
  `ios/docs/native-file-review.json` and `ios/docs/native-design-review.md`.
- **Verification:** Swift 44/44, JS 129/129 (12 resource cases), actual native export
  parity 1711/1711; deterministic resources, original icon pixels, lint, types,
  Prettier, docs, existing web build, Swift syntax/format and config parsing pass.
  Thirty-seven solid-color text/border pairs meet their 4.5:1/3:1 targets; this
  does not cover glass compositing. Five native UI journeys are authored but not
  run here. Xcode/SwiftUI compilation and rendered/device QA remain unrun on Linux.
- **Follow-ups:** Execute the enforced SDK 26.1+ native workflow on Mac and complete
  the actual narrow/large-text, keyboard, VoiceOver, motion/transparency/contrast,
  glass compositing and device matrix before visual sign-off or distribution.
  No push, deployment, TestFlight or App Store submission occurred.


### Raouf: 2026-10-23 — Full native correctness audit

- **Scope:** All 68 authored native files, eight integration files and six shared
  contract modules; preserve the loaded draft and no-publication instruction.
  Current Apple source register: 62 text/API/session sources and three inspected
  reference images. Complete source reading, all-record generated checks and
  decoded assets are distinguished in the per-file SHA-256 ledger.
- **Summary:** Fixed workout/notes acknowledgement races without dropping queued
  lifecycle saves; bound completion/add-set work to captured session/entry IDs;
  corrected duplicate-entry previous-set lookup, deleted-history detail retention,
  per-side range traps, prefix-colliding draft cleanup and duplicate routine saves.
  Kept loaded timed-distance values visible and volume units consistent. Added
  portable backup names, export snapshot cleanup and compact 20 MiB-bounded export;
  a valid 150,000-set backup now occupies 11.6 MB instead of 36.4 MB. Aligned native
  canonical validation using 38 shared boundary records; deduplicated identical
  corrupt recovery originals; strengthened actual native default/unit/completion
  comparisons. Avoid repeated history parsing on unchanged-history commits.
- **Files:** Native app/core/tests/fixtures, contract checker, resource/boundary
  unit tests and CI triggers; Apple/privacy/verification/file-review docs; README,
  AGENT and CHANGELOG. `ios/docs/native-file-review.json` lists every input hash.
- **Verification:** Fresh Swift 62/62 and JS 134/134 pass; all 1711 fresh actual
  native exports pass strict web validation and independent default-measurement
  comparisons. The session 422-input probe has no rejected native-accepted output;
  three stronger native whitespace-name rejections remain intentional. A 150,000-
  set export round-trips and passes the web backup reader. Resources/icon, lint,
  types, formatting, docs, web build, Swift syntax/format and config parsing pass.
  Linux Foundation benchmark identifies avoidable 191–341 ms history rebuild work;
  the equality guard takes 0.020–0.066 ms in that harness, not an iPhone measurement.
- **Follow-ups:** Eight authored UI journeys remain unrun on Linux. Xcode/SwiftUI
  compilation, simulator/device accessibility, keyboard, interruptions/protection,
  performance, archive/privacy/legal/rights/signing and Store gates remain open.
  No native import/account transport, server boundary or published state changed;
  no push, deployment, TestFlight upload or App Store submission occurred.


### Raouf: 2026-10-26 — First Xcode build and file-by-file native audit

- **Scope:** All 76 files from `57d685a`, on macOS with Xcode 27.1 / iOS 27.1 SDK
  for the first time; Apple Watch requirements rechecked against 2026 sources.
- **Summary:** The app did not compile: `PlanView` used a nonexistent
  `Section(title) { } footer: { }`. Native workout start now rejects per-side
  rep ranges above 50, matching `main`'s `perSideTargetError`. The receipt no
  longer blanks while dismissing; inline save errors no longer replay as stale
  root alerts; UI tests query the finish alert by label. Cached date formatters,
  indexed exercise lookup and empty-query search skip avoidable per-row work.
- **Files:** Native app (`AppModel`, `FORMAApp`, `PlanView`, `WorkoutView`,
  `YouView`), core (`WorkoutEngine`, `ExerciseSearch`), tests, UI tests;
  `ios/docs/full-audit-2026-10-26.md`, `ios/docs/verification.md`; AGENT, CHANGELOG.
- **Verification:** Swift 63/63; contract probe 1711/1711; Debug and Release
  Xcode builds without Swift warnings; swift-format clean; resources regenerate
  without diff; JS 134/134, lint, Prettier, types, docs. UI journeys not run (no
  simulator runtime installed). Watch API availability matched SDK headers.
- **Follow-ups:** Run the UI journeys on a simulator; open a PR so the Native iOS
  workflow runs for the first time (confirm `macos-15` has Xcode 26.1+); update
  the Watch matrix's current-state column for this branch; hold timer parity.
  No push, deployment or store action occurred.


### Raouf: 2026-10-26 — Native hold timer and Apple Watch workouts

- **Scope:** Close the hold-timer gap with the web (PR #20) and add an Apple Watch
  companion: a workout started on the iPhone checks for the Watch, begins when
  Start is pressed on the Watch, and the Watch records it to Apple Health.
- **Summary:** `HoldTimer.swift` ports the web rules (5 s to 60 min, unit steps,
  default from the next unfinished set, legacy plank logs a rep per 10 s, no timer
  for per-side plank) and `WorkoutEngine.logHold` completes the set with rest
  exactly as ticking does. The workout screen adds the countdown with pause, end
  early, cancel, keep-awake, haptic, tone unless muted and a VoiceOver
  announcement. `FORMAWatch` (watchOS 10) runs `HKWorkoutSession` and
  `HKLiveWorkoutBuilder`, mirrors to the iPhone, recovers after a crash and saves
  in Apple's stop/end/finish order. The iPhone checks pairing and installation
  first and starts on its own when no Watch is paired. Finish saves the Watch
  workout; discard discards it. Heart rate and energy stay in Apple Health, so
  the workspace contract is unchanged. The privacy notice, inventory and review
  matrix now describe the Health use.
- **Files:** `ios/Sources/FORMACore/{HoldTimer,Models}.swift`, `HoldTimerTests`;
  `ios/Shared/`, `ios/FORMAWatch/`, `WatchWorkoutCoordinator`,
  `StartWorkoutSheet`, `AppModel`, `FORMAApp`, `WorkoutView`, `TodayView`,
  `PlanView`, entitlements, `Info.plist`, `project.yml`;
  `scripts/build-ios-resources.mjs` and regenerated `legal.json`/manifest,
  `unit/ios-resources.test.js`; `ios/docs/apple-watch.md` and privacy docs;
  README, AGENT, CHANGELOG.
- **Verification:** Swift 71/71; contracts 1711/1711; iPhone + embedded Watch
  build (simulator Debug, device Release) and Watch scheme build without Swift
  warnings; Watch binary arm64 + arm64_32; resources check, JS 134/134, lint,
  Prettier, types, docs; swift-format clean. No simulator or device run.
- **Follow-ups:** Test on the real iPhone and Ultra 2 (detection, permissions,
  live metrics, reconnect, one Health workout per finish, none on discard,
  locked-phone save, recovery, battery, heart-rate sample density). Set up the
  team, bundle IDs and HealthKit capability for signing. Update the Watch
  matrix's current-state column. No deployment or store action occurred.
- **Release:** Committed as `718e8cf` and pushed to `origin/work` on 26 October
  2026 (no pull request yet, so the Native iOS workflow has not run). Decisions,
  15 evidence-backed claims and the new iOS docs are recorded in Zurvan.

### Raouf: 2026-10-29 — Private native widgets and training audit

- **Date/scope:** 29 October 2026, Australia/Sydney; native iPhone/Watch audit on `feat/frontend-widgets-2026-10`, preserving the existing dirty account/navigation baseline at `c0883a3`.
- **Summary:** Added six WidgetKit families with owner-scoped opt-in, protected committed snapshots and precise draft-safe links; refined Today/accessibility layouts; repaired hold retries, recovery/import ownership and Watch failure/reconnect status. Release coverage instrumentation is disabled; test coverage remains opt-in.
- **Files:** Native app/core/Watch/widget/shared-surface sources and tests, `ios/project.yml`, privacy/resources/README, generator, widget bundle validator and CI. Exact paths and 146-path baseline reconciliation: `ios/docs/audits/frontend-widget-2026-10/FILE_LEDGER.md`; ten reports and original visual evidence accompany it.
- **Verification:** 141 core + 4 surfaces, 32 hosted app, 24 UI regressions, separate real widget gallery/install/link and three dark tours passed; final focused layout/render reruns passed with 120 widget images. 151 web unit tests and 1,711 native contract cases passed. Signed Release/bundle checks and final iPhone installation passed; launch remained locked. Short Simulator trace captured; no physical performance claim.
- **Follow-ups:** Unlock/connect the companion iPhone by USB for launch and Watch pairing; verify passcode widgets, Watch/Health recovery, physical accessibility, older runtimes, live staging account deletion and Store/legal/privacy gates. Live Activity/Watch complications remain explicitly deferred. No commit, push, merge, production deployment or Store submission.

### Raouf: 2026-10-29 — Publish native account and widget checkpoint

- **Date/scope:** 29 October 2026, Australia/Sydney; owner-authorized feature-branch delivery and durable handoff.
- **Summary:** Committed native accounts/navigation, protected widgets and the audited training fixes as `076e267c6a4b3b5081348ddbd40cf53e22700ffd`; pushed `feat/frontend-widgets-2026-10` and verified the matching remote ref.
- **Files:** AGENT, CHANGELOG, root/native READMEs, account review, audit publication records and reconciled file ledger. Zurvan reference note recorded privately; source ingestion/index refresh belongs to this delivery postflight.
- **Verification:** Staged source hashes matched the settled audit; staged additions secret scan had zero findings. Existing native/web/contract test evidence retained. First-push GitHub CI was in progress, not a claimed pass.
- **Follow-ups:** Finish locked-phone/Watch, physical privacy/accessibility/performance and live staging account gates. No merge, production deployment, Store action or public Zurvan push.
