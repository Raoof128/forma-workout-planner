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
