# Account security QA

This document tracks the security properties and adversarial evidence for the self-hosted account implementation. It is an engineering test record, not a compliance certification. The current release target is local integration against an isolated PostgreSQL database. Read-only Cloudflare account access succeeded, but the selected account has no deployed FORMA application resources; SSH connections to the Droplet were refused before authentication. No external staging result is claimed.

## Threat model

FORMA stores email addresses, account credentials and private workout workspaces. The primary security boundary is the authenticated member identity resolved by Better Auth on the API. A request's body, query, path, forwarded headers or Cloudflare Access service credential must never select the member whose workspace is read or changed. PostgreSQL and the API run on the private backend; the browser reaches them through the same-origin Worker gateway.

| Asset or boundary                                                          | Threat                                                                                    | Required evidence                                                                                                                                                                           |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Member workspace (profile, routines, active workout, history and settings) | A member guesses or supplies another member's identifier                                  | Two synthetic members; every read, write and export is scoped to the authenticated session; foreign IDs and owner fields are rejected or ignored without data disclosure                    |
| Cross-tab account binding                                                  | A tab retains member A's private data after shared cookies switch to member B             | Protected requests carry the opaque member ID captured by that repository; mismatch returns `409 account_changed` without data; stale client state clears before refreshing the session     |
| Better Auth session cookie                                                 | Forgery, tampering, replay after revocation, or cross-origin state change                 | Missing, malformed, tampered and revoked cookies cannot reach workspace routes; state-changing requests enforce the configured origin/CSRF policy                                           |
| Worker-to-origin credential                                                | Browser supplies a fake service credential or untrusted forwarding identity               | Origin requests fail without the configured Worker credential; browser-supplied credential and identity headers cannot substitute for it                                                    |
| Workspace mutation                                                         | Mass assignment, malformed input, replay or concurrent stale writes                       | Strict request shape and schema validation; operation IDs are bound to the original normalized payload; stale revisions return conflict and current revision                                |
| Account lifecycle                                                          | Verification, reset or account deletion changes another member's data                     | Authenticated ownership is established server-side; deletion cascades only the authenticated account's workspace and operation rows                                                         |
| Private responses                                                          | Browser, proxy or shared cache retains another member's data                              | Authenticated workspace and export responses carry private no-store cache directives                                                                                                        |
| Email tokens and secrets                                                   | Tokens, cookies, credentials or workout contents reach logs, fixtures or frontend bundles | Test email sink captures synthetic messages; rendered templates point to real Better Auth actions; no secret in built frontend; logs omit credentials, cookies, tokens and workspace bodies |

## Test scope

The adversarial suite uses a real, isolated PostgreSQL database and the actual Better Auth session mechanism. Unit or stub-only results do not satisfy the member-isolation gate. Tests create synthetic accounts and use only their generated credentials and records. Production data and infrastructure are out of scope.

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

The outcome record below reflects the frozen `ebbec2e` implementation. The suite uses synthetic members and a random PostgreSQL schema per browser run.

| Check                                            | Result  | Evidence                                                                                                                                                                                                                                |
| ------------------------------------------------ | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Real PostgreSQL account/session setup            | Pass    | `npm run test:server`: 24/24 passing against isolated PostgreSQL, including Better Auth lifecycle, account binding, email templates/sink integration, and bounded rate-limit checks                                                     |
| Two-member workspace isolation                   | Pass    | `server/tests/security.test.ts`: real sessions; cross-member read, write and export attempts return no protected data                                                                                                                   |
| Missing, malformed and revoked session rejection | Pass    | `server/tests/security.test.ts`: unauthenticated, forged and revoked session checks                                                                                                                                                     |
| Worker credential and origin enforcement         | Pass    | `server/tests/security.test.ts`: missing/fake gateway secret and hostile origin rejected                                                                                                                                                |
| CSRF and spoofed header resistance               | Pass    | `npm run test:worker`: 11/11 passing, including origin enforcement and caller-header stripping                                                                                                                                          |
| Strict body validation and mass assignment       | Pass    | `server/tests/security.test.ts` and PostgreSQL workspace tests                                                                                                                                                                          |
| Idempotency and stale revision handling          | Pass    | PostgreSQL workspace tests; browser conflict, acknowledgement retry and stale-refresh journeys                                                                                                                                          |
| Private export and cache headers                 | Pass    | `server/tests/security.test.ts`: authenticated owner-only export and no-store behavior                                                                                                                                                  |
| Account deletion isolation                       | Pass    | PostgreSQL cascade and real-auth lifecycle tests                                                                                                                                                                                        |
| Local browser account journey                    | Pass    | At `ebbec2e`, `npm run test:accounts` and `FORMA_ACCOUNT_BUILD=1 npm run test:accounts:production` each passed 45/45 across Chromium desktop/mobile, Firefox desktop, and WebKit desktop/mobile.                                        |
| Hosted staging Worker-to-private-API journey     | Blocked | Read-only Cloudflare calls worked, but the selected account has no deployed FORMA application resources and candidate staging names are unused. SSH was refused before authentication. No staging API, hostname, or isolated staging database was available. |

## Review baseline and references

The review is structured around OWASP ASVS 5.0 authentication, session management, input validation, API and data protection requirements; the OWASP API Security Top 10 2023, especially broken object-level authorization, broken authentication, unrestricted resource consumption, security misconfiguration and unsafe API consumption; and NIST SP 800-63B-4 authentication guidance. The browser checks also use the same-origin policy and OWASP CSRF guidance. These references guide the test plan and do not imply that all controls have been assessed or that FORMA is certified.

- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Better Auth session management](https://www.better-auth.com/docs/concepts/session-management)
- [Better Auth cookies](https://www.better-auth.com/docs/concepts/cookies)

## Release limits

Local integration evidence cannot establish the security of a production Cloudflare Access policy, Worker secrets, Tunnel configuration, public DNS/TLS, Droplet firewall, production email delivery, backups or operational logging. Those controls require isolated staging configuration and verification. The final release decision must preserve these as blocked until tested; missing credentials or infrastructure must not be recorded as a pass. The Worker strips caller-supplied forwarding headers and sets `x-forma-client-ip` from Cloudflare's edge-provided `cf-connecting-ip`; Better Auth on the API trusts only `x-forma-client-ip`. Worker tests verify header stripping and injection, but the Cloudflare-to-origin production path remains unverified until staging is available. Better Auth's default special rule limits `/send-verification-email` to 3 requests per 60 seconds per trusted client IP. Browser tests exposed this across multiple synthetic journeys sharing one local IP. An exact-path override is bounded to 5–1000 requests and applies only when both `config.environment` and `NODE_ENV` are `test`; tests verify a fourth request is rejected under development and production configs. Production keeps Better Auth's default rule.

### Final external evidence update

The isolated mail domain is enabled with six matching provider DNS records; existing apex/mail settings were preserved and temporary provisioning tokens were revoked. One owner-authorized synthetic template message was accepted and queued by Cloudflare (HTTP 200), with no permanent bounce; inbox receipt remains unverified. See [mail evidence](../accounts/mail-delivery-test.json). Both complete GitHub CI runs on `ebbec2e` passed. Private-host SSH and deployed application/operational verification remain blocked as described in [release readiness](../accounts/release-readiness.md).
