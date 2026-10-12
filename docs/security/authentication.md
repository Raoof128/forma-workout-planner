# Authentication and sessions

[Back to security overview](README.md)

FORMA uses Better Auth 1.7.7 (`server/auth.ts`) behind a hardening proxy in
`server/app.ts`. The browser only ever talks to the same-origin Worker.

## Controls

| Area                      | Behaviour                                                                                                                                                                                                                                                                                                                                                                 | Evidence                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| Reachable endpoints       | Only the flows the app uses are routed (`AUTH_ROUTES`). Password oracles (`verify-password`), `list-accounts`, `account-info`, `get-totp-uri`, OTP and social routes return 404.                                                                                                                                                                                          | RT-08                             |
| Request bodies            | Every non-GET auth request must be a JSON object, so body checks cannot be bypassed with form-encoded payloads.                                                                                                                                                                                                                                                           | RT-13                             |
| Registration              | Email verification required before sign-in; sign-up for an existing address returns the same response as a new one; `emailVerified` and other server fields cannot be set by the client; names are 1–60 characters; avatars are not accepted.                                                                                                                             | `auth.test.ts`, RT-09             |
| Passwords                 | 15–1,024 characters, hashed with scrypt by Better Auth, never returned. No breached-password blocklist yet (open item R-10).                                                                                                                                                                                                                                              | `auth.test.ts`                    |
| Sign-in throttling        | Per-IP limit of 5 per minute (Better Auth). Per-account limit keyed by an HMAC of the normalised email, for existing and non-existent addresses alike: 10 failures in 15 minutes lock for 15 minutes; 100 consecutive failures lock until a password reset. Attempts are reserved atomically before the password is checked, so parallel guesses cannot exceed the limit. | RT-04, RT-04b, RT-14              |
| Signed-in password checks | `change-password`, `delete-user` and the 2FA enable/disable/recovery-code endpoints share the same limits per member, so a stolen session is not a password oracle.                                                                                                                                                                                                       | RT-15                             |
| Enumeration               | Unverified accounts receive the same 401 as a wrong password. Reset and resend always succeed generically. Locks apply to any submitted address, so a 429 is not an existence oracle.                                                                                                                                                                                     | `auth.test.ts`, RT-04             |
| Password reset            | Single-use, one-hour tokens; all sessions revoked on reset; reset clears the per-account lock; the token is removed from the address bar after it is read.                                                                                                                                                                                                                | `auth.test.ts`, RT-04             |
| Password change           | Requires the current password and always revokes other sessions, whatever the client sends.                                                                                                                                                                                                                                                                               | RT-05                             |
| Email links               | `callbackURL`, `redirectTo`, `errorCallbackURL` and `newUserCallbackURL` must be same-origin, and any `Location` the library emits is checked again. Email links never create a session.                                                                                                                                                                                  | RT-02, RT-10, RT-12               |
| TOTP 2FA                  | Optional per member. Secrets encrypted with `AUTH_SECRET`. Replay of a used code within 90 seconds is rejected. Better Auth adds 3 attempts per 10 seconds per IP and locks after 10 consecutive failures for 15 minutes. Recovery codes are single-use.                                                                                                                  | `auth.test.ts`, engagement probes |
| Mail budget               | At most 5 messages of each kind per recipient per hour, regardless of source IP. Excess mail is dropped silently so responses reveal nothing.                                                                                                                                                                                                                             | RT-06                             |

## Sessions

| Property             | Value                                                                                                                                                                           |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cookie               | `__Secure-forma.session_token`, `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, no `Domain`                                                                                     |
| Sliding expiry       | 7 days, refreshed at most daily                                                                                                                                                 |
| Absolute lifetime    | 30 days from sign-in, enforced on member routes, `get-session` and member-bound auth routes (RT-11)                                                                             |
| Revocation           | Immediate: Better Auth cookie cache is disabled, so every request reads the session table                                                                                       |
| Step-up              | Revoking sessions requires a session created in the last 5 minutes. Since email links can no longer mint sessions, only password (plus TOTP when enabled) sign-in satisfies it. |
| Account binding      | Member routes require `X-Forma-Member`, an HMAC of the user ID. A tab still showing member A cannot act as member B (409 `account_changed`).                                    |
| Tokens in JavaScript | None. Better Auth's `token` field is stripped from responses and user IDs are replaced with references.                                                                         |

## Known gaps

- No breached or common password blocklist (NIST SP 800-63B-4 requires one).
  Better Auth's `haveIBeenPwned` plugin would send a hash prefix to an external
  service, so it is an owner decision.
- Better Auth's per-IP limiter stores counters in memory; they reset when the
  API restarts. The per-account limits are durable in PostgreSQL.
- MFA is optional and there is no step-up for changing email or starting
  account deletion; both are confirmed by email to the current address.
- A pre-registered but unverified address can be re-claimed only through
  password reset (accepted, Low).
- Changing email does not end other sessions (Info).
- **Targeted lockout (accepted, R-08).** Anyone who knows an address can lock
  it for 15 minutes with 10 guesses, and by keeping more than 5 reset requests
  an hour flowing can suppress the reset mail that would clear a lock. Every
  suppression is logged (`auth email suppressed by budget`). Operators can lift
  a lock; see [incident response](incident-response.md). Raising the mail cap
  instead would re-open mailbox flooding, which the cap exists to stop.
