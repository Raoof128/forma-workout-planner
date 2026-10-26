# Optimisation decisions

Audit base: `678b48325189f83beb942bc6759e7c519eb26b19`. Work began on 23 October and continued on 26 October 2026. This record explains the changes retained and the experiments rejected. Final aggregate test results belong in [REGRESSION_TESTS.md](REGRESSION_TESTS.md); matched browser measurements belong in [PERFORMANCE_RESULTS.md](PERFORMANCE_RESULTS.md).

## Retained changes

### Aggregate Progress history once

`src/components/Insights.jsx` previously traversed the whole workout history separately for each of 1,418 load/reps catalogue records. `src/progressSummary.js` now aggregates completed sets once by saved exercise ID, then emits records in the original catalogue order. The implementation keeps aliases separate, excludes timed/distance records, preserves per-side strength calculations and leaves the saved records untouched.

The isolated 1,000-session comparison checked exact output parity. Eight original samples had a median of 91.67ms; eight helper samples had a median of 0.502ms. The original first run included warmup, so this small Node microbenchmark is evidence of the algorithmic improvement, not a field percentile or browser INP claim. Separate browser measurements determine the actual route-level effect. No chart redesign, list virtualisation or blanket component memoisation was needed.

### Cache only repeated catalogue normalisation

`src/catalog/search.js` retains the most recent query's normalised tokens and stores each exercise's normalised search text in a `WeakMap`. The current joined source text is compared before reuse, so edited metadata and mutated arrays invalidate the entry. Cache identity is the exercise object rather than its ID; distinct objects sharing an ID cannot inherit each other's metadata. Empty normalised queries return immediately.

This avoids repeated Unicode folding without introducing an unbounded query/result cache. The paired microbenchmark used 30 samples, each containing 30 full filters of the 1,411 selectable records. For example, `pushup` fell from a median of 3.50ms to 1.16ms per filter; the empty query fell from 2.07ms to 0.022ms. The absolute saving is modest and must not be presented as a measured page-load improvement. Parity tests cover catalogue names/aliases, punctuation, diacritics, metadata mutation and distinct objects with matching IDs.

### Remove redundant database work on established workspace reads

`server/workspace.ts` now reads an existing owner-scoped workspace with one `SELECT`, then validates the returned record as before. It retains the transaction and creation path for a missing row, including concurrent first visits. Writes still use their existing locks, optimistic revision checks and idempotency rules. No authenticated response cache or alternate ownership source was introduced. A missing row pays one extra initial SELECT before the existing creation transaction; this deliberately favors repeated established reads over the one-time initialization path.

This reduces established reads from four queries to one. The controlled loopback PostgreSQL comparison alternated baseline/candidate order, used 10 warmup pairs and 100 measured reads per variant/scenario, and included validation. Empty workspace p95 fell from 2.564ms to 0.904ms; a 100-session, 570,687-byte workspace fell from 23.215ms to 21.655ms. These are function-plus-database timings, not HTTP, Worker or production API p95. Earlier separate-run measurements were too noisy to support the decision and are superseded by the paired comparison.

The initial pre-security-patch paired real-HTTP comparison includes signed-in authentication, validation, serialisation and full response-body receipt. It used the same 100 samples/10 warmup pairs per fixture and the same default pool maximum of 10 for both variants. Empty-workspace HTTP p95 fell from 9.014ms to 5.193ms; the 100-session response fell from 30.254ms to 28.006ms. Total query count fell from six to three because two authentication queries remain. The larger-response timing change was modest (about 7%); this initial loopback experiment excludes the Worker, TLS and public network. It predates the final dependency/runtime patches and is superseded for final claims by the matched rerun in PERFORMANCE_RESULTS.md. It does not establish a production latency gain.

### Keep cloud recovery state authoritative during overlapping reads

`src/account/cloudRepository.js` advances a write epoch when a commit or retry starts. An older ordinary refresh response or network error cannot then replace that write's acknowledgement, retry payload or conflict. Refreshes do not begin while saving or while unresolved recovery state exists. A retained conflict blocks new edits even while an explicit reload temporarily displays a refreshing status.

This correction addresses demonstrated data-recovery races rather than hiding them with request delays. Late authentication or account-change errors still clear private data. Owner binding, session checks, server revisions and the original retry operation remain authoritative; there is no optimistic acknowledgement or silent merge.

### Bind transient resources to their actual lifecycle

`src/components/Workout.jsx` scopes wake-lock acquisition to the running hold effect. One pending request is permitted; cleanup invalidates it, releases any granted lock, and causes a late grant to release itself. Foreground reacquisition remains supported. This fixes resource leaks without altering the hold's saved-data contract, timing interval or user controls.

The same component closes a replacement picker when its target disappears through another tab. The mutation handlers keep their existing target checks. `RoutineCardOrder.jsx` escapes imported routine IDs before building its focus-restoration selector, preserving valid stored IDs and keyboard focus without changing the ordering algorithm.

### Preserve explicit import review and existing measurement contracts

`Account.jsx` gives asynchronous file reads a sequence identity. Selecting another backup immediately clears the previous review, acknowledgement and safety-export readiness. Obsolete successes/errors cannot restore a cancelled review or overwrite a later selection. Existing confirmation and export requirements remain in place.

Per-side routine targets are checked before saving an edit or constructing a workout: the logger accepts 50 reps per side, or 100 combined. Historical routines with larger targets remain readable and editable under the same schema; the app explains what must be corrected. Silent clamping, destructive migration and tightening the persisted schema were rejected because they would change existing data or compatibility.

Account calendar displays and coach weekly summaries now use the existing Australia/Sydney helpers. Coach estimated strength uses the same per-side rep semantics as the application. These are corrections to existing contracts, not changes to kilograms, saved exercise identities or legacy hold units.

### Recover from an idle database connection failure without hiding startup failure

`server/index.ts` handles the pool's idle-client error event with a fixed, redacted diagnostic. The PostgreSQL client pool discards the failed connection and can acquire another for subsequent work. The initial connectivity query remains unchanged, so an unavailable database during startup is not reported as a successful start. Raw database errors, credentials and query contents are not logged by this handler. The process-level regression proves continued process survival, the fixed diagnostic, a normal unauthenticated account response and acquisition of a replacement PostgreSQL connection. The final server suite passed 67 cases; the aggregate regression report records the other checks.

### Correct narrow interface and documentation gaps

The Worker explicitly forwards `WWW-Authenticate`, restoring the documented bearer-token challenge while retaining the fixed backend origin, route restrictions and existing credential boundaries. A dedicated gateway test justifies the single response-header addition.

Privacy export errors/successes use the account screen's existing feedback elements. The Sydney date hint is corrected. These are the intentional UI differences; no CSS, typography, media quality, animation, layout or colour redesign was made.

Current guides were reconciled with the version 2 workspace, exact authentication contract, pinned runtime and later dated release evidence. Unsafe old-image rollback advice was removed because older validators can reject already-saved fields or exercise IDs. Historical test and deployment receipts keep their original dates and outcomes; they do not become fresh certification merely because the documentation was reviewed.

## Rejected or deferred approaches

### A single deferred training chunk reduced startup bytes but harmed first use

A scratch-only `TrainingViews.jsx` experiment deferred Routines, Library, Workout and routine dialogs. Initial JavaScript fell from 2,947,063 decoded / 560,332 gzip bytes to 1,921,606 decoded / 397,684 gzip bytes, a 29.0% gzip reduction. The new deferred chunk added 1,028,016 decoded / 165,280 gzip bytes on first training use.

That transfer moved a material delay into the first training interaction. Three alternating paired Chromium 156 production-preview samples used fresh contexts, 4× CPU throttle, a download rate of `1.6 × 1024 × 1024 / 8` bytes/sec and 40ms simulated network latency. After Overview and its images had loaded, click-to-visible-heading latency for My routines rose from a median of 190ms (185–271) to 1,443ms (1,431–1,489). This is synthetic route latency, not INP.

The offline comparison was more decisive: load Overview, disconnect, then open My routines. The baseline opened the routine screen; the candidate reached the global recovery screen because its chunk could not load. Saved data was retained, but the experience regressed. The candidate was rejected and never entered the shared source tree. No service worker, prefetch framework or new caching layer was added to force a bundle target. Reducing eager catalogue/media metadata remains a separate opportunity; the cold-load target miss remains visible in the performance report.

### Do not add an index for an already indexed lookup

The representative 10,002-owner plan used `member_workspace_pkey`, returned one row and recorded three shared-buffer hits with 0.030ms execution time. The demonstrated problem was redundant round trips and initialisation work, not a missing owner index. No migration, duplicate index, schema change or speculative query cache was justified. Pool limits and request concurrency were not increased; production capacity was not load-tested.

A suspected Docker build-context exclusion was also tested rather than patched speculatively. A COPY probe proved that the existing `!src/catalog/` exception admits the required imports. The ignore file remains unchanged, and the pinned Node 26 image builds and starts as UID 10001.

### Keep the existing workout tick until profiling shows a user problem

The production React root hook observed four commits over 1.1 seconds in an active workout with no running rest and five with rest running, consistent with the existing 250ms tick. Five sequential weight fills plus 300ms produced 18 root commits, including persistence acknowledgements and timer work. These are root commits, not counts for every component.

The measured synthetic input path remained responsive; render count alone does not establish visible lag. Moving the timer into a new state architecture or adding broad memoisation would expand risk without a demonstrated benefit. Timer locality is recorded as a follow-up, not claimed as an implemented optimisation. Wake-lock cleanup was independently justified and retained.

### Preserve visual and security costs that serve a purpose

No animation, shadow, blur, gradient, image, font or product feature was removed to improve a score. The existing reduced-motion and pause behavior remain. Assets were validated and generators reproduced their output; optimisation did not recompress or lower the sharpness of reviewed artwork.

No security validation, cookie protection, member consistency check, CSRF/origin restriction or account isolation boundary was bypassed for speed. No shared authenticated cache, client-side bearer-session replacement, API schema migration, new library, production deployment or live-data experiment was required. Initial dependency restoration used the committed lockfile; the later minimal advisory patch is described below. Peer checks were not weakened.

### Apply only the newly disclosed transitive security patches

The final 26 October production-dependency audit reported `fast-uri` advisories
published after the initial 23 October morning check. The correction changes
only four lockfile records: three 3.1.8 copies to 3.1.9, and one 4.2.2 copy to
4.2.3, including their registry URLs and integrity hashes. Direct library pins remain unchanged. The separate development override is
scoped to the affected Miniflare version; no new library or broad dependency
upgrade was introduced.

FORMA has no direct `fast-uri` imports or caller-supplied JSON schemas; the
package is used by Fastify/AJV schema URI handling. Application origin and
redirect policies use the platform URL implementation. No concrete application
exploit was demonstrated, but leaving a known vulnerable production dependency
would fail the repository's release gate. A clean isolated install and backend
revalidation precede applying installed dependencies at a browser-matrix
boundary, preserving the running test process. The final regression report
records the advisory result and exact verification scope.

### Patch the toolchain and bundled runtime at their own boundaries

A full advisory scan also found Undici 7.29.1 under Miniflare, whose exact pin
prevented an ordinary compatible lockfile update. An override scoped to
`miniflare@5.20261012.1-beta` selects patched Undici 7.30.1, preserving the
Wrangler/Miniflare releases. The broad npm audit fix suggestion would downgrade
Wrangler and was rejected. Validation includes clean installation, full audit,
actual Wrangler dry-run and local Miniflare/workerd asset/gateway behavior.

An npm scan cannot see Node's bundled HTTP client. The old API image used
Undici 8.11.2 inside Node 26.12.0. Both Docker stages now pin official stable
Node 26.12.1 and an exact image digest; the actual container reports Undici
8.12.2. The identified API fetch goes to the fixed Cloudflare mail endpoint;
no attacker-selected URL, EventSource or SRI path was established. These are
advisory corrections, not a claim of a demonstrated FORMA exploit.

The production runtime is tested separately. The diagnostic host was not
silently replaced; its Node version remains explicit in lab measurements.
Disk exhaustion from obsolete audit Docker layers was resolved without
removing source/evidence or PostgreSQL volumes. Failed environment operations
are retained as such, rather than counted as passing builds.

## Evidence handling

The selected evidence includes `ui/progress-comparison.json`,
`search-final-benchmark.json`, `workspace-paired.json`,
`http-workspace-paired.json` (historical), `http-workspace-final-paired.json`
(both variants on Node 26.12.1 / Undici 8.12.2), `lazy-payload-proposal.json`,
`lazy-tradeoff.json` and matching scripts/logs. Root commit and browser samples
are in the runtime evidence directory. Raw captures stay outside the source
repository and are supplied in the separate review and visual evidence bundles.

Historical fingerprint microbenchmark numbers are omitted because their runtime-version metadata could not be independently verified after continuation. The retained initializer change has a narrower, directly reviewable claim: it hashes the same immutable guest snapshot once per workspace mount instead of on every render. Early browser samples that observed a loading heading or failed to load the intended history fixture are also excluded from the final comparison; corrected measurements must be used.
