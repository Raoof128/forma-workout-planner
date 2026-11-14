# QA and release evidence

This directory holds dated evidence: one folder per release, plus the audit
snapshots from the first release-readiness review. Each record states what was
run, what passed and what was not done. A record describes its own date; it is
not a statement about the service today.

## Release records

| Date             | Record                                                                   |
| ---------------- | ------------------------------------------------------------------------ |
| 13 November 2026 | [App Store 1.0 preparation release](app-store-1.0-2026-11-13/README.md)  |
| 5 November 2026  | [Frontend audit release](frontend-audit-2026-11-05/README.md)            |
| 26 October 2026  | [Runtime quality release](runtime-quality-2026-10-26/README.md)          |
| 22 October 2026  | [Hold timer and timed holds release](holds-timer/README.md)              |
| 19 October 2026  | [Workout editing and full-access coach release](workout-coach/README.md) |
| 18 October 2026  | [Coach tokens release](coach-tokens/README.md)                           |
| 18 October 2026  | [Sign-out release](sign-out/README.md)                                   |
| 17 October 2026  | [Routine programming v2 release](routine-programming-v2/README.md)       |
| 14 October 2026  | [Whole-site review](site-sweep/README.md)                                |

[Whole-row routine dragging](routine-row-drag/README.md) records the
investigation and tests behind that interaction. The account launch itself is
recorded in the [production launch record](../accounts/production-launch.md).

## First release-readiness review, 12 October 2026

The files directly in this directory come from the review of the browser-only
candidate, before the account API existed. Its
[release readiness report](release-readiness.md) gives that candidate's
decision, results and known limits. Account gates are tracked separately in
[account release readiness](../accounts/release-readiness.md).

The report links the machine-readable interaction inventory, function/branch coverage matrix, defect register, and progress record. Those artifacts record observed outcomes; an item marked untested, blocked, or not applicable must not be counted as passing coverage.

Older verification and remediation records remain in [verification.md](../verification.md), [audit-fixes.md](../audit-fixes.md), [frontend-design-audit.md](../frontend-design-audit.md), and [backend-audit.md](../backend-audit.md). Their dated results describe earlier runs and should not be read as current results.

The documentation link, fragment, image, and npm-script checker is invoked with `npm run docs:check`. It performs local checks only and does not fetch external links.

## Durable artifacts

- [Interaction outcomes](interaction-matrix.json) and [source crosswalk](control-crosswalk.json): semantic actions, exact test references and visible partial coverage.
- [Function branches](function-matrix.json) and [static source inventory](source-inventory.json): domain/persistence evidence and all discovered function/callback nodes.
- [Execution results](verification-results.json) and [reproduction evidence](reproduction-evidence.json): individual outcomes, tested content hashes, pre-fix failure and environment blockers.
- [Hosted CI evidence](hosted-ci-evidence.json): immutable tested commit, both successful runs, prior failed runs and accessible summary provenance.
- [Runtime control snapshots](runtime-controls.json): 17 representative accessible trees using synthetic data.
- [Defects and risks](defects.md), [independent review](independent-review.md) and [progress](progress.md): causes, decisions, unresolved limits and review history.

The JSON files are audit snapshots. Updating tests does not automatically update their coverage claims: inspect assertions, rerun affected checks, reconcile exact title/path references, and review changed statuses before replacing an audit snapshot. A passing adjacent test is not proof of an unasserted branch.
