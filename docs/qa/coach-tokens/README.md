# Coach tokens release — 18 October 2026

Production is deployed in account mode with schema 0005. Source tree is the
PR #10 head `25154af` (feature/coach-read-api merged with main after PR #9).
Deployment was authorised by the owner in the project thread.

## Deployed versions

| Target                                              | Version                                                             |
| --------------------------------------------------- | ------------------------------------------------------------------- |
| [Production Worker](https://forma.raoufabedini.dev) | `4005f27c-03ea-427c-b087-7173d62c804b`                              |
| Production API image                                | `forma-api:coach-20261018-a831507` (Node 26.11.1, UID 10001, amd64) |
| Previous Worker (rollback)                          | `64806558-cb0d-40dc-a029-3767586b456b`                              |
| Previous API image (rollback)                       | `forma-api:routine-v2-20261017-cca9b07`                             |
| Private staging                                     | unchanged: `forma-api:routine-v2-20261017-cca9b07`                  |

[Deployment receipt](deployment.json)

## Procedure

1. Image built on the owner's Mac for `linux/amd64` from the integration tree,
   saved and gzipped (SHA-256 `2f99d462…506db`), copied to the host, checksum
   re-verified, loaded.
2. Encrypted, signed off-host backup `archives/forma-production-20261018T021730Z.dump.age`.
3. `0005-coach-tokens.sql` applied by the one-shot migrate service using the new
   image; the ledger shows 0001 to 0005, table owner `forma_migrator`.
4. `ops/grant-runtime-access.sql` updated on the host and re-run; `forma_runtime`
   holds SELECT, INSERT, UPDATE, DELETE on `member_coach_token`.
5. `IMAGE_TAG` switched in the protected `.env`; API recreated with
   `up -d --no-deps api`; healthy after about 10 seconds. Unrelated container
   IDs unchanged before and after.
6. Post-migration backup `archives/forma-production-20261018T022111Z.dump.age`.
7. Worker deployed with `npm run worker:deploy:production` (one-hour scoped
   token minted and revoked by the helper).

## Verification

| Check                                                      | Result                                                         |
| ---------------------------------------------------------- | -------------------------------------------------------------- |
| Lint, typecheck, unit (89), Worker (25), account build     | Passed on the merged tree                                      |
| Home                                                       | 200, `no-transform`, CSP and HSTS present                      |
| `/api/health`                                              | 200                                                            |
| `/api/workspace` anonymous                                 | 401 JSON                                                       |
| `/api/coach/workspace` without token / with invalid bearer | 401 JSON / 401 JSON                                            |
| `/api/auth/get-session` anonymous                          | 200 `null`                                                     |
| Unknown API route                                          | 404 JSON                                                       |
| Live HTML and JS hashes                                    | Match the local account build                                  |
| Row counts before and after                                | 1 user, 1 workspace, 21 operations, 2 sessions; 0 coach tokens |

Evidence (logs, counts, image archive and checksum, previous grant SQL and
`.env`) is retained on the host under
`/opt/forma-production/releases/coach-tokens-20261018/`.
