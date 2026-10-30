# Agent notes

Branch consolidation on 13 October 2026 uses main as the repository's confirmed
default branch. The Node 26 Docker base and action releases are pinned. ESLint
stays at 9.39.5 until the React/accessibility plugins declare ESLint 10 support;
the attempted upgrade fails normal `npm ci`. Preserve peer checks.

`.gitleaksignore` contains exact historical fingerprints for the public
Cloudflare Access audience and two public container-label receipt findings.
These grant no access; signature, issuer and owner validation remain mandatory.
Do not replace these with a general path/rule allowlist or add exceptions for
credential material.

Catalog import measurement classification lives in
`scripts/exercise-measurement.mjs`; use ordered string matching and retain
measurement precedence. The regression suite checks all published supplemental
labels. Final merge checks passed 51 unit, 46 Node 26 API, 20 gateway and 14
operations cases. Two network-interrupted Chromium journeys passed all six
repetitions; the other 256 browser cases passed the full run. Keep Docker network
setup separate from browser startup to avoid Chromium ERR_NETWORK_CHANGED.

Rules and context for coding agents working in this repository. Read this and
[CHANGELOG.md](CHANGELOG.md) before changing code, and append to both after.

## Constraints

- Security boundaries live on the server and in the Worker, never only in the
  UI. Member identity comes from the server session; never accept an owner,
  user ID or role from a request.
- `server/app.ts` is deny-by-default: only exact `/healthz` is public, every
  other path needs the Worker secret, mutations need the exact app `Origin`,
  and auth requests must be JSON objects. Keep new routes inside this model.
- Better Auth endpoints are reachable only through `AUTH_ROUTES`. Adding a
  client call to a new Better Auth endpoint means adding it there, with a test.
- Redirect parameters and emitted `Location` must stay same-origin
  (`isSafeRedirect`).
- Password attempts go through `reserveAttempt` and settle with
  `settleFailure`, `refundAttempt` or `clearSignInFailures` (`server/throttle.ts`).
- The workspace schema in `src/storage.js` is shared by the browser and the API.
  Keep the aggregate bounds checked before zod parsing.
- The Worker forwards allowlisted headers and cookies only. Do not widen the
  allowlists without a test showing why.
- New database tables need a numbered migration and an entry in
  `ops/grant-runtime-access.sql`. Never edit an applied migration.
- Tests that need PostgreSQL must fail, not skip, when `TEST_DATABASE_URL` is
  missing.
- The repository is public: no secrets, real member data or exploit recipes.

## Checks

```sh
npm run lint && npm run format:check && npm run typecheck && npm run docs:check
TEST_DATABASE_URL=postgres://… npm run test:server
npm run test:worker && npm run test:unit
npm test && npm run test:browser:production
TEST_DATABASE_URL=postgres://… npm run test:accounts
```

## Log

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

### Raouf: 2026-10-28 — iOS native accounts (app half)

- Code lives in `ios/FORMA/Account/` plus `AppModel+Account.swift`. The pure
  wire layer (cookie jar value, request bodies, response decoders, error
  wording) is in FORMACore (`AccountCookies.swift`, `AccountWire.swift`) so
  `swift test` covers it; the app files are thin shells over it.
- Store switching: signed out is the guest store, untouched. Signed in is one
  SQLite file per member (`WorkspaceStore.memberStoreURL`) with an
  `AccountSync`. The guest store is never written while signed in and is merged
  only by "Bring your phone training". Sign-out keeps the member file unless
  "Sign out and remove from this iPhone" is chosen.
- Nothing schedules sync by itself: after each commit `markDirty` + `flush`, at
  launch and on foreground `refresh`, timed retry with back-off plus a
  reachability trigger. After any call that may replace the member workspace,
  reload it from the store or the next save fails with `conflictingRevision`.
- Account origin is the build setting `FORMA_ACCOUNT_ORIGIN` (project.yml →
  Info.plist `FORMAAccountOrigin`), production by default. HTTPS only, ATS
  default. Requests send `X-Forma-Client: ios`, never `Origin`/`Referer`/
  `Sec-Fetch-*`; the URLSession has cookies, cache and credentials off and
  refuses redirects. Never call the production API from tests.
- Privacy text is generated: edit `scripts/build-ios-resources.mjs`
  (`nativeLegal`) and run it, then keep `ios/FORMA/Resources/native-privacy.md`
  in step.

### Raouf: 2026-10-27 — iOS motion system (Commit 2)

- All native motion goes through `FormaMotion.swift`. Views read
  `@Environment(\.formaMotion)` and use `motion.animation(token)`,
  `motion.transition(...)`, `.formaAnimation(_:value:)` or
  `.formaReveal(order:)`. Never read `accessibilityReduceMotion` or
  `model.motion` directly in a feature view; the root resolves both (plus
  Prefer Cross-Fade Transitions on iOS 26.4+).
- Rules live in `ios/docs/commit-2/MOTION_SPEC.md`: animate committed state,
  never the tap; no loops; no animating through invented chart values; no
  animation while a field is being typed in. `.success` is reserved for the
  finished-workout receipt; a saved set is `.impact(weight: .light)`.
- XCUITest: lists (`Form`, `List`) are lazy, so a row below the fold does
  not exist until scrolled to. Target the finish alert by `finish-confirm`;
  the toolbar button shares the label "Finish workout". Replace field text by
  selecting it (`replaceText(with:)`), not by sending one delete per
  character. A view placed in `formaBottomBar` needs
  `.accessibilityElement(children: .contain)` or the screen identifier
  overrides its controls' identifiers.
- `ScreenshotTourTests` produces named before/after screenshots; run it once
  per appearance (`xcrun simctl ui <udid> appearance light|dark`).
- Haptics: call `model.haptic(_:)` with a `FormaHaptic` after the change it
  confirms has saved; never add a bare `.sensoryFeedback` that skips
  `hapticsEnabled`. Keep one system pattern per meaning (map in
  `ios/docs/commit-2/IMPLEMENTATION_REPORT.md`).
- Native sign-in: read `ios/docs/native-accounts-findings.md` first. The
  browser Origin/cookie boundary must not be relaxed for the app, and the
  "production must stay guest-only" note above predates the 13 Oct 2026
  account launch.

### Raouf: 2026-10-27 — iOS launch path and performance rules

- Keep startup work off the main thread: `AppModel.prepareLaunch()` is
  `@concurrent` and returns everything the first screen needs. Do not add
  synchronous decoding or SQLite work to `load()` or view initialisers.
- Exception: `WatchWorkoutCoordinator.init` must keep activating
  `WCSession` and registering the HealthKit mirroring handler at launch;
  iOS may wake the app in the background for either.
- Engine calls look the catalogue up through `ExerciseMetricIndex.cached`;
  never rebuild a dictionary of the catalogue per call or per row.
- `ios/FORMA.xcodeproj` is generated and untracked; a fresh worktree needs
  `xcodegen generate` (or a copy) before building. On the iOS 27.0
  simulator, 5 of the 8 UI tests also fail on the original code, so compare
  against a baseline before blaming a change.
- Device installs use automatic signing with team `3L5A4R7JNY`
  (`-allowProvisioningUpdates`); the bundle ID is still the provisional
  `dev.raoufabedini.forma`.

### Raouf: 2026-10-27 — cloudflared 2026.10.4 (eMudhra advisory)

- **Why:** Cloudflare's 2026-10-26 advisory: cloudflared before 2026.10.2
  trusts eight compromised eMudhra (emSign) intermediates. Both tunnels ran
  2026.9.3.
- **Change:** `ops/compose.yaml` pins
  `cloudflare/cloudflared:2026.10.4@sha256:c6c7ae1d…0515` (index digest
  re-resolved from Docker Hub). The same line was applied on the Droplet
  (`compose.yaml.pre-cloudflared-2026.10.4-*.bak` kept) and only the
  `cloudflared` service recreated with `--no-deps`, staging before production,
  with each environment's usual overlay and `.env`.
- **Verification:** both containers report 2026.10.4 and registered four edge
  connections. Origins are `http://api:3000`, so the upgraded trust store
  cannot reject an origin certificate.

### Raouf: 2026-10-26 — Apple Watch readiness and full baseline audit

- Published the audit of all 1,471 tracked baseline files and 37 Apple Watch
  requirements, including relevant 2026 API and submission guidance.
- Recorded open runtime, operations, privacy and testing findings with explicit
  evidence limits. No native iOS/watchOS integration or application fixes added.
- See [the audit](docs/audits/apple-watch-readiness-2026-10-26/README.md).
  Baseline verification is separate from this documentation-only publication.

### Raouf: 2026-10-26 — Runtime audit deployed

- **Source/order:** owner-authorized PR #30 merged as `10942dc`; application
  inputs `d770a6c`, documentation/scanner follow-up `4234d5e`. Released each
  API before its account website, staging before production, using explicit
  Compose project names.
- **Hosted result:** both APIs run Node 26.12.1/Undici 8.12.2 as UID 10001.
  Encrypted signed off-host backups, unchanged counts/unrelated containers and
  zero observed API error lines recorded. Both environments passed 38 HTTP
  checks, exact HTML/four-asset hashes and 15 responsive functional states.
  Thirty baseline accessibility node findings remain unchanged; staging's
  response-fulfilling screenshot artifact was checked with native requests.
- **Verification/follow-up:** CI security and non-browser checks passed; at
  05:50 UTC the development browser suite had passed and later browser
  suites were unfinished. Worker deployment tokens were revoked; temporary
  release-access cleanup completed at 05:48:47 UTC, preserving existing
  policies and removing private session journals. See
  [release evidence](docs/qa/runtime-quality-2026-10-26/README.md) for image
  identity, Worker versions, scope and retained accessibility follow-ups.

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

### Raouf: 2026-10-26 — Full file and runtime quality audit

- **Scope:** local audit of baseline `678b483` begun 23 October and completed
  after continuation; all 1,453 tracked paths reconciled, 550 applicable files
  reviewed and 903 generated/imported/binary files individually validated.
  Ten new implementation/test files and six audit reports are also inventoried.
- **Changes:** protect cloud retry/conflict state from older refreshes; validate
  per-side routine targets before saving/starting; release late hold wake locks;
  close stale exercise pickers and escape imported IDs during focus restoration.
  Sequence backup reviews, use Sydney dates/weeks, correct coach side-rep
  estimates and expose Privacy export feedback. Aggregate Progress once, cache
  unchanged search text, hash the captured guest backup once, and use a validated
  owner-filtered SELECT for established workspace reads. Handle idle pool errors
  without logging raw errors; preserve bearer authentication challenges.
- **Files:** state/storage orchestration, Account/Workout/Routines/Insights/
  RoutineCardOrder, new progress helper, catalog search, server workspace/coach/
  entry point, gateway and regression tests. Correct current docs and unsafe
  historical rollback guidance; full paths are in
  `docs/audits/forma-runtime-quality-2026-10/FILE_AUDIT.md`.
- **Dependencies:** the final advisory check found fast-uri advisories published
  after the initial check. Patch four fast-uri records to 3.1.9/4.2.3; override only the exact Miniflare
  version to patched Undici 7.30.1. The pinned Node 26.12.1 image also patches
  its bundled Undici to 8.12.2. Direct library pins and engine constraints remain
  unchanged. Revalidate clean installation, tooling and the API image.
- **Verification:** lint, formatting, types, docs and builds pass; unit 134/134,
  server 67/67 on Node 26.12.1, Worker 27/27 and operations 14/14. Full npm
  audit reports zero vulnerabilities. All 902 browser cases have passing
  coverage: the original 901-pass/1-timeout run was investigated, and the
  affected 22-case profile passed unchanged at its original budget. Matched
  performance and screenshot evidence are recorded in the audit reports.
- **Decisions/follow-ups:** the scratch route split was rejected: it delayed first
  training navigation and broke first-use navigation after going offline.
  Initial payload and physical-device/hosted checks remain follow-ups. Preserve
  schema, saved IDs/units, explicit import review and account boundaries. No
  deployment, push, merge or production action was performed. Review the six
  audit reports before a separate staged API/frontend release.

### Raouf: 2026-10-22 — Dependency release deployment

- Both environments run `forma-api:deps-20261022-d05d40b` at schema 0006.
  Production Worker `c5639ed9-…`, staging `a981c1e7-…`; `main` is `fb6f115`.
  Rolling back to `holds-timer-20261022-316c5d9` is safe (same catalogue);
  anything older rejects the timed hold IDs.

### Raouf: 2026-10-22 — Dependency updates

- `npm install` writes `^` ranges; this repo pins exact versions, so strip
  them before committing. Dependabot ignores ESLint and `@eslint/js` majors
  until the plugins support ESLint 10.
- Server, auth and Node-base bumps change the API image: release the API
  (`docs/qa/holds-timer/api-release.sh`, always `-p forma-<env>`) before or
  with the website.

### Raouf: 2026-10-22 — Holds release and the Compose project name

- Both hosts' `ops/compose.yaml` start with `name: forma-staging`. Every
  Compose command on the Droplet must pass `-p forma-<env>`; without it,
  production commands act on staging's containers (this recreated the
  staging database once). Use `docs/qa/holds-timer/api-release.sh`, which
  pins the project, detaches the backup tool from stdin, and switches back
  if the API is not healthy.
- Both environments run `forma-api:holds-timer-20261022-316c5d9` at schema 0006. Do not roll back to `workout-coach-20261019-98f853d` once a timed
  hold is saved; the older image rejects those IDs.
- Production Worker `28ef859c-…`, staging `2b97ab5f-…`; `main` is
  `c4b3b2b`.

### Raouf: 2026-10-22 — Wait for images in browser assertions

- Check a loaded image with a retrying assertion
  (`await expect(img).toHaveJSProperty("naturalWidth", n)`), never a one-off
  `evaluate`: under CI load the read can land before the image decodes.
- A Verify run cancelled at the job limit is not a failure; check the limit
  in the PR's base branch before investigating.

### Raouf: 2026-10-21 — Switching a routine hold to its timed version

- **Supersedes** the line below that a routine hold keeps logging reps "until
  the member replaces it": the routine editor now offers **Use the timed
  version** under such an entry, and the workout card's ⋯ menu offers the
  same. The rule is `timedVersion` in `src/timedHolds.js`: a saved ID that
  logs reps (`tracksLoadReps` on `exerciseById`) whose canonical row
  (`canonicalId`) has `metric: "duration"`. Take units from `exerciseById`,
  never from `guideExercise`.
- It only runs when the member presses it. `toTimedVersion` keeps sets, load,
  RPE, rest, note, superset and position, sets `reps: 1`, `repsMax: null` and
  `durationSeconds` (60 by default, editable before saving), clears
  `perSide` (it only applies to reps), and writes the
  old key into `entryId` so `entryKey` and the editor's `repInputs` stay put.
  History and the active workout are never rewritten; saved sets keep the rep
  ID and their reps.
- Excluded on purpose: the legacy `plank` (10-second reps and its own timer)
  and seconds-and-metres aliases (Battle Ropes, Rope Jumping), which already
  log time and would lose their distance.
- The workout card goes through `replaceEntry` and `setsLostByReplacing`, so
  completed rep sets are dropped only after the confirmation, which now reads
  "Log L-sit in seconds?" instead of "Replace L-sit with L-sit?".
  `replaceEntry` now keeps `note`, `rpe` and each set's `weight` whenever the
  replacement has the same canonical ID (a 20 kg Plate Pinch stays 20 kg);
  other replacements still start from the new exercise's defaults.
- `tests/timed-hold-switch.spec.js` uses relative URLs.
- **Verification:** unit 116/116 (6 new); the new spec 4/4 in Chromium and
  WebKit. Development suite on a private port at load 40-150: 256/320 first
  pass, almost all timeouts; the 64 failures rerun serially 58/64, and the
  six left (WebKit focus cases in `keyboard-focus`, `regressions:200/229`,
  `ui-coverage-gaps:333/379`, `exercise-media:37`) fail the same way on
  `9b0c216`. Production guest build: 124/160; 31 are Firefox failing to
  launch in this sandbox, the other 5 (`routine-programming:4`,
  `routine-archive:4`, `routine-drag:321`) passed 8/8 serially. Lint,
  Prettier, types, docs and worker 26/26 pass. Docker was off, so the
  PostgreSQL server and account suites did not run locally; CI runs them.
  A vite build from a symlinked mirror fails (`index.html` resolves outside
  the root): build in the worktree and link `dist` instead.

### Raouf: 2026-10-21 — Hold metric migration, second review

- Fifteen more holds, balances and isometrics have timed identities by the
  route above: Crucifix, Axe Hold, Incline Static Hold, Hercules Pillars,
  Dynamic side hold (all `load`), Hip Raise, Lying (`added`), Balance Board,
  Downward Facing Balance, Frog stand balance, Single-leg BOSU balance,
  Single-Leg Balance with Eyes Closed, Kneeling Superman, Standing Pancake, Recruitment Pulls and Double-Leg Abdominal Press. The
  `duration` metric keeps a weight column, so a loaded hold logs seconds and
  kg. 213 exercises are now timed; 200 show the hold timer.
- Six stay in reps under `excludedMeasurementCorrections`: Seated Knee
  Extension with Overpressure, Chin tuck and Single-Leg Soft-Landing Holds
  (their guides repeat a short hold for reps), Back bridge (the guide pushes
  up and lowers, never holds), Estiramiento de brazos y cuello (the guide
  describes no position, so it needs a guide repair before any measure
  change) and "Rest (for timed workouts)" (a placeholder; keeping,
  timing or removing it is the owner's call).
- A timed identity of a one-side-at-a-time hold needs the saved ID's side
  copied to `forma-<saved ID>` in `src/catalog/unilateral.json`: `withSide`
  looks up the canonical ID, which is the timed ID itself. A reviewed guide
  repair (`docs/research/reviewed-guide-repairs.json`) follows the alias
  automatically (Frog stand balance).
- `docs/research/exercise-logging-review.json` is written as
  `JSON.stringify(value, null, 1)` with sorted keys and no final newline, and
  `docs/research/original-art/registry.json` as `JSON.stringify(value, null, 2)`
  plus a newline. Running Prettier over the registry reflows 9,000 lines.
- Same deploy order and no-rollback rule as above.
- **Verification:** unit 111/111; `unit/hold-metric-migration.test.js` 5/5,
  and its identity and timed-set tests fail on the base catalogue. The hold
  spec passes 6/6 in Chromium and WebKit, including the new loaded-hold case.
  Development suite on a private port at load average ~125: 286/318 first
  pass. 26 of the 32 failures passed on a one-worker rerun, and the six left
  (WebKit keyboard focus) fail the same way on `feat/hold-metric-migration`.
  Production 129/129 on Chromium and WebKit, desktop and mobile; Firefox
  does not launch in this sandbox. Lint, Prettier, types, docs, build,
  server build, worker 26/26 and operations 14/14 pass. The equipment audit
  is clean, artwork coverage is 1,411/1,411, both builders rebuild byte for
  byte, and the compiled API accepts the timed IDs and rejects rep sets on
  them. Docker was off, so the PostgreSQL server and account suites did not
  run locally. An independent review of the 21 guide calls moved Back
  bridge to reps and tightened three reasons.

### Raouf: 2026-10-21 — Hold metric migration

- **Supersedes** the line below that the holds stored as reps need a reviewed
  metric migration. Fifteen of them now have timed identities,
  `forma-<saved ID>` (`metric: "duration"`), built by `npm run catalog:curate`
  from reviewed `measurementCorrections` in
  `docs/research/exercise-quality-review.json`, the route the five 14 October
  timed identities took. Each saved ID is a curation alias that keeps
  `load_reps` in `exerciseById`. Never put them in
  `src/catalog/programming-aliases.json` (it rewrites saved IDs, and the units
  differ), and never give a rep entry the hold timer.
- Arch Hang stays in reps: its guide says "Hold it for time/reps". The reason
  is under `excludedMeasurementCorrections`.
- A timed identity also needs its load decision moved to the new ID in
  `src/catalog/logging-review.json` and its artwork entry carried to the new
  ID in `docs/research/original-art/registry.json` (same `guideSha256`, as
  `instructionId` keeps the guide), then
  `node scripts/build-exercise-media.mjs`. `unit/hold-metric-migration.test.js`
  pins all of it. Both builders reproduce the committed files byte for byte,
  so run them rather than editing their output.
- A routine that already lists one of these holds keeps logging reps until the
  member replaces it. In the routine editor, removing and re-adding the hold
  in one edit restores the saved entry (the cached-alias rule), so switching
  takes a save in between.
- `curation.json` and `machine-exercises.json` ship in the API image and the
  API rejects unknown exercise IDs: deploy the API before the frontend in each
  environment (staging API, staging frontend, production API, production
  frontend). `src/storage.js` and `src/exerciseMetrics.js` are unchanged.
  Once anyone saves a timed hold, do not roll back: reads re-validate stored
  workspaces (`asAcknowledgement` in `server/workspace.ts`), so an older API
  cannot load that workspace and an older frontend sends guest data to
  recovery. Fix forward.
- Eleven dev specs hard-code `127.0.0.1:5173` or `localhost:5173`. When another
  session holds that port, run a scratch copy of `tests/` with only the port
  rewritten (symlink `src`, `node_modules` and `package.json` beside it) on a
  private port rather than sharing its server.
  `tests/hold-metric-migration.spec.js` uses relative URLs.
- **Verification:** unit 110/110; the new spec 4/4 in Chromium and WebKit
  (red on the base catalogue first); development 309/316 and production
  127/129 on private ports. Every failure also fails with the base catalogue
  (six WebKit keyboard-focus cases, the `routine-library.spec.js:78` drag
  timing) or passed on rerun (concurrent tabs). The PostgreSQL server and
  account suites were not run locally.

### Raouf: 2026-10-21 — No-load columns and the hold timer

- Load display is UI-only: `src/exerciseLoad.js` reads
  `src/catalog/logging-review.json` (`load` / `added` / `none`, plus
  `noTimer`). Keep it out of `src/exerciseMetrics.js` and `src/storage.js`:
  the API imports those (`metricFields`, `tracksLoadReps`,
  `validMeasurement`) and `ops/Dockerfile` copies an explicit file list, so a
  change there needs an API redeploy. Sets still store `weight: 0`.
- `unit/exercise-load.test.js` fails while any selectable exercise is
  unreviewed. A catalogue import must add each new ID to exactly one class,
  and to `noTimer` if it is a rep-prescribed drill stored in seconds. IDs
  resolve through `canonicalId`, so an alias (`plank` → `db-plank`) follows
  its target's class.
- A `none` exercise shows its weight column again when any set has weight
  above 0. Keep that: it stops older logs disappearing.
- The hold timer is component state in `Workout.jsx`, not persisted, so the
  workspace schema is unchanged. It is a deadline (`endsAt`) on the existing
  250 ms tick, holds a screen wake lock (requested again on
  `visibilitychange`), and completes through `useEffectEvent` guarded by
  `finishedHold` so a set logs once. It writes through `holdUnit`:
  `durationSeconds`, or `reps` at 10 s each for the legacy `plank`, whose
  units are preserved.
- Do not give the holds stored as reps (Hollow Hold, L-sits, levers,
  Handstand, Deadhang) a timer by reading reps as seconds; that needs a
  reviewed metric migration.
- Drag timing is flaky under load: `routine-drag.spec.js:321` and `:77` in
  CI (local reruns 30/30), and `routine-library.spec.js:78` in
  production Chromium mobile, which fails 2 of 6 runs on `841e518` as well.
  Rerun a failed job once before investigating, and never merge on a red,
  pending or cancelled run.

### Raouf: 2026-10-21 — Drag tests reliable under parallel load

- **Scope:** CI reruns of PRs #19 and #20 and parallel local runs flaked
  `tests/routine-library.spec.js:78`, `tests/routine-drag.spec.js:77` and the
  top-edge case at `:321` (now `:408`). Each cause was traced first; no assertion was
  loosened.
- The editor hides with `<form hidden>`, which collapses every `Reorder.Item`
  to a zero box. Motion 14.3 springs each row into that box. It discards only
  zero-size snapshots, so the reveal never animates but the hide does.
  `RoutinePrescriptions` takes `hidden` and makes the layout transition
  instant while the library is open. Without it, closing the library within
  about 400 ms brought the rows back mid-spring, 70–220 px off. The drag
  helper then pressed moving rows or the sticky header.
- Motion delivers `onDragStart` and `onDragEnd` on later frames. Starved
  WebKit frames on CI spread one gesture's start and commit over about 700 ms,
  and `hover()`'s stability check passes between stalled frames. A test that
  aims a new press must first wait until the previous drop has landed and
  every row is at rest: no `.is-dragging` and identity transforms. App logs
  showed every such gesture beginning and finishing with a valid release.
- A superset survives only while its entries stay adjacent
  (`normalizeGroups`). Drag expectations derive `groupId` from the final
  order: a top-edge drop can land between the two superset entries.
- A stationary edge-scroll release is checked against the dialog's visible
  area, not the list's bounds. Holding at an edge until scrolling stops moves
  the list away from the pointer (the form or the Save row slides under it),
  and the old check cancelled a drop the preview showed in the first or last
  slot. Edge tests measure the slot reachable without scrolling _before_ the
  pointer moves; a later read can arrive after scrolling has finished.
- To reproduce starved frames, delay the page's `requestAnimationFrame`
  callbacks in an init script. Playwright's isolated world keeps native
  timing. Chromium CPU throttling does not reproduce the failure.
- **Files:** `src/components/Routines.jsx`, `RoutinePrescriptions.jsx`,
  `RoutinePrescription.jsx`, `tests/routine-drag.spec.js`,
  `tests/routine-library.spec.js`, `docs/qa/routine-row-drag/README.md`, this
  log and `CHANGELOG.md`.
- **Verification:** `--repeat-each=20` at the default two workers, one suite
  at a time: production Chromium and WebKit, desktop and mobile, 560/560 for
  the seven affected cases; development Chromium and WebKit 280/280. The full
  production suite passes 141/141. The editor-related development specs pass
  205/210; the five failures are WebKit focus cases that fail identically on
  unmodified `main` on this host. Lint, format, types, docs and 98 unit tests
  pass. Running several suites at once on this 8-core host (load 100–200)
  produced only 30 s test timeouts; count those as host load, not drag
  failures.

### Raouf: 2026-10-21 — CI Verify job limit

- `.github/workflows/ci.yml` gives `verify` 70 minutes; the four browser
  suites run sequentially (~23 + 6 + 13 + 4 min). If it times out again,
  split the account suites into their own job rather than raising the limit
  further. Treat a cancelled step as not passed.

### Raouf: 2026-10-21 — Card animations release

- Production runs `7079e21` (version `5fa82b05-…`), staging `9814b283-…`.
  This is ahead of PR #19's `main` merge: merge #19, retarget #20 to `main`,
  then merge #20 so `main` matches production.

### Raouf: 2026-10-21 — Animations in the cards

- `ExerciseAnimation` reads `src/catalog/animations.json` (canonical guide ID
  → `src`, `still`, `seconds`, `description`) built by
  `python3 scripts/exercise-svg/build.py`, which resolves exact FORMA names
  through `src/data.js` and fails on an ambiguous or missing name. Never
  hand-edit the manifest or `public/exercise-animations/`.
- Animations load through `<img>` (CSP has `object-src 'none'` and
  `frame-ancestors 'none'`, so `<object>`/`<iframe>` would not work); pausing
  swaps to the `-still.svg`. Keep the pause control: the loops exceed 5 s.
- Card media order is fixed by the owner: cover illustration
  (`ExerciseMedia`), then the video (`ExerciseDemo`) if any, then
  `ExerciseAnimation`. Keep all three together at the top of the card.
- Exercises without an animation simply render nothing; e.g. the starter
  "Leg day" template opens on the barbell back squat, which has none.

### Raouf: 2026-10-21 — Preview and demo production release

- Production runs `846919b` (version `c0778873-…`), staging `27a43e9`
  (`85e28324-…`); both serve the same app bundle. Merge PR #19 after CI so
  `main` matches. The owner approved this production deploy in chat; a later
  release needs its own approval.

### Raouf: 2026-10-21 — Preview and demo staging release

- Staging runs `27a43e9` (version `85e28324-…`). Production still runs the
  previous release until the owner runs `npm run worker:deploy:production`
  (agent sessions in auto mode are refused production deploys; do not work
  around that, hand the command to the owner). After production, merge
  PR #19 so `main` matches production.
- CI Semgrep (`p/nodejsscan`) blocks any `createHash("sha1")` in `scripts/`.
  The demo registry keeps Commons' SHA-1 as provenance only and verifies
  originals with `originalSha256`.
- Deploy env: `set -a; . ~/.config/forma/production-deploy.env; set +a`, then
  unset the Droplet variables before running the deploy script; only
  `CLOUDFLARE_API_TOKEN` is needed for website releases.

### Raouf: 2026-10-21 — RDL polish

- For any barbell hinge, place the bar with `bar_on_legs` (straight arms
  meeting the leg-front polyline) rather than a hand-picked target, which bent
  the elbows at lockout.

### Raouf: 2026-10-21 — Legs B demos

- `scripts/exercise-svg/legs_b.py`. A Romanian deadlift hinges at the hips
  with the knees only soft (thigh about 20° back, shin near vertical); a first
  pass with 50° of knee bend read as a squat, so keep that check when posing
  hinges. Variants of an existing pose (leg press from the wide leg press) copy
  the exercise dict and change only the slug, text and steps.

### Raouf: 2026-10-21 — Upper B demos

- `scripts/exercise-svg/upper_b.py` adds the reusable `draw_skeleton` (3D
  skeleton through any camera) and `torso_joints`; use them, with
  `dual_labels`, for any exercise where grip width or elbow path only shows
  from the front. Standing dual views use the smaller `STAND_*` cameras so
  the head clears the title.
- Do not duplicate demos across sets: `build.py` builds each exercise once,
  and the README names where a shared demo lives.

### Raouf: 2026-10-21 — Animated SVG exercise demonstrations

- `assets/exercise-svg/<set>/` holds one animated SVG per exercise (22 so far:
  upper-a, legs-a, core), built by `scripts/exercise-svg/build.py` from a 3D
  figure rig (`rig.py`) and per-set pose files (`exercises.py`, `legs.py`,
  `core.py`). Never hand-edit the SVGs; rebuild, and confirm the output is
  byte-identical to what is committed. Not wired into the app yet.
- Keep each exercise's draw order constant across frames (`render` asserts
  it); `keySplines` is not used, poses are sampled at 15 fps with linear
  interpolation. Overlays (fault outlines, timers, labels) take step indices.
- Review every new demo by rendering start, middle and end frames
  (Playwright `pauseAnimations` + `setCurrentTime`) in Chromium and WebKit,
  and update the set's `key-poses.png`. Follow the FORMA guide; where coaching
  sources give a safer cue, use it and say so in the README.
- Personal routine material (the Monday overview SVG/GIF) stays outside the
  public repo.

### Raouf: 2026-10-21 — Exercise demonstration clips and single-exercise card

- **Supersedes** the earlier same-day note that the demo slot is empty and no
  media was downloaded: the owner asked for the open-licence clips. 22 clips
  (9 CDC, 4 U.S. Army public domain; 9 FitnessScape CC BY 3.0) now play for 22
  exercises in the preview and in `ExerciseGuide`.
- Source of truth is `docs/research/exercise-videos/registry.json`; never edit
  `src/catalog/demos.json` by hand. Rebuild with
  `node scripts/build-exercise-demos.mjs <originals>` (FFmpeg with libx264;
  originals are not committed and must match the recorded SHA-1). A segment of
  a longer source names it in `original`. Only `formaIds` publish; `heldIds`
  are reviewed-but-uncertain and stay hidden. One clip per exercise, keyed by
  canonical guide ID (`guideExercise(id).id === id`); duplicates resolve to it.
- Publish a new clip only after frame review against the exact FORMA variant
  and its illustration (the leg-press artwork is a 45-degree sled, so the CDC
  seated selectorized clip is held). Keep per-clip credit, the CC BY change
  notice and the government no-endorsement notice. Self-host only; CSP
  `default-src 'self'` already covers `media-src`.
- Clips never autoplay (`preload="none"`, muted, loop, poster). `Modal`'s
  focus trap now lists `video[controls]`. The library guide may hold a video
  and credit links, so the trap test wraps with Shift+Tab first.
- An exercise name in `RoutineDetail` opens only that exercise's card
  (`single` state, title is the exercise name, `View <name>` label); **Preview
  workout** and the card menu open the carousel. `PreviewSlide` is the shared
  card.
- `keyboard-focus.spec.js:5` (account import focus) fails in WebKit on `main`
  too; it is not caused by this work.

### Raouf: 2026-10-21 — Routine preview and demo-video slot

- **Preview:** `src/components/RoutinePreview.jsx` is a non-rotating WAI-ARIA
  APG carousel (grouped style). Previous/Next use `aria-disabled`, not
  `disabled`, at the ends so focus stays on them; Playwright waits forever on
  `click()` of an `aria-disabled` button, so tests use `press("Enter")`. Only
  the short "Exercise N of total: name" line is live; do not make the whole
  slide `aria-live` (it would read the full guide on every step).
- Entry points: **Preview workout** in `RoutineDetail` (a mode inside the same
  `Modal`, so focus is moved by hand to **Back to overview** and back to the
  opener), each routine card's ⋯ menu (`detail` modal with `preview: 0`),
  exercise names in the overview, and a **Preview** button on each template
  (`TemplatePreview`, modal type `template-preview`). The template card button
  itself still adds the template; `tests/catalog.spec.js` relies on its
  accessible name starting with the template name.
- `GuideInstructions.jsx` now holds the lazy instruction loading and the
  source/licence credits for both `ExerciseGuide` and the preview. Keep
  attribution in that one place.
- **Videos:** owner asked for open 2026 demonstration videos. Research in
  `docs/research/exercise-videos.md`: rehostable public-domain/CC BY clips
  cover only about 2–5% of exercises; YMove's free grant conflicts with its
  terms; YouTube embeds need curation, CSP and a Privacy Policy update first.
  `ExerciseDemo.jsx` + `src/catalog/demos.json` is an empty slot. Add a clip
  only with a reviewed exact-variant match, recorded licence and author, and a
  self-hosted H.264 file; never hotlink or cache provider URLs. No media was
  downloaded and nothing was deployed.
- Firefox will not launch inside the agent shell sandbox ("Could not find
  profile folder"), even on untouched specs; that is environmental.

### Raouf: 2026-10-19 — Per-exercise ⋯ menu

- Mid-workout exercise actions live in each card's `ActionsMenu`
  (`src/components/ActionsMenu.jsx`); reuse it for any new ⋯ menu instead of
  a `<details>` dropdown. Items take `{ label, icon, onSelect, disabled,
danger }`; keep unavailable actions listed with `disabled`.
- Every action calls `focusCard(key)` after its update so focus returns to the
  card's ⋯ button; keep that when adding actions. Tests locate menus by
  `Options for <exercise name>` and items by `menuitem` role.
- `replaceEntry` keeps sets only when `setFields` match (which includes the
  per-side mode); use `setsLostByReplacing` before replacing.

### Raouf: 2026-10-19 — Workout and coach release deployment

- `~/.config/forma/production-deploy.env` names `DROPLET_USER=root`, and the
  key `~/.ssh/eoi_droplet_ed25519` is also accepted for root. Connect as
  `eoiadmin@$DROPLET_IP` and use `sudo`, per the earlier rule; only
  `DROPLET_IP` and `CLOUDFLARE_API_TOKEN` are needed from that file.
- `ops/Dockerfile` copies an explicit list of shared `src` files. A new
  import from `server/` into `src/` must be added there; CI now imports every
  server entry module inside the built image to catch a miss.
- Host backups: `cd /opt/forma-<env> && python3 operations/account-operations.py operations/config.json backup`
  (encrypted, signed, off-host). Each API container's compose files and env
  file are in its `com.docker.compose.project.*` labels.
- Both environments run `forma-api:workout-coach-20261019-98f853d` at schema 0006. Production Worker `a09aec75-…`, staging `27deb76c-…`. Record in
  `docs/qa/workout-coach/`.

### Raouf: 2026-10-19 — Full-access coach tokens

- **Supersedes** the 2026-10-18 rule that `/api/coach/workspace` "must never
  write": the owner asked for coach tokens with full read and edit access.
  Coach tokens now carry `scope` (`read` | `full`, migration
  `0006-coach-token-scope`). Existing and default tokens stay `read`; never
  widen a minted token in place.
- Bearer routes: `GET /api/coach/workspace`, `GET /api/coach/exercises` (any
  scope), `GET`/`PATCH /api/coach/workspace/data` (`full`). Keep them out of
  account, credential, session, token and deletion routes; a coach token must
  never reach `/api/account/*` or `/api/auth/*`.
- Coach edits go through `patchWorkspace` → `writeWorkspace` in
  `server/workspace.ts`, the same locked, revision-checked, idempotent path as
  `PUT /api/workspace`. Do not add a second write path. Each named section
  replaces the stored one; the merged result passes `workspaceDataSchema`.
  Dropping history needs `removesSessions` equal to the count removed.
- The coach `PATCH` is the only mutation that may arrive without the app
  `Origin` (Worker `bearerEdit` and server onRequest). It still refuses a
  foreign `Origin` and `Sec-Fetch-Site: cross-site`. Keep that exemption tied
  to that exact path, method and missing Origin.
- Budgets in `server/coachRoutes.ts`: 120 reads/hour (summary, data and
  exercises share it), 60 edits/hour per token, 20 failures/15 min per IP.
  Security events: `coach_scope_denied`, `coach_token_rate_limited`,
  `coach_workspace_write` (successful PATCH).
- Server tests register members by display name; names must be unique per
  file (`coach.test.ts` already uses Alpha–Delta). A repeated sign-up
  answers 200 without sending mail, by design.
- Local PostgreSQL 18 for server and account browser tests: start Docker
  Desktop, run the CI image (`postgres:18.4-alpine@sha256:9a8a…`) on
  `127.0.0.1:55432`, and set `TEST_DATABASE_URL` to it.

### Raouf: 2026-10-19 — Workout editing, set fill and left/right logging

- A per-side load/reps set stores `sides: { left, right }` and keeps `reps`
  as their total; `validSides` in `src/exerciseMetrics.js` enforces that on
  completed sets in the shared schema. Never store per-side reps in `reps`:
  volume, the coach API and history all read `reps` as the set total. Use
  `sideReps(set)` for strength estimates.
- Side logging follows the entry's `perSide` flag, not the catalogue directly:
  `defaultPerSide` turns it on for rows in `src/catalog/unilateral.json`
  (`id → arm | leg | side`) and `sideLabel` reads that label. Keep that file
  keyed by catalogue ID; `unit/workout-session.test.js` fails on unknown IDs.
  The review covered every catalogue row; a new import needs its new rows
  reviewed and added there, since `catalog:sync` does not touch it.
- Build session entries with `sessionEntry` / `addedEntry`
  (`src/workoutSession.js`), never by hand: they set `sides` and the fresh
  `entryId` that keeps duplicate exercises unique. `updateSetValue` holds the
  fill rule (later unfinished sets that still match the replaced value).
- `WorkoutEditor` commits each action through `onUpdate`; there is no draft.
  Removing an exercise with completed sets is a two-click confirm on the same
  button (`aria-label` changes), which the browser test relies on.
- Profile gains `fillSets` (default true). The API's strict parser accepts it,
  so deploy the API with or before the frontend.

### Raouf: 2026-10-18 — Dashboard deploy and branch links

- Deploy the operations dashboard with `npm run worker:deploy:dashboard`; it
  has no staging environment. It sits behind Cloudflare Access, so an anonymous
  check only proves the 302 to Access, not the page content.
- Link to repository files through `blob/main/`, never a feature or release
  branch: merged branches are deleted, and the links then 404.

### Raouf: 2026-10-18 — Sign-out release deployment

- The Droplet address and a Cloudflare management token are in the owner's
  local deploy env file outside the repository (ask the owner where). Source it
  inside commands; never print values.
  SSH is key-only as `eoiadmin` with `~/.ssh/eoi_droplet_ed25519`; do not use
  the password in that file.
- When piping a remote script into `sudo bash -s`, give every
  `docker compose run`/`exec` `< /dev/null`: otherwise it reads the rest of the
  script from stdin and the remaining steps silently never run.
- Release folders under `/opt/forma-*/releases` are root-only; run their steps
  inside one `sudo` shell. The ledger table is `forma_schema_migrations`.
- Staging and production both run `forma-api:signout-20261018-ea2dc4b` at
  schema 0005. Staging's `compose.small-host.yaml` and production's
  `compose.production-host.yaml` intentionally differ from the repository.

### Raouf: 2026-10-18 — Session sign-out step-up and sidebar menu

- `revoke-all` needs only a member session. `revoke-others` and single revoke
  use `confirmStepUp` in `server/app.ts`: a session under 5 minutes old, or
  `{ password, code? }` in the JSON body. Keep both checks on the
  `password-check` throttle key and `storeTotpUse` replay table, and never
  mutate the session or set cookies to satisfy step-up.
- Do not re-authenticate in the browser by calling `sign-in/email` while
  signed in: Better Auth's two-factor hook clears the current session cookie
  before the code step, which flips the app to guest mid-prompt.
- 403 bodies include `twoFactor` so the client knows to ask for a code.
  `accountApi` attaches it as `error.twoFactor`.
- `AccountWorkspace` remounts per account (keyed by user ID). App-wide state
  that must survive sign-in/out, such as toasts, belongs in `App` above it.
- Drag lift surfaces must not extend their box past the row: use a
  box-shadow spread for side bleed. Any wider box counts as scrollable overflow
  and trips `tests/responsive.spec.js` at 540px.
- Assert a specific status message with
  `getByRole("status").filter({ hasText })`: the app toast is also a status
  region and now survives sign-in/out.
- Account browser tests age sessions directly in the isolated
  `forma_browser_*` schema to simulate older sign-ins; they need
  PostgreSQL 18 (`RETURNING old.*` in the throttle).

### Raouf: 2026-10-18 — Coach tokens production deployment

- The production API host is the shared DigitalOcean Droplet (address in the
  owner's deploy env, not recorded here); SSH is key-only as `eoiadmin` then
  `sudo`. FORMA lives under
  `/opt/forma-production` (`.env`, `ops/`, `releases/<name>/`, `operations/`),
  Compose project `forma-production`, files `ops/compose.yaml` +
  `ops/compose.production-host.yaml`. The host has ~2 GB RAM: build the API
  image elsewhere for `linux/amd64`, `docker save | gzip`, transfer, verify the
  SHA-256, `docker load`. Keep each release's evidence in its `releases/` dir.
- Migrate with `IMAGE_TAG=<new> docker compose … --profile migrate run --rm
migrate` from the root-owned `ops/` directory (`sudo sh -c 'cd … && …'`),
  then install the current `ops/grant-runtime-access.sql` and run
  `ops/grant-runtime-access.sh` with the `.env` sourced, then set `IMAGE_TAG`
  in `.env` and `up -d --no-deps api`. The database admin role is
  `$POSTGRES_USER` inside the db container, not `postgres`.
- `scripts/deploy-public.mjs` works with a management token that only has
  "API Tokens Write" plus zone read; it mints and revokes the scoped deploy
  token itself. Keep the token in a mode-0600 file outside the repository and
  source it inside the command.
- Production and staging share the host; this release updated production
  only. Staging still runs `forma-api:routine-v2-20261017-cca9b07`.

### Raouf: 2026-10-18 — Read-only coach tokens

- **Scope:** owner asked for an API so an AI coach can read FORMA progress
  between conversations without sharing the account password.
- **Constraints added:** `/api/coach/workspace` is the only bearer-token route;
  it must never accept cookies, write, or return identity fields (email,
  member reference, revision, operation IDs). Keep the `Authorization` forward
  in the Worker scoped to that path. Tokens are digest-only in
  `member_coach_token`; never log or return a token after the create response.
  Minting is a fresh-session step-up like session revocation. Budgets live in
  `server/coachRoutes.ts`; change them with a test.
- **Verification:** `server/tests/coach.test.ts`, `coach-summary.test.ts` and
  `worker/tests/coach.test.ts`; see the changelog for the full run.

### Raouf: 2026-10-18 — Drag animation redeploy

- Owner asked for a redeploy of `57bd68d` and then to "do all yourself". With no
  `CLOUDFLARE_API_TOKEN` on this Mac, the frontend was deployed with the owner's
  existing Wrangler OAuth login (`wrangler deploy --env staging|production`,
  account `25c840ad…`). This is a one-off exception to the one-hour-token rule;
  prefer `npm run worker:deploy:staging` and `npm run worker:deploy:production` whenever a management token is available.
- On this host Node's fetch stalls on Cloudflare's API over IPv6 while curl is
  fine. Set `NODE_OPTIONS=--dns-result-order=ipv4first` for Wrangler, and run it
  outside the command sandbox. Wrangler needs `CLOUDFLARE_ACCOUNT_ID` because
  the login can see two accounts.
- A failed custom-domain trigger update after "Uploaded" still left the new
  version active; confirm with `wrangler deployments list` and live asset hashes.
- Production `64806558-cb0d-40dc-a029-3767586b456b`, staging
  `c299adb6-8e4d-4dcb-9e39-9e6a13eb5716`; live gateway checks match the
  previous record. API/database untouched.

### Raouf: 2026-10-17 — Drag animation for routine rows and cards

- Drag motion tokens (`--spring-lift`, `--spring-settle`, `--ease-standard`)
  live on `:root` and come from M3 Expressive springs. Reuse them for any new
  drag surface instead of new curves.
- Prescription rows must never scale: drag tests assert exact row positions
  and an identity transform after drop. Their lift lives on `::before`.
  Card lift scales the inner `.routine-card`; the Motion wrapper only
  translates.
- Card ordering uses `RoutineCardOrder.jsx` with Motion `layout` + 2D drag and
  offset-based hit-testing (`.routine-grid.full-grid` is positioned for this).
  `reorderRoutines` only permutes the visible ids within their existing slots;
  hidden/archived routines never move. Touch requires a 400 ms hold before
  dragging; keep native scrolling for quick swipes.
- Only the page toast may use `role="status"`: existing tests locate it with
  `getByRole("status")`. Extra announcers use plain `aria-live`.
- Known unrelated failures on this branch: 7 WebKit focus cases, one
  routine-library case, an intermittent empty-overview case. Firefox Nightly
  does not launch on this macOS host.

### Raouf: 2026-10-14 — Owner-authorised artwork redeployment

- Owner requested commit, push and redeploy after the completed artwork/site sweep.
  This supersedes the generation-phase no-deployment note below. Public accounts
  were already active: preserve account mode and existing gateway credentials.
- Both Workers received source `d292664`; final live verification found Cloudflare
  automatically injecting a beacon blocked by the existing CSP. HTML responses
  now append `no-transform` while preserving cache directives; scripts and API
  policies remain unchanged. Cloudflare documents this as preventing injection.
- All 21 Worker tests and live desktop/mobile checks pass. Final production is
  `20b4bb4a-e50a-4762-93aa-3a9746f0baa2`; staging is
  `e815bd37-68d7-483b-91b4-6bd292d5fa02`. Health 200, anonymous workspace 401,
  session null and staging Access 302 passed. Browser HTML has no beacon.
  No live member was created; four temporary deployment tokens were revoked.
  Logs and screenshots are in `docs/qa/site-sweep/deployment`.

### Raouf: 2026-10-14 — Full artwork coverage and whole-site sweep

- All 1,414 selectable exercises have reviewed original artwork. Strict coverage
  passed and checkpoint `0f8bc3c` was pushed before starting the site review.
- Owner requests a whole-site desktop/mobile sweep using current official
  documentation and original photos where needed. Evidence and final results
  belong in `docs/qa/site-sweep`; preserve sources, prompts and review decisions
  in `assets/site-visuals` and `docs/research/site-visuals`.
- Compact WebP previews must preserve reviewed atlas proportions; full guides
  retain original PNGs. Keep provenance in the original registry and verify
  runtime metadata and derivative hashes against it. Preview regeneration needs
  FFmpeg with libwebp; ordinary builds consume committed previews.
- Legal contents links transfer keyboard focus to headings and honor reduced
  motion. Account import retains its native file input with visible focus.
- Test service credentials are synthetic and stay in ignored local scratch.
  Account checks use disposable database schemas and an in-memory email sink;
  never redirect them to live member data. No deployment is authorized here.
- Ignore generated `work`, `test-results` and `playwright-report` folders in
  Vite's watcher. Trace HTML caused unwanted full reloads during integration
  tests. Concurrent test runners must use different output folders. Lint/docs
  checks exclude local scratch; ordinary application sources remain checked.
- Desktop/mobile photograph review fixed the phone detail-banner sprite sizing
  as well as the hero and routine crop positions. Recheck rendered crops if the
  background assets or responsive sizing change.
- Account form mode changes stay on the same route, so route focus alone is
  insufficient: focus the new registration/recovery/MFA heading and keep it
  visible. Preserve initial route focus and all account API methods. The focused
  regressions mock local responses; real-service journeys are separate checks.
- Prefer Playwright's matching browser builds. Record browser version, worker
  count and any budget overrides with results. Keep failed-run evidence; do not
  weaken saved-data assertions or performance bounds to hide cloud timeouts.
- Final verification: 62 unit cases; all 112 unique guest cases across the full
  run and exact failed-case replay; 18 isolated real-account journeys plus four
  mocked form-focus regressions; 40 production checks across Chromium, Firefox
  and WebKit. The final legal/import checks also pass, including phone headings
  below the sticky header. Lint, format, types, docs, build and strict 1,414
  artwork coverage pass. Evidence: `docs/qa/site-sweep/README.md`. No deployment.

### Raouf: 2026-10-14 — Cloud crash recovery and pushed checkpoints

- On resume, fetch origin and compare coverage before generating: the restored
  checkout can be behind already pushed assets and reviews. Recovered remote
  commit `8d0c5a7` contained 1,341 accepted matches.
- Owner explicitly requests frequent pushed checkpoints for original PNGs, full
  prompts, review decisions, coverage and recovery logs. Archive and push each
  completed generation/review batch; do not wait for full-library completion.
- Recovery retained new sources, integrated only previously pending reviewed IDs,
  and clarified source-backed guides without changing historical IDs or units.
- Progress and remaining work: `docs/research/original-art/recovery-state.json`.
  No artwork release is deployed during generation.

### Raouf: 2026-10-14 — Guide repair during artwork review

- Replaced the selectable roman-chair RDL's save-error placeholder with an
  authored secured-foot dumbbell hip-hinge guide and retained its ID and
  historical load/repetition units. Its earlier name remains searchable.
- Catalog admission now rejects that imported save-error boilerplate. The
  regression failed before the fix; all 61 unit cases passed afterward.
  The browsing scope remains 1,414 and compatibility scope remains 1,681.
- Original artwork generation/review and the subsequent whole-site review
  are still in progress. Do not deploy an incomplete media release.

### Raouf: 2026-10-14 — Original exercise artwork in progress

- **Scope:** owner now requests original AI-assisted FORMA illustrations for
  every selectable exercise. This supersedes mixed-source runtime media; retain
  earlier source research as evidence, not original-art coverage.
- **Review:** record each accepted/held atlas cell against the actual current
  guide; preserve equipment, support, grip and variation distinctions. Compatible
  machine/cardio apparatus references are allowed and must be labelled. Prompts
  and generated files alone never establish complete coverage.
- **Implementation:** local lazy thumbnails/guide imagery, proportion-preserving
  atlas views, finite image-error states, per-guide fingerprints and strict
  full-catalog coverage check. See `docs/research/original-art/README.md` and
  `coverage.json`. Original source images remain preserved.
- **Verification so far:** six focused Chromium catalog/media cases passed;
  60 unit cases, lint, formatting, type checking, docs and build passed.
  Actual source panel bounds now prevent uneven-row head clipping. Fifteen
  focused browser checks across three engines passed, including the crop
  regression. Generated sheets are archived in `assets/exercise-artwork` for
  recovery after session loss; pending artwork is excluded from runtime mappings.
  Generation and review are ongoing; no image release was deployed,
  and no account, database, API contract or logging units changed.

### Raouf: 2026-10-14 — Expanded photo search

- **Sources:** new research/inventory covers 25 YMove free demonstrations and
  12 inspected Commons files, plus commercial providers and specialist libraries.
  Twenty shortlist thumbnails were visually inspected; preferred candidates
  reference 10 distinct FORMA IDs. This is not deployed or approved coverage.
- **Matching:** hold the provider's Glute Kickback thumbnail showing a Standing
  Leg Curl station. Preserve front/behind-neck pulldown, forearm/high plank and
  ball-support distinctions; clarify two conflicting Commons licence records.
- **Network:** Commons image access recovered by supplying its required legitimate
  project User-Agent. Complete small thumbnails replaced a size-limited original
  probe. Do not bypass limits or repeatedly retry HTTP 429 responses.
- **Rights:** free-video use and standalone still/thumbnail rights are separate
  observations. Paid hosting/brand permissions depend on the agreement; no plan
  was purchased, provider contacted or media deployed for this research.

### Raouf: 2026-10-14 — Photo-source feasibility

- **Research:** `docs/research/exercise-photos.md` and its per-movement inventory
  cover all 1,414 selectable IDs. Identity-linked wger images cover 205 movements;
  106 have attributed, non-AI-flagged declared-photo candidates. These are
  metadata counts, not accepted photo coverage. No exercise images were deployed.
- **Constraint:** visually checked Photo-labelled assets included drawings and a
  weighted variation of a bodyweight guide. Match the actual movement and asset
  rights individually. Never infer photo rights/author from instruction metadata.
- **Provider:** current AscendAPI media URLs rotate weekly; caching/rehosting
  rights depend on the selected plan. Do not bundle rotating URLs or API keys.
- **Release:** current live versions and compatibility checks are recorded in
  `docs/research/catalog-quality.md`. The fan-bike note no longer exposes an
  internal ID; API identities and existing account data are unchanged.

### Raouf: 2026-10-14 — Catalog quality correction

- **Contract:** `exercises` and `exerciseById` retain every historical ID and
  metric; `selectableExercises` is the reviewed browsing/picker view. Never
  mutate saved IDs or reinterpret their units when consolidating synonyms.
- **Guides:** use `guideExercise` and its attributed `instructionId`. Original
  manufacturer-referenced guides have separate references; do not attribute
  authored text to a copied source. Archive unusable guides outside browsing.
- **Review:** 180 groups/240 duplicates; 15 new machine movements, six repaired
  guides and five corrected timed identities. There are 1,414 selectable and
  1,681 compatible records. Run `npm run catalog:curate` after source review.
- **Constraints:** machine inference requires reviewed machine equipment;
  barbell hack squats and butterfly/band movements remain distinct. Restore
  every cached alias prescription and its position on picker group toggles.
- **Verification:** 60 unit, 46 API, 20 Worker and 57 affected browser cases
  passed. All new IDs validate in the compiled Node 26 API. Deployment uses
  existing private projects/credentials, backups and bounded API containers;
  never reset accounts or change unrelated services for a catalog update.

### Raouf: 2026-10-12 — Red-team security hardening

- **Scope:** authorised red-team assessment and hardening of the account stack
  (API, Worker, frontend sync, database roles, ops, CI).
- **Summary:** 27 findings fixed (1 High, 11 Medium, 14 Low, 1 Info) with
  regression tests; security documentation added under `docs/security/`;
  verdict NO-GO for real members pending live infrastructure, restore and
  monitoring checks.
- **Files:** `server/app.ts`, `server/auth.ts`, `server/throttle.ts`,
  `server/workspace*.ts`, `server/migrations/0003-security-throttle.sql`,
  `worker/index.ts`, `src/storage.js`, `src/App.jsx`,
  `src/account/*`, `src/components/Account.jsx`, `ops/*`, `wrangler.jsonc`,
  `.github/*`, tests, `docs/security/*`.
- **Commits:** `6f26a09` (hardening), `2f8407c` (fixes from the second
  independent retest), followed by the documentation commit.
- **Verification:** see `docs/security/release-security-verdict.md`.
- **Follow-ups:** sign backups, breached-password blocklist, security alerting,
  live Access/Tunnel/Droplet checks, isolated restore drill, branch protection.

### Raouf: 2026-10-13 — Deployment

- **Scope:** public guest site and private account staging; see
  `docs/security/deployment-record.md`.
- **Constraints added:** the Worker forwards only `forma.*` cookies upstream;
  production must stay guest-only (no API secrets) until the verdict is GO;
  staging runs with `ops/compose.small-host.yaml` on a shared host, so never
  publish ports or raise memory limits without checking the other services.
- **Verification:** live gate probes S09, S10, S18 and a staging restore drill.

### Raouf: 2026-10-13 — Legal pages

- **Constraints added:** legal text lives only in `src/legal/content.js`; bump
  its version and effective date for material changes and give account holders
  14 days' notice of material Terms changes. Never add a liability cap that
  relies on ACL s 64A, an "as is" exclusion without the ACL savings clause, or
  unilateral change/termination without notice. New data collection, a new
  provider or country, analytics or ads require updating the Privacy Policy
  first (see `docs/legal/README.md`).

### Raouf: 2026-10-13 — Logs and memory

- **Summary:** changelog, deployment record and Zurvan memory updated for the
  deployment and legal pages. Redeploys use a freshly minted one-hour Cloudflare
  token that is revoked straight after; never keep long-lived deploy tokens.
- **Verification:** `npm run docs:check`; Zurvan index rebuilt.

### Raouf: 2026-10-13 — Catalog and public guest release

- **Scope:** latest upstream `5c826d7`, expanded exercise library and functional
  public guest controls. See `docs/research/runtime-catalog.md`.
- **Summary:** 1,661 sourced exercises, 12 additional templates, paginated
  alias search, on-demand licensed guides, and validated seconds/metres/carry
  logging. New guest profiles use `Guest`; the public account page opens real
  local profile, backup and history controls. Rest deadlines begin at the click.
  URL navigation uses a subscribed snapshot so startup hash changes are not missed.
- **Constraints:** preserve all 16 legacy IDs and the original plank units.
  Keep the 100-exercise session/routine and aggregate workspace bounds. Never
  count time/distance as kilogram volume or estimated 1RM. Imported content
  retains per-entry licence/author; do not import unreviewed image assets.
  Refreshes retain published supplemental IDs. The API Docker build must include
  the shared catalog and measurement helper. Update the staging API before its
  account frontend; the older API rejects new exercise IDs.
- **Infrastructure:** the published environment's unrestricted HTTP policy is
  enforced. Direct SSH is refused; the current Cloudflare client-side SSH method
  was verified through a temporary Service Auth gate with the stored key.
  Temporary credentials and routes are removed after maintenance. Do not export
  staging member data into the sandbox; take the release backup and perform the
  isolated restore check on the Droplet. Reusable startup instructions were saved.
- **Verification:** release evidence is recorded in `docs/live-catalog-release.md`.
  Source `d821632` is deployed to the public guest Worker and matching private
  staging API/frontend. Final browser matrices passed 40 guest and 45 member
  cases; live public and private probes passed. Unrelated container IDs were
  unchanged. Docker 29 reports the OCI manifest digest, not the sandbox's config
  digest: verify both from the transferred archive before activation.

### Raouf: 2026-10-13 — Public account activation

- **Scope:** owner-authorised launch of public accounts after the guest release.
  The release verdict is GO for controlled activation; see
  `docs/accounts/production-launch.md` for current evidence and limits.
- **Constraints:** production uses a separate project/database/roles/Tunnel/
  Access token/auth secret. Preserve unrelated host services. Production limits
  are 256 MiB API, 256 MiB database and 96 MiB connector; review capacity before
  changing them. Production deployment builds account assets intentionally.
- **Operations:** each environment has a private bucket with a bucket-only
  credential, encrypted and signed daily backups and a 34-day lifecycle rule.
  Restore archives only on authorised hosts into `forma_restore_` databases.
  Never export member rows to the sandbox. Recovery identities are wrapped to
  the owner's SSH key and kept off-host; rewrap before replacing that key.
- **Monitoring:** one-minute host timers plus an independent five-minute edge
  monitor. Logs contain fixed event names, correlation IDs and HMAC client keys,
  never request bodies, raw identities or auth links. Provider-wide audits remain
  operator dashboard checks. Operations email to the owner was explicitly approved.
- **Verification:** 46 server, 49 unit, 20 Worker, 4 Python operations and
  5 edge-monitor tests passed; 9 updated legal browser tests passed. A second
  recovery review required backup-time snapshot fingerprints, consistent recovery
  container selection and independent KV alert state; actual disaster drills passed.
  Public registration, owner-confirmed email receipt, verified sign-in, timed
  private saves, export and two-session persistence passed. Canary data was removed.

### Raouf: 2026-10-13 — Brand and journals

- **Scope:** original logo/loading animation, workout history polish and an
  owner-only read-only operations dashboard. Real pending states only; preserve
  stable control labels, reduced motion, auth contracts and measurement units.
- **Operations:** Access JWT validation accepts standard string/array audiences
  while requiring exact scope and signature. Workers supports manual/follow
  redirects; use manual and reject non-success responses. Dashboard records
  sanitized monitor state only; never give it member/database credentials.
- **Verification:** 258 development and 40 production guest cases passed; 40
  account cases and all five affected migration rechecks passed. Eighteen history
  cases passed across three engines. Live public/staging/dashboard checks passed;
  mobile overflow/page errors/axe violations were absent. Current operations
  checks are 6 Python and 8 Node tests.
- **Completed owner-authorised reset:** all FORMA production accounts and linked
  data removed after polish; nine tables verified empty. Production signing
  secret rotated with no MFA rows remaining. Staging and unrelated services
  unchanged. Public health/registration and private workspace denial passed;
  no new canary account was created. Backups retain the 34-day lifecycle.

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

### Raouf: 2026-10-29 — Prepare safe branch consolidation

- **Scope:** owner-authorized merge and cleanup of accumulated local/remote branches.
- **Summary:** preserved all 38 starting tips, combined the native work, release records, historical Watch audit and dependency updates. Resolved log conflicts without dropping entries; retained the narrow patched-Undici override for the new Miniflare version.
- **Files:** package manifest/lock, AGENT/CHANGELOG, historical audit annotations and `docs/maintenance/branch-consolidation-2026-10-29.md`.
- **Verification:** 151 unit, 35 Worker, 20 repeated WebKit journeys and 1,711 contract cases passed; static/build/resource/docs checks passed; OSV found no vulnerable lockfile packages. Combined remote CI and Native iOS CI remain separate gates.
- **Follow-ups:** merge validated integration, delete only main-contained branch tips with race checks, preserve all worktree files, and record final outcomes. No production deployment or Store action.

### Raouf: 2026-10-29 — Compile the motion resolver on older SDKs

- **Scope:** integration portability defect exposed by Native iOS CI on SDK 26.2.
- **Summary:** replaced the unavailable SwiftUI Cross-Fade environment key with UIKit's iOS 14 preference/notification at the root, initialized before first render and refreshed on foreground. Kept one resolver and existing Off/Minimal/accessibility priority.
- **Files:** `FormaMotion.swift`, hosted navigation regressions, Apple source register and consolidation record.
- **Verification:** 33 hosted app and four motion/navigation UI tests passed on local Xcode 27.1; strict Swift lint passed. Older-SDK CI rerun is still required.
- **Follow-ups:** finish combined CI/main merge and remaining branch cleanup. First safe cleanup removed 11 local/13 remote already-merged branches; worktree files and recovery refs retained. No deployment.

### Raouf: 2026-10-29 — Repair compact-phone integration journeys

- **Scope:** failures discovered while validating the all-branch consolidation on iPhone SE and the older CI SDK.
- **Summary:** keep Start above navigation at the largest accessibility size by placing metadata after it; reveal lazy account/history/profile controls; verify consent state explicitly; select the system widget provider row and leave Home-button editing correctly.
- **Files:** TodayView, account/history/navigation/widget UI journeys, Apple source register, consolidation record, AGENT and CHANGELOG.
- **Verification:** final compact account/history 5/5; preceding widget install/link, profile draft and largest-text geometry checks pass. Signed Release/widget bundle, strict Swift formatting, docs and added-line secret checks pass. Combined web/security CI at 5756291 passed, including 902 browser executions; final older-SDK CI remains the merge gate.
- **Follow-ups:** preserve all assertions and original branch ancestry; finish main merge/deletion only after final CI. Physical-device and distribution gates remain; no production deployment or Store action.

### Raouf: 2026-10-29 — Verify gallery launch and drag readiness

- **Scope:** the two remaining system/test setup failures in consolidation CI.
- **Summary:** activate the running test app through Home before widget discovery and check sharing remains enabled; wait for the real drag handle to be actionable before measuring raw pointer coordinates. Preserve all installation, routing, scroll and saved-data assertions with zero retries.
- **Files:** widget gallery UI test, routine drag test, Apple source register, consolidation record, AGENT and CHANGELOG.
- **Verification:** fresh compact simulator widget installation/link passes; 20 mobile WebKit repetitions and all 20 edge cases across five production browser/device projects pass. Lint, formatting, docs and added-line secret checks pass. Application/Watch/widget source is unchanged; final combined CI remains the merge gate.
- **Follow-ups:** merge and delete remaining branch refs only after final checks; retain all 38 original tips and existing physical-device/distribution gates.

### Raouf: 2026-10-29 — Budget both installed native runtimes

- **Scope:** measured native CI cancellation after the complete primary suite passed.
- **Summary:** increase the job limit from 35 to 65 minutes for the observed 26-minute primary build/test plus a second full iOS 26.0 suite. Keep all tests and runtime coverage enabled.
- **Files:** Native iOS workflow, consolidation record, AGENT and CHANGELOG.
- **Verification:** CI at 063abaa passed 33 hosted and all 25 UI tests on iOS 26.2, plus the protected widget check; GitHub confirmed the 35-minute job timeout during fallback. Workflow syntax/docs and secret checks pass; the rerun must establish the fallback result.
- **Follow-ups:** merge and retire remaining refs only after final validation; do not describe the interrupted fallback as a pass. Existing hardware/distribution gates remain.

### Raouf: 2026-10-29 — Isolate manual-password UI fixtures

- **Scope:** the sole remaining iOS 26.0 fallback failure in consolidation CI.
- **Summary:** configure the isolated simulator's AutoFill setting before the negative-password journey; assert it is off and retain every password-length and consent check. Keep production new-password support and prevent physical-device setting changes.
- **Files:** account UI test, Apple source register, consolidation record, AGENT and CHANGELOG.
- **Verification:** complete local signup journey passed in 92.947 seconds after switching suggestions from on to off; preceding sign-in/guest journeys passed. Strict Swift formatting, docs and added-line secret checks pass. Final combined CI remains the merge gate.
- **Follow-ups:** merge and retire remaining refs only after final checks; preserve all 38 starting tips, worktree files and physical-device/distribution gates. No production service or Store action.

### Raouf: 2026-10-29 — Handoff with native CI blocked

- **Scope:** preserve the branch consolidation work and document its unfinished validation.
- **Summary:** PR #34 remains open at `846a6fe`; main is not merged. The web/account/security run passed, while native CI still needs a clean full run. Eleven local and thirteen remote branch refs were retired in the earlier safe phase; remaining branch cleanup is pending. Original tips and worktree files are retained.
- **Defects and evidence:** native run 40800619323 attempt 1 passed 33 hosted and 25 UI tests on iOS 26.2, then stalled starting the iOS 26.0 test host and was cancelled at the 65-minute job limit. Attempt 2 passed 33 hosted tests but failed one of 25 primary UI tests: the Settings automation selected a non-interactive AUTOFILL heading at AccountExperienceTests.swift:168. The other 24 UI tests passed; fallback did not run. iOS 17 has not been verified on the hosted runner because its runtime was unavailable.
- **Fix under CI:** the Settings query now matches only rows (buttons or cells), never a same-titled section heading; password and consent assertions are unchanged. No iOS 26 simulator runtime is installed locally, so hosted native CI is the verification. Full logs and next steps are in the consolidation record.
- **Follow-ups:** validate the selector on both iOS 26.2 and 26.0, run full CI, then merge with ancestry preservation and execute guarded cleanup. Update the final records and Zurvan after actual completion. Current phone and Watch installation attempts were blocked by disconnected device services; no current installation success is claimed.

### Raouf: 2026-10-29 — Finish branch consolidation

- **Scope:** owner-authorized merge of PR #34 and retirement of every superseded branch.
- **Summary:** the Settings fixture now selects only rows (`50803a1`). Native CI passed on iOS 26.2 and 26.0 (33 hosted + 25 UI tests each) and application CI passed. PR #34 merged as `73f2e83`; main is the only remote branch and all 38 original tips have recovery refs.
- **Files:** account UI test, consolidation record, AGENT and CHANGELOG.
- **Verification:** guarded cleanup dry run, then execution: 17 local and 19 remote explicit deletions plus GitHub's automatic removal of the two Dependabot heads; main parity 0/0. iPhone Air Release install and launch succeeded.
- **Follow-ups:** the Watch install is blocked by RemotePairing 1035. The iOS 17 hosted runtime was unavailable. Physical privacy, accessibility and distribution gates remain.

### Raouf: 2026-10-29 — iOS UI/UX audit fixes

- **Scope:** native iPhone app, Apple Watch app and widgets. Six static audits (Today/Plan/Progress/You and shell, accounts, workout logging, visual system, Watch, widgets) produced 12 distinct High findings; all High and Medium findings, plus the low-risk Low findings, are fixed.
- **Summary:** rest ends reach a locked phone (screen kept awake during rest, local reminder in the background); the workout resumes on the first unfinished exercise; set errors appear on the set; dark-mode hold buttons are legible. Today and the widget offer the next routine in rotation, as the web does. Tab re-tap pops to root through value-based navigation paths, and labels stay at accessibility sizes. Forced sign-outs are explained and announced; a signed-out member can remove the saved copy, and a deleted account's synced copy is removed. Watch: separate controls page, Saving state, Paused text, minute-only Always On, Health permission checks, Retry save, disconnects and stale heart rate shown on the iPhone. Widgets: the privacy message stays readable, locked reads back off within the reload budget, labels match their destination. Design system: lime button edge (≥6:1 in light mode), boundary, radius, spacing and numeral tokens, account haptics, a 207 KB hero strip, and dark and tinted app icons. App and widget brand colours come from one `BrandPalette`.
- **Files:** `ios/FORMA` (App, Features, Account, DesignSystem, Resources), `ios/FORMAWatch`, `ios/FORMAWidgets`, `ios/WidgetPresentation`, `ios/Sources`, tests, `scripts/check-ios-widget-bundle.py`, Watch and privacy docs, AGENT and CHANGELOG.
- **Verification:** build-for-testing (app, Watch, widgets, all test targets) succeeds; `swift test` passes 144 core tests with 0 failures; 1711 Swift-generated workouts pass the web contract; resource check in sync; swift-format strict lint clean on changed files. New app-target tests run first in CI. Nothing has run on a simulator here, at the owner's request.
- **CI fixes:** the deletion-request ledger compares times in the unit it stores, so a request made this instant is no longer rejected as future-dated (failed on the iOS 26.0 run). The native job limit rises from 65 to 90 minutes: the iOS 26.2 run plus the iOS 26.0 rerun have taken up to an hour, and one run was cancelled at the limit.
- **Follow-ups:** device checks listed in the PR. Product decisions are not implemented: editing or deleting finished workouts, the fixed Sydney time zone and kg-only units, the system tab bar, syncing a Watch pause to the phone clock, the web keeping a running rest when a set is corrected, and Live Activities (see research).

### Raouf: 2026-10-30 — Workout Live Activity

- **Scope:** native iPhone Lock Screen, Dynamic Island, StandBy and (iOS 18+) Apple Watch Smart Stack/CarPlay `.small` presentation for an active workout.
- **Summary:** one `WorkoutLiveActivityController` follows the saved workspace from its single observer. It starts in the foreground when Live Activities are allowed and You › "Show workout on Lock Screen" is on (default on, local to this iPhone). It updates only when the mapped state changes (timers are system-rendered), and ends immediately on finish, discard, sign-out, account switch, reset, load failure or the switch turning off. On relaunch it adopts the matching activity and ends all others; a workspace that is still opening never ends it, and a swiped-away activity is not restarted for that workout. Lock Screen and Island show a neutral title, `privacySensitive` routine/exercise names, set position, elapsed time and the rest countdown, with Complete set and Skip rest buttons (`LiveActivityIntent`, unlock required, same engine path as the app, ignored for another session). The payload stays under 1 KB. No push tokens, notes, account data or Health metrics.
- **Files:** FORMASurfaces `WorkoutActivityState`; app controller, mapping, AppModel hook and preference, You toggle; WidgetPresentation attributes, views and intents; FORMAWidgets bundle; `NSSupportsLiveActivities`; widget bundle check; architecture, privacy and README docs; tests.
- **Verification:** build-for-testing succeeds with no function over ~0.23 s type-checking (no iOS 27-only API, for CI's iOS 26.2 SDK); `swift test` 144/144; docs and swift-format clean. Signed Release installed on the owner's iPhone Air. App-target tests compile and run first in CI.
- **Follow-ups:** physical checks: start, update and end on device, no leftover after discard, sign-out or force-quit, locked-screen redaction of names, landscape and two-activity Dynamic Island widths, StandBy, Watch Smart Stack next to FORMA's own Watch app, and both buttons from the Lock Screen.

### Raouf: 2026-10-30 — Tab bar motion, set row balance and workout toolbar

- **Scope:** native iPhone tab bar, active workout set rows and the active workout toolbar.
- **Summary:** each tab's symbol fills when chosen and plays its own SF Symbols effect: Today's sun turns (`rotate`, iOS 18), Plan's stack lifts layer by layer (`bounce.up.byLayer`), Progress's line draws itself (`drawOn` transition, SF Symbols 7 on iOS 26) and You waves (`wiggle`, iOS 18). Older systems bounce, and below full motion the symbols only change. The highlight slides on a new `tabSelection` spring (420 ms, bounce 0.28) with a selection haptic. Set rows are columns of caption over a 48 pt box: Set, the fields and a Done column whose complete button matches the fields' height and 10 pt radius, bottom-aligned, and the row now fills its card. On iOS 26 the toolbar is three Liquid Glass groups: a round close button (named "Save & close" for VoiceOver), the actions menu, and a prominent lime Finish set apart by a fixed `ToolbarSpacer`. Earlier systems keep the text buttons.
- **Files:** `ios/FORMA/DesignSystem/TrainingTabBar.swift`, `FormaMotion.swift`, `ios/FORMA/Features/WorkoutView.swift`, `ios/docs/commit-2/MOTION_SPEC.md`, AGENT and CHANGELOG.
- **Verification:** build-for-testing (app, Watch, widgets, all test targets) succeeds with no new slow type-checks and only SDK 26.x API behind availability checks; swift-format strict lint clean. Accessibility names and identifiers the UI tests use are unchanged. Nothing has run on a simulator here, at the owner's request.
- **Follow-ups:** check on device that each tab effect reads well in light and dark mode, and that the set row fits at large text sizes (it falls back to the stacked layout).

### Raouf: 2026-10-30 — Firmer tab haptics and a polished Progress chart

- **Scope:** native iPhone tab bar haptics and the Progress lifting-volume chart.
- **Summary:** changing tab now plays its own firm tap (`tabChanged`, solid impact at 0.85), stronger than the light selection tick it used before; tapping the selected tab to go back to its start plays a softer one (`tabReturned`, soft impact at 0.65). Both respect You › Haptics. The chart opens with a large readout of the latest workout's volume and a capsule showing the change from the workout before (arrow and whole percentage, never colour alone). Touching or dragging across the chart selects a bar: the readout follows it with a numeric roll between real totals, the touched bar is solid and the rest step back, and each new bar ticks the selection haptic. A dashed average line, slimmer rounded bars, dashed gridlines and compact axis values (1.2K) finish it. Bars still draw their real values at once and are never grown from zero; the value list stays for VoiceOver.
- **Files:** `ios/FORMA/DesignSystem/FormaHaptics.swift`, `TrainingTabBar.swift`, `ios/FORMA/Features/ProgressView.swift`, `ios/FORMAAppTests/FormaDesignSystemTests.swift`, AGENT and CHANGELOG.
- **Verification:** build-for-testing (app, Watch, widgets, all test targets) succeeds with no new slow type-checks; swift-format strict lint clean; a new app test pins the two tab haptics and keeps them distinct from account and set haptics. Nothing has run on a simulator here, at the owner's request.
- **Follow-ups:** feel both tab haptics on device, and check the chart readout and selection in light and dark mode with one, two and eight workouts.

### Raouf: 2026-10-30 — Tab bar collapse, page-end clearance and the Progress tab effect

- **Scope:** native iPhone floating tab bar on every tab and pushed screen, and the Progress tab symbol.
- **Summary:** verified on the owner's iPhone with an on-device UI probe (separate test storage) before and after. Three faults, each confirmed with measurements. (1) The bar never collapsed: `onScrollPhaseChange` stayed `idle` during drags on device, and the observer only acted while it reported dragging. The observer now follows position alone, and `TabBarScrollState` still ignores small moves and overscroll. (2) Pages ended under the bar: a `safeAreaInset` on the `TabView` never reached the tabs' scroll views, and a stack-level inset missed Today, which hides its navigation bar. The bar now floats as an overlay that reports its height, and every tab root and pushed screen keeps that height clear (`TrainingBarClearance`). On device, Today's last row ends 30 pt above the bar, where it used to be 32 pt under it. (3) The scroll limit subtracted `containerSize`, which already excludes the insets, so it counted them twice: the end of a page was never detected and the rubber-band settle re-opened the bar. The limit now uses `visibleRect`, which on Today gives 568 pt, matching the real maximum offset (it was 739). The Progress symbol's SF Symbols Draw On played nothing on device because the symbol has no drawing data. It now sweeps in left to right from a faint copy over 0.5 s, easing out, with a small lift, on every supported system.
- **Files:** `ios/FORMA/DesignSystem/TrainingTabBar.swift`, `ios/FORMA/App/FORMAApp.swift`, `ios/docs/commit-2/MOTION_SPEC.md`, AGENT and CHANGELOG.
- **Verification:** on device: collapses after one swipe and re-expands on a swipe down on Today, Plan and You. It stays collapsed at the end of the page. The last row of each page clears the bar. Device screenshots taken during a slowed sweep show it partly drawn, then complete. Build-for-testing succeeds and swift-format strict lint is clean. The probe test was removed afterwards.
- **Follow-ups:** none known; check Progress with real history once workouts exist.
### Raouf: 2026-10-30 — Website media and display font in the native app

- **Scope:** native iPhone technique guide and display typography.
- **Summary:** the guide now shows the website's media offline. Each of the 1,411 exercises with web media gets its cell of FORMA's illustration sheets (185 sheets, cropped off the main thread and cached). The 22 exercises with a web demo get the clip: its poster first, playing only when asked, muted, looping and mixed with other audio, with its author, licence, notice and source link. Editorial titles, the Today hero and the workout exercise name use the website's display face, Barlow Condensed Bold (SIL OFL; licence bundled), through `Font.custom(relativeTo:)`, so they scale with Dynamic Type; body text stays on the system font. `scripts/build-ios-media.py` generates everything from the web catalogues: the 1536×1024 PNG sheets become HEIC (322 MB to 15 MB, so no Background Assets download is needed), clips are copied, and the WOFF2 font becomes TTF. CI checks it with `--check`.
- **Files:** `scripts/build-ios-media.py`, `ios/FORMA/Media/` (generated), `ios/FORMA/Resources/Fonts/`, `ios/media-sources.json`, `ios/FORMA/Features/ExerciseMedia.swift`, `PlanView.swift` (GuideView), `FormaTheme.swift`, `TodayView.swift`, `WorkoutView.swift`, `ios/FORMA/Info.plist`, `ios/project.yml`, `.github/workflows/ios.yml`, `ios/FORMAAppTests/ExerciseMediaTests.swift`, `ios/README.md`, AGENT and CHANGELOG.
- **Verification:** `ExerciseMediaTests` (3) pass on the owner's iPhone: the index covers all web media, every file is bundled, a cell is cut at its catalogued size, and the font registers. An on-device UI probe showed the bench press and trap bar deadlift illustrations, the deadlift clip playing with its U.S. Army credit, and Barlow titles. The probe was removed afterwards. build-for-testing succeeds; swift-format strict lint and the media check are clean. App size grows by about 20 MB.
- **Follow-ups:** the 32 animated SVG demonstrations need a native rendering (render the "-still" frames, or record the animations to video). The website's hero and routine photos are not used yet. Add the font and demo sources to You › Exercise sources & licences.

### Raouf: 2026-10-30 — Website animations, photos and media credits in the native app

- **Scope:** native iPhone technique guide, Today, Plan, routine detail and You.
- **Summary:**
  - The website's 32 animated SVG demonstrations now play in the guide under "See the movement". iOS cannot play SMIL, so `scripts/render-ios-animations.mjs` records each one in headless Chromium, setting every frame to an exact time. That gives a silent H.264 loop at 30 fps (2.9 MB for all 32) and a still start pose.
  - The guide loops the video and shows the still when motion is reduced, with a Pause/Play control like the web's.
  - The website's photos are bundled as HEIC. The hero photo fills Today's next-session card; the old editorial art remains the fallback. The routine strip is cut into its three panels, positioned like the web's `.photo-N`, and shown on Plan rows and each routine's cover.
  - New You › Pictures, videos & font lists the FORMA originals, each demo source and licence, and the Barlow Condensed licence text.
- **Files:** `scripts/render-ios-animations.mjs`, `scripts/build-ios-media.py`, `ios/FORMA/Media/animations/`, `ios/FORMA/Media/photos/`, `ios/media-sources.json`, `ExerciseMedia.swift`, `PlanView.swift`, `TodayView.swift`, `YouView.swift`, `TrainingTabBar.swift` (`mediaCredits` route), `ExerciseMediaTests.swift`, `ios/README.md`, `ios/design/artwork-provenance.md`, AGENT and CHANGELOG.
- **Verification:**
  - `ExerciseMediaTests` (4) pass on the owner's iPhone, including every animation's video and still, and the photos with web-style index wrapping.
  - An on-device UI probe (removed afterwards) captured Today's hero photo, the routine photos on Plan and on the routine cover, two different frames of the bench press loop, and the credits screen.
  - build-for-testing succeeds; swift-format strict lint and the media check are clean.
- **Follow-ups:** none known.
