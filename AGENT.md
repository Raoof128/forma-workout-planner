# Agent notes

Branch consolidation on 13 October 2026 uses main as the repository's confirmed
default branch. The Node 26 Docker base and action releases are pinned. ESLint
stays at 9.39.5 until the React/accessibility plugins declare ESLint 10 support;
the attempted upgrade fails normal `npm ci`. Preserve peer checks.

`.gitleaksignore` contains one exact historical fingerprint for the public
Cloudflare Access audience in dashboard configuration. It grants no access;
signature, issuer and owner validation are still mandatory. Do not replace this
with a general path/rule allowlist or add exceptions for credential material.

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
