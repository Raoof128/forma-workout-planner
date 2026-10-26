# Database security

[Back to security overview](README.md)

See also [account database notes](../accounts/database.md).

## Roles

`ops/bootstrap-db-roles.sql` and `ops/grant-runtime-access.sql` were executed
against PostgreSQL 18.4 during the engagement, followed by migrations as
`forma_migrator` and a full sign-up, sign-in, workspace read and write as
`forma_runtime`.

| Check as `forma_runtime`                                    | Result             |
| ----------------------------------------------------------- | ------------------ |
| Superuser, CREATEROLE, CREATEDB, BYPASSRLS                  | All false          |
| Connection limit                                            | 40                 |
| `statement_timeout` / `lock_timeout` / idle in transaction  | 15 s / 10 s / 30 s |
| `CREATE TABLE` in `public`, `CREATE TEMP TABLE`             | Denied             |
| `TRUNCATE`, `ALTER TABLE`                                   | Denied             |
| `pg_read_file`, `COPY ... TO PROGRAM`                       | Denied             |
| Read `forma_schema_migrations`                              | Denied             |
| Connect to the `postgres` database                          | Denied             |
| DML on the nine application tables and `security_throttle`  | Allowed (required) |

Migrations run as `forma_migrator`, which owns the schema. The runtime role
cannot change schema.

## Isolation and integrity

- Every member table is keyed by `owner_id` (or `"userId"`) with
  `ON DELETE CASCADE` from `"user"`.
- `member_workspace` checks that `data` is an object, `version` is 2 (since migration 0004) and the
  JSON revision equals the column revision.
- Writes use `SELECT ... FOR UPDATE`, compare-and-swap on `revision`, and an
  idempotency table keyed by `(owner_id, operation_id)` with a request hash.
  Concurrent tests produced exactly one winner and no lost acknowledged write.
- All queries are parameterised. Row-level security is not used; isolation is
  enforced by the API and by owner keys.
- `security_throttle` stores only HMAC digests of emails and member IDs.
- `member_coach_token` stores only an HMAC digest of each coach token, with
  its scope, expiry and revocation timestamps; rows cascade with the user.

## Backups

The deployed `ops/account-operations.py` workflow encrypts custom-format dumps
with `age`, signs manifests with Ed25519 and verifies backup-time fingerprints
during isolated restore. The [13 October launch record](../accounts/production-launch.md)
records off-host recovery checks and scheduling. The separate manual
`ops/backup-postgres.sh` helper uploads an encrypted archive with a SHA-256 file
and does not provide the signed-manifest workflow.

The following findings describe the original 12 October assessment. R-01 and
R-17 were addressed for the deployed workflow in the launch record; the broad
backup-role privilege in R-02 remains an explicit operational tradeoff:

| ID   | Item                                                                                                                                                                                                                                        | Severity |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| R-01 | Archives are not signed. The checksum sits beside the archive, so anyone who can write the remote can replace both. Sign with an offline key (minisign or `ssh-keygen -Y sign`), verify before decrypting, and use append-only credentials. | Medium   |
| R-02 | Backups run as the bootstrap superuser. Use a role with `pg_read_all_data`. Restore as a non-superuser.                                                                                                                                     | Low      |
| R-17 | No isolated restore has been executed against a real off-host archive (gate S14 BLOCKED). A Droplet snapshot is not a tested restore.                                                                                                       | Medium   |

After any restore, re-run `ops/grant-runtime-access.sh`, because dumps are taken
with `--no-owner --no-privileges`.
