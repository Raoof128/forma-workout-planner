# Testing

[Back to README](../README.md)

## Run checks

```sh
npm ci
npx playwright install chromium firefox
npm run lint
npm run format:check
npm run build
npm test
```

`npm test` runs the Node.js unit suite before the browser suite. Use `npm run test:unit` or `npm run test:browser` to run a layer independently.

Playwright starts a Vite server on port 5173. Run tests from the repository root. If that port already serves another application, stop it first. Linux hosts may require `npx playwright install-deps chromium firefox` with suitable OS permissions.

## Test organization

| File                          | Coverage                                                                                                                                                         |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `unit/persistence.test.js`    | Lock failures, revisions, preservation, stale restores, concurrency, and rollback behavior                                                                       |
| `unit/storage.test.js`        | Backup limits, schema compatibility, timestamps, IDs, dates, and calculations                                                                                    |
| `tests/persistence.spec.js`   | Browser integration for rejected locks, temporary restore, UUID fallback, stale routine start, fractional weights, timer bounds, and repeated simultaneous edits |
| `tests/workflows.spec.js`     | Routine creation, exercise search, logging, history, progress, preferences, and mobile flow                                                                      |
| `tests/regressions.spec.js`   | Cross-tab writes, stale editors, invalid storage, recovery, rapid input, timer persistence, keyboard behavior, and backup round trips                            |
| `tests/responsive.spec.js`    | Seven viewport widths, large content, small landscape navigation, local fonts, reduced motion, and imported history ordering                                     |
| `tests/accessibility.spec.js` | axe scans of main pages and dialogs on desktop and mobile                                                                                                        |
| `tests/helpers.js`            | Screenshot paths and font/animation settling                                                                                                                     |

Run a specific browser or scenario:

```sh
npx playwright test --project=chromium
npx playwright test tests/regressions.spec.js -g 'concurrent tabs'
```

Screenshots are stored in the system temporary directory under `forma-qa/<browser>/`. Set `FORMA_ARTIFACT_DIR` to change the root. Test output under `test-results/` is ignored by Git. Use synthetic fixtures; never commit someone's exported workout data.

## Regression expectations

Data changes need tests for the relevant failure boundary as well as the successful path. Useful cases include malformed imported data, rejected storage access, quota failure, stale confirmation, concurrent tabs, and reload after an acknowledged save. Assert user-visible state and stored/exported results together where data loss is possible.

For visual changes, check long names and notes, minimum-width numeric fields, short landscape drawers, focus order, and reduced motion. Accessibility scans do not replace keyboard or assistive-technology review. Chromium and Firefox are verified targets; Safari and physical devices require separate validation.

See [verification](verification.md) for recorded results rather than assuming every environment supports every browser.
