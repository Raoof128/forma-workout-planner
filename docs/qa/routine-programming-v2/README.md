# Routine programming v2 release — 17 October 2026

Production and private staging are deployed in account mode with schema v2.
All requested changes remain in [PR #9](https://github.com/Raoof128/forma-workout-planner/pull/9).
Frontend source is `27e3728`; matching API source is `cca9b07`. Subsequent evidence
and deployment-helper changes do not change either runtime bundle.

## Deployed versions

| Target | Worker version |
| --- | --- |
| [Production](https://forma.raoufabedini.dev) | `e6ea40f3-dbc8-46ee-a7d6-5fc9eb5205ce` |
| Private staging | `29a7cfc6-0caf-428f-9ba8-58803b287573` |

Both APIs run `forma-api:routine-v2-20261017-cca9b07`, Node 26.11.1, UID 10001,
with read-only filesystems and no published ports. Existing API limits remain
320 MiB staging / 256 MiB production. Database/connector services and every
unrelated container retained their IDs.

[Deployment receipt](deployment.json) · [Gateway checks](gateway-checks.json) ·
[Live asset hashes](live-asset-hashes.json) · [Browser layouts](live-browser-layouts.json)

## Verification

| Check | Result |
| --- | --- |
| Unit | 89 passed |
| Real PostgreSQL API | 49 passed, including the final schema under Node 26 |
| Worker gateway | 21 passed |
| Operations | 14 passed |
| Development baseline | 348 unique cases, 116 per engine |
| Full development CI after compatibility corrections | 351 passed, 117 per engine |
| Archive/programming after compatibility correction | 15 development cases passed across three engines |
| Production guest browsers | All 70 unique cases verified, including exact menu replays |
| Production-built real account browsers | Fresh final matrix: 55 passed across five desktop/phone projects |
| Hosted production / staging | 15 programming/archive journeys passed on each |
| Lint, formatting, types, docs, frontend/server builds | Passed |
| Equipment audit / strict artwork coverage | Passed; 1,411 selectable exercises |

The full CI matrices run on pushed commits; current immutable run reports and
artifacts are linked from the PR checks. The production matrix includes all four
programming journeys plus the archived-routine regression in every profile.

The development baseline includes exact replays after a test-server exit and one
isolated Firefox performance replay: 4.4 seconds against the unchanged 10-second
bound. The final production run passed 68 cases; two phone menu-interception
failures were corrected, then all 25 programming/archive cases passed across the
five profiles, completing the 70 unique cases. Failed evidence was retained.
No saved-data assertions or performance limits were weakened. Account suites
used a 60-second CLI test budget in this shared cloud environment.

The final CI production archive test initially reloaded while the trace still
showed `data-saving` and the busy Save control. Both account matrices (55 cases
each) and all 351 development cases passed on those runs. The archive test now
waits for the editor to close after its successful save before reloading, keeping
all range/archive persistence and duplicate assertions. A fresh local production
matrix also passed all 70 cases before this synchronization correction. After the
correction, the full 70-case matrix and nine repeated archive journeys across three
engines passed again. No runtime bundle, sleep, retry, assertion reduction or
larger timeout was added for it.

Hosted checks use Chromium desktop/phone and WebKit phone. Firefox is covered by
local/CI production and account matrices; its hosted attempt was blocked by the
managed proxy's certificate trust. TLS verification was not disabled. Account
matrices use isolated databases and email sinks, not live member identities.

Live desktop/390px layouts have no overflow, page errors or console errors. Live
HTML, JavaScript and CSS byte hashes match the verified account build. Public
health is 200, anonymous workspace access 401 and anonymous session null. Staging
anonymous access remains 302 to Access. CSP/HSTS and HTML `no-transform` remain
intact, with no injected beacon.

## Migration and preserved data

Both projects took verified encrypted and signed off-host backups before and
after migration. Old API writers were paused while numbered migration 0004 ran;
a second runner invocation completed cleanly. Workspace, routine, history and
active-session counts matched. Every stored workspace passed the compiled v2 API
validator on the host; no member row was exported or deleted. No applied
migration was edited. See the [migration contract](../../routine-programming-v2.md).

Production validation detected live `archivedAt` metadata absent from the initial
checkout's schema. SQL had retained the timestamps. Writers stayed paused while
strict validation and archive/restore behavior were corrected. The regression
starts with all routines archived, edits a range, reloads, restores, archives and
duplicates, retaining the original marker and making only the copy active.

Final signed-in testing then exposed a null workspace during initialization of
account/legal routes. The filter now uses an empty list during loading; both
previously failing journeys and the fresh 55-case account matrix pass. The API
image did not need another restart for this frontend correction.

The final image configuration digest is
`0291febef76ec8143eab141fcdea6b5e369d78e15aeca2660007b99c5f095323`;
the host's OCI manifest digest is
`5674089fac6cfc10e3f5a5443640996e876ed816f9e2ff1ae7d9bdf8bd0f6808`.
The transferred archive checksum matched locally and on the host; both identity
forms are recorded because the Docker versions report different fields.
Do not put the v1 API onto migrated v2 rows; use controlled recovery if needed.

## Operations and retained observations

A control-plane permission lookup returned an IP-restriction error, while a fresh
uncached lookup succeeded with the existing credential. The deployment helper now
requests `no-store` responses; the final staging deployment passed. No credential
restriction or token scope was widened. Scoped deploy tokens were revoked in
`finally`. Temporary SSH ingress, DNS, Access apps/policies and service credentials
were removed, and the maintenance token was revoked.

Concurrent development runs emitted two React render-phase warnings without a
caller stack. Four isolated concurrent exact-flow WebKit replays passed without
them. Independent review found no Critical or Important issue and no evidence for
a speculative runtime change. These remain unconfirmed development observations;
the hosted clean-console checks above are separate evidence.
