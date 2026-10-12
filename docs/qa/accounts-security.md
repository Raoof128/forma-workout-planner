# Account security QA

This document tracks the security properties and adversarial evidence for the self-hosted account implementation. It is an engineering test record, not a compliance certification. The current release target is local integration against an isolated PostgreSQL database. Protected owner deployment credentials were supplied, but Droplet SSH was refused and the Cloudflare API was unreachable from this environment, so no external staging result is claimed.

## Threat model

FORMA stores email addresses, account credentials and private workout workspaces. The primary security boundary is the authenticated member identity resolved by Better Auth on the API. A request's body, query, path, forwarded headers or Cloudflare Access service credential must never select the member whose workspace is read or changed. PostgreSQL and the API run on the private backend; the browser reaches them through the same-origin Worker gateway.

| Asset or boundary                                                          | Threat                                                                                    | Required evidence                                                                                                                                                        |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Member workspace (profile, routines, active workout, history and settings) | A member guesses or supplies another member's identifier                                  | Two synthetic members; every read, write and export is scoped to the authenticated session; foreign IDs and owner fields are rejected or ignored without data disclosure |
| Cross-tab account binding                                                    | A tab retains member A's private data after shared cookies switch to member B              | Protected requests carry the opaque member ID captured by that repository; mismatch returns `409 account_changed` without data; stale client state clears before refreshing the session |
| Better Auth session cookie                                                 | Forgery, tampering, replay after revocation, or cross-origin state change                 | Missing, malformed, tampered and revoked cookies cannot reach workspace routes; state-changing requests enforce the configured origin/CSRF policy                        |
| Worker-to-origin credential                                                | Browser supplies a fake service credential or untrusted forwarding identity               | Origin requests fail without the configured Worker credential; browser-supplied credential and identity headers cannot substitute for it                                 |
| Workspace mutation                                                         | Mass assignment, malformed input, replay or concurrent stale writes                       | Strict request shape and schema validation; operation IDs are bound to the original normalized payload; stale revisions return conflict and current revision             |
| Account lifecycle                                                          | Verification, reset or account deletion changes another member's data                     | Authenticated ownership is established server-side; deletion cascades only the authenticated account's workspace and operation rows                                      |
| Private responses                                                          | Browser, proxy or shared cache retains another member's data                              | Authenticated workspace and export responses carry private no-store cache directives                                                                                     |
| Email tokens and secrets                                                   | Tokens, cookies, credentials or workout contents reach logs, fixtures or frontend bundles | Synthetic local email sink only; no production sink; no secret in built frontend; logs omit credentials, cookies, tokens and workspace bodies                            |

## Test scope

The adversarial suite is intended to use a real, isolated PostgreSQL database and the actual Better Auth session mechanism. Unit or stub-only results do not satisfy the member-isolation gate. Tests create synthetic accounts and use only their generated credentials and records. Production data and infrastructure are out of scope.

Required cases:

- Member A and member B each read, write and export their own distinct workspace.
- A cannot read, overwrite, or export B's workspace by changing body fields, query parameters, identifiers, cookies, or forwarding headers; repeat in the opposite direction.
- Requests without a cookie, with a malformed or modified cookie, and after session revocation receive an authentication failure and no private payload.
- The API rejects requests without valid Worker service authentication and ignores browser-supplied service, identity and forwarding headers.
- Cross-origin mutation attempts fail under the deployed cookie and origin policy; same-origin application writes continue to work.
- Extra top-level fields, owner identifiers, invalid nested workspace data, missing revision, malformed operation IDs and oversized payloads do not mutate persisted state.
- Reusing an operation ID with a different payload conflicts; retrying an identical operation is idempotent; stale revisions conflict without silently discarding the current workspace.
- Export is private, no-store, and contains only the authenticated member's data.
- A tab bound to member A cannot read, export, mutate, list sessions, or submit sensitive account changes when another tab switches the shared cookie to member B; the old UI clears A's data and does not retry an A write under B.
- Deleting one synthetic member removes only that member's workspace and operation records; the other member can still authenticate and read their data.

## Outcome record

The repository is being changed in parallel. Results must be filled in only after inspecting the corresponding assertions and executing them against the integrated implementation.

| Check                                            | Result  | Evidence                                                                                                                     |
| ------------------------------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Real PostgreSQL account/session setup            | Pending | Local database harness not yet integrated                                                                                    |
| Two-member workspace isolation                   | Pending | `server/tests/security.test.ts`                                                                                              |
| Missing, malformed and revoked session rejection | Pending | `server/tests/security.test.ts`                                                                                              |
| Worker credential and origin enforcement         | Pending | `server/tests/security.test.ts`                                                                                              |
| CSRF and spoofed header resistance               | Pending | `server/tests/security.test.ts`                                                                                              |
| Strict body validation and mass assignment       | Pending | `server/tests/security.test.ts`                                                                                              |
| Idempotency and stale revision handling          | Pending | `server/tests/security.test.ts` and workspace integration tests                                                              |
| Private export and cache headers                 | Pending | `server/tests/security.test.ts`                                                                                              |
| Account deletion isolation                       | Pending | `server/tests/security.test.ts` and auth integration tests                                                                   |
| Local browser account journey                    | Pending | `tests/accounts-security.spec.js`                                                                                            |
| Hosted staging Worker-to-private-API journey     | Blocked | Cloudflare API was unreachable and Droplet SSH was refused; staging hostname and isolated staging database remain unverified |

## Review baseline and references

The review is structured around OWASP ASVS 5.0 authentication, session management, input validation, API and data protection requirements; the OWASP API Security Top 10 2023, especially broken object-level authorization, broken authentication, unrestricted resource consumption, security misconfiguration and unsafe API consumption; and NIST SP 800-63B-4 authentication guidance. The browser checks also use the same-origin policy and OWASP CSRF guidance. These references guide the test plan and do not imply that all controls have been assessed or that FORMA is certified.

- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Better Auth session management](https://www.better-auth.com/docs/concepts/session-management)
- [Better Auth cookies](https://www.better-auth.com/docs/concepts/cookies)

## Release limits

Local integration evidence cannot establish the security of a production Cloudflare Access policy, Worker secrets, Tunnel configuration, public DNS/TLS, Droplet firewall, production email provider, backups or operational logging. Those controls require isolated staging configuration and verification. The final release decision must preserve these as blocked until tested; missing credentials or infrastructure must not be recorded as a pass. Local Better Auth runs log a warning when no client IP is present and use a shared per-path rate-limit bucket; production relies on the Worker forwarding Cloudflare's edge-controlled `cf-connecting-ip` after stripping caller-supplied forwarding headers. The production path remains unverified until staging is available.
