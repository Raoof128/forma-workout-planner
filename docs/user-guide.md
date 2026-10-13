# User guide

[Back to README](../README.md)

## Plan a routine

Open **My routines** to use a starter routine or create your own. Give it a name, choose exercises, set an estimated duration, and enter the number of sets, reps, and starting weight. Use the up/down controls to reorder exercises. Save the routine before starting.

Changing or deleting a routine does not rewrite completed workout history. An active workout keeps its own exercise and prescription snapshot.

The template section adds strength, bodyweight, core, cardio, carries and mobility
starting points. Selecting one creates an editable copy in your routines. Choose
appropriate loads yourself. The library searches 1,661 exercises across all
pages; use equipment/activity filters and **Show more exercises** to browse.
Imported guides show their source, author and licence.

On Overview, choose your next session and use **Schedule your week** to mark your usual training days. The calendar shows planned days and logged workouts. Training days are reminders, not assignments of specific routines to dates.

## Log a workout

1. Start a routine from Overview or its details.
2. Enter the displayed measurements for a set, then mark it complete: weight/reps, seconds, metres, or loaded carry distance.
3. Use the rest timer between sets; choose 60, 90, or 120 seconds, pause it, or skip rest.
4. Add sets and session notes as needed. Open the book icon for exercise instructions.
5. Finish the workout and confirm **Save workout**.

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

## Preferences and limits

Settings controls the profile name and weekly workout target. Dates use Sydney time, weights use kilograms, and one plank rep means a 10-second hold. In guest mode, data stays in browser storage and does not sync between devices. In account mode, validated workspace changes save to the self-hosted API and can be used from another signed-in device. Account mode requires a deployed, configured service; see the [account help and limitations](accounts/README.md). Browser-local guest storage is not encrypted by FORMA; same-origin scripts, browser extensions, and people with access to your browser profile may be able to read it. A hosting provider may also keep ordinary access logs. Review the provider's privacy and retention settings separately.
