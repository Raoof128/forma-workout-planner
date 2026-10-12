# Account authentication implementation notes

The server pins Better Auth `1.7.7` and uses its PostgreSQL adapter with the
application's `pg.Pool`. The installed adapter documentation shows this direct
Pool configuration; PostgreSQL supports a dedicated schema through
`search_path`, which the isolated integration tests use:

- [PostgreSQL adapter](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/adapters/postgresql.mdx)
- [Better Auth 1.7.7 PostgreSQL implementation](https://github.com/better-auth/better-auth/tree/v1.7.7/packages/better-auth/src/adapters)

The account setup uses Better Auth's native email verification and password
reset callbacks. Email/password sign-in requires verified email; the app sets a
15-character password minimum, and reset invalidates existing sessions. The
native generic duplicate-signup response is enabled by requiring email
verification, so an existing address does not produce an explicit
`USER_ALREADY_EXISTS` response. Password-reset responses are likewise generic.
The backend also normalizes Better Auth's unverified-email sign-in response to
the same 401 code/message used for unknown email or wrong password. The UI
offers a separate generic resend-verification action.
The email adapter either sends via Resend over HTTPS or writes to a process-local
test/development sink only when explicitly enabled outside production.

- [Email verification and password reset](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/concepts/email.mdx)
- [User and account management](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/concepts/users-accounts.mdx)

Sessions are persisted in PostgreSQL and cookie caching is disabled. Better
Auth documents that session cookie caching can leave a revoked session usable
until the cache expires, so disabling it makes revocation immediate on the next
request. The configured five-minute `freshAge` is used by Better Auth's
reauthentication gates for sensitive account operations.

- [Session management and freshness](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/concepts/session-management.mdx)
- [Cookie behavior](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/concepts/cookies.mdx)

The `twoFactor` plugin handles TOTP setup/verification and backup-code
generation. The installed 1.7.7 implementation encrypts TOTP secrets and
backup-code material with the Better Auth secret by default. Backup codes are
single-use. The 1.7.7 TOTP verify route validates the current code but does not
persist a consumed-code marker; the app therefore adds a 90-second, per-user
HMAC digest uniqueness gate in PostgreSQL to prevent the same accepted TOTP
from authenticating more than once. It does not implement TOTP generation,
verification, or encryption itself.

- [Two-factor plugin](https://raw.githubusercontent.com/better-auth/better-auth/main/docs/content/docs/plugins/2fa.mdx)
- [Better Auth 1.7.7 two-factor plugin source](https://github.com/better-auth/better-auth/blob/v1.7.7/packages/better-auth/src/plugins/two-factor/index.ts)
- [Better Auth 1.7.7 TOTP verification source](https://github.com/better-auth/better-auth/blob/v1.7.7/packages/better-auth/src/plugins/two-factor/totp/index.ts)

The app runs Better Auth behind a Fastify bridge. It preserves request bodies
and every `Set-Cookie` response header. Browser cookies are HttpOnly, SameSite
Lax, host-only, and Secure on HTTPS origins. The API also independently checks
the Worker service secret and checks the configured application origin on
unsafe requests; only `CF-Connecting-IP` is trusted as the rate-limit client
address, supplied by the Worker after it discards client-provided forwarding
headers.

Normal and production per-route sign-in, sign-up, and password-reset limits are
five attempts per trusted client IP per minute. The isolated account browser
harness sets `NODE_ENV=test` and uses a bounded `authRateLimitMax: 1000` because
separate browser specs share one synthetic source IP; that override is honored
only for a test-mode app, is capped at 1000, and is not an abuse-resistance or
production-rate-limit verification.

The integration suite exercises real PostgreSQL migrations, verified signup,
unverified login denial, reset and email-change flows, TOTP and backup-code
verification, TOTP replay with a forged session-cookie regression, session
revocation, and account deletion with workspace cascade.
