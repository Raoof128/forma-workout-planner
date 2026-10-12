# Contributing to FORMA

Thank you for helping improve FORMA. Keep changes aligned with its current purpose: a personal, browser-local workout planner.

## Development workflow

1. Read the [setup guide](docs/getting-started.md) and [architecture](docs/architecture.md).
2. Create a branch for a focused change.
3. Use `npm ci` and keep dependency changes intentional and reproducible.
4. Make the change and add regression coverage for meaningful behavior or data-integrity fixes.
5. Run `npm run docs:check`, lint, formatting checks, build, and relevant unit/browser tests. Record which checks ran and their actual results; do not describe unrun checks as passing.
6. Open a pull request describing the problem, the resulting behavior, validation, and any known limits.

## Maintainer notes

FORMA stores workout data in each user's browser profile. Before changing validation, restore behavior, or the version 1 backup shape, review the compatibility guidance in [data-model.md](docs/data-model.md) and update the user instructions. Do not request real workout backups in public issues. Use synthetic data when reproducing import or recovery problems.

For releases, verify the static build and supported checks, review the diff and bundled assets, update the changelog and release evidence with observed results, and preserve a rollback copy of the previous static files. A static-file rollback does not roll back browser-local data. This repository does not document a release cadence or response-time commitment.

## Code conventions

Use the existing React components and shared controls. Format code with `npm run format`. Keep browser persistence inside the store boundary; do not add component effects that save stale snapshots directly. Validate imported/persisted data before use, and preserve original data when recovery is required.

For responsive changes, retain keyboard focus, dialog semantics, readable labels, reduced-motion behavior, and usable input widths at 320px. Use local assets and avoid adding remote services without explaining their effect on the browser-local design.

Do not change the backup version or accepted fields without documenting compatibility and recovery. Keep [data-model.md](docs/data-model.md) and user-facing guidance synchronized with behavior.

## Issues and pull requests

For bugs, include the browser/version, viewport if relevant, steps to reproduce, expected/actual behavior, and whether site storage was available. Use a minimal synthetic example for backup issues. Do not publish private workout logs, credentials, or unredacted browser data.

For suspected vulnerabilities, do not include exploit details, credentials, or private workout data in a public issue. Follow [SECURITY.md](SECURITY.md) to check whether the repository offers a private reporting route. If no private route is available, open a non-sensitive issue asking the maintainer for a private contact method.

The repository does not currently grant a project-wide software license. Bundled font licenses apply to those assets separately.
