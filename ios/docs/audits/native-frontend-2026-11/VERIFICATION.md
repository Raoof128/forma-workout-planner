# Verification commands and outcomes

All commands ran from the existing FORMA checkout unless an isolated temporary Xcode project is specified. No production service, real member login, deployment or Store action was performed.

| Check | Actual result |
| --- | --- |
| `swift test --package-path ios` baseline | 144 FORMACore + 38 FORMASurfaces passed |
| `swift test --package-path ios` after package fixes | 146 FORMACore + 38 FORMASurfaces passed; no failures |
| `swift run --package-path ios FORMAContractProbe . /tmp/forma-native-contracts-20261104.json` | 1711 fresh native-generated workouts |
| `node scripts/check-ios-contracts.mjs /tmp/forma-native-contracts-20261104.json` | All 1711 pass strict web contract |
| `node scripts/build-ios-resources.mjs --check` | Six resources in sync, 1711 accepted/1411 selectable IDs |
| `npm run lint`, `npm run format:check`, `npm run typecheck` | Pass |
| `npm run docs:check` before new audit documents | Pass; final documentation pass recorded below |
| `npm run test:unit` | 151 pass, 0 fail/skip/cancel |
| `npm run test:worker` | 35 pass, 0 fail/skip/cancel |
| `npm run build` | Pass; existing chunk-size/plugin timing warnings retained |
| Strict `xcrun swift-format lint --strict` on changed/new Swift | 30 files pass at source freeze; later test-only harness edits checked separately |
| Baseline device build-for-testing | Pass; real signed app/widget/UI/hosted targets; 38.889 s original build duration |
| Baseline full selected device run | 130 checks: 129 pass, 1 sign-in typing fixture failure; zero skipped. Original failed result retained |
| Baseline focused diagnosis | ASCII synthetic typing failed; actual x key absent on active layout. Visible-letter fixture then passed on unchanged app |
| Baseline selected repeated tours | Three tours pass; requested-Light launch override ignored, so these are dark captures |
| Simulator | Created only a new audit iPhone Duo supported by installed iOS 27.1 runtime; build succeeded, install stalled and tool timed out after 300 s. Only owned install process stopped and owned simulator shut down; no reset/erase |
| Image integrity | 190 existing PNG/JPEG files decoded and drawn successfully using native ImageIO/CoreGraphics |

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

Final source build, supported physical suite, screenshot comparison, bundle validation and documentation results are pending at this draft checkpoint. PostgreSQL/server/account/browser suites, remote CI, iOS 17, physical Watch, signed distribution archive and App Review remain unrun; database suites were not invoked without isolated infrastructure and were not reported skipped/passed.

## Owner-requested commit checkpoint

The owner explicitly requested committing and pushing all current changes before the website audit. The final isolated app and test bundle build, signed bundle validator and all **139 final hosted iPhone tests** passed. The full **27-case UI suite is in progress**, after the owner unlocked the waiting phone; it is not yet reported as passed. Final matching appearance captures, performance comparison and remaining outcomes will be recorded in a follow-up. No merge, deployment or Store submission is authorized by that commit/push request.

Website discovery found installed Vite 8.3.4/Motion 14.3.0 differ from the current lockfile pins 8.3.5/14.6.0. The recorded npm outcomes used that existing install; clean-install reproducibility and locked frontend browser validation are assigned to the subsequent website audit. This does not establish a pinned frontend release build.
