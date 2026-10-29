# File-by-file native correctness audit

23 October 2026, Australia/Sydney. This audits the loaded draft and preserves
its prior foundation and Apple design work. Nothing was published.

Coverage: **68 authored native files**, including these two reports, **eight
integration files** and **six shared contract modules**. All **80 input files**
are recorded below and in the [SHA-256 ledger](native-file-review.json). No
native authored input was skipped. `.build`, `.swiftpm` and Python caches are
generated outputs. The scope is the native app and these named supporting files.

Source/documents were read completely. Generated resources/fixtures were checked
record by record, including all 1,711 catalogue and credit records and every
shared boundary/golden fixture. Both app PNGs were decoded, hashed and visually
inspected; their bytes remain unchanged. These methods are distinguished from
manual line reading of generated JSON. Reports are read/validated separately
without hashing themselves into their own coverage ledger.

## Findings and repairs

| Failure | Result and evidence |
| --- | --- |
| Save completion cleared text entered during the awaited write | Freeze submitted workout/notes snapshots and clear only exact acknowledged drafts. Newer edits remain editable and keep close/Finish open; lifecycle saves still queue. Tested acknowledgement helper, source integration review; native race execution remains open. |
| A queued action could follow a changed selected exercise | Capture session/entry identities and resolve them against the acquired workspace. |
| Duplicate exercises produced older or first-occurrence Last time values | Search every occurrence newest first; two failing assertions reproduced, then three regressions pass. |
| Open journal retained deleted records | Details retain only IDs and resolve current stored history; reset removes content and clears stale errors. Authored native reset regression remains unrun. |
| Per-side 60-rep editor formed an invalid 60...50 range | Valid ranges preserve existing values; actionable correction blocks unsupported new targets. Standalone Foundation/source reproduction verifies bounds. |
| Deleting row a removed invalid input belonging to row a\|b | Match exact row IDs when cleaning draft fields; preserve other validation. Guard routine Save against rapid duplicate tasks. |
| Timed-distance logs hid stored load; volume labels varied | Preserve nonzero load in controls/summaries; consistent kg × reps. Seven measurement regressions pass. |
| Valid large backup exceeded the restore reader limit | Compact canonical export: actual 150,000-set backup 11,580,553 bytes versus 36,416,138 pretty-printed; exact round trip and web parse/strict validation pass. ISO Sydney filenames avoid slashes; dialog completion/cancellation releases the temporary snapshot. |
| Native validation accepted invalid canonical exports | Shared 38-case corpus rejects optional zero targets, active completion fields and invalid/noncanonical UTC dates. Fifteen failing assertions reproduced before repair. |
| Retry duplicated the same damaged snapshot indefinitely | Preserve each distinct original once, retaining distinct corrupt bytes and the unchanged database; fault regression passes. |
| Schema-only checker missed changed published measurements | Independent defaults/units/completion comparison rejects seven schema-valid corruptions; all 1,711 fresh actual Swift exports pass. |
| Every set/rest write reparsed unchanged history | Rebuild only when history changes. Foundation/Linux harness measures 191–341 ms old work versus 0.020–0.066 ms comparison; no iPhone performance claim. |
| README contradicted its recorded launch and current contracts | Reconcile existing launch record, workspace v2 and accepted/selectable catalogue counts without asserting fresh service health. |

## Developer documentation and boundaries

The [source register](apple-design-2026.md) now contains **62 official Apple
text/API/session sources**, including five full WWDC26 transcripts, and three
inspected HIG images. New checks cover lifecycle, programmatic dismissal,
localized versus fixed date formatting, export cancellation and direct
required-reason API categories. Individual availability takes precedence over
future APIs appearing in living documentation. SDK 26.1 remains required;
iOS 17 remains the deployment floor. Native controls retain guarded glass,
opaque data surfaces and accessibility alternatives from the preceding pass.

AGENT and CHANGELOG were read before edits: preserve server-derived identity,
Origin/auth boundaries, workspace v2, all published IDs/units and no credentials
in clients. No web/server runtime or database boundary changed. Draft source
findings are not App Store certification or proof that no bugs remain.

## Per-file disposition

| File | Review / disposition |
| --- | --- |
| [.github/workflows/ios.yml](<../../.github/workflows/ios.yml>) | Run boundary test and watch its path; SDK/runtime gates and missing-runtime reporting retained. Workflow NOT RUN remotely. |
| [AGENT.md](<../../AGENT.md>) | Read in full before edits; append matching Raouf audit entry with actual results and open native gates. |
| [CHANGELOG.md](<../../CHANGELOG.md>) | Read in full before edits; append matching Raouf audit entry with actual results and open native gates. |
| [README.md](<../../README.md>) | Reconcile stale account-staging prose with existing launch record; current 1711 accepted / 1411 selectable and workspace v2 facts. |
| [ios/.gitignore](<../.gitignore>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/App/AppModel.swift](<../FORMA/App/AppModel.swift>) | Compact tested export; rebuild history only when changed; reset clears stale errors; FIFO persistence and session guards retained. |
| [ios/FORMA/App/FORMAApp.swift](<../FORMA/App/FORMAApp.swift>) | Complete read; stable native tab/accessory identity and explicit OS guards retained; no new confirmed defect. |
| [ios/FORMA/DesignSystem/FormaTheme.swift](<../FORMA/DesignSystem/FormaTheme.swift>) | Retained: no new behavioral defect established; pending drafts continue to display unsaved status. Rendered contrast/glass/layout proof requires Mac/device. |
| [ios/FORMA/DesignSystem/GlassControls.swift](<../FORMA/DesignSystem/GlassControls.swift>) | Retained: API guards and content/control layering are consistent with source docs. Rendered glass/keyboard/safe-area behavior unverified on Linux. |
| [ios/FORMA/Features/PlanView.swift](<../FORMA/Features/PlanView.swift>) | Repair invalid per-side range, exact-row draft cleanup, duplicate Save tasks; details retain stored IDs. |
| [ios/FORMA/Features/ProgressView.swift](<../FORMA/Features/ProgressView.swift>) | Resolve journal details against current history after reset; consistent kg × reps; tested load-aware summary. |
| [ios/FORMA/Features/TodayView.swift](<../FORMA/Features/TodayView.swift>) | Complete read; genuine history/schedule, safe active-session state and adaptive layout retained. |
| [ios/FORMA/Features/WorkoutView.swift](<../FORMA/Features/WorkoutView.swift>) | Freeze submitted drafts/notes; acknowledge exact values; retain late editable drafts; captured session/entry IDs; correct duplicate previous set and loaded timed-distance fields. |
| [ios/FORMA/Features/YouView.swift](<../FORMA/Features/YouView.swift>) | ISO Sydney filename; release export snapshot after completion/cancellation; profile protection retained. |
| [ios/FORMA/Info.plist](<../FORMA/Info.plist>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json](<../FORMA/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/Assets.xcassets/AppIcon.appiconset/app-icon.png](<../FORMA/Resources/Assets.xcassets/AppIcon.appiconset/app-icon.png>) | Retain original asset; no image edits |
| [ios/FORMA/Resources/Assets.xcassets/Contents.json](<../FORMA/Resources/Assets.xcassets/Contents.json>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/Contents.json](<../FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/Contents.json>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/training-editorial.png](<../design/training-editorial-source.png>) | Retain original asset; no image edits |
| [ios/FORMA/Resources/PrivacyInfo.xcprivacy](<../FORMA/Resources/PrivacyInfo.xcprivacy>) | No new collection/permission introduced; final required-reason/archive audit remains unrun |
| [ios/FORMA/Resources/README.md](<../FORMA/Resources/README.md>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/catalog.json](<../FORMA/Resources/catalog.json>) | All 1,711 records and 1,411 selectable mappings match authoritative source. |
| [ios/FORMA/Resources/catalogue-notices.json](<../FORMA/Resources/catalogue-notices.json>) | All 1,711 per-entry notices match authoritative source. |
| [ios/FORMA/Resources/legal.json](<../FORMA/Resources/legal.json>) | Retain truthful local guest scope; legal/final archive gates remain open |
| [ios/FORMA/Resources/native-privacy.md](<../FORMA/Resources/native-privacy.md>) | Retain; no new concrete defect established in this file |
| [ios/FORMA/Resources/resource-manifest.json](<../FORMA/Resources/resource-manifest.json>) | All 21 source hashes match; six deterministic outputs reproduce. |
| [ios/FORMA/Resources/seed-workspace.json](<../FORMA/Resources/seed-workspace.json>) | Retain genuine empty history and validated editable starter routines. |
| [ios/FORMAUITests/OfflineWorkoutTests.swift](<../FORMAUITests/OfflineWorkoutTests.swift>) | Eight authored journeys; adds invalid-draft correction, notes and stale-detail reset checks. NOT RUN without Xcode. |
| [ios/Fixtures/parity.json](<../Fixtures/parity.json>) | All 12 synthetic golden cases checked record by record against both domains. |
| [ios/Fixtures/validation-boundaries.json](<../Fixtures/validation-boundaries.json>) | All 38 synthetic acceptance/rejection records checked independently by Swift and strict web validation. |
| [ios/Package.swift](<../Package.swift>) | Retain; no new concrete defect established in this file |
| [ios/README.md](<../README.md>) | Complete read; correct SDK 26.1, deployment 17, guest-only scope and reproduction instructions retained. |
| [ios/Sources/CSQLite/module.modulemap](<../Sources/CSQLite/module.modulemap>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/CSQLite/shim.h](<../Sources/CSQLite/shim.h>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/FORMAContractProbe/main.swift](<../Sources/FORMAContractProbe/main.swift>) | Retain synthetic per-ID start/complete/finish probe; rerun actual Swift output through the strengthened checker. |
| [ios/Sources/FORMACore/DraftAcknowledgement.swift](<../Sources/FORMACore/DraftAcknowledgement.swift>) | Tested exact-value acknowledgement retains newer edits and new keys across awaited saves. |
| [ios/Sources/FORMACore/ExerciseSearch.swift](<../Sources/FORMACore/ExerciseSearch.swift>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/FORMACore/LastCompletedSet.swift](<../Sources/FORMACore/LastCompletedSet.swift>) | Tested newest completed occurrence across all duplicate entries, skipping unfinished/excluded sessions. |
| [ios/Sources/FORMACore/MeasurementDraft.swift](<../Sources/FORMACore/MeasurementDraft.swift>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/FORMACore/MeasurementNumberInput.swift](<../Sources/FORMACore/MeasurementNumberInput.swift>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/FORMACore/MeasurementText.swift](<../Sources/FORMACore/MeasurementText.swift>) | Tested summary preserves all measurement units, historical loads, unequal sides and legacy plank. |
| [ios/Sources/FORMACore/Models.swift](<../Sources/FORMACore/Models.swift>) | Retain full version 2 Codable identities, explicit active null and optional programming fields. |
| [ios/Sources/FORMACore/SerializedMutationGate.swift](<../Sources/FORMACore/SerializedMutationGate.swift>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/Sources/FORMACore/WorkoutEngine.swift](<../Sources/FORMACore/WorkoutEngine.swift>) | Strict positive optional routine targets, UTC/calendar completion dates and active/history field separation; existing units/bounds preserved. |
| [ios/Sources/FORMACore/WorkspaceExport.swift](<../Sources/FORMACore/WorkspaceExport.swift>) | Tested compact canonical JSON fits the existing 20 MiB budget and round-trips maximum supported sets. |
| [ios/Sources/FORMACore/WorkspaceStore.swift](<../Sources/FORMACore/WorkspaceStore.swift>) | Deduplicate identical corrupt recovery originals without deleting distinct originals or overwriting corruption. |
| [ios/Tests/FORMACoreTests/DraftAcknowledgementTests.swift](<../Tests/FORMACoreTests/DraftAcknowledgementTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/Tests/FORMACoreTests/ExerciseSearchTests.swift](<../Tests/FORMACoreTests/ExerciseSearchTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/Tests/FORMACoreTests/GoldenParityTests.swift](<../Tests/FORMACoreTests/GoldenParityTests.swift>) | Retain all 12 generated golden workspaces in the passing core suite. |
| [ios/Tests/FORMACoreTests/LastCompletedSetTests.swift](<../Tests/FORMACoreTests/LastCompletedSetTests.swift>) | Covers unfinished first duplicate, later completed duplicate precedence, last done set, excluded session, no completed result and unknown exercise. |
| [ios/Tests/FORMACoreTests/MeasurementDraftTests.swift](<../Tests/FORMACoreTests/MeasurementDraftTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/Tests/FORMACoreTests/MeasurementNumberInputTests.swift](<../Tests/FORMACoreTests/MeasurementNumberInputTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/Tests/FORMACoreTests/MeasurementTextTests.swift](<../Tests/FORMACoreTests/MeasurementTextTests.swift>) | Seven meaningful metric/locale/history regressions. Timed-distance load omission reproduced RED, then GREEN. |
| [ios/Tests/FORMACoreTests/SerializedMutationGateTests.swift](<../Tests/FORMACoreTests/SerializedMutationGateTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/Tests/FORMACoreTests/ValidationBoundaryTests.swift](<../Tests/FORMACoreTests/ValidationBoundaryTests.swift>) | Three regression groups exercise all 38 shared boundary records; RED before validation repair, GREEN afterwards. |
| [ios/Tests/FORMACoreTests/WorkoutEngineTests.swift](<../Tests/FORMACoreTests/WorkoutEngineTests.swift>) | Complete read; retain metric/rest/finish/validation regressions in the passing suite. |
| [ios/Tests/FORMACoreTests/WorkspaceExportTests.swift](<../Tests/FORMACoreTests/WorkspaceExportTests.swift>) | 150,000-set exact round trip stays within the existing backup byte limit. |
| [ios/Tests/FORMACoreTests/WorkspaceStoreTests.swift](<../Tests/FORMACoreTests/WorkspaceStoreTests.swift>) | Complete read; domain, measurement and persistence regressions retained and passing. |
| [ios/design/app-icon.svg](<../design/app-icon.svg>) | Retain; no new concrete defect established in this file |
| [ios/design/artwork-provenance.md](<../design/artwork-provenance.md>) | Retain; no new concrete defect established in this file |
| [ios/design/asset-checksums.json](<../design/asset-checksums.json>) | All three durable asset hashes match; original PNG bytes retained. |
| [ios/design/build-icon.py](<../design/build-icon.py>) | Retain; current icon reproduction passes |
| [ios/docs/app-review-matrix.md](<../docs/app-review-matrix.md>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/docs/apple-design-2026.md](<../docs/apple-design-2026.md>) | 62 official text/API/session sources and three reference images; availability, retrieval hashes and living-doc limits explicit. |
| [ios/docs/baseline-evidence.md](<../docs/baseline-evidence.md>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/docs/implementation-plan.md](<../docs/implementation-plan.md>) | Complete read; retain verified contract, configuration or evidence boundaries. |
| [ios/docs/privacy-inventory.md](<../docs/privacy-inventory.md>) | Current direct required-reason lists checked; no reason invented for plain size/type keys; final archive audit remains open. |
| [ios/docs/verification.md](<../docs/verification.md>) | Preserve previous milestones; record fresh 62/134/1711 audit results and explicit unrun native gates. |
| [ios/project.yml](<../project.yml>) | Retain; no new concrete defect established in this file |
| [scripts/build-ios-resources.mjs](<../../scripts/build-ios-resources.mjs>) | Retain; no new concrete defect established in this file |
| [scripts/check-ios-contracts.mjs](<../../scripts/check-ios-contracts.mjs>) | Independently compare every default measurement/target/completion; reject seven schema-valid corruptions. |
| [src/exerciseLoad.js](<../../src/exerciseLoad.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [src/exerciseMetrics.js](<../../src/exerciseMetrics.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [src/routineProgramming.js](<../../src/routineProgramming.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [src/storage.js](<../../src/storage.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [src/timedHolds.js](<../../src/timedHolds.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [src/workoutSession.js](<../../src/workoutSession.js>) | Complete read; shared contract boundary probes only; published source and units unchanged. |
| [unit/ios-resources.test.js](<../../unit/ios-resources.test.js>) | 14 passing cases, including exhaustive 1711 controls and independent unit/completion corruption rejection. |
| [unit/ios-validation-boundaries.test.js](<../../unit/ios-validation-boundaries.test.js>) | Three passing groups check all 38 shared boundary records against authoritative strict web schema. |
| [ios/docs/native-design-review.md](<native-design-review.md>) | Read back; complete inventory/JSON/local-link validation; no self-referential hash. |
| [ios/docs/native-file-review.json](<native-file-review.json>) | Read back; complete inventory/JSON/local-link validation; no self-referential hash. |

## Fresh verification and remaining gates

- **62/62 Swift core tests**, **134/134 JavaScript tests**, **1,711/1,711 fresh
  actual Swift exports** checked against strict web validation and independent
  measurements/defaults/completion.
- **38 shared boundary records** checked by both implementations. A session-only
  422-input probe found all 168 native-accepted canonical outputs web-valid;
  three stronger native whitespace-name rejections remain intentional. Arbitrary
  web import and account sync are separate follow-on work.
- Six resources and icon pixels/hashes reproduce; original PNG bytes retained.
  Lint, types, formatting, docs, web build, source syntax and config parsing pass.
- **Eight authored XCUITest journeys remain unrun.** Linux cannot establish
  SwiftUI SDK compilation, native rendering, keyboard/VoiceOver behavior,
  device storage protection/interruption behavior, frame time or energy use.
- Xcode, simulator/device testing, archive privacy/legal/rights/signing and final
  Store review remain open. No push, deployment, TestFlight or App Store action.

See [verification](verification.md) for commands, observed results and the
unchanged readiness scorecard. Source review and Linux tests support the repairs
within the evidence above; they do not establish native visual sign-off.
