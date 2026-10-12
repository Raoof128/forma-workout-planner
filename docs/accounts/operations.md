# Account service operations

This runbook describes the current repository configuration. It does not claim
that a production host, Cloudflare account, custom domain, email provider,
backup remote, or staging deployment has been configured.

### Current external-access blocker

Authorized Cloudflare and Droplet credentials were bound in the runtime for
read-only staging inventory. Cloudflare token verification succeeded, but the
Cloudflare accounts API returned HTTP 403 / error 9109 because the token is
location-restricted from this runtime; no account, zone, Worker, Tunnel, or
Access-app inventory was returned. Droplet SSH returned connection refused.
No external resources were created or changed. The sanitized probe result is
recorded at `/workspace/forma-private/cloudflare-inventory.json`.

## Local development and test services

Use Node.js 24 and npm from the lockfile. Install with `npm ci`. The isolated
account browser harness requires a disposable PostgreSQL database named by
`TEST_DATABASE_URL`; it creates a random schema, applies both SQL migrations,
starts a local API with an in-memory test email sink, then drops that schema on
shutdown. It refuses `NODE_ENV=production`.

```sh
export TEST_DATABASE_URL='postgres://test-role:password@127.0.0.1:5432/forma_test'
npm run test:server
npm run test:accounts -- --project=accounts-chromium
```

`npm run test:server`, `npm run test:accounts`, and `npm run test:accounts:production` use real PostgreSQL. The production browser target builds account assets and serves them through Vite preview; it does not exercise a deployed Worker. The
email sink in the tests is not a production mail integration. `npm run
test:worker` exercises the gateway handler with a fake upstream fetch function;
it does not establish a real Cloudflare Access, Tunnel, or Droplet connection.

For a local account UI connected to a separately running development API, set
the Vite development proxy target and its local-only shared secret:

```sh
FORMA_API_TARGET=http://127.0.0.1:3000 \
FORMA_DEV_WORKER_SECRET='local-only-value-at-least-32-characters' \
VITE_ACCOUNT_MODE=account npm run dev
```

The API expects `APP_ORIGIN`, `AUTH_SECRET`, `ORIGIN_SHARED_SECRET`, and
`DATABASE_URL`. Local test configuration is created by the isolated harness.
For offline guest mode, run `VITE_ACCOUNT_MODE=guest npm run dev`; this uses
browser storage and does not exercise the account API.

## Database preparation and migrations

The database service has no published port. In a private-host deployment,
PostgreSQL uses the internal Compose network and the API uses a separate
network for Tunnel egress. Run the role bootstrap as a database administrator
once per isolated environment, with a mode-0600 admin password file and
different 64-character lowercase-hex runtime and migration passwords:

```sh
export COMPOSE_PROJECT_NAME=forma-staging
export COMPOSE_ENV_FILE=/etc/forma/staging.env
set -a
. "$COMPOSE_ENV_FILE"
set +a
./ops/bootstrap-db-roles.sh
```

The migration role owns migration-created tables; the runtime role has
application table privileges. Keep `MIGRATION_DATABASE_URL` out of the API
container. Build and apply versioned SQL migrations with the separate one-shot
Compose service:

```sh
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" \
  -f ops/compose.yaml build api
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" \
  -f ops/compose.yaml --profile migrate run --rm migrate
```

The migration runner serializes concurrent invocations with a PostgreSQL
advisory lock and records a SHA-256 checksum for each applied migration. It
refuses changed applied SQL. Add a new numbered migration instead of editing an
applied one. The `api` and `db` services can then be started with the same
Compose project and environment file. The checked-in SQL and workspace behavior
are described in the [database reference](database.md).

## Cloudflare Worker and private API origin

`wrangler.jsonc` has separate staging and production environments, but their
committed `.invalid` origins are deliberate placeholders. Before deploying,
replace them with owned HTTPS origins and create DNS, Worker custom domains,
Cloudflare Tunnel and Access policy resources in the intended account.

The Worker accepts the explicit routes and methods in its allowlist, including `/api/health`, approved `/api/auth/*` endpoints, `/api/account/sessions` and its revocation routes, `/api/workspace`, and `/api/workspace/export`. Set `BACKEND_URL` to the fixed backend HTTPS origin
that resolves through the Tunnel and requires an Access Service Auth policy.
Configure the Cloudflare Access service token only on that origin policy. Store
the Worker secrets in Wrangler, separately for staging and production:

```sh
npx wrangler secret put ACCESS_CLIENT_ID --env staging
npx wrangler secret put ACCESS_CLIENT_SECRET --env staging
npx wrangler secret put FORMA_WORKER_SECRET --env staging
```

`FORMA_WORKER_SECRET` must equal the API's `ORIGIN_SHARED_SECRET`; the Access
Client ID and secret are separate credentials. The gateway strips caller
versions of all service and forwarding headers before attaching its own. Do
not place these values in `wrangler.jsonc`, `.env` files copied into Vite, or
the browser bundle. Configure distinct values for staging and production.

Configure the Tunnel route to send the protected backend hostname to
`http://api:3000` on the Compose tunnel network. The Tunnel connector makes
outbound connections; the Droplet/API does not need a public inbound port. A
VPC-only Droplet still needs an outbound route, commonly a VPC NAT gateway, for
Tunnel, security updates, approved package retrieval, and transactional email.
Confirm current DigitalOcean procedures directly before creating those cloud
resources; the official pages could not be retrieved in this environment.

```sh
npm run build
npx wrangler deploy --env staging
```

These commands can deploy only after actual origins and required Worker secrets
are configured. This repository's current `.invalid` hostnames are not
deployable. See the [infrastructure guide](../accounts-infrastructure.md) for
the request boundary and confirmed local Worker checks.

## Environment variables

`[.env.example](../../.env.example)` lists backend, email, database-role,
Tunnel-token-file, and backup settings. Keep the production file outside the
repository, readable only to the service operator, and separate each
environment. Worker `ACCESS_CLIENT_ID`, `ACCESS_CLIENT_SECRET`, and
`FORMA_WORKER_SECRET` are Wrangler secret bindings, not backend env vars.

| Name                                       | Component            | Purpose                                                                                              |
| ------------------------------------------ | -------------------- | ---------------------------------------------------------------------------------------------------- |
| `APP_ORIGIN`                               | API                  | Exact allowed public app origin and Better Auth base URL.                                            |
| `AUTH_SECRET`                              | API                  | Better Auth cryptographic secret and opaque session-reference HMAC key.                              |
| `ORIGIN_SHARED_SECRET`                     | API                  | Worker-to-origin shared service credential; matches `FORMA_WORKER_SECRET`.                           |
| `DATABASE_URL`                             | API                  | Runtime PostgreSQL role.                                                                             |
| `MIGRATION_DATABASE_URL`                   | Migration service    | Separate schema-owner role.                                                                          |
| `EMAIL_FROM`, `RESEND_API_KEY`             | API                  | Verified transactional mail sender and provider key. Production config rejects the local email sink. |
| `POSTGRES_ADMIN_PASSWORD_FILE`             | Compose DB bootstrap | Protected file consumed by the PostgreSQL container.                                                 |
| `CLOUDFLARE_TUNNEL_TOKEN_FILE`             | cloudflared          | Protected connector token file.                                                                      |
| `ACCESS_CLIENT_ID`, `ACCESS_CLIENT_SECRET` | Worker               | Access service token for the origin policy.                                                          |
| `FORMA_WORKER_SECRET`                      | Worker               | Shared origin credential; separate from Access token.                                                |
| `BACKUP_AGE_RECIPIENT`, `BACKUP_REMOTE`    | Backup operator      | Encryption recipient and access-controlled `rclone` destination.                                     |

## Backups, restore, and incident handling

Use [the infrastructure runbook](../accounts-infrastructure.md#encrypted-backup-and-isolated-restore)
for the exact tested-script behavior and prerequisites. `ops/backup-postgres.sh`
streams `pg_dump` through `age` and uploads the encrypted archive plus SHA-256
sidecar with `rclone`; it does not write a plaintext dump to disk or prune old
backups. `ops/restore-postgres.sh` verifies the sidecar, decrypts into
`pg_restore`, and refuses any target database whose name does not start
`forma_restore_`.

A local isolated PostgreSQL 18.4 backup/restore drill passed: custom pg_dump, age encryption/decryption, restoration into a separate database, exact workspace comparison, and corrupt-ciphertext rejection. See [the recorded evidence](backup-restore-evidence.json). No off-host upload or operational scheduler was tested. Provision off-host storage, schedule the
backup script, alert on missing uploads, protect the decryption identity
separately from the host and backup remote, and run an isolated restore drill
before using this procedure for recovery. A live database backup or Droplet
snapshot must not be treated as a completed restore test.
