# Exercise demonstration videos: licence research

**21 October 2026 · 22 reviewed clips bundled; not yet deployed**

The owner asked for open-licence 2026 demonstration videos so members can see
how to perform each exercise. This note records what was checked and what is
safe to use. It follows the earlier still-image research in
[exercise-photos.md](exercise-photos.md) and
[exercise-photos-more.md](exercise-photos-more.md). Licences were read on each
source page, not taken from summaries. Free use of a video and rights to a
still from it are separate questions.

## Usable without further permission

| Source                                                                                                                                                | What it has                                                                                                                                        | Licence                                                                                    | Notes                                                                                    |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| [CDC physical-activity videos on Commons](https://commons.wikimedia.org/wiki/Category:CDC_videos_about_physical_activity)                             | 17 clips, 320×240: gym machines (leg press, row, leg extension, leg curl, chest press, overhead press and others) and home moves (push-up, squat…) | US government public domain ([CDC policy](https://www.cdc.gov/other/agencymaterials.html)) | Low resolution. Do not imply CDC endorsement.                                            |
| US Army / DVIDS clips on Commons (for example [Forward Lunge](https://commons.wikimedia.org/wiki/File:Strength_Training_Circuit-_Forward_Lunge.webm)) | About 10 clips, 1080p                                                                                                                              | US government public domain                                                                | Check each clip for music and identifiable people.                                       |
| FitnessScape series on Commons (for example [Squat](https://commons.wikimedia.org/wiki/File:Squat_-_exercise_demonstration_video.webm))               | About 15 clips, 720p: squat, bench press, deadlift, pull-up, rows, presses                                                                         | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0)                                   | Credit FitnessScape. The uploader's claim is the only evidence of the licence.           |
| [wger videos](https://wger.de/api/v2/video/)                                                                                                          | 78 videos for 46 wger exercises; 28 link to FORMA movements by catalogue identity                                                                  | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) per record                 | Mostly large HEVC `.MOV`; needs H.264 transcodes. ShareAlike applies to the video files. |
| Commons kettlebell series (for example [Goblet Squat](https://commons.wikimedia.org/wiki/File:Kettlebell_Goblet_Squat.webm))                          | About 55 clips, many advanced or combination moves                                                                                                 | CC BY-SA 4.0                                                                               | ShareAlike on the files.                                                                 |

Together these cover roughly 30–70 FORMA exercises (2–5% of 1,414). That
figure is an estimate; each clip still has to be matched to the exact FORMA
variant, as the artwork review did.

## Needs written permission or an agreement

- **YMove free set** ([page](https://ymove.app/free-exercise-videos)): 25
  clips described as free for commercial use in apps, but YMove's general
  [terms](https://ymove.app/terms-and-conditions) say content is personal and
  non-commercial without written permission. Ask YMove before shipping.
- **YouTube embeds**: allowed through the embedded player
  ([YouTube terms](https://www.youtube.com/t/terms)); downloading or caching is
  not ([developer policies](https://developers.google.com/youtube/terms/developer-policies)).
  This is the only route to near-full coverage without filming, but it needs a
  curated video per exercise, a click-to-load player on
  `youtube-nocookie.com`, CSP `frame-src` changes, a Referer (no
  `no-referrer` policy) and a Privacy Policy update before release, because it
  adds a third-party provider.
- **Paid catalogues**: MuscleWiki's API forbids storing or rehosting; AscendAPI
  media URLs rotate weekly and rehosting needs a separate agreement; RepDB sells
  AI-generated looping animations for about 500 exercises.

## Rejected

free-exercise-db and Everkinetic (stills only), NHS videos (excluded from the
Open Government Licence), stock sites such as Pexels and Pixabay (generic gym
footage, not specific exercises), and GitHub or Hugging Face datasets without
stated provenance, including GIF sets copied from GymVisual.

## Not verified

NIH/NIA exercise video licences (the sites returned a bot challenge, which was
not bypassed), Mixkit's licence text, GymVisual and AscendAPI terms (HTTP 403),
and YMove's position on its own conflicting terms.

## Implementation status

The owner approved adding the open-licence clips. 39 candidate files were
downloaded from Commons and checked against the SHA-1 Commons publishes. Each
clip's frames were reviewed against the FORMA guide and equipment for the exact
variant. Only high-confidence matches are published; 16 likely but uncertain
matches are recorded as held in the registry and are not shown.

| Source       | Clips published | Licence       |
| ------------ | --------------- | ------------- |
| CDC          | 9               | Public domain |
| FitnessScape | 9               | CC BY 3.0     |
| U.S. Army    | 4               | Public domain |

Published exercises: barbell bench press, incline barbell bench press (medium
grip), barbell back squat, barbell deadlift, trap-bar deadlift, standing
military press, pull-up, bent-over barbell row, 45-degree leg press, calf press
on the leg press, seated leg curl, leg extension, machine chest press, machine
shoulder press, seated machine row, seated back extension machine, dumbbell
shoulder press, dumbbell biceps curl, superman, double kettlebell push press,
knee tuck jump and backward medicine-ball throw.

- [Registry](exercise-videos/registry.json): every candidate with its source
  page, author, licence, SHA-1, what it shows, the review reason, matched and
  held exercise IDs, trim window and poster time.
- `scripts/build-exercise-demos.mjs <originals folder>` trims, scales to at
  most 720 px, strips audio and encodes H.264 MP4 plus a JPEG poster into
  `public/exercise-demos/`, then writes `src/catalog/demos.json`. The originals
  are not committed; rerun only after changing the registry.
- `unit/exercise-demos.test.js` fails if a published exercise is not
  selectable or unreviewed, a credit or licence is missing, or a clip file
  changed since it was built.
- FitnessScape clips keep their burned-in exercise-name label; CC BY credit and
  the change notice ("trimmed, resized and muted") appear under each clip.
  Government clips carry a no-endorsement notice.
