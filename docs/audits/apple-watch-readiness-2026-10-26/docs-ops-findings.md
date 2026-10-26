# Operations and security documentation review

Baseline: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`.

All 39 assigned authored files (295,755 bytes) were read in full, including all four email HTML fixtures and every dated plan, assessment and readiness table. Every file matches its manifest length and SHA-256. The per-file ledger is `docs-ops-review.json`. Current instructions were distinguished from clearly dated launch records; historical passing checks are not reported as fresh tests. No production, secret, inbox, provider settings or live restore was accessed.

## Confirmed documentation defects

### DO01 — P3 — Current operations/legal guidance retains obsolete setup claims

- `docs/legal/README.md:50–52` states that backups are not configured, while its own current retention commitment is 35 days. `docs/accounts/operations.md:3–7` says encrypted remote backups and monitoring are deployed, and `docs/accounts/production-launch.md:19–28` records separate signed, encrypted remote backups, 34-day retention and daily timers. `docs/security/privacy.md:26` and `:56–59` also describe those controls and correctly qualify the dated evidence.
- The local-development instructions at `docs/accounts/operations.md:48–52` say the harness applies “both SQL migrations”, although the baseline contains six numbered migrations and the harness enumerates and applies all numbered SQL files (`scripts/accounts-test-server.ts:25–36`). This is stale wording, not a two-migration runtime defect.
- **Impact:** a maintainer using the current legal and operations guide gets contradictory information about established controls and setup scope. The audit does not infer that backups are currently absent or that retention currently fails.
- **Recommendation:** replace the obsolete setup statements with the implemented workflow, link dated evidence, and explicitly separate current verification obligations from recorded deployment history.

### DO02 — P3 — Sensitive-data inventory omits coach access to workout data

- `docs/security/privacy.md:20` lists workout workspace access as “Member only”; the same table at `:23` acknowledges read/full coach tokens.
- `server/coachRoutes.ts:230–252` authenticates a read-capable bearer token and returns the token owner's workspace summary. `server/coachTokens.ts:313–328` specifies routines, recent sessions, personal bests and weekly totals. Full-scope coach routes additionally permit workspace access and updates, as documented by `docs/accounts/api.md`.
- **Impact:** the current internal privacy inventory understates authorized recipients of sensitive workout information. This does not establish unauthorized access; coach access is intentionally member-authorized. Any broader published-policy issue should be consolidated with the parent audit's legal/UI findings.
- **Recommendation:** state that a member and their authorized coach-token holders can access the relevant data, distinguish read/full scope, and describe revocation/expiry and the limits of revocation after a recipient has copied data.

## Confirmed code finding carried by these documents

**T01** in `tooling-findings.md` applies to the documented shell restore workflow. `docs/accounts/operations.md:231–233` promises that the shell helper refuses non-isolated target databases; its URL-suffix predicate does not enforce that promise. `docs/accounts-infrastructure.md:112–119` correctly instructs an isolated target, but the implementation still accepts a synthetic URI whose query suffix passes the predicate while libpq resolves the live database name. The signed Python workflow is explicitly distinguished at `docs/accounts-infrastructure.md:95` and `docs/accounts/operations.md:239–242`; do not attribute this shell defect to the production signed restore path.

## Operational and Watch readiness gaps, separate from confirmed defects

### TOG01 — Monitoring does not provide an authenticated database readiness probe

`docs/accounts-infrastructure.md:85` correctly calls `/healthz` API liveness and says database checks must be monitored separately. `server/app.ts:551` returns a static success; the container database check is `pg_isready -U forma_bootstrap -d forma` (`ops/compose.yaml:35–36`). The host monitor nevertheless says its HTTP probe includes database connectivity (`ops/account-operations.py:239–245`). The following database-log scan (`:260–262`) only matches selected authentication/connection-limit strings. There is no periodic authenticated runtime-role query in that path. A healthy monitor result therefore does not certify working account queries or current runtime grants. Add a bounded authenticated readiness check and correct the comment; no live DB outage was induced or established by this audit.

### DOW01 — Current web/account contracts do not define native Watch synchronization

`docs/architecture.md`, `docs/data-model.md`, `docs/member-data-sync.md` and `docs/security/threat-model.md` describe browser-local and server-authoritative web accounts. They do not define a paired-device workout identity, phone/watch ownership transfer, interrupted/background delivery, duplicate HealthKit write prevention, HealthKit permission/revocation, on-watch offline conflict handling, native secure token storage or native Apple privacy/signing/release evidence. This is a future integration design and validation gap, not a regression in the web application. The absence of native source/build targets is independently recorded as TW01/TW02 in the tooling review.

## Limits and positive consistency observations

- Historical browser-only backend reviews, original NO-GO tables, plans and penetration-test dispositions were read fully and interpreted using their dates and explicit superseding launch links. They are not evidence of today's deployment state.
- Operational docs consistently separate checksum-only manual shell backups from the deployed signed-manifest Python workflow, except for the shell isolation assurance affected by T01.
- Incident-response account-lock HMAC instructions match the implemented `throttle:sign-in:<normalised-email>` key namespace; no credential was read and no lock changed.
- Email fixtures contain preview/action copy and placeholder URLs, not an exercised mail provider integration. All fixture source was read; client-specific rendering and inbox delivery remain unverified.
- Legal applicability and external source currency were not independently adjudicated. Documentation review is not legal certification.
