# Change summary and next gates

29 October 2026, Australia/Sydney. Implementation is local and uncommitted on `feat/frontend-widgets-2026-10`, based on `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba` plus the preserved, separately authorized dirty account/navigation work. Xcode 27.1 (27A9275), Swift 6.4, macOS 27.0.1 (26A434). Minimum iOS 17 / watchOS 10. No push, merge, production deployment or Store submission occurred.

## What changed

- **Training Instrument composition:** compact decorative photo, solid ink session content, legible condensed hierarchy and an immediate lime Start/Resume. Largest accessibility text and short landscape prioritize that action. The existing custom Liquid Glass tab selection, symbol animation and scroll collapse remain governed by the single motion resolver.
- **Working WidgetKit extension:** small/medium/large Home Screen and circular/rectangular/inline accessories, configurable Next session/This week. Minimal real committed routine/active/week facts, explicit consent off by default for each owner and origin, protected atomic snapshot, strict epoch/ID routes, expiry and nonpersonal empty/private/unavailable/stale states. Extension never opens SQLite, accesses Health/accounts or writes workouts.
- **Trust and interruption repairs:** exact timed-hold failure retry and one-save claiming; store-scoped recovery and explicit cache-removal errors; durable phone-import reservation before upload; current-owner delayed Watch Start; midnight/half-open Sydney weeks; queued deep links preserve workout/routine/profile drafts until explicit closure.
- **Watch source repairs:** recovered-session remirroring, explicit single-flight reconnect, session identity guards, confirmed failed-recording discard and neutral iPhone Health-save status. Physical acceptance remains blocked by pairing.
- **Build/privacy delivery:** embedded signed extension, matching App Group/Complete protection, no SQLite/Health extension linkage, updated disclosures/resource generator, CI bundle validation, meaningful regression tests and dated audit evidence.

No new photo was necessary after inspecting the existing editorial asset. Three feasible directions and the selection rationale are in [DESIGN_SYSTEM_V3](DESIGN_SYSTEM_V3.md). Live Activity and Watch complications are deliberately deferred with code-level lifecycle/data-flow plans in [WIDGETKIT_ARCHITECTURE](WIDGETKIT_ARCHITECTURE.md); no prototype/capability is presented as shipping.

## Verification and evidence

The final integration results are recorded in [TEST_AND_APP_REVIEW_EVIDENCE](TEST_AND_APP_REVIEW_EVIDENCE.md). Final source hashes and 146/146 baseline coverage are in [FILE_LEDGER](FILE_LEDGER.md). The [visual manifest](visual-evidence.json) gives attachment provenance, original dimensions and SHA-256; actual SpringBoard screenshots are separate from direct shared-view renders.

Baseline 138 core tests passed. Current package run passed **141 core + 4 surfaces**; web unit suite passed **151**, including the **17** native-resource/boundary tests (a subset, not additional). Strict validation accepted all **1,711** actual Swift-generated contract cases. The final hosted app run passed **32** tests and the separate actual WidgetKit gallery/install/routine-link journey passed. Dark tour passed all three journeys. The final complete UI repeat passed **24/24** with the gallery already passed separately; dark tours passed **3/3**. Expanded family/state rendering evidence and final installation status are recorded below.

## Use and reproduce

1. Open FORMA → You → Training at a glance and enable sharing for the current guest/member. No sharing is inherited across owners or service origins.
2. Long-press the iPhone Home Screen → Edit → Add Widget → FORMA → Training at a glance. Choose Next session or This week in Edit Widget. Lock Screen customization offers the supported accessories. Their real locked/passcode/Always On behavior remains a hardware acceptance gate.
3. Tap View routine to open its current prescription; this does not start a workout. Saved active links resume only the matching current-owner workout. A link arriving during an editor waits for Save/Cancel or Save & close.
4. In the checkout: `node scripts/build-ios-resources.mjs --check`, `swift test --package-path ios`, `xcodegen generate --spec ios/project.yml`. Use the installed destination and commands in the test report. The generated project uses the existing development team, not a new identity.

## Prioritized remaining gates

| Priority | Action and acceptance |
|---|---|
| Device verification | Unlock the iPhone and connect it to this Mac by USB. Verify the final installed app launches, add real Home/Lock Screen widgets, test lock/reboot/consent-off/reset/account-exit snapshots. WidgetKit caches/system reload budgets prohibit a promise of instantaneous withdrawal. |
| Watch pairing and Health | Resolve CoreDevice 4000 / RemotePairing 1035 via the unlocked companion USB connection; install the already-built companion. Run permissions denied, disconnect/recover/reconnect, End delivery failure, slow/failed save and explicit discard. Confirm one Health workout per finish and no duplicate retry. No unpair/reset is authorized or attempted. |
| OS/accessibility/appearance | Run iOS 17 and 26 / watchOS 10 floors when available; physical VoiceOver/Voice Control/Switch Control, largest text, high contrast/transparency/motion, keyboard and real Lock Screen/StandBy/tinted/clear/vibrant/Always On contexts. Simulator render evidence is not equivalent. |
| Accounts/deletion | With suitable staging service credentials, perform synthetic real lifecycle/email deletion/session revocation and local cache removal. No live account or production-service pass is claimed by this audit. Keep legacy unscoped recovery JSON until ownership can be reviewed safely. |
| Performance | Release physical-device cold launch, set-save typing, full-catalog search, long history, hold/rest, glass transitions and Watch energy traces. Hosted projection samples prove only their measured scope. No p95/FPS/energy or speedup claim. |
| Distribution | Owner/Apple/legal review of operator/provider eligibility, regions/age/support, content rights, account deletion, privacy answers and final archive manifests. Signed development build is not App Store acceptance. |

Suggested next logical commit after reviewing the complete preserved account baseline: `feat(ios): add private training widgets and harden workout recovery`. Keep the earlier account/navigation scope explicit in the commit description; do not silently label all existing dirty input as this audit's work.

## Exact implementation paths changed from captured native baseline

The list below compares file bytes against the private 146-path native snapshot, so it distinguishes this audit from pre-existing uncommitted account code. Generated report/media paths are individually inventoried in the file ledger and visual manifest. External native-support paths changed in this audit: `.github/workflows/ios.yml`, `scripts/build-ios-resources.mjs`, `scripts/check-ios-widget-bundle.py`, `unit/ios-resources.test.js`, plus the required `AGENT.md` and `CHANGELOG.md` entries.

- `ios/FORMA/Account/AccountPrivacyView.swift`
- `ios/FORMA/Account/AccountProfileView.swift`
- `ios/FORMA/Account/AccountSecurityView.swift`
- `ios/FORMA/Account/PhoneTraining.swift`
- `ios/FORMA/Account/TrainingDataView.swift`
- `ios/FORMA/App/AppModel+Account.swift`
- `ios/FORMA/App/AppModel+WidgetRouting.swift`
- `ios/FORMA/App/AppModel.swift`
- `ios/FORMA/App/FORMAApp.swift`
- `ios/FORMA/App/WatchWorkoutCoordinator.swift`
- `ios/FORMA/App/WidgetSnapshotBridge.swift`
- `ios/FORMA/DesignSystem/WidgetNavigationGuard.swift`
- `ios/FORMA/FORMA.entitlements`
- `ios/FORMA/Features/HoldLogState.swift`
- `ios/FORMA/Features/PlanView.swift`
- `ios/FORMA/Features/StartWorkoutSheet.swift`
- `ios/FORMA/Features/TodayView.swift`
- `ios/FORMA/Features/WorkoutView.swift`
- `ios/FORMA/Features/YouView.swift`
- `ios/FORMA/Info.plist`
- `ios/FORMA/Resources/legal.json`
- `ios/FORMA/Resources/native-privacy.md`
- `ios/FORMA/Resources/resource-manifest.json`
- `ios/FORMAAppTests/HoldLogStateTests.swift`
- `ios/FORMAAppTests/PhoneTrainingLedgerTests.swift`
- `ios/FORMAAppTests/WidgetProjectionPerformanceTests.swift`
- `ios/FORMAAppTests/WidgetProjectionTests.swift`
- `ios/FORMAAppTests/WidgetRenderingTests.swift`
- `ios/FORMAUITests/AccountExperienceTests.swift`
- `ios/FORMAUITests/MotionExperienceTests.swift`
- `ios/FORMAUITests/OfflineWorkoutTests.swift`
- `ios/FORMAUITests/ReviewViewport.swift`
- `ios/FORMAUITests/ScreenshotTourTests.swift`
- `ios/FORMAUITests/TodayLayoutAndWidgetRoutingTests.swift`
- `ios/FORMAUITests/TrainingNavigationTests.swift`
- `ios/FORMAUITests/WidgetGalleryTests.swift`
- `ios/FORMAWatch/WatchViews.swift`
- `ios/FORMAWatch/WorkoutManager.swift`
- `ios/FORMAWidgets/FORMAWidgets.entitlements`
- `ios/FORMAWidgets/Info.plist`
- `ios/FORMAWidgets/PrivacyInfo.xcprivacy`
- `ios/FORMAWidgets/TrainingWidget.swift`
- `ios/Package.swift`
- `ios/README.md`
- `ios/Sources/FORMACore/WorkspaceStore.swift`
- `ios/Sources/FORMASurfaces/SnapshotFileWriter.swift`
- `ios/Sources/FORMASurfaces/TrainingCalendar.swift`
- `ios/Sources/FORMASurfaces/TrainingSnapshot.swift`
- `ios/Sources/FORMASurfaces/WidgetRoute.swift`
- `ios/Tests/FORMACoreTests/WorkspaceStoreTests.swift`
- `ios/Tests/FORMASurfacesTests/TrainingSnapshotTests.swift`
- `ios/WidgetPresentation/TrainingWidgetView.swift`
- `ios/docs/privacy-inventory.md`
- `ios/project.yml`

## Final polish reconciliation

Final visual QA repaired large-text widget clipping with a concise accessibility composition and fixed the Simulator rotation-capture race. The evidence set contains 120 component images, 32 final app/layout images and four actual gallery/Home images, plus nine baseline originals. The signed Release executables exclude test coverage instrumentation; ordinary test assertions remain enabled and coverage can be requested explicitly. The completed 24-case UI result and separately passed gallery remain distinct from the final focused renderer/layout reruns.

The final signed app was reinstalled successfully on the iPhone after the last widget changes. Launch remains blocked while the phone is locked; Watch installation still needs the unlocked companion USB connection. Final executable hashes and the exact install/launch results are in the test evidence report.
