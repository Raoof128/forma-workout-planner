# Implementation roadmap

Status: **proposed, not implemented by this research update**. Preserve browser-local ownership and existing version-1 backups. These requirements follow the coverage study; they are not a new server architecture.

## 1. Define measurements before expanding the runtime catalog

Use a discriminated result type instead of forcing every activity into `weight × reps`. The following identifiers match `metric_profile` in the candidate CSV. Optional fields should stay optional; do not invent unavailable machine measurements.

| Profile             | Required result                                                | Optional context                                                                         |
| ------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `load_reps`         | Reps and external mass                                         | Load convention, left/right, tempo, RPE/RIR, machine instance                            |
| `reps`              | Reps                                                           | Side, bodyweight snapshot if relevant, setup                                             |
| `added_load_reps`   | Reps and added external mass                                   | Bodyweight snapshot stored separately                                                    |
| `assistance_reps`   | Reps and assistance value                                      | Machine identity; less assistance can represent progress                                 |
| `duration`          | Elapsed seconds                                                | Side, setup, hold quality notes                                                          |
| `load_duration`     | External mass and seconds                                      | Load convention, apparatus                                                               |
| `load_distance`     | External mass and distance                                     | Elapsed time, surface, sled tare, per-hand convention                                    |
| `distance_duration` | Distance and elapsed seconds                                   | Repeats, course/setup; useful for climbing/shuttles                                      |
| `reps_duration`     | Reps and elapsed seconds                                       | Cadence and interval index                                                               |
| `cardio`            | Elapsed seconds                                                | Distance, pace, speed, watts, cadence, incline, level, floors, machine-reported calories |
| `resistance_reps`   | Reps and a typed resistance setting                            | Band/spring identity, pneumatic setting, inertia, electronic mode                        |
| `force_work`        | Reps plus at least one reported force or work value with units | Duration, machine mode, average/peak distinction; manual entry only                      |

One exercise may later support more than one profile, such as loaded versus unloaded holds. The CSV lists a primary planning profile, not an immutable restriction. Unknown values must remain absent, not zero. Zero is a valid measured value in some contexts. A result with no meaningful completed effort must not count as a completed workout.

Store canonical mass/distance/time units while retaining the user's entry units. Distinguish a mass in kilograms from force in newtons and inertia in kg·m². Resistance levels, spring colors, and band colors are vendor-specific labels. A device's displayed calories are estimates supplied by that device, not a universal computation from lifted volume.

Concept2 documents multiple cardio metrics; Exxentric documents inertia; EGYM documents a mode where speed is controlled. These justify separate measurements. The exact schema above is a FORMA design recommendation. [Concept2](https://www.concept2.com/blog/customize-your-data-display-with-ergdata), [Exxentric](https://exxentric.com/how-it-works/advantages/variable-resistance/inertia/), [EGYM](https://knowledge.egym.com/en/smart-strength/workout-settings/training-methods/isokinetic-training).

## 2. Separate exercise, equipment family, and machine instance

An exercise definition should contain a stable ID, canonical name, aliases, movement family, primary/secondary muscles, supported metric profiles, required/optional equipment, variation metadata, original instructions, and content provenance. Muscle assignments and technique must be reviewed individually before publication.

An equipment family describes a kind of implement. A machine instance records the user's actual station: optional gym/name/model, resistance mechanism, display units, pulley/handle setup, seat/backrest settings, starting resistance, and notes. A selectorized and a plate-loaded chest press should not silently share a personal-best series.

Require an explicit load convention: total implement mass, each dumbbell, plates added, plates per side, displayed stack value, added bodyweight load, or assistance. Do not double a dumbbell record or add assumed bar/Smith/sled mass without evidence. Side-specific reps need `per_side` versus `total` semantics. Cable ratios should be recorded only from the specific machine's documentation, with any conversion shown explicitly. [Matrix example](https://ca.matrixfitness.com/eng/strength/multi-station/go-ft-functional-trainer).

Custom entries should use unique IDs and validated bounded fields. Their definitions must travel with backups; archive referenced entries instead of deleting history. Keep catalog version/content revision separate from workout timestamps. Avoid a compile-time enum containing every permitted exercise ID once custom entries exist.

## 3. Plan migration and protect current users

1. Keep the 16 existing exercise IDs stable. Add schema version 2 with an explicit version-1 adapter and fixture coverage.
2. Preserve original numbers and raw backup export. Existing kilogram entries have ambiguous per-hand/total conventions; mark them `legacy_unspecified`, not newly normalized totals.
3. Preserve historical plank reps and document the old ten-second convention. If displaying `reps × 10` seconds, label it a conversion from the old convention, not measured elapsed time. Never infer timing for other exercises.
4. Snapshot exercise name, metric profile, unit/convention, and relevant machine context in completed sessions so later catalog edits do not reinterpret history.
5. Support custom-definition restore with referential validation. Unknown external definitions should be reviewed or retained as explicit archived definitions, never silently rebound by name.
6. Revisit the current catalog-size-derived exercise-array bound, backup-size limits, validation complexity, local quota, and recovery-copy behavior. Keep deterministic size limits; measure representative long histories before changing storage engines.
7. Run migrations through the audited repository/lock/recovery path. Preserve disk and unsaved originals; reject stale previews. Mixed app versions need a visible unsupported-version state instead of overwriting newer data.

## 4. Expand content in usable phases

| Phase      | Deliverable                                                                                   | Completion evidence                                                                                                                |
| ---------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Foundation | Typed results, stable definitions, custom exercises, unit/convention metadata, safe migration | Version-1 round trips preserve original logs; incompatible records cannot contaminate calculations                                 |
| P1         | Common machines/free weights, precise search, setup fields, duration holds                    | Each published candidate has reviewed metadata and original instructions; all referenced equipment resolves                        |
| P2         | Cardio, carries, circuits, suspension/bands, accessible equipment                             | Phone logging uses correct fields; interval and background/resume timing work; equipment availability filters respect dependencies |
| P3         | Specialty resistance, strongman, advanced apparatus                                           | Vendor-specific settings and reviewed instructions; no unsupported weight-equivalence claims                                       |
| Ongoing    | Alias cleanup, local custom entries, new machines and variants                                | Catalog changes preserve history; provenance and attribution stay attached                                                         |

P1/P2/P3 in the CSV inherit the main equipment family's priority. They are a sorting aid, not permission to publish unreviewed advanced movements. Review complexity can move an individual exercise to a later phase.

## 5. Make a large library practical on a phone

Offer search synonyms such as “RDL,” “hex bar,” “lat pull-down,” and “rear delt fly.” Filter by available equipment, movement, body area, and favorites. A user's gym inventory should include supporting benches, racks, handles, and attachments where needed. Suggest compatible substitutions without treating their loads as equivalent.

For logging, display only relevant fields, readable unit labels, large touch targets, and an accessible timer. Provide a concise machine setup summary and copy-last-set action. Keep drafts stable when filtering or switching tabs. Test 320-pixel screens, landscape, desktop, keyboard-only operation, screen-reader labels, and zoom after implementation.

## 6. Keep analytics honest

Compare like with like: same exercise/variation, machine instance where relevant, metric type, load convention, and compatible units. Do not merge assisted reps, timed holds, sled distance, inertia, or cardio into lifted tonnage. Do not apply the existing estimated-1RM calculation to these profiles.

Offer separate summaries for resistance work, duration, distance, and workout frequency. For assistance, explicitly define whether progress means fewer assistance units at the same reps. Distinguish measured, device-reported, derived, and legacy-converted values. A changed seat or pulley setup may warrant a new comparison series.

## Acceptance scenarios for the implementation

- Log a barbell bench set, per-hand dumbbell set, assisted pull-up, 30-second hold, sled carry, and 2 km row without substituting fake reps or weights.
- Record a spring setting, a pneumatic setting, and flywheel inertia without labeling them all kilograms.
- Change machine/setup without overwriting historical context or producing a misleading PR.
- Import a version-1 backup, then export/restore version 2 with all old numeric values and definitions preserved.
- Archive a custom exercise while retaining its completed sessions and backup portability.
- Recover from quota denial, rejected locks, corrupt imports, and simultaneous tab edits using the existing regression suite plus migration-specific cases.
- Validate every published exercise's required equipment, instructions, provenance, aliases, and result profile before counting it as supported.

The research CSVs are inputs to this work, not an automatic production import. Implementing this roadmap is a separate code change from the completed data-layer audit.
