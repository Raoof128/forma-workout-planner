# FORMA implementation handoff

Audit started 4 November and continued 5 November 2026, Australia/Sydney. Starting website branch: `fix/tunnel-monitor-readiness`; starting commit: `3c27308c5856928ab18650293df1c2f6e2e91389`, the already-pushed native implementation checkpoint. This website checkpoint is ready for publication under the user's explicit commit/push authorization. Complete current-source CI and local account matrices remain open; no full-pass or release-ready claim is made yet.

## Implementation

The changes correct reproduced reliability and access faults while retaining the established training product. Version 2 workspaces, historical exercise IDs/units, account/member isolation, guest/offline training, media precedence/attribution, local fonts, artwork and drag tuning remain. No dependency, migration or production deployment was added.

| Area | Result and owning files |
| --- | --- |
| Account drafts and recovery | [Account](../../../src/components/Account.jsx) retains later name/goal/email drafts, captures submitted values, honors reviewed conflict reload without erasing newer input and catches retry failures. [App](../../../src/App.jsx) distinguishes read refresh from exact pending-write retry. |
| Submitted training edits | [Routines](../../../src/components/Routines.jsx) and [HistoryEditor](../../../src/components/HistoryEditor.jsx) freeze pending forms, prevent duplicate submissions and retain rejected drafts. [RoutineCardOrder](../../../src/components/RoutineCardOrder.jsx) confirms a move only after persistence, with failure rollback. |
| Timer ownership | [Workout](../../../src/components/Workout.jsx) cancels a stopwatch when its exercise/set disappears or is replaced, invalidates late wake grants and rechecks current identity before writing. The immediate duration alarm remains distinct from saved-set acknowledgement. |
| Focus and preferences | [Navigation](../../../src/components/Navigation.jsx), [useNavigation](../../../src/hooks/useNavigation.js), explicit dialog openers and the Skip handler preserve usable focus across Safari behavior and asynchronous recovery. [ExerciseAnimation](../../../src/components/ExerciseAnimation.jsx) pauses on a live reduced-motion change without restarting automatically. |
| Responsive readability | [styles.css](../../../src/styles.css) retains 16 px numbers and 44 px Done targets at narrow widths. [account.css](../../../src/account.css) improves helper contrast/phone inputs/tablet navigation and prevents narrow Security wrapping and tablet auth clipping. [Overview](../../../src/components/Overview.jsx) describes account saving accurately. |
| First account workspace | [workspace.ts](../../../server/workspace.ts) builds the existing bounded name prefix from complete Unicode code points. A real PostgreSQL boundary regression replaces the original invalid-surrogate JSONB failure; stored data and authentication are unchanged. |
| Regression coverage | Added controlled account/editor/order/design/numeric/hold checks. An existing four-route start test now waits for the actual session heading before its unchanged persisted-name assertion. Mac WebKit keyboard normalization is volatile per process; security tests retain DOM/network/source traces and failure images while omitting the expensive continuous filmstrip. |

[Findings](FINDINGS.md) provide exact source lines, reproductions, corrections and remaining limits. [File ledger](FILE_LEDGER.md) reconciles **1,214 inputs and 243 complete authored reviews**, with zero source gaps or stale hashes at the recorded checkpoint. Structured data, 627 full raster decodes and 22 complete video decodes/6,924 frames are separate review methods; they are not universal visual, coaching or legal approval.

## Verification and visual critique

Current completed evidence includes 151 unit, 35 Worker and 77 server passes; full lint/format/type/docs checks; 18 editor/order, 15 account draft/retry/conflict, six existing WebKit focus, 21 hold/numeric and ten narrow Security/auth focused passes. The last Skip and CTA readiness checks each passed all three desktop engines. These groups overlap and are not summed into an inflated unique-test count.

The first full guest run recorded 512/519. The later 540-case attempt stopped with 271 passes, one test-readiness failure, one interruption and 267 unrun before the last focus correction. The failure trace showed a same-route assertion running before the durable commit; the strengthened readiness check preserves the data assertion. Earlier account development recorded 189/190 with a WebKit cumulative timeout, then 37/38 on repeat. The unchanged security journey subsequently passed in 20.873 seconds when only trace-filmstrip capture was disabled. Current broad matrices remain pending. Exact commands, retained attempts and final dispositions belong to [test results](TEST_RESULTS.md) and its [machine-readable evidence](evidence/VERIFICATION_RESULTS.json).

The visual package has **318 primary product PNGs**, **30 paired contact sheets** and clearly separated intermediate diagnostics. It includes 78 matched guest states, 48 matched account states, loaded-font narrow measurements and actual Security captures. The extended account sweep passed **88/88 states at 11 widths**, including internal auth bounds and field sizing. The final critique found no outstanding material defect in reviewed states. Transient lazy-media frames and emulated-browser limitations remain explicit in [screen review](SCREEN_REVIEW.md) and the [screenshot index](evidence/screenshots/INDEX.md).

## Performance and accessibility

[Performance](PERFORMANCE.md) records exact build bytes, five interleaved before/after pairs per desktop/mobile profile and three paired React development profiles with 2,000 synthetic history entries. The CSS-freeze set measured mobile lab LCP about 4.3 seconds in both builds; no causal speedup is established. The main bundle grows by 2,203 bytes and the existing chunk warning remains. The final small Skip callback requires the queued current-bundle repeat before those measurements are called final-source evidence. These are lab samples, not field p75, INP, FPS, energy or leak results.

The accessibility work improves contrast, phone field sizing, readable numeric values, keyboard focus, dragging alternatives and motion preferences. The [WCAG mapping](ACCESSIBILITY_AUDIT.md) distinguishes automated checks and measured browser journeys from unverified criteria. Physical Safari keyboard/zoom and real screen-reader sessions remain open; no blanket WCAG certificate is claimed.

## Physical iPhone Verification

The authorized **Raouf iPhone Air** ran a separately signed, isolated development bundle with distinct storage identities and synthetic data. Baseline and final signed builds succeeded in **38.889** and **37.952 seconds**. The full final physical suite completed **164 passes, two intentional personal-device safety skips and zero failures**; three additional Light tours passed. There are **32 matched Light/Dark screenshot pairs**, with metadata removed while preserving display pixels.

Actual projection samples averaged **20.188 to 19.926 ms**; the four-tab XCTest clock averaged **5.712 to 5.749 seconds**, including driver overhead. Launch samples were incomplete; memory/CPU values and limitations remain in the [dedicated physical report](../../../ios/docs/audits/native-frontend-2026-11/PHYSICAL_IPHONE_VERIFICATION.md). No speedup, thermal, energy or leak conclusion follows. The ordinary app/widget/Watch build also passed unsigned in **36.346 seconds**. Existing phone apps, training data and security/settings were preserved.

Simulator UI installation stalled, so no Simulator UI pass is inferred. Real Watch/Health, locked ActivityKit/widget placement/privacy, iOS 17 runtime, complete assistive technology and signed distribution remain unverified. Native results do not establish physical Safari behavior. App Store release remains NO-GO under those documented gates.

## Running and delivery boundary

Use the supported Node version, `npm ci`, and `VITE_ACCOUNT_MODE=guest npm run dev -- --host 127.0.0.1` for local guest review. Use the pinned Playwright browsers and the repository scripts in [test results](TEST_RESULTS.md). Server/account tests require all three documented test database variables to point explicitly to the same disposable local database; never use a production member database.

[AGENT.md](../../../AGENT.md) and [CHANGELOG.md](../../../CHANGELOG.md) retain the historical notes and record this checkpoint. Final broad results, current-bundle metrics, staged scan, commit/push verification and owned-service cleanup remain to be recorded. No merge, production deployment, live infrastructure mutation, Store action or real training-record mutation occurred. Local source quality, deployment health, physical-web behavior and distribution readiness remain separate evidence boundaries.
