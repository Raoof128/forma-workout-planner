# Independent account architecture and security review

Review date: 2026-10-12. The independent reviewer inspected the integrated working tree on `feature/self-hosted-accounts`, based on audited baseline `86cfddad922eea6fb54de344c3b7a045c94f0ce8`. Implementation was still changing during this review. This record is not an acceptance of an immutable release commit or evidence of deployed staging readiness.

## Scope and method

The reviewer read the supplied account brief, design, backend identity/session adapter, installed Better Auth 1.7.7 implementation for sensitive endpoints, workspace schema and queries, migrations, browser account/repository integration, Worker gateway, Compose services, role provisioning, migration runner, and backup/restore scripts. Active probes used synthetic accounts in separately created PostgreSQL schemas; every probe dropped its own schema afterward. No production account, credential file, external backend or browser test port was used.

The architecture retains identity, sessions and workspaces in PostgreSQL behind the private API. Workspace queries derive ownership from the verified session, with an additional opaque expected-member reference to reject stale browser state after a shared-cookie account switch. The reference is a consistency guard, not authentication. CAS revisions and owner-scoped idempotency prevent acknowledged stale writes from overwriting current state. Runtime and migration database roles are distinct; the application does not claim database RLS.

## Findings and corrections independently checked

| Finding | Severity | Evidence and correction |
| --- | --- | --- |
| A stale tab could save member A's workspace into member B after another tab changed the shared session cookie. | High | Independently reproduced against PostgreSQL and real Better Auth: A's revision-zero payload with B's cookie returned 200 and changed B's profile to `Security Alpha`. Protected workspace and account requests now require `X-Forma-Member`, matching the authenticated member's opaque reference. Repeated probe returned 409 `account_changed`; B retained `Security Beta`. GET, export, session listing and profile mutation mismatch probes also returned 409. The browser captures the member reference in each repository and discards a mismatched account's pending retry. |
| Rejected TOTP replay could preserve newly issued credentials when any incoming cookie name ended in `session_token`. | High | Static inspection found the unauthenticated cookie-name shortcut in the adapter. The adapter now resolves the actual incoming Better Auth session, revokes a newly created session on replay, and strips session/trusted-device cookies. Independent regression with an attacker-controlled `junk.session_token` received 401, no new session cookie, and a subsequent workspace request received 401. The vulnerable version was identified by inspection; active verification ran after the correction. |
| Raw Better Auth session-revocation routes bypassed the recent-authentication policy of the custom account endpoints. | Medium | Installed Better Auth `sensitiveSessionMiddleware` checks authoritative session validity, not freshness. The adapter now adds a freshness requirement to raw revoke-all/revoke-others paths. An independently aged one-hour session received 403 from both the custom and raw revoke-others endpoints. |
| Applying the new member header to emailed deletion links prevented legitimate account deletion. | Functional regression | Normal browser navigation cannot send a custom member header. The deletion callback is exempted; Better Auth binds the single-use email token to the authenticated account. The independent lifecycle test completed the callback without `X-Forma-Member` and verified user/workspace deletion. |

The reviewer also identified that the second Cloudflare edge can replace `CF-Connecting-IP` for Worker-to-origin requests. The Worker now strips an incoming `x-forma-client-ip` and sets its own value from the first edge's address; the API uses that authenticated gateway header for rate limiting. The source and local gateway tests support this change; deployed address propagation still requires staging verification.

## Executed evidence

- Independent temporary lifecycle and two-member probes: **3 passed, 0 failed, 0 skipped** on the integrated working tree at approximately 01:49 UTC. They exercised real PostgreSQL and Better Auth, forged-cookie TOTP replay, stale session revocation, shared-cookie member mismatch, private export, profile mutation, and deletion callback without custom headers. The temporary harnesses are outside tracked source under `node_modules/.cache`; permanent regressions belong in the server and browser suites.
- `npm run test:worker`: **11 passed, 0 failed, 0 skipped**. The reviewer inspected assertions for fixed upstream routing, request-header filtering, manual redirect handling, multiple session cookies, no-store responses, body bounds, invalid configuration and static security headers. These are local tests with an injected upstream, not a Cloudflare deployment.
- Source inspection confirmed workspace owner predicates, owner-scoped operation keys, foreign-key deletion cascades, bounded idempotency metadata, strict mutation shape, origin checks, host-only HttpOnly cookies, disabled session cookie caching, and encrypted Better Auth recovery-code storage.

## Remaining release boundary

No unresolved high-severity issue remained from these specific probes after correction. This is a bounded review result, not a claim that every account interaction or infrastructure control has passed. The complete original/account browser matrix, UI interaction inventory, real email-provider delivery, actual Cloudflare-to-Tunnel-to-Droplet connectivity, operational access controls, and backup recovery evidence must be reconciled in the final release report.

The owner supplied infrastructure credentials later in the task. External deployment is still unverified because the required runtime bindings/connectivity were unavailable; this must not be described as lack of owner authorization. Existing unrelated services must remain untouched.

Final release acceptance remains **pending** until the exact proposed commit is frozen and independently reviewed with its final test evidence. Mandatory hosted staging gates remain **NO-GO** until exercised successfully. Local passing tests cannot replace them.
