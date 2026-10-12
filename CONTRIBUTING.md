# Contributing to FORMA

Thank you for helping improve FORMA. Keep changes aligned with its purpose as
an accessible workout planner with a browser-local guest mode and a
self-hosted, member-owned account workspace.

## Development workflow

1. Read the [setup guide](docs/getting-started.md), [architecture](docs/architecture.md), and [account overview](docs/accounts/README.md).
2. Create a branch for a focused change.
3. Use `npm ci` and keep dependency changes intentional and reproducible.
4. Keep account data access scoped to the user ID from the server-validated session. Do not accept a workspace owner from a URL or request body. Make meaningful data-integrity changes with real PostgreSQL integration coverage.
5. Run `npm run typecheck`, `npm run docs:check`, lint, build, and relevant tests. `npm run test:server` requires a disposable real PostgreSQL database through `TEST_DATABASE_URL`; account browser tests use an isolated schema and in-memory email sink. Record actual checks and results. Do not describe unrun staging, email, or backup work as passing.
6. Open a pull request describing the problem, the resulting behavior, validation, and any known limits.

## Maintainer notes

FORMA's guest mode stores workout data in browser storage. Account mode uses the version 1 workspace in PostgreSQL. Before changing validation, import/export, ownership, revision, or account deletion behavior, review the [data model](docs/data-model.md), [database model](docs/accounts/database.md), and [API contract](docs/accounts/api.md). Do not request real workout backups in public issues. Use synthetic data when reproducing import or recovery problems.

For releases, verify the frontend and server builds and supported checks, review the diff and bundled assets, update the changelog and [account release evidence](docs/accounts/release-readiness.md) with observed results, and keep the previous application image available. Account releases require database migration compatibility and tested recovery; static-file rollback alone does not roll back member data or PostgreSQL schema. This repository does not document a release cadence or response-time commitment.

## Code conventions

Use the existing React components and shared controls. Format code with `npm run format`. Keep guest persistence inside the guest store boundary and cloud writes inside the authenticated workspace repository. Do not add component effects that save stale snapshots directly. Validate imported and persisted data before use, and preserve original data when recovery is required.

For responsive changes, retain keyboard focus, dialog semantics, readable labels, reduced-motion behavior, and usable input widths at 320px. Use local assets and avoid adding remote services without explaining their effect on member privacy and the self-hosted architecture.

Do not change the backup version or accepted fields without documenting compatibility and recovery. Keep [data-model.md](docs/data-model.md) and user-facing guidance synchronized with behavior.

## Issues and pull requests

For bugs, include the browser/version, viewport if relevant, steps to reproduce, expected/actual behavior, and whether site storage was available. Use a minimal synthetic example for backup issues. Do not publish private workout logs, credentials, or unredacted browser data.

For suspected vulnerabilities, do not include exploit details, credentials, or private workout data in a public issue. Follow [SECURITY.md](SECURITY.md) to check whether the repository offers a private reporting route. If no private route is available, open a non-sensitive issue asking the maintainer for a private contact method.

The repository does not currently grant a project-wide software license. Bundled font licenses apply to those assets separately.
