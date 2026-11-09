# Change summary

Branch `claude/practical-planck-xi0wq2`.

- **Not deployed.**
- **No schema migration.** No applied migration was edited.
- **No `src/storage.js` or catalogue change.** No iOS source change.

## What changed, by file

- `server/app.ts`:
  - `/readyz`;
  - `503` for session-store failures;
  - `requestTimeout`;
  - throttle refund on handler failure;
  - fixed-label failure logs;
  - class-and-code 5xx logs;
  - origin-side cross-site coach refusal;
  - `session_data` withheld on 2FA replay;
  - credential cleanup on change-password, `revoke-sessions` and `revoke-all`;
  - mail-budget refund;
  - prune sampling.
- `server/auth.ts`:
  - `revokeCredentialArtifacts`;
  - background auth mail in production;
  - a one-hour deletion link;
  - `afterDelete` verification cleanup.
- `server/throttle.ts`: `refundBudget`; single-flight batched
  `pruneExpiredAuthRows`.
- `server/config.ts`: refuses placeholder, reused and low-entropy secrets, and
  HTTPS origins outside production.
- `server/index.ts`: pool-size validation, bounded shutdown, start-up errors
  that name the setting.
- `server/schema.ts`: the real invariant message for validation failures;
  `removesActive`.
- `server/workspace.ts`:
  - the canonical fingerprint with legacy fallback;
  - the lazy starter;
  - broken-connection release;
  - the write guard;
  - active-workout confirmation;
  - `exportWorkspace`.
- `server/workspaceRoutes.ts`: raw export.
- `server/migrate.ts`: bounded lock waits, `lock_timeout`, ledger checks, and
  injectable options for tests.
- `server/coachTokens.ts`, `server/coachRoutes.ts`:
  - the in-transaction token check;
  - mint and member write budgets;
  - throttled `last_used_at`;
  - the `active_removal_unconfirmed` mapping.
- `worker/index.ts`, `wrangler.jsonc`: the gateway items B-15 and B-16.
- `ops/account-operations.py`, `ops/edge-monitor.mjs`,
  `ops/restore-postgres.sh`: the `/readyz` probe, timeout-safe probes,
  persisted alert state, tunnel judgement, and the restore target check.
- `src/components/Account.jsx`: the sign-out-everywhere confirmation explains
  the coach-token and trusted-device revocation.
- `scripts/bench-workspace.ts`: a reproducible persistence benchmark for
  disposable databases.
- Tests:
  - `server/tests/backend-hardening.test.ts` (13 cases),
    `auth-hardening.test.ts` (7) and `coach-hardening.test.ts` (5), plus
    `worker/tests/hardening.test.ts` (8);
  - new cases in `ops/test_operations.py` and `ops/edge-monitor.test.mjs`;
  - the schema fixtures in the `auth`, `redteam`, `security` and
    `server-lifecycle` tests now include migrations 0005 and 0006, as
    production does;
  - `email.test.ts` uses random-looking synthetic production secrets;
  - the Worker red-team fixtures send a session cookie (EDGE-01) and
    `Sec-Fetch-Mode: navigate` (EDGE-06), as real clients do. No assertion
    was weakened.
- Docs: `docs/accounts/api.md`, `docs/security/authentication.md`,
  `CLAUDE.md`, `AGENT.md`, `CHANGELOG.md` and this folder.

## Release

This is an **API image release and a Worker release**, staging before
production, following the API release recipe in `CLAUDE.md`. Owner approval is
needed for each deploy.

Before migrating, run these read-only checks on each host:

1. `SELECT name FROM forma_schema_migrations ORDER BY name` lists only
   `0001`–`0006` with today's file names.
2. The host `.env` secrets are not placeholders, and `AUTH_SECRET` differs from
   `ORIGIN_SHARED_SECRET`. Otherwise the new API refuses to start, and the old
   container keeps running.
3. `NODE_ENV=production` is set (Compose already sets it).

Order:

1. Back up.
2. Release the API, and confirm `/readyz` answers 200 inside the network.
3. Install the updated `ops/account-operations.py` and check the next monitor
   run reports healthy.
4. Deploy the Worker.

There is no migration step.

**Rollback:** the previous API image is data-compatible. An in-flight save
retried across the rollback may receive `409 operation_id_reused` (D-14 in
BACKEND_AUDIT.md). No data is lost; the client reloads and the member saves
again.

## Behaviour changes to tell people about

- **Credential cleanup.** "Sign out everywhere", a password change and a
  password reset now also revoke coach tokens and trusted devices.
- **Coach tool limits.** A tool must send `removesActive: true` to discard an
  unfinished workout. Minting is limited to 10 per hour and writes to 120 per
  hour per member.
- **Silent mail failures.** Auth mail failures no longer return an error to
  the requester. The member can use "Resend".
