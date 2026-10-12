# Contributing to FORMA

Thank you for helping improve FORMA. Keep changes aligned with its current purpose: a personal, browser-local workout planner.

## Development workflow

1. Read the [setup guide](docs/getting-started.md) and [architecture](docs/architecture.md).
2. Create a branch for a focused change.
3. Use `npm ci` and keep dependency changes intentional and reproducible.
4. Make the change and add regression coverage for meaningful behavior or data-integrity fixes.
5. Run lint, formatting checks, build, and relevant browser tests.
6. Open a pull request describing the problem, the resulting behavior, validation, and any known limits.

## Code conventions

Use the existing React components and shared controls. Format code with `npm run format`. Keep browser persistence inside the store boundary; do not add component effects that save stale snapshots directly. Validate imported/persisted data before use, and preserve original data when recovery is required.

For responsive changes, retain keyboard focus, dialog semantics, readable labels, reduced-motion behavior, and usable input widths at 320px. Use local assets and avoid adding remote services without explaining their effect on the browser-local design.

Do not change the backup version or accepted fields without documenting compatibility and recovery. Keep [data-model.md](docs/data-model.md) and user-facing guidance synchronized with behavior.

## Issues and pull requests

For bugs, include the browser/version, viewport if relevant, steps to reproduce, expected/actual behavior, and whether site storage was available. Use a minimal synthetic example for backup issues. Do not publish private workout logs, credentials, or unredacted browser data.

For suspected vulnerabilities, avoid posting exploitable details or private data in a public issue. Use the repository's private vulnerability-reporting option if enabled, or ask the maintainer for a private reporting channel.

The repository does not currently grant a project-wide software license. Bundled font licenses apply to those assets separately.
