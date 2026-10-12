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

## GitHub handoff update

Implementation/evidence commit d05ebd31a7101c1413952ea4fee08062393b6b3b was pushed successfully, and draft PR #1 was created. Existing authentication supports Git push and GitHub CLI PR/status operations, despite an earlier issue-API denial. Hosted CI installed the pinned browsers and started the full matrix. This supersedes the earlier blanket API-access blocker; local browser downloads remain blocked. The reusable cloud start instructions were updated again to reflect verified GitHub access.

## Hosted CI diagnostic follow-up

Both initial hosted runs on d05ebd31a7101c1413952ea4fee08062393b6b3b installed all pinned browsers but failed the development browser step. Production was skipped; artifacts uploaded. Accessible annotations reported only exit code 1. Log downloads at results-receiver.actions.githubusercontent.com and artifact downloads at productionresultssa12.blob.core.windows.net returned Forbidden. Those exact domains were added to the environment draft; no runtime application is claimed.

Reporting-only commit 64dd74d1e061a7e472fe6825f28808ba89bbbec7 adds Playwright's built-in GitHub reporter and lets production diagnostics run after a failed dev suite when the build succeeded. Failures remain fatal; cancellation still skips production. Luna D independently reviewed failure propagation. Local CI-reporter smoke passed one meaningful import-preservation case, emitted a GitHub run summary, and lint/format/test discovery passed. No application or test assertion changed in this follow-up. New hosted runs are collecting accessible failure annotations.

Open GitHub issue query succeeded and returned none; the only open PR is the audit draft #1. The earlier issue/API denial is not a current blanket access limitation.

## Final hosted outcome

Both follow-up runs on 64dd74d1e061a7e472fe6825f28808ba89bbbec7 succeeded: PR 38190803860 and push 38190799370. Each reports 237 development and 20 production passes. The required pinned-browser execution blocker is resolved on hosted runners. Earlier local limitations and initial hosted failures remain historical evidence; raw download access and their causes remain unresolved. Network draft now includes six exact domains. The final documentation-only commit records this evidence without changing tested application, test or configuration bytes. NO-GO remains for coverage, historical concurrency and unexplained initial CI failures.
