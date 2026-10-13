# Runtime exercise catalog

[Research index](README.md) · [User guide](../user-guide.md)

The current library offers **1,414 reviewed selectable movements**; see the
[catalog quality correction](catalog-quality.md) for duplicate review, guide
quality and machine coverage. All 1,661 previously published IDs remain compatible,
and 20 new records cover missing machines and corrected timed measurements.

The original imported catalog contained **1,661 exercises**: 16 original movements with their IDs
and names unchanged, 858 additional Free Exercise DB entries, 654 additional
pinned wger entries, and 133 additional entries from the current wger API.
Normalized names and known legacy synonyms are deduplicated. This is measured
coverage of the sources below; new variations and workout combinations do not
have a finite worldwide inventory.

## Sources and content rights

| Source                                                                        | Snapshot                                                       | Imported content                                                                    |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [Free Exercise DB](https://github.com/yuhonas/free-exercise-db)               | `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`, 876 source records | Text and taxonomy under the source's Unlicense/public-domain declaration; no images |
| [wger fixtures](https://github.com/wger-project/wger)                         | `d09dd5e50e7dbeafe492b1a9b7c5cb1f1e89c73e`                     | English text with each entry's own CC licence and author                            |
| [Current wger API](https://wger.de/api/v2/exerciseinfo/?language=2&limit=100) | 13 October 2026, all 925 advertised records paginated          | 133 extra complete, licensed English guides                                         |

The first current API pass found 676 records already represented and 116 with
insufficient descriptions; it added 133. A second pass retained those 133,
found 809 already represented, and added zero. No records in this API snapshot
were excluded for missing English or unrecognised licences. The saved report
records per-page hashes and dispositions; it is not a claim that all source
records are suitable coaching instructions.

Each imported guide includes its source URL, author, licence URL and adaptation
notice. HTML was removed and equipment, muscle and measurement labels were
normalised. CC BY-SA adaptations remain under the corresponding entry's
licence; source and adapted text are available in the checked-in JSON files.
wger's AGPL software licence was not treated as its content licence; no wger
application code was imported. Free Exercise DB images were excluded because
their provenance needs separate review. No demonstration images or videos were
copied. Sources are not endorsements or personalised exercise prescriptions.

## Reproduce and refresh

```sh
NODE_USE_ENV_PROXY=1 npm run catalog:sync
NODE_USE_ENV_PROXY=1 node scripts/snapshot-current-exercises.mjs
NODE_USE_ENV_PROXY=1 npm run catalog:sync
npm run catalog:curate
npm run test:unit
```

`catalog:sync` fetches pinned source files and records their SHA-256 hashes in
[catalog-import.json](catalog-import.json). The current API supplement and its
page hashes are in [current-wger-additions.json](current-wger-additions.json).
The supplement retains previously published IDs if the live source changes or
removes a record. A fetch/pagination failure does not replace the supplement.
Review source changes and tests before publishing a refreshed catalog.

## Measurements and limits

New exercises use load/reps, time with optional load, time/distance, or
load/distance. Search covers aliases, muscle names, equipment and activities,
including punctuation and diacritic variants. Cards are paginated and full
instructions load on demand. Twelve reusable templates supplement the three
original starters; imported movements start at zero load for the user to edit.

Seconds and metres do not contribute to kilogram volume or estimated 1RM.
The original plank keeps its legacy ten-second-per-rep convention so existing
history is not reinterpreted. Version 1 backups preserve optional time and
distance fields. A workout still has at most 100 exercises; expanding the
catalog did not relax aggregate workspace bounds.

Specialised measurements such as flywheel inertia, pneumatic resistance and
machine-specific calibration from the original research remain unimplemented.
Custom routine composition is supported; user-defined catalog entries,
automatic coaching and device integrations are not implemented. The new IDs
require the matching API version before the private account frontend is updated.
