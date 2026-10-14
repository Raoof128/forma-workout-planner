# Original FORMA exercise artwork

The owner requested original FORMA illustrations for the entire selectable
exercise catalog, superseding the earlier mixed free-photo approach. The style
uses charcoal/gray equipment and clothing, white backgrounds, subtle shadows and
lime accents. These are AI-assisted original illustrations, not third-party
photographs or claims of exclusive copyright.

`coverage.json` is the current per-ID progress record. Its scope must remain all
1,414 selectable exercises. Unmatched movements remain pending; a generated
image or a prompt alone does not count as an accepted exercise match. No image
release has been deployed during generation.

`registry.json` contains accepted mappings and guide fingerprints. The individual
batch records retain the generation prompt, original generated file, cell
positions and visual-review decisions. Held cells explain equipment, anatomy,
variation or source-guide problems that still need correction. Source text keeps
its existing catalog attribution; the artwork uses factual movement requirements.

Equipment illustrations can be shared across compatible machine/cardio variants,
as explicitly approved by the owner. Their captions identify them as equipment
references and direct the member to the guide for exact settings and movement.
Free-weight/bodyweight illustrations show a matching representative pose.
Multi-step drills/classes may use a clearly captioned example or starting phase.

The app loads local artwork lazily in library cards and immediately in a guide.
Atlas cells are displayed with CSS, preserving the generated source files and
image proportions. Image failures leave instructions visible and end the loader.
The current checkpoint still needs crop review: generated row boundaries can
vary from the requested equal grid. Explicit pixel bounds and rendered-cell
checks are required before releasing the complete library.
Saved exercise aliases still resolve through the existing canonical-guide logic.
Exercise IDs, logging units, account data and backend services are unchanged.

After a recorded visual review, register a batch and rebuild the local manifest:

```sh
node scripts/register-exercise-atlas.mjs docs/research/original-art/<batch>.json
node scripts/build-exercise-media.mjs
node scripts/check-exercise-media.mjs
```

Before describing the library as complete, the strict release check must pass:

```sh
node scripts/check-exercise-media.mjs --require-complete
```

It verifies full coverage, local assets, original-art status, byte hashes, cache
versions and atlas geometry. A changed guide invalidates its previous review
when the runtime manifest is rebuilt. Generation/review remains in progress until
every ID passes; the existing live deployment is unchanged meanwhile.
