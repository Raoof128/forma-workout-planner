# FORMA account infrastructure

This document describes the implemented deployment boundary for the account API. The Worker serves the Vite build and owns the only browser-facing `/api/*` route. The Node API and PostgreSQL run on a private Droplet; Cloudflare Tunnel is outbound-only, and Cloudflare Access requires a service token on the backend hostname. PostgreSQL has no published container port and is on a separate internal Compose network.

```text
Browser ── HTTPS ──> Cloudflare Worker + static assets
                         │ fixed HTTPS origin, Access service token,
                         │ FORMA worker secret
                         ▼
                Cloudflare Access protected hostname
                         │ Cloudflare Tunnel
                         ▼
                 cloudflared ──> Node API ──> PostgreSQL
                                  tunnel net     internal DB net
```

The Access token authenticates the Worker to the protected origin. `FORMA_WORKER_SECRET` / backend `ORIGIN_SHARED_SECRET` is a second, independent shared service credential. Neither credential represents a member. The API still authenticates each account cookie and applies member ownership checks.

## Worker gateway contract

[wrangler.jsonc](../wrangler.jsonc) deploys `worker/index.ts` with the Vite `dist` assets. The Worker runs first for requests and then uses its static-asset binding to serve files; all static responses receive CSP, HSTS on HTTPS, frame, MIME-sniffing, referrer and permissions headers. Unknown API paths return JSON 404 responses and cannot receive the SPA shell. Other unknown navigation paths resolve to the SPA `index.html`. Hashed build assets use Cloudflare's static-asset delivery and caching.

The gateway only accepts `/api/health` (`GET`/`HEAD`), `/api/auth/*`, `/api/workspace` (`GET`/`PUT`), `/api/workspace/export` (`GET`), the read-only coach endpoints (`GET /api/coach/workspace` with a bearer token, and `GET`/`POST /api/account/coach-tokens` plus `DELETE /api/account/coach-tokens/:id` for managing them), and the explicit account-session endpoints: `GET /api/account/sessions`, `DELETE /api/account/sessions/:id/revoke` (the backend's fixed-length base64url session reference), and `POST /api/account/sessions/revoke-others` or `/api/account/sessions/revoke-all`. Other account paths and methods are rejected before reaching the backend. `/api/health` maps to the backend's `/healthz`. It constructs the upstream URL from the configured origin, never from a request parameter. Both configured origins must be origin-only URLs without credentials, query or path. Production and staging require HTTPS. Local Wrangler development permits HTTP only for `localhost` or `127.0.0.1`.

Mutating requests require `Origin` to exactly match `APP_ORIGIN`; a different or missing origin is rejected. The Worker removes client-supplied Access credentials, the worker secret, forwarding headers, host and hop-by-hop headers, then attaches its own service credentials. Cloudflare overwrites `CF-Connecting-IP` at the public app edge; the Worker copies that value into the private `x-forma-client-ip` header after removing any caller-supplied copy. This avoids a second Cloudflare edge replacing the address on the Worker-to-Tunnel request. Local direct requests do not receive a synthesized address. The backend trusts `x-forma-client-ip` only for rate-limit and audit context, never as identity or authorization.

The gateway does not follow upstream redirects. It maps backend-origin redirect locations to the application origin and permits an already same-origin application location; other redirect targets fail with 502. Redirect `Set-Cookie` headers are preserved for Better Auth flows. Responses preserve individual `Set-Cookie` values and status codes, strip transport and length metadata, and always use `Cache-Control: no-store`. Upstream HTML is rejected so a Cloudflare Access login page or SPA fallback cannot appear as an API success.

Request and response streams are limited to 20 MiB plus 16 KiB for JSON framing, matching the backend's workspace request limit, with a 30-second gateway timeout. The application workspace schema separately caps decoded workspace data at 20 MiB. Cloudflare's account plan may set lower limits. The Worker allows streaming and does not buffer full imports or exports. API errors are short JSON responses and contain no upstream body, URL, credential or workout data. There is no request or response-body logging.

Worker bindings:

| Binding                | Kind     | Purpose                                                     |
| ---------------------- | -------- | ----------------------------------------------------------- |
| `APP_ORIGIN`           | Variable | Exact public app origin used for Origin and redirect checks |
| `BACKEND_URL`          | Variable | Fixed protected HTTPS API origin                            |
| `ACCESS_CLIENT_ID`     | Secret   | Cloudflare Access service-token client ID                   |
| `ACCESS_CLIENT_SECRET` | Secret   | Cloudflare Access service-token secret                      |
| `FORMA_WORKER_SECRET`  | Secret   | Independent value equal to backend `ORIGIN_SHARED_SECRET`   |

Set the three secrets separately for each Wrangler environment with `wrangler secret put NAME --env staging` or `--env production`. Do not put secret values in `wrangler.jsonc`, Vite variables, CI output or browser code. Use a different Access token and worker secret in staging. Add the secrets before exposing the Worker. Replace the `.invalid` staging and production hostnames in `wrangler.jsonc` with owned domains and configure custom domains in Cloudflare. The committed hostnames are inert examples, not deployment endpoints.

For local gateway development, run the API at `http://127.0.0.1:3000`, use `wrangler dev` at `http://localhost:8787`, and provide local-only secrets through ignored `.dev.vars`:

```dotenv
ACCESS_CLIENT_ID=local-placeholder
ACCESS_CLIENT_SECRET=local-placeholder
FORMA_WORKER_SECRET=local-worker-shared-secret
```

Local development does not exercise Cloudflare Access or the real Tunnel. The backend's development config may use a local email sink. Do not reuse staging or production secrets.

## Private Droplet and Compose

`ops/compose.yaml` defines isolated API, database, migration and tunnel services. Compose project names scope its containers, network and volume. Use `forma-staging` for staging and a distinct name for production. The services publish no host ports. The database joins only the internal `database` network; the API joins that network and a separate outbound-capable `tunnel` network; `cloudflared` joins only the tunnel network. The API image is Node 24, runs as UID 10001, has a read-only root filesystem, drops Linux capabilities and has CPU, memory and process limits. The PostgreSQL image is pinned to `postgres:18.4-alpine`, stores its versioned data under the PostgreSQL 18 volume path, and drops all but initialization capabilities. PostgreSQL runs as its image-managed unprivileged server process after initialization.

Use a VPC-only Droplet in a dedicated VPC. Do not attach a public inbound listener for the Node API or PostgreSQL. If the private Droplet has no public interface, route outbound traffic through a DigitalOcean VPC NAT Gateway or an explicitly approved egress design. Permit DNS and HTTPS for updates and approved email/backup endpoints, and Cloudflare Tunnel's outbound transport (UDP or TCP 7844, according to the chosen protocol). Do not open an inbound port for the tunnel. Keep SSH on the private administration path, use key-only access and a named administrator account, and restrict host firewall rules to the VPC/admin sources. Do not apply global firewall changes as part of this repository setup.

Create `/etc/forma/staging.env` from [.env.example](../.env.example), replace every placeholder, and set it to owner `root`, mode `0600`. Create separate `/etc/forma/secrets` files for the PostgreSQL bootstrap password and Tunnel token. Generate unrelated random values for staging and production. The Tunnel token file should be root-owned and readable by the Cloudflared container's runtime group only; PostgreSQL's password file should be root-readable for its entrypoint. Keep the `.env` and files out of source control and off command output. Docker admins can inspect service environment and are part of the trusted host-admin group.

On the Droplet, from the checked-out release directory:

```sh
export COMPOSE_PROJECT_NAME=forma-staging
export COMPOSE_ENV_FILE=/etc/forma/staging.env
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml build api
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml up -d db
./ops/bootstrap-db-roles.sh
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml --profile migrate run --rm migrate
./ops/grant-runtime-access.sh
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml up -d api cloudflared
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml ps
```

`ops/bootstrap-db-roles.sh` requires the environment values from the protected env file to be exported in the operator shell. It provisions the database, a migration role, and a separate runtime role. Migrations connect as `forma_migrator`. After migrations, `ops/grant-runtime-access.sh` grants the API role DML on the eight explicit authentication, MFA and workspace tables; it does not grant access to the migration ledger or schema changes. The API connects as `forma_runtime`. Update both role scripts when a future application table is added. Rotate credentials deliberately through the role script and corresponding env file update, then recreate the relevant service. Do not give the API the bootstrap or migration credentials.

The Tunnel's remotely managed public hostname must target `http://api:3000`. Attach a Cloudflare Access application to the backend hostname and use a Service Auth policy that accepts only the Worker's service token. Keep the application hostname and backend hostname separate. Verify both Access rejection without the service token and success through `/api/health` on the Worker. This repository does not create DigitalOcean or Cloudflare resources, modify host firewalls, run production deployments, or rotate live credentials.

### Staging isolation

Staging needs its own app hostname, protected backend hostname, Access service token, Worker secret, database roles, PostgreSQL volume, Tunnel, email credentials/sink, and backup destination. `docker compose -p forma-staging ...` creates project-scoped names such as `forma-staging_postgres_data`; it will not reuse the production Compose volume or network. Use a staging `.env` file and run the commands with `-p forma-staging`. Do not put production fixtures or member data in staging. The project is currently configured with inert `.invalid` hostnames and has not been deployed.

## Migrations, health and service operations

The `db` health check uses `pg_isready`. The API container health check calls `/healthz` inside the API network. The public Worker `/api/health` routes to the same endpoint through Tunnel and Access. The current endpoint is an API liveness check; it is not proof of database readiness, successful email delivery, backup completion or an end-to-end account journey. The Cloudflare dashboard/Tunnel health and application-level database checks must be monitored separately.

Deploy application code in this order: take a verified backup; build the immutable release image; run the one-shot migration profile; check API health and targeted integration flows; then bring up the API. Migrations are forward-only in this repository. A failed migration should be inspected and repaired with a new migration or restored into an isolated database; do not drop or reset the live database. Keep prior application images for rollback and ensure schema changes remain compatible with the prior release before returning to it. This version does not automatically roll back database changes.

Use `docker compose ... logs --since=15m api db cloudflared` for operational diagnosis. The application redacts credentials and request URLs, but restrict access to host logs and do not add payload, cookie or password logging. Compose rotates each container's JSON logs at 10 MiB, keeping three files; alert on disk and memory pressure, and monitor PostgreSQL database size, connections, backup age, Tunnel availability, API health, email provider delivery and repeated authentication failures. Set explicit host disk alerts; Compose health checks alone do not notify an operator.

Suggested initial targets are a daily encrypted backup and an off-host retention rule of 35 daily and 12 monthly copies. These are operational settings the owner must configure on the selected remote; the script does not delete backups or configure retention. Nightly successful backups would give a nominal RPO of at most 24 hours, but no RPO is established until scheduling, upload alerts and restore drills are running. RTO is not claimed until measured during a restore exercise.

## Encrypted backup and isolated restore

The scripts use PostgreSQL's custom archive format, `age` authenticated encryption and `rclone` to an off-host remote. They store no plaintext dump on disk: backup streams `pg_dump` through age; restore downloads only the encrypted archive and streams the decrypted archive into `pg_restore`. The encrypted archive and its SHA-256 sidecar are uploaded separately. Keep the age private identity in a protected off-host recovery location, separate from both the Droplet and backup storage. Restrict rclone configuration and bucket access to the backup operator; enable server-side encryption and object versioning/retention where the selected storage supports it.

Prerequisites on the operator host are Docker Compose, `age`, `rclone`, a configured remote, `BACKUP_AGE_RECIPIENT`, `BACKUP_REMOTE`, and an exported `COMPOSE_PROJECT_NAME` / `COMPOSE_ENV_FILE`. The database container must be running. Example:

```sh
export COMPOSE_PROJECT_NAME=forma-staging
export COMPOSE_ENV_FILE=/etc/forma/staging.env
set -a
. "$COMPOSE_ENV_FILE"
set +a
./ops/backup-postgres.sh
```

The backup script writes an encrypted timestamped `.dump.age` and `.sha256` to `BACKUP_REMOTE`. It never prunes or overwrites prior backups. Review the result in the remote and alert if the expected daily file is missing.

For a restore drill, use a disposable isolated database whose name begins `forma_restore_`, use a restore credential with create/update rights there, and set `RESTORE_DATABASE_URL` to that exact database. Never point it at `forma`, `forma-staging`, or another active member database. The script verifies the encrypted file checksum before decryption and asks `pg_restore` to stop on error. A failed restore may leave a partial disposable database; drop and recreate that isolated target before retrying. After restoration, verify migration records, row counts, account ownership constraints and one account read/export before declaring the drill successful.

```sh
export BACKUP_ARCHIVE=forma-forma-staging-20261012T010000Z.dump.age
export BACKUP_AGE_IDENTITY_FILE=/etc/forma/recovery/backup-age-identity.txt
export RESTORE_DATABASE_NAME=forma_restore_20261012
export RESTORE_DATABASE_URL='postgres://forma_restore:URL_SAFE_PASSWORD@db:5432/forma_restore_20261012'
./ops/restore-postgres.sh
```

The repository does not claim that a production backup or restore has run. Configure an isolated staging backup and restore drill before relying on this procedure.

## Rotation and recovery checklist

- Rotate the Cloudflare Access Client ID/secret by creating a second token, allowing both during rollout if the Access policy supports it, updating the Worker secret, checking `/api/health`, then revoking the old token. Do not log token values.
- Rotate `ORIGIN_SHARED_SECRET` and `FORMA_WORKER_SECRET` as a coordinated change. Update the backend and Worker in a controlled maintenance window, verify origin health, and remove the old value. The two are equal by design; Access service credentials remain separate.
- Rotate `AUTH_SECRET` only with a planned session invalidation because signed session material may stop validating. Re-authenticate members and verify recovery email paths.
- Rotate database runtime/migration credentials independently. Change PostgreSQL roles first, update the protected env file, recreate the corresponding service/one-shot migration container, and verify the previous credential fails.
- Rotate Tunnel tokens through Cloudflare Tunnel controls, install the new protected token file, restart `cloudflared`, confirm connector health, and revoke the old token.
- Rotate email API keys in the provider and env file, then test verification and password reset delivery with a staging mailbox.
- Keep backup decryption identity recovery separate from ordinary application deployment. Generate a replacement recipient, verify a test restore, then re-encrypt historical archives before destroying the prior identity.

For a suspected origin compromise, disable the Access service token, pause the API/Tunnel services, preserve access-controlled logs and database storage, rotate affected credentials, restore only into an isolated database, and review member-impact scope before returning service. Do not restore over the primary volume during investigation.

## Documentation research record

Checked 2026-10-12 against Cloudflare's official `cloudflare/cloudflare-docs` production branch through raw GitHub because the managed environment allows `raw.githubusercontent.com` but not the live documentation host. The retrieved source records were successful (HTTP 200):

- [Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/) — `src/content/docs/workers/static-assets/index.mdx`; Worker code and assets deploy as one unit.
- [SPA routing](https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/) — `src/content/docs/workers/static-assets/routing/single-page-application.mdx`; `run_worker_first` is the advanced routing control; SPA fallback is explicit via `not_found_handling`.
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) — `src/content/docs/workers/platform/limits.mdx`; limits vary by plan, so the gateway applies its own lower 20 MiB + 16 KiB cap.
- [Workers secrets](https://developers.cloudflare.com/workers/configuration/secrets/) — `src/content/docs/workers/configuration/secrets.mdx`; secrets are encrypted bindings available through the Worker environment.
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) — `src/content/docs/cloudflare-one/networks/connectors/cloudflare-tunnel/index.mdx`; `cloudflared` establishes outbound-only connections so an origin need not have a public address.
- [Access service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/) — `src/content/docs/cloudflare-one/access-controls/service-credentials/service-tokens.mdx`; tokens require a Service Auth policy and consist of a Client ID and Client Secret.
- [Workers VPC](https://developers.cloudflare.com/workers-vpc/) — `src/content/docs/workers-vpc/index.mdx`; current docs mark Workers VPC as beta, so it is not the production dependency.

The official PostgreSQL Docker image [documentation](https://github.com/docker-library/docs/blob/master/postgres/README.md) was retrieved from `docker-library/docs` on the same date. Its PostgreSQL 18 note confirms the versioned `PGDATA=/var/lib/postgresql/18/docker` default and that the volume should mount at `/var/lib/postgresql`; Compose follows that location and does not override `PGDATA`.

The installed Wrangler package is pinned by the root lockfile and was verified as 4.149.0. Its checked-in schema supports `assets.run_worker_first` and `assets.not_found_handling`; `wrangler deploy --dry-run --env staging` completed locally. DigitalOcean official references for [Private Droplets](https://docs.digitalocean.com/products/droplets/details/private-droplets/), [VPC](https://docs.digitalocean.com/products/networking/vpc/), and [NAT Gateways](https://docs.digitalocean.com/products/networking/vpc/how-to/create-nat-gateway/) were identified but their live pages were not retrievable through the current environment's network policy. Requests to the live docs were policy-blocked, and guessed paths in the official raw docs repo returned 404. The private-network and egress steps above are owner deployment requirements, not claims of a provisioned Droplet.
