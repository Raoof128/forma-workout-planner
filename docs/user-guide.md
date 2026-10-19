# User guide

[Back to README](../README.md)

## Plan a routine

Open **My routines** to use a starter routine or create your own. Give it a name, choose exercises, set an estimated duration, and enter the number of sets, reps, and starting weight. Drag an exercise by its grip, or use the up/down controls, to reorder exercises. Save the routine before starting.

To change the order of your routines, drag a card on **My routines** (on a phone, touch and hold the card first), or open its **⋯** menu and choose **Move earlier** or **Move later**. Press Escape while dragging to cancel.

Changing or deleting a routine does not rewrite completed workout history. An active workout keeps its own exercise and prescription snapshot.

The template section adds strength, bodyweight, core, cardio, carries and mobility
starting points. Selecting one creates an editable copy in your routines. Choose
appropriate loads yourself. The library searches 1,661 exercises across all
pages; use equipment/activity filters and **Show more exercises** to browse.
Imported guides show their source, author and licence.

On Overview, choose your next session and use **Schedule your week** to mark your usual training days. The calendar shows planned days and logged workouts. Training days are reminders, not assignments of specific routines to dates.

## Log a workout

1. Start a routine from Overview or its details.
2. Enter the displayed measurements for a set, then mark it complete: weight/reps, seconds, metres, or loaded carry distance. A one-side-at-a-time exercise (a lunge, a one-arm row, a side plank) shows **Left** and **Right** rep fields instead of one rep count; both sides are needed before the set can be completed, and the set's total reps count toward volume.
3. Use the rest timer between sets; choose 60, 90, or 120 seconds, pause it, or skip rest.
4. Add sets, remove an unfinished last set, and write session notes as needed. Open the book icon for exercise instructions.
5. Use **Edit workout** to add an exercise, move one earlier or later, or remove one while the workout is running. Removing an exercise that has completed sets asks once more and discards those sets.
6. Finish the workout and confirm **Save workout**.

By default the weight and reps you type into a set also fill the later unfinished sets of that exercise, as long as they still show the value you replaced; a set you changed deliberately keeps its own value. Turn **Fill the remaining sets with what I type** off in the workout side panel or in Settings to enter every set by hand.

The exercise library marks 408 movements as performed one side at a time. They log left and right by default; the **Reps per leg/arm/side** option in a routine's exercise menu turns side logging on or off for any load-and-reps exercise.

Only completed sets count toward volume and progress. Complete at least one set before saving a workout. Completed sets are locked for entry; undo completion before changing them. A different routine cannot silently replace an active workout: the app offers a choice to resume or discard and start again.

Persistent sessions and timers survive navigation and reload. Wait for “Saving changes…” to disappear before closing. If the app reports temporary mode, export a backup before leaving.

## Read and correct progress

**Workout history** shows completed sessions newest first. Open a workout to inspect its sets and notes, correct its name or logged values, or delete it with confirmation. Corrections update the progress totals.

**Progress** shows completed workouts, completed sets, and volume, calculated as the sum of `weight × reps` for completed sets. Bodyweight sets logged at 0 kg contribute completed sets but zero external-load volume. Dumbbell volume uses the weight entered; it does not automatically double for two hands or both sides.

Time and distance stay visible in workout history and corrections but do not
become kilogram volume or lifting personal bests. Personal bests for load/reps
movements show the highest completed weight and an estimated one-repetition
maximum. One rep uses the actual load; 2–12 reps use the Epley formula. Sets above
12 reps do not contribute to the estimate. These are training records, not
personalized exercise prescriptions.

## Back up and restore

In **Settings**, use **Export my data** to download the entire workspace as JSON. Keep a copy somewhere outside browser storage and confirm the download completed before resetting or clearing site data. To move to another browser or device, transfer that file yourself, open FORMA there, and choose **Import backup**.

Import validates the file before showing a confirmation. If you select another file while an earlier file is still being read, only the most recently selected backup can open the confirmation preview; a late result from the earlier read is ignored. Restoring replaces the current workspace and attempts to preserve the previous data locally first. Files must be FORMA version 1 JSON backups within the documented size limit. A local recovery copy is not an external backup; clearing site data removes both. Recovery preservation and replacement use separate browser-storage writes, so they are not a crash-atomic transaction. Keep an external backup before restoring or resetting.

If data cannot be read, first use **Download original data** and keep the downloaded file outside the browser. Then restore a known-good backup, or use the explicit reset option only after confirming you have preserved anything you need. If storage is full or blocked, follow the displayed error; do not clear site data as the first recovery step. Temporary mode keeps changes only in memory for that visit: export before closing or refreshing. A conflict message means another tab changed the record you were editing. Reopen that record and reapply your changes to the latest version.

## Share progress with a coach

Account members can create a **coach token** under Account › Security ›
Coach access and give it to a coaching tool or AI assistant. Choose its access
when you create it:

- **Read only** lets the tool read your routines, recent workouts and
  personal bests.
- **Full access: read and edit** also lets it read everything in your
  training workspace and change it: build or rewrite routines, log or correct
  workouts, plan your week and adjust your preferences. If it would delete
  logged workouts, it has to say how many, or the change is refused.

No coach token can see your email or change your password, sign-ins, 2-step
verification, coach tokens or account. The token is shown once, expires after
90 days, and can be revoked at any time.
Treat it like a password: store it in the tool's secret settings and never
paste it into a chat. Details are in the [API reference](accounts/api.md#coach-access-read-only-and-full-access-tokens).

## Preferences and limits

Settings controls the profile name and weekly workout target. Dates use Sydney time, weights use kilograms, and one plank rep means a 10-second hold. In guest mode, data stays in browser storage and does not sync between devices. In account mode, validated workspace changes save to the self-hosted API and can be used from another signed-in device. Account mode requires a deployed, configured service; see the [account help and limitations](accounts/README.md). Browser-local guest storage is not encrypted by FORMA; same-origin scripts, browser extensions, and people with access to your browser profile may be able to read it. A hosting provider may also keep ordinary access logs. Review the provider's privacy and retention settings separately.
