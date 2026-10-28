# Test and App Review evidence — 29 October 2026

The audit began at `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba` with existing
uncommitted native accounts and the owner's custom animated tab bar. The work
continues on `feat/frontend-widgets-2026-10`. Existing dirty changes are part of
the baseline, not all changes from this audit. Historical guest-only reports do
not describe the current account-enabled build.

This report records source/resource/privacy review and scoped Watch edits. It
does not claim a signed archive, App Review approval, physical Watch operation,
validated live accounts or measured performance. Final integration command
results belong in the audit's change summary; the evidence below must not be
expanded into a build/device pass without the corresponding run.

## Checks observed in the Watch/privacy subaudit

| Check actually performed | Observed result / limit |
| --- | --- |
| Complete mandatory document reading | Assigned 11 native design/privacy/provenance documents read in full; 1,564 lines at read time. Owner brief read 1–362. Historical statements distinguished from current source. |
| Authored Watch/account review | Every authored file under `FORMAWatch`, `Shared` and `FORMA/Account` read completely. Project, all six plist/entitlement/privacy files, integration workflow and resource generator also read completely. Detailed read ranges/dispositions are in the file ledger. |
| Property-list parse | All six current iPhone/Watch Info.plist, entitlement and privacy-manifest files parsed successfully. This is source metadata validation, not signed binary validation. |
| Asset metadata / provenance | Six asset catalogs parsed; every referenced PNG exists. Three durable manifest hashes/sizes match. All three PNGs visually inspected; binary bytes are not claimed as line-by-line source reads. |
| Image dimensions and size | iPhone and Watch icons are byte-identical 1024 × 1024 RGB PNGs, 17,399 bytes each. Editorial image is 1536 × 1024 RGB, 2,187,502 bytes. No image regeneration/edits. |
| Resource-manifest validation | All 16 source hashes and five output hashes/sizes match at audit time. Generated JSON parsed: 1,711 unique catalog IDs, 1,411 selectable, 1,711 matching notice IDs, three seed routines, empty history and null active workout. This did not execute the generator or domain test suite. |
| Required-reason source search | No direct UserDefaults, uptime, timestamp or disk-space API use found across native app, Watch, Shared and core source; URL file-size/type metadata is used in recovery handling. Final linked-binary inspection remains open. |
| Changed Watch Swift formatting | All four edited Swift files pass the installed toolchain's `swift-format lint --strict`. Bare `swift-format` was absent from PATH; the absolute Xcode toolchain binary succeeded. |
| Changed Watch whitespace | `git diff --check --` the four scoped paths passed. |
| Build, unit/UI tests, Simulator, device | Not run by the Watch/privacy subaudit agent; owned by the integrating agent. No fresh test count is inferred here. |

Read-only parser results are retained in
`/tmp/forma-widget-watch-audit/validation.json`; read coverage and source findings
are in `ledger.json` and `findings.md` alongside it. Scratch paths are not durable
release evidence; the repository file ledger and integration results should be
used for handoff.

Formatting command actually run from the repository root:

```sh
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format lint --strict \
  ios/FORMAWatch/WorkoutManager.swift ios/FORMAWatch/WatchViews.swift \
  ios/FORMA/App/WatchWorkoutCoordinator.swift \
  ios/FORMA/Features/StartWorkoutSheet.swift
```

## Watch changes and remaining behavioral proof

The iPhone previously reported a Health save immediately after sending an end
command, including a failed delivery. It also treated HealthKit's stopped state
as a completed save. The coordinator now distinguishes ending from session-ended
and shows a neutral instruction to check the Watch for Health save status. It
retains a recording state when end delivery fails. No remote save acknowledgement
was invented.

Watch recovery now re-establishes mirroring. A failed mirror has a single-flight,
user-requested Reconnect action and sends current metrics after success. It does
not poll or stop Health collection when the iPhone is absent. These are source
changes; reconnection/save behavior still requires paired-hardware execution.

| Scenario | Required acceptance evidence |
| --- | --- |
| Watch unavailable / permission denied | iPhone-only logging remains useful; no fake Watch recording or success. |
| Disconnect and reconnect | Watch recording continues; explicit reconnect restores current metrics without duplicate FORMA/Health workouts. |
| Watch process recovery | Recovered primary session mirrors again and preserves elapsed/pause state. |
| End command lost | iPhone never says saved; Watch remains controllable and the failure notice is visible. |
| Slow/failed Health save | iPhone remains pending or neutral; Watch error is preserved; no duplicate workout save. |
| Locked Watch finish with nil workout/nil error | Treat as successful system save, without retrying into a duplicate. |
| Watch HealthKit session failure callback | **Fixed in source; hardware proof open:** the failed screen offers a confirmed discard and explains that already recorded Health samples may remain. Session/builder callback guards reject late events after discard; no automatic loss or speculative save retry. |
| Session/account ownership | A late mirrored callback cannot attach another owner's workout or republish private data after account exit/reset. A future Live Activity/widget must be bound to saved session and owner generation, not live Health metrics. |

## Widget, privacy and release matrix

The [source register](APPLE_2026_SOURCE_REGISTER.md) supplies the current Apple
links, retrieval date and availability distinctions. Source metadata checks are
not substitutes for the following final-binary/device evidence.

| Area | Current source facts | Release gate |
| --- | --- | --- |
| Accounts | Optional real account source exists; credentials stay outside widget/Watch projections. Member and guest stores are separate. | Fresh staged account lifecycle tests with synthetic users; usable credentials were unavailable previously. No production authentication was attempted in this audit. |
| In-app deletion | You → Account → Privacy & account initiates deletion with password/DELETE and describes emailed confirmation. | Verify real staged email completion, revoked sessions and local cache behavior. Historical guest-only deletion matrix must not be reused as current proof. |
| Local cache removal | Sign-out can keep or request removal of a member copy. Corruption/recovery files need owner-scoped retention review. | Prove the removal promise covers raw recovery and `.unreadable-*` copies, preserves other owners' data, and surfaces deletion failures. |
| Data protection | Private workspace uses complete protection and backup exclusion. | Check passcode-device attributes for SQLite/WAL/SHM/recovery files and any shared snapshot, including lock/reboot and failed writes. |
| App Group/signing | App and Watch bundle identifiers have a matching companion prefix; the existing development team `3L5A4R7JNY` is pinned in project source; the app and widget share the provisioned App Group. | Confirm owner-controlled widget identifier, matching app/extension group/team/profiles, target embedding and signed entitlements. Do not change team identity to unblock a build. |
| Lock Screen / Always On | Training patterns and routine names can be private even without Health metrics. | Confirm extension protection and actual redaction; Complete protection intentionally disables iPhone-on-Mac widget mirroring. Test unavailable/empty/corrupt states separately. |
| Widgets | Snapshot/deep-link implementation is documented separately in this audit. | Compile/embed actual targets; inspect every family in real gallery, Home/Lock Screen, tint/clear/vibrant, long names, large text, empty/reset/stale/owner-switch states. |
| Required-reason APIs | Existing app/Watch manifest lists are empty; source uses no known directly listed API requiring a reason. | Inspect every final executable/dependency and extension manifest; add only factually matching approved reasons if actual APIs change. |
| Health | Health authorization types include workout, heart rate and active energy; basal energy is read. Live metrics are not workspace fields. | Paired-hardware permission revocation, persistence and network/export exclusion proof; reconcile purpose strings and privacy answers. |
| App Privacy | Current account manifest declares linked email/name/fitness/user ID for functionality, no tracking. | Assess notes as Other User Content/Health as appropriate and verify archive/network inventory. Guest mode does not justify Data Not Collected for the whole build. |
| Artwork/guide rights | Original generated decorative image and deterministic mark; entry-specific guide credits retained. | Human rights/license/brand review, including share-alike compatibility and final screenshot truth. |
| Accessibility | Source labels/controls are only one layer of evidence. | Physical VoiceOver, Voice Control/Switch Control, largest Dynamic Type, Reduce Motion/Transparency, contrast, sunlight and sweaty-hand interaction. |
| Performance | No Release Instruments/device measurement in this subaudit. | Same-device/scenario Release baseline and final traces, energy/thermals and adequate sample counts. No FPS/speedup claim from static review. |

## App Review and owner decisions

Current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
require complete, accurately represented functionality and public APIs. Privacy,
consent, account deletion, health data handling and IP rights need the final
shipping binary and policies. For provider eligibility under 5.1.1(ix), obtain an
Apple/legal determination for this actual service and operator. Personal
membership is neither certified sufficient nor automatically rejected here.

Before distribution the owner must approve final operator/support, age/guardian,
regions, privacy/retention text, content rights, account review access and export
compliance. Confirm SDK requirements again on submission day. App Group
registration, profiles, archive validation and any App Store Connect action stay
with the owner. This audit does not publish, submit, enroll, contact others,
change production, or establish Apple approval.

Live Activity release remains gated until ownership/end/relaunch/stale and privacy
behavior is proven. A Watch widget needs an explicit Watch-local data path and
provisioning; the iPhone group's file is not implicitly available on Watch.

## Final root integration evidence

These outcomes supersede the unfinished integration status in the earlier subaudit section while preserving its narrower claims. All data is synthetic and local; no production authentication, deployment or external-service mutation occurred.

| Executed check | Result / actual artifact |
|---|---|
| `swift test --package-path ios` | **141 core + 4 surfaces passed**, `/tmp/forma-widget-package-complete.log` |
| `swift run --package-path ios FORMAContractProbe . /tmp/forma-widget-contract.json` then `node scripts/check-ios-contracts.mjs /tmp/forma-widget-contract.json` | **1,711** actual native-generated cases accepted by canonical strict web validation; `/tmp/forma-widget-probe.log` and contract fixture |
| `npm run test:unit` | **151 passed**, `/tmp/forma-widget-web-unit.log`; native-resource/boundary subset **17** in `/tmp/forma-widget-resources-final.log` |
| `node scripts/build-ios-resources.mjs --check` | Passed, `/tmp/forma-widget-resource-check.log`; 1,711 catalog/notice IDs and hashes validated |
| Hosted app + real widget gallery | **32 hosted + 1 UI gallery journey passed**, `/tmp/forma-widget-widget-complete.log`; `.xcresult` `Test-FORMA-2026.10.29_02-05-24-+1100` |
| Complete repeated UI matrix | **24 passed, zero failed**, `/tmp/forma-widget-regression-complete.log`; result `/tmp/forma-widget-derived/Logs/Test/Test-FORMA-2026.10.29_02-24-48-+1100.xcresult` |
| Dark tours | **3 passed**, `/tmp/forma-widget-dark-tour.log`; `.xcresult` `Test-FORMA-2026.10.29_02-17-08-+1100` |
| Signed Release + embedded extension | Build passed; actual signature/App Group/Complete protection/privacy/no SQLite-or-Health link validator passed. Final rebuild/install status below. |
| Swift formatting | Strict lint across 61 changed/new Swift files passed after formatting-only repairs; `/tmp/forma-widget-swift-format-final.log` |
| Web static checks | ESLint, TypeScript and Prettier passed in `/tmp/forma-widget-{lint,types,format}.log` |
| Documentation / whitespace | `npm run docs:check` passed 120 Markdown files after adding the final summary; final `git diff --check` is recorded at handoff |
| Changed/new text secret review | Redacted Gitleaks scan found three historical generic-api-key detections in AGENT/CHANGELOG. Exact detected lines already exist at HEAD; no new credential finding. No credential values were printed or copied into this report. |

UI reproduction (ad-hoc signing is necessary for actual hosted Keychain tests):

```sh
xcodebuild test -project ios/FORMA.xcodeproj -scheme FORMA \
  -destination 'platform=iOS Simulator,id=B84DC3C8-D015-4BB6-9408-E5522F6D0346' \
  -derivedDataPath /tmp/forma-widget-derived -parallel-testing-enabled NO \
  -only-testing:FORMAUITests -skip-testing:FORMAUITests/WidgetGalleryTests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=3L5A4R7JNY
```

The skip applies only to this repeat after its actual successful installation/deep-link journey. The gallery case remains part of normal default tests. It uses semantic controls first; iOS 27's remote gallery sometimes omits the visible Add Widget control from accessibility, so a geometry-guarded fallback taps its observed position on the tall portrait review viewport. This fallback is test-only.

Original screenshot dimensions, hashes, test names and timestamps are preserved in [visual-evidence.json](visual-evidence.json). Widget gallery previews intentionally use illustrative two-of-four progress; the installed widget uses actual committed zero-of-four. Shared-view renders explicitly identify their component context. No gallery/example snapshot is substituted for unavailable private training in a real timeline.

Historical failed runs remain failed evidence: full UI 24/five failed; focused queued navigation and gallery discovery failures. Fixes and rerun provenance are described in [SCREEN_REVIEW](SCREEN_REVIEW.md). Runtime `invalidDigitCount(94232)` metadata and SwiftUI keyboard frame diagnostics occurred without a matching failed assertion in final passed runs; no unsupported SDK workaround was added.

### Final visual and tooling reconciliation

The 24/24 UI suite finished successfully; its automatic `simctl diagnose` collector stalled afterward. Only that owned diagnostic child was terminated after roughly 2.5 minutes, allowing Xcode to finalize the valid `.xcresult` and `TEST SUCCEEDED` output. No test runner, assertion or app was terminated to create a pass. A trial build-only invocation with `-enableCodeCoverage NO` was rejected before execution because that option is test-only; the actual fix uses project/scheme settings and the subsequent signed build.

The original landscape application snapshot raced the rotated capture surface. The capture helper now waits for settled layout, takes `XCUIScreen` evidence, asserts its orientation matches the tested viewport and retains the full Start geometry assertions. Both focused layout cases passed in `/tmp/forma-widget-layout-capture-final.log`; final exported landscape is a correct 2622×1206 original.

Expanded real-view rendering found and repaired large-text widget clipping. The final renderer covers **120** light/dark family/state/text-size combinations in `/tmp/forma-widget-render-last.log`. It includes normal saved/active/completed/long-name/private and empty/hidden/unavailable/stale states for all six families, plus accessibility3/accessibility5 for three Home families. It validates image production/dimensions; sampled originals were visually reviewed, without claiming image assertions prove passcode redaction or all system appearances.

A short Simulator Time Profiler capture completed; its exact duration, sample row count, warning and limitations are in [performance evidence](PERFORMANCE_BASELINE_AND_RESULTS.md). Release physical-device performance remains NOT RUN.

### Final signed delivery

`/tmp/forma-widget-device-delivered.log`: **BUILD SUCCEEDED**, generic iOS Release, existing team `3L5A4R7JNY`. `/tmp/forma-widget-device-bundle-final.log`: embedded extension/signature verified, correct protected group/minimum iOS 17, no SQLite/Health linkage. Mach-O coverage sections are absent in all three signed executables:

| Executable | SHA-256 | `__llvm_prf*` sections |
|---|---|---|
| FORMA | `6d0f318a2eef4d7faa1c5cb45fa11b479cdfe2497cc7864b80d6fdb798d053c1` | absent |
| FORMAWidgets | `ecb0381cf5f9fc803cd7098d4a0ab2a400ebbe69cabc527fe42f3e5555598594` | absent |
| FORMAWatch | `e4d165c4acf8f04780e7dd27d06b9cc46557981b9bf1960873e5de2ddba4c68a` | absent |

`/tmp/forma-widget-phone-delivered.log`: the final signed app installed successfully on the physical iPhone. `/tmp/forma-widget-phone-delivered-launch.log`: launch denied because the iPhone remains locked (CoreDevice 10002, FBS locked error 7). This is installation proof only. The Watch remains blocked by the earlier CoreDevice 4000 / RemotePairing 1035 Bluetooth rejection; no new unlocked/USB state was supplied. No interactive phone, Health, paired Watch or passcode privacy success is inferred.

## Authorized branch publication

Implementation commit [076e267c6a4b3b5081348ddbd40cf53e22700ffd](https://github.com/Raoof128/forma-workout-planner/commit/076e267c6a4b3b5081348ddbd40cf53e22700ffd) was pushed to `origin/feat/frontend-widgets-2026-10`; `git ls-remote --heads` returned that exact SHA. This is Git delivery, not production/Store delivery. A documentation-only follow-up reconciles the release logs. All committed source hashes matched the settled audit ledger and staged additions had zero Gitleaks findings. Remote CI was started by the branch push and remains a separate observation from the locally passed test matrix.
