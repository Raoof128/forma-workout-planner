# Native resource provenance

These resources are generated from the existing FORMA web domain, not maintained
as a second catalogue or workspace schema. From the repository root, run:

```sh
node scripts/build-ios-resources.mjs
node scripts/build-ios-resources.mjs --check
node --test --test-isolation=none unit/ios-resources.test.js
```

`catalog.json` preserves all 1,711 currently accepted IDs, while `selectable`
marks the 1,411 reviewed picker entries. Saved legacy IDs remain accepted with
their original measurement units. In particular, the original `plank` still
logs ten-second repetitions; `db-plank` logs seconds. The logging metric comes
from `exerciseById`, independently of a canonical guide's metric.

`seed-workspace.json` is the exact validated version-2 `freshData()` workspace:
all three complete starter routines, no history and no active workout. Fictional
development data is isolated in `ios/Fixtures/parity.json`. The showcase has
12 completed sets, 2,760 kg of external-load volume and 135 seconds of timed
work. Seconds and distance are not converted to load volume.

`resource-manifest.json` records SHA-256 hashes of the source files and generated
outputs. No generation timestamp is inserted, so regeneration is deterministic.
Check mode reports drift without overwriting it.

Each catalogue row retains the reviewed guide's exact source credit under
`source`, its original record's credit under `rawSource`, and any equipment
references under `references`. Keys include `title`, `url`, `author`, `license`,
`licenseUrl` and, where supplied, `modified`. The guide must display those
attributions and modification notices. `catalogue-notices.json` provides the
same per-entry rights inventory for review. Original FORMA instructions remain
separate from third-party instructions; the `description` and reviewed full
`guide` are both retained.

Upstream text includes entry-specific CC BY-SA 3.0/4.0, CC0 and Unlicense
material. Retaining credits does not settle share-alike distribution obligations
or App Store compatibility. Those require review before distribution. This
bridge imports no wger application code and no third-party exercise photographs.
The original generated FORMA site photographs, if separately adopted, have
provenance in `docs/research/site-visuals/`; they are decorative imagery rather
than verified exercise instruction.

`legal.json` preserves the existing website Privacy Policy version 1.3 and Terms
of Use version 1.0 without silently rewriting them. A separate
`nativeGuestNotice` explains this development build's local Application Support
storage, readable JSON exports, the optional FORMA account (what is sent, the
Keychain session, the saved copy, deletion) and lack of analytics. Despite its
key name it covers signed-in use too. The source website policies describe browser/account behavior and
need a reviewed native revision before an App Store submission. This resource
generation does not establish developer eligibility, legal approval or App
Review acceptance.
