# FORMA accounts

The account implementation uses the existing React/Vite workout interface with
a Cloudflare Worker for static assets and the same-origin API gateway. Better
Auth and the Fastify API run on a private host; PostgreSQL is the authoritative
store for member identity, sessions, and each member's workout workspace.

Each authenticated member has a private, server-validated workspace. The
browser does not select an owner ID or connect to PostgreSQL. Writes include an
expected revision and operation ID. Conflicts surface the latest server state
so the client can recover without silently overwriting another device's save.
The account UI also offers a guest mode using browser storage; guest data is
separate from the member database.

## Documents

- [Implementation handoff](handoff.md): original architecture, changes, evidence and release gates at that review stage.

- [API reference](api.md): authentication, account session, and workspace APIs.
- [Database and ownership model](database.md): PostgreSQL tables, ownership,
  validation, revision and idempotency rules.
- [Operations and deployment](operations.md): local test setup, environment
  configuration, Cloudflare, private-host, and backup procedures.
- [Infrastructure guide](../accounts-infrastructure.md): Worker gateway,
  Tunnel/Access, Compose services, backup/restore implementation, and research
  record.
- [Member sync and conflict handling](../member-data-sync.md): client save and
  conflict contract.
- [Release readiness](release-readiness.md): dated implementation evidence,
  blockers, and GO/NO-GO decisions for the original accounts branch.
- [Source review](sources.md): official documentation retrieval status.
- [Transactional email previews](email-previews/README.md): synthetic HTML templates and responsive review images for the four account email actions.

## Current deployment state

Public account activation, separate staging and production backends,
transactional email, signed off-host backups and isolated restores are recorded
in the dated [production launch record](production-launch.md). The checked-in
Worker configuration uses `forma.raoufabedini.dev` and
`forma-staging.raoufabedini.dev` with separate protected API origins. Consult
[operations](operations.md) for the configuration and
[release readiness](release-readiness.md) for the historical test scope. These
records do not replace current release checks or live monitoring.

The previous [browser-only release report](../qa/release-readiness.md) is a
historical baseline (`86cf`); it does not verify this account-backed branch.
