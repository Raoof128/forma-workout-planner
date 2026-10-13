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
Current operation checks: 6 Python and 8 edge-monitor/dashboard tests, including missing
containers, unavailable/malformed R2 objects and hourly alert suppression.

Provider-wide Access attempts and unexpected Cloudflare/GitHub deployments
still require dashboard review. DigitalOcean cloud-firewall inventory and shared
host maintenance remain separate operator work; FORMA itself has no public
backend ports. Mail acceptance does not establish inbox receipt. Hosting limits
are suitable for an initial launch and must be reviewed before growing traffic.
The Email Service sender is the existing verified FORMA sending subdomain;
the word `staging` in that provider hostname does not change account isolation.

## Final hosted canary

Public Worker version `858e5694-89f3-4ea6-9539-e60e2b85764c` serves the polished account
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

The canary account used a random password in protected test evidence. The owner
subsequently requested removal of all production accounts after visual polish;
the completed reset is recorded below. The temporary password file was removed.

## Branding, loading and journals

The original three-facet F mark now appears in navigation, account screens,
favicon and real pending states. Motion uses transform/opacity, stable action
labels and native reduced-motion handling. [Research and accessibility evidence](../research/brand-motion.md)
records the references. Workout history shows real session/set/time totals,
grouped entries and correction controls while preserving units.

The owner-only dashboard at `https://forma-ops.raoufabedini.dev` is behind
Cloudflare Access email authentication. It reads only bounded, sanitized monitor
observations, with no member database access or backup downloads. JWT validation
requires a valid signature, exact issuer and audience, and the owner identity.
Both standard string/array audience formats are supported. Certificate and
health fetches use Workers-supported manual redirects and reject non-success
responses. Temporary diagnostic routes and QA service policies were removed.

Polished staging version: `09874f65-df57-4df0-8dd3-5d94ecf32715`.
Dashboard version: `3e2e2188-39bb-40a2-b212-6a9344d3636f`.
Independent monitor version: `d67f5f12-b6b6-47b8-9aab-3e72fffe4f06`.

Verification: 258 development guest browser cases and 40 production guest cases
passed. The production account run passed 40 cases; its five migration cases
exposed a duplicate status announcement, which was corrected, and all five
passed on recheck. Eighteen history cases passed across Chromium, Firefox and
WebKit. Loading/reduced-motion checks and live dashboard desktop, 390px and 320px
checks had no overflow, page errors or axe violations. Live staging confirmed
1,661 exercises, full guides and anonymous workspace denial. The polished public
canary again passed verified sign-in, private saves, two-session persistence,
export and forged member rejection before cleanup.

Database backups do not contain runtime environment configuration. Preserve the
protected deployment configuration, especially `AUTH_SECRET`, separately for
MFA recovery; rotating it while enrolled accounts exist requires a recovery plan.

## Owner-requested production reset

After deployment and the final polished member canary, the owner authorised
clearing every FORMA production account so they could register afresh. On
13 October 2026, production went from two users to zero. All nine auth/workspace
tables were checked: users, credentials, sessions, verification records, MFA,
MFA replay records, workspaces, operation acknowledgements and abuse budgets
were empty. Only the production API was briefly stopped to prevent write races.

Production `AUTH_SECRET` was regenerated after confirming no enrolled MFA rows
remained, invalidating old action links. The API returned healthy; no ports were
published. Staging configuration/data and every other running container retained
their previous state/IDs. Encrypted signed backups were verified before and
after reset on the owner's private remote. Historical encrypted backups remain
subject to the existing 34-day lifecycle; the reset does not claim to erase them.

The post-reset public browser check passed: page and gateway health 200,
anonymous session null, private workspace 401, usable Create account form,
no overflow at 390px/320px and no page errors. The operations dashboard denied
anonymous access. No new test account was created after the reset. Temporary SSH
resources, scoped tokens, canary credentials and plaintext recovery-key scratch
files were removed. The owner can now register their personal account normally.
