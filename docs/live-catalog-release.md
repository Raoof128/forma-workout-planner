# Public catalog release

[README](../README.md) · [Catalog sources](research/runtime-catalog.md) ·
[Deployment](deployment.md) · [Cloud environment](cloud-environment.md)

This release builds on upstream `5c826d7`. It expands the browser-local planner
to 1,661 exercises and adds 12 reusable workout templates alongside the three
starters. It includes full licensed guides, paginated search with aliases,
correct time/distance units in logging and history corrections, and version 1
backup compatibility. Timed/carry measurements cannot inflate lifting volume
or estimated 1RM. Original IDs, historical plank units and workspace bounds
are preserved.

The public account screen provides local profile, backups and history controls
instead of forms connected to an unavailable account API. New guest profiles
use `Guest`. Production has no fake backend hostname or API secret bindings.
Privacy Policy version 1.1 includes the new measurement fields; Terms wording
is unchanged.

## Validation

- Lint, formatting, TypeScript and server compilation passed.
- Unit tests: 49 passed; Worker tests: 20 passed; real-PostgreSQL API tests: 44 passed.
- Production browser matrix: 40 passed across desktop Chromium, Firefox and
  WebKit, plus mobile Chromium and WebKit; includes catalog, cardio, corrections,
  persistence and public workspace controls.
- Broad development run: 252 passed, two new export-label assertions were
  corrected, and one startup hash-navigation race was reproduced and fixed.
  The deterministic navigation regression then passed in all three engines.
  All 15 affected development cases then passed in three engines. The final
  40-case production matrix includes the deterministic navigation regression.
- Account development run: 40 passed; all five cases that timed out or missed
  readiness under concurrent browser load passed when rechecked separately.
  The built account browser matrix passed all 45 cases across five projects.
- Dependency audit: zero production vulnerabilities; repository credential scan:
  zero matches.
- Source refresh was exercised twice: 925 current wger records paginated,
  133 additions retained on refresh, zero additional imports on the second pass.
- API container build passed. Its network-disabled, read-only runtime verified
  1,661 catalog entries, timed schema validation and UID 10001 under the existing
  320 MB memory limit. Image: `sha256:976980fac2cdcb8882f3f08cf3e6f92175e4fcb460ebcd6f965e1680a0d988ab`.
- Both Worker deployment configurations passed dry runs. The rebuilt guest
  asset hashes matched the exact build used by the final 40-case matrix.
- Before the staging update, an age-encrypted backup was created on the Droplet
  under `release-backups/catalog-20261013T010731Z`. Its checksum, isolated restore,
  workspace fingerprint and application validation passed; the restore database
  was removed. Member data stayed on the Droplet. The protected decryption key
  stays with this manual release backup; scheduled off-host recovery remains open.

## Deployment and remaining scope

Target: [forma.raoufabedini.dev](https://forma.raoufabedini.dev), public guest mode.
Deployment uses a fresh one-hour scoped token which is revoked immediately.
The live Worker version and post-deployment checks are recorded after deployment.

Environment version 5 reports unrestricted Internet access as enforced. Direct
SSH is still refused before authentication, but the official Cloudflare
client-side SSH route was verified from this sandbox with the stored key and
root login. Anonymous access was denied. Temporary Access credentials, DNS and
SSH ingress were removed; the existing FORMA API ingress was preserved. See
[SSH access](cloud-ssh-access.md) for the current developer documentation.

Do not deploy this account frontend to private staging until its API uses the
matching catalog/schema. Staging's existing frontend and API remain together.
Public accounts remain gated by off-host backups and actionable alerting as
required by `AGENT.md` and the existing security verdict. This is a public guest
planner release, not a claim that account production is ready or that the catalog
enumerates every possible workout worldwide.
