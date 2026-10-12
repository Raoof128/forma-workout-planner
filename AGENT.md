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
