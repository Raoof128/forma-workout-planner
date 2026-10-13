# Changelog

Notable changes are recorded here. Dates use Australia/Sydney. No versioned release tags have been published by this documentation update.

## Unreleased

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
