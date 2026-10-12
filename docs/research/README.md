# Gym equipment and workout coverage research

**12 October 2026 · Research and implementation proposal · Runtime library remains 16 exercises**

FORMA can cover a much broader gym through an extensible exercise catalog and several kinds of workout measurements. This research maps **76 equipment families**, **236 exercise candidates** (16 existing and 220 proposed), and **12 measurement profiles**. It is a broad coverage baseline, not a claim to enumerate every machine model, exercise variation, or training system worldwide.

## Deliverables

| File                                                | Use                                                                                                                     |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| [Equipment catalog](equipment-catalog.csv)          | Equipment families, priority, source references, candidate counts, and existing exercise mappings                       |
| [Exercise candidates](exercise-candidates.csv)      | Original candidate names, equipment dependencies, movement families, required measurements, and current/proposed status |
| [Workout formats](workout-formats.md)               | Splits, goals, session formats, set methods, and template requirements                                                  |
| [Implementation roadmap](implementation-roadmap.md) | Schema, migration, content, search, logging, and acceptance criteria                                                    |
| [Sources](sources.md)                               | 22 source records with direct links, evidence scope, and retrieval/licensing limits                                     |

## What the research establishes

Commercial gyms use distinct free-weight, selectorized, plate-loaded, cable, and support-equipment families. A generic “Machine” filter hides meaningful differences. The catalogs also include numerous leg and hip machines beyond a basic leg press. [Life Fitness](https://www.lifefitness.com/en-us/catalog/strength-training), [Precor](https://www.precor.com/en-US/strength).

Functional and specialty areas add suspension systems, rings, sleds, carries, and strongman implements. These need setup, distance, or duration fields. [TRX](https://www.trxtraining.com/pages/quickstart-suspension-trainer), [Rogue strongman](https://www.roguefitness.com/strongman), [Rogue sleds](https://www.roguefitness.com/sleds).

Cardio logs need time and machine-appropriate measurements. Concept2's documented metrics include distance, pace, power, cadence, and intervals. Upper-body ergometers and recumbent steppers broaden equipment coverage for different training needs. [Concept2](https://www.concept2.com/blog/customize-your-data-display-with-ergdata), [SCIFIT](https://www.lifefitness.com/en-us/brands/scifit).

Resistance is not always a mass. Cable ratios can change effective resistance; pneumatic machines, controlled-speed electronic machines, Pilates springs, and inertial flywheels require their own descriptors. For example, Matrix specifies different effective resistance when one or both handles are used. [Matrix](https://ca.matrixfitness.com/eng/strength/multi-station/go-ft-functional-trainer), [Keiser](https://www.keiser.com/fitness-equipment/strength-training/resistance-machines), [EGYM](https://knowledge.egym.com/en/smart-strength/workout-settings/training-methods/isokinetic-training), [Balanced Body](https://www.pilates.com/collections/pilates-apparatus), [Exxentric](https://exxentric.com/how-it-works/advantages/variable-resistance/inertia/).

ACSM's 2026 healthy-adult update emphasizes consistent participation and individualization. Product implication: a large library should help users find suitable exercises and maintain a routine; it should not force complex programs or rank machine training below free weights. This is a product inference, not a personalized training prescription. [ACSM](https://acsm.org/resistance-training-guidelines-update-2026/).

## Current implementation versus coverage target

The baseline is [src/data.js](../../src/data.js), [src/storage.js](../../src/storage.js), and the logging components at commit `288f907`.

| Area               | Current app                                                  | Target from this research                                                       |
| ------------------ | ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| Catalog            | 16 fixed exercises, six equipment labels                     | Stable exercise IDs, equipment families, aliases, user-defined entries          |
| Resistance logging | Kilograms and integer reps                                   | Explicit total/per-hand/per-side load; added load; assistance; machine settings |
| Holds              | Forearm plank uses a documented 10-second-per-rep convention | Real duration, with honest migration of old records                             |
| Cardio and carries | No dedicated distance, pace, or interval model               | Distance/time and optional machine-specific measurements                        |
| Routines           | Three editable starters and custom ordered exercise lists    | Optional split, goal, block, interval, and progression metadata                 |
| Discovery          | Name/muscle/equipment search and filters                     | Availability, movement family, secondary muscles, aliases, setup, favorites     |
| Data scope         | Browser-local routines and logs                              | Continue browser-local use; no account or cloud dependency required             |

No candidate rows have been installed in the runtime library by this research update. Existing logs, backups, and interface behavior remain at the audited version.

## Coverage model

Use independent facets rather than one enormous exercise-name list:

- **Movement:** squat, hinge, lunge/step, push, pull, carry, rotation/anti-rotation, joint isolation, locomotion, balance, mobility, power, and conditioning.
- **Body area:** chest; lats/upper back; spinal extensors; deltoids/rotator cuff; biceps/triceps/forearms; quadriceps/hamstrings/glutes; adductors/abductors; calves/tibialis; abdominal and oblique muscles. These are future review facets, not muscle annotations already validated for every candidate.
- **Equipment:** required implements plus optional supports and attachments. Multiple implements may be necessary for one exercise.
- **Variation:** grip, stance, angle, unilateral/bilateral execution, support, range of motion, and tempo. Keep materially different movements separate; make synonyms searchable without duplicating history.
- **Training context:** goal, split, format, assistance, machine identity, and the user's available equipment.

ACE's library provides a useful precedent for equipment, body-part, and experience facets. The exact model above is FORMA's proposed synthesis. [ACE](https://www.acefitness.org/resources/everyone/exercise-library/equipment/).

Support custom equipment and exercises to handle unusual local machines and new variants. The long tail still includes hydraulic circuits, dedicated neck/tibialis machines, climbing walls, boxing apparatus, pools, vibration platforms, specialty Pilates barrels, and sport-specific rehabilitation systems. These were not individually cataloged or validated in this pass. Thus, no “100% of all gyms” coverage percentage is asserted.

## How to read the catalogs

Both CSV files are UTF-8, with semicolon-separated IDs inside multi-value cells. `source_ids` resolve in [sources.md](sources.md) and indicate **family-level evidence**. Exercise names and movement groupings are original editorial proposals, not individually source-verified coaching instructions.

`equipment_ids` represents a typical setup, not an exhaustive compatibility guarantee. `bench` and `rack` are support dependencies inferred from existing exercises; the current app does not yet store them as separate inventory objects. Machine families deliberately group selectorized and plate-loaded variants where the movement is similar; the future machine instance must distinguish them.

`current` means the exercise exists today; it does not mean the proposed metric model already exists. `current_legacy_hold` identifies the plank convention. `proposed` means unimplemented and awaiting editorial review. `partial` equipment coverage means at least one current exercise maps to that family, not full family support. Candidate counts include supporting equipment and must not be summed to obtain the exercise total.

Priorities are product judgments: **P1** core commercial-gym logging; **P2** conditioning, functional, and accessible coverage; **P3** specialty workflows. Priority is not difficulty, safety, popularity measured from users, or medical suitability. Advanced Olympic lifts can occur on P1 equipment and still require separate technique review.

## Content sourcing decision

Write and review original concise instructions. Commission or license demonstrations with documented rights. wger is a potential structured-data source after checking each entry's license; its code license is distinct from content licenses. Do not assume a repository's permissive license clears every bundled image: free-exercise-db has a documented image-provenance concern. [wger](https://github.com/wger-project/wger/blob/master/README.md), [image licensing discussion](https://github.com/yuhonas/free-exercise-db/issues/2).

The next implementation should begin with measurement types and migration, then common machines, then broader catalogs. Adding hundreds of names to the existing weight/reps schema would produce misleading records for many of the activities researched here.

## Validation of this research package

Checked both CSVs for unique IDs, valid source/equipment references, recognized measurement profiles and priorities, matching per-equipment candidate counts, and exact preservation of all 16 current exercise IDs and names. All checks passed: 76 equipment families, 236 candidates, 220 proposed additions, 12 measurement profiles, and 22 source records. Relative Markdown links, formatting, and whitespace checks passed.

This update changes documentation and research data only. Runtime tests were not repeated for it; the completed audit's 21 unit tests, 86 browser tests, and additional cross-tab stress checks remain recorded in [verification.md](../verification.md). Catalog consistency validation is not equivalent to individual exercise instruction review or physical equipment testing.
