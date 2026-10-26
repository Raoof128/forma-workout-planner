# Native file-by-file audit, 26 October 2026

Scope: all 76 files added or changed by `57d685a` (`git diff --name-only main...work`),
read in full or, for generated JSON, validated programmatically. Host: macOS with
Xcode 27.1, Swift 6.4, iOS 27.1 and watchOS 27.0 SDKs. **No iPhone simulator
runtime was installed** (about 8 GB, with 9.6 GB free), so the eight UI journeys
were compiled but not run.

This was the first time the app was compiled with Xcode. Earlier evidence came
from Linux, where SwiftUI cannot build.

## Defects fixed

| # | File | Defect | Fix |
| --- | --- | --- | --- |
| 1 | `FORMA/Features/PlanView.swift:518` | **The app did not compile.** `Section("Targets") { } footer: { }` is not a SwiftUI initializer: a title string cannot be combined with a footer. | `Section { } header: { Text("Targets") } footer: { }` |
| 2 | `Sources/FORMACore/WorkoutEngine.swift` | Starting a workout checked only `reps <= 50` for per-side rep rows. `main` now rejects such a row when `max(reps, repsMax) > 50` (`perSideTargetError`, `d770a6c`), so a 40–60 per-side range started natively but is refused on the web. | Native start checks `max(reps, repsMax ?? 0)`. New test `testPerSideRepRangeAboveFiftyCannotStartAWorkout`. |
| 3 | `FORMA/App/FORMAApp.swift`, `WorkoutView.swift` | "Keep the feeling." set `receipt = nil` in the same update that dismissed the full-screen cover, so the receipt re-rendered as an empty screen while it slid away. | The cover's `onDismiss` clears the receipt. |
| 4 | `YouView.swift`, `PlanView.swift`, `WorkoutView.swift` | A failed profile, routine or notes save was shown inline but left in `model.errorMessage`. The root alert cannot present over a sheet or cover, so the same error was replayed as a stale "Couldn't save this change" alert once it closed. | Clear the message after it is shown inline, and on a successful "Save & close". |
| 5 | `FORMAUITests/OfflineWorkoutTests.swift` | Three journeys queried `app.buttons["finish-confirm"]`, an identifier set on a SwiftUI alert button. SwiftUI does not pass identifiers through to alert actions, so those journeys would time out. | Query `app.alerts.buttons["Finish workout"]`, the pattern the delete journey already uses. Not run here (no runtime). |

## Performance improvements

| File | Before | After |
| --- | --- | --- |
| `FORMA/App/AppModel.swift` (`TrainingDate`) | Two `ISO8601DateFormatter`s and a `Calendar` allocated **per call**. History rebuilds call it once per workout (up to 10,000), and journal rows and chart labels call it in view bodies. | Formatters and the calendar are created once on the main actor; label formatters are cached per template. Fractional-second dates, which native finishes always write, are parsed first. |
| `FORMA/App/AppModel.swift` (`exercise(_:)`) | Linear scan of 1,711 catalogue rows per lookup, called per row in plan, history and workout views. | Dictionary index rebuilt when the catalogue changes. |
| `Sources/FORMACore/ExerciseSearch.swift` | Folded every exercise's indexed text even for an empty query: 1,411 Unicode folds on each library render. | Early return for an empty query; results are unchanged. |

## Files reviewed with no defect

FORMACore `Models`, `WorkspaceStore` (transactions roll back on every path,
compare-and-swap revisions, BLOBs bounded before allocation, statements
finalised), `MeasurementDraft`, `MeasurementNumberInput`, `MeasurementText`,
`LastCompletedSet`, `DraftAcknowledgement`, `SerializedMutationGate` (FIFO
hand-off), `WorkspaceExport`, CSQLite and the contract probe. Volume, Epley 1RM,
superset rest (`shouldRest`), `restRemaining` and the Monday-first weekday index
match the web code. All twelve test files make real assertions; every fixture
record is consumed (12 parity cases and 38 boundary records). Theme and glass layer
have opaque fallbacks for Reduce Transparency and Increase Contrast. Stepper ranges
cannot trap. `Info.plist`, `project.yml`, asset catalogs (1024² RGB icon,
1536×1024 art) and the privacy manifest are valid: the app calls no required-reason
API directly and stores preferences in JSON, not `UserDefaults`. The generator,
checker, unit tests, CI workflow, resources, design tooling and docs are consistent.

## Not changed, by decision

- `ITSAppUsesNonExemptEncryption` was not added. `app-review-matrix.md` leaves the
  export-compliance assessment to the owner, and setting the key would make that
  declaration.
- `native-file-review.json` still lists the 23 October hashes. No test enforces
  it; this report supersedes it for the files above.
- Native had no hold timer, unlike the web since PR #20. It was added later
  the same day (`HoldTimer.swift`, `WorkoutView`).
- The Native iOS workflow has never run remotely: it exists only on `work`, which
  has no pull request. `runs-on: macos-15` should be confirmed to provide Xcode
  26.1+ on its first run.

## Verification

| Check | Result |
| --- | --- |
| `swift test` (ios/) | **63 passed, 0 failed** (62 before + 1 new) |
| `swift run -c release FORMAContractProbe .. out.json` + `check-ios-contracts.mjs` | **1711/1711** Swift-generated workouts pass strict web validation |
| `xcodebuild build-for-testing`, Debug, iOS Simulator SDK 27.1 | **Succeeded**, no Swift warnings (app + UI test bundle) |
| `xcodebuild build`, Release | **Succeeded**, no Swift warnings |
| `swift-format lint` on changed Swift files | Clean |
| `node scripts/build-ios-resources.mjs` | Regenerates with no diff; manifest source hashes match this branch |
| `npm run test:unit` | **134/134** |
| `npm run lint`, `format:check`, `typecheck`, `docs:check` | Pass |
| XCUITest journeys | **Not run**: no simulator runtime installed |

## Apple Watch check against 2026 sources

*Later the same day the Watch companion and the native hold timer were added;
see [Apple Watch workouts](apple-watch.md). The check below describes the state
before that.* There was **no Apple Watch code** in this app or repository: no watchOS target,
WatchConnectivity, HealthKit entitlement or Info.plist purpose strings. The Watch
work is the requirements matrix on `audit/apple-watch-readiness-2026-10-26`
(`APPLE_WATCH_REQUIREMENTS.md`, AP01–AP37). Its Apple claims were checked against
the installed iOS 27.1 / watchOS 27.0 SDK headers and Apple's live pages:

| Claim | Evidence | Verdict |
| --- | --- | --- |
| AP14 `getEarliestAuthorizedSampleDate` is iOS/watchOS 27 | `HKHealthStore.h`: `API_AVAILABLE(ios(27.0), watchos(27.0), …)` | Correct |
| Recovery/collection APIs are iOS 26 / watchOS 5, not iOS 17 | `recoverActiveWorkoutSession`, `typesToCollect`, `HKLiveWorkoutBuilder`, `HKLiveWorkoutDataSource`: `ios(26.0), watchos(5.0)` | Correct |
| AP18/AP19 mirroring is watchOS 10 / iOS 17 | `startMirroringToCompanionDevice` `watchos(10.0)`, unavailable on iOS; `workoutSessionMirroringStartHandler` `ios(17.0)` | Correct |
| AP17 `startWatchApp` is iOS-only | `ios(10.0)`, `API_UNAVAILABLE(watchos)`, async name `startWatchApp(toHandle:)` | Correct |
| AP23 nil workout and nil error can be a locked-device success | Header: "If both workout and error are nil then finishing the workout succeeded but the workout sample is not available because the device is locked." | Correct |
| AP29 `WKExtension`/`WKExtensionDelegate` deprecated | `WK_DEPRECATED_WITH_REPLACEMENT(2.0, 9.2, "WKApplication")` | Correct |
| AP30 workout zones are OS 27 | `HKLiveWorkoutZoneUpdate`: `ios(27.0), watchos(27.0)`; WWDC26 session 207 | Correct |
| AP27 SDK floor | Upcoming requirements: "Since April 28, 2026", Xcode 26+ and watchOS 26 SDK | Correct |
| AP28 arm64 | Apple News, 22 July 2025: "Beginning April 2026, watchOS apps … must also include 64-bit support" | Correct |

Corrections and additions for that matrix:

1. Its current-state column predates this app. `work` now has an iOS 17 Xcode
   project (it builds) and a macOS workflow (never run), so AP03 and AP27 are
   **partial** (iOS side only; still no watchOS target). AP15 remains missing
   natively: the app's rest timer is timestamp-based like the web's.
2. Because this app targets **iOS 17**, every phone-side `HKWorkoutSession`
   primary, `HKLiveWorkoutBuilder` or recovery call needs `if #available(iOS 26, *)`.
   Only the mirroring handler works from iOS 17.
3. Requirement added since: "Since September 9, 2026", iOS uploads must target
   iOS 13 or later. The app's iOS 17 target already satisfies it.
4. Hardware-test risk: an unconfirmed developer-forum report (FB24834050) says
   watchOS 27 workout sessions record almost no heart-rate samples on Series 10.
   Treat heart-rate collection on Ultra 2 as unverified until tested on a device.
