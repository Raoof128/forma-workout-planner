# Authorisation and member isolation

[Back to security overview](README.md)

## Model

There is one role: member. Every member owns exactly one workspace row. No
administrative API exists.

- The owner of every workspace operation is the user ID from the server-side
  session. No request field, header or query parameter selects an owner.
- `member_workspace.owner_id` and the `member_workspace_operations` key
  `(owner_id, operation_id)` are owner-scoped, with foreign keys that cascade
  on account deletion.
- The workspace schema strips unknown keys, so imported backups cannot carry
  owner fields into storage.
- Session list and revoke endpoints address sessions by an HMAC reference and
  always constrain SQL by the caller's user ID.
- `X-Forma-Member` must equal the HMAC reference of the session's user on every
  member route and member-bound auth route. It is a request-binding check, not
  the authorisation decision.

## Route inventory

| Route                                               | Method | Authentication                                                | Owner rule                                          | Limit                                               |
| --------------------------------------------------- | ------ | ------------------------------------------------------------- | --------------------------------------------------- | --------------------------------------------------- |
| `/api/health` → `/healthz`                          | GET    | None                                                          | None                                                | Worker                                              |
| `/api/workspace`                                    | GET    | Session + member reference                                    | Session user                                        | Worker                                              |
| `/api/workspace`                                    | PUT    | Session + member reference, checked before the body is parsed | Session user, revision CAS, idempotent operation ID | 120 per minute per member, 20 MiB, aggregate bounds |
| `/api/workspace/export`                             | GET    | Session + member reference                                    | Session user                                        | Worker                                              |
| `/api/account/sessions`                             | GET    | Session + member reference                                    | `WHERE "userId" = session user`                     | Worker                                              |
| `/api/account/sessions/:ref/revoke`                 | DELETE | Fresh session (5 min)                                         | Reference matched within caller's sessions          | Worker                                              |
| `/api/account/sessions/revoke-others`, `revoke-all` | POST   | Fresh session (5 min)                                         | Caller's sessions only                              | Worker                                              |
| `/api/account/coach-tokens`                         | GET    | Session + member reference                                    | `WHERE owner_id = session user`                     | Worker                                              |
| `/api/account/coach-tokens`                         | POST   | Fresh session (5 min) + same-origin `Origin`                  | Session user; at most 5 active tokens               | Worker                                              |
| `/api/account/coach-tokens/:id`                     | DELETE | Session + member reference + same-origin `Origin`             | ID matched within caller's tokens                   | Worker                                              |
| `/api/coach/workspace`                              | GET    | Bearer coach token (HMAC digest lookup); cookies ignored      | Token owner; read-only summary, no identity fields  | 20 failures/15 min per IP; 120 reads/hour per token |
| `/api/auth/*` (allowlisted)                         | Varies | See [authentication](authentication.md)                       | Better Auth session user                            | Per-IP and per-account                              |

Anything else returns 404 at the Worker and at the API.

## Evidence

- `server/tests/security.test.ts`: two real sessions cannot read, mutate or
  export each other's workspace; forged gateway credentials and hostile origins
  are rejected.
- `server/tests/workspace.test.ts`: ownership, concurrency, idempotency and
  cascade in PostgreSQL.
- `server/tests/coach.test.ts`: a coach token reads only its owner's summary;
  another member cannot revoke it; revocation, expiry and user deletion end it;
  guessing and polling are budgeted. `worker/tests/coach.test.ts` shows the
  bearer header reaches the origin only on the coach route, without cookies.
- `tests/accounts-security.spec.js`: isolation and account switching in real
  browsers.
- Independent re-attack during the engagement: every combination of one
  member's cookie with another member's reference returned 409; session revoke
  by another member's reference returned 404 and left the target valid; 20
  parallel writes at one revision produced exactly one success; 15 parallel
  retries of one operation ID produced one revision.

No cross-member read, write, export, restore or deletion was achieved.
