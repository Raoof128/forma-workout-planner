# Exercise logging review

**21 October 2026 · Every selectable exercise reviewed for load and timing**

The owner asked for the weight field to disappear for exercises that have no
external weight (the ab roller, the plank) and for a settable timer on the
plank "and its family" so members need not leave the app. All 1,411 selectable
exercises were read by name, equipment label and guide text, in eight batches
of about 177, and each got one load decision and, when it is timed, a timer
decision. The per-exercise result, with the reason for every call and any
flag, is in [exercise-logging-review.json](exercise-logging-review.json); the
decisions the app reads are in `src/catalog/logging-review.json`.

## Load decisions

| Decision | Meaning in the app                                                   | Exercises |
| -------- | -------------------------------------------------------------------- | --------- |
| `load`   | An implement whose kg is logged (dumbbell, barbell, cable, machine…) | 787       |
| `added`  | Body weight, with optional added kg (dip belt, vest, plate)          | 57        |
| `none`   | No external load: the weight column is hidden                        | 567       |

- **Rules:** judged by what the exercise actually is, not only its equipment
  label. Bodyweight core work, stretches, mobility, foam rolling, plyometrics,
  band and suspension-trainer work, stability-ball moves and cardio machines
  are `none`; the plank is `none` at the owner's request. `added` is used only
  where a weighted version is a common progression: pull-ups and chin-ups,
  dips, standard push-ups, inverted rows, back extensions, glute-ham raises,
  decline sit-ups and crunches, basic glute bridges, calf raises.
- **Consistency pass:** after the batches, families were compared side by side.
  Rarely loaded skill variants (clock, pseudo-planche, three-point,
  side-to-side and Tyson push-ups; typewriter, side-to-side and Rocky pull-ups)
  were set to `none`, matching the archer pull-up and finger push-up; the
  basic glute bridge and hip bridge were set to `added`, matching "Hip Raise,
  Lying".
- **Display only:** a stored set keeps its `weight` (0 when nothing is added),
  so the shared validator, the API and existing data are unchanged. A `none`
  exercise still shows its weight column when one of its sets already carries
  weight, so an older log is never hidden.

## Timer decisions

The hold timer appears on the 213 exercises measured in seconds (`duration`),
including the 30 holds moved to seconds on 21 October (see
[Hold metric migration](#hold-metric-migration)), except 13 whose guides
prescribe repetitions rather than a hold or interval:
Crossover Reverse Lunge, Dynamic Back Stretch, Dynamic Chest Stretch, Elbow
Circles, Frog Hops, Front Leg Raises, Groin and Back Stretch, Groiners, Hip
Circles (prone), Inchworm, Iron Crosses (stretch), Knee Circles and Lower Back
Curl. Reps, distance and cardio (time and distance) exercises have no hold
timer. The one exception is the legacy starter Forearm plank (`plank`, used by
"Lower body foundation"), which keeps its original units of one rep per
10-second hold: its timer moves in 10-second steps and logs one rep for every
full 10 seconds, so its logged sets mean what they always did.

## Catalogue problems found

These were flagged and left unchanged, because changing an exercise's measure
would reinterpret logged sets (see AGENT.md):

- **Holds stored as reps.** Hollow Hold, L-sit (plus foot-supported, straddle
  and tuck), Front Lever and Front lever tuck, Back Lever, Planche Lean Hold,
  Arch Hang, Deadhang, Sloper hanging, Ring Support Hold, Handstand, Elbow
  lever and Sphinx logged reps, so they had no hold timer. All but Arch Hang
  now have timed identities; see the next section.
- **More holds, balances and isometrics stored as reps.** Crucifix, Axe Hold,
  Incline Static Hold, Hercules Pillars, Balance Board, Downward Facing
  Balance, Frog stand balance, Single-leg BOSU balance, Single-Leg Balance
  with Eyes Closed, Kneeling Superman, Hip Raise (Lying), Dynamic side hold,
  Standing Pancake, Recruitment Pulls and Double-Leg Abdominal Press now have
  timed identities too. Seated Knee Extension with Overpressure, Chin tuck,
  Single-Leg Soft-Landing Holds, Back bridge, Estiramiento de brazos y cuello
  and the "Rest (for timed workouts)" placeholder stay in
  reps; see [Second review](#second-review).
- **Intervals stored as reps:** Fast Skipping, Flutter Kicks, Mountain
  Climbers, Jumping Jacks, Foam Roller Anterior tibialis and 90/90 Breathing
  are usually timed but are not holds; they were left for a separate review.
- **Rep drills stored as seconds:** the 13 no-timer exercises above.
- **Misleading equipment labels:** 75 rows, mostly machine, cable or barbell
  lifts labelled Bodyweight. They were classified by the guide.
- **Odd metrics:** for example Box jumps, High knees and Bag training log
  metres; a sled sprint logs time and distance without a load.

## Hold metric migration

**21 October 2026.** Each of the 16 holds above was checked against its guide.
Fifteen describe holding a position (Sloper hanging even says "for a amount of
seconds"), so they moved to seconds. Arch Hang stays in reps: its guide says
"Hold it for time/reps", so counting reps is one of its prescribed measures.
The reason for every call is in `measurementCorrections` and
`excludedMeasurementCorrections` in
[exercise-quality-review.json](exercise-quality-review.json). A second review
the same day moved 15 more; see [Second review](#second-review).

### Approach

Each hold gets a timed identity, `forma-<saved ID>`, with `metric: "duration"`
and the same name, guide (`instructionId`), source, licence and reviewed
illustration. The saved ID becomes a curation alias of it. This is the route
the catalogue review already took for Wall-sit, Parallel Bar Hold, Plate Pinch,
Battle ropes and Diaphragmatic Breathing; `npm run catalog:curate` builds both
from the reviewed corrections.

Options weighed:

- **New timed IDs with an alias (chosen).** Saved IDs keep `load_reps` in
  `exerciseById`, so every saved set, routine and backup validates and reads
  as before, with no schema or validator change. An older API rejects the new
  IDs rather than misreading them, so a wrong deploy order fails safely.
- **A per-set unit marker on the existing IDs.** Every reader of
  `exercise.metric` (the shared validator, volume, records, the API's coach
  summary) would have to become set-aware, saved data would need migrating,
  and one exercise's history would mix units. During a rollout an older API
  would read a new 45-second set as 1 rep.
- **Rewriting saved rep sets or prescriptions as seconds.** That reinterprets
  saved units, which AGENT.md forbids, and what "10 reps" of an L-sit meant
  cannot be known.
- **Reading reps as seconds, like the legacy plank.** Only the plank defines
  how long its rep is (10 seconds).

### What changes for members

- Adding one of these holds (the routine editor's search or exercise library,
  **Add exercise** or **Replace exercise** in a workout) adds the timed
  version: a seconds column, the hold timer and no rep target. Deadhang keeps
  its **ADDED (KG)** column.
- A routine that already lists one of them keeps its rep prescription and
  logs reps, with no timer, until the member switches it. History, volume and
  records count those sets exactly as before, and their guide and
  illustration are the timed version's.
- To switch, the member presses **Use the timed version** under the hold in
  the routine editor (added 21 October 2026, below). Removing and re-adding
  it in a single edit still restores the saved entry, by design.

### Switching a routine entry on request

The editor offers **Use the timed version** on any routine entry whose saved
ID logs reps (`load_reps` in `exerciseById`) while its canonical row is timed
(`metric: "duration"`): the 15 holds above, the 14 October Wall-sit, Parallel
Bar Hold and Plate Pinch, and the earlier timed aliases (foam-roller drills,
Toe Touch, seated figure four, Battling Ropes). It never runs on its own.
Pressing it keeps sets, load, RPE, rest, note, superset and position, and
replaces the rep target with a 60-second target the member can change before
saving. The saved ID becomes the entry's `entryId`, so the row keeps its key.
Saved workouts keep the rep ID and their reps.

Excluded: the legacy `plank` (10-second reps with its own timer), and
seconds-and-metres aliases (Battle Ropes, Rope Jumping, Skipping, Diaphragmatic
Breathing) that already log time, where switching would drop the distance.

A workout card offers the same action in its **⋯** menu. It goes through
**Replace exercise**: the sets start again in seconds, completed rep sets are
discarded only after a confirmation, and the note, RPE and each set's load
stay because it is the same movement. Per-side logging applies to reps only,
so the switch clears it. `src/timedHolds.js` holds the rule;
`unit/timed-hold-switch.test.js` and `tests/timed-hold-switch.spec.js` pin it.

### Second review

**21 October 2026.** The 21 other holds, balances and isometrics flagged in
[exercise-logging-review.json](exercise-logging-review.json) were checked the
same way, one guide at a time, and 15 moved to seconds:

| Exercise                            | Guide says                                                        | Load    |
| ----------------------------------- | ----------------------------------------------------------------- | ------- |
| Crucifix                            | Hold implements out to the sides for time; fail in 30-60 s        | `load`  |
| Axe Hold                            | Hold dumbbells out to the sides as long as you can                | `load`  |
| Incline Static Hold                 | Hold the dumbbells mid-press for 20-45 seconds                    | `load`  |
| Hercules Pillars                    | Stand between two cables under tension and hold                   | `load`  |
| Dynamic side hold                   | Hold a kettlebell at the side on one leg, switching legs          | `load`  |
| Hip Raise, Lying                    | Raise the hips and hold as long as you can                        | `added` |
| Balance Board                       | Hold the balance for as long as desired                           | `none`  |
| Downward Facing Balance             | Lie on a ball, walk the hands out, lift the legs; no reps or time | `none`  |
| Frog stand balance                  | (Reviewed guide) feet lifted, hold briefly with control           | `none`  |
| Single-leg BOSU balance             | Hold for 10-20 seconds                                            | `none`  |
| Single-Leg Balance with Eyes Closed | Hold for the prescribed time, then switch legs                    | `none`  |
| Kneeling Superman                   | "Unilateral and static hold"                                      | `none`  |
| Standing Pancake                    | Wide straddle, fold at the hips; no reps                          | `none`  |
| Recruitment Pulls                   | Max-effort pull for 3-5 seconds, one arm at a time; no reps       | `none`  |
| Double-Leg Abdominal Press          | Hold for 10 seconds of maximum effort                             | `none`  |

Six stay in reps, with the reason under `excludedMeasurementCorrections`:

- **Seated Knee Extension with Overpressure:** hold each press about three
  seconds and repeat for the prescribed number of repetitions.
- **Chin tuck:** hold 5 seconds, return and repeat.
- **Single-Leg Soft-Landing Holds:** hold each landing up to 2 seconds, reset
  and repeat.
- **Back bridge:** the guide pushes up into the bridge and lowers with a slow,
  controlled descent, and never says to hold the position or for how long.
- **Estiramiento de brazos y cuello:** the guide only says the stretch eases
  upper-body tension; it describes no position or hold, so one cannot be
  confirmed. It needs a guide repair first.
- **Rest (for timed workouts):** a rest placeholder, not a hold. Whether to
  time it, remove it or leave it is a separate product decision.

The loaded holds keep their **WEIGHT (KG)** column beside the seconds, and
Hip Raise (Lying) keeps **ADDED (KG)**. The five one-side-at-a-time holds
(the two single-leg balances, Kneeling Superman, Dynamic side hold and
Recruitment Pulls) keep their reviewed side in `src/catalog/unilateral.json`
under the timed ID, as the timed stretches do. Frog stand balance keeps its
reviewed guide repair, which the curation builder now applies to the timed
ID. Members see the same changes as in the first review: new selections log
seconds, and saved rep logs and routines keep counting reps.

### Deploying

The API validates exercise IDs against the catalogue it bundles
(`src/catalog/curation.json` and `src/catalog/machine-exercises.json` are in
`ops/Dockerfile`), so an older API rejects a workspace that contains a timed
hold. Deploy the API before the frontend in each environment: staging API,
then staging frontend; production API, then production frontend.
`src/storage.js` and `src/exerciseMetrics.js` are unchanged.

Rolling back is not safe once anyone has saved a timed hold. The API
re-validates stored workspaces when it reads them, so an older API image
cannot load that member's workspace, and an older frontend sends a guest's
saved data to the recovery screen. Fix forward instead of rolling back.

## Keeping it current

`unit/exercise-load.test.js` fails if any selectable exercise is missing from
the review, listed twice, or unknown, and if a no-timer entry is not a timed
exercise. A catalogue import therefore needs its new rows reviewed and added
to `src/catalog/logging-review.json`.

`unit/hold-metric-migration.test.js` pins each migrated hold: the saved ID
keeps `load_reps` and no timer, the timed ID is the one offered, both share a
load class, guide and illustration, saved rep sets keep their values, text and
volume, and a completed timed set needs its seconds. Another timed identity
follows the same steps: add a reviewed entry to `measurementCorrections`, run
`npm run catalog:curate`, move its decision in `src/catalog/logging-review.json`
to the new ID, give it the saved ID's side in `src/catalog/unilateral.json` if
it has one, carry its artwork entry in
`docs/research/original-art/registry.json` and run
`node scripts/build-exercise-media.mjs`.
