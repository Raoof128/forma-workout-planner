# Changelog

Notable changes are recorded here. Dates use Australia/Sydney. No versioned release tags have been published by this documentation update.

## Unreleased

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
