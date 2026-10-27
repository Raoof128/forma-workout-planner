# Runtime quality release — 26 October 2026

The owner-authorized audit release is live on staging and production. Each API
was released before its account website, with staging verified first. This
record adds hosted evidence to the [local audit](../../audits/forma-runtime-quality-2026-10/AUDIT_REPORT.md);
it does not replace the earlier account launch or its historical checks.

## Source and deployment

[PR #30](https://github.com/Raoof128/forma-workout-planner/pull/30) merged as
`10942dcd24de194e620550cd298fd1479d2324a4`. Application inputs are from
`d770a6c`; `4234d5e` changes only documentation and an exact historical scanner
fingerprint. The latter and the merge have identical trees. This release adds
no schema migration and preserves saved workout identities and units.

| Environment | Worker version, serving 100% | Hosted result |
| --- | --- | --- |
| [Staging](https://forma-staging.raoufabedini.dev) | `1ec26df9-3e4b-491f-8bb0-b0772bfc38ab` | API healthy; HTTP 38/38; functional smoke passed |
| [Production](https://forma.raoufabedini.dev) | `d0481946-7509-4496-8dba-8bcb600e7d6f` | API healthy; HTTP 38/38; functional smoke passed |

Both APIs use repository `forma-api`, tag `runtime-audit-20261026-d770a6c`,
Node 26.12.1, bundled Undici 8.12.2 and UID 10001. Each release recorded two
encrypted off-host backups with uploaded signatures, unchanged database row
counts and unrelated containers, and zero API error lines in its verification
window. These backup receipts do not constitute a new restore drill. Compose
operations explicitly selected `forma-staging` or `forma-production`.

The transferred archive's OCI manifest `37201d56…` references configuration
`95a1529d…`, the locally audited image identifier. Both hashes and all ten
layer hashes/diff IDs were verified. Classic Docker reports the configuration
digest as `Image.Id`; the remote containerd store reports the manifest target.
The complete manifest/configuration/layer chain establishes the same image
despite those display differences. Full digests and curated receipts are in
[deployment.json](deployment.json).

## Hosted checks

Both environments passed 38 HTTP checks: health 200, anonymous workspace 401,
unknown API route 404, coach 401 with its bearer challenge, API no-store and
restrictive CSP, HTML security headers, and exact HTML plus all four account
build asset hashes. The served entry is `index-B2mput03.js`; CSS is byte-identical
to the pre-release site. Health establishes liveness.

Chromium 156.0.8078.4 checked login, Overview, Exercise library, Progress and
Privacy at widths 320, 390 and 1440: 15 functional/layout states per environment.
Auth-form mode transitions and keyboard focus passed without submission.
There was no horizontal overflow, page/console error, failed request,
unexpected HTTP failure or attempted write. Production Library captures waited
for 24 thumbnails to decode at each width; hero and routine photos rendered.

Initial and settled staging screenshots made through a response-fulfilling
`route.fetch` harness showed blank CSS photos despite valid image responses.
A native Chromium probe at 1440, with Access headers restricted to each exact
staging-origin request, rendered both photos and observed their 200 responses.
The blank backgrounds were isolated to the harness; its low-level mechanism
was not determined. The initial staging captures do not prove complete visual
rendering. Production used native requests. Different image-settling procedures
also mean these are not pixel-exact before/after screenshot comparisons.

The same 30 accessibility node findings remain across six scans in each
environment: sign-in helper-text contrast (3.8:1 versus 4.5:1), the brand's
visible/accessibility label mismatch, and seven Overview calendar-button labels.
These baseline issues remain documented follow-ups. There are zero new,
changed or resolved findings. The defined release comparison and functional
checks pass; raw browser `pass` and `accessibilityPass` remain false. This is
not an accessibility-conformance claim.

## CI, cleanup and limits

At **2026-10-26 05:50 UTC**, [CI run 40273543896](https://github.com/Raoof128/forma-workout-planner/actions/runs/40273543896)
had passed full-history gitleaks, OSV, Semgrep and production SBOM generation/
upload. All non-browser application checks and the development browser suite
had passed. The production browser suite was running; both account browser
suites were pending. The complete application job was still in progress.

The separate local audit records 134 unit, 67 API, 27 Worker and 14 operations
passes, with passing coverage for all 902 browser cases. Its original matrix
had one timeout; the affected 22-case profile passed unchanged at its original
budget. These local results do not establish a completed CI run.

Both one-hour Worker deployment tokens were revoked. Temporary release-access
cleanup completed at **05:48:47 UTC**: the session service token, both added
policies, temporary SSH application/DNS/ingress and scoped infrastructure API
token were removed or revoked; private session journals were removed. An
initial deletion returned provider error 12139 because of a policy reference.
Removing only the exact temporary policy IDs resolved it; existing policies
were preserved. The final tunnel configuration version is 59.

Hosted smoke used fresh anonymous member contexts and GET/HEAD/OPTIONS, with
staging Access credentials restricted to that origin. No member login,
member-data writes, email delivery, recovery restoration, sustained load or
physical-device testing was performed by this release smoke.

The selected public evidence bundle is `forma-release-evidence-2026-10-26.zip`.
It contains release receipts and HTTP/browser comparisons; credentials, private
session journals and host inventory are excluded. This repository stores the
curated facts in `deployment.json`, not raw operational logs.
