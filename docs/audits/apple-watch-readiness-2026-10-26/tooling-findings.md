# Tooling audit — baseline 1794dd27fad87e8f0cc6f4923d37eedf713783ed

All 63 manifest paths match their expected byte lengths and SHA-256 values. All 62 authored files were read in full, including the complete 1,313-line AGENT.md and 1,394-line CHANGELOG.md. The generated lockfile was parsed and traversed exhaustively (506 records; 505 package versions/registry URLs/SHA-512 integrity fields; 902 dependency edges and 114 peers). All 25 direct pins agree; required dependency edges resolve and satisfy their ranges, with the declared Miniflare override accounted for. Syntax-only validation passed on 37 JavaScript, Python and shell files. No repository file, generator output, infrastructure or secret was changed/read beyond the authorized source audit.

## Confirmed defects

### T01 — P2 — Restore isolation checks the URL suffix instead of the resolved database

- **Evidence:** `ops/restore-postgres.sh:12` validates the independent `RESTORE_DATABASE_NAME`; `:13` accepts the connection string solely when its final characters are `/` plus that name. `:29` then passes the entire original string to `pg_restore --clean --if-exists --dbname`.
- **Observed:** a synthetic PostgreSQL URI whose actual path names `forma`, with an ordinary connection query value ending in `/forma_restore_audit`, passes the exact Bash predicate. The installed libpq `PQconninfoParse` resolves its database to `forma`, not `forma_restore_audit`. Parsing was local only; no connection, restore, decryption or backup command ran.
- **Impact:** the guard does not enforce the documented isolation promise. An operator-supplied connection string can pass validation while targeting a non-isolated database, after which the destructive restore receives it. This is an operator-tool guard failure, not an unauthenticated remote attack.
- **Recommendation:** parse the actual libpq connection target, require its database to equal the validated isolated name, reject conflicting query database parameters, and use an isolated restore role. Add a pure parser/predicate regression before any restore execution.
- **Scope limit:** current signed production recovery uses `ops/account-operations.py`, which creates and selects a generated `forma_restore_` database directly. This finding concerns the still-documented shell restore path; no live recovery was tested.

### T02 — P2 — A timed-out host probe discards monitor state and prevents its alert threshold

- **Evidence:** `ops/account-operations.py:229–238` loads/increments local failure state. Its `docker exec` health probe at `:240–241` uses a 15-second subprocess timeout without catching `TimeoutExpired`; later Docker log reads at `:248`, `:260` and `:263` have the same issue. Alerting and persistence occur only at `:278–282`. The top-level catch at `:309–312` prints an exception type and exits.
- **Observed:** using mocks only, two successive monitor calls with unhealthy containers and a timed-out health subprocess both raise `TimeoutExpired`; neither writes state nor calls the alert function. Every timer invocation therefore begins again from the old counter.
- **Impact:** a hung Docker/API health command—one condition the monitor should report—disables host alert evaluation and prevents consecutive-failure progress. Disk, database-auth and security signals later in the function also remain unchecked during that condition.
- **Recommendation:** convert each bounded subprocess failure into a fixed signal, persist the failure observation, and continue the checks that remain possible. Keep error bodies/credentials out of messages. Cover repeated timeout behavior with mocked subprocesses.
- **Scope limit:** the separately deployed edge Worker can still alert on public gateway or backup failure. This finding does not claim total monitoring loss, nor does it establish the current host state.

## Apple/Watch readiness gaps — not regressions in the existing web product

### TW01 — No native Apple application/tooling target

`package.json:6–35` defines Vite/Node/Worker/browser tasks; `README.md` describes a React/Vite product and explicitly excludes Apple Health integration. `index.html` is the web entrypoint. The baseline tracked-file query returns no Swift sources, Xcode projects/workspaces, entitlements or PrivacyInfo.xcprivacy files. There is no native iOS/watchOS companion, HealthKit/WatchConnectivity capability/signing configuration or native release artifact to build or review. Browser implementation alone cannot establish the requested Watch integration.

### TW02 — CI/browser coverage cannot certify paired-device behavior

`.github/workflows/ci.yml:20` and `:69` run Linux jobs; the Node toolchain is 24, while Docker uses Node 26. Production/account mobile projects in `playwright.production.config.js` and `playwright.accounts.config.js` use Playwright's iPhone 13 device profile with desktop-hosted browser engines. These are valuable web checks but supply no macOS/Xcode build, Simulator/native tests, signing validation, paired physical iPhone/Ultra 2, locked/background transfer, HealthKit permission/recording or interruption/recovery evidence. Add those release gates with the native implementation; do not relabel current emulation as physical Apple coverage.

## Reviewed operational constraints and limits

- Ten application tables declared by the numbered migrations are covered by runtime DML grants. The migration ledger is intentionally not granted to the runtime role. No migration was run or changed.
- Compose publishes no backend/database host ports, separates the internal database network, uses secret files, non-root API execution, bounded logs and resource overrides. `name: forma-staging` remains a documented operational hazard; supported shell wrappers explicitly require and pass the project name. Never infer current host resource usage from committed overrides.
- API schema/catalog changes require API-first deployment. Both Docker stages use the same pinned Node 26.12.1 digest. CI builds the actual image and imports core server entry modules; the parent reviewer owns whether that build was executable here.
- The legacy shell backup is encrypted plus a checksum sidecar; the signed remote-backup implementation is the Python tool. Current docs distinguish them. Remote keys, retention rules, service timers, restored data and permission policies were not inspected.
- The 32 unique SVG demonstrations and source generators were reviewed as authored code, including reusable poses, draw order, timelines, XML escaping and still generation. This is not a fresh anatomical/frame-by-frame visual review. No catalogue, registry, image, video or SVG was rebuilt.
- Token cleanup uses `finally` for ordinary errors; abrupt process termination and live Cloudflare revocation were not exercised. Provider policy correctness and current advisory results remain outside this local static audit.

## Additional operational readiness gap

### TOG01 — Liveness is treated as database connectivity

`ops/account-operations.py:239–245` claims its HTTP probe includes database connectivity, but `server/app.ts:551` returns a static success from `/healthz`. The DB container health check (`ops/compose.yaml:35–36`) is `pg_isready`, not a runtime-role application query. The later monitor log scan (`ops/account-operations.py:260–262`) matches selected authentication/connection-limit errors only. `docs/accounts-infrastructure.md:85` correctly documents the endpoint as liveness. Add an authenticated bounded database readiness probe; current healthy signals do not certify working account queries/grants. This is a coverage gap, not a reproduced live database outage or a new backend endpoint defect.
