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
| `DELETE /api/account/sessions/:id/revoke`  | Recent session, at most 15 minutes old | Revokes the referenced session after matching it within the authenticated member's active sessions.             |
| `POST /api/account/sessions/revoke-others` | Recent session                         | Revokes every other session belonging to the authenticated member.                                              |
| `POST /api/account/sessions/revoke-all`    | Recent session                         | Revokes all sessions belonging to the authenticated member, including the current session.                      |

The opaque session reference is an HMAC under the server auth secret. It is not
a database ID or a session token. The session routes do not accept an owner ID.
Sensitive session revocations require reauthentication through a fresh
Better Auth session.

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
