# Changelog

Notable changes are recorded here. Dates use Australia/Sydney. No versioned release tags have been published by this documentation update.

## Unreleased

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
