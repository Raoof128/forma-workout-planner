# Test results

All runs were on 9 November 2026 (Australia/Sydney).

- **Runtime:** Node 22.23.4.
- **Database:** PostgreSQL 18.4 (`postgres:18.4-alpine` at the CI digest), in a
  disposable local container, with a separate scratch database per workstream.
- **Browsers:** Chromium 1243, for the account suites.

Each test database was synthetic. No staging or production system was
contacted.

## Baseline (`53c4877`)

| Command                   | Result                |
| ------------------------- | --------------------- |
| `npm run test:server`     | 76/76                 |
| `npm run test:worker`     | 35/35                 |
| `npm run test:operations` | 8 Python + 8 Node, OK |
| `npm run build:server`    | Pass                  |

## Final branch

| Command                                                   | Result                                                                                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `npm run lint`, `format:check`, `typecheck`, `docs:check` | Pass                                                                                                                                       |
| `git diff --check`                                        | Pass                                                                                                                                       |
| `npm run build:server`                                    | Pass                                                                                                                                       |
| `npm run test:server`                                     | **101/101**                                                                                                                                |
| `npm run test:worker`                                     | **43/43**                                                                                                                                  |
| `npm run test:operations`                                 | **14 Python + 9 Node, OK**                                                                                                                 |
| `npm run test:unit`                                       | 160/160                                                                                                                                    |
| `npm run test:accounts` (5 projects)                      | **110/110**                                                                                                                                |
| `npm run test:accounts:production` (5 projects)           | **110/110**                                                                                                                                |
| `node scripts/build-ios-resources.mjs --check`            | Pass; no `ios/` drift                                                                                                                      |
| `docker build -f ops/Dockerfile` + CI image checks        | Pass: runs as UID 10001 and prints "API modules load". Built with the sandbox proxy CA passed as the Dockerfile's `proxy_ca` build secret. |

## Run history

1. **First full server run: 97/101.**
   - Three red-team tests returned 500 on password reset and change. Their
     schema fixtures stopped at migration 0004, while production has the coach
     tables from 0005/0006, which the new credential cleanup updates. The
     fixtures now match production.
   - One migration test hit an uncaught "terminating connection" error. Its
     helper force-dropped a scratch database while pg was still closing a
     socket. The helper now waits for the connections to close.
2. **Second run: 101/101.**
3. **After the independent-review fixes: 98/101.** Adding a `message` to the
   coach `429` body broke three tests that pin the exact body
   `{ "error": "rate_limited" }`. The message was removed to keep the coach
   contract exact.
4. **Final run: 101/101.**

## Regressions that fail before the fix

The new test files were run against the baseline backend in an untouched
worktree.

- **`server/tests/backend-hardening.test.ts`.** The whole file fails to import
  on the baseline, because the new exports do not exist there. With the two
  tests that need new exports removed, **9 of the remaining 10 fail on the
  baseline**. The one that passes is the replay test, by design: it proves that
  operations recorded before the upgrade still replay, so it must pass on both.
- **`auth-hardening.test.ts`.** The implementing agent reverted each change in
  turn: 6 of 7 failed. The seventh is a scoping test for a new function.
- **`coach-hardening.test.ts`.** The in-flight revocation test failed until the
  write guard was wired. The `last_used_at` test failed under a mutation of
  the interval constant. The budget tests expect `429` where the baseline
  answers `409` or `200`.
- **`worker/tests/hardening.test.ts`.** All 8 cases fail against a snapshot of
  the original `worker/` and pass after.
- **`ops/test_operations.py`.** The hung-probe and restarting-container tests
  error or fail on the previous script and pass after.

## Fixture changes to existing tests

No assertion was weakened, skipped or retried. Only these request fixtures
changed:

- `worker/tests/redteam.test.ts` EDGE-01 sends a session cookie with the 1 MiB
  save, as a real signed-in client does. EDGE-06 sends
  `Sec-Fetch-Mode: navigate`, as a real email-link click does.
- `server/tests/email.test.ts` uses random-looking synthetic production
  secrets, because `"a".repeat(32)` is now refused.
- The schema fixtures in `auth`, `redteam`, `security` and `server-lifecycle`
  include migrations 0005 and 0006.

## Not run

- **Security scans:** Semgrep, gitleaks, OSV and SBOM. Their CI images were not
  pulled locally; they run in CI on push.
- **iOS:** no `swift test`, and no iOS simulator tests. No iOS source changed.
  The iOS contract was checked by reading `WorkspaceTransport.swift` and
  `AccountWire.swift`.
- **Load:** no load test over HTTP. The persistence benchmark is in-process;
  see PERFORMANCE.md.
