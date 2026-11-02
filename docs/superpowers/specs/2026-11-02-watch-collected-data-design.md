# Watch collected data, Watch stop choice and loading state

Date: 2 November 2026. Owner asked for four changes and said to go ahead without
a question round ("start integrating"), and that the Watch must not control
everything. Calls marked **(agent's call)** were made without the owner and are
listed in the PR for review.

## Why

The Watch records heart rate and energy, but once the workout ends the numbers
are only in Apple Health. The person wants to see what the Watch collected next
to the finished workout and in Progress, on the iPhone and on the website. On the
Watch, ending or pausing should be one obvious control, the Done button must stay
easy to hit, and the screen should show that it is working while the session and
sensors start.

## What the Watch records today

`WorkoutManager` (watchOS) keeps elapsed active time, the latest heart rate, the
average heart rate and the sum of active energy from `HKLiveWorkoutBuilder`.
Basal energy is collected but unused. This change also keeps the **maximum**
heart rate (`HKStatistics.maximumQuantity()`), already in the builder's statistics.

## 1. Collected-data section

- **Data:** finished workouts gain an optional `watch` object:
  `{ elapsedSeconds, averageHeartRate?, maxHeartRate?, activeEnergyKcal? }`,
  whole numbers, bounded (time 0–86 400 s, heart rate 25–250 bpm, energy
  0–10 000 kcal). Only `history` sessions carry it, never `active`. Absent means
  no Watch recording; every existing workspace stays valid.
- **Where it comes from:** the iPhone attaches the latest Watch snapshot when the
  workout is finished, then replaces it with the Watch's final snapshot
  (state `ended`) if that arrives later for the same session. Nothing is read back
  from Apple Health **(agent's call: keeps one source and no new Health read path)**.
- **Sync:** the summary is part of the workout record, so a signed-in member's
  summary syncs to the account and the website shows it. Guest mode on the web
  never has one (no Watch).
- **iPhone:** the "Session saved" receipt and the session detail show a
  "Collected by Apple Watch" card (time, average and max heart rate, active
  energy). Progress adds a Watch card (workouts recorded, average heart rate across
  them, total active energy) and journal rows with Watch data show a heart badge.
- **Website:** the workout detail modal shows the same card; the journal row shows
  a heart badge; Progress shows the same totals panel.
- **Privacy:** this reverses the documented boundary "heart rate and energy never
  enter the workspace". The Privacy Policy (`src/legal/content.js`, version
  bump), native privacy text, `ios/docs/apple-watch.md`, privacy inventory and
  data model docs are updated. **The owner must approve the policy text before
  any deploy.** Release order: API (accepts the field) before the iPhone build that
  sends it; an older API strips the unknown key rather than rejecting the write.

## 2. Watch workout screen polish (agent's call on scope)

- Summary: **Done** is pinned as a full-width 52 pt bottom button that never
  scrolls away, and is shown during Always On too (the summary has nothing to
  protect).
- Metrics page: the elapsed time, heart rate and energy keep their layout; a
  "Waiting for heart rate" state replaces "-- bpm" while sensors warm up.
- iPhone workout screen with a Watch: the recording strip becomes a card with
  its status, heart rate and energy; when the Watch ends its own recording the card
  says so and offers **Finish workout** (a large primary button) so the person
  is not left hunting for it.

## 3. Watch stop / end control

A large Stop button on the metrics page opens a choice: **Pause recording**
(or **Resume**), **End workout** (saves to Health), and Cancel. Discard stays on the
controls page behind its confirmation. Per the owner, the Watch controls only its
own recording; it does not stop the iPhone's set, hold or rest timers. Ending on
the Watch does not finish the FORMA workout; the iPhone prompts for it.

## 4. Watch loading animation

A heart that pulses (`symbolEffect(.pulse)`) with "Starting…", "Restoring…",
"Saving to Health…" and "Waiting for heart rate" text, used for `.starting`,
`.recovering`, `.ending` and the time before the first heart-rate sample. Reduce
Motion and Always On show the same symbol without the effect.

## Non-goals and anti-goals

- No Watch control of iPhone timers, sets or holds.
- No reading of historical Health data, no new Health types, no charts of samples.
- Never show a reading as live when it is stale; never invent a summary for a
  workout the Watch did not record.

## Testing

FORMACore: summary encode/decode, bounds, merge rules, old workspaces decode.
Web: `unit/` tests for the schema (accepts, bounds, strips from `active`) and the
summary formatter; server tests if a PostgreSQL is available. iOS app tests for
attaching and replacing the summary. Watch views have no test target; build
both apps and check on the owner's devices.
