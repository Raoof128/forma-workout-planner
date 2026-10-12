# FORMA release readiness — 12 October 2026

**NO-GO for release.** The scoped repairs and available-browser workflows pass, but the required pinned-browser matrix and hosted CI remain blocked. An earlier intermittent concurrent-write failure has not been explained. No deployment, merge or release publication occurred.

## Candidate and environment

Repository `Raoof128/forma-workout-planner`; branch `release/forma-readiness-audit`; clean baseline `a232ad2cee68f340c2102d6e5bf9a0c8ca9a9ba1`. The final candidate is the commit containing this report; its exact SHA is in the handoff. [Verification evidence](verification-results.json) records SHA-256 hashes of tested application, tests, scripts, manifests and configurations. A tracked report cannot contain its own commit SHA.

Linux cloud container; Node 24.19.0, npm 11.9.0, React 19.3.0, Vite 8.3.4, Zod 4.6.6, Playwright 1.64.0 and axe-core 4.14.0. Actual browser: system Chromium 154.0.8037.57 via explicit `/usr/bin/chromium` override. Pinned Chromium 156, Firefox and WebKit are absent. Dependency versions and lockfile are unchanged.

## Coverage accounting

[Interaction matrix](interaction-matrix.json): **108 semantic rows: 91 PASS and 17 NOT TESTED for incomplete expected-result coverage in system Chromium; zero FAIL and zero NOT APPLICABLE semantic rows.** All 108 rows cite passing primary-action evidence, but the 17 incomplete rows retain explicit unverified branches. Each cites exact executed test titles and files. Required pinned Chromium, Firefox and WebKit remain **BLOCKED for every row**, separate from local semantic-row results.

[Source inventory](source-inventory.json): 21 handwritten JS/JSX files, 390 function/callback nodes and 108 control templates. The [crosswalk](control-crosswalk.json) maps 104 templates to semantic rows; four structural templates are NOT APPLICABLE (three submit-form wrappers and the reusable Button implementation). The equal totals of 108 templates and 108 semantic rows are coincidental: mappings are many-to-many. Repeated data-driven instances with identical behavior share rows; conditional actions are distinguished. No literal DOM-instance or mathematical path-completeness claim is made.

[Runtime snapshots](runtime-controls.json) record accessible role/name trees from 17 representative states, including mobile navigation, recovery, restore preview and an ErrorBoundary fixture. Static review and tests supplement these snapshots. Tests assert resulting UI and, where relevant, stored/downloaded data. A click alone does not establish PASS. The keyboard column describes intended operation; executed keyboard coverage is limited to referenced tests.

[Function matrix](function-matrix.json) accounts for 56 important domain/persistence scopes, with deliberate overlaps. It preserves NOT TESTED branches and partial evidence. All 390 source function/callback nodes remain statically inventoried; this does not mean 390 tested functions. Its 174 branch rows contain 131 PASS and 43 NOT TESTED, including partial evidence. A zero-load fixture proves handling, not catalogue defaults; latest-file race tests do not separately prove clearing an existing preview before awaiting; grouped stale-profile/routine/session/history coverage is incomplete.

## Verification

Fresh installation, lint, formatting, build, unit, documentation, production dependency audit and whitespace checks passed. [Execution summaries](verification-results.json) record exact titles, files, projects, durations and retries. Raw outputs and captures are retained in this task at `/workspace/forma-release-evidence/`; future CI runs retain reports and failure artifacts.

| Check                                                       | Result                                                                                          |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `npm ci --cache /workspace/.npm-cache --no-audit --no-fund` | PASS; lockfile unchanged                                                                        |
| `npm run lint`, `npm run format:check`, `npm run build`     | PASS                                                                                            |
| `npm run test:unit`                                         | 31 PASS; zero fail/skip                                                                         |
| Development, system Chromium                                | 79 PASS; zero fail/skip/flaky; zero automatic retries                                           |
| Production build, system Chromium desktop/mobile            | 8 PASS, four scenarios per project; zero fail/skip/flaky                                        |
| Concurrent profile/session stress scenario                  | 20 repeated PASS; original intermittent failure remains unexplained                             |
| axe                                                         | 24 states: 12 at 1536px and 390px; zero reported violations in system Chromium                  |
| Responsive                                                  | 320, 375, 390, 540, 768, 1024, 1440, 1536, 1920px; short landscape and maximum-content fixtures |
| `npm audit --omit=dev`                                      | Zero reported production vulnerabilities                                                        |
| `npm run docs:check`, `git diff --check`                    | PASS                                                                                            |
| Pinned Chromium/Firefox/WebKit; mobile WebKit               | BLOCKED before execution                                                                        |
| Hosted Actions                                              | Configured; successful run NOT VERIFIED                                                         |

The original baseline passed 21 unit tests. Its browser command attempted 86 cases, all failing at launch because executables were absent. These were environment launch failures, not 86 demonstrated app defects. Earlier [verification records](../verification.md) remain historical.

Development uses a fresh strict-port Vite server. Production builds and serves actual `dist/` at a separate origin. Smoke tests check assets/errors/requests, navigation, backup restore/reload, workout completion and cross-tab profile/session saves. Successful unexpected external HTTP requests also fail the production monitor. This is representative production smoke coverage, not every development assertion repeated in production. Mobile Chromium is emulation, not a physical device.

## Repairs and review

The [defect register](defects.md) gives causes, repairs and regression evidence. An older asynchronous backup read can no longer replace the latest file preview/error. Selection tokens guard success, rejection and picker reset. Deterministic regressions first reproduced the race, then proved the chosen backup survives restore and reload. No schema, recovery transaction or visual-design change was needed.

Independent review also found and repaired a P3 documentation-checker defect: inline-code heading text now contributes to anchors while fenced examples remain excluded. Its permanent unit regression failed before repair and passes afterward.

Six Luna specialists owned UI, domain/workout, persistence, infrastructure, security and documentation. Root inspected substantive patches and assertions, reran integration checks, inspected desktop/narrow captures and reconciled mappings. Luna E reviewed the import repair; Luna C reviewed neighbouring domain/security tests; Luna D audited interaction mappings. Rejected mappings led to actual cancellation, empty-state, resume and timer-clear assertions. Static reconciliation found the omitted empty Workout start action, now tested.

A fresh GPT-6 Astra reviewer independently inspected the integrated patch, source, tests, CI and command evidence. Its [review record](independent-review.md) accepts the scoped application repair and supports NO-GO. It did not claim to rerun browsers. Final immutable-commit review is recorded in the handoff supplement.

## Security, accessibility and operations

Targeted review found no demonstrated XSS, prototype pollution or workout-data exfiltration in tested paths. Untrusted strings render literally; malformed imports preserve storage; prototype-shaped unknown keys do not pollute prototypes; oversized files are rejected before reading. The production advisory scan returned zero. This is a focused engineering review, not unrestricted security certification.

Automated accessibility and keyboard checks cover focus traps/restoration, Escape, navigation, selected controls and reduced motion. Root inspected representative desktop and narrow-screen captures. Physical screen readers, touch keyboards, high zoom/text enlargement, device safe areas and comprehensive manual contrast/state inspection remain unverified. Complete WCAG 2.2 AA conformance is not claimed.

Storage is browser-local, unencrypted and origin/profile-specific. There is no backend, authentication, telemetry or cross-device synchronization. Hosting logs and response headers remain host responsibilities. External backups are needed after site-data loss; code rollback does not roll back browser data. Font OFL licenses exist; software licensing and photograph redistribution rights remain owner decisions.

## Limits and gates

1. Browser downloads return `403 Domain forbidden`. Pinned Chromium, Firefox, WebKit and mobile WebKit remain unverified. Saved network additions cover `cdn.playwright.dev`, `playwright.download.prss.microsoft.com`, `storage.googleapis.com` and `api.github.com`; saving does not apply or publish them.
2. GitHub API access is Forbidden despite an existing binding. Issue/PR review and hosted CI evidence are unavailable. Git HTTPS reads work; final handoff records push/PR outcomes.
3. The earlier concurrent profile/session failure is unexplained. Passing isolated, stress and integrated runs do not establish a causal fix.
4. Function gaps include some formatter/date boundaries, missing crypto APIs, pending-write/unload paths, irrelevant storage events, saving interlocks, stale action conflicts and background timer suspension. Partial evidence is not promoted to full branch PASS. Sydney dates are explicitly intended by the brief.
5. A 2,000-session progress fixture passes; maximum-size valid import, large History DOM rendering and low-end performance remain unmeasured. The 20 MiB limit is preserved; no arbitrary collection-count cap was introduced.
6. Physical Safari/iOS/Android, assistive technologies, mobile keyboards and host TLS/cache/security headers were not verified. No deployment occurred.
7. Another tab can unmount recovery before an inline stale error displays. Tests verify preservation of newer data, not guaranteed transient feedback.
8. Software licensing and photograph provenance require owner decisions before redistribution.

| Mandatory gate             | Status                    | Basis                                                                                  |
| -------------------------- | ------------------------- | -------------------------------------------------------------------------------------- |
| 1. Functional coverage     | BLOCKED                   | All discovered actions accounted for; 17 rows have incomplete expected-result coverage |
| 2. Application correctness | PASS, scoped              | Critical tested workflows, calculations and validation pass                            |
| 3. Data safety             | BLOCKED                   | Safety regressions pass; historical concurrent-write failure unexplained               |
| 4. Browser compatibility   | BLOCKED                   | Required pinned browsers unavailable                                                   |
| 5. Security/accessibility  | PASS, scoped              | No blocking finding in examined paths; manual/performance limits explicit              |
| 6. Production smoke        | PASS, scoped              | Eight Chromium desktop/mobile checks; other browsers blocked                           |
| 7. CI/reproducibility      | BLOCKED                   | Clean local install passes; hosted CI and required matrix unverified                   |
| 8. Documentation           | PASS                      | Source-backed guidance and local link/command checks                                   |
| 9. Independent review      | PASS for review performed | Separate review supports NO-GO, not release approval                                   |

## Reproduce and unblock

Follow [testing](../testing.md) and [getting started](../getting-started.md). The cloud draft saves install/start instructions. Review and save the environment settings, then publish to activate them; fresh-task restoration is unverified. Retry downloads/API calls after a meaningful settings change. Do not disable TLS or bypass network controls.

Supplemental commands used here:

```sh
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npm run test:browser -- --project=chromium
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npm run test:browser:production -- --project=production-chromium-desktop --project=production-chromium-mobile
```

Run pinned-browser suites and hosted CI once available; investigate the historical concurrency failure and remaining risk-path gaps before changing the verdict. Review the exact candidate and any subsequent fixes. No release approval is implied by this audit handoff.
