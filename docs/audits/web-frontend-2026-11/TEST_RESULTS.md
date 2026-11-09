# Test results

All runs were on 9 November 2026 (Australia/Sydney) in a Linux cloud container.

- **Toolchain:** Node 22.23.4, npm 10, `@playwright/test` 1.64.1.
- **Chromium:** Chromium 1243 at `/opt/pw-browsers/chromium`, used through `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` because the pinned Playwright expects a newer build.
- **Firefox and WebKit:** Firefox 157 and WebKit 27.2, installed with `npx playwright install firefox webkit`. WebKit's system libraries were installed with `npx playwright install-deps webkit`.
- **Database:** PostgreSQL 18.4 (`postgres:18.4-alpine`, the CI digest) in a disposable local container.

Only results that were actually observed are recorded here.

## Baseline (commit `53c4877`, before any change)

| Command                                                   | Result                                        |
| --------------------------------------------------------- | --------------------------------------------- |
| `npm ci`                                                  | 0 vulnerabilities                             |
| `npm run lint`, `format:check`, `typecheck`, `docs:check` | Pass                                          |
| `npm run test:unit`                                       | 151/151                                       |
| `VITE_ACCOUNT_MODE=guest npm run build`                   | Pass; main chunk 2,949.63 kB (560.29 kB gzip) |
| `npm run test:server` (PostgreSQL 18.4)                   | 76/76                                         |

## Final (branch `claude/practical-planck-xi0wq2`)

| Command                                                       | Result                                                          |
| ------------------------------------------------------------- | --------------------------------------------------------------- |
| `npm run lint`, `format:check`, `typecheck`, `docs:check`     | Pass                                                            |
| `git diff --check`                                            | Pass                                                            |
| `npm run test:unit`                                           | 160/160                                                         |
| `npm run build`                                               | Pass; main chunk 2,592.73 kB (443.82 kB gzip)                   |
| `node scripts/build-ios-resources.mjs --check`                | Pass; no `ios/` diff                                            |
| `npm run test:browser`, Chromium and Firefox                  | All 348 cases pass (see the run history below)                  |
| `npm run test:browser`, WebKit                                | 173/174; the failure passed 9/9 on a targeted rerun (see below) |
| `npm run test:browser:production` (5 projects)                | 175/175                                                         |
| `npm run test:accounts` (5 projects, at web commit `b880d05`) | 110/110                                                         |
| `npm run test:accounts:production` (at `b880d05`)             | 110/110                                                         |

The account suites were run in a separate worktree checked out at the web
commit, so that the backend work happening at the same time could not affect
them. The suites on the final combined branch are recorded in
`docs/audits/backend-2026-11/TEST_RESULTS.md`.

## Browser run history

1. **First full run, discarded.** Code was edited while it ran, so Vite hot
   reloads interrupted tests (`NS_BINDING_ABORTED`) and some specs met renamed
   accessible names. It was stopped and its results were not counted.
2. **Clean run.**
   - Chromium and Firefox reported 344 passes and 2 failures. Both failures
     were `accessibility.spec.js` at 390 px: axe `label-content-name-mismatch`
     on the mobile rest bar ("Open rest timer" versus visible "Rest 00:00").
     This was a real defect, found because the spec now runs axe's `wcag21a`
     rules.
   - WebKit could not launch (missing system libraries), so the run was
     stopped. Two Firefox `workout-release` cases were still in flight at that
     point.
3. **Fix and targeted rerun.** The rest bar's name now starts with its
   visible text. Every spec touching it, plus the unfinished cases, was rerun
   on Chromium and Firefox: `accessibility`, `routine-programming`,
   `regressions`, `workout-release` and `web-audit-2026-11`.
   - First rerun: 104 passed and 2 failed. The new name regex did not allow
     the space the browser inserts before the colon.
   - After making the regex whitespace-tolerant: 50/50 for the two affected
     specs.
4. **WebKit after installing its dependencies.** 173/174 passed.
   `catalog-quality` › "new fan-bike guide …" saw 24 cards instead of 1 right
   after typing, on the sixth test of a cold browser start. The same spec then
   passed 9/9 with `--repeat-each=3`. It is recorded as a transient failure,
   not a pass.

## Regressions that fail before the fix

These were checked by running the new tests against an untouched worktree at
`53c4877`.

| Test                                                                 | Baseline                                                                                          | Final |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ----- |
| `tests/web-audit-2026-11.spec.js` — running hold survives navigation | Fail                                                                                              | Pass  |
| … notes save after a pause, not per keystroke                        | Fail                                                                                              | Pass  |
| … text selection ending outside a dialog keeps it open               | Fail                                                                                              | Pass  |
| … set rows fit the card at 320 px                                    | Fail (overflow 9.98 px)                                                                           | Pass  |
| … calendar day names start with their visible text                   | Fail                                                                                              | Pass  |
| `unit/cloud-repository.test.js` — 4 new cases                        | Fail (3 at first; the stalled-body case was added after review and fails on the headers-only fix) | Pass  |
| `unit/progress-summary.test.js` — reviewed names                     | Fail                                                                                              | Pass  |

`unit/lean-catalog.test.js` and `unit/sign-out-guard.test.js` cover new code.
They have no baseline equivalent.

## Not run, or limited

- **No real devices.** No physical-device, screen-reader or voice-control
  testing was done.
- **No hosted or production checks.** Nothing was deployed, and the live site
  was not measured.
- **No visual baselines.** Screenshots were taken for review only. The
  repository has no screenshot-comparison tests.
