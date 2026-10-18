# Account and workspace API

The browser calls the Worker on the application origin. The Worker forwards
only the routes listed below to a fixed backend origin. The backend checks the
Worker service credential, then checks the Better Auth session for every
member-owned operation. Worker identity never substitutes for member identity.

All `/api/*` responses are private and uncached. Authenticated endpoints use
the Better Auth `forma.session_token` HttpOnly cookie; the browser client does
not store a bearer token. The Worker and backend preserve Better Auth
`Set-Cookie` headers. The API does not return Better Auth database IDs or
session tokens in its JSON responses.

Protected workspace, account-session, and authenticated account-mutation
requests also require `X-Forma-Member`, set to the opaque `user.id` returned by
`GET /api/auth/get-session`. This is an expected-member consistency guard,
not authentication: the server derives identity from the verified cookie and
compares the header with that member's reference. A missing or mismatched
reference returns HTTP 409 with `error: "account_changed"` and no private data.
Discard the old member's pending writes and refresh the session before loading
the new workspace; never retry an old member's write with the new reference.
Public sign-in/registration/session lookup and token-bound email callbacks are
exempt. Use the account client adapter to attach the header to protected Better
Auth operations as well as workspace requests.

## Authentication

`/api/auth/*` is Better Auth 1.7.7's self-hosted HTTP handler. Its configured
email/password and two-factor client methods support:

- Account registration, email verification, email/password sign-in, and
  sign-out.
- Session lookup and refresh after page reload.
- Password-reset request and token-based password reset.
- Profile and email changes, which use Better Auth's email confirmation flow.
- Password changes and two-factor enrollment, TOTP verification, and recovery
  codes.
- Account deletion through Better Auth's email confirmation flow.

Passwords must be at least 15 characters. Sign-in requires verified email.
Session cookies are HttpOnly, SameSite=Lax, and Secure on HTTPS. Sessions have
a seven-day lifetime, and password reset revokes prior sessions. Authentication
email links expire according to the Better Auth configuration. Exact endpoint
payloads are defined by the pinned Better Auth client/server version; use the
browser `authClient` methods rather than hand-building a parallel auth API.

## Account sessions

| Method and path                            | Authentication                         | Result                                                                                                          |
| ------------------------------------------ | -------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `GET /api/account/sessions`                | Member session                         | Active sessions for that member, with an opaque signed reference, dates, user agent and current-session marker. |
| `DELETE /api/account/sessions/:id/revoke`  | Recent session, at most 5 minutes old | Revokes the referenced session after matching it within the authenticated member's active sessions.             |
| `POST /api/account/sessions/revoke-others` | Recent session                         | Revokes every other session belonging to the authenticated member.                                              |
| `POST /api/account/sessions/revoke-all`    | Recent session                         | Revokes all sessions belonging to the authenticated member, including the current session.                      |

The opaque session reference is an HMAC under the server auth secret. It is not
a database ID or a session token. The session routes do not accept an owner ID.
Sensitive session revocations require reauthentication through a fresh
Better Auth session.

## Coach access (read-only tokens)

A member can mint up to five read-only **coach tokens** in Account › Security
and give one to a coaching tool or AI assistant. The token reads a training
summary and nothing else: it cannot write, cannot reach any other route, and
the summary carries no email address, member reference, revision or operation
data. Tokens expire 90 days after creation and can be revoked at any time.

| Method and path                           | Authentication                            | Result                                                                                                       |
| ----------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `GET /api/account/coach-tokens`           | Member session                            | Active tokens for the member: `id`, `label`, `createdAt`, `expiresAt`, `lastUsedAt`. Never the token itself. |
| `POST /api/account/coach-tokens`          | Recent session, at most 5 minutes old     | Body `{ "label": "Claude coach" }` (1–60 plain characters). Returns `{ token, record }`; `token` is shown once. |
| `DELETE /api/account/coach-tokens/:id`    | Member session                            | Revokes one of the caller's tokens by its 22-character ID; another member's ID is `404`.                      |
| `GET /api/coach/workspace?days=28`        | `Authorization: Bearer forma_coach_…`     | The owner's coach summary for the last `days` days (1–365, default 28).                                      |

Tokens look like `forma_coach_` followed by 43 URL-safe characters (32 random
bytes). PostgreSQL stores only an HMAC-SHA-256 digest of the token under the
server auth secret, so a database read never yields a usable credential.
Minting is a step-up action and returns `403 reauthentication_required` from a
session older than five minutes; a sixth active token returns
`409 token_limit`; a bad label returns `400 invalid_label`.

The bearer route ignores cookies and the member reference. It is the only
route for which the Worker forwards an `Authorization` header, and the Worker
withholds cookies on it so the two credential types never travel together.
Failures return `401` with `WWW-Authenticate: Bearer realm="forma-coach"`;
after 20 failures from one client in 15 minutes the route returns
`429 too_many_attempts`. Each token may read 120 times per hour, after which
the route returns `429 rate_limited` with `Retry-After: 3600`. A revoked or
expired token is indistinguishable from an unknown one.

The summary has this shape (abbreviated):

```json
{
  "generatedAt": "2026-10-18T01:00:00.000Z",
  "days": 28,
  "member": { "name": "Raouf", "weeklyGoal": 5 },
  "schedule": ["Monday", "Wednesday", "Friday"],
  "routines": [{ "id": "…", "name": "Upper A", "minutes": 60, "level": "…", "exercises": [{ "exerciseId": "…", "name": "Bench Press", "sets": 3, "reps": 10, "weight": 40 }] }],
  "activeWorkout": null,
  "sessions": [{ "id": "…", "name": "Upper A", "routineId": "…", "date": "…", "durationSeconds": 3540, "notes": "…", "exercises": [{ "exerciseId": "…", "name": "Bench Press", "sets": [{ "weight": 40, "reps": 10, "done": true }] }] }],
  "personalBests": [{ "exerciseId": "…", "name": "Bench Press", "bestWeight": 42.5, "estimatedOneRM": 53.8, "lastPerformed": "…" }],
  "weekly": [{ "weekStart": "2026-10-12", "sessions": 3, "volume": 9120 }],
  "totalSessions": 41
}
```

Sessions are newest first and capped at 200; notes are truncated to 1,000
characters; personal bests and estimated one-rep maximums follow the
[data model](../data-model.md#calculations) and count completed load/reps sets
only.

## Workspace data

| Method and path             | Authentication                           | Result                                                                                        |
| --------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| `GET /api/workspace`        | Member session                           | `{ data, revision, updatedAt }` for the signed-in member.                                     |
| `PUT /api/workspace`        | Member session and same-origin `Origin`  | Stores one validated version 1 workspace using optimistic concurrency.                        |
| `GET /api/workspace/export` | Member session                           | The same member's validated workspace as an `application/json` attachment.                    |
| `GET /api/health`           | Worker service credentials at the origin | Maps to API liveness check `/healthz`; it does not prove database, mail, or backup readiness. |

PUT accepts exactly this top-level shape:

```json
{
  "data": { "version": 1 },
  "expectedRevision": 0,
  "operationId": "client-generated-id"
}
```

The abbreviated `data` stands for the full existing FORMA backup structure.
The server validates it with the browser's runtime schema, including duplicate
record IDs and active/history consistency. The workspace data limit is 20 MiB;
the Worker permits a small JSON/framing allowance. The user ID is resolved only
from the authenticated server session. Unknown ownership properties in the
data are discarded by the shared schema; extra top-level request properties
are rejected.

On success PUT returns the committed `{ data, revision, updatedAt }`. The
server advances `revision` and `updatedAt`. A stale expected revision returns
HTTP 409 with `error: "stale_revision"` and the latest `data`, `revision`, and
`updatedAt`. The client reloads or resolves that conflict before sending a new
operation. Reusing an operation ID with a different normalized request returns
HTTP 409 with `error: "operation_id_reused"`. Repeating the same request returns
the original acknowledgement. A retry beyond the bounded idempotency retention
window returns a stale-revision conflict and cannot be applied twice.

Workspace implementation and retention details are in the
[database reference](database.md) and [sync guide](../member-data-sync.md).
