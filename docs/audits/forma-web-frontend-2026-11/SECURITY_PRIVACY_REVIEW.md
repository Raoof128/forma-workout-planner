# Security and privacy review

The changes retain Better Auth cookie sessions, server-derived member identity, CSRF and exact Origin checks, Worker route/method/header allowlists, protected API origin, redirect validation, MFA, throttling, member isolation, coach scopes and account-deletion review. No authentication rule, database migration, historical exercise ID, measurement unit or workspace schema changed. No secret was added to Vite variables.

User and imported text remains rendered through React text nodes. Existing nested validation, aggregate backup bounds, the 20 MiB import limit, damaged-source preservation and explicit revision-bound import confirmation remain. Repository epochs, owner-keyed remount/disposal and original-value checks retain their existing roles. A failed write retry retains its exact payload and operation ID; reconnection without a pending write performs a read. The new profile reconciliation preserves later drafts while explicit conflict reload discards only the reviewed training fields, retaining edits made after the click.

The server correction builds the initial profile-name prefix from complete Unicode code points within the existing 50 UTF-16-unit limit. The original implementation failed PostgreSQL JSONB insertion for a valid boundary-length account name. The real PostgreSQL regression now covers three boundaries; all 77 server checks passed. Existing stored data is not rewritten.

The timer fix binds local stopwatch ownership to the exercise identity and row key, releases stale wake locks, rejects late grants and suppresses removed/replaced targets. The guarded update checks current data again before recording a set. These changes do not persist a new timer format. All 15 new lifecycle checks passed across three engines, including real cross-tab storage notifications with controlled wake grants.

## Test and artifact boundaries

Earlier account tests used disposable PostgreSQL 18.4 in Docker. After repeated Docker precondition failures, the final server/account environment uses an existing PostgreSQL 18.6 binary with a new private temporary cluster and socket on loopback. No existing database, global service or configuration is changed. All three database test variables target that same isolated database; accounts, schemas and mail are synthetic. Some browser cases intercept APIs to control races; those are not represented as database transactions. The repeated WebKit development timeout was reproduced with the original case and with independent setup in parallel. The unchanged case then completed in 20.873 seconds when continuous trace-filmstrip capture alone was disabled. A narrow setting in the security spec retains DOM/network/source traces and failure screenshots; assertions, scenario and the 30-second limit are unchanged. Full-profile and final matrix dispositions are recorded in [test results](TEST_RESULTS.md).

Browser screenshots contain synthetic training data and names and use fresh browser contexts. Native screenshots have metadata removed with decoded-pixel comparisons. Original already-pushed native screenshots were privately inspected and contained generic screenshot metadata without private device identifiers; no history rewrite was needed. Raw device identifiers, logs and xcresults remain outside the repository.

No production member, production deployment, live infrastructure, original iPhone app data or device security setting was modified. A read-only request to the public website was unavailable, so this review establishes neither current live health nor deployed fixes.

## Dependencies and remaining limits

The clean pinned install reported seven moderate npm audit entries associated with the existing development-only minimatch advisory and lint dependents. The existing scoped OSV exception expires on 4 January 2027. No forced dependency upgrade or new exception was introduced. See the [reviewed advisory](https://github.com/advisories/GHSA-g3hv-75wg-m249).

The final Worker/account matrices and staged secret scan are reported in [test results](TEST_RESULTS.md). This source review and local verification do not certify deployed configuration or constitute a penetration test. Legal approval, media rights, operational release acceptance and real assistive-technology checks remain outside the completed local audit.
