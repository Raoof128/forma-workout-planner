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

`/api/auth/*` is Better Auth 1.7.11's self-hosted HTTP handler. Its configured
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
a seven-day sliding lifetime, refreshed at most daily, and a 30-day absolute
lifetime. Password reset revokes prior sessions. Authentication
email links expire according to the Better Auth configuration. Exact endpoint
payloads are defined by the pinned Better Auth client/server version; use the
browser `authClient` methods rather than hand-building a parallel auth API.

## Account sessions

| Method and path                            | Authentication                         | Result                                                                                                          |
| ------------------------------------------ | -------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `GET /api/account/sessions`                | Member session                         | Active sessions for that member, with an opaque signed reference, dates, user agent and current-session marker. |
| `DELETE /api/account/sessions/:id/revoke`  | Fresh session or password step-up | Revokes the referenced session after matching it within the authenticated member's active sessions.             |
| `POST /api/account/sessions/revoke-others` | Fresh session or password step-up | Revokes every other session belonging to the authenticated member.                                              |
| `POST /api/account/sessions/revoke-all`    | Member session                         | Revokes all sessions belonging to the authenticated member, including the current session.                      |

The opaque session reference is an HMAC under the server auth secret. It is not
a database ID or a session token. The session routes do not accept an owner ID.
Single-session and other-session revocation accept a session at most five
minutes old. Older sessions require `password` in the same request body and,
when MFA is enabled, a six-digit TOTP `code`. This step-up verifies the existing
session without creating a new session or replacing its cookie. Revoking all
sessions requires the current member session and reference, without step-up.

## Coach access (read-only and full-access tokens)

A member can mint up to five **coach tokens** in Account › Security and give
one to a coaching tool or AI assistant. Each token has a scope chosen when it
is minted:

- **`read`** (the default, and every token minted before scopes existed)
  reads the training summary and the exercise catalogue.
- **`full`** also reads the whole workspace and edits any part of it:
  routines, the active workout, workout history, profile and schedule.

No token reaches the account itself. Email, password, sessions, 2-step
verification, other coach tokens and account deletion stay behind the
member's own sign-in, and no coach response carries the email address or
member reference. Tokens expire 90 days after creation and can be revoked at
any time.

| Method and path                           | Authentication                            | Result                                                                                                       |
| ----------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `GET /api/account/coach-tokens`           | Member session                            | Active tokens for the member: `id`, `label`, `scope`, `createdAt`, `expiresAt`, `lastUsedAt`. Never the token itself. |
| `POST /api/account/coach-tokens`          | Recent session, at most 5 minutes old     | Body `{ "label": "Claude coach", "scope": "read" }` (label 1–60 plain characters; scope `read` or `full`, default `read`). Returns `{ token, record }`; `token` is shown once. |
| `DELETE /api/account/coach-tokens/:id`    | Member session                            | Revokes one of the caller's tokens by its 22-character ID; another member's ID is `404`.                      |
| `GET /api/coach/workspace?days=28`        | Bearer token, any scope                   | The owner's coach summary for the last `days` days (1–365, default 28), with `access` set to the token's scope. |
| `GET /api/coach/exercises?q=row&limit=25` | Bearer token, any scope                   | Catalogue search: `{ total, exercises }`, each with `id`, `name`, `muscle`, `equipment`, `metric`, `logs` (the fields a set records), `perSideByDefault` and `side`. `limit` is 1–100. |
| `GET /api/coach/workspace/data`           | Bearer token, `full` scope                | The whole workspace `{ data, revision, updatedAt }`, exactly as the member's app loads it.                  |
| `PATCH /api/coach/workspace/data`         | Bearer token, `full` scope                | Replaces the named sections; see [coach edits](#coach-edits). Returns `{ revision, updatedAt, replayed }`.     |

Tokens look like `forma_coach_` followed by 43 URL-safe characters (32 random
bytes). PostgreSQL stores only an HMAC-SHA-256 digest of the token under the
server auth secret, so a database read never yields a usable credential.
Minting is a step-up action and returns `403 reauthentication_required` from a
session older than five minutes; a sixth active token returns
`409 token_limit`; a bad label returns `400 invalid_label`; a scope other than
`read` or `full` returns `400 invalid_scope`. Scopes never change after
minting: to widen access, mint a new token and revoke the old one.

The bearer routes ignore cookies and the member reference. They are the only
routes for which the Worker forwards an `Authorization` header, and the Worker
withholds cookies on them so the two credential types never travel together.
A read-only token on a `full` route gets `403 insufficient_scope`.
Failures return `401` with `WWW-Authenticate: Bearer realm="forma-coach"`;
after 20 failures from one client in 15 minutes the route returns
`429 too_many_attempts`. Each token may read 120 times per hour across the
read routes and edit 60 times per hour, after which the route returns
`429 rate_limited` with `Retry-After: 3600`. A revoked or expired token is
indistinguishable from an unknown one.

### Coach edits

`PATCH /api/coach/workspace/data` takes a JSON body:

```json
{
  "expectedRevision": 41,
  "operationId": "coach-2026-10-19-plan-week",
  "changes": {
    "routines": [],
    "schedule": [0, 2, 4]
  },
  "removesSessions": 1
}
```

- `changes` names one or more of `routines`, `history`, `active`, `profile`
  and `schedule`. Each named section replaces the stored one as a whole;
  unnamed sections are kept. Read the workspace first, change it, and send
  back the sections you changed. Any other key is `400`.
- The merged workspace passes the same strict validator as a member save, so
  a coach cannot store anything the app could not. A refusal is
  `400 invalid_workspace` with up to ten `issues`, each `{ path, message }`,
  for example `history.0.exercises.0.sets.0`.
- `expectedRevision` must equal the stored revision, otherwise
  `409 stale_revision` returns the current `revision` and `updatedAt`; read
  again and redo the change. `operationId` (1–200 characters) makes a retry
  safe: the same operation and body replays its first result with
  `replayed: true`, and reusing the ID for a different body is
  `409 operation_id_reused`.
- An edit that leaves out workouts already in `history` must say how many
  with `removesSessions`. Without the exact count it is refused with
  `400 history_removal_unconfirmed` and `removedSessions`. This stops a tool
  that only read the recent summary from erasing older history by accident.
- To finish a workout, send `active: null` and a `history` that adds the
  session with `date` and `duration`. Unilateral sets keep `reps` as the total
  of `sides: { left, right }`.

Edits need no browser `Origin`, because a bearer header is never attached by a
browser on its own and the route ignores cookies. A request that does carry a
foreign `Origin`, or `Sec-Fetch-Site: cross-site`, is refused, so a web page
on another site cannot drive an edit. Every successful edit is logged as the
`coach_workspace_write` security event.

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
| `PUT /api/workspace`        | Member session and same-origin `Origin`  | Stores one validated version 2 workspace using optimistic concurrency.                        |
| `GET /api/workspace/export` | Member session                           | The same member's validated workspace as an `application/json` attachment.                    |
| `GET /api/health`           | Worker service credentials at the origin | Maps to API liveness check `/healthz`; it does not prove database, mail, or backup readiness. |

PUT accepts exactly this top-level shape:

```json
{
  "data": { "version": 2 },
  "expectedRevision": 0,
  "operationId": "client-generated-id"
}
```

The abbreviated `data` stands for the full existing FORMA backup structure.
The server validates it with the browser's runtime schema, including duplicate
record IDs and active/history consistency. The workspace data limit is 20 MiB;
the Worker permits a small JSON/framing allowance. The user ID is resolved only
from the authenticated server session. Unknown properties in the data are rejected at every nesting level, including
ownership fields; extra top-level request properties are also rejected.
Version 1 payloads migrate before storage; see the [v2 migration guide](../routine-programming-v2.md).

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
