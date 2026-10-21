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

The hold timer appears on the 183 exercises measured in seconds (`duration`),
except 13 whose guides prescribe repetitions rather than a hold or interval:
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
  lever and Sphinx log reps, so they get no hold timer. Giving them one needs
  a reviewed metric migration.
- **Rep drills stored as seconds:** the 13 no-timer exercises above.
- **Misleading equipment labels:** 75 rows, mostly machine, cable or barbell
  lifts labelled Bodyweight. They were classified by the guide.
- **Odd metrics:** for example Box jumps, High knees and Bag training log
  metres; a sled sprint logs time and distance without a load.

## Keeping it current

`unit/exercise-load.test.js` fails if any selectable exercise is missing from
the review, listed twice, or unknown, and if a no-timer entry is not a timed
exercise. A catalogue import therefore needs its new rows reviewed and added
to `src/catalog/logging-review.json`.
