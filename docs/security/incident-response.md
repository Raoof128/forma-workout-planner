# Incident response

[Back to security overview](README.md)

The [13 October launch record](../accounts/production-launch.md) documents
S16 launch monitoring, host alerts and the independent edge monitor. Confirm
current alert delivery and backup freshness during operations; provider-wide
Access-attempt and unexpected-deployment audits still require operator review.
Each runbook follows: **contain, preserve, recover, communicate, verify**.

## Detection requirements and operator checks

| Signal                                            | Source                                 | Suggested threshold                     |
| ------------------------------------------------- | -------------------------------------- | --------------------------------------- |
| Failed sign-ins, per-account locks                | API log on 401/429 for `sign-in/email` | > 50 per 5 min, or any 100-failure lock |
| Password reset and verification volume            | Mail budget suppression warnings       | Any suppression                         |
| 2FA failures and lockouts                         | Better Auth 429 on `two-factor/*`      | Any lockout                             |
| `account_changed` 409 bursts                      | API responses                          | > 20 per 5 min from one IP              |
| Access service-token failures                     | Cloudflare Access logs                 | Any                                     |
| Tunnel down, `/api/health` failing                | Cloudflare and Compose health checks   | 2 consecutive failures                  |
| DB authentication failures, connection-limit hits | PostgreSQL log                         | Any                                     |
| Backup job failure                                | Backup script exit status              | Any                                     |
| Unexpected deploys                                | Cloudflare and GitHub audit logs       | Any deploy outside a release            |

Logs must carry time, event, outcome and a correlation ID, never passwords,
cookies, tokens, TOTP codes or workout payloads.

## Runbooks

1. **Member account compromise.** Revoke all the member's sessions
   (`DELETE FROM "session" WHERE "userId" = …`), require password reset, check
   2FA status, review session IPs and user agents, tell the member what changed
   and when. Verify the old cookie returns 401.
2. **Cloudflare service token leaked.** Create a new token, `wrangler secret
put` it, deploy, then revoke the old token in Access. The worker secret and
   member sessions still protect the API in the interval. Review Access logs.
   Verify requests with the old token get 401/403.
3. **Database credential leak.** Rotate the role password with
   `bootstrap-db-roles.sh`, update `DATABASE_URL`, restart the API. Review
   `pg_stat_activity` and logs for unknown clients. The database is not
   publicly reachable; confirm that first.
4. **Stolen backup.** Archives are age-encrypted; treat as an exposure only if
   the identity key may also be exposed. Rotate the age key, re-encrypt
   retained backups, assess notification obligations.
5. **Malicious dependency.** Pin to the last known-good lockfile, rebuild from
   a clean runner, rotate every secret the build or runtime could read
   (see the `AUTH_SECRET` warning below), audit outbound traffic.
6. **Compromised CI.** CI holds no deploy secrets. Revoke GitHub tokens,
   review workflow and branch changes, rebuild from a verified commit.
7. **Widespread unauthorised access.** Stop the intended API with explicit Compose project and environment arguments
   so guest mode keeps working, preserve logs and a database snapshot, find the
   root cause, end every session (`DELETE FROM "session"`), restore service,
   and notify affected members.
8. **Database corruption.** Stop writes, snapshot the volume, restore the last
   good backup into an isolated `forma_restore_*` database, compare, then
   switch. Re-run `grant-runtime-access.sh`.
9. **Tunnel or backend outage.** Guest mode is unaffected; signed-in members see
   the offline state and keep unsent edits. Check `cloudflared` and API health,
   restart, confirm `/api/health`.
10. **Host compromise or ransomware.** Isolate the Droplet with the cloud
    firewall, preserve a snapshot for forensics, rebuild from a clean image,
    rotate every secret, restore from an off-host backup verified against a
    known-good signature, then notify.

**`AUTH_SECRET` warning.** It signs cookies, derives member references and
throttle keys, and encrypts TOTP secrets and recovery codes. Rotating it ends
all sessions, changes every member reference, and makes existing 2FA secrets
undecryptable, so members with 2FA would need recovery. Rotate it only when it
is believed exposed, and plan 2FA re-enrolment. Ending sessions alone does not
require rotation.

**Lifting a sign-in lock.** Locks are keyed by an HMAC, so compute the key
for the member's address and delete the row. First select the intended
`COMPOSE_PROJECT_NAME` (`forma-staging` or `forma-production`) and its protected
`COMPOSE_ENV_FILE`; do not rely on the Compose file's staging default:

```sh
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" \
  -f ops/compose.yaml exec api node -e '
const { createHmac } = require("node:crypto");
const email = process.argv[1].trim().toLowerCase();
console.log(createHmac("sha256", process.env.AUTH_SECRET)
  .update(`throttle:sign-in:${email}`).digest("hex"));' member@example.com
# then, as the runtime role:
# DELETE FROM security_throttle WHERE scope = 'sign-in-failure' AND key_digest = '<hex>';
```

Confirm the member's identity out of band before lifting a lock, and look for
the suppression warnings that indicate a targeted lockout.

After any incident record the timeline, root cause, fix and the regression test
that now covers it.
