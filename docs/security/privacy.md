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
| Guest data                  | Local-only mode             | Browser `localStorage` (`forma-v1`)    | Until the person clears it                        | That browser             |
| Logs                        | Operations                  | Container logs, 3 × 10 MB rotation     | Rotation                                          | Operator                 |
| Backups                     | Recovery                    | Off-host, age-encrypted                | Owner to define (open)                            | Operator                 |

No analytics, trackers or third-party scripts are loaded. The only external
service receiving personal data is Cloudflare (edge, Access, Email Service).

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
  immediate removal from backups; state the backup retention period once it is
  defined.

## Open items

- Backup retention period and deletion statement (owner).
- A browser's guest data is offered for import to any member who signs in on
  that browser (R-05, Low). Recommend recording who migrated it and offering
  it once.
