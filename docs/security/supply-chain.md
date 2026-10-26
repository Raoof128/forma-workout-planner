# Supply chain and CI

The scanner and CI results below belong to the 12 October 2026 assessment.
Later hosted CI evidence is retained in [QA](../qa/README.md); run the current
checks for a new release. These historical results do not establish the
current vulnerability or branch-protection state.

[Back to security overview](README.md)

## Dependencies

Results from 2026-10-12, run locally:

| Check                                       | Result                                                                                                            |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `npm audit` (all and `--omit=dev`)          | 0 vulnerabilities                                                                                                 |
| `osv-scanner` 2.6.0 on the lockfile         | 496 packages, no issues                                                                                           |
| Lockfile provenance                         | All entries resolve to `registry.npmjs.org` with integrity hashes; no git or URL dependencies                     |
| Install scripts                             | Only `esbuild`, `fsevents` and `workerd`, all development-only                                                    |
| Direct versions                             | Exact versions in `package.json` (no ranges)                                                                      |
| `gitleaks` 8.30.1 over all branches         | 14 commits, no leaks                                                                                              |
| Semgrep 1.170 (JS, TS, nodejsscan, secrets) | 10 results, all triaged as false positives and annotated with a reason; the run now exits 0 with no rule timeouts |

A clean scan only means no known issue was found by that tool.

## CI controls

`.github/workflows/ci.yml`:

- `permissions: contents: read`; no `pull_request_target`; no secrets used.
- Actions pinned to commit SHAs; checkouts use `persist-credentials: false`.
- A separate **Security scans** job runs gitleaks over full history, OSV on the
  lockfile, and Semgrep with `--error`, each from a digest-pinned image, and
  builds a CycloneDX SBOM (`--omit dev`) with `--ignore-scripts`. Any finding or
  scanner failure fails the job.
- The verify job builds the non-root image, runs real-PostgreSQL server tests,
  Worker tests, unit tests and all browser suites.
- `.github/dependabot.yml` proposes weekly npm, Actions and Docker updates.

These CI changes were validated locally (actionlint, YAML lint, scanners run
from the same pinned images). They have not yet run on GitHub-hosted runners.

## Repository settings (owner)

- `main` has no branch protection. Require pull requests, the "Verify
  application" and "Security scans" checks, and no force pushes.
- Enable private vulnerability reporting, secret scanning and push protection
  in the GitHub Security tab (referenced by `SECURITY.md`).
- Playwright traces uploaded on failure contain only synthetic data; keep it
  that way, because the repository is public.
