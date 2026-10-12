# FORMA

**Plan your training. Log every set. See your progress.**

FORMA is a workout planner built with React and Vite. Members can use an
account-backed workspace that stores routines and workout history in
self-hosted PostgreSQL, or use the separate local guest mode in a browser.
The intended hosted architecture serves the frontend and same-origin API
gateway from Cloudflare Workers and keeps the Node.js API and database on a
private DigitalOcean host. The repository includes deployment configuration;
it does not claim that the configured placeholder domains or staging services
have been deployed.

[Account docs](docs/accounts/README.md) · [Getting started](docs/getting-started.md) ·
[User guide](docs/user-guide.md) · [Architecture](docs/architecture.md) ·
[Contributing](CONTRIBUTING.md)

## Features

| Plan                               | Train                                        | Review and manage                                     |
| ---------------------------------- | -------------------------------------------- | ----------------------------------------------------- |
| Three editable starter routines    | Set-by-set weight and rep logging            | Editable workout history                              |
| Custom routines and exercise order | Persistent rest timer and session notes      | Volume, completed sets, and personal bests            |
| Weekly training schedule           | Exercise instructions while logging          | Validated JSON backup and restore                     |
| Searchable 16-exercise library     | Resume an unfinished session                 | Account profile, security, and training-data settings |
| Local guest mode or member account | Authenticated workspace sync across sessions | Session revocation, MFA, import, and export           |

The interface uses semantic controls, keyboard navigation, accessible dialogs,
mobile workout controls, and locally hosted fonts. See the [verification
record](docs/verification.md) for the original frontend baseline. Current
account readiness is tracked separately in
[docs/accounts/release-readiness.md](docs/accounts/release-readiness.md).

## Development

Use Node.js 24 and npm. Install the lockfile and start the Vite interface:

```sh
npm ci
npm run dev
```

For offline local storage mode, run `VITE_ACCOUNT_MODE=guest npm run dev`.
Account mode requires the API or the isolated account test harness; the Vite
development proxy is configured with `FORMA_API_TARGET` and
`FORMA_DEV_WORKER_SECRET`. Never put production credentials in Vite variables.
See [account operations](docs/accounts/operations.md) for local service and
database setup.

## Build and tests

```sh
npm run build
npm run typecheck
npm run lint
npm run docs:check
npm run test:unit
npm run test:server
npm run test:worker
npm run test:accounts
```

The real PostgreSQL server tests require `TEST_DATABASE_URL` for a disposable
database. Account browser tests use an isolated API schema and an in-memory test
email sink; they do not prove real email delivery or a Cloudflare/DigitalOcean
deployment. Browser engines must be installed with Playwright before the full
browser suite. See [testing](docs/testing.md) and the current account
[release-readiness report](docs/accounts/release-readiness.md) for the observed
limits and status.

## Privacy and security

Account-backed workout data is stored in PostgreSQL on the configured private
API host. The browser sends its Better Auth session cookie to the same-origin
Worker gateway; it never connects directly to PostgreSQL. Member identity comes
from the server-validated session, and every workspace query is scoped to that
member. Workspace API responses are not cached. Review the
[database ownership model](docs/accounts/database.md) and
[security reporting policy](SECURITY.md).

A red-team engagement on 2026-10-12 hardened the account stack and recorded
its findings, tests and residual risks in [docs/security](docs/security/README.md).
Its verdict is **NO-GO for real members** until live Cloudflare, Droplet,
backup-restore and monitoring checks pass.

Local guest mode stores data in browser `localStorage`; it is specific to the
browser profile and origin and is not encrypted. Export a backup before clearing
site data or changing browsers. The account interface supports validated import
after member confirmation, so an existing v1 backup can be transferred.

The Cloudflare Access token authenticates the Worker to the protected API
origin; it is separate from member authentication. The Worker and API share an
additional service secret. Keep both out of client assets. A configured
production origin, Access/Tunnel route, email delivery, off-host backup, and
restore drill are still deployment owner tasks.

## Documentation

| Document                                                | Purpose                                                         |
| ------------------------------------------------------- | --------------------------------------------------------------- |
| [Account docs](docs/accounts/README.md)                 | Account overview and references                                 |
| [Account API](docs/accounts/api.md)                     | Auth, sessions, workspace routes, and error contract            |
| [Operations](docs/accounts/operations.md)               | Environment, deployment, migrations, backup, and recovery       |
| [Database](docs/accounts/database.md)                   | Schema, ownership, revision, and migration integrity            |
| [Infrastructure](docs/accounts-infrastructure.md)       | Worker, Tunnel/Access, private-host topology, and source checks |
| [Member sync](docs/member-data-sync.md)                 | Save, retry, import/export, and conflict handling               |
| [Account readiness](docs/accounts/release-readiness.md) | Release gates and evidence for this branch                      |
| [Security](docs/security/README.md)                     | Threat model, red-team findings, coverage and release verdict   |
| [Sources](docs/accounts/sources.md)                     | Official source retrieval status and limits                     |
| [User guide](docs/user-guide.md)                        | Workout use and legacy browser backup guidance                  |
| [Data model](docs/data-model.md)                        | Version 1 workspace shape and validation                        |
| [Testing](docs/testing.md)                              | Existing frontend suite and test conventions                    |
| [Changelog](CHANGELOG.md)                               | Notable changes                                                 |
| [Security](SECURITY.md)                                 | Responsible reporting and security notes                        |

Weights use kilograms and dates use Australia/Sydney. Starter weights are
editable examples. One plank rep represents a 10-second hold. FORMA does not
include billing, social networking, Apple Health integration, or automated
coaching.

The repository does not currently include a project-wide software license. The
Barlow Condensed and DM Sans font licenses are in `public/fonts/`; the
redistribution terms for the workout photographs are not documented here.
