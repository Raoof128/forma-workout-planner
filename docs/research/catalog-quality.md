# Catalog quality and machine coverage

Reviewed **14 October 2026, Australia/Sydney**.

The library and routine picker now offer **1,414 selectable movements**, backed
by 1,681 compatibility records. All 1,661 previously published IDs and their
original measurement types remain valid for saved routines, workouts and backups.
The smaller browsing count reflects consolidation and guide review, rather than
deletion of member data.

## Duplicate review

The original importer compared punctuation-folded names and a small synonym list.
It missed singular/plural, word-order, translation, editorial-suffix and equipment
aliases. The review identifies **180 groups containing 240 duplicate entries**.
Only established equivalences are consolidated. Grip, angle, stance, unilateral,
equipment and range differences stay separate; 86 reviewed variant families and
50 uncertain families are recorded in [the review](exercise-quality-review.json).

Each browsing representative carries the other names as searchable aliases.
Compatibility lookup retains the original objects. Guide lookup can use a better
source within a group while keeping that source's author, licence and full-text
ID. The picker recognizes older alias IDs as selected and restores every cached
alias prescription and its position when the group is removed and re-added.

The legacy plank keeps its ten-second-per-rep convention in saved data; new
selections use the existing timed plank ID. Five new IDs represent corrected
timed measurement profiles without reinterpreting historical records. On
21 October 2026 thirty more were added the same way, in two reviews, for
holds, balances and isometrics that had been stored as reps; the 1,411
selectable movements of that date are backed by 1,711 compatibility records (see
[the hold metric migration](exercise-logging-review.md#hold-metric-migration)). The old
“Air Bike” describes a bicycle crunch; its browsing label now says so, while the
new fan-bike entry represents the cardio apparatus.

## Guides and equipment

The importer's length-only check previously admitted 29 boilerplate descriptions.
Reviewed equivalents replace eight of them, one gets a complete original guide,
and the remaining 20 stay outside browsing. They remain readable as compatibility
records; their old guide screen honestly states that no usable source guide exists.
Future imports reject known boilerplate and retain published archival IDs.

Equipment synonyms are normalized and reviewed cable/machine metadata is
corrected. Specific stations augment broad Machine and Cable filters. The review
caught and fixed a too-broad station-name rule: barbell hack squats, elastic-band
leg curls and butterfly floor exercises retain their actual equipment. The
band-described “Cable External Rotation” resolves to the equivalent band exercise.

Six machine guides were rewritten with original setup/execution instructions.
Fifteen distinct machine movements were added: Smith Romanian deadlift, cable
hip abduction, seated machine back extension, rotary torso, assisted machine
chin-up, fan bike, upper-body ergometer, recumbent stepper, machine pullover,
forward V-squat, tibialis machine, grip machine and three four-way-neck directions.
Their initial external load is zero. Assisted movements log repetitions; machine
counterweights are explicitly excluded from lifted kilogram volume.

Original FORMA guide wording is separate from manufacturer references. The
references establish equipment identity/family; they do not claim vendor-authored
coaching text or permission to copy vendor photography. Existing licensed
instructions keep their own attribution. No images were imported in this correction.

## Coverage evidence and remaining boundaries

The [machine manifest](machine-coverage.json) enumerates all 76 families from the
earlier research: 34 outside the machine audit, 26 represented, eight with reviewed
additions and eight requiring unsupported specialty measurements. Five additional
machine families were checked. This is a source-backed family review, not a claim
that every commercial model or exercise variation worldwide is represented.

Model-specific flywheel, pneumatic, adaptive-resistance, Pilates and other special
measurements remain explicit in the manifest. Similar equipment names do not
authorize kilogram or distance conversion. Fetch successes, failures and redirect
destinations are retained in [source evidence](machine-source-fetches.json).

## Reproduction and validation

```sh
npm run catalog:curate
npm run test:unit
npm run docs:check
```

After a source refresh, retain all published IDs, rerun curation and review changed
guides and newly added movements before publishing. The generated
[summary](catalog-quality-summary.json) separates selectable movements from
compatibility records. Metadata and reviewed original guides live in the JSON
files alongside this report.

Verification passed: 60 unit, 46 PostgreSQL API, 20 gateway Worker tests and 57
affected browser cases across Chromium, Firefox and WebKit. Tests cover actual
guide quality, equipment distinctions, alias search, machine selection, preserved
backup units and multiple old alias prescriptions. The compiled Node 26 image
validates all 20 new IDs and runs as UID 10001. Existing data is validated on the
private host during deployment without exporting member rows.

## Live release

Both APIs use `forma-api:catalog-curation-20261014` from source commit `9f0629d`.
The image config digest is
`1c56e8281de12aba07b01c81b7684b9a9f81a98a501a46d3b2c7d8f741906966`;
the Droplet's OCI manifest digest is
`b8d348ecce66f3864f9cde133e652c70a6d2999e6fe77483b6373f4e2adbcbc5`.
Each project was backed up before and after its API replacement. All new IDs and
existing workspaces validated; unrelated running container IDs stayed unchanged.

The matching frontends include a follow-up wording correction removing an internal
exercise ID from the fan-bike guide. That presentation-only note change does not
alter API exercise identities or validation; the API image remains the version
above. Current Worker versions:

- Public: `af5e7b21-e2f0-42fe-b30f-4b47569a0264`.
- Private staging: `3fdc322e-f433-4fbf-808e-ecebf82be97e`.

Live browser checks found 1,414 movements, consolidated Hammer Curl results,
corrected machine filtering and complete attributed guides. Public layouts fit
320 px and 390 px widths. Both gateways returned health 200 and anonymous
workspace 401, with no browser page errors. Private staging account forms rendered.
The public wording correction was verified after its final deployment. No member
account or workspace data was changed by these checks. Temporary Access policies
and smoke/deployment tokens were removed or revoked.

Follow-up [photo research](exercise-photos.md) records candidate coverage and
asset-specific matching/rights checks separately from this live catalog release.
