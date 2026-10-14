# Expanded exercise-photo search

Reviewed **14 October 2026, Australia/Sydney**, against FORMA's 1,414 selectable
movements. This extends the [first photo audit](exercise-photos.md). Research
changed no application behaviour or member data; no media was deployed, provider
account created, subscription purchased or licensing enquiry sent.

## What the wider search found

- **25 freely offered exercise demonstrations with photo thumbnail URLs** from
  YMove: 11 studio/free-weight movements and 14 machine/cable movements. Eight
  thumbnails were downloaded and visually inspected.
- **12 Wikimedia Commons files shortlisted and visually inspected**. Five are
  preferred movement candidates; the others need a different variation, licence
  clarification or exclusion.
- **10 distinct FORMA exercise IDs have preferred visual candidates** across
  those inspected subsets. This is a review shortlist, not publication approval.
- Additional commercial photo/video providers: YMove's wider library,
  Hyperhuman, WorkoutDB and Physitrack. Their catalog totals and marketing claims
  do not establish exact coverage of FORMA's variants.

The [expanded inventory](exercise-photo-expanded-inventory.json) records all 25
free demonstrations and 12 Commons candidates, original asset/source URLs,
candidate FORMA IDs, rights evidence and individual review findings. None is
marked approved for publication. Do not add 37 files or 10 shortlisted IDs to the
earlier 205-movement wger count: sources overlap and assets differ in suitability.

## Most useful new source: YMove's free set

[The free collection](https://ymove.app/free-exercise-videos) explicitly permits
commercial use in apps, websites, social media and client materials, with no
signup or payment. Attribution is appreciated but optional. Reselling or
redistributing the clips as a standalone product/library is prohibited.

The page's structured data enumerates exactly 25 VideoObjects, each with a public
video URL and photo-thumbnail URL. The source page was modified 10 October 2026;
the structured upload dates are 1 August 2026. These are provider-supplied dates.

Machine/cable entries include lat pulldown, close-V-bar seated cable row, seated
machine chest press, mid cable crossover, cable lateral raise, rope face pull,
rope cable curl, cable triceps pushdown, overhead rope extension, leg extension,
leg press, lying leg curl, machine glute kickback and high-to-low cable woodchop.
Studio entries include squat, bench press, deadlift, lateral raise, hammer curl,
dumbbell row, goblet squats and kettlebell movements.

Seven inspected thumbnails have relevant setups for existing FORMA entries:
barbell back squat, barbell bench press, dumbbell lateral raise, hammer curl,
front lat pulldown, machine leg extension and leg press. Complete action, grip,
stance and machine variation still require full-clip review. A hammer-curl start
frame cannot establish simultaneous versus alternating action.

**One inspected thumbnail is on hold:** “Glute Kickback Machine” shows apparatus
labelled **Standing Leg Curl**, with a pad setup suggesting knee flexion. Do not
map it to a hip-extension kickback from its title. Review the full demonstration
and equipment before use.

The inspected thumbnails carry Your Move branding even though the free page
describes watermark-free video downloads. Preserve visible branding; do not
assume rights to remove it. The free grant clearly addresses clips and edits;
this research does not independently clear standalone thumbnail/still reuse.
Use the offered video licence as documented and establish the still-image scope
before treating these JPEGs as permanent FORMA photo assets.

### Wider paid library

[YMove's library page](https://ymove.app/exercise-video-library) currently lists
**1,413+ demonstrations**, with photo thumbnails, instructions and machine,
cable, free-weight and bodyweight coverage. That total being close to FORMA's
1,414 does not mean only one exercise is missing: the two catalogs use different
movement and variation definitions.

The [API pricing](https://ymove.app/exercise-api/pricing) and
[terms](https://ymove.app/terms-and-conditions) describe brand registration,
subscription-dependent use, time-limited media URLs, restrictions on redistribution
and separate self-hosting rights. Product-page white-label descriptions and
terms differ on some plan entitlements; the exact purchased agreement must
settle those before integration. The free 25-clip grant is described separately.

## Wikimedia Commons: specific photo candidates

The wider search produced 78 distinct JPEG/WebP-format search hits, many of which
were unrelated scenes, empty apparatus, historical scans or unsuitable variants.
That number is not exercise-photo coverage. Searches were bounded and retained
continuation markers rather than claiming a complete Commons inventory.

Preferred candidates from actual visual inspection:

| Movement           | File/source                                                                                                   | Declared licence | Review detail                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------- |
| Front lat pulldown | [Lat pulldown photo](https://commons.wikimedia.org/wiki/File:Girl_doing_lat_pulldown_exercise.jpg)            | CC BY 2.0        | Person using the front cable pulldown; inspect grip/full clip if available |
| Seated leg press   | [Leg press photo](https://commons.wikimedia.org/wiki/File:Young_man_using_a_leg_press_machine_at_the_gym.jpg) | CC BY 2.0        | Legs and machine are visible; crop excludes supported back                 |
| Forearm plank      | [Forearm plank photo](https://commons.wikimedia.org/wiki/File:Girl_exercising_doing_a_plank.jpg)              | CC BY 2.0        | Forearm support matches the guide                                          |
| Side plank         | [Side plank photo](https://commons.wikimedia.org/wiki/File:Girl_exercising_side_plank.jpg)                    | CC BY 2.0        | Forearm support, stacked feet and raised top arm                           |
| High plank         | [High plank photo](https://commons.wikimedia.org/wiki/File:Plank.jpg)                                         | CC BY-SA 3.0     | Straight-arm support; excluded for the forearm-plank entry                 |

These files have their own licence/artist metadata. Several request a PTPioneer
link as well as photographer credit; retain the complete attribution evidence
in the inventory rather than inventing it from a guide author. They remain
candidates for image placement and final rights review.

Other inspected findings:

- “Amer Lat Pulldown” shows a **behind-neck** pull, not the standard front pull.
  Its descriptive text declares CC BY 4.0 while the structured licence declares
  CC BY-SA 4.0. Hold the asset until that discrepancy is clarified.
- “Marian Leg Press” shows a vertical setup and has the same licence discrepancy.
  No exact vertical-machine guide was mapped in this research.
- “Bench press.webp” is an **empty bench/rack**, not an execution photo.
- “Eibl. bench press” shows a pronounced powerlifting arch rather than an accepted
  illustration of FORMA's general bench guide.
- A plank with feet on a ball is distinct from an ordinary forearm plank or a
  forearms-on-ball variation.
- A chest-to-bar contest photo uses an underhand grip; a military group photo has
  mixed grips. Neither was accepted as an unambiguous general pull-up guide.

Initial Commons image requests failed because the download client lacked the
descriptive User-Agent required by the server. Adding legitimate project/client
identification restored access. All 12 inspection thumbnails then downloaded
completely with normal TLS verification. An earlier original-image probe hit an
8 MiB read limit and was discarded for inspection; its hash is explicitly marked
as a partial body. One bounded search returned HTTP 429 and was not repeatedly
retried. See [request evidence](exercise-photo-expanded-fetches.json).

## Other sources checked

| Source                                                                   | Finding                                                                                                          | FORMA use                                                                                                                                       |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| [Hyperhuman](https://hyperhuman.cc/fitness-content-licensing)            | Commercial licensing for filmed exercises/classes, stock stills and app/web/API delivery                         | Promising broader source; agreement must cover individual content, territory, stills and hosting                                                |
| [WorkoutDB](https://work-out-db.com/answers/exercise-photos-api)         | Advertises approximately 873 exercises with photos, video and GIFs; commercial use on Pro/Scale                  | Additional photo provider; exact FORMA matches and complete storage terms unverified                                                            |
| [Physitrack](https://www.physitrack.com/exercise-library)                | Real machine/cardio/conditioning demonstrations, including upper-body ergometers and supported exercise variants | Useful specialist source; [service terms](https://www.physitrack.com/legal/terms) do not grant unrestricted commercial copying into another app |
| [Pexels](https://www.pexels.com/license/)                                | Free-use licence page retrieved; exact-exercise search pages returned HTTP 403                                   | Potential individual stock photos; broad “gym” results do not establish a movement match                                                        |
| [GymVisual](https://gymvisual.com/)                                      | Anatomical illustrations and animations; actual terms request returned HTTP 403                                  | An illustration option, excluded from real-photo counts                                                                                         |
| [WorkoutLabs](https://workoutlabs.com/exercise-illustrations-licensing/) | 679-exercise illustration library and explicit case-specific commercial licences                                 | An illustration option; advertised full-library pricing starts at $1,200/year or $3,500+ perpetual, not purchased                               |
| [ExRx](https://exrx.net/)                                                | Public reference homepage retrieved; legal page returned HTTP 403                                                | Reuse permission unresolved                                                                                                                     |
| [Life Fitness](https://www.lifefitness.com/en-us/legal/terms-conditions) | Retrieved page is commercial terms of sale                                                                       | Does not establish permission to publish manufacturer product photography                                                                       |

The old GymVisual `/content/6-terms-and-conditions-of-use` address now redirects
to **Price rules**. Its actual current terms link is `/content/3-terms-and-conditions-of-use`.
A successful old-address response therefore does not establish current licence
inspection. Search snippets were used to discover sources; provider pages and
per-asset metadata support the findings above.

The practical route is to review the free demonstrations and attributed Commons
candidates first, then compare a licensed commercial catalog against remaining
FORMA variants. Original photography can fill unsupported models or movements.
Keep distinct equipment, grip and setup variations throughout that mapping.
