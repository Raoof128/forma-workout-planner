# Changelog

Notable changes are recorded here. Dates use Australia/Sydney. No versioned release tags have been published by this documentation update.

## Unreleased

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
