# Exercise photo feasibility

Reviewed **14 October 2026, Australia/Sydney**, against the corrected 1,414-movement
catalog. This is research and an asset-review inventory, not a deployed image
feature. No third-party exercise images were copied into the site.

Exercise-specific photos can be added, but the sources checked do not establish
exact, licensed photo coverage for every FORMA movement. A same-name result, API
exercise relationship or muscle match cannot supply that guarantee. Equipment,
grip, angle, stance, assistance and unilateral variations need individual review.

## Audited coverage

The public wger API returned all **932 exercise records**, **383 image records**
and five licence records, with no remaining pagination. FORMA IDs use wger's
**exercise base UUID**, not translation UUID. Images join to that base UUID;
already reviewed duplicate groups may share candidates. No new name-based or
variation-group equivalences were introduced for this research.

| Measure                                                    | FORMA movements |
| ---------------------------------------------------------- | --------------: |
| Reviewed selectable catalog                                |           1,414 |
| Have a wger identity in their reviewed group               |             684 |
| Have any identity-linked wger image                        |             205 |
| Have an image declared `Photo`                             |             164 |
| Have a declared photo with no AI flag                      |             136 |
| Have a declared photo, no AI flag and attribution metadata |             106 |
| Have no image from this audited identity-linked source     |           1,209 |
| Photos approved for publication by this audit              |               0 |

These are **metadata candidate counts**, not confirmed photograph, technique or
rights coverage. See the [per-movement inventory](exercise-photo-inventory.json),
which retains asset licence and author fields separately from guide attribution.
Every asset remains unapproved. Source-response SHA-256 values and complete
pagination observations are recorded in that inventory.

## Visual checks explain why automatic matching fails

Five fetched assets were visually inspected. A sixth, an AVIF adductor image,
could not be decoded by the inspection tool and remains unreviewed.

| Candidate                | Observed content                                  | Decision                                                          |
| ------------------------ | ------------------------------------------------- | ----------------------------------------------------------------- |
| Alternate Hammer Curl    | Drawing despite `Photo` metadata                  | Exclude from photo selection; grip/provenance review also pending |
| Bodyweight Arabesque     | Drawing of a single-leg hinge holding weights     | Exclude for this bodyweight movement                              |
| Narrow Leg Press         | Drawing despite `Photo` metadata                  | Exclude from photo selection; stance review pending               |
| Flat Barbell Bench Press | Line drawing correctly identified as illustration | Illustration candidate only; not a photo                          |
| Dumbbell Goblet Squat    | Genuine photo with heels raised on a plate        | Variant and source/model-rights review pending                    |

Contributor names and a false AI flag do not prove authorship or release rights.
The photographs and illustrations therefore cannot be bulk-approved from their
API labels. A static photo also cannot verify the complete execution of an exercise;
start/end views or a reviewed demonstration video are preferable for technique.

## Internet sources and rights

| Source                                                                               | Useful finding                                                                         | Current suitability                                                                  |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| [wger image API](https://wger.de/api/v2/exerciseimage/?limit=1000)                   | Exercise UUIDs, image-specific licence/author fields, art style, AI flag               | Candidate source requiring visual and provenance review; partial coverage            |
| [Free Exercise DB image issue](https://github.com/yuhonas/free-exercise-db/issues/2) | Maintainer says image origin and royalty-free status are unknown                       | Excluded from bulk image import                                                      |
| [ExerciseDB V2 / AscendAPI](https://docs.ascendapi.com/products/edb-v2/overview.md)  | Provider advertises 11,000+ exercises, 20,000+ images, multiple resolutions and videos | Potential broader provider; actual FORMA variant coverage and plan rights unverified |
| Manufacturer machine pages from the [machine audit](machine-coverage.json)           | Establish machine identity and setup references                                        | Public viewing does not grant photo reuse; need explicit image permission            |
| GymVisual and ACE exercise library                                                   | Relevant specialist sources                                                            | Requests denied with HTTP 403; current reuse terms not verified                      |
| Original commissioned photography                                                    | Can depict FORMA's exact setup and equipment                                           | Best way to fill remaining gaps with documented creator and model permissions        |

The inspected wger images declare **CC-BY-SA 3.0 or 4.0**. Their licences come
from each image record, not the exercise description or wger's software licence.
Preserve source, actual creator, licence link and change notices; comply with the
asset's ShareAlike conditions where applicable. Blank fields or unclear provenance
require clarification rather than substituting the text guide's author. Licence
deed requests returned HTTP 403 during this research, so the audit does not claim
fresh inspection of their full legal text.

Free Exercise DB's text Unlicense does not settle third-party photo rights. Its
maintainer explicitly states, “I actually have no idea where the images are from
or if they are royalty free.” A later comment points to an
[upstream rights question](https://github.com/wrkout/exercises.json/issues/305).

### Current ExerciseDB developer documentation

The old `docs.exercisedb.dev` URL redirects to AscendAPI's current documentation.
Its V2 product page says free media is watermarked and paid media is clean. The
[get-by-ID endpoint](https://docs.ascendapi.com/api-reference/exercisedb-v2/exercises/getexercisebyid.md)
provides stable exercise IDs and multiple image resolutions, which makes an
explicit FORMA-to-provider mapping possible.

The [caching policy](https://docs.ascendapi.com/guides/caching.md) is consequential:

- Caching is permitted only when the selected plan explicitly allows it.
- Media URLs rotate every Monday at 00:00 UTC. Never store them permanently.
- Allowed caches must expire before that rotation; plans without caching require
  fresh requests. Exercise IDs remain stable.
- Standard plans reference provider CDN URLs. Persistent storage, bulk download
  and custom hosting require a separate arrangement.

The GitHub repository's AGPL software licence does not demonstrate unrestricted
rights to its hosted media. The separate terms link returned HTTP 403. No plan
was purchased and no new provider account was created. Provider scale and quality
claims are documented claims, not an independently verified inventory of FORMA
matches. See [fetch evidence](exercise-photo-source-fetches.json), including
failed requests and bot-challenge pages; HTTP 200 alone was not treated as usable
documentation.

## Recommended implementation

1. Keep a separate approved-media manifest keyed by canonical FORMA exercise ID.
   Record provider exercise ID, exact variation, source asset ID, creator, licence,
   permission evidence, review outcome and review date. Resolve saved aliases
   through the existing reviewed mapping without changing workout data.
2. Review the actual asset against the full guide: equipment/station, grip and
   attachment, bench angle, stance, assistance, side and range of movement. A
   similar muscle target or commercial machine name is insufficient.
3. Use properly attributed approved open assets where available. Fill gaps with
   an appropriately licensed provider or commissioned original photos. Check
   rights to display, transform, cache and redistribute before choosing delivery.
4. Publish approved assets only. Keep the current honest exercise icon when no
   exact asset is approved; do not substitute generic stock or invented AI poses.
5. Use responsive, lazy-loaded thumbnails with reserved dimensions and useful
   alt text. Show attribution with the guide. If using AscendAPI, retrieve rotating
   URLs through a credential-protected backend and obey the selected plan's cache
   policy; never ship provider credentials to browsers.
6. Track photo coverage separately from catalog completeness. Claim full coverage
   only after every selectable movement has an individually accepted asset and
   documented reuse rights. Machine additions remain separate entries until
   matching assets are supplied.

The inventory was checked against every selectable exercise ID, its reviewed
source-group UUIDs and each fetched asset's own licence. All 1,414 IDs occur once,
all 205 linked-image counts reproduce, and no candidate is marked approved.
