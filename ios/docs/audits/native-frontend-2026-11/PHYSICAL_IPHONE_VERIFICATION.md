# Physical iPhone Verification

The owner confirmed that the connected iPhone Air reported as Raoof's iPhone is the authorized Raouf iPhone Air. Read-only checks confirmed pairing/trust, Developer Mode already enabled and iOS 27.2 compatibility with Xcode 27.2. Locked states were reported and operations waited for the owner to unlock. No security, Auto-Lock, AutoFill, keyboard, accessibility or global appearance setting was changed.

The separately signed FORMA Audit app uses dev.raoufabedini.forma.audit202611, a distinct App Group, Keychain service/default access group and forma-audit URL scheme, a reserved invalid account origin and synthetic data. No Watch companion is embedded in the phone audit build. Original FORMA applications, training stores, accounts and Health records were not used as fixtures, reset or overwritten.

| Check                                              | Actual result                                                                                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Baseline signed build-for-testing                  | Passed; original duration 38.889 seconds                                                                                        |
| Final signed app, widget, hosted and UI test build | Passed; strict deep signature and isolated identities verified                                                                  |
| Final signed widget bundle validator               | Passed; six families, local ActivityKit bundle, protected group and FileTimestamp/C617.1 manifest verified                      |
| Final physical hosted tests                        | 139 passed                                                                                                                      |
| Final physical UI suite                            | 27 executed: 25 passed, 2 explicitly skipped, 0 failures                                                                        |
| Final Light screenshot tours                       | 3 passed, 0 failed/skipped; no runtime warnings                                                                                 |
| Ordinary full iPhone/Watch/widget build            | Passed, 36.346 seconds; unsigned, generic device destination, no installation                                                   |
| Compatibility in ordinary built metadata           | iOS 17, watchOS 10, widget iOS 17 retained                                                                                      |
| Simulator execution                                | No UI journey completed: new compatible iPhone Duo built but install stalled; owned simulator was shut down without erase/reset |

The two hardware skips preserve the full Simulator fixtures: manual-password signup changes AutoFill settings, and system widget gallery edits the Home Screen. Their skips are recorded separately from passes. Real phone journeys choose the actual Start on iPhone only action and never start a Watch/Health workout.

## Screenshots and comparison

There are 32 matched state/appearance pairs, 64 metadata-sanitized PNGs: 17 Dark before/after and 15 Light before/after. [Pair manifest](SCREENSHOT_COMPARISON.json), [before Dark](screenshots/before-dark/contact-sheet.jpg), [after Dark](screenshots/after-dark/contact-sheet.jpg), [before Light](screenshots/before-light/contact-sheet.jpg) and [after Light](screenshots/after-light/contact-sheet.jpg) provide the evidence. Pixel dimensions, EXIF display orientation, SHA-256 and originating synthetic test are recorded in each folder's manifest. Raw device identifiers, logs and diagnostic archives remain private and outside this repository.

Both actual Light captures use the audit app's existing Appearance picker. The earlier process-default request yielded Dark images and is retained privately as an unsuccessful approach, not counted as Light proof. Largest accessibility Today and landscape were captured in Dark; they do not establish the full size/appearance matrix.

## Measurements, diagnostics and limits

[Performance](PERFORMANCE.md) records actual projection, CPU, memory, launch and XCTest-clock samples. The launch metric is incomplete. Four final invalid-frame-dimension warnings arose during text-field/keyboard focus; the same warning reproduced in the unchanged baseline decimal-entry case, which passed. This establishes that the warning predates these fixes; its underlying cause is not resolved.

Initial baseline sign-in failed because literal ASCII input left the secure field empty. Email was correct and the active keyboard exposed no x key. A visible-letter fixture then passed on unchanged baseline and final app, preserving secure-value and submit-enabled assertions without changing keyboard configuration or product validation. Failed and phone-locked attempts remain separate private results.

Retained P2 visual issue: the normal-width Workout inline Training title truncates beside toolbar actions; routine identity, Save & close and Finish remain available.

Rendered widget/Live Activity views are not system-hosted placement/privacy proof. Actual ActivityKit intents, locked-screen redaction, physical Watch/Health sensing and save/recovery, full assistive technologies, human haptic judgement, storage/thermal interruption pressure, Release performance/energy/leaks, iOS 17 runtime and a signed distribution archive remain unverified. Distribution remains NO-GO. No merge, deployment, TestFlight upload or App Store submission occurred.
