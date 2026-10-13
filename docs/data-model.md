# Data model and backup format

[Back to README](../README.md)

## Workspace envelope

The version 1 workspace shape is shared by guest mode, JSON backups, and the authenticated server workspace. Guest mode stores it under `localStorage['forma-v1']`; account mode stores it as owner-scoped JSONB in PostgreSQL. Exports contain the same versioned envelope. `src/storage.js` is the source of truth for validation; this document explains the data contract. See [account database details](accounts/database.md) for the server revision and ownership boundary.

| Field      | Meaning                                                                                   |
| ---------- | ----------------------------------------------------------------------------------------- |
| `version`  | Schema version; currently `1`                                                             |
| `revision` | Monotonic workspace revision used for conflict detection; defaults to 0 for older backups |
| `routines` | Routine definitions, each with a unique ID and ordered exercise prescriptions             |
| `active`   | One active workout snapshot, or `null`                                                    |
| `history`  | Completed workout snapshots with unique IDs, completion dates, and durations              |
| `profile`  | Display name and weekly goal                                                              |
| `schedule` | Unique weekday indices, Monday = 0 through Sunday = 6                                     |

## Routine and session records

Routine names contain 1–60 trimmed characters. Routine exercises reference built-in exercise IDs and specify 1–12 sets, 1–100 reps, and 0–1,000 kg. Estimated duration is 1–1,000 minutes. Duplicate exercises within a routine are rejected; use multiple sets for the same exercise.

A session snapshots the routine name and prescribed sets at the start. Each set has `weight`, `reps`, and `done`. Depending on the exercise, routine prescriptions and sets also carry `durationSeconds` (1–86,400) and/or `distanceMeters` (1–1,000,000). Completed sets require all fields appropriate to that exercise's measurement profile. Unfinished fields can be blank while being edited. Fractional weights are supported consistently by validation and editing controls. Session notes can contain up to 10,000 characters. Each exercise can contain up to 100 logged sets, and each routine or session at most 100 exercises.

`startedAt` and `restEnd` use nonnegative Unix milliseconds within JavaScript’s valid date range. A history record must include at least one completed set, and its ID cannot also identify the active session. `restSeconds` and `restPaused` use seconds; rest preferences range from 10 to 600 seconds at the data boundary. History uses a UTC ISO completion `date` and a `duration` in seconds. Display dates are calculated in Australia/Sydney, independently of the device's time zone. Import ordering is determined by parsed timestamps, not by array position.

The profile name contains 1–50 trimmed characters and the weekly goal is 1–7 workouts. A new guest workspace starts with the name `Guest`; an empty account workspace uses the member's display name without inventing workout history.

## Compatibility and recovery

Only version 1 backups are accepted. Existing version 1 snapshots without `revision`, notes, or rest-state fields receive their documented defaults during validation. Unknown exercise IDs, duplicate record IDs, invalid nested objects, and unsupported versions are rejected before replacement.

Malformed saved data is left untouched and opens the recovery screen. Restore/reset preserve the previous raw content under a `forma-v1-recovery-*` key before replacing the main workspace. If preservation or replacement fails, recovery reports an error. Originals use unique keys even when multiple restores happen in the same millisecond. When restoring out of temporary mode, both the last saved version and unsaved in-memory version are preserved if they differ. Browser quota is implementation-dependent and may be smaller than the 20 MiB (20,971,520 bytes) backup-input limit. Both file imports and raw saved JSON are size-checked before parsing.

Recovery copies remain in browser storage and have no automatic retention policy. Download backups and the original corrupt data before clearing any site data. The application does not claim crash-atomic transactions across multiple storage keys: each `localStorage.setItem` is atomic, while preservation and replacement are separate writes protected by the shared lock.

## Calculations

- Completed sets: number of sets whose `done` flag is true.
- Volume: sum of `weight × reps` across completed load/reps sets; time and distance are excluded.
- Best weight: maximum weight across completed load/reps sets for that exercise.
- Estimated 1RM: actual weight for 1 rep; `weight × (1 + reps / 30)` for 2–12 reps; no estimate from higher-rep sets.
- Recent volume chart: the most recent eight completed sessions, ordered by time.

Unfinished sets do not contribute to progress. Historical session snapshots remain meaningful after a routine is edited or deleted.
