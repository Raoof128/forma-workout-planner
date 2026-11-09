# Design review

The visual identity is kept on purpose. FORMA already has a clear
athletic-editorial direction: Barlow Condensed display type, DM Sans for the
interface, charcoal and warm neutral surfaces, lime reserved for primary
actions and progress, and original exercise artwork. This pass did not
redesign it. It removed the places where the identity broke down:

- controls that overflowed their containers;
- controls that could not be seen clearly enough;
- the same element styled two different ways;
- names that did not match what is on screen.

## Decisions

| Decision                                                                                            | Reason                                                                                                                                                                                                                                                                                                                                      |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| No new palette, typefaces, gradients, glass or decorative motion.                                   | The audit found no failure of the existing language, only failures in how it was applied. New decoration would add weight without helping training.                                                                                                                                                                                         |
| One new token, `--field-border: #889088`.                                                           | Field borders were 1.24–1.53:1 against their backgrounds, so inputs read as floating text. `#889088` is the lightest neutral in the existing grey-green family that reaches 3:1 on both white and the `#f7f9f3` set-row fill (3.29:1 and 3.10:1). A darker candidate (`#7d857e`) also passed but made forms look heavy, so it was rejected. |
| Menu focus rings use `--ink`.                                                                       | The lime-grey ring was 1.9:1. Ink matches the global `:focus-visible` treatment already used elsewhere.                                                                                                                                                                                                                                     |
| Legal links are underlined; buttons and navigation keep their current treatment.                    | Inline links in running text need a non-colour cue (WCAG 1.4.1). Navigation and buttons are already identified by shape and position.                                                                                                                                                                                                       |
| The set row at ≤700 px has one rule: `26px` index, three flexible tracks, and a `44px` check track. | Two conflicting rules had left the 44 px check button in a 34 px track, so it overflowed the card. The check button is the most frequent action in a workout and keeps its full target.                                                                                                                                                     |
| The routine editor's last column is widened to 36 px.                                               | It holds the 34 px options button. Nothing else in the row moves.                                                                                                                                                                                                                                                                           |
| Safe-area insets apply on all sides (`max(20px, env(safe-area-inset-*))`).                          | `viewport-fit=cover` was set, but only the top inset was honoured. In landscape on notched phones, content could sit under the notch.                                                                                                                                                                                                       |
| The history summary uses 26 px numbers at ≤380 px.                                                  | Three columns of 32 px numbers wrapped mid-number at 320 px. Wrapping is kept only as a last resort, so very large totals never overflow the card.                                                                                                                                                                                          |
| Chest and shoulder library cards use the existing cool tint.                                        | They had no tint rule and fell back to the base colour, unlike the other muscle groups.                                                                                                                                                                                                                                                     |
| Dead selectors (`.brand-mark`, `.brand-period`, `.exercise-detail-icon`) were removed.              | No reference anywhere in `src/`, `tests/`, `public/`, `index.html`, `server/` or `worker/`. They were left over from the older brand mark.                                                                                                                                                                                                  |

## Screens checked

Every page (Overview, Routines, Library, Active workout, History, Progress,
Settings, Privacy) was rendered with long names, 999.5 kg × 100 rep sets and six
history sessions, at 320, 360, 375, 390, 430, 768, 1024, 1280, 1440 and 1920 px.
The routine editor and active workout were also rendered at 701, 760, 800, 850
and 900 px. Per-side (left/right) set rows were checked at 320 and 360 px: no
overflow, with 40 px fields at 320 px.

None of the 80 page and width combinations scrolls horizontally, before or after
the change. Screenshots are kept as local QA artefacts and were not committed:
the repository keeps evidence as text unless a release needs images.

## Not changed, and why

- **Large-screen width.** The main column is capped at 1500 px. History rows and
  the records table stretch to that width at 1920 px. This is a layout choice
  rather than a defect, and narrowing it changes the Progress composition.
  Left for an owner design decision.
- **Dark mode.** The app has no dark theme. Adding one is a product change, not
  a fix.
- **Exercise media resolution.** Guides show crops of full-size PNG atlases.
  The images look right, but each costs 1.5–2.0 MB (deferred item D-02 in
  AUDIT.md).
