# FORMA Release Readiness Implementation Plan

> For agentic workers: use superpowers:subagent-driven-development for implementation and independent review. The user has explicitly authorized continuous execution with parallel Luna specialists.

**Goal:** Audit, repair and verify FORMA with permanent interaction/function traceability and an honest release decision.

**Architecture:** Preserve the browser-local React/Vite product and v1 backup contract. Expand observable UI and data-layer regression tests, run development and production targets separately, and retain explicit evidence for unavailable environments.

**Tech Stack:** Node 24, React 19.3, Vite 8.3, Zod 4.6, Playwright 1.64, native Node tests, axe-core.

**Spec:** User-supplied FORMA production-readiness brief; scope and status are recorded in `../../qa/progress.md`.

## Global constraints

- Preserve visual identity, user data contracts and unrelated changes.
- Use synthetic data and isolated browser contexts. No deployment, merge, release publication or real user data changes.
- No backend, authentication, analytics or new product features.
- Never weaken assertions, disable verification, conceal retries or claim unexecuted coverage.
- Keep the 20 MiB backup limit and Australia/Sydney date semantics.
- Each specialist edits only assigned files; root integrates shared source changes and reviews every patch.

## Review focus

1. Concurrent input and cross-tab saves must preserve acknowledged values.
2. Failed recovery must preserve the original bytes and avoid false success.
3. Browser capability loss must lead to recoverable temporary state.
4. The production bundle must support the same storage and download workflows.
5. Traceability must distinguish static mappings from executed outcomes.

## Tasks

- [x] Record clean baseline SHA, branch, versions and all original check outcomes before edits.
- [x] Inventory all semantic controls, conditional variants and important domain/persistence functions with exact test mappings.
- [x] Reproduce defects; add failing regression tests; apply minimal fixes; independently review source and test patches.
- [x] Add strict dev/production Playwright targets, browser projects, failure artifacts and least-privilege CI.
- [x] Exercise UI controls, domain edges, malicious imports, recovery and concurrency in available browsers; disclose unsupported targets.
- [x] Run fresh installation, lint, formatting, build, unit, browser, production, dependency, documentation and diff checks after integration.
- [x] Reconcile matrix rows against exact test reports, perform independent acceptance review, finalize documentation and release gates.
- [x] Prepare reviewed work for commit and a draft PR; the handoff records the final immutable SHA and actual remote outcome.

## File ownership and interfaces

| Owner  | Files/deliverable                                                                                                         |
| ------ | ------------------------------------------------------------------------------------------------------------------------- |
| Root   | Shared application fixes, package scripts, `docs/qa` matrices/register/release report, integration and final verification |
| Luna A | UI inventory and `tests/ui-controls.spec.js`                                                                              |
| Luna B | Domain/workflow audit, `tests/workout-release.spec.js`, `unit/domain-release.test.js`                                     |
| Luna C | Persistence diagnosis, `tests/persistence-release.spec.js`, `unit/persistence-release.test.js`                            |
| Luna D | Playwright configs, `tests/production.spec.js`, `.github/workflows/ci.yml`                                                |
| Luna E | Security evidence, `tests/security-release.spec.js`, `unit/security-release.test.js`                                      |
| Luna F | Existing documentation, `SECURITY.md`, `scripts/check-docs.mjs`, QA index                                                 |

Every fix requires a named reproduction, source-level cause, regression command, result and independent reviewer. Test counts must come from the final reports; missing browsers remain BLOCKED. Parent owns browser-run scheduling to prevent port/report collisions.
