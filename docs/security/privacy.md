# Privacy and data handling

[Back to security overview](README.md)

Workout history and goals can reveal health-related information. FORMA treats
them as sensitive personal information. Whether the Australian Privacy
Principles legally bind the operator depends on circumstances this assessment
cannot determine; APP 11 (security of personal information) is used as the
practical benchmark.

## Data inventory

| Data                        | Purpose                     | Stored                                 | Retention                                         | Access                   |
| --------------------------- | --------------------------- | -------------------------------------- | ------------------------------------------------- | ------------------------ |
| Name (1–60 chars), email    | Account, mail               | `"user"`                               | Until account deletion                            | Member, API              |
| Password hash (scrypt)      | Sign-in                     | `account.password`                     | Until deletion or change                          | API only, never returned |
| Sessions (token, IP, UA)    | Sign-in state, session list | `"session"`                            | 7-day sliding, 30-day absolute, deleted on revoke | Member sees UA and dates |
| TOTP secret, recovery codes | Second factor               | `"twoFactor"`, encrypted               | Until disabled or deletion                        | API only                 |
| Verification tokens         | Email flows                 | `verification`                         | Expire (1 hour)                                   | API only                 |
| Workout workspace           | The product                 | `member_workspace` (JSON)              | Until deletion                                    | Member only              |
| Operation acknowledgements  | Idempotent retries          | `member_workspace_operations`          | 30 days or latest 1,000                           | API only                 |
| Abuse counters              | Rate limiting               | `security_throttle`, HMAC digests only | Pruned after 2 days unless locked                 | API only                 |
| Coach tokens                | Coaching access (read/full) | `member_coach_token`, HMAC digest only | 90 days, or until revoked or account deletion     | Member sees label, dates |
| Guest data                  | Local-only mode             | Browser `localStorage` (`forma-v1`)    | Until the person clears it                        | That browser             |
| Logs                        | Operations                  | Container logs, 3 × 10 MB rotation     | Rotation                                          | Operator                 |
| Backups                     | Recovery                    | Off-host, age-encrypted                | 34-day scheduled deletion; within 35 days                            | Operator                 |

No analytics, trackers or third-party scripts are loaded. Service providers
processing personal data are Cloudflare (edge, Access,
Email Service and encrypted backup storage) and DigitalOcean (the private
server and database), as described in the [published policy](../../src/legal/content.js).

## Minimisation

- No avatars, phone numbers, dates of birth or body measurements are collected.
- Logs redact cookies, authorisation, worker secret, passwords, tokens, codes
  and full URLs, and never include workspace payloads.
- Session tokens never reach JavaScript; user IDs are replaced by HMAC
  references in API responses.

## Export and deletion

- Export returns only the caller's workspace, as an uncached attachment
  (`private, no-store`), and requires the member reference header, so it
  cannot be triggered cross-site.
- Deletion requires confirmation through a link sent to the current address.
  It removes the user, sessions, credentials, 2FA rows, workspace and
  operations (cascade, verified in tests) and invalidates the old member
  reference.
- Copies inside backups persist until those backups expire. Do not promise
  immediate removal from backups. The published policy schedules deletion after
  34 days and requires deletion within 35 days.

## Operational boundaries

- Backups must continue to match the published retention and location commitments
  (see [legal](../legal/README.md)). The dated
  [launch record](../accounts/production-launch.md) records the 34-day lifecycle
  and isolated recovery checks; it does not verify today's remote settings.
- Guest data is browser-local and shared by people using the same browser
  profile. Import is explicit; a migration marker records the importing member
  and guest-data fingerprint to avoid offering unchanged data again. That
  marker is a local convenience, not an access-control boundary.
