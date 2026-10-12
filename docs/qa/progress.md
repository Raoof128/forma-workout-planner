# Release audit progress

Baseline: `a232ad2cee68f340c2102d6e5bf9a0c8ca9a9ba1`. Branch: `release/forma-readiness-audit`. Audit date: 12 October 2026 (Australia/Sydney). Initial working tree clean.

## Authorized scope

The user supplied an execution brief covering complete UI interaction and domain-function accounting; independent Luna audits; reproducible fixes and regressions; development and production testing; security/accessibility; CI; corrected documentation; a committed release candidate and PR where access allows. Publication, deployment and merging are excluded.

The current orchestrator coordinates six GPT-6 Luna specialists. A requested model label is not evidence that the parent runtime changed models.

## Baseline evidence

Node 24.19.0, npm 11.9.0, Playwright 1.64.0; system Chromium 154.0.8037.57. Commands executed before source/test edits:

| Check                                                       | Outcome                                                                                          |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `npm ci --cache /workspace/.npm-cache --no-audit --no-fund` | PASS                                                                                             |
| `npm run lint`                                              | PASS                                                                                             |
| `npm run format:check`                                      | PASS                                                                                             |
| `npm run build`                                             | PASS                                                                                             |
| `npm run test:unit`                                         | PASS: 21 tests                                                                                   |
| `npm run test:browser`                                      | BLOCKED: all 86 attempts failed at launch because pinned Chromium/Firefox executables are absent |
| `npm audit --omit=dev`                                      | PASS: zero reported vulnerabilities                                                              |
| `git diff --check`                                          | PASS                                                                                             |

Original command logs are retained outside the checkout in `/workspace/forma-release-evidence/baseline-*.log`. Earlier onboarding evidence (not this baseline): 42/43 system-Chromium scenarios passed; one concurrent profile/session update failed, then three isolated reruns passed. Subsequent diagnosis did not reproduce it; its cause remains unresolved.

## Ownership and decisions

- Luna A: all UI controls and interaction evidence.
- Luna B: workout workflows and domain function boundaries.
- Luna C: persistence, backup/recovery and concurrency diagnosis.
- Luna D: browser/production infrastructure and CI.
- Luna E: security, untrusted input, privacy and dependency review.
- Luna F: documentation consistency, recovery/operations and local link validation.
- Root: shared source integration, test execution scheduling, matrices and final acceptance.

The existing cloud checkout is already isolated; a dedicated branch is used without another worktree. User authorization to implement the release audit supersedes the earlier onboarding-only restriction on source edits. Parallel edits have disjoint ownership. Browser retries are disabled; unavailable browsers are not silently substituted. System Chromium runs are explicitly labeled as supplemental evidence, not pinned-browser certification.

## Current blockers

The enforced network allowlist excludes Playwright browser downloads. Draft additions for `cdn.playwright.dev` and `playwright.download.prss.microsoft.com` exist but are not applied to runtime. Firefox, WebKit and pinned Chromium cannot yet be validated. Continue all independent work and retain an honest NO-GO if mandatory gates remain unresolved.

## Integrated outcome

The reviewed source repair prevents stale file-read results from replacing a later backup selection. A separate documentation-checker anchor defect was reproduced and fixed. Both have permanent regressions. Test infrastructure now includes three desktop browser projects, production desktop/mobile smoke projects, strict ports, explicit Chromium override, zero retries, and a pinned least-privilege CI workflow.

Six Luna workstreams completed. Fresh Astra source review found the checker defect and accepted the scoped import repair; the release assessment remains NO-GO. Root and independent mapping review rejected inaccurate interaction mappings and added direct cancellation, empty-state, active-resume and timer-clear assertions. Final accounting: 108 semantic interactions crosswalked against 108 source templates; four structural templates are N/A. Important function scopes and untested branches are retained separately.

Fresh installation, 31 unit tests, 79 system-Chromium development tests and eight production desktop/mobile tests passed. No automatic retries or skip-based success. Earlier note-write reordering was not reproduced in 20 stress repeats or ordered instrumentation; no causal repair is claimed. Final command summaries and content hashes are in verification-results.json. Raw pre-fix/red, browser-blocker, stress, screenshot and run artifacts are retained under /workspace/forma-release-evidence.

The local documentation check temporarily reported missing matrix links while reports were being assembled; final generated files and link checks resolve those documentation-build gaps. This was not an application failure.

Network draft revision 4 saves current install/start instructions and retains the four browser/API domains. Settings have not been published/applied, and fresh-task restoration is unverified. Missing browsers and API denial remain external blockers. No deployment, merge or release publication occurred. The final handoff records the immutable candidate and GitHub operation outcome.

Final independent acceptance review tightened coverage definitions: 91 of 108 semantic rows are PASS; 17 retain passing primary-action evidence but are NOT TESTED for their full expected-result contract. The 56 function scopes contain 174 branch rows: 131 PASS, 43 NOT TESTED. All source controls remain accounted for, with no orphan semantic ID. Gate 1 remains BLOCKED. The reviewer resolved the concrete traceability objections through explicit partial accounting, not blanket completion claims.
