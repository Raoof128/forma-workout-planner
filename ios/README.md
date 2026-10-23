# FORMA for iPhone

A native SwiftUI development milestone for **offline guest training**, with an
iOS 17 deployment target. It follows the uploaded master plan and motion research,
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
uses the local `FORMACore` package. `dev.raoufabedini.forma` is a provisional bundle
identifier for development; confirm ownership and choose the final identifier
before signing. No development team, certificate, production credential or
distribution entitlement is included.

To run the native UI suite, choose an installed iPhone simulator destination:

```sh
xcodebuild test -project FORMA.xcodeproj -scheme FORMA \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

Replace the example device name with a simulator actually installed in Xcode.
The CI workflow requires an iOS 26.1+ primary simulator and separately runs iOS 17
compatibility and iOS 26.0 fallback journeys when those runtimes are installed.
Missing optional runtimes are reported as **not run**, never as passes. Generated Xcode
projects are reproducible outputs; review `project.yml` as their source.

## Scope and verification boundaries

The [Apple design research](docs/apple-design-2026.md) records the current HIG,
Liquid Glass API availability and WWDC26 sources used in the refinement pass.
The [file review](docs/native-design-review.md) records every native project
file's disposition and the improvements made.

The first slice is local guest use. It introduces no native account adapter,
tracking, advertising, HealthKit, purchases or medical advice. Web account routes,
server authentication and production infrastructure remain separate. Guest
progress begins empty; starter routines are editable examples, not past workouts.

The host used to start this work is Linux. Swift package tests can exercise the
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
