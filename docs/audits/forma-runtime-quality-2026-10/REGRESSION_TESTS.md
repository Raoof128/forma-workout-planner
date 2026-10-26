# Regression tests and runtime verification

Audit dates: 23–26 October 2026. All accounts, emails, workspaces, database
schemas and connection-loss experiments were synthetic and local.

## Quality gates

| Command or check | Final result |
| --- | --- |
| `npm run lint` | Pass |
| `npm run typecheck` | Pass |
| `npm run format:check` | Pass |
| `npm run test:unit` | 134/134; zero failures/skips |
| `TEST_DATABASE_URL=… npm run test:server` | 67/67 under actual Node 26.12.1; zero failures/skips |
| `npm run test:worker` | 27/27; zero failures/skips |
| `npm run test:operations` | Six Python and eight Node cases pass |
| `npm run build` in guest and account modes; `npm run build:server` | Pass; production browser matrices exercise both frontend modes |
| `npm ci` and full `npm audit --json` | Clean installation; zero reported vulnerabilities, including development packages |
| Final pinned API image build and smoke | Node 26.12.1 / bundled Undici 8.12.2; non-root UID 10001; health 200 and missing gateway credential 401 |
| Actual Wrangler dry-run and local Miniflare/workerd smoke | Pass; asset/gateway behavior, credentials and denied routes checked without deployment |
| `npm run docs:check` | 84 Markdown files pass; repeated after final report reconciliation |
| `git diff --check` and exhaustive inventory reconciliation | Pass; all 1,453 baseline paths represented exactly once |

The final image digest is
`sha256:95a1529dbd360c5a660600cc6a2052507b58deaa67b2de6027472eccb3f50bfb`.
Both build stages use the pinned official Node 26.12.1 base; earlier audit
images are superseded. The tooling override is absent from the pruned API
image. Host-side diagnostics use Node 24.19.0, which was not globally replaced;
its bundled HTTP client is a diagnostic-environment limitation. API release
verification uses the patched production runtime.

The repository's TypeScript configuration checks its configured TypeScript
scope; it does not make the React JavaScript fully type-checked. ESLint does
not match server TypeScript files in this configuration. Those files were
reviewed, compiled by `build:server` and exercised by the real database tests.
Markdown is outside `format:check`; documentation links/fragments, images and
documented npm commands are checked by `docs:check`.

## Full browser matrix

| Matrix | Initial result | Profiles | Follow-up |
| --- | --- | --- | --- |
| Guest development | 507/507 pass; 0 skips | Chromium, Firefox, WebKit | 24.9 min; no retries |
| Guest production | 175/175 pass; 0 skips | Three desktop engines, Chromium/WebKit mobile | 6.6 min; no retries |
| Account development | 109/110 pass; one total-budget timeout | Three desktop engines, Chromium/WebKit mobile | Entire affected Chromium-mobile profile, 22/22, passes unchanged; investigation below |
| Account production | 110/110 pass; 0 skips | Three desktop engines, Chromium/WebKit mobile | Includes the same ownership flow at its original budget |

Commands: `npm run test:browser`, `npm run test:browser:production`,
`TEST_DATABASE_URL=… npm run test:accounts` and
`TEST_DATABASE_URL=… npm run test:accounts:production`. The existing account
wrapper starts isolated API/database and browser processes for each profile.
The replay invokes the same wrapper's Chromium-mobile project selection;
the diagnostic-only runs explicitly set a 60-second ceiling without editing
repository configuration.

The configured matrix contains 902 test executions before platform-specific
skips: 507 guest development cases across three engines, 175 production guest
cases across five profiles, and 110 account cases in each development and
production mode. Each final result below is reported with its actual passes,
failures and skips. Retry settings remain zero; a separate investigation replay
is identified rather than silently counted as a clean original run.

Guest development began before the final transitive security update. The
application source was identical throughout. Controlled builds from identical
final source with old and patched dependency trees produced byte-identical
frontend JavaScript/CSS assets; `fast-uri` is not in the browser bundle.
Installed dependencies were changed only at the matrix boundary. The additional
scoped Miniflare/Undici override is a development-tool correction; the Node
image update is independently verified on the production runtime. Subsequent
production and account matrices use the patched lockfile. Patched API/Worker/
container checks also ran from a clean isolated checkout whose source files
were hash-matched to the working tree.

The browser environment provides Chromium, Firefox and WebKit. Mobile profiles
use Playwright's iPhone 13 device characteristics with Chromium or WebKit.
The WebKit runtime uses the environment's available shared libraries; launching
the engine itself was verified. This is browser emulation, not a physical
iPhone, Android handset or installed Safari application.

Existing journeys include registration/verification, sign-in/out, MFA and
recovery, password/session management, account switching and isolation,
workspace conflict/offline recovery, import/export/deletion, workout editing
and persistence, per-side/timed measurements, history/progress, exercise search
and guides, routine drag/order, touch/keyboard/focus and axe accessibility.
The account harness runs the actual local API/PostgreSQL through a same-origin
development/preview proxy with an email sink. New deterministic account UI
regressions additionally stub selected responses to control file/network races.

## Added regression coverage

| File | Cases and behavior |
| --- | --- |
| `unit/cloud-refresh-races.test.js` | Eight cases: retain retry/conflict after older GET, ignore obsolete ordinary errors, suppress reads while saving, block edits during conflict reload, retry recovery, and still clear private data on late 401/account change. |
| `unit/per-side-targets.test.js` | Three cases: upper range and per-side limits, valid 50-per-side/100-total start, and unchanged acceptance of historical backups. |
| `unit/progress-summary.test.js` | Three cases: exact saved identity/order, unilateral strength/high reps and non-strength/unfinished exclusions. |
| `unit/catalog-search.test.js` | Three cases covering complete result parity for all catalog names/aliases, normalization and mutable metadata, and same-ID object isolation. |
| `unit/storage.test.js` | Existing legacy test now supplies version 1 explicitly and asserts migration to version 2. |
| `tests/wake-lock-lifecycle.spec.js` | Two cases: late grants after pause/navigation, foreground request deduplication and resume release. |
| `tests/per-side-targets.spec.js` | One case: existing overrange routine remains editable, invalid range is rejected, corrected range starts with exact stored side/total values. |
| `tests/ui-audit-edge-cases.spec.js` | Two cases: another tab removes a picker target; imported punctuation-bearing routine ID preserves requested order and focus without page errors. |
| `tests/accounts-audit-regressions.spec.js` | Four cases: Sydney date/week from Los Angeles timezone; old/cancelled backup success/error cannot replace current review; export error is visible and failed sign-out still hides private data. |
| `server/tests/coach-summary.test.ts` | Two cases: side-based strength with total volume preserved; Sydney Monday boundary in standard and daylight time. |
| `server/tests/workspace.test.ts` | One case: existing workspace reads work without write permission, and twenty concurrent first reads keep exactly one row per synthetic owner. |
| `server/tests/server-lifecycle.test.ts` | One real child-process case: terminate only its uniquely identified idle PostgreSQL backend, assert survival/redacted message/new connection/normal account response. |
| `worker/tests/coach.test.ts` | One case: 401/403 bearer challenge survives while private adjacent headers remain stripped and response stays uncached. |

This adds 17 unit cases, four server cases, one Worker case and nine browser
cases, plus the corrected existing migration fixture. Repeating a browser case
in multiple projects is counted as matrix coverage, not a newly authored case.

## Visual, motion and repeated-use checks

The final visual set contains **75 guest before/after pairs**: nine routes at
eight widths, plus an active workout and two populated Progress views. After
matched image readiness, **68 pairs are pixel-identical**. The remaining seven
have only 10–48 differing pixels each, with maximum channel difference 1/255;
dimensions match and no layout/content differences remain. No horizontal
overflow was observed in the measured route captures.

The original Library screenshots sometimes captured blank lazy-thumbnail
placeholders. All eight Library widths were recaptured for both versions by
scrolling each of the 24 cards into view, awaiting decoded images and the end
of loading overlays, then returning to the top. Seven replacement pairs are
identical; the eighth has only the tiny raster-rounding difference described
above. The original captures/differences remain available and are not claimed
as an application improvement. Product image-loading behavior was not changed.

Four additional private account pairs cover summary/profile at 375px and
1440px, with a synthetic account and a fixed Los Angeles/Sydney date boundary.
Their differences are intentional: Sydney member/session dates, the correct
weekly count and progress bar, and the accurate date hint. Root inspected all
four pairs, the final 375px Overview/1440px populated Progress, and matched
settled Library captures. Typography, spacing, artwork and layout are preserved.

Repeated-use checks cover 90 route changes and 40 guide-open/close cycles with
120 searches. The detailed counter investigation and its limits are in
[PERFORMANCE_RESULTS.md](PERFORMANCE_RESULTS.md). Three motion runs per version
exercise routine overview, animated preview and pause/play. Reduced-motion
preference starts the preview paused in both versions. Linux headless frame
intervals cannot certify physical-device refresh-rate smoothness; animations
were preserved, not removed to improve the measurements.

The requested widths are all represented: 320, 375, 390, 430, 768, 1024, 1440
and 1920. The screenshot set covers guest routes and synthetic workout/history
states; private account layouts receive the four extra pairs, and failure
states receive the separate browser matrix.
No claim is made that every possible private account state has a pixel baseline.
The stylesheet and runtime image/font/video files are unchanged.

Root review inspected baseline and final 375px Overview and populated 1440px
Progress for layout, typography, spacing and overflow. Meaningful visual
differences were investigated and the account corrections checked directly. The helper's
record ordering and values are also checked semantically, so a fast but
incorrect chart cannot pass solely because its layout resembles the baseline.

## Asset and documentation validation

- Every catalog/research JSON file was parsed with duplicate-key and nonfinite
  rejection; referenced IDs, logging metrics and provenance were reconciled.
  All 1,411 selectable exercises pass strict artwork mapping; no held source
  cell was promoted to runtime use.
- Catalog assets: 627 raster files fully decoded, 22 MP4 files probed, two font
  headers/licences checked; all 64 generated SVG demonstrations reproduced
  byte-for-byte from reviewed generators. Three curation outputs also rebuilt
  byte-identically in scratch.
- Other documentation evidence: 101 PNG files decoded, two WebM files probed,
  two public keys parsed, synthetic rendered email links checked and generated
  logs/JSON decoded. These checks do not mean every archived pixel/frame was
  visually re-reviewed.
- All 253 ASVS rows and 63 security-control rows were read; identifiers are
  unique after correcting the duplicate coach control. Authored historical
  coverage annotations were reviewed and crosswalk summaries reconciled.
- The final file ledger reconciles all 1,453 baseline paths and ten new
  implementation/test files, plus six audit documents, without duplicates.

## Failures investigated and evidence exclusions

- Restored stale dependencies initially lacked Motion. A normal pinned
  `npm ci` repaired the environment; peer/dependency checks were not bypassed.
- The new defect regressions intentionally failed against baseline before
  their corrections. Their final passing receipts are distinct from those red
  reproductions.
- One per-side browser fixture incorrectly clicked a background card while
  its routine dialog was still open. It was corrected to use that dialog's
  existing Edit button. Another cross-tab fixture omitted revision zero and
  entered storage recovery; a corrected baseline replay reproduced the actual
  TypeError before the final guarded case passed.
- A resumed browser invocation initially lacked the executable-path setting;
  the available browser was selected without changing product behavior.
- An early Docker build caught a Date-vs-string inference error in the new
  coach calendar call; the explicit Date conversion fixed it before the
  successful final compilation/image checks.
- A suspected Docker ignore exclusion was disproved by an actual COPY probe;
  no speculative packaging patch was made.
- Early browser load samples stopped on the loading heading or before hero
  image completion. Early heavy-history samples did not mount the seeded
  fixture. These are retained as invalid/premature, excluded and replaced by
  corrected measurements. Separate noisy backend timing runs are superseded
  by controlled paired runs.
- The final production advisory scan correctly failed on newly published
  `fast-uri` advisories. The broader scan also found a pinned development
  Undici dependency; runtime inspection identified a separately bundled affected
  Undici in Node. Four fast-uri records, one scoped Miniflare override/Undici
  record and the pinned Node 26.12.1 image address these distinct boundaries.
  Failed scans are retained with final clean-install/advisory/tool/runtime
  checks. No concrete FORMA exploit was demonstrated.
- Repeated isolated Docker builds exhausted the 32GB sandbox disk at the paused
  matrix boundary. Only obsolete audit-created images/cache and verified duplicate
  generated assets were reclaimed; source, PostgreSQL data and evidence were
  preserved. A clean npm ci restored the partial install, all static/unit gates
  passed again, and browser tests resumed on the complete dependency tree.

The first complete browser matrices produced **901 passes and one failure**,
with zero skips or automatic retries. The failure was the existing development
Chromium-mobile ownership test's overall 30-second deadline. Its trace shows
normal multi-account work and a new-tab navigation completing at 29.613s; the
next navigation poll began at 29.618s and had only about 0.15s before cancellation.
Earlier ownership, CSRF, forged-owner, anonymous and tampered-session assertions
had passed. The navigation action itself was not stuck for 30 seconds.

The complete ownership flow was then compared on unchanged baseline and current
source with a diagnostic 60-second ceiling: all assertions passed in **15.904s**
and **15.966s**, respectively. Finally, the **entire affected 22-case profile**
passed unchanged at the **original 30-second budget**, including the ownership
case in **16.110s**. The same flow passed production mobile in **9.94s**. No
application code, assertion, retry setting or committed timeout was changed to
obtain these results.

All 902 configured cases therefore have passing coverage across the full runs
and this investigated profile replay. The initial red run is retained and is
not relabelled as a clean first run. This is a non-reproduced deadline outlier;
test duration variability remains a monitoring concern, not a demonstrated
application regression or justification for an arbitrary timeout increase.

## Coverage limits

No production deployment, live member mutation, remote restore, Cloudflare
Access/Tunnel probe, transactional mail delivery, R2 operation or hosted load
test was performed. Existing fixture/contract tests and dated operational
receipts do not certify today's remote services. Real-device battery/wake-lock
permissions, mobile on-screen keyboards and hardware frame rates remain
physical-device checks. No field INP or real-user percentile is available.
The full file audit is complete within the prompt's generated/vendor/binary
exclusions; these runtime limits are not hidden as passing tests.
