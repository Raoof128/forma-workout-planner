# Animated exercise demonstrations

Self-contained animated SVGs that show how to perform an exercise, one file per
exercise. They are an alternative to video for exercises with no reviewed clip.
They are not yet shown in the app.

| Set                              | Exercises                                                                                                                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [upper-a](upper-a/key-poses.png) | Barbell bench press, leverage decline chest press, machine bench press, leverage shoulder press, plate-loaded lat pulldown, one-arm dumbbell row, dumbbell lateral raise, cross-body hammer curl |
| [legs-a](legs-a/key-poses.png)   | Barbell step-ups, leg extensions, leg presses (wide), lying leg curls, seated calf raise, seated leg curl, split squat with dumbbells                                                            |
| [core](core/key-poses.png)       | Ab roller, bicycle crunch, seated barbell twist, plank, dumbbell side bend, standing calf raise, dumbbell lateral raise                                                                          |
| [upper-b](upper-b/key-poses.png) | Incline dumbbell press, wide-grip lat pulldown, seated cable row, face pull, cable rope overhead triceps extension, incline dumbbell curl (the lateral raise is the core set's)                  |
| [legs-b](legs-b/key-poses.png)   | Dumbbell goblet squat, Romanian deadlift, leg press, dumbbell reverse lunge, barbell hip thrust (seated leg curl is in legs-a, standing calf raise in core)                                      |

Each set folder has a `key-poses.png` with the start, middle and end of every
movement, used to review the poses.

## How they work

- A small figure rig in `scripts/exercise-svg/` places joints in 3D and
  projects them, so limbs keep their length as they move. Two-bone inverse
  kinematics keeps hands on handles and feet planted. Twisting moves use a
  camera angle; the lateral raise, wide-grip lat pulldown, face pull and goblet squat
  show front and side views together.
- Poses are sampled at 15 frames a second into SMIL `<animate>` values, which
  work when the SVG is shown as an image. Captions change with each phase and a
  progress bar runs along the bottom. Green marks the working muscle; red dotted
  outlines with a cross show a fault to avoid.
- Fonts are the bundled DM Sans and Barlow Condensed (SIL Open Font Licence,
  see `public/fonts/`), embedded so the files work standalone.
- SMIL ignores the reduced-motion setting, so the app should show the first
  frame until the member presses play.
- Cues follow each exercise's FORMA guide plus coaching sources. Where they
  differ, the safer cue is shown (bar across the upper back, not the neck, on
  the seated twist; bend toward the dumbbell on the side bend). The poses have
  not been reviewed by a coach.

## Rebuilding

```sh
cd scripts/exercise-svg && python3 build.py
```

This rewrites every set in this folder; the output is deterministic.
