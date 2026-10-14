# Deployment record

[Back to security overview](README.md)

This page preserves the initial 2026-10-13 (Australia/Sydney) deployment and its
historical guest-only state. Public accounts were subsequently activated; the
[production launch record](../accounts/production-launch.md) supersedes the initial
NO-GO notes and owner follow-ups below. Current artwork/frontend versions and
verification are in the [14 October redeployment record](../qa/site-sweep/deployment/README.md).
This page contains no secret values.

## Initial deployment state

| Surface             | Hostname                                     | Mode                                                                                        | Who can reach it                                                                      |
| ------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Public site         | `https://forma.raoufabedini.dev`             | Worker `forma-workout-planner-production`, guest build; data stays in the visitor's browser | Everyone                                                                              |
| Account staging UI  | `https://forma-staging.raoufabedini.dev`     | Worker `forma-workout-planner-staging`, account build                                       | Cloudflare Access: the owner's email (one-time PIN) and the smoke-test service token  |
| Account staging API | `https://forma-api-staging.raoufabedini.dev` | Tunnel `forma-staging` → `http://api:3000` on the Droplet                                   | Cloudflare Access: only the staging Worker's service token (strict service tokens on) |

The production Worker has no API credentials, so every `/api` request returns
503 before any upstream call. Account sign-up is therefore impossible on the
public site; this follows the release verdict (NO-GO for real members).

## Droplet layout

`/opt/forma-staging` on the shared Droplet (root-only):

- `.env` (`0600`): per-environment secrets, database URLs for `forma_runtime`
  and `forma_migrator`, the Email Sending token, `APP_ORIGIN`.
- `secrets/postgres-admin-password` (`0400`, UID 70) and
  `secrets/cloudflare-tunnel-token` (`0400`, UID 65532): readable only by the
  container that needs them.
- `ops/`: `compose.yaml`, `compose.small-host.yaml` (memory limits for the
  shared 2 GB host), role bootstrap, grants, backup and restore scripts.

Containers: `forma-staging-db-1` (PostgreSQL 18.4, internal network only),
`forma-staging-api-1` (image `forma-api:ee798b5`, UID 10001, read-only root),
`forma-staging-cloudflared-1`. None publishes a host port. Other services on
the Droplet were not changed.

Operate with:

```sh
cd /opt/forma-staging
C="docker compose -p forma-staging --env-file .env -f ops/compose.yaml -f ops/compose.small-host.yaml"
$C ps
$C logs --tail 50 api
```

## Credentials (names and expiry only)

| Credential                                               | Purpose                                       | Expiry / rotation                                                                                      |
| -------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| API token `forma-deploy-2026-10-13`                      | One-off deploy (Workers, Tunnel, Access, DNS) | 24 hours; revoked after deployment                                                                     |
| API token `forma-idp-setup-1h`                           | Added the one-time PIN login method           | 1 hour; revoked after use                                                                              |
| API token `forma-staging-email-send`                     | Staging API sends account email               | 2027-01-10; rotate before then                                                                         |
| Access service token `forma-staging-worker`              | Staging Worker → API (Worker secrets)         | 1 year                                                                                                 |
| Access service token `forma-staging-smoke`               | Operator smoke tests of the staging UI        | 30 days                                                                                                |
| API token `forma-redeploy-1h` (twice)                    | Redeployed both Workers for the legal pages   | 1 hour; revoked immediately after each use                                                             |
| `AUTH_SECRET`, `ORIGIN_SHARED_SECRET`, DB role passwords | Staging API                                   | Generated for staging only; see the `AUTH_SECRET` warning in [incident response](incident-response.md) |

## Verified at deployment

- Access on the API: no token 401, bogus token 401, wrong service token 403,
  Worker token without the worker secret 401, encoded path 404.
- Staging UI: anonymous visitors are sent to the Access login.
- Full member lifecycle through the real chain: sign-up, real verification
  email delivered to a controlled inbox, sign-in (`__Secure-` HttpOnly cookie),
  workspace read, save and export, forged member reference refused, deletion
  confirmed by email with every row removed.
- Public site: app loads, strict CSP and HSTS, `/api` returns 503, the
  `workers.dev` alias is off.
- Isolated restore drill of the staging database.

## Later deployments

- 2026-10-13, commits `2788a5f` and `9031373`: Privacy Policy and Terms of Use
  pages (`#privacy`, `#terms`), sign-up consent checkboxes and collection
  notice. Both Workers redeployed with a one-hour token, revoked after use.
  Verified live: both pages render with their required sections and fit a
  phone screen. See [legal](../legal/README.md).

## Rollback

- Public site: `npx wrangler rollback --env production`, or delete the custom
  domain to take it offline.
- Staging: `$C stop api cloudflared` stops all traffic; the Access apps stay in
  place. `$C down` keeps the database volume; add `-v` only to discard data.
- Remove the Access apps, Tunnel and DNS record in Cloudflare to retire staging
  entirely.

## Owner follow-ups

- The Droplet reports a pending reboot and 74 upgradable packages; it also runs
  other production services, so schedule maintenance deliberately.
- The DigitalOcean cloud firewall was not inspected; restrict SSH to operator
  addresses there.
- The password in the Portfolio `.env` no longer works (SSH is key-only);
  remove it.
- Configure an off-host backup destination and age recipient, then run
  `ops/backup-postgres.sh` and `ops/restore-postgres.sh` (gate S14).
- Security alerting (gate S16) before inviting any member.
