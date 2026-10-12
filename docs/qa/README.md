# QA and release evidence

This directory collects evidence for the current release-readiness review. Read the root-owned [release readiness report](release-readiness.md) for the decision, results, and known limitations.

The report links the machine-readable interaction inventory, function/branch coverage matrix, defect register, and progress record. Those artifacts record observed outcomes; an item marked untested, blocked, or not applicable must not be counted as passing coverage.

Older verification and remediation records remain in [verification.md](../verification.md), [audit-fixes.md](../audit-fixes.md), [frontend-design-audit.md](../frontend-design-audit.md), and [backend-audit.md](../backend-audit.md). Their dated results describe earlier runs and should not be read as results from the current review.

The documentation link, fragment, image, and npm-script checker is invoked with `npm run docs:check`. It performs local checks only and does not fetch external links.

## Durable artifacts

- [Interaction outcomes](interaction-matrix.json) and [source crosswalk](control-crosswalk.json): semantic actions, exact test references and visible partial coverage.
- [Function branches](function-matrix.json) and [static source inventory](source-inventory.json): domain/persistence evidence and all discovered function/callback nodes.
- [Execution results](verification-results.json) and [reproduction evidence](reproduction-evidence.json): individual outcomes, tested content hashes, pre-fix failure and environment blockers.
- [Hosted CI evidence](hosted-ci-evidence.json): immutable tested commit, both successful runs, prior failed runs and accessible summary provenance.
- [Runtime control snapshots](runtime-controls.json): 17 representative accessible trees using synthetic data.
- [Defects and risks](defects.md), [independent review](independent-review.md) and [progress](progress.md): causes, decisions, unresolved limits and review history.

The JSON files are audit snapshots. Updating tests does not automatically update their coverage claims: inspect assertions, rerun affected checks, reconcile exact title/path references, and review changed statuses before replacing an audit snapshot. A passing adjacent test is not proof of an unasserted branch.
