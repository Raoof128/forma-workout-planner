# Security review

This review used the OWASP API Security Top 10 (2023) and OWASP ASVS 5.0 as
checklists. Better Auth behaviour was checked against the installed 1.7.12
sources under `node_modules/better-auth/dist`, not against general
documentation. It is a code review plus tests, run on real PostgreSQL and the
Worker harness. **It is not a penetration test or a certification**, and no
traffic was sent to staging or production.

## Boundaries re-verified (no change needed)

- **Deny by default.** Only the exact `/healthz` and `/readyz` paths are
  public. Encoded paths are refused. Every other request needs the
  constant-time-checked Worker secret, and mutations need the exact app
  `Origin` or the native marker with no browser headers.
- **Identity.** Member identity comes only from the server-validated
  session. `X-Forma-Member` is compared with the session-derived reference
  (`409 account_changed`) and is never used as identity.
- **Coach tokens.**
  - Tokens are stored only as an HMAC digest, and the owner comes from the
    token row.
  - `read` tokens cannot write.
  - Bearer credentials are forwarded only on the three coach paths, without
    cookies.
  - Tokens never reach account or auth routes.
  - Errors do not reveal whether a token exists.
- **Worker.** Request and response header allowlists are enforced. The
  client IP is set only from `CF-Connecting-IP`. `Set-Cookie` is sanitised,
  and redirects are validated with `redirect: "manual"`. API responses get
  `no-store` and a sandboxed CSP.
- **SQL.** Every statement is parameterised. The only interpolation in the
  change set is a regex-validated `lock_timeout` literal.

## Changes and threat mapping

| Threat                                   | OWASP          | Change                                                                                                                                                            |
| ---------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A credential outliving a compromise      | API2           | Coach tokens and trusted devices are revoked on password reset or change, `revoke-sessions` and `revoke-all` (B-04).                                              |
| Token revoked mid-request                | API2           | The write guard runs inside the transaction (B-03).                                                                                                               |
| Account enumeration by timing            | API2, ASVS V6  | Background mail removes the delivery-latency difference (B-05). A smaller database-work difference remains, for example the reset-token insert.                   |
| Lockout by transient errors              | API4           | Throttle refund on handler failure, without refunding settled wrong passwords (B-07).                                                                             |
| Mail suppression during provider outages | API4           | Budget refund on a failed send (B-06).                                                                                                                            |
| Resource consumption through the Tunnel  | API4           | Anonymous bodies capped small at the Worker (B-15). Coach mint and member-wide write budgets (B-17). Request timeout (B-18).                                      |
| Cross-site requests on token links       | API8           | The link exemption requires `Sec-Fetch-Mode: navigate` (B-16). The origin also refuses a cross-site coach PATCH (B-18).                                           |
| Information leakage                      | API8           | 5xx logs carry the error class and code only. Upstream 5xx bodies are replaced at the Worker. The auth failure log uses a fixed route label, never a reset token. |
| Known secrets in production              | API8, ASVS V13 | Placeholder, reused and low-entropy secrets are refused. An HTTPS origin outside production fails closed (B-14).                                                  |
| Destructive AI or coach edits            | API3, API5     | `removesActive` confirmation (B-02), in addition to `removesSessions`.                                                                                            |

## Independent review results

The security reviewer found one new P2 in the first draft of the change set:
the auth failure log line included the request path, which for
`reset-password/<token>` is a live token. It was fixed before commit, and the
line now logs a fixed route label. Its other verified points were also fixed:

- the settled-before-refund ordering;
- refusing any non-production environment with an HTTPS origin;
- the entropy floor;
- the event name for background tasks;
- two inaccurate comments.

Items it raised that remain open are listed as D-01 to D-17 in BACKEND_AUDIT.md.

## Residual risks

These are open and recorded as deferred items:

- **D-01:** disabling 2FA needs only the password.
- **D-02:** email change has no step-up.
- **D-07:** the Worker passes every `/api/auth/*` path to the origin's exact
  route table.
- **D-11:** requests without a client IP share one rate-limit bucket.
- **D-12:** the second factor is not counted in FORMA's own throttle.

The FORMA cookie name is chosen by the API and the Worker's cookie filter
together, so a change to one needs both.

`AUTH_SECRET` rotation now also invalidates every coach token, because the
digest is keyed by it. This is documented in `docs/accounts/api.md`.
