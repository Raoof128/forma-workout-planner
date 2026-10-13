# Agent notes

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
