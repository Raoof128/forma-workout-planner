# Reliability

## Failure behaviour after this change

| Failure                                            | Before                                                                                               | After                                                                                            | Evidence                              |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------- |
| PostgreSQL unreachable while a member is signed in | `401` on member routes, so clients could treat the outage as a sign-out                              | `503 temporarily_unavailable` with `Retry-After`. Web and iOS treat it as transient.             | Server test with an ended pool        |
| PostgreSQL unreachable, monitoring                 | `/healthz`, the Docker healthcheck and the edge check stayed green                                   | `/readyz` returns `503`. The host monitor alerts after two failed probes.                        | Server and Python tests               |
| API event loop wedged                              | The monitor's probe raised a timeout and the run aborted before its state write, so it never alerted | Timeouts count as failed probes                                                                  | `test_a_hung_readiness_probe…`        |
| Alert email provider down                          | Counters and journal entries were lost; the edge monitor started no retry                            | State persists in `finally`. Only a delivered alert opens a suppression window.                  | Python and Node tests                 |
| API container down or restarting                   | Reported as `tunnel_error`                                                                           | The tunnel is not judged that run                                                                | Python tests                          |
| Migration meets a long reader                      | DDL waits in the lock queue and blocks member queries; the runner waits indefinitely                 | Fails within `lock_timeout` (default 5 s). Rerun when quiet.                                     | Migration test (300 ms setting)       |
| Two migration runners                              | Serialised by the advisory lock with no time bound                                                   | Serialised; the waiting runner gives up after 120 s                                              | Concurrent-runner test                |
| Stalled request upload                             | No Fastify request timeout                                                                           | 120 s `requestTimeout`. Handler time is bounded by the runtime role's 15 s `statement_timeout`.  | Code review                           |
| SIGTERM with a hung request                        | `app.close()` could wait indefinitely, and a rejected close skipped `pool.end()`                     | Drains, always ends the pool, and exits with code 1 after 8 s (below Docker's 10 s grace period) | Code review                           |
| `ROLLBACK` fails                                   | The broken connection went back to the pool                                                          | The connection is destroyed                                                                      | Code review (pg-pool `release(true)`) |
| Auth handler throws mid sign-in                    | The reserved attempt stayed counted, so a member could be locked out                                 | Refunded unless already settled, and logged with a fixed event                                   | Server test with an injected failure  |
| Email provider failure                             | Sign-up or reset returned 500 (an existence oracle) and the recipient's budget was spent             | Sent in the background, the failure is logged as a class only, and the budget is refunded        | `auth-hardening`                      |

## Logging and observability

- **New fixed events:** `auth request failed` (error class and fixed route
  label), `credential cleanup failed`, `auth_email_failed` and
  `auth_background_task_failed` (error class only).
- **5xx logs** keep only the error name and code. A pg error's `message` and
  `detail` can quote row values, so they are no longer logged.
- **No new telemetry, third-party service or recurring cost.**

## Deploy order

1. Release the API (staging, then production) so that `/readyz` exists.
2. Install the updated `ops/account-operations.py` on each host. The probe
   fails, and alerts, if `/readyz` is missing.
3. Deploy the Worker, staging first.

The edge-monitor Worker change is independent.
