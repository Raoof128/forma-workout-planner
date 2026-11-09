# Database review

PostgreSQL 18.4 is the only supported engine (`RETURNING old.*` is used in
`server/throttle.ts`). All findings were checked with real PostgreSQL in
throwaway schemas or databases. No schema migration was added in this pass,
and none of the applied migrations `0001`–`0006` was edited.

## Integrity guarantees re-verified

- **Owner scoping.** Every workspace, operation and coach-token query filters
  by the owner from the session or token row.
- **Single write path.** A member `PUT` and a coach `PATCH` both go through
  `writeWorkspace`, which runs in this order:
  1. take the row lock (`FOR UPDATE`);
  2. replay the operation, if it was seen before;
  3. check the revision;
  4. write.

  Under READ COMMITTED, the single-row lock plus the revision check rules
  out lost updates.

- **First write.** It uses `INSERT … ON CONFLICT DO NOTHING`, then a locked
  re-read, so concurrent first writes serialise without unique-violation 500s.
- **Idempotency.** Keys are `(owner_id, operation_id)`. A replay must match
  the fingerprint, and the same ID with a different body is
  `409 operation_id_reused`. Retention is bounded at 1,000 operations or 30
  days per member and runs under that member's row lock.

## Changes

| Change                                                                                                                                                                   | Why                                                                                                                                                                                                                                                                            | Compatibility                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Member-save fingerprint = SHA-256 of `"v2:"` + JSON of the canonical parsed save; the legacy sorted-key hash is still accepted                                           | The recursive key sort cost about 23 ms per 400 KB save, more than validation (18 ms). zod 4 rebuilds every object in schema order and `dataSchema` has no record or passthrough types, so the parsed JSON is canonical. A test with keys reversed at every level confirms it. | Ledger rows written before the upgrade still replay (tested). Rolling back to an older image turns a retry of a newer operation into `409` (D-14 in BACKEND_AUDIT.md). No data is lost.                                                            |
| Lock the existing row first; build the starter workspace only when it is missing                                                                                         | The starter (fresh data, validated, serialised) was built on every save.                                                                                                                                                                                                       | Same transaction and lock semantics.                                                                                                                                                                                                               |
| `client.release(true)` when `ROLLBACK` itself fails                                                                                                                      | A broken connection was returned to the pool.                                                                                                                                                                                                                                  | None.                                                                                                                                                                                                                                              |
| Raw export                                                                                                                                                               | A stricter future validator must not block a member's backup.                                                                                                                                                                                                                  | The bytes are the stored workspace. Both clients validate on import.                                                                                                                                                                               |
| Coach `removesActive`                                                                                                                                                    | Protects an unfinished workout from tool edits.                                                                                                                                                                                                                                | Additive optional field. A coach edit that discards the active workout now needs it.                                                                                                                                                               |
| Migration runner: bounded advisory-lock wait, `SET LOCAL lock_timeout` (default `5s`, `MIGRATION_LOCK_TIMEOUT`), refusal of missing or misordered files                  | A queued DDL lock blocks every later query, so the runtime role's `lock_timeout` turned that into member 500s.                                                                                                                                                                 | Before the next migration, run a read-only `SELECT name FROM forma_schema_migrations ORDER BY name` on each host and confirm it lists only `0001`–`0006`, as shipped. The renumbered `0004-coach-tokens.sql` was never applied (commit `189ad70`). |
| Batched, single-flight pruning of expired sessions (expired more than 1 day), expired verification rows, and coach tokens past expiry or revocation by more than 30 days | These tables grew without bound.                                                                                                                                                                                                                                               | Deletes only rows that can no longer authenticate. 1,000 rows per statement with `SKIP LOCKED`.                                                                                                                                                    |

## Grants

The runtime role already has `SELECT`, `INSERT`, `UPDATE` and `DELETE` on all
ten tables (`ops/grant-runtime-access.sql`). The new statements need no new
grant. Narrowing the grants per table (D-04) is deferred, because it needs an
owner-run host change and a restricted-role test harness.

## Not measured

The operation-retention `DELETE` plan at production scale (D-10). The
benchmark in PERFORMANCE.md exercises it at 40 members × about 12 operations,
which is far below 1,000 operations per member, so it gives no evidence about
an index.
