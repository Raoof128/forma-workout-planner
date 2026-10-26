# Original FORMA exercise artwork

The owner requested original FORMA illustrations for the entire selectable
exercise catalog, superseding the earlier mixed free-photo approach. The style
uses charcoal/gray equipment and clothing, white backgrounds, subtle shadows and
lime accents. These are AI-assisted original illustrations, not third-party
photographs or claims of exclusive copyright.

As of 23 October 2026, `coverage.json` is the current per-ID record. All 1,411 selectable exercises
have accepted, guide-matched artwork and pass the strict complete-coverage check.
A generated image or a prompt alone does not count as an accepted match. Source
records retain held attempts as review history. The first image release was
deployed on 14 October 2026; see the [release history](../../../CHANGELOG.md).

`registry.json` contains accepted mappings and guide fingerprints. The individual
batch records retain the generation prompt, original generated file, cell
positions and visual-review decisions. Held cells explain equipment, anatomy,
variation or source-guide problems that still need correction. Source text keeps
its existing catalog attribution; the artwork uses factual movement requirements.

Generated source sheets are also archived unchanged in `assets/exercise-artwork`.
`sourceAssetPath` lets registration work after a cloud-session replacement;
`sourceGeneratedPath` records the original generator output location. Pending
sheets in the archive are research assets, not runtime-approved illustrations.

Equipment illustrations can be shared across compatible machine/cardio variants,
as explicitly approved by the owner. Their captions identify them as equipment
references and direct the member to the guide for exact settings and movement.
Free-weight/bodyweight illustrations show a matching representative pose.
Multi-step drills/classes may use a clearly captioned example or starting phase.

The app loads small local WebP atlas previews lazily in library cards and original
PNG artwork immediately in a guide. Preview crops use the same reviewed geometry.
Source and recipe hashes identify preview filenames, with byte hashes for caching.
The builder needs FFmpeg with libwebp only when a new preview is missing; ordinary
Vite builds use committed previews and need no encoder. Full provenance remains
in the original registry and is checked against the smaller runtime manifest.
Atlas cells are displayed with CSS, preserving the generated source files and
image proportions. Image failures leave instructions visible and end the loader.
Generated row boundaries can vary from the requested equal grid. Reviewed batches
support explicit pixel bounds, and accepted equal-grid views have crop reviews.
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
when the runtime manifest is rebuilt. Re-run the strict gate after any guide,
artwork or manifest change; the existing live deployment is unchanged.
