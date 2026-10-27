# Commit 2 test results

Environment: Xcode 27.1, iOS 27.0 simulator "FORMA Test iPhone 17 Pro"
(`BE9F1441`), macOS 27, Swift 6 strict concurrency. The Mac's load average
stayed between 10 and 47 throughout, which made simulator runs slow and
sometimes caused stalls; see "Flaky under load" below.

## Summary

| Suite | Result |
| --- | --- |
| iOS app + Watch app build (Debug, simulator) | **Passed**, no errors or new warnings |
| iOS app + Watch app build (Release, iPhone Air, signed) | **Passed** |
| FORMACore (`swift test`) | **Passed**: 76 tests, 0 failures, 3.05 s |
| UI tests: baseline `7373cf6`, iOS 27.0 | 3 of 8 passed (recorded before this work) |
| UI tests: this commit, full suite, light | 10 of 12 passed in one run; the other 2 then passed on their own (below) |
| UI tests: every test passed at least once on the final code | **12 of 12** |
| Screenshot tour, baseline code | Passed in light and in dark |
| Screenshot tour, this commit | Passed in light and in dark |

## Every UI test, final code

| Test | Full run (light) | Rerun alone |
| --- | --- | --- |
| MotionExperienceTests.testMotionOffStillShowsEveryFinalState (new) | Passed | – |
| MotionExperienceTests.testCompletingASetKeepsTheRowInPlace (new) | Passed | – |
| MotionExperienceTests.testReceiptWaitsForTheConfirmedFinish (new) | Passed | – |
| ScreenshotTourTests.testPrimaryScreensTour (new) | Passed (and passed in dark) | – |
| OfflineWorkoutTests.testFreshWorkspaceHasNoInventedProgress | Passed | – |
| OfflineWorkoutTests.testCompletedSetSurvivesProcessTerminationAndFinishesOnce | Passed (failed on baseline) | – |
| OfflineWorkoutTests.testUnfinishedWorkoutSurvivesProcessTermination | Passed | – |
| OfflineWorkoutTests.testResumeAccessoryPreservesTheSelectedTabAndRoutineDetails | Passed (failed on baseline) | – |
| OfflineWorkoutTests.testInvalidDraftCannotCloseOrFinishAndCanBeCorrected | Passed (failed on baseline) | – |
| OfflineWorkoutTests.testDeletingLocalTrainingClearsAnAlreadyOpenHistoryDetail | Passed (failed on baseline) | – |
| OfflineWorkoutTests.testDecimalEntryCommitsAndRestPauseSurvivesReopening | Failed: app did not launch ("does not have a process ID") | **Passed** (54 s); also passed in an earlier targeted run |
| OfflineWorkoutTests.testSessionNotesPersistAndDiscardKeepsAcknowledgedText | Failed: a scroll stalled for 8 minutes under load | **Passed** (51 s); also passed in the first full run |

## Flaky under load

The two failures in the full run were environmental: one launch failure
before any app code ran, and one 506-second stall in a step that normally
takes seconds. Both tests passed alone on the same build. They are not
reported as fixed by this commit, and not as broken by it.

## Why the baseline failures went away

Each cause was diagnosed from the accessibility hierarchy captured at
failure, not guessed:

| Cause | Tests affected | Fix |
| --- | --- | --- |
| The finish alert's button and the toolbar button are both labelled "Finish workout" | completed-set, delete-training | Tests target the alert button by its identifier `finish-confirm` |
| Rest dock controls reported the screen's identifier (`workout-screen`), so `rest-toggle` never existed | decimal-entry | **App fix**: the dock is its own accessibility container (`WorkoutView.swift`) |
| Synthesized deletes partly dropped on the simulator's keyboard layout ("40" then "42.5" became "42.54") | decimal-entry, invalid-draft | Tests replace text by selecting it (`replaceText(with:)`) |
| `List` rows below the fold are not in the hierarchy until scrolled to | resume-accessory ("Edit routine"), delete-training (made worse by the longer You footer) | Tests scroll to the row before requiring it |
| 5 s waits too short on a loaded simulator | several | Waits raised to 15 s |

No assertion was removed or weakened. Every test checks the same outcomes as
before.

## Screenshots

Nine screens in light and dark, before (`7373cf6`, captured from a clean
checkout) and after (this commit). Each image puts before on the left and
after on the right, in `screenshots/`, for example
[light set completion](screenshots/light-05-set-completed-rest.jpg) and
[dark receipt](screenshots/dark-06-receipt.jpg) (`light-NN-*.jpg`, `dark-NN-*.jpg`, 360 px
wide per side). Full-resolution originals were kept in the session scratchpad
and are not committed (about 15 MB).

## NOT RUN

- Instruments and launch metrics (see PERFORMANCE_RESULTS.md).
- Watch app on a simulator or on hardware (built only).
- VoiceOver, Dynamic Type accessibility sizes and Reduce Motion by hand on a
  device (see REMAINING_GATES.md). Motion Off is covered by
  `testMotionOffStillShowsEveryFinalState`.
- The web contract probe and web test suites (no web code changed).
