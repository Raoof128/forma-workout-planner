# Documentation index

[Back to the project README](../README.md)

The documentation has two kinds of page. **Reference pages** describe how FORMA
works now and are kept in step with the code. **Dated records** describe an
audit, review or release on a given day; they are kept as written and are not
updated when the code changes. Each dated record names its date in its title or
first paragraph.

## Start here

| Page                                  | Use it for                                                    |
| ------------------------------------- | ------------------------------------------------------------- |
| [Getting started](getting-started.md) | Installing, running the web app locally and running the tests |
| [Architecture](architecture.md)       | The parts of the system and how a request moves through them  |
| [Testing](testing.md)                 | The test layers, what each one covers and how to run them     |
| [User guide](user-guide.md)           | How a member plans, logs and reviews training                 |
| [Native app guide](../ios/README.md)  | Building and testing the iPhone, Watch and widget targets     |

## Reference

### Web app and data

| Page                                                | Contents                                                       |
| --------------------------------------------------- | -------------------------------------------------------------- |
| [Data model](data-model.md)                         | Version 2 workspace shape, version 1 migration and validation  |
| [Routine programming v2](routine-programming-v2.md) | Rep ranges, rest, supersets and per-side sets in a routine     |
| [Member data sync](member-data-sync.md)             | Save, retry, import, export and conflict handling              |
| [Exercise catalogue](research/runtime-catalog.md)   | Where the exercise library comes from, its licences and limits |
| [Catalogue research](research/README.md)            | Equipment coverage, media sourcing and review files            |

### Accounts and API

| Page                                                 | Contents                                                           |
| ---------------------------------------------------- | ------------------------------------------------------------------ |
| [Accounts overview](accounts/README.md)              | What the account system does and where each part is documented     |
| [Account API](accounts/api.md)                       | Authentication, sessions, workspace routes and error contract      |
| [Database](accounts/database.md)                     | Schema, ownership, revisions and migration integrity               |
| [Account infrastructure](accounts-infrastructure.md) | Worker, Tunnel, Access and private-host topology                   |
| [Legal documents](legal/README.md)                   | Privacy Policy and Terms of Use: versions, sources and commitments |

### Operations

| Page                                                  | Contents                                                     |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| [Deployment](deployment.md)                           | Building and releasing the Worker and the API                |
| [Account operations](accounts/operations.md)          | Environment, migrations, backup, restore and recovery        |
| [Incident response](security/incident-response.md)    | Runbooks, alert thresholds and the sign-in lock procedure    |
| [Cloud environment](cloud-environment.md)             | Notes for working in a managed cloud development environment |
| [SSH from a managed environment](cloud-ssh-access.md) | Reaching the host through Cloudflare Tunnel and Access       |

### Security

| Page                                                 | Contents                                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------- |
| [Security overview](security/README.md)              | Entry point: findings, coverage and where each control is described |
| [Threat model](security/threat-model.md)             | STRIDE threat model for the account architecture                    |
| [Authentication](security/authentication.md)         | Sign-in, sessions, two-step verification and throttling             |
| [Authorisation](security/authorisation.md)           | Member isolation, coach-token scope and the native client           |
| [Database security](security/database-security.md)   | Roles, grants and data protection                                   |
| [Privacy and data handling](security/privacy.md)     | What is collected, where it is stored and how it is deleted         |
| [Incident response](security/incident-response.md)   | Runbooks and alert thresholds                                       |
| [ASVS Level 2 mapping](security/asvs-l2-mapping.csv) | Control-by-control mapping to OWASP ASVS                            |
| [Reporting a vulnerability](../SECURITY.md)          | How to report a security problem                                    |

The 12 October 2026 security engagement is a dated record:
[penetration test report](security/penetration-test-report.md),
[standards and scope](security/standards-and-scope.md),
[release security verdict](security/release-security-verdict.md),
[supply chain and CI](security/supply-chain.md),
[Cloudflare checklist](security/cloudflare.md) and
[host hardening checklist](security/droplet-hardening.md).

### Native app

| Page                                                                  | Contents                                                           |
| --------------------------------------------------------------------- | ------------------------------------------------------------------ |
| [Native app guide](../ios/README.md)                                  | Targets, setup, tests, widgets, media and device notes             |
| [Apple Watch workouts](../ios/docs/apple-watch.md)                    | How the Watch workout works and what data it keeps                 |
| [Privacy inventory](../ios/docs/privacy-inventory.md)                 | Data flows, capabilities and the App Privacy draft                 |
| [App Store submission checklist](../ios/docs/app-store-submission.md) | Verified archive facts and the steps that remain before submission |

## Dated records

### Releases

[QA and release evidence](qa/README.md) lists every release record, newest
first. The account launch is in the
[production launch record](accounts/production-launch.md), and earlier staging
evidence is in the [deployment record](security/deployment-record.md).

### Audits

| Date               | Audit                                                                                               | Scope                                              |
| ------------------ | --------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 9 November 2026    | [Backend audit](audits/backend-2026-11/BACKEND_AUDIT.md)                                            | API, Worker gateway and operations tooling         |
| 9 November 2026    | [Web frontend audit](audits/web-frontend-2026-11/AUDIT.md)                                          | Web application and browser tests                  |
| 4–5 November 2026  | [Web frontend audit and handoff](audits/forma-web-frontend-2026-11/FINAL_REPORT.md)                 | Reliability, accessibility and design              |
| 4 November 2026    | [Native audit with iPhone verification](../ios/docs/audits/native-frontend-2026-11/FINAL_REPORT.md) | iPhone, Watch and widget interface                 |
| 2 November 2026    | [Native frontend reviews](../ios/docs/audits/frontend-2026-11-02/README.md)                         | Eight reviews against Apple's interface guidelines |
| 2 November 2026    | [Watch battery audit](../ios/docs/audits/watch-battery-audit-2026-11-02.md)                         | Watch energy use and watchOS practice              |
| 29 October 2026    | [Native frontend and widget audit](../ios/docs/audits/frontend-widget-2026-10/EXECUTIVE_AUDIT.md)   | iPhone interface and widgets                       |
| 26 October 2026    | [Apple Watch readiness audit](audits/apple-watch-readiness-2026-10-26/README.md)                    | Readiness of the codebase for a Watch app          |
| 23–26 October 2026 | [Runtime, performance and quality audit](audits/forma-runtime-quality-2026-10/AUDIT_REPORT.md)      | Web runtime and performance                        |

Some of these audits end in a NO-GO verdict or list open findings. Those
verdicts are kept as written; later release records say what was fixed.

### Native milestones, October 2026

| Record                                                                                                     | Contents                                                      |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [Verification log](../ios/docs/verification.md)                                                            | What was built and tested in the 23 to 26 October milestones  |
| [Full audit, 26 October](../ios/docs/full-audit-2026-10-26.md)                                             | First Xcode compile and file-by-file audit                    |
| [Account review and tab bar](../ios/docs/account-review-and-tab-bar-2026-10-28.md)                         | Native account fixes and tab bar, with test results           |
| [Native accounts findings](../ios/docs/native-accounts-findings.md)                                        | Findings that preceded the native accounts design             |
| [Native design review](../ios/docs/native-design-review.md)                                                | File-by-file review of the first native files                 |
| [Apple design sources](../ios/docs/apple-design-2026.md)                                                   | Apple guidance consulted and the decisions taken from it      |
| [App Review matrix](../ios/docs/app-review-matrix.md)                                                      | Guideline readiness for the first, guest-only milestone       |
| [Implementation plan](../ios/docs/implementation-plan.md) and [baseline](../ios/docs/baseline-evidence.md) | The original plan and the repository state before native code |
| [Second implementation pass](../ios/docs/commit-2/IMPLEMENTATION_REPORT.md)                                | Report on the follow-up interface pass                        |

### Design and planning

| Date            | Record                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------ |
| 2 November 2026 | [Watch collected data design](superpowers/specs/2026-11-02-watch-collected-data-design.md) |
| 28 October 2026 | [Native accounts design](superpowers/specs/2026-10-28-native-accounts-design.md)           |
| 12 October 2026 | [Self-hosted accounts design](superpowers/specs/2026-10-12-accounts-design.md)             |
| 12 October 2026 | [Self-hosted accounts plan](superpowers/plans/2026-10-12-self-hosted-accounts.md)          |
| 12 October 2026 | [Release readiness plan](superpowers/plans/2026-10-12-release-readiness.md)                |
| 29 October 2026 | [Branch consolidation](maintenance/branch-consolidation-2026-10-29.md)                     |

### Before accounts existed

These pages describe the browser-only planner of 11 to 13 October 2026. Each
carries a note at the top saying so.

| Page                                                  | Contents                                              |
| ----------------------------------------------------- | ----------------------------------------------------- |
| [Product brief](research.md)                          | The original reference research and scope             |
| [Verification record](verification.md)                | Test results and the NO-GO verdict for that candidate |
| [Frontend audit remediation](audit-fixes.md)          | Fixes made after the first front-end audit            |
| [Data-layer audit](backend-audit.md)                  | Audit of browser persistence and validation           |
| [Frontend design audit](frontend-design-audit.md)     | Design review and polish                              |
| [Public catalogue release](live-catalog-release.md)   | The 13 October catalogue release                      |
| [Account implementation handoff](accounts/handoff.md) | The original account handoff, before launch           |

## Project logs

[CHANGELOG.md](../CHANGELOG.md) records notable changes, newest first.
[AGENT.md](../AGENT.md) holds the working constraints, the checks to run and a
dated engineering log. [CLAUDE.md](../CLAUDE.md) is a condensed guide for AI
coding sessions in this repository.
