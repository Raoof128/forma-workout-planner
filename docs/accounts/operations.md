# Account service operations

Public accounts, separate private staging/production backends, encrypted remote
backups and monitoring are deployed. See the [current launch record](production-launch.md)
for verified versions, recovery evidence and operating limits. Earlier setup
constraints below are historical; Cloudflare Access SSH now provides maintenance
access without changing unrelated backends.

### Historical external-access blockers

The four original infrastructure bindings are present in the runtime and match
the supplied `.env`. The owner subsequently supplied a burner SSH key and
explicitly requested a local environment file. `/workspace/.env`, outside this
repository, now contains those bindings plus `DROPLET_SSH_USER=eoiadmin`,
`DROPLET_SSH_PORT=22`, and the multiline `DROPLET_SSH_PRIVATE_KEY`, with mode
0600. OpenSSH parsed the key and its fingerprint matched the owner's reference.
This local file is not evidence that the platform imported the key into its
managed secret store. Do not copy it into Git, a Docker build context, or Vite.

A read-only SSH attempt with the supplied key and normal process permissions
still returned connection refused before authentication. The owner reports the
same host is reachable from their Mac on port 22; no alternate port or bastion
exists. This establishes an environment-specific connectivity blocker, without
proving whether outbound policy or a DigitalOcean cloud firewall causes it.
The supplied password is documented for the DigitalOcean web console only.
Do not enable password SSH or change unrelated host services to work around it.

Cloudflare Worker, Tunnel, Access-app and DNS inventory reads succeeded in the
selected account. Existing `persiancommons.com` mail settings were preserved.

Cloudflare enabled `mail-staging-forma.raoufabedini.dev` and created its six
provider-required DNS records, all matching the provider configuration. No apex
DNS, existing mail routing, unrelated backend, or paid plan was changed. All
temporary provisioning tokens were revoked; the dedicated account-scoped Email
Sending Read/Write token remains in the protected local `.env`.

On 12 October 2026, the owner-authorized single template test received HTTP 200
with `success=true`, the controlled recipient in `queued`, no permanent bounce,
and no provider errors. The subject is `[FORMA STAGING DELIVERY TEST] Approved
email template`; no account was created and its link cannot verify an account.
This establishes provider acceptance, not inbox receipt. Gmail access is not
available through this session's tools. See [domain evidence](email-domain-onboarding.json)
and [mail acceptance evidence](mail-delivery-test.json). A hosted application
lifecycle, public DNS verification and actual inbox receipt remain unverified.

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
./ops/grant-runtime-access.sh
```

Grant runtime access after migrations, before starting the API. The grant script
allows application-table DML and excludes the migration ledger and schema DDL.
The isolated [runtime-role evidence](runtime-role-evidence.json) verifies these
boundaries against PostgreSQL; it does not establish live staging privileges.

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

Read-only discovery on 2026-10-12 confirmed these candidate staging names are
unused in the owner's `raoufabedini.dev` zone:

- Application: `staging-forma.raoufabedini.dev`.
- Protected origin: `api-staging-forma.raoufabedini.dev`.

Use a new `forma-staging` Worker, a dedicated Tunnel, a separate Access
application with a Service Auth policy and token, and DNS records limited to
these two names. Recheck absence immediately before creating them. Do not
reuse or change existing applications, hostnames, credentials, databases,
firewalls, or tunnels. Resource read access succeeded for this account, but
write permission has not been exercised. Workers subdomain lookup returned
403; a `workers.dev` address is therefore not established. No resources were
created while host connectivity and production email configuration remain
unavailable. Provision the isolated backend and verify the protected origin
before publishing the public application.

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

## Cloudflare transactional email

Cloudflare Email Service Email Sending is in Beta as of the source review on
12 October 2026. Sending to arbitrary new members requires Workers Paid and an
onboarded sending domain; classic Email Routing's verified-destination sending
is insufficient for account registration. The official price lists 3,000
messages per account/month included, then $0.35 per 1,000; check the current
account plan and daily reputation-based limits before activation.

The isolated `mail-staging-forma.raoufabedini.dev` subdomain is now configured, with sender
`FORMA <accounts@mail-staging-forma.raoufabedini.dev>`. Onboard that exact
subdomain in Email Service when reproducing setup and obtain its generated DNS records. Inspect and
add only its own bounce MX/SPF, DKIM and DMARC records; never replace apex mail
records or the existing `persiancommons.com` sender setup. Verify records and
sending status before enabling auth email. Do not invent DKIM keys or reuse
another application's credentials. Cloudflare does not document per-domain
token scoping here, so review the account-wide capability before binding a
new sending token to a shared host.

Set `CLOUDFLARE_ACCOUNT_ID`, a dedicated `CLOUDFLARE_EMAIL_API_TOKEN` with
Email Sending Read/Write, and the onboarded `EMAIL_FROM` only on the API runtime.
Do not reuse the broad infrastructure token as the application mail token.
The backend calls the fixed Cloudflare REST endpoint over HTTPS and sends
branded HTML plus a plaintext alternative. Treat a queued response as accepted
for delivery, not proof of inbox delivery; verify actual receipt with a
controlled staging member and test provider rejection/bounce handling.
The four account email actions are verification, password reset, email-change
approval, and deletion confirmation. Template previews use synthetic links;
they do not prove rendering in every email client or real provider delivery.

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
| `EMAIL_FROM`, `CLOUDFLARE_EMAIL_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | API | Onboarded transactional sender, dedicated Email Sending: Edit token, and account ID. Production rejects the local email sink. |
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
