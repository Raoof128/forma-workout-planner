# Workout formats and template coverage

This is a proposed product model, not a set of individualized training prescriptions. Splits, goals, and session formats are independent: an upper/lower split can serve strength or hypertrophy and can use ordinary sets or supersets. Keep these dimensions separate in the data model.

ACSM's current summary supports individualization and consistent resistance training in healthy adults; it does not prescribe the exact template library below. CrossFit's glossary supports the AMRAP, EMOM, and interval terminology. The remaining structures are original product requirements. [ACSM 2026](https://acsm.org/resistance-training-guidelines-update-2026/), [CrossFit glossary](https://www.crossfit.com/essentials/crossfit-terms-explained).

## Planning dimensions

| Dimension       | Coverage                                                                                       | Data needed                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| Weekly split    | Full body, upper/lower, push/pull/legs, body-part split, custom rotation                       | Ordered routine cycle; optional weekdays; recovery-day labels                          |
| Goal            | General fitness, strength, hypertrophy, muscular endurance, power, aerobic endurance, mobility | User-selected goals; optional reviewed defaults; editable targets                      |
| Training mode   | Free weights, machines, bodyweight, mixed equipment, accessible setup                          | Available equipment; substitutions; setup notes                                        |
| Sport emphasis  | Powerlifting, Olympic lifting, strongman, functional fitness, hybrid conditioning              | Movement standards and attempts/rounds/segments where relevant                         |
| Session segment | Warm-up, skill practice, primary work, accessories, conditioning, cool-down                    | Ordered blocks with different measurement and timer rules                              |
| Progression     | Fixed targets, rep-range progression, load progression, deload, custom plan                    | Planned versus performed values; optional RPE/reps-in-reserve; explicit change history |

## Session and set methods

| Format                          | Log structure and score                       | Implementation requirement                                        |
| ------------------------------- | --------------------------------------------- | ----------------------------------------------------------------- |
| Straight sets                   | Individual load/reps or duration results      | Existing baseline, extended to typed results                      |
| Warm-up and working sets        | Separate role on each set                     | Volume and PR filters must respect role                           |
| Superset / paired sets          | Two exercises share an ordered round          | Group identity, per-exercise result, shared rest                  |
| Tri-set / giant set / circuit   | Several exercises in a repeating block        | Round and sequence, independent result types                      |
| Drop set                        | Linked effort segments with changing load     | Segment order; retain each load and rep count                     |
| Rest-pause / cluster            | Linked short efforts and intra-set rests      | Rest timing within a parent set                                   |
| Pyramid / reverse pyramid       | Planned changes between sets                  | Per-set targets, no invented total score                          |
| Tempo / pause                   | Repetition phase or hold annotations          | Optional tempo and pause seconds; no automatic coaching inference |
| AMRAP                           | Rounds plus additional reps within a time cap | Round definition, completed reps, time cap                        |
| EMOM / repeating start interval | Work starts on interval boundaries            | Start interval, completion, skipped/unfinished work               |
| For time / chipper              | Complete an ordered amount of work            | Elapsed time, time cap, unfinished work, substitutions            |
| Work/rest intervals             | Repeated timed efforts and recovery           | Work duration, recovery duration, repeats, per-effort metrics     |
| Steady cardio                   | One continuous effort                         | Duration plus optional distance and machine settings              |
| Mixed cardio/strength           | Ordered runs/ergs/carries/sets                | Typed segments and transitions, not a single tonnage total        |
| Isometric holds                 | Duration with optional load                   | Time result; no artificial rep conversion                         |
| Mobility / Pilates / balance    | Duration or reps with setup                   | Spring/band/support context; no strength PR by default            |

A Tabata preset can represent eight 20-second work periods with 10-second recoveries, as described in the CrossFit glossary; arbitrary intervals should remain configurable. A HYROX-style planner requires alternating running and stations, but official competition targets must be linked to a verified season/division rulebook before publication. The searched 2025/26 rulebook is insufficient to assert current 2026/27 standards. [CrossFit](https://www.crossfit.com/essentials/crossfit-terms-explained), [HYROX race overview](https://hyrox.com/the-fitness-race/).

## Proposed starter-template backlog

These are layouts to author and review after metric support lands; no default loads or personalized intensity are implied.

| Template                    | Movement coverage                                           | Prerequisites                                                    |
| --------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------- |
| Full-body A/B               | Knee-dominant, hinge, push, pull, core                      | P1 catalog; alternating-routine support                          |
| Upper/lower                 | Horizontal/vertical push and pull; squat/hinge; accessories | P1 machines and free weights                                     |
| Push/pull/legs              | Presses and triceps; pulls and curls; lower body            | Editable weekly cycle                                            |
| Machine-based full body     | Leg press/curl, chest press, row/pulldown, core             | Machine identity and setup                                       |
| Dumbbell-only               | Squat/lunge, hinge, press, row, carry                       | Per-hand convention; distance logging                            |
| Bodyweight / bands          | Squat/lunge, push/pull, core, band work                     | Resistance labels and timed holds                                |
| Strength practice           | Main lift attempts plus assistance work                     | Set roles; failed attempt logging; comparable PR rules           |
| Power and lifting technique | Selected lift progressions with full recovery               | Reviewed advanced instructions; no automatic prescription        |
| Cardio steady / intervals   | Bike, treadmill, erg, or accessible cardio                  | Time/distance and interval blocks                                |
| Functional circuit          | Carry, sled, erg, bodyweight, ball work                     | Mixed metrics and round scoring                                  |
| Mobility / recovery         | Selected mobility movements and holds                       | Duration and side-specific setup                                 |
| Accessible gym session      | User-selected supported press/pull and erg                  | Specific equipment configuration; no diagnosis-based assumptions |
| Pilates apparatus session   | Reviewed reformer/tower/chair sequence                      | Spring settings and specialist content review                    |

Substitutions should match a user's goal, available equipment, and supported movement, then let the user choose. A machine row and dumbbell row can be useful alternatives without having equivalent loads or interchangeable personal records. Accessibility is a property of the particular setup and user requirements, not a universal “easy” exercise label.
