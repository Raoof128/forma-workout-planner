# Account database and workspace API

PostgreSQL on the private API host is the authoritative store for account
identity, sessions, and workout workspace data. Better Auth owns the identity
tables (`user`, `session`, `account`, and `twoFactor`). Migration `0002-workspace`
adds `member_workspace` and `member_workspace_operations`.

## Workspace ownership

`member_workspace` has one row per Better Auth user. Its text `owner_id` is both
the primary key and a foreign key to `"user"(id) ON DELETE CASCADE`. It stores
the validated version 2 FORMA data in JSONB, an authoritative PostgreSQL integer
revision, and a server-assigned timestamp. The JSONB keeps the existing FORMA
backup contract intact while the relational key provides a strict member
boundary. Starter routines are copied for new members; workout history remains
empty until the member records a workout.

Every query in the HTTP data layer includes the member ID resolved from the
Better Auth session. No request body or route parameter supplies a database
owner. This release does not rely on PostgreSQL row-level security; application
queries must preserve the owner filter. The browser has no database connection.

PUT uses a transaction and locks the member's row before comparing
`expectedRevision`. A successful update advances the revision exactly once and
sets `updated_at` to the greater of the database clock and the previous
timestamp plus one microsecond. Stale writes return the latest state with HTTP 409. There is no blind last-write-wins update.

## Idempotency records

The operation table is keyed by `(owner_id, operation_id)` and cascades with its
user. It stores a canonical payload hash plus the original acknowledgement's
revision and timestamp. The retried, validated payload reconstructs the exact
acknowledgement without storing a full copy of the workspace for every save.
The server retains at most 1,000 operations per member and removes records older
than 30 days during a write. A retry whose record has aged out cannot be
reapplied: its expected revision is stale and returns HTTP 409.

The complete request and response contract, including export and conflict
handling, is in [Member workspace API and conflict handling](../member-data-sync.md).

## Migrations and database roles

Run `npx tsx server/migrate.ts` with `DATABASE_URL` set to the migration role's
connection string. The runner takes a PostgreSQL advisory lock so two deploys
cannot apply the same migration simultaneously. It records SHA-256 checksums
and refuses to rerun a migration whose contents changed; schema changes must
be added as a new numbered SQL file. SQL migrations run in individual
transactions.

Use a separate runtime database role for the API. Grant it only the table
permissions required by Better Auth and workspace requests. Keep the migration
role credentials out of the running API environment. Restrict PostgreSQL to
private host access or a local Unix socket, and do not expose its port publicly.
Backups must include PostgreSQL data and be restored into an isolated database
to verify recovery.

## Workspace endpoints

- `GET /api/workspace`: authenticated `{data, revision, updatedAt}`.
- `PUT /api/workspace`: authenticated strict body `{data, expectedRevision, operationId}`.
- `GET /api/workspace/export`: authenticated validated workspace JSON attachment.

All workspace responses use `Cache-Control: private, no-store`. The API validates
the same data rules as the browser backup parser, including unique routine and
history IDs and the active workout/history ID constraint. Payloads are limited
to 20 MiB of workspace data. Account deletion goes through Better Auth; database
foreign-key cascades remove the member's workspace and operation records.
