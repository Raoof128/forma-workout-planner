# Account release readiness

**Latest maintenance release, 26 October 2026:** the runtime audit is deployed
to staging and production. Both passed the defined anonymous HTTP and browser
smoke; existing accessibility findings remain follow-ups. Completed temporary
release-access cleanup and ongoing application CI are recorded separately in the
[dated release receipt](../qa/runtime-quality-2026-10-26/README.md). The launch
decision below remains the historical 13 October record.

**Launch status, 13 October 2026:** GO for the owner-authorised controlled
production activation. Hosted staging lifecycle, isolated production services,
credential rotation, signed off-host restores, scheduled backups and alerts have
now been verified. See [the current launch record](production-launch.md) and
[security verdict](../security/release-security-verdict.md).

The report below is historical evidence from the original implementation
candidate. Its unavailable SSH, undeployed resources and NO-GO statements are
superseded by those current records, not descriptions of today's environment.

**NO-GO for external release.** The implementation and local deployment checks
are complete enough for review; required hosted staging and operational gates
remain unverified. This report does not claim a Cloudflare or DigitalOcean
deployment. The candidate is on `feature/self-hosted-accounts`, in
[draft PR #2](https://github.com/Raoof128/forma-workout-planner/pull/2), stacked on
the earlier browser audit PR #1.

## Credential and deployment status

All four owner-provided credential bindings were present in the running
environment and matched the upload without printing their values. The temporary
downloaded `.env` was removed after this verification; no credential values
were added to Git, build configuration, or client assets. Reusable environment
installation/startup instructions were saved as a draft; publication and
fresh-task restoration are separate platform operations.

Cloudflare token verification and selected-account Worker, Tunnel, Access-app
and DNS inventory now succeed. No FORMA application resources were found during the initial inventory. The owner then
supplied a burner SSH key and requested it in `/workspace/.env`, outside Git.
That file has mode 0600, preserves the existing bindings and key line breaks,
and the key parses with the expected fingerprint. A key-based SSH attempt on
port 22 with normal process permissions still fails before authentication with
connection refused. The owner reports successful access from their Mac; the
cause of this environment's connectivity failure remains unproven.

The owner selected Cloudflare Email Service and approved the four branded templates.
Cloudflare enabled `mail-staging-forma.raoufabedini.dev` and created its six
provider-required DNS records, all matching the provider configuration. No apex
DNS, existing mail routing, unrelated backend, or paid plan was changed. All
temporary provisioning tokens were revoked; the dedicated account-scoped Email
Sending Read/Write token remains in the protected local `.env`.

On 12 October 2026, the owner-authorized single template test received HTTP 200
with `success=true`, the controlled recipient in `queued`, no permanent bounce,
and no provider errors. The subject is `[FORMA STAGING DELIVERY TEST] Approved
email template`; no account was created and its link cannot verify an account.
This establishes provider acceptance, not inbox receipt. Gmail access is not
available through this session's tools. See [domain evidence](email-domain-onboarding.json)
and [mail acceptance evidence](mail-delivery-test.json). A hosted application
lifecycle, public DNS verification and actual inbox receipt remain unverified.
Off-host backups and the private application deployment remain unverified.

## Implemented architecture

The browser uses the existing React workout interface and a separate guest
workspace. Member data uses a same-origin Worker API, a private Fastify/Better
Auth service, and PostgreSQL. The Worker has a fixed upstream and a strict
route/method allowlist, strips caller-supplied service headers, and supplies
Access service credentials plus an origin secret. The API separately verifies
member sessions and expected-member binding. Owner-filtered SQL, revisions,
transactions and bounded idempotency protect private writes and retries.

Account features include verified registration, password reset/change, email
change with approval at the old address and verification at the new address,
session management, TOTP/recovery codes, profile editing, private export and
confirmed deletion. The frontend keeps member data out of guest localStorage,
requires explicit migration review, and exposes save/conflict recovery.

The operational configuration has no public database/API port, separate runtime
and migration roles, a non-root read-only API container, and encrypted logical
backups. Committed `.invalid` origins are placeholders, not hosted endpoints.

## Executed local evidence

On implementation candidate `ebbec2eae455388013076b09facfbca341e108e3`,
**40 unit** and **11 Worker** tests passed. The independent reviewer also ran
**24 server tests**, including real PostgreSQL authentication/workspace
integration and the new provider/template checks; all passed with no skips.
The email transport tests inject fetch responses and do not establish inbox
delivery. The full Better Auth lifecycle generates real signed action URLs,
which are rendered before the isolated email sink captures them.
Worker tests use an injected upstream and do not establish deployed edge
connectivity.

- Pinned Chromium, Firefox and WebKit guest regression matrix: **237 passed**.
  Supplemental system Chromium run: **79 passed**.
- Guest production smoke: **20 passed (five desktop/mobile browser projects)**.
- Account development matrix: **45/45 passed on `ebbec2e`**, all five projects 9/9.
- Account production-built matrix: **45/45 passed on `ebbec2e`**, all five projects 9/9. Both final runs used the restored, unchanged candidate; provisional runs with working-tree edits are excluded.
- [Branded account email previews](email-previews/README.md) include HTML/plaintext verification, password reset, email-change approval and deletion messages. Desktop/mobile browser captures were inspected. These are synthetic previews, not email-client or delivered-message evidence.
- Actual profile screenshots were inspected at 320/390/1536px after fixing a Firefox form-grid overflow with a long email. Representative [mobile](../qa/accounts-screenshots/profile-320.png) and [desktop](../qa/accounts-screenshots/profile-1536.png) captures use synthetic test accounts. Final-source Security, Training data and Privacy captures were also inspected at390/1536px with no horizontal overflow; expanded/error/loading visual states still require audit.
- Lint, formatting, TypeScript, frontend/server builds, documentation links and
  patch whitespace passed. Production dependency audit reported zero findings.
- [Container evidence](container-evidence.json): Docker image built with strict
  TLS, API ran as UID/GID 10001 with a read-only root filesystem, and health
  returned HTTP 200 in an isolated disposable Compose project.
- [Runtime-role evidence](runtime-role-evidence.json): application DML passed;
  migration-ledger reads and CREATE/ALTER/DROP were rejected. Runtime role has
  no superuser, create-database or create-role privileges. No RLS claim is made.
- [Backup/restore evidence](backup-restore-evidence.json): PostgreSQL 18.4
  `pg_dump` → age encryption/decryption → separate-database `pg_restore` passed;
  member/workspace/revision matched exactly and corrupted ciphertext failed.
  This did not test off-host upload, retention scheduling or production recovery.

Browser harnesses use a disposable PostgreSQL schema and a loopback-only email
sink. Built-account tests exercise Vite preview assets and the real local API;
they do not substitute for a hosted Worker/Tunnel/Access/email-provider journey.
The test harness alone has a bounded increased rate-limit bucket because all
fixtures share one IP; server regressions verify normal limits remain enforced.
Local Firefox used approved normal process permissions for its internal sandbox.
WebKit used verified Debian libraries in its local bundle; a local ldconfig-only
precheck was skipped, while actual browser launch and test assertions ran.
Hosted CI uses the standard browser installation without these local overrides.

Both full GitHub CI runs on `ebbec2e` completed successfully: [push workflow](https://github.com/Raoof128/forma-workout-planner/actions/runs/38198690402) and [PR workflow](https://github.com/Raoof128/forma-workout-planner/actions/runs/38198694083). These are CI results, not hosted application deployment checks.
The historical browser-only report in `docs/qa/release-readiness.md` applies to
the prior `86cf` baseline and is not account-release acceptance.

## Mandatory gates

| Gate | State | Evidence and remaining requirement |
| --- | --- | --- |
| A — Account functionality | Local integration verified; hosted pending | Server lifecycle checks and browser journeys use real Better Auth/PostgreSQL; actual email delivery and hosted lifecycle remain required. |
| B — Member ownership | Local PASS; staging pending | Two-member read/write/export isolation and stale shared-cookie member mismatch are tested. Repeat through hosted gateway. |
| C — Workout data | Local integration verified; staging pending | Workouts, revisions, persistence and retry/conflict recovery are implemented and tested; final matrix evidence is listed above. |
| D — Migration | Local integration verified; staging pending | Reviewed guest import retains local data and verifies server values; production-like migration journey remains required. |
| E — Cross-device sync | Local integration verified; staging pending | Separate browser contexts, stale revision conflicts, lost acknowledgements and delayed reads are covered; hosted two-device run remains required. |
| F — Cloudflare | BLOCKED | Token source-IP restriction cleared; selected-account Worker/Tunnel/Access/DNS inventory reads succeeded. Isolated Email Sending domain setup and one queued test are verified. Application resource writes and deployed routing/cookies/headers remain unverified. |
| G — Private backend | BLOCKED | Local container and database privileges passed; refused SSH prevents host inspection, isolated staging install, firewall and egress verification. |
| H — Security | Bounded source review PASS; hosted pending | No unresolved high finding in the reviewed candidate. Live origin access, operational controls and provider configuration remain unverified. |
| I — E2E/accessibility | Browser matrices PASS; control-state coverage incomplete | Final account matrices passed 45+45. The 74-control inventory remains PARTIAL for missing per-control keyboard/error/loading evidence. |
| J — Backups/recovery | Local isolated restore PASS; operations pending | Real encrypted restore drill passed. Off-host storage, scheduled uploads, access controls and alerting remain unverified. |
| K — Documentation | Maintained for this candidate | API/schema/operations/security/sources and truthful evidence are present; deployment values intentionally remain placeholders. |
| L — Independent review | Bounded candidate acceptance | See the immutable-SHA review; this is not approval for release while mandatory gates remain incomplete. |

## Review and remaining limitations

[Independent review](../qa/accounts-independent-review.md) reproduced and
verified corrections for stale-account overwrites, MFA replay credentials,
session freshness and deletion callbacks. Further review corrected account
export size, unfinished-set personal records, email-change guidance, recovery
code labeling and password entry, and profile-name consistency.

[The account interaction inventory](../qa/accounts-ui-inventory.json) distinguishes
passed journeys from partial or untested states. Do not describe it as exhaustive
acceptance unless every required state has evidence. Complete those gaps and run
the hosted synthetic-member journeys, isolation checks, actual mail delivery and
off-host recovery procedure before changing this verdict to GO.
