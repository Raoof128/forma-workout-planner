# Account release readiness

**NO-GO for external release.** The code and isolated integration harness are
present, but the release gates below are not all evidenced. This report is for
the current `feature/self-hosted-accounts` candidate and must be reconciled with
the final run results before release. It does not claim a Cloudflare or
DigitalOcean deployment.

Authorized Cloudflare and Droplet credential bindings were present for
deployment verification, and Cloudflare token verification succeeded. The
read-only Cloudflare accounts request returned HTTP 403, error 9109: the token
cannot be used from this source location; no accounts, zones, Workers, Tunnels,
or Access applications could be inventoried. Droplet SSH returned connection
refused. No external resources were created or changed, and no live
configuration or staging deployment was verified. Credential values and
locations are intentionally omitted.

## What is in the repository

- The browser supports a Better Auth account UI and a separate local guest
  mode. Authenticated workspaces use the same FORMA version 1 data schema and
  PostgreSQL API; cross-device writes use explicit revisions and idempotency
  keys.
- Fastify/Better Auth routes, PostgreSQL migrations, an ownership-scoped JSONB
  workspace, a Worker API gateway, and private-host Compose files are checked
  in.
- Isolated server and browser test harnesses use real PostgreSQL. Local mail
  tests use an in-memory sink. The Worker test suite exercises the gateway
  handler but is not a deployed edge-to-origin test.
- `docs/qa/release-readiness.md` and the existing QA inventories describe the
  historical browser-only candidate (`86cf`). Their PASS counts do not count
  toward these account release gates.

## Mandatory gates

| Gate                                      | State                                          | Evidence / remaining action                                                                                                                                                                    |
| ----------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Account functionality                     | BLOCKED pending final integrated run           | Auth test source covers verification, password reset, MFA, sessions, and deletion. Reconcile current test output and resolve every failure before release.                                     |
| Member ownership                          | Locally tested; final rerun required           | Real PostgreSQL HTTP test creates two members and checks private read/write/export boundaries. Record final command/count after integration.                                                   |
| Workout persistence and conflict handling | Locally tested; final rerun required           | Real PostgreSQL test covers concurrent revision writes, retry acknowledgements, stale conflicts, schema invariants, bounded idempotency, and cascade. Final app/browser pass remains required. |
| Legacy data transfer                      | Code present; user acceptance evidence pending | Import is a validated, confirmed cloud write. Test an actual legacy backup in the final browser run and report row/value preservation.                                                         |
| Cross-device sync                         | Local integration evidence pending final count | The API uses PostgreSQL revisions; a staging two-browser save/read/modify/reload check has not been performed.                                                                                 |
| Cloudflare Worker staging                 | BLOCKED                                        | `wrangler.jsonc` still contains `.invalid` origins. The Cloudflare API was unreachable, so no real app domain or staging Worker binding was verified.                                          |
| Private API and database staging          | BLOCKED                                        | The supplied Droplet credentials could not be used because SSH was refused. Tunnel route, Access service-token policy, private firewall, and outbound/NAT configuration remain unverified.     |
| Security                                  | BLOCKED pending final integrated review        | Local adversarial tests exist. Review and rerun the exact candidate; production security posture and live origin controls are not established.                                                 |
| Browser and accessibility                 | BLOCKED pending final integrated run           | Account Playwright configuration covers Chromium, Firefox, and WebKit. Record actual browser availability and outcomes; local mocks/sinks do not substitute for staging.                       |
| Backup and restore                        | Local restore PASS; off-host BLOCKED                                        | Local encrypted PostgreSQL 18.4 dump/restore passed with exact workspace comparison and corrupt-ciphertext rejection; see backup-restore-evidence.json. Off-host upload and operational scheduling remain unverified.                                                                                       |
| Documentation                             | IN PROGRESS                                    | Account API, operations, database, infrastructure, and release docs are being reconciled to the final scripts and actual results.                                                              |
| Independent review                        | PENDING                                        | Root integrator must review the exact final tree and evidence.                                                                                                                                 |

## Evidence to record before a GO decision

Run the relevant checks on the exact proposed commit and attach actual exit
codes and counts. At minimum, record `npm run typecheck`,
`npm run test:server` with a disposable PostgreSQL database,
`npm run test:worker`, the original unit/browser suite, and account browser runs
in each available engine. Do not combine unit tests with database tests under a
single “all tests passed” statement. Any absent browser engine is a limitation,
not a pass.

Then perform staging journeys through the real Worker, Access-protected Tunnel,
API, Better Auth, PostgreSQL and email provider. Use two synthetic accounts,
test conflicting writes and cross-member isolation, import and export a
synthetic legacy backup, and capture the client-visible recovery behavior.
Finally upload an encrypted backup to the configured off-host destination,
verify its checksum, restore into a separate `forma_restore_*` database and run
application-level integrity checks.

Until those results exist, do not label the account implementation production
ready. Never report placeholder domains, test email sink messages, a mocked
Worker fetch, or local database tests as a successful cloud deployment.
