# Worker subreview — 1794dd27fad87e8f0cc6f4923d37eedf713783ed

All four assigned files were read in full, and their hashes match backend-manifest.json. No repository files, accounts, production services or secrets were changed/read. One explicitly authorized focused reproduction imports the Worker with a mocked origin and synthetic data; no network is used. Existing suites were not rerun.

## B-W1 — Medium: redirect rewrite can change the destination origin

**Status:** confirmed in an isolated local Worker reproduction; successful email-verification callback reachability traced statically. This is an open redirect, not demonstrated session theft or account takeover.

**Code evidence:** `worker/index.ts:270` resolves the origin's Location against the backend; lines 273–277 approve that origin and then pass its path/query/fragment to a fresh `new URL(..., appOrigin)`. A path starting with `//` is therefore parsed a second time as a network-path reference. The result's origin is never checked. `server/app.ts:318` approves any leading-slash callback that does not literally start with `//`; lines 773–776 apply that same check to the emitted Location. Dot-segment normalization can introduce the double slash between those checks.

**Local validation:** An in-memory mocked redirect through the actual Worker emitted an origin different from the configured app origin. No account, real token, network or live endpoint was used. Reproduction payloads and tools are retained outside this public repository.

**Callback source trace:** installed Better Auth `dist/auth/trusted-origins.mjs:68–75` accepts that relative shape because its single URL parse retains the dummy origin. `dist/api/routes/email-verification.mjs:288` and `:317` redirect to a valid callback verbatim on successful verification/already-verified paths. Better Call `dist/context.mjs:60–62` writes that string directly into Location. The application's outgoing guard accepts it, then the Worker changes its origin. Invalid-token verification paths use `appendQueryParams` and normalize the string earlier, so this report does **not** claim an invalid-token request reaches the redirect. Password-reset redirects are separately constructed as absolute URLs; that flow is not claimed affected here.

**Practical effect:** a successful verification link can send a browser to an external site despite the intended same-origin redirect invariant. The Worker still sends no-store/no-referrer headers; this review did not demonstrate token, cookie or user-data disclosure.

**Recommended correction:** retain a single parsed URL object and replace only its protocol/host (or construct a target then set pathname/search/hash separately); verify the final target origin equals APP_ORIGIN. Add regression coverage for dot-segment inputs resolving to a pathname beginning with `//`. Existing tests at `worker/tests/gateway.test.ts:247–285` omit this case.

## B-W2 — Native member authentication and durable upload are absent gateway capabilities

**Classification:** native/watch readiness gap, not a vulnerability in the current browser application.

`worker/index.ts:43–53` recognizes bearer credentials only for the three coach routes. Lines 198–205 remove Authorization on other routes, and remove cookie/member identity on coach routes. Lines 153–182 expose the current account/workspace/auth routes but no device registration, native token exchange, workout-event append/batch, or upload-receipt endpoint. Lines 382–387 require the app Origin for member mutations. Lines 403–442 make one upstream request under a 30-second deadline; this is a stateless pass-through with no durable per-device queue or transfer receipt. Native clients can implement cookie/Origin requests themselves, but these files do not provide a dedicated native member-token or background-transfer protocol. Coach credentials are deliberately isolated and should not be treated as native member credentials.

The absence of Worker retries is not itself a defect: automatic mutation replay requires application-level idempotency. Backend persistence/replay behavior and future native-client queueing must be assessed separately. Tests in `worker/tests/coach.test.ts:400–421` intentionally pin the member Origin and credential separation behavior.

## Per-file review boundaries

The companion `worker-subreview.json` contains exactly four rows with individual methods, scopes, results and limitations. Static coverage cannot prove deployed Cloudflare behavior, physical-device sleep/resume, offline completion, or native watch session revocation. No other confirmed worker issue was identified in the assigned files.
