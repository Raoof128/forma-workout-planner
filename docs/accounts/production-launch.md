# Public account launch — 13 October 2026

The owner authorised completing and activating public accounts at
`https://forma.raoufabedini.dev`. Activation follows the verified operational
controls below. Public registration and the hosted member canary passed.

## Verified infrastructure

- Separate `forma-production` Compose project, PostgreSQL volume, roles and
  credentials, protected Tunnel and Access service token. API runs as UID 10001
  with a read-only filesystem. No API/database ports are published.
- Production is bounded to 256 MiB each for API/database and 96 MiB for the
  connector on the shared host. Approximately 1 GiB was available before
  provisioning. Every unrelated running container retained its ID.
  Use `ops/compose.production-host.yaml` with the base Compose file. The Tunnel
  token file must be owned by its container UID/GID 65532 with mode 0400, inside
  the protected deployment directory. Its initial incorrect ownership caused
  Cloudflare 1033 during the canary; correcting that file restored the connector.
- Staging and production use separate private Cloudflare R2 backup buckets and
  credentials scoped to their own bucket. No existing bucket was changed.
  Archives are age-encrypted and their checksum manifests are Ed25519-signed.
  Independent 34-day lifecycle rules enforce the policy's 35-day deletion limit.
- Both actual off-host archives were downloaded only to the Droplet, signature
  verified and restored into temporary databases. All table fingerprints matched;
  live databases stayed unchanged and restore databases were removed. A modified
  signature failed verification. No member rows were exported to the sandbox.
- Daily systemd backup timers and one-minute host monitoring are active for both
  projects. Cloudflare accepted the owner-approved operations test message.
  Synthetic staging records exercised sign-in failures/locks, MFA locks, mail
  suppression, stale-member bursts and gateway rejection through the real mail
  pipeline. They did not send member requests or change member records.
- An independent five-minute Cloudflare Worker checks public gateway health and
  production remote-backup freshness. It has no public route. Two failures alert
  the owner's approved inbox, with hourly suppression to prevent a mail flood.
  Alert suppression uses a separate KV namespace, so unavailable or malformed
  backup objects still produce alerts. Missing host containers count as failures.
- A staging Access-token rotation verified new-token health and old-token
  revocation. Auth signing secrets were preserved to avoid invalidating MFA.

## Recovery and operating commands

Protected configuration lives under `/opt/forma-staging/operations/` and
`/opt/forma-production/operations/`. Run the corresponding operations service,
or invoke `account-operations.py config.json backup` from that directory.
Monitor output contains event names and counts, never member payloads.

Each R2 bucket retains `recovery/identity.wrapped.age` and `verification.pem`.
The recovery identity is encrypted to the owner's existing SSH public key;
the matching private key must be retained separately. Retrieve and unwrap that
identity on an authorised recovery machine, then use the `restore` command with
an archive name and protected identity file. The script creates and removes a
separate `forma_restore_` database. It never replaces the live database.
Keep the signing public key independently when verifying disaster recovery.
Before replacing the operator SSH key, rewrap and verify both recovery identities.
Public verification keys are pinned in [staging](backup-public-keys/staging.pem)
and [production](backup-public-keys/production.pem).

Backups include table fingerprints from the same exported PostgreSQL snapshot
used by `pg_dump`. Restore verifies those signed backup-time fingerprints rather
than comparing with today's live rows. Both environments passed recovery in a
disposable container where no live `forma` database existed; the fixture and
temporary plaintext decryption identities were removed. These checks also prove
that later live writes do not make an older valid archive unusable.

## Verification and limits

The logging change passed all 46 real-PostgreSQL server tests. Backup tampering,
restore-target refusal and monitor thresholds have Python checks; independent
edge health checks have Node tests. Earlier production UI matrices passed 45
member and 40 guest cases on the catalog release. Updated legal-page checks
are recorded separately rather than claimed as a new full UI matrix.
Current operation checks: 6 Python and 5 edge-monitor tests, including missing
containers, unavailable/malformed R2 objects and hourly alert suppression.

Provider-wide Access attempts and unexpected Cloudflare/GitHub deployments
still require dashboard review. DigitalOcean cloud-firewall inventory and shared
host maintenance remain separate operator work; FORMA itself has no public
backend ports. Mail acceptance does not establish inbox receipt. Hosting limits
are suitable for an initial launch and must be reviewed before growing traffic.
The Email Service sender is the existing verified FORMA sending subdomain;
the word `staging` in that provider hostname does not change account isolation.

## Final hosted canary

Public Worker version `c508102c-e0cc-4b46-9df5-94c384f60eb6` serves the account
build. API image config digest is
`af3527faa9f3e61fd0ff8b70c13202150ea0bbbf7a3ace87dc5dcfb1e2134a35`;
the Droplet's OCI manifest digest is
`cabbc8609d0cbc9d1606ca243f6056b9906c44158412676eba107c2efffbce59`.

- Public page and gateway health: 200; anonymous private workspace: 401.
- Real registration: 200; no session before verification. The owner confirmed
  actual receipt and clicked the verification link; verified sign-in returned 200.
- A real 600-second/900-metre synthetic workout saved through the public UI,
  persisted after reload and appeared in a separate signed-in browser session.
- Private export returned 200; forged member binding returned 409.
- Mobile layout had no horizontal overflow and no page errors occurred.
- Synthetic workout cleanup succeeded through the normal revision API.

The owner inbox account is verified. Its canary password was random and retained
only in protected test evidence; use the normal Forgot password flow to choose
a personal password before continuing with that account.
