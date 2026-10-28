# Forma complete file inventory audit and Apple Watch readiness

Date: 26 October 2026. Baseline commit: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`. Repository: `/workspace/forma-workout-planner`.

## Answer to the request

The previous audit was selective and added no Watch implementation. This pass accounts for **every one of the 1,471 tracked files individually**, with a per-file method, checked scope, result, findings and limitations. Authored code, Markdown, HTML and scripts were read; structured/generated data and binary media received explicit validation methods. A binary decode is not called a visual review, and a historical QA receipt is not treated as a fresh runtime result.

**No Apple Watch code has been added.** The available project remains a React/Vite web application with no Swift files, Xcode project, iOS/watchOS companion targets, HealthKit entitlements, native privacy manifests or native tests. Research and an audit are not a working device connection.

The expanded [Apple requirements matrix](APPLE_WATCH_REQUIREMENTS.md) maps **37 relevant checks** to official Apple sources, applicability, current implementation state and required verification. It includes current API documentation and actual 2026 release/submission changes. It does not claim that every Apple document or every optional Apple feature must be implemented. Native requirements are missing or untested; the existing server snapshot safeguards are a partial foundation.

## Per-file coverage

| Area | Files | Review |
|---|---:|---|
| Runtime `src/` | 64 | 53 complete authored-source/CSS reviews; 11 catalog JSON files checked across every record and relevant relation |
| Server and Worker | 37 | Complete source, migration and test review |
| Browser and unit tests | 70 | Complete test/helper review; fixture, assertion and coverage analysis |
| Root, CI, operations and scripts | 63 | 62 complete authored-file reviews; exhaustive generated lockfile validation |
| Assets and public resources | 719 | Every raster/media/font decoded or parsed, every SVG checked, README/licenses read |
| Documentation and research evidence | 518 | 83 authored Markdown/HTML/shell files read; 435 historical/structured/media/key artifacts individually validated |
| **Total** | **1,471** | Exact baseline manifest; coverage reconciliation recorded in `coverage-proof.json` |

Open [FILE_AUDIT.md](FILE_AUDIT.md) for all rows, or use [FILE_AUDIT.csv](FILE_AUDIT.csv) / [FILE_AUDIT.json](FILE_AUDIT.json) to filter by path, method or finding. Each row includes the baseline SHA-256 and size. Untracked build outputs, dependency installations, `.git` internals and secret files are outside the tracked-source inventory; they are not silently counted as reviewed source.

Final reconciliation found **zero missing paths, duplicate paths, extra paths or changed source hashes**. The [coverage proof](coverage-proof.json) records all eight review parts; [artifact verification](artifact-verification.json) confirms matching Markdown/JSON/CSV row counts, all 37 requirement IDs and all 27 cached Apple source hashes.

## Confirmed findings requiring attention

Severity is local to the current behavior. Watch release gates and unverified risks are separated from proven defects. Reproductions used synthetic local inputs and mocks, never production accounts or restore operations.

| Finding | Severity | Evidence and effect | Recommended correction |
|---|---|---|---|
| B-W1 — redirect rewriting can leave the app origin | P2 | `server/app.ts:318` accepts a relative callback that normalizes unexpectedly; Worker rewriting emits an external `Location`. The actual Worker function reproduced a 302 outside the app origin with injected mock fetch. No credential leak or live-token exploitation was tested. | Normalize once, validate the final resolved origin, and preserve that origin when rewriting. Add canonicalization cases to gateway/server tests. |
| T01 (tooling) — restore isolation guard validates a suffix, not the database | P2 | `ops/restore-postgres.sh:13` accepts a synthetic connection URI whose libpq-resolved database differs from the required isolated name; `:29` passes it to destructive restore. This is an operator-tool guard failure. | Validate the parsed database/connection target and use an isolated restore role; add parser-only regressions. |
| T02 (tooling) — probe timeout prevents host alert state updates | P2 | `ops/account-operations.py:240` can raise before the state/alert code. Two mocked timeouts produced no persisted failure count or alert. The separate edge monitor remains available. | Convert timeouts into bounded failure signals, persist state and continue independent checks. |
| DP04 — release image is not bound to the verified archive | P2 | `docs/qa/holds-timer/api-release.sh:26` skips loading a verified archive whenever its tag already exists, then deploys that existing tag. | Verify the selected image against the archive or an expected immutable digest before migration/deployment. |
| DP05 — release postflight deviations leave a success exit | P2 | `api-release.sh:65–67` prints count/container differences and error totals without failing or requiring review; container comparisons omit IDs. | Return a failed/review-required result for unresolved deviations and compare actual container/image identities. A count difference alone does not establish data loss. |
| RT01 — repeated hold completion logs the next set | P2; Watch gate | `src/components/Workout.jsx:375` retargets a completed timer target to the first unfinished set. Exact-source replay and prior two-tab browser reproduction produce two completed sets for one intended target. | Stable set/timer/event IDs; acknowledge duplicates without retargeting. |
| RT02 — delayed completion restarts rest late | P2 | `Workout.jsx:368,397` uses callback time after suspension, leaving a full rest interval after it should have expired. | Use scheduled completion time for automatic expiry, action time for manual early end. |
| RT03 — manually started rest has no initialized audio cue | P2 | Manual rest actions omit `prepareCue`; a fresh unmuted screen retains a null AudioContext. | Initialize/resume during the user gesture and test cue/mute/error behavior. |
| RT04 — navigation loses the running/paused hold | P2; Watch gate | Component-only state at `Workout.jsx:117` is destroyed when `App.jsx:535` unmounts the workout route. This is an existing documented limitation. | Persist timer identity/state independently of screen lifetime. |
| B-S1 — coach summaries lose prescription meaning | P2 | `server/coachTokens.ts:388` omits per-side and rep-range semantics. Validated materially different prescriptions produce identical summaries in a local pure-function test. | Preserve meaningful prescription fields in the read contract and add exact-value tests. |
| RUI01 — privacy disclosure omits enabled coach/AI sharing | P2 | `src/legal/content.js:74` says there is no other third-party disclosure while Account offers user-authorized coach access. | Explain user-directed access and its scopes, revocation and future health-data exclusions. This is a factual disclosure mismatch, not a legal opinion. |
| RUI02 — account crash recovery exports guest data | P2 | `src/components/ErrorBoundary.jsx:20` always exports browser guest storage or an empty string. Actual handler callback reproduced both outcomes. | Match export to the failed storage mode or clearly label the limited fallback and provide account recovery. |
| RUI03 — cloud Overview says saved on device | P3 | `Overview.jsx:308` does not distinguish cloud from guest persistence. | Show actual storage/acknowledgement state. |
| RUI04 — account caption contrast fails | P2 | Actual CSS/computed-style probe confirms `#858d86` on white at 9px: 3.4138:1. | Darken the caption and recheck affected statuses and screens. |
| RUI05 — auth color variables are out of scope | P3 | Account tokens are defined on the signed-in wrapper but used on signed-out roots; computed styles show transparent/missing accents. | Define shared tokens on an ancestor common to both layouts. |

Details, exact scope and reproduction artifacts: [runtime findings](runtime-findings.md), [backend findings](backend-findings.md), [tooling findings](tooling-findings.md). Additional documentation, historical-evidence and release-script findings are in [operations documentation](docs-ops-findings.md), [product/QA documentation](docs-product-findings.md), and [structured documentation](docs-structured-findings.md). Those reports distinguish current instruction errors from valid dated records.

**Conditional release risk DP06:** the still-recommended API helper automatically switches back to the previous image after migrations if health checks fail, without checking schema or saved-workout compatibility. Reuse for an incompatible release can leave the old API unable to read the current data. The original release expected no migration changes; this audit does not claim that its recorded deployment failed. Require a verified compatibility plan before enabling automatic rollback.

Current documentation also needs corrections for backup/setup claims, authorized coach access, per-side prescription limits, obsolete release-status links and the installed authentication-library version. Two structured research/QA records contain historical tally/capture drift; the underlying current assets and active guide hashes match. Resolved validation candidates are documented separately and are not reported as bugs.

## Test coverage gaps

The [70-file test review](tests-findings.md) identifies missing regressions for repeated same-target completion, suspension-based rest timing, hold continuity, manual sound initialization and durable retry after process restart. Built mobile test selection omits the hold-specific specs; browser pass totals therefore do not establish built mobile hold coverage. Other documented gaps include recovery-code rotation revocation assertions, a browser CSRF fixture using the wrong write method, fixed development origins, and wall-clock budgets affected by host load. These are test limitations, not claims that every corresponding product behavior is broken.

## Apple Watch implementation gates

1. Create native iOS/watchOS companion targets, sign them, configure HealthKit/background capabilities, and add macOS/Xcode verification.
2. Establish native Forma identity and protected credentials; Apple device pairing does not authenticate a Forma account. Preserve server-derived ownership and browser protections.
3. Make Watch the active workout recording owner, use HealthKit mirroring for the companion session, and use appropriate WatchConnectivity transports for selected plans and queued events.
4. Add stable session/exercise/set/event identities and persistent account-bound queues. Selection prepares a plan; only an explicit Start begins recording. Duplicate delivery must never complete a later set or restart a finished workout.
5. Store consented health summaries/events separately or introduce a strict tested version contract. Older browser decoding strips unknown fields, so simply adding optional sensor fields to the current whole-workspace document risks erasure on old-client saves.
6. Handle actual permissions, limited-history access, unavailable metrics, disconnects, reconnect sessions, crash recovery, pause/end/save, locked-device successful saves, and separate HealthKit/cloud acknowledgements.
7. Test the real paired iPhone/Ultra 2, including background delivery, app termination, account switching, VoiceOver/large text, Always On, haptics and battery use. No physical-device test was available here.

The matrix now includes details omitted or under-specified previously: the April 2026 ARM64 requirement; OS 27 limited-history APIs and availability guards; modern Watch lifecycle; reconnect callbacks with new session objects; batches delayed for minutes; workout processing/Audio modes; exact stop/collection/save sequence; locked-device nil-success behavior; and optional zones, complications and Ultra Action button support. Optional new APIs are not prerequisites for basic connection.

## Verification and limits

This pass adds per-file hashes, exhaustive catalog relationships/defaults, full binary/media/font validation, lockfile dependency/peer checks, syntax validation, pure-function/callback/CSS probes and the mocked Worker redirect reproduction. The runtime catalog probe reports **65,404 assertions** without structural/reference/default-validation errors. The fresh strict media check matches **1,411/1,411 exercises**, and the docs checker passes **85 Markdown files**.

Earlier in this same session, the identical unchanged commit passed frontend/server builds, lint, formatting, types, **134 unit + 67 local-PostgreSQL API + 27 Worker + 14 operations tests**, **30 WebKit cases**, and npm audit with zero known advisories. Those tests were not all repeated during this deeper pass, and they do not cover the newly found scenarios. API test execution used Node 24.19.0; the deployment image uses Node 26.12.1. Neither previous CI totals nor historical hosted receipts are presented as fresh production evidence.

All 627 asset rasters and 22 asset videos passed decoding; the docs images/videos were checked separately. Two fonts passed after restoring a scratch-only Brotli tool dependency. SVG checks found no flagged scripts/events/external hrefs. These checks do not certify exercise technique, expert review, visual quality, licensing ownership, real iPhone behavior or Watch functionality. The public asset footprint is about 355 MB, not the initial download size; do not ship that whole tree to the Watch.

One previous warning is corrected: ordinary mobile form inputs already become 16px through the responsive stylesheet. Account-specific inputs remain 12px; actual Safari focus zoom still requires device testing. Existing broad accessibility debt is distinct from the new computed-style contrast finding.

No repository source, application data, infrastructure or deployment was changed. Findings remain open; an audit report is not a fix or release approval.
