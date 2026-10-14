# Deployment

[Back to README](../README.md) · [Account operations](accounts/operations.md) ·
[Infrastructure reference](accounts-infrastructure.md)

The account architecture is browser → Cloudflare Worker static assets and
same-origin API gateway → Access-protected Cloudflare Tunnel → private Fastify
API → PostgreSQL. The API and PostgreSQL are not intended to have public
inbound listeners. The browser never connects to the database.

## Local build and preview

```sh
npm ci
npm run build
npm run preview
```

`npm run preview` only serves the Vite assets locally. Account mode also needs a
configured backend; use [account operations](accounts/operations.md) for the
development proxy and real-PostgreSQL test requirements. Set
`VITE_ACCOUNT_MODE=guest` to exercise browser-local guest mode without an API.

## Cloudflare Worker

`wrangler.jsonc` serves the Vite `dist/` output and runs Worker code before
static-asset routing for `/api` and `/api/*`. The Worker allow-lists health,
Better Auth, workspace, and account session routes; unknown API paths return
JSON errors and do not fall through to the SPA shell. Authenticated and API
responses are not cached. Static responses receive the configured security
headers.

Production serves `forma.raoufabedini.dev` in account mode. Public accounts were
activated after the hosted operational gates passed; see the
[production launch record](accounts/production-launch.md). Private staging uses
`forma-staging.raoufabedini.dev` and the Access-protected
`forma-api-staging.raoufabedini.dev`. Both use separate private backends and
credentials. A local Wrangler run does not test the real Access token, Tunnel,
or remote API. Older guest-only release records describe historical deployments.

For frontend updates, verify the account build and use the one-hour scoped token
helper; its token is held in memory and revoked in `finally`:

```sh
npm run worker:deploy:production
npm run worker:deploy:staging
```

The helper uses the existing infrastructure token to mint and revoke the
temporary token. Do not put tokens in Vite variables or commit an `.env` file.
Keep the previous Worker version for rollback. After deployment, check the real
HTTPS site, library guides, photos, forms and anonymous gateway boundaries.
HTML adds `no-transform` to cache control to prevent automatic analytics injection.
API responses remain uncached and protected by the same ownership rules.

For catalog identity/schema changes, update and validate each matching private
API before its account frontend. Artwork, client guide wording and presentation
changes do not require restarting an unchanged API. Preserve member data, secrets,
resource limits and unrelated services. In this managed environment set
`XDG_CONFIG_HOME=/workspace/forma-cloudflare-config` for Wrangler's writable
configuration and logs. See the [latest frontend deployment](qa/site-sweep/deployment/README.md)
and [catalog/API release record](research/catalog-quality.md).

## Private API and PostgreSQL

The Compose file defines a private PostgreSQL service, restricted Fastify API,
one-shot migration service, and outbound `cloudflared` connector. It publishes
no host ports. The database is on an internal Compose network; the API also
joins the Tunnel network. Use separate Compose project names, databases,
secrets, volumes, and email configuration for staging and production.

Use the separate migration role for versioned migrations and the runtime role
for API access. Do not copy production values into the Worker bundle or
development environment. On a private-only DigitalOcean host, verify outbound
DNS and routing (including NAT if needed) for Tunnel, security updates, email,
and backups. Official DigitalOcean documentation retrieval was blocked in this
execution environment; see [source status](accounts/sources.md).

The [deployment record](security/deployment-record.md) records the original
private staging stack at `/opt/forma-staging`, its resource limits, and the
completed live probes. Current production operations are recorded in the
[production launch record](accounts/production-launch.md). Update only the intended
FORMA Compose project on the shared host.
The expanded catalog and timed workspace fields require the matching API build
before deploying the new account frontend; the previous API rejects new IDs.

Direct cloud sandbox SSH remains blocked before authentication. The verified
[Cloudflare Access SSH method](cloud-ssh-access.md) provides a protected
alternative using the existing Tunnel. Do not change host firewalls or unrelated
services to solve sandbox egress.

## Deployment order, rollback, and recovery

Before an API release, take a verified backup, build the server image, apply
the one-shot SQL migrations, then start the API. Migrations are transactionally
applied, advisory-locked, and checksum-verified. The deployment does not
automatically roll back database schema. Keep the previous API image available
and keep changes backward compatible for the rollback window; add forward
migrations instead of editing applied SQL.

An application rollback does not reverse member workspace data. Restore only
to a pre-created isolated database whose name begins `forma_restore_`; verify
the checksum and application-level integrity before considering recovery. The
backup scripts are implemented and a staging isolated restore was verified in
the deployment record; off-host uploads and actionable alerting remain open
before accounts can become public. See [account operations](accounts/operations.md) and the
[infrastructure backup runbook](accounts-infrastructure.md#encrypted-backup-and-isolated-restore).
