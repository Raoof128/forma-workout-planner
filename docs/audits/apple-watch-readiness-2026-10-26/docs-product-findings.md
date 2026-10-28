# Product, research and QA documentation review

Reviewed all 44 files in `docs-product-manifest.json` in full at commit `1794dd27fad87e8f0cc6f4923d37eedf713783ed`. The exact per-file ledger is `docs-product-review.json`; every source byte count and SHA-256 matches the immutable manifest. Repository source was not changed. Shell validation was limited to `bash -n` and source inspection: no release command, migration, backup, Docker operation, network fetch or member mutation ran.

Dated QA results, prior NO-GO decisions and research proposals retain their historical meaning. The findings below concern current-facing descriptions or an executable helper still recommended in `AGENT.md:137–148`. None establishes that an earlier recorded deployment failed. T11, referenced from `docs/testing.md`, is defined in `tests-findings.md` and concerns the configured production/mobile selection omitting hold journeys.

## DP01 — P3: Routine editing guidance omits the current per-side limit and reviewed side labels

**Evidence:** `docs/routine-programming-v2.md:7–8` says each rep endpoint is 1–100 without the per-side exception. Lines 15–17 say lower-body movements display `/ leg` and everything else `/ arm`. Current `src/routineProgramming.js:37–44` rejects per-side load/reps targets above 50, including the upper endpoint; `src/components/Routines.jsx:559–566` blocks saving them. `sideLabel` at `src/routineProgramming.js:17–22` first uses the reviewed `exercise.side`, which can be `side`, before its leg/arm fallback.

**Impact:** A member or integrator following the current feature guide can prescribe an advertised valid 60-per-side target that cannot save/start, or expect the wrong label. Historical larger saved prescriptions remain readable; that is distinct from acceptance of new edits.

**Correction:** Document 1–100 total reps versus 1–50 per side, the upper-range check, historical-data preservation, and the reviewed arm/leg/side labels. Existing per-side unit/browser tests already establish the current behavior; no schema change is needed.

## DP02 — P3: Current-status entry points still direct readers to pre-account release state

**Evidence:** `docs/verification.md:3–5` calls the 12 October browser-only NO-GO report the “Current release-readiness audit” and “current release report.” `docs/qa/README.md:3` frames the directory as that historical browser-only candidate and routes “current account gates” through the older account report while omitting later release folders. `docs/qa/accounts-security.md:3` calls local integration the current release target and says no FORMA resources are deployed; lines 68–72 retain current-sounding external blockers. In contrast, `docs/qa/runtime-quality-2026-10-26/README.md` records the later staging/production API and frontend release, and states its remaining live/read-only, signed-in, restore and physical-device limits precisely.

**Impact:** Readers entering through verification/security indexes can mistake an older candidate's blockers and browser-only architecture for the current deployment state. This does not invalidate the named 12 October review, its frozen outcome table, or any earlier NO-GO decision.

**Correction:** Label these entry points and auth-security outcome sections as dated snapshots, add links to the later runtime audit and release receipts, and keep current outstanding gates separate from historical blockers. Do not rewrite historical counts or fabricate a new GO verdict.

## DP03 — P3: Authentication implementation notes identify an obsolete installed version

**Evidence:** `docs/qa/accounts-auth-research.md:3` states the server pins Better Auth 1.7.7; lines 40–50 describe “the installed 1.7.7 implementation” and link version-specific TOTP source. `package.json:37` pins 1.7.11. The current runtime audit explicitly documents the corrected pin in `docs/audits/forma-runtime-quality-2026-10/AUDIT_REPORT.md:154`.

**Impact:** A maintainer can inspect the wrong installed implementation when evaluating session/MFA assumptions. This is documentation drift, not evidence that the existing TOTP replay guard or encrypted recovery codes are broken.

**Correction:** Either clearly date the entire note as 1.7.7 research or reconcile its pin and source references with 1.7.11, preserving which behavior was actually verified. No new upstream source or security assessment was performed in this read-only review.

## DP04 — P2: Release helper does not bind the deployed image to the verified archive

**Evidence:** `docs/qa/holds-timer/api-release.sh:22–25` copies/verifies the supplied archive's SHA-256, but line 26 skips `docker load` whenever `forma-api:$TAG` already exists. Line 27 records that existing image's ID without comparing it to the verified archive. The migration at line 37 and API update at lines 43–44 then use that tag. `AGENT.md:137–148` still recommends this helper for API releases; the helper's line 2 advertises generic environment/tag/archive arguments.

**Trigger and impact:** Retry a tag after rebuilding/correcting its archive, or encounter a stale local tag on the release host. The archive checksum can pass while migrations and the API use different pre-existing bytes. This is a deterministic identity gap in the helper, not a claim that the historical holds release used an incorrect image.

**Correction:** Load the verified archive and verify the resulting expected image identity, or require a separately supplied immutable image digest and compare the selected tag to it before migration or deployment. Keep the archive/source/image identity in the release receipt. A unique-tag convention alone is not enforced by this script.

## DP05 — P2: Release helper reports success despite failed postflight invariants

**Evidence:** `docs/qa/holds-timer/api-release.sh:65` handles a count mismatch by printing both snapshots; line 66 handles unrelated-container differences with `echo`; line 67 prints the error-line count. Those successful reporting commands leave the script with exit status zero even if all three checks show a problem. `set -e` does not make these explicit `||` branches fatal. Error collection at line 57 masks failures and only keeps five matching lines. `others()` at line 19 records name/image/status but no container ID, so recreating an unrelated container under the same name/tag and healthy state can compare equal.

**Impact:** A caller can record a successful release after an unexplained data-count change, cross-environment recreation, or API error. Counts can legitimately change during live member writes, so a mismatch is not itself proof of data loss; the defect is that the helper has no explicit failed/review-required outcome and its isolation comparison cannot detect same-name recreation.

**Correction:** Make unresolved postflight deviations fail or require an explicit reviewed acceptance path, preserve full relevant logs, and compare unrelated container IDs plus image IDs/health. Do not automatically roll back or restore member data merely because counts differ. The historical release receipts may contain additional manual checks; their recorded success is not invalidated here.

## DP06 — P2: Generic release helper automatically rolls back after migrations without compatibility validation

**Evidence:** `docs/qa/holds-timer/api-release.sh:36–38` invokes the new image's migration runner; “expected no-op” is only a comment. On failed health polling, lines 51–55 unconditionally restore the old `.env` and recreate the previous API. There is no migration/version/catalog or saved-data compatibility check. The surrounding release notes explicitly warn that old images reject saved timed identities (`docs/research/exercise-logging-review.md:205–217`; `docs/qa/holds-timer/README.md:24`), while `AGENT.md:137–148` recommends the helper beyond the original release.

**Trigger and impact:** Reuse this helper for a release whose migration or newly accepted saved IDs/fields are not readable by the prior API, then encounter a health failure. The rollback can leave the old API unable to read current workspaces. This risk depends on compatibility of the actual release; it is not proof that the original no-op-migration release's rollback was unsafe or that any rollback occurred.

**Correction:** Restrict and clearly label the helper for its original compatible/no-op release, or enforce an explicit checked rollback-compatibility plan before deployment. For incompatible changes, stop with a failed state and follow a forward-repair plan; preserve member data and backups rather than blindly restoring an older database.

## Evidence boundaries

The current user guide already states that an in-progress hold is component-local and resets on navigation/reload; this limitation was not reported as an undocumented guarantee. The runtime audit and later QA receipts carefully distinguish lab action timings from field INP, repeated coverage from a clean first run, anonymous hosted probes from member journeys, and Playwright WebKit/mobile emulation from physical iPhone/watchOS validation. The research proposals distinguish candidate coverage, exact variant acceptance, metadata checks, medical judgments and reuse rights. No new clinical, licensing, screenshot/frame, native HealthKit/WatchConnectivity, physical-device or hosted-service certification follows from reading these documents.
