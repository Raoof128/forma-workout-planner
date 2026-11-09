# FORMA web frontend audit

4–5 November 2026, Australia/Sydney. Baseline: `3c27308c5856928ab18650293df1c2f6e2e91389`; implemented application source: `cc771830b92929485dae5f4fe8297a49df9fa394`. Documentation-only follow-up `c247e9e` preserves the same source/test/configuration fingerprint.

**The implemented changes passed the complete web CI run and both final local account matrices.** [CI run 41840783732](https://github.com/Raoof128/forma-workout-planner/actions/runs/41840783732) completed **SUCCESS**, with both jobs and every stage successful. Local development and production-build account matrices each passed **200/200**, with zero failures, skips or retries.

The corrections preserve profile drafts during acknowledgements and refresh, honor explicit conflict-reload intent, distinguish read reconnection from exact pending-write retry, protect submitted routine/history edits and confirm routine order after persistence. Unicode-safe first-workspace initialization fixes a real PostgreSQL failure. Delayed/explicit Skip focus, Safari dialog/drawer focus, hold ownership, live reduced motion and narrow measurement/Security/tablet-auth layouts are corrected. FORMA retains its lime and ink palette, fonts, artwork, native controls, drag behavior, workspace schema, saved identities/units and guest/member security boundaries. No dependency, migration or service provider was added.

## Completed verification

| CI execution stage                | Actual passes | Failures / skips / interruptions |
| --------------------------------- | ------------: | -------------------------------- |
| Guest development browsers        |           540 | 0 / 0 / 0                        |
| Production browser smoke          |           175 | 0 / 0 / 0                        |
| Account development browsers      |           200 | 0 / 0 / 0                        |
| Production-build account browsers |           200 | 0 / 0 / 0                        |

CI also passed 151 unit tests, 35 Worker tests, 77 real-PostgreSQL server tests, eight Python and eight Node operations tests, 166-file documentation validation, lint, formatting, type/build checks and the configured security scans. CI used Ubuntu 24.04.5, Node 24.22.1/npm 11.19.1 and PostgreSQL 18.4. Local account verification used the separately owned PostgreSQL 18.6 cluster; its 77-test server result passed in 29.076 seconds, and the final whole-WebKit gate passed 40/40. Exact receipts and retained history are in [TEST_RESULTS.md](TEST_RESULTS.md).

The full final runs include the strengthened hold-cue checks, Skip-after-retry, CTA readiness, persisted editor/order behavior and all seven design cases per account profile. The two local account matrices each include 35 design executions across five profiles. The final responsive sweep has 88 fitting states and zero failures; narrow Security and tablet sign-in/sign-up/reset regressions pass without hiding controls.

Historical failures remain separate: the frozen 507-case baseline stopped at 130 passes, two failed timeout cases, one interruption and 374 unrun cases; the first complete guest attempt was 512/519. A later 540-case attempt stopped at 271 passes, one readiness-race failure, one interruption and 267 unrun cases. The four-route CTA case retained its stored-name assertion and gained an exact ready-heading wait; it then passed 3/3. The separate Skip product fix produced three controlled failures followed by 3/3 passes. The earlier account matrix was 189/190. None of those historical attempts is relabelled as the final successful execution.

## Visual and performance assessment

The published package distinguishes 318 primary product captures, 30 contact sheets and 15 intermediate diagnostics. Full-size critical-subset inspection, whole-set structural checks and phase labels are recorded in [SCREEN_REVIEW.md](SCREEN_REVIEW.md); candidate CSS images are not final-product captures. All 627 raster assets were decoded/drawn and all 22 videos decoded across 6,924 frames without errors. These integrity checks do not grant new pose, coaching or legal approval.

Final paired measurements use the implemented source: 20 production journeys and six React profiles, with no recorded browser errors. A clean rebuild reproduced the measured HTML and asset hashes. Mobile lab LCP remains **3,920 ms before and after** under the documented throttling; the main JavaScript grew by **2,229 bytes** and the large-chunk warning remains. No speedup or new measured performance regression is established. Mobile payload/parse cost remains a documented concern. [PERFORMANCE.md](PERFORMANCE.md) separates these lab observations from field INP/p75, production latency and physical hardware.

[FILE_LEDGER.md](FILE_LEDGER.md) reconciles 1,214 source/data/configuration inputs, including 243 complete authored reviews and all 193 runtime/test/configuration inputs. Generated visual evidence and private raw-log digests have separate methods and publication boundaries. Final documentary hashes are refreshed separately from the tested application source.

## Physical iPhone Verification

The native audit used a separately signed, isolated development build on the authorized **Raouf iPhone Air**. Its app identity, App Group, Keychain service and synthetic data were separate from the existing FORMA installation. No personal training data or device security settings were changed.

- Both physical-device builds succeeded: baseline **38.889 seconds**, final **37.952 seconds**. The final full device run had **166 cases: 164 passes, two intentional skips and zero failures**. The skips protect personal Home Screen state and avoid a Simulator-only AutoFill-settings fixture.
- There are **32 matched before/after Light and Dark screenshot pairs**, including phone layout and accessibility-size evidence. Generic metadata was removed from the curated PNGs while preserving their oriented display pixels. The original pushed screenshots were also privately checked: their metadata contained generic screenshot/dimension/orientation/toolkit fields, with no personal device identifiers, location or credential material.
- Ten projection samples averaged **20.188 to 19.926 ms**. Five four-tab samples averaged **5.712 to 5.749 seconds**, including XCTest automation overhead. Responsive-launch samples averaged **455.3 to 458.4 ms**, but only four usable samples were returned and that benchmark remains incomplete. No speedup, FPS, thermal, energy or leak conclusion follows from these small samples.
- The ordinary app, widget and embedded Watch build also compiled successfully in **36.346 seconds**, unsigned and without installation. Real Watch/Health, locked ActivityKit/widget privacy, iOS 17 hardware/runtime, manual assistive technology and distribution checks remain open. Simulator installation stalled; no Simulator UI pass is inferred.

The [dedicated native verification report](../../../ios/docs/audits/native-frontend-2026-11/PHYSICAL_IPHONE_VERIFICATION.md) records the builds, screenshots, metrics and remaining limits. Native XCTest results do not establish physical Safari keyboard, zoom or web behavior.

## Delivery boundary

The implementation checkpoint and portable-receipt correction are committed and pushed. This final evidence/log update records completed validation and its remaining limits; its documentation-only commit does not alter the tested implementation. No merge, deployment, live infrastructure mutation, Store action or real training-record mutation occurred. Passing CI and local tests does not establish a deployed service or distribution readiness.

The owned standalone PostgreSQL cluster is stopped and the test/API/preview ports are free. Cleanup of the earlier audit Docker container could not be confirmed while the Docker API was unavailable; no global or unrelated process was forced. Physical Safari keyboard/zoom, manual screen-reader verification, field Core Web Vitals and the native device/distribution gates remain unverified. The native minor toolbar-title truncation is retained in its findings. No blanket quality score or security certification is claimed.

See [FINDINGS.md](FINDINGS.md), the [final handoff](FINAL_REPORT.md), [accessibility review](ACCESSIBILITY_AUDIT.md) and [security/privacy review](SECURITY_PRIVACY_REVIEW.md) for the exact corrections, evidence and remaining limits.
