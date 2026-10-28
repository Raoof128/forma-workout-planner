# Backend and Worker full-file review

Baseline: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`, 26 October 2026. Repository: `/workspace/forma-workout-planner`.

All **37 assigned files** were read in full: 14 server TypeScript modules, six SQL migrations, 13 server test files, the Worker and three Worker test files. The Worker subset was delegated and its individual evidence incorporated. `backend-review.json` has exactly one row per manifest path with method, scope, result, findings and limitations. Every assigned file's SHA-256 and byte count was rechecked against `backend-manifest.json`.

The repository's AGENT constraints were read first. No repository source, production state or accounts were changed. No credentials, member data or production services were read. Existing database/build suites were not rerun in the shared tree: the parent reports 67 server and 27 Worker tests passing. This review independently ran only a synthetic pure summary projection and an explicitly requested Worker mock reproduction; both use no network or database. Historical audit reports were context, not evidence of this review's completeness.

## Confirmed findings

### B-W1 — Medium security defect: redirect rewriting can change a local destination to an external origin

**Evidence:** `server/app.ts:314-324` considers a leading-slash callback safe if it does not literally begin with two slashes. The outgoing Better Auth Location passes the same guard at `server/app.ts:773-776`. `worker/index.ts:270-277` first resolves that Location against the backend and then constructs another URL from the resulting pathname/query/fragment against APP_ORIGIN. Dot-segment normalization can produce a pathname beginning with two slashes; the second URL parse treats that as a new authority, and its final origin is not checked.

**Local validation:** An in-memory mocked redirect through the actual Worker emitted an origin different from the configured app origin. No account, real token, network or live endpoint was used. Reproduction payloads and tools are retained outside this public repository.

**Source reachability:** the installed Better Auth origin validator accepts the relative path (`node_modules/better-auth/dist/auth/trusted-origins.mjs:68-75`). Successful/already-verified email verification branches emit callbackURL verbatim (`node_modules/better-auth/dist/api/routes/email-verification.mjs:288,317`), and Better Call places it directly in Location (`node_modules/better-call/dist/context.mjs:60-62`). This establishes a source path to the affected rewrite. Invalid-token verification paths normalize earlier and are not claimed as a working reproduction. The exact Worker rewrite is executed; the successful valid-token callback path is statically traced, not exercised with a real account.

**Impact:** a successful verification link can lead to an external site despite the explicit same-origin invariant. This is an open redirect; no token/cookie disclosure, session theft or account takeover was demonstrated. Worker privacy headers still apply. Existing API redirect tests (`server/tests/redteam.test.ts:195-239`) and Worker redirect tests (`worker/tests/gateway.test.ts:247-285`) cover ordinary external/local URLs but miss this canonicalization case.

**Correction:** retain the parsed path as a pathname rather than reparsing it as a URL reference. For example, construct the app-origin URL once and assign pathname/search/hash separately, then verify the final origin equals APP_ORIGIN. Add the exact normalized-double-slash case to Worker tests and a valid-callback integration regression. Canonicalize callback guards consistently as defense in depth.

### B-S1 — P2 correctness defect: coach routine summaries erase prescription semantics

**Evidence:** `server/coachTokens.ts:388-405` projects each routine entry to exerciseId/name/sets/reps/weight and optional duration/distance. It omits the saved `perSide`, `repsMax`, `rpe`, `restSeconds`, `note`, `groupId` and entry identity. `src/routineProgramming.js:34-35` shows that perSide changes the displayed meaning of reps, and `src/storage.js:112-156` validates the actual richer prescription. Completed-set sides are preserved at `server/coachTokens.ts:288-302`; this does not recover the lost routine target.

**Pure reproduction:** `backend-summary-repro.mjs` supplies two validated synthetic routines to the actual coachSummary function at a fixed timestamp. One has three sets of 8-10 reps **per side**, RPE 8, 120 seconds rest and a note. The other has three sets of eight total reps with no range/RPE/rest/note. Both return the exact same `{ exerciseId: "lunge", name: "Dumbbell reverse lunge", sets: 3, reps: 8, weight: 12 }`. Assertion and complete synthetic inputs/outputs are stored in `backend-summary-evidence.json`. Run from the repository with `node --import tsx /workspace/scratch/forma-full-audit-2026-10-26/backend-summary-repro.mjs`.

**Impact:** a read-only coaching tool cannot distinguish materially different prescriptions. A default-per-side catalog hint cannot reconstruct the member's saved override. This is a current data-projection defect, not an authentication vulnerability. The existing `server/tests/coach-summary.test.ts` tests sides on completed sets and strength estimates, but has no assertion preserving routine per-side/range targets.

**Correction:** carry at least perSide and repsMax in the routine DTO and include the relevant programmed RPE/rest/note/group/entry identity fields if the response is intended to represent the routine. Document any deliberate omission. Add a projection test with contrasting per-side/range prescriptions. Do not use the existing summary as a lossless phone-to-Watch routine contract.

## Native/Watch capability gaps, not current vulnerabilities

### B-W2 — Dedicated native member authentication and durable event transfer are not implemented

`server/app.ts:169-176` intentionally removes native session tokens and database IDs. Member data requests resolve the cookie session and require its member reference (`server/app.ts:57-101`); non-coach mutations also require the configured web Origin (`server/app.ts:535-547`). Worker bearer forwarding is limited to coach endpoints (`worker/index.ts:43-53,198-205`). The route sets in `server/app.ts`, `server/workspaceRoutes.ts`, `server/coachRoutes.ts` and `worker/index.ts:153-182` have no native device enrollment/exchange, append-workout-event, batch upload or device acknowledgement endpoints.

A native HTTP client can manually implement cookies and send Origin; this review does not claim native networking is inherently impossible. It does establish that a dedicated first-party native sign-in/device-binding/background-recovery contract is absent. Keep gateway secrets on the server. Coach tokens have different authority and budgets: summary-only read or broad full-workspace access, 90-day lifetime, five active tokens, 120 reads/hour and 60 writes/hour (`server/coachTokens.ts:18-28`, `server/coachRoutes.ts:31-39`). Repurposing them as Watch member credentials would require an explicit product/security design.

Existing snapshot durability is real: `server/workspace.ts:185-290` locks the member row, checks the operation hash before expected revision, persists the workspace and receipt in one transaction, and returns monotonic revision/time. Exact member PUT retries reconstruct the original acknowledgement (`server/workspace.ts:293-319`). Receipt retention is bounded to 1,000 operations/30 days; expired receipts safely return stale-revision conflicts (`server/workspace.ts:264-282`). Coach PATCH shares this write path and replaces named sections as whole values (`server/workspace.ts:347-407`). The Worker makes one upstream request under its deadline; the absence of automatic mutation replay is not itself a bug.

These mechanisms do not provide a native device outbox, immutable event identities for individual sets/commands, sequence reconciliation, workout terminal-state deduplication, or HealthKit save/upload receipts. Add such a contract before promising reliable phone/Watch concurrent controls or offline completion. Preserve server-derived ownership and existing replay/account-change protections.

### B-N3 — Health schema evolution, permissions and deletion require an explicit boundary

The current shared schema is used by the server (`server/schema.ts:1-39`) and whole-workspace writes replace the validated payload (`server/workspace.ts:299-312`). Shared storage accepts v1/v2 then migrates to v2 (`src/storage.js:159-160,273-293`); strict server validation rejects unknown fields (`src/storage.js:259-276`). The ordinary browser read validator is non-strict (`src/account/cloudRepository.js:7-13`), so future optional fields added to the same whole-document schema can be stripped by an older client and omitted on its later PUT. This is a future extension hazard, not evidence that health data is already stored or currently leaking.

Use a versioned native protocol and an explicit compatibility policy; preferably keep consented health summaries/event records in separate bounded, owner-bound storage. Test legacy whole-workspace clients against the new API before release. Applied migration 0004 preserves legacy draft/alias identity and increments revision (`server/migrations/0004-routine-programming.sql:3-79,82-88`), but it is not a general minimum-client version mechanism.

Full coach tokens can read the entire workspace (`server/coachRoutes.ts:316-332`) and replace its five allowed sections (`server/schema.ts:49-68`). Existing tokens defaulted to read when scope was introduced (`server/migrations/0006-coach-token-scope.sql:1-16`); retain that no-widening principle for future health access. Sensor/HealthKit data should not automatically become available to today's full coaching tokens without a deliberate permission decision.

Current owner-bound training and credential tables cascade on user deletion: auth/session/account/MFA/replay in migration 0001, workspace/receipts in 0002, and coach tokens in 0005. Outstanding verification metadata is not user-FK-bound (`server/migrations/0001-auth.sql:45-53`); throttle keys have no user FK and permanent lock rows intentionally survive pruning (`server/throttle.ts:215-221`). Better Auth's installed deleteUser path removes sessions/accounts/user, while expired verification cleanup occurs on library lookup. These are retention considerations; this audit did not inspect records, production retention jobs or backups. New health records require explicit account deletion/export, consent revocation, device-cache and backup-retention behavior. No native tables currently exist to validate.

## Review notes that are not confirmed bugs

- The outer auth catch at `server/app.ts:846-848` does not explicitly refund a reserved password attempt. Ordinary HTTP errors do refund at lines 734-754, and Better Auth commonly turns exceptions into HTTP responses. A truly rejected handler could leave an unjudged reservation; no concrete reachable rejected-handler reproduction was established here. Add fault injection when changing this path, but do not report this as an exploited lockout bypass.
- The coach authentication comment says failures count before lookup, but a well-formed token lookup occurs at `server/coachRoutes.ts:176-178` before failure-budget consumption at lines 180-186. The limiter restricts responses, not lookup admission. This is a misleading comment/resource-admission limitation, not demonstrated auth bypass or denial of service.
- `/healthz` is intentionally static liveness (`server/app.ts:551`); startup runs SELECT 1 (`server/index.ts:27`). A separate operations reviewer was told to assess any script that mistakes ongoing liveness for database readiness.
- Tests that need PostgreSQL fail on missing test DB configuration. Several focused older suites install migrations 0001-0004 only; coach/session-step-up suites apply all migration files. Passing API tests do not prove every suite independently validates the latest schema or every deletion table.
- Physical iPhone/Watch pairing, HealthKit, native credential storage, transport suspension/restart, deployed Cloudflare policy, production email delivery and backup/deletion retention were outside this read-only backend review. No blanket security or native-readiness pass is claimed.

The complete per-file evidence and limitations are in `backend-review.json`; Worker-specific details are in `worker-subfindings.md`.
