# FORMA

A personal gym workout planner and log, researched from Leap Health's Gym Workout Planner & Gym Log and built with an original responsive web design.

## Run

```sh
npm ci
npm run dev
```

Open http://localhost:5173. `npm run build` creates the production bundle; `npm run preview` serves it. Deploy using HTTPS for browser storage locking; localhost is also supported.

## Included

- Dashboard, weekly schedule, and selectable next routine
- Three editable starter routines, custom routines, exercise ordering, and preserved prescriptions
- Search and muscle/equipment filters across 16 exercises, with instructions available while logging
- Set logging, additional sets, notes, and rest timers that survive navigation and reload
- Completed workout history with correction/deletion and recalculated progress
- Training volume, completed sets, personal best weights, and estimated 1RM
- Profile/weekly goal preferences, validated JSON export/import, and corrupt-data recovery
- Keyboard-accessible dialogs, mobile drawer, browser Back, and bookmarked screens

Data stays in this browser under `forma-v1`. Cross-tab changes use serialized transactions. Invalid data is preserved for recovery; imports/resets save the previous content under a `forma-v1-recovery-*` key. Clearing browser data removes these copies, so download backups from Settings.

If saving is blocked or Web Locks are unavailable, the app clearly switches to temporary in-memory changes with export available. Wait for “Saving changes…” to clear before closing; the app warns when a write is pending. Browser shutdown or clearing storage is not a substitute for a backup.

Weights use kilograms. Dates use Australia/Sydney. Starter weights are editable examples, not personalized prescriptions. One plank rep represents a 10-second hold. Single-rep maximums use actual weight; sets of 2–12 reps use Epley estimates.

This version has no accounts, remote sync, Apple Health integration, videos, or automated coaching.

## Checks

```sh
npx playwright install chromium
npm run lint
npm run format:check
npm run build
npm test
```

The suite covers core workflows, concurrent tabs, invalid storage/recovery, backup round trips, rapid typing, focus/drawer behavior, timer persistence, routine edits, history calculations, navigation, responsive edge cases, and automated accessibility scans.

See [research](docs/research.md), [audit fixes](docs/audit-fixes.md), and [verification](docs/verification.md). The [original design concept](docs/design-concept.png) is historical reference material.
