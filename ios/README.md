# FORMA for iPhone

A native SwiftUI app for **offline guest training and optional FORMA accounts**,
with an iOS 17 deployment target. It follows the uploaded master plan and motion research,
reconciled against the current web app's version 2 data model. This is not an App
Store release or a claim of Apple approval.

The native interface lives in `FORMA/`; the independently testable domain and
SQLite package live in `Sources/`. Generated catalogue, seed and legal snapshots
come from the current JavaScript implementation, rather than the older counts and
version-one examples in the plans.

## Run on a Mac

Use Xcode **26.1 or later**, the **iOS 26.1 or later SDK**, an installed iPhone
simulator and XcodeGen 2.44.1 or later. The SDK floor compiles the availability-gated
conditional tab accessory; the supported-device deployment target remains iOS 17.
From the repository root:

```sh
npm ci
node scripts/build-ios-resources.mjs
cd ios
swift test
xcodegen generate
open FORMA.xcodeproj
```

Select the `FORMA` scheme and an installed iPhone simulator, then Run. The project
uses the local `FORMACore` and independent `FORMASurfaces` packages. `dev.raoufabedini.forma` is a provisional bundle
identifier for development; confirm ownership and choose the final identifier
before signing. The project keeps the existing development team `3L5A4R7JNY`; no certificate,
production credential or distribution profile is checked in. Device signing
requires that team’s App Group assignment for both the app and widget extension.

To run the native UI suite, choose an installed iPhone simulator destination:

```sh
xcodebuild test -project FORMA.xcodeproj -scheme FORMA \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=3L5A4R7JNY
```

Replace the example device name with a simulator actually installed in Xcode.
The hosted account tests exercise Keychain storage, so the simulator app is
signed ad hoc (`-`); this does not need a signing certificate or a provisioning
profile. Disabling signing causes the Keychain fixture writes to fail.
The CI workflow requires an iOS 26.1+ primary simulator and separately runs iOS 17
compatibility and iOS 26.0 fallback journeys when those runtimes are installed.
Missing optional runtimes are reported as **not run**, never as passes. Generated Xcode
projects are reproducible outputs; review `project.yml` as their source.

## Apple Watch

The iPhone app embeds a watchOS 10+ companion (`FORMAWatch/`). Starting a workout
checks for a paired Watch; when one is ready, the workout begins when Start is
pressed on the Watch, which records heart rate and energy to Apple Health and
mirrors the session to the iPhone. See [Apple Watch workouts](docs/apple-watch.md).
Run the `FORMAWatch` scheme on a paired Watch simulator or device; HealthKit
sensing and Watch-to-iPhone mirroring need physical devices.

## Home Screen and Lock Screen widgets

The app embeds `FORMAWidgets.appex`. In **You → Training at a glance**, enable
**Share training with widgets**, then add FORMA from the system widget gallery.
Small, medium and large Home Screen layouts and circular, rectangular and inline
Lock Screen layouts are supported. Edit the widget to choose Next session or This week.
Tap View routine to review it in the app; Resume opens the current saved workout.
Widgets do not start workouts, log sets, run account requests or read Health.

Sharing starts off for each service/owner training space. The app alone writes an
atomic, versioned, minimal snapshot into `group.dev.raoufabedini.forma`; SQLite,
credentials, notes and full history stay private. Complete protection hides
locked-device content and prevents iPhone-widget mirroring to Mac. Updates are
system scheduled, so removal/reset/revocation can leave a cached view visible
until WidgetKit updates. Remove a widget for immediate screen withdrawal.
Widget links wait for explicit Save/Cancel when an editor/workout has drafts.

The [October frontend/widget audit](docs/audits/frontend-widget-2026-10/CHANGE_SUMMARY_AND_NEXT_GATES.md)
contains current sources, full file ledger, screenshots, tests and remaining device gates.
The shared widget view renderer exports visual evidence separately from real
SpringBoard placement. To verify a built, signed app bundle:

```sh
python3 scripts/check-ios-widget-bundle.py /path/to/FORMA.app
```

This validates embedding, manifest, entitlement declarations, signature and
absence of SQLite/HealthKit widget linkage, plus the workout Live Activity contract
(`NSSupportsLiveActivities`, the widget bundle, local-only requests). It is not a
device-lock/privacy or App Store archive validation. The workout Live Activity
(Lock Screen, Dynamic Island, StandBy, Watch Smart Stack) and its remaining device
gates, and the deferred Watch complications, are in
[the architecture decision](docs/audits/frontend-widget-2026-10/WIDGETKIT_ARCHITECTURE.md).

## Website media and display font

The technique guide shows the website's media offline. Each exercise gets its cell of FORMA's illustration sheets, and 22 exercises also have a demo clip (public domain or CC BY), shown with its credit and licence. Titles use the website's display face, Barlow Condensed Bold, under the SIL Open Font License; its licence is bundled beside it.

- Regenerate after the web media changes: `python3 scripts/build-ios-media.py` (macOS; needs `sips` and fontTools).
- CI runs `python3 scripts/build-ios-media.py --check`. It fails if `ios/FORMA/Media/media.json` drifts from `src/catalog/media.json` or `demos.json`, if a sheet is missing or the wrong size, if a clip differs from its web copy, or if a font file is missing.
- Sheets are the web's 1536×1024 originals, re-encoded as HEIC. That brings 322 MB of PNG down to 15 MB, so nothing needs to be downloaded later. Clips and posters are copied as they are (4.9 MB).
- The app reads `Media/media.json` once and crops a cell off the main thread. A demo shows its poster and plays only when asked: muted, looping, and mixed with any audio already playing.

## Hold timer

Timed holds offer the web's countdown above their sets: adjust the length, start,
pause, end early or cancel. When it ends, it logs the seconds (the legacy plank
logs a rep per 10 seconds) into the next unfinished set and starts rest, as
ticking it would. One physical hold can claim only one save; a failed write keeps
the exact ended duration for Retry save or Cancel timed set. The rules live in `Sources/FORMACore/HoldTimer.swift`.

## Scope and verification boundaries

The [Apple design research](docs/apple-design-2026.md) records the current HIG,
Liquid Glass API availability and WWDC26 sources used in the refinement pass.
The [file review](docs/native-design-review.md) records every native project
file's disposition and the improvements made.

Signed-out training stays local. Optional email/password accounts use the
website's existing account service, with verification, two-step sign-in, account
management and a separate member cache that syncs routines and workouts. Guest
training is brought into an account only through an explicit review and backup.
See [the account review and tab bar report](docs/account-review-and-tab-bar-2026-10-28.md)
for validation and hosted-test boundaries. JSON backup-file import is not yet
implemented; export and importing this phone's guest training are supported.

The app introduces no tracking, advertising, purchases or medical advice. The
Apple Watch companion records workouts into Apple Health (see below); nothing
else uses HealthKit. Server authentication and infrastructure releases remain separate. Guest
progress begins empty; starter routines are editable examples, not past workouts.

The original prototype started on Linux; the October2026 audit uses macOS/Xcode.
Swift package tests can exercise the
domain and SQLite on Linux when a compatible compiler and SQLite development
headers are available. SwiftUI, the app binary, XCUITest, device protection,
VoiceOver, Dynamic Type, sunlight readability, energy use and App Store archive
validation require macOS/Xcode and real devices. A successful package test is not
evidence that the iPhone interface builds or meets those gates.

The UI suite uses the DEBUG-only `--ui-testing` partition and
`--reset-workspace` launch arguments. A production workspace must never be
deleted by a test launch argument. Tests relaunch without reset to check actual
process-interruption recovery.

Before distribution, complete the [App Review matrix](docs/app-review-matrix.md),
review the [privacy inventory](docs/privacy-inventory.md), and record fresh native
build and physical-device evidence. See the [baseline](docs/baseline-evidence.md)
and [implementation plan](docs/implementation-plan.md) for remaining work.

Nothing in this milestone publishes the app, changes production services,
uploads a binary, or creates an App Store Connect record.

## Verify native exports against the web contract

From the repository root, with Swift and Node available:

```sh
node scripts/build-ios-resources.mjs --check
swift test --package-path ios
swift run --package-path ios FORMAContractProbe . /tmp/forma-native-contracts.json
node scripts/check-ios-contracts.mjs /tmp/forma-native-contracts.json
```

The probe is a development executable, not part of the iPhone binary. It starts,
completes and finishes one fictional native workout for every accepted exercise
ID. The final command checks the actual Swift-encoded output through
`src/storage.js` with strict field validation. This establishes the emitted slice's
contract compatibility, not support for arbitrary web imports or account sync.

Numeric edits stay explicitly **unsaved** until a local transaction completes.
The keyboard's Done action, set completion and Save & close persist valid values.
An incomplete numeric draft can be lost on process termination; completed,
acknowledged sets and committed rest state are stored in SQLite. Physical-device
interruption and keyboard tests remain required.

### Published native development checkpoint

The account/navigation and widget audit implementation is committed as
[076e267](https://github.com/Raoof128/forma-workout-planner/commit/076e267c6a4b3b5081348ddbd40cf53e22700ffd) on the pushed
`feat/frontend-widgets-2026-10` branch. See the
[delivery handoff](docs/audits/frontend-widget-2026-10/CHANGE_SUMMARY_AND_NEXT_GATES.md)
for source/visual evidence, the documentation reconciliation and device gates.
This branch has not been merged or submitted to the App Store.
