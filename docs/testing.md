# Testing

[Back to README](../README.md)

## Run checks

```sh
npm ci
npx playwright install chromium firefox webkit
npm run lint
npm run format:check
npm run docs:check
npm run build
npm test
npm run test:browser:production
```

`npm test` runs the Node.js unit suite before the development browser suite. Use `npm run test:unit` or `npm run test:browser` to run a layer independently. The development suite runs Chromium, Firefox, and WebKit. `npm run test:browser:production` builds the app and runs production smoke workflows in desktop Chromium, Firefox, and WebKit, plus mobile Chromium and WebKit emulation.

Run tests from the repository root. Playwright starts a fresh Vite server bound to `127.0.0.1:5173` with a strict port; if that port is occupied, stop the other server before running the suite. It reuses an existing server only when `PLAYWRIGHT_REUSE_SERVER=1` is explicitly set outside CI. The production suite builds first, then starts a fresh preview server on `127.0.0.1:4173`; it never reuses an existing server. Linux hosts may require `npx playwright install-deps chromium firefox webkit` with suitable OS permissions.

Both configurations set `retries: 0`, so failures are reported on the first run and are not hidden by automatic retries. On failure, Playwright retains traces under `test-results/dev/` or `test-results/production/`; CI uploads `test-results/` and HTML reports under `playwright-report/` as artifacts. To run the same required matrix as CI, install the pinned browsers and Linux dependencies with `npx playwright install --with-deps chromium firefox webkit`, then run the commands above. The GitHub Actions workflow is configured for pushes and pull requests using Node.js 24 on Ubuntu 24.04 in `.github/workflows/ci.yml`; a hosted CI run has not been verified as part of this audit.

## Test organization

| File                                | Coverage                                                                                                                                                         |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `unit/persistence.test.js`          | Lock failures, revisions, preservation, stale restores, concurrency, and rollback behavior                                                                       |
| `unit/persistence-release.test.js`  | Added persistence-boundary cases for temporary mode and commit application                                                                                       |
| `unit/storage.test.js`              | Backup limits, schema compatibility, timestamps, IDs, dates, and calculations                                                                                    |
| `unit/domain-release.test.js`       | Completed-set volume, bodyweight behavior, empty aggregates, and estimated 1RM precision                                                                         |
| `unit/security-release.test.js`     | Prototype-shaped fields, malformed/schema-invalid backups, and pre-read size limits                                                                              |
| `unit/docs-check.test.js`           | Inline-code heading anchors and exclusion of fenced examples                                                                                                     |
| `tests/persistence.spec.js`         | Browser integration for rejected locks, temporary restore, UUID fallback, stale routine start, fractional weights, timer bounds, and repeated simultaneous edits |
| `tests/persistence-release.spec.js` | Cross-tab restore conflicts and selection races where an older valid or invalid file finishes after a newer selection                                            |
| `tests/workflows.spec.js`           | Routine creation, exercise search, logging, history, progress, preferences, and mobile flow                                                                      |
| `tests/workout-release.spec.js`     | Set validation, finish/discard choices, timer persistence, real-time timer smoke, history conflicts, and large-history calculations                              |
| `tests/regressions.spec.js`         | Cross-tab writes, stale editors, invalid storage, recovery, rapid input, timer persistence, keyboard behavior, and backup round trips                            |
| `tests/ui-controls.spec.js`         | Reachable UI controls and navigation actions                                                                                                                     |
| `tests/ui-coverage-gaps.spec.js`    | Shell shortcuts, empty-state actions, active resume, cancellation, invalid forms, and dialog dismissal                                                           |
| `tests/security-release.spec.js`    | Malformed imports, literal untrusted text, external-request checks, and download failure feedback                                                                |
| `tests/responsive.spec.js`          | Nine viewport widths from 320 to 1920 px, large content, short landscape navigation, local fonts, reduced motion, and history ordering                           |
| `tests/accessibility.spec.js`       | axe scans of main pages and dialogs on desktop and mobile                                                                                                        |
| `tests/production.spec.js`          | Production-build load and representative desktop/mobile workflows across Chromium, Firefox, and WebKit projects                                                  |
| `tests/helpers.js`                  | Screenshot paths and font/animation settling                                                                                                                     |

Run a specific development browser or scenario:

```sh
npx playwright test --project=chromium
npx playwright test tests/regressions.spec.js -g 'concurrent tabs'
```

Run a specific production project with `npx playwright test --config=playwright.production.config.js --project=production-webkit-mobile`.

Screenshots are stored in the configured system temporary directory under `forma-qa/<browser>/`; `FORMA_ARTIFACT_DIR` can select a different output directory. Failure traces and screenshots are stored under `test-results/`, separated by development and production config, and ignored by Git. Use synthetic fixtures; never commit someone's exported workout data.

## Regression expectations

Data changes need tests for the relevant failure boundary as well as the successful path. Useful cases include malformed imported data, rejected storage access, quota failure, stale confirmation, concurrent tabs, and reload after an acknowledged save. Assert user-visible state and stored/exported results together where data loss is possible.

For visual changes, check long names and notes, minimum-width numeric fields, short landscape drawers, focus order, and reduced motion. Accessibility scans do not replace keyboard or assistive-technology review. CI is configured to execute Chromium, Firefox, and WebKit using Playwright's browser builds; WebKit is not the same as verifying Safari on physical Apple devices. Physical devices and assistive technologies require separate validation.

See [verification](verification.md) for recorded results rather than assuming every environment supports every browser.
