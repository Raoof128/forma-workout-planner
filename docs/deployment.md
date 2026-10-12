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

The staging and production origins in the checked-in configuration are
`.invalid` placeholders. Replace them with owned HTTPS hostnames, add Cloudflare
Worker secret bindings, configure a Tunnel route and Access Service Auth
policy, and verify cookies and API paths before any deployment. Follow the
[infrastructure guide](accounts-infrastructure.md) for exact binding names and
the [operations guide](accounts/operations.md) for deployment steps. A local
Wrangler run does not test the real Access token, Tunnel, or remote API.

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

The local Compose definitions and scripts are configuration artifacts, not
evidence of a provisioned Droplet or isolated cloud network. The current
[release-readiness report](accounts/release-readiness.md) lists the deployment
gates that still require owner credentials and staging.

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
backup scripts are implemented, but no off-host upload or restore drill has
been run. See [account operations](accounts/operations.md) and the
[infrastructure backup runbook](accounts-infrastructure.md#encrypted-backup-and-isolated-restore).
