# Independent final branch review — FORMA

Review date: 2026-10-12. Reviewer: fresh acceptance reviewer, separate from the implementation and earlier specialist reviews. Baseline: `a232ad2cee68f340c2102d6e5bf9a0c8ca9a9ba1`; branch: `release/forma-readiness-audit`.

## Verdict

**NO-GO for release acceptance; the scoped application repair is acceptable.** I found no new blocking application defect or regression in the integrated source change. The required pinned Chromium/Firefox/WebKit execution and reproducible hosted CI evidence remain unresolved. Final interaction/function accounting and final commit identity were not available at the review snapshot, so this document does not certify their completeness or their eventual counts.

**Code-quality verdict:** the Preferences repair is narrow, preserves the data contract, and addresses both successful and rejected stale reads. The new test and CI structure is suitable to retain, subject to the minor documentation-checker finding below and final execution of newly added tests. There is no evidence here supporting an unconditional release GO.

## Scope and method

I read the user's complete release brief, the current working-tree diff against the baseline, the application import handler and its restore UI, persistence/storage implementation and hook, both Playwright configurations, CI workflow, npm scripts, documentation checker, new domain/persistence/security unit tests, new persistence/security/workout/UI/production browser tests, and edited documentation. I also compared specialist findings with the actual source and run artifacts. New UI gap tests were still being integrated during this review.

I made no repository source or test edits and ran no browsers, preserving the orchestrator's ownership of final test execution. The one targeted check was a read-only Node VM evaluation of the actual documentation-checker functions, described below. This is review of the current branch contents, not a claim to have independently rerun every release gate or to have reviewed an immutable final commit.

## Ranked findings

### P3 — Documentation fragment checker drops inline-code text from headings

Location: `scripts/check-docs.mjs:205`, via `stripCode()` at `scripts/check-docs.mjs:35-38`.

`headingSlugs()` calls the same function used to remove code examples when scanning link text. That function deletes the complete contents of inline code. For a valid heading `## Run `npm ci``, the checker generates `run`, whereas the GitHub heading anchor includes the code text: `run-npm-ci`. Consequently, a correct link to `#run-npm-ci` fails validation, and an incorrect link to `#run` may pass. I reproduced the result `["run"]` by evaluating the exact functions read from the script in a Node VM, without modifying files. No current repository heading with inline code was found, so this is a checker reliability defect, not a current application release blocker. Preserve inline-code contents when extracting heading slugs; code fences may still be excluded. The orchestrator was notified before this report.

### Acceptance blocker — Required browser evidence is unavailable

Locations: `playwright.config.js:18-32`, `playwright.production.config.js:21-56`; evidence: `/workspace/forma-release-evidence/browser-install.log:2` and `/workspace/forma-release-evidence/baseline-browser.log:270`.

The configurations correctly require the browser projects instead of silently skipping them, but those declarations are not execution evidence. The pinned-browser baseline failed at launch and installation receives `403 Domain forbidden` from the Playwright CDN. Passing system Chromium 154 scenarios cannot certify Playwright's pinned Chromium 156, Firefox, WebKit, mobile WebKit, or physical Safari. Keep the compatibility gate BLOCKED and distinguish these runs from successful system-Chromium execution. This is an environment/evidence blocker, not a defect in the new configuration.

### Acceptance hold — Final traceability and immutable commit review are outstanding

Locations at review time: `docs/qa/release-readiness.md:3-7`, `/workspace/forma-release-evidence/ui-inventory.json`, `docs/qa/source-inventory.json`.

The current release report explicitly says the audit is in progress; final interaction and function/branch matrices had not yet been generated. The semantic inventory's 107 groups and source inventory's 108 control templates use different denominators. I cannot approve their final statuses, test-to-control mappings, crosswalk, or counts before those artifacts exist and cite executed assertions. The current report correctly avoids a premature PASS. The orchestrator must reconcile final artifacts and record the exact committed candidate SHA. This is a remaining acceptance step, not a finding that all controls are untested.

## Review conclusions by workstream

- **Application/data integrity:** `src/components/Preferences.jsx:29-47` captures a monotonically increasing selection number, clears the previous preview/error when a new file is selected, and ignores stale resolution, rejection, and input-reset completion. It preserves the revision captured for the selected import and existing stale-restore checks. The fix changes no schema, persistence key, restore transaction, or workout behavior. No new data-loss path was found.
- **Regression evidence:** `tests/persistence-release.spec.js:126-239` gates the earlier file's read, selects a later file, releases the older read, checks the latest preview, restores it, and checks stored data after reload. Separate valid and invalid earlier reads cover both guarded branches. The pre-fix failure is retained in `persistence/import-race-red.log`, and the four-case green report is retained. This is substantive red/green protection, not a test that merely observes a click.
- **Workout/domain:** new cases check stored set values, completion/undo, added sets, finish/discard/switch outcomes, history conflict preservation, deadlines, expiry, and progress values. Domain cases prove 800 kg completed volume, zero-external-load behavior, actual singles, and 80 kg × 5 Epley arithmetic. The 2,000-entry fixture is evidence for that shape and size only; it is not maximum-size import validation.
- **UI/accessibility:** added controls tests observe changed schedule/routine/profile/restore state, cancellation preservation, focus return, keyboard trapping, filters, and fallback download bytes. The new gap suite also covers navigation shortcuts, empty calls to action, clean/invalid editors, history cancel/keep, and dialog backdrops. Those new tests require the orchestrator's subsequent run before PASS attribution. Existing responsive checks now include 375 and 1536 pixels; this changes coverage parameters rather than assertions. Axe/emulated keyboard evidence does not prove physical-device or assistive-technology conformance.
- **Security:** malformed import tests assert unchanged storage; imported attack-shaped text is asserted literally in profile/routine/history views with no injected image, script dialog, page error, or external request. Prototype-shaped fields and pre-read size rejection receive unit coverage. These checks support the stated scope, not an unrestricted security assurance. The pre-existing unbounded routine/history collection risk remains an explicitly unmeasured availability limit.
- **Production/infrastructure:** production tests serve built `dist/` through preview on port 4173 and use a separate origin from development. They cover settings/export/import/reload, navigation/layout, a saved workout, and parallel profile/session writes. The monitor catches browser errors, unsuccessful requests/responses, and successful external HTTP(S) requests. Both configs use strict ports, zero retries, retained failure traces/screenshots, and CI `forbidOnly`; production never reuses a server. CI grants read-only repository permission, pins actions by SHA, installs browsers matching the lockfile, propagates command failures, and uploads artifacts even on failure. No assertion weakening or lock bypass was found.
- **Documentation/operations:** privacy, lack of encryption, origin/profile storage, temporary mode, external backups, non-atomic recovery archival, deployment rollback limits, missing project license, and uncertain photograph provenance are candidly stated. Historical audit results remain historical. The workflow is described as configured, with hosted CI execution explicitly unverified. Final release reporting remains the orchestrator's outstanding work.

## Evidence inspected

- `final-unit.log`: 30 passed, 0 failed.
- `final-dev.log`: 70 passed under the explicit system-Chromium override; predates the newly authored gap suite.
- `final-production.log`: actual production build plus 8 passed across system-Chromium desktop/mobile projects.
- `persistence/import-race-red.log` and `persistence/release-spec-green.log`: retained pre-fix failure and post-fix four-case success.
- `browser-install.log` and `baseline-browser.log`: explicit download/launch blockers.
- Earlier independent reviews and security/workout/persistence/infra reports were read as supporting context; their claims were not substituted for source inspection.

These are inspected orchestrator/specialist execution artifacts. No browser run was performed by this reviewer. The root must publish the later integrated run results without presenting the earlier 70-case run as coverage of tests added afterward.

## Residual limits and required handoff

The original intermittent concurrent-profile/session failure is not explained by the later 20 passing repeats. Keep that evidence and its unresolved status; do not label it repaired without a demonstrated cause. Recovery's stale-raw conflict protects newer data but can unmount the recovery screen before its inline error is shown; this is the earlier reported feedback limit. Very large valid imports, full device/assistive-technology coverage, host-specific response headers/caching/TLS, asset redistribution rights, and real hosted CI execution are not established by the present runs.

Complete the final matrices and source crosswalk, classify untested actions visibly, run the newly added suite and required checks after integration, inspect the final documentation, and record the committed candidate identity. Browser availability and any remaining mandatory coverage gaps still require an honest NO-GO. No merge, release, or deployment is approved by this review.

## Acceptance supplement — 2026-10-12 00:52 UTC

This supplement preserves the original review snapshot above and supersedes its statement that final traceability artifacts were absent. It is still a working-tree review; immutable-commit acceptance has not yet occurred. I inspected the new interaction/function matrices, source inventory and crosswalk, runtime snapshots, verification manifest, release-readiness report, defect register, checker repair and permanent regression. I ran only read-only structural/reference/hash checks; I did not run browsers or edit application/test files.

### Repairs and execution evidence

The P3 heading-fragment defect above is **fixed**. `headingSlugs()` now removes fenced code while preserving inline-code text, and `unit/docs-check.test.js` asserts both the expected `run-npm-ci` fragment and exclusion of a fenced heading. The script's command-line guard also prevents importing the exported helper from running the whole documentation scan. The inspected final unit output reports 31 passing tests, including this regression.

The inspected raw JSON reports contain 79 passing development cases (run started 00:46:31 UTC) and 8 passing production cases (00:49:05 UTC), without skipped, unexpected or flaky results. These agree with `verification-results.json`. At this snapshot all recorded source/test/configuration hashes matched the current files. The orchestrator subsequently requested strengthened existing timer-control assertions and another integrated run; that later evidence must replace the earlier results and hashes before final candidate review. Neither these system-Chromium passes nor the manifest establish pinned-browser or hosted CI success.

### Traceability reconciliation

The artifacts account for 108 semantic interaction rows, 108 source control templates and 390 source function/callback nodes. The crosswalk contains 104 mapped templates and four explicit structural exclusions; every semantic ID has a source mapping. Every interaction and function test reference resolves to an exact executed file/title in the verification manifest. The function matrix contains 56 scopes and 174 branch rows; its initial summary was 134 PASS and 40 NOT TESTED. These are independently checked structural counts, not approval of every coverage attribution.

The initial interaction matrix marked all 108 semantic rows PASS while several `expectedResult` descriptions included unasserted behavior. **I reject interpreting that snapshot as 108 fully verified expected-result contracts.** The orchestrator agreed to preserve partial evidence explicitly and downgrade rows with unverified requirements rather than claim full coverage. Concrete review corrections were:

- `routine-editor-duration`: the mapped regression reads the existing duration and confirms it remains unchanged; it does not change the control. Invalid-duration rejection is also untested. This is an interaction gap, not just an untested boundary.
- `routine-delete-confirm`: its mapped fixture has empty history, so it cannot prove associated history or an active workout survives deletion. `schedule-save` and `settings-save-profile` likewise include stale-conflict expectations absent from their cited success tests.
- `settings-name`, `routine-editor-name`, `workout-session-notes` and `history-editor-notes`: valid edits are covered, but whitespace or maximum-length claims are not all asserted. `routine-editor-prescriptions` needs the workflow test reference for actual sets/reps edits and must retain numeric-boundary limitations.
- `navigation-main-items` and `navigation-settings`: navigation is observed, but the stated `aria-current` requirement is not asserted. `routine-editor-search` demonstrates the no-match case, not case-insensitive positive matching.
- `recovery-fresh-reset`, `modal-close-shared` and `modal-escape-shared`: the mapped tests do not establish pending-operation interlocks or busy-close guards. `recovery-download-original` does not establish its download-failure branch.
- Some missing evidence can be mapped without new tests: Settings export failure is tested in `security-release.spec.js`; stale valid import confirmation is tested in `persistence-release.spec.js`; invalid recovery import is tested by “recovery distinguishes an invalid backup from a failed storage write.” These references still do not establish an oversized-file recovery UI path.

Function-row attribution also needs narrow correction. `latest-selection-clears-old-preview-and-error-before-await` maps to a race test without an existing preview/error and without a pending-read assertion, so that branch is not established. `stale-profile/routine/session/history` is broader than its mapped stale-routine/independent-edit tests; history has separate evidence, while stale-profile rejection remains a gap. The catalogue “Bodyweight defaults are zero external load” row uses a fixture explicitly assigning zero, which proves zero-load handling but not the catalogue's defaults. These corrections affect summaries; the initial counts above must not override the regenerated final matrix.

### Updated acceptance assessment

The matrix files and runtime inventory materially improve accounting, and the report appropriately retains NO-GO, the unexplained historical concurrency failure, blocked browsers/CI, unmeasured maximum-size import behavior, and manual/device limits. The functional-coverage gate must also remain BLOCKED while its inventoried expected behaviors include the gaps identified here. A matching test title and a passing run establish execution; the assertions determine what behavior that run proves.

No new application defect was established in this supplementary review. The Preferences fix remains acceptable. The final handoff must use the corrected coverage counts, later integrated run/hashes, and exact immutable commit review. This supplement approves neither deployment nor release.

## Corrected-accounting acceptance — 2026-10-12 00:55 UTC

I reviewed the regenerated artifacts and the narrow test additions. The interaction matrix now reports **91 PASS and 17 NOT TESTED**, with explicit unverified branches and retained evidence for the parts actually exercised. The function matrix now reports **131 PASS and 43 NOT TESTED branch rows** across 56 scopes. All three function-attribution errors identified above are downgraded. Crosswalk results agree with the semantic rows, and every interaction test reference resolves to the verification manifest.

The duration control now has an actual edit to 75 minutes, a stored-value assertion and a reopened-field assertion in `ui-controls.spec.js`. The two timer-skip paths assert cleared persisted timer fields and reload behavior; the panel and mobile rows cite the correct separate tests. Export failure, stale restore and malformed recovery evidence references have also been added. These corrections resolve the concrete traceability objections raised in the preceding supplement. The release report correctly marks functional coverage BLOCKED and states the partial-coverage denominator.

**NO-GO remains the appropriate release decision.** No additional blocking discrepancy was found in this correction review. The latest clean integrated run is still in progress at this supplement's timestamp, so final run/hash reconciliation and immutable-commit review remain pending; this paragraph does not claim those later steps have passed. No browser run was performed by this reviewer.

## Final integrated execution record — orchestrator

After the final duration-edit and timer-clear assertions were integrated, the clean verification command completed successfully: dependency installation, lint, formatting, build, 31 unit tests, production dependency audit, documentation validation, whitespace check, 79 development system-Chromium cases and eight production desktop/mobile Chromium cases. Both browser reports record zero skipped, unexpected or flaky results and no automatic retries. This paragraph is the orchestrator's execution record, not a claim that the independent reviewer ran these tests.

Development report start: `2026-10-12T00:54:41.317Z`; production report start: `2026-10-12T00:57:21.149Z`. Final content hashes and exact test outcomes are recorded in verification-results.json. The read-only review of the resulting immutable commit is supplied separately in the task handoff so it can name the actual commit without a self-reference cycle. NO-GO remains unchanged.

## Hosted verification supplement — immutable 64dd74d

Astra independently reviewed `64dd74d1e061a7e472fe6825f28808ba89bbbec7` after the initial immutable implementation review of `d05ebd31a7101c1413952ea4fee08062393b6b3b`. The diff contains only GitHub reporter additions in both Playwright configurations and a CI build-step ID plus production diagnostic condition. It changes no application code, tests or assertions. A failed development step still fails the job; production can collect evidence when the build succeeded and the job was not cancelled. No code objection was found.

Astra inspected REST metadata binding successful runs 38190803860 and 38190799370 to the exact commit. Every verification step succeeded, including pinned-browser installation, development and production. Both annotation sets report 237 development and 20 production passes, consistent with 79 scenarios across three engines and four smoke scenarios across five projects. This supersedes the earlier hosted-browser execution blocker for this commit. It does not establish physical Safari behavior or access to raw hosted reports.

The two initial hosted failures remain unexplained; reporting changes are not a demonstrated causal fix. The 17 incomplete interaction contracts, 43 unverified/partial function branches and historical concurrent-write failure remain explicit. **Final technical assessment: NO-GO for release; scoped repairs and CI reporting changes accepted.** The later documentation-only handoff records this evidence without changing the tested source, tests or configurations. Its exact immutable SHA and final review outcome are supplied in the handoff.
