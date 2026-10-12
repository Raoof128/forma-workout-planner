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

- [Implementation handoff](handoff.md): architecture, changes, evidence and remaining release gates.

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
- [Release readiness](release-readiness.md): current evidence, blockers, and
  GO/NO-GO status for this accounts branch.
- [Source review](sources.md): official documentation retrieval status.
- [Transactional email previews](email-previews/README.md): synthetic HTML templates and responsive review images for the four account email actions.

## Current deployment state

The repository contains deployment configuration and isolated integration
harnesses. Application/backend deployment and Cloudflare Access/Tunnel bindings remain
unverified. The committed Wrangler hostnames use the reserved `.invalid`
domain; the operations guide identifies isolated staging candidates. Cloudflare and DigitalOcean staging deployment,
transactional email delivery, and an off-host backup/restore drill therefore
remain release gates. See [release readiness](release-readiness.md)
before using this as a production service.

The previous [browser-only release report](../qa/release-readiness.md) is a
historical baseline (`86cf`); it does not verify this account-backed branch.
