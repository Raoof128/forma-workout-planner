# Commit 2 remaining gates

Nothing below blocks the local commit. Each gate needs a person, a device or an
unloaded machine. None of them was claimed as done.

## Needs the owner

1. **Push, PR and merge.** The commit is local on
   `feat/ios-commit2-premium-experience`. Pushing, opening a PR and merging
   were not authorised in the brief.
2. **Feel on device.** Use the iPhone Air build and check:
   - set completion while typing in another row (the keyboard should stay up);
   - the rest ring across Pause, Resume, +15 s and Skip;
   - the rest-end haptic and "Rest finished" announcement;
   - the receipt seal and its one success haptic;
   - the week-strip fill after finishing.
3. **Haptic choice.** Set completion moved from `.success` to a light impact
   (IMPLEMENTATION_REPORT, "Haptic map"). Revert in one line if the success
   pattern is preferred.

## Needs a device or an unloaded Mac

4. **Instruments** (SwiftUI, Hitches) on the iPhone Air during a workout with
   a running hold and a running rest. NOT RUN; see PERFORMANCE_RESULTS.
5. **Launch metric** (`XCTApplicationLaunchMetric`). NOT RUN.
6. **VoiceOver pass** on device: rest-end announcement, week strip labels,
   "Starting" values, chart summary. Code-reviewed only.
7. **Dynamic Type at accessibility sizes**: the rest ring in the Label icon
   slot and the Pause/Resume width reservation. Code-reviewed only.
8. **Apple Watch on hardware**: phase fades, `.start` / `.success` haptics,
   and stillness in Always On. The watch was built but not run; no watch
   simulator or paired run was done this session.

## Known limits, accepted for now

9. **Watch haptics ignore You › Set confirmation haptics.** The iPhone
   preference is not synced to the Watch; doing so needs a change to
   `Shared/` or `WorkoutManager`, which this commit kept out of scope. Watch
   haptics follow watchOS settings.
10. **Hold chime** (system sound 1057) follows `Profile.muted`, which has no
    iOS UI. Unchanged by this commit; noted in FILE_AUDIT.
11. **Busy gating.** Completion, Finish, Add set, Notes, Next exercise and the
    rest dock still disable for the few milliseconds of each commit. They are
    correctness gates and were kept.
12. **Screenshot evidence lives outside the repo.** The before/after PNGs are
    in the session scratchpad (sizes in TEST_RESULTS). Only downscaled
    comparison sheets are committed.
