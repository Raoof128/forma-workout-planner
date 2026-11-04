# Verification commands and outcomes

All commands ran from the existing FORMA checkout unless an isolated temporary Xcode project is specified. No production service, real member login, deployment or Store action was performed.

| Check                                                                                         | Actual result                                                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `swift test --package-path ios` baseline                                                      | 144 FORMACore + 38 FORMASurfaces passed                                                                                                                                                                                        |
| `swift test --package-path ios` after package fixes                                           | 146 FORMACore + 38 FORMASurfaces passed; no failures                                                                                                                                                                           |
| `swift run --package-path ios FORMAContractProbe . /tmp/forma-native-contracts-20261104.json` | 1711 fresh native-generated workouts                                                                                                                                                                                           |
| `node scripts/check-ios-contracts.mjs /tmp/forma-native-contracts-20261104.json`              | All 1711 pass strict web contract                                                                                                                                                                                              |
| `node scripts/build-ios-resources.mjs --check`                                                | Six resources in sync, 1711 accepted/1411 selectable IDs                                                                                                                                                                       |
| `npm run lint`, `npm run format:check`, `npm run typecheck`                                   | Pass                                                                                                                                                                                                                           |
| `npm run docs:check` before new audit documents                                               | Pass; final documentation pass recorded below                                                                                                                                                                                  |
| `npm run test:unit`                                                                           | 151 pass, 0 fail/skip/cancel                                                                                                                                                                                                   |
| `npm run test:worker`                                                                         | 35 pass, 0 fail/skip/cancel                                                                                                                                                                                                    |
| `npm run build`                                                                               | Pass; existing chunk-size/plugin timing warnings retained                                                                                                                                                                      |
| Strict `xcrun swift-format lint --strict` on changed/new Swift                                | 30 files pass at source freeze; later test-only harness edits checked separately                                                                                                                                               |
| Baseline device build-for-testing                                                             | Pass; real signed app/widget/UI/hosted targets; 38.889 s original build duration                                                                                                                                               |
| Baseline full selected device run                                                             | 130 checks: 129 pass, 1 sign-in typing fixture failure; zero skipped. Original failed result retained                                                                                                                          |
| Baseline focused diagnosis                                                                    | ASCII synthetic typing failed; actual x key absent on active layout. Visible-letter fixture then passed on unchanged app                                                                                                       |
| Baseline selected repeated tours                                                              | Three tours pass; requested-Light launch override ignored, so these are dark captures                                                                                                                                          |
| Simulator                                                                                     | Created only a new audit iPhone Duo supported by installed iOS 27.1 runtime; build succeeded, install stalled and tool timed out after 300 s. Only owned install process stopped and owned simulator shut down; no reset/erase |
| Image integrity                                                                               | 190 existing PNG/JPEG files decoded and drawn successfully using native ImageIO/CoreGraphics                                                                                                                                   |

## Native commands

XcodeGen creates the project from the copied spec. Device operations use local Xcode CLI because the enabled XcodeBuildMCP build/test tools expose Simulator workflows. The baseline and final project copies change the bundle prefix, widget App Group, Keychain identity, URL scheme and account endpoint together; the phone-only audit copy excludes embedded Watch installation. Original/iPhone app data is never a fixture. Build inputs and transformations are captured by private temporary manifests.

```sh
xcodebuild build-for-testing -project <isolated-ios>/FORMA.xcodeproj \
  -scheme FORMA -configuration Debug -destination 'platform=iOS,id=<connected-audit-device>' \
  -derivedDataPath <audit-derived-data> -resultBundlePath <new-build-result>.xcresult \
  -allowProvisioningUpdates
xcodebuild test-without-building -project <isolated-ios>/FORMA.xcodeproj \
  -scheme FORMA -configuration Debug -destination 'platform=iOS,id=<connected-audit-device>' \
  -derivedDataPath <audit-derived-data> -resultBundlePath <new-test-result>.xcresult \
  -parallel-testing-enabled NO
```

The first baseline run selected all hosted tests and ten named UI cases. Final physical suites classify the keyboard-settings signup and Home Screen installation fixtures as intentionally skipped on hardware; their full Simulator assertions remain. Skips/unrun/cancelled tests are never passes.

Final signed build and widget validation passed. Physical suite: 166 tests, 164 passed, 2 intentional hardware skips, 0 failures (139 hosted + 25 supported UI). Final Light tours: 3/3 pass. Ordinary full app/Watch/widget generic compile passed unsigned with no installation. Thirty-two matched screenshot pairs are recorded in SCREENSHOT_COMPARISON.json. Four text-field frame warnings were observed; unchanged baseline decimal entry reproduces the warning. Launch metric is incomplete. iOS 17 runtime, physical Watch, live nonproduction account transactions, signed distribution archive and App Review remain unverified. Database/server/browser suites belong to the subsequent website audit and are not inferred from these native outcomes.

## Owner-requested commit checkpoint

The owner explicitly authorized the source checkpoint commit/push at 3c27308 before the website audit. It recorded the then-pending UI status truthfully. The follow-up now records final physical results: 139 hosted + 25 supported UI passed, 2 explicit hardware skips, zero failures; Light tours 3/3 pass; matched captures and signed bundle/ordinary Watch compile checks completed. No merge, deployment or Store submission occurred.

Website discovery found installed Vite 8.3.4/Motion 14.3.0 differ from the current lockfile pins 8.3.5/14.6.0. The recorded npm outcomes used that existing install; clean-install reproducibility and locked frontend browser validation are assigned to the subsequent website audit. This does not establish a pinned frontend release build.

## Final native evidence

See [VERIFICATION_RESULTS.json](VERIFICATION_RESULTS.json) for machine-readable outcomes. The two hardware skips are manual-password signup and Home Screen gallery; their Simulator assertions are unchanged. No Simulator UI run passed. The launch metric warning and baseline-reproduced keyboard frame warning remain visible in reports.

The final Light suite and generic Watch build passed after the source checkpoint. Raw xcresult/device diagnostics remain private; curated synthetic screenshots and metric arrays are durable. The final documentation/link check is owned by the integrating reviewer and is not inferred from test success.
