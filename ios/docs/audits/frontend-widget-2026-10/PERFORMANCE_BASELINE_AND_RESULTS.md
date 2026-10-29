# Performance baseline and results

29 October 2026, Australia/Sydney. Measurements below identify their configuration and scope. No frame-rate, battery, startup-speedup or release-device latency claim is made from a package suite duration or source inspection.

## Baseline environment

| Item | Recorded value |
|---|---|
| Source baseline | HEAD `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba`, owner-approved dirty native account/navigation input |
| Working branch | `feat/frontend-widgets-2026-10` |
| Host | macOS 27.0.1 build 26A434 |
| Xcode / Swift / XcodeGen | 27.1 build 27A9275 / Swift 6.4 / 2.46.0 |
| Installed review Simulator | iOS 27, `FORMA Review`, `B84DC3C8-D015-4BB6-9408-E5522F6D0346` |
| Baseline machine load averages | 3.40, 3.65, 3.56 (one/five/fifteen minutes) |
| Deployment support | iOS 17 and watchOS 10; earlier runtimes unavailable locally |
| Physical release profiling | NOT RUN; paired Watch and on-device Instruments gates remain open |

Concurrent development/build work can affect Simulator timing. Record fresh load, thermal/power state, app build configuration and device identity with each final performance run. Compare before/after only when those inputs and the scenario match.

## Executed verification checkpoints

| Command / artifact | Observed result | Interpretation |
|---|---|---|
| Root baseline `swift test --package-path ios`, `/tmp/forma-widget-baseline-core.log` | 138 FORMACore tests, zero failures; core executable elapsed 3.246 s | Current baseline correctness checkpoint. This is whole-suite elapsed time |
| Root changed package run, `/tmp/forma-widget-surfaces-core.log` | 141 FORMACore tests, zero failures; core executable elapsed 1.787 s. Separate FORMASurfaces executable: four tests, zero failures, 0.044 s | Adds three recovery isolation/removal regressions and four shared-snapshot tests. Different suite contents and host scheduling prevent a speedup claim |
| Baseline ScreenshotTour run, `/tmp/forma-widget-baseline-tour.log` | Passed; nine full-resolution attachments exported to `/tmp/forma-widget-before` with manifest | Visual baseline evidence; no animation-hitch or input-latency measurement |
| Reviewer `swift format lint --strict` on scoped recovery source/tests | Passed | Formatting evidence only |
| Python full parity-fixture traversal | All 12 synthetic cases match independent completed sets, load/reps volume, seconds and metres | Deterministic parser correctness evidence; no native runtime latency measurement |

The first targeted reviewer package attempt ran during new-target setup and failed because the FORMASurfacesTests directory was not yet present. It executed no tests; the later successful root package run is the actual checkpoint.

## Projection measurement harness

`FORMAAppTests/WidgetProjectionPerformanceTests.swift` defines one hosted XCTest performance scenario using `XCTClockMetric` and ten measured iterations. The fixture reaches the canonical record limits: 10,000 saved workouts and 200 routines, with one completed set per history item and two sets in the active session. Fixture construction, validation, date formatter construction and correctness assertions run before the measured block. The block invokes only `WidgetSnapshotBridge.project` and stores its result so the work has an observed outcome.

Correctness assertions verify a selected nonarchived routine, three current-week sessions distributed through unsorted history, two trained weekday flags, the weekly goal, active completed/total set counts, canonical revision, unchanged source workspace, exclusion of synthetic notes and valid bounded snapshot roundtrip. The final result must equal the preverified projection. There is no invented timing threshold, flaky speed assertion or pass/fail percentage.

**Execution status:** the hosted Simulator XCTest ran successfully in three recorded checkpoints. Each run measured ten synchronous `project` calls after fixture construction and validation. The samples below are milliseconds, transcribed from the actual XCTest log and summarized by arithmetic mean/range. No matched pre-change projection benchmark exists, so these do not establish a speedup.

| Hosted run / artifact | Samples | Mean | Observed range | Outcome and context |
|---|---|---|---|---|
| `/tmp/forma-widget-focused.log`, log time 00:38 | 10 | 15.854 ms | 15.673–16.200 ms | Performance case passed; all 31 hosted app tests passed. That combined command also had UI failures, so the whole invocation was not green |
| `/tmp/forma-widget-focused-final.log`, log time 00:43 | 10 | 16.318 ms | 16.258–16.374 ms | Performance case and 31 hosted app tests passed; separate focused UI matrix passed five of six |
| `/tmp/forma-widget-all-final.log`, log time 00:54 | 10 | 29.435 ms | 27.418–40.765 ms | Performance case and 31 hosted app tests passed. Later full UI result was 24 executed / five failed, under higher host pressure |

Raw samples (milliseconds):

```text
focused:       15.679 15.674 15.889 16.027 16.200 16.164 15.882 15.679 15.675 15.673
focused-final: 16.374 16.338 16.307 16.278 16.258 16.318 16.343 16.332 16.313 16.316
all-final:     40.765 30.415 27.433 28.417 27.691 29.125 27.418 27.484 28.075 27.528
```

The third set is slower and more variable. Root later observed load near 84 following Watch Simulator startup and shut down two extra Simulators; the CPU/load state was not sampled at every projection iteration. This supports investigating host contention but does not quantitatively attribute every difference to it. No p95, frame-rate, battery, device latency or before/after improvement is claimed from these small and differently loaded samples.

Production projection is now prepared through an `@concurrent` nonisolated task and the shared nonisolated `TrainingCalendar`; it returns to the bridge before the latest-publication check and file writer. This keeps the 10,000-date scan off the input/UI actor. The hosted harness measures the pure projection call itself; task handoff, full widget reload, input latency and extension scheduling are not included. The post-relocation 32-case hosted run passed in `/tmp/forma-widget-widget-complete.log`, including the same projection correctness/performance case; the three earlier sample sets remain explicitly dated measurements, not a matched before/after benchmark.

Run on an installed destination after XcodeGen generation, preserving the XCTest result bundle:

```sh
xcodebuild test -project ios/FORMA.xcodeproj -scheme FORMA \
  -destination 'platform=iOS Simulator,id=B84DC3C8-D015-4BB6-9408-E5522F6D0346' \
  -only-testing:FORMAAppTests/WidgetProjectionPerformanceTests
```

Use the repository's actual signing configuration and supported destination. A Simulator measurement is separately labeled from a signed Release physical-device result. Save the source SHA, fixture shape, `.xcresult`, measurement samples and host context with the final result.

## Release-device Instruments matrix

| Scenario | Required measurement | Current result |
|---|---|---|
| Cold launch / first usable Today | Release launch metric, existing prepare-training-space signpost, main-thread Time Profiler and framework/startup attribution | NOT RUN on physical device |
| Completing a set while another field changes | Commit acknowledgement to visible response, keyboard/focus stability, SwiftUI invalidation, main-actor/concurrency trace | NOT RUN on physical device |
| Full catalogue search and long routine edit | Per-keystroke response, cancellation/debounce behavior, allocations and view updates across approximately 1,700 accepted exercises | NOT RUN on physical device |
| Long-history Progress | Parsed-date aggregation and chart construction at realistic large history; Time Profiler and allocations | NOT RUN on physical device |
| Hold/rest and background/foreground | Timer update frequency, CPU/energy, retained tasks, resumption correctness, no per-frame full-screen redraw | NOT RUN on physical device |
| Tab transition / glass bar | Animation Hitches and SwiftUI trace in light/dark and reduced settings | NOT RUN on physical device |
| Widget projection and bounded read | Hosted projection clock samples, atomic writer/read costs, extension allocation/time trace for available/locked/stale cases | Three hosted ten-sample checkpoints recorded above; physical file/read/reload/allocation trace NOT RUN |
| Watch workout and mirroring | Primary-session recovery/reconnect, live metrics batching, Always On update frequency, battery and Health deduplication | NOT RUN on paired physical hardware |

For each physical run: build Release, install once, set a recorded synthetic scenario, let launch/setup settle, choose a fixed sampling window, record repetitions, save the Instruments trace and inspect hitches/concurrency/allocations rather than relying on perceived smoothness. Use Time Profiler, SwiftUI, Animation Hitches, Swift Concurrency and System Trace as available in the installed Xcode. Root owns any `xctrace` attempt; an attachment/profiling failure must retain its exact error and must not be relabeled a completed device profile. No new build, test, Simulator or Instruments operation was run by this documentation follow-up.

No Live Activity high-frequency update loop is introduced as a performance experiment. Any eventual ActivityKit integration needs a separate saved-state/lifecycle measurement and release gate.

## Loaded UI run and repeat policy

The full UI checkpoint executed 24 tests with five failures. Three have identified source/helper changes (control discovery after scrolling, native search drawer visibility, actual workout-cover dismissal). Two late failures concern Reset visibility and portrait restoration under the severe host-load episode. The logs remain failed evidence until the focused rerun actually passes. Host-load suspicion must not excuse a reproducible application defect or justify weaker persistence assertions. Root will repeat the affected focus, light/dark tour, shared widget renderer and gallery after checking actual CPU settlement; this report records no result from those future runs.

## Final UI repeat

The settled final run `/tmp/forma-widget-regression-complete.log` passed all 24 UI cases. Separate real system-gallery and dark tours passed. At 02:32 the host load was 2.64/3.44/3.71 with 58.48% CPU idle; this is a host context sample, not a per-action latency metric. Earlier failures and load context remain above for reproducibility.

## Executed Simulator Instruments capture

A **10.707901-second Debug idle-foreground Simulator** Time Profiler recording completed at 02:35:56–02:36:06, with **477 time-profile rows**. Both TOC and sample exports parsed successfully. Exact command/configuration/limits are in [performance-evidence.json](performance-evidence.json); local trace `/tmp/forma-widget-idle-simulator.trace`, log `/tmp/forma-widget-profile.log`. Instruments warned that one configured table has no known input source. This does not negate the exported sample rows, but is retained as a collection limitation. No physical Release scenario, matched baseline, latency percentile, energy result or SwiftUI invalidation conclusion is inferred from this short idle capture.

The final Release audit found scheme-wide coverage instrumenting app and Swift-package dependencies. Coverage is now opt-in (`xcodebuild test -enableCodeCoverage YES`), with Release coverage settings disabled. Mach-O load commands for the signed iPhone, widget and Watch executables were checked and contain no `__llvm_prf*` sections. No performance percentage is claimed from removing instrumentation. See Apple's current [build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference).
