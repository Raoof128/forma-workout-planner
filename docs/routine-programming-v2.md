# Routine programming v2

[Back to data model](data-model.md)

## Programming a routine

The exercise editor accepts a single rep count or a range, such as `8-10` or
`8–10`. Sets stay within 1–12; each rep endpoint is an integer from 1–100.
Optional RPE is 1–10 in half steps. Rest is 10–600 seconds; a blank rest field
inherits the user's Settings preference, which starts at 90 seconds. Settings
also controls the rest timer sound. Vibration depends on browser/device support.

The exercise options disclosure holds a plain-text cue of up to 140 characters,
per-side repetitions and “Superset with previous exercise”. Known unilateral
movements default to per-side only when newly added; existing prescriptions keep
their saved false/default values. Lower-body movements display `/ leg`, others
`/ arm`. Supersets contain consecutive exercises and display A1/A2, B1/B2, etc.
Rest begins only when a set of the last exercise in its group is completed.
Reordering or removing exercises clears groups that would become disconnected
or have only one member. Arrow buttons remain available alongside drag handles.
The routine card's actions disclosure offers “Duplicate routine”.

A workout snapshots targets and cues. Actual repetitions, load, and optional
actual set RPE remain independent of the target. Editing/deleting a routine does
not alter existing sessions. Rest uses a persisted millisecond deadline, so
reloads, navigation and tab switches do not reset its duration. Pause/resume and
±15-second adjustments use action timestamps, including with asynchronous saves.
Sound needs a browser audio capability and an interaction to unlock playback;
suspended devices may deliver the completion cue when they resume.

## Schema and compatibility

`src/storage.js` remains the shared browser/API validator. The envelope is
`version: 2`; the browser key remains `forma-v1` so existing installations are
found. Routine/session exercise records gain optional `repsMax`, `rpe`,
`restSeconds`, `perSide`, `note` and `groupId`. Nullable fields default to null;
`perSide` defaults false. Sessions additionally snapshot `targetReps`. Logged sets
have nullable actual `rpe`. Profile defaults are `restSeconds: 90`, `muted: false`.

Only the reviewed identical-unit incline press/fly synonyms in
`src/catalog/programming-aliases.json` migrate IDs. If old aliases and their
canonical exercise both occur in a routine/session, every row survives with its
own stable `entryId`. Other historical IDs, including the ten-second-per-rep
legacy plank, retain their original measurement units.

Version 1 imports and existing local data normalize before use. Under the existing
browser write lock, initialization writes the migrated v2 data once. Invalid
unfinished numeric drafts from v1 become blank correction fields, retaining the
exact entered numbers as strings in optional `legacyDraft` metadata on each set.
The original values remain available in input placeholders and exports. Completed
measurements never receive this conversion. V2 inputs retain strict numeric bounds.

The API rejects unknown fields at every nesting level, including ownership keys.
Backup import keeps its existing behavior of stripping unknown fields. Notes are
plain React text nodes; the API enforces their length. No dependency was added.
Every workspace query continues to select the session's owner; exercise/routine
IDs never select another member's workspace.

## Database migration and rollout

Migration `server/migrations/0004-routine-programming.sql` transforms JSONB inside
PostgreSQL for routines, active sessions and history. It adds defaults, converts
the same aliases/drafts as the browser, advances each v1 row's revision once, and
changes the workspace version constraint to v2. Running it again changes no v2
row. Its functions are temporary and it creates no persistent tables or grants.

Before deployment, take the normal encrypted backup and pause old API writers.
Run the standard migration runner with the migration-role connection supplied
through `DATABASE_URL`:

```sh
npm run server:migrate
```

Deploy the matching API image before enabling the v2 account frontend, then resume
writes. The previous API rejects v2 workspaces. Do not roll back to it after
migration; restore through the existing controlled recovery procedure if needed.
Old clients can import v1 payloads through the new API; stale revisions still
return 409. Retained operation hashes from before the upgrade can also return 409
for an old retry after normalization, so reload/reconcile before a fresh operation.
The migration and API must ship together. The owner-authorised rollout is recorded in the release evidence linked below.

## Verification

```sh
npm run lint && npm run format:check && npm run typecheck && npm run docs:check
npm test
npm run test:worker && npm run test:operations
npm run test:server
npm run test:accounts
npm run test:browser:production
node scripts/audit-exercise-equipment.mjs --check
node scripts/check-exercise-media.mjs --strict
```

The server and account suites require `TEST_DATABASE_URL` naming an isolated test
database and fail when it is missing. The migration regression compares PostgreSQL
and browser results, including alias collisions, all session paths, invalid legacy
drafts and a second migration run. Browser cases exercise the example program,
reload, timer, actual RPE, duplication, drag/arrows and superset restoration.
The real account journey also checks target/cue persistence in another browser
context. The equipment script audits cable, barbell, dumbbell/DB, machine,
kettlebell, band and Smith names. One reviewed exception retains an EZ-bar guide
whose historical title says Barbell; the script records the reason explicitly.

## Existing archived routines

The live v1 application also persisted an optional `archivedAt` timestamp on
routines. Preserve it through browser/import/SQL migration and strict API
validation. Archived routines remain in the workspace and backup, with their
original prescriptions and history links, but stay out of the overview and start
suggestions. Active/Archived views allow restoration; editing keeps the timestamp
and duplication produces an active copy. Archive/restore actions reject stale
routine snapshots just like other routine changes.

During the initial production rollout, the post-migration validator detected
this missing compatibility field before the v2 frontend was enabled. Writers
were paused while the schema/UI compatibility correction was verified. The SQL
migration had already retained the field, so no applied migration was changed and
no member row was deleted or exported. See the [release evidence](qa/routine-programming-v2/README.md).
