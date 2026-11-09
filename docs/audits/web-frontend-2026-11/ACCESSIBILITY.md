# Accessibility

Target: WCAG 2.2 Level AA. This document records what was checked and what was
verified. **It is not a conformance claim.** Automated scanners and code
review do not replace testing with assistive technology. No screen reader,
voice control or switch testing was done in this pass.

## How it was checked

- **axe-core 4.14.0**, with the `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` and
  `wcag22aa` tags, on every page at 390 and 1440 px with seeded data
  (baseline sweep). `tests/accessibility.spec.js` also covers routine and
  workout dialogs at 1536 and 390 px.
- Code review of every component for names, roles, states, focus, live regions
  and target sizes.
- Contrast ratios computed from the CSS token values (WCAG relative luminance).
- Keyboard behaviour checked through the Playwright suites, which drive the app
  by role and accessible name.

## Results by criterion

| Criterion                       | Before                                                                                                                                             | After                                                                                               | Evidence                                            |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1.3.1 Info and relationships    | Some `aria-label`s were on generic `div`s (ignored). Some `div`s sat inside `button`s.                                                             | `list`/`listitem` and `group` roles added; spans used inside buttons.                               | Review                                              |
| 1.4.1 Use of colour             | Legal inline links matched the body text colour, with no underline.                                                                                | Underlined.                                                                                         | Review                                              |
| 1.4.3 Contrast (text)           | The account summary caption was 3.41:1.                                                                                                            | 5.05:1.                                                                                             | Computed                                            |
| 1.4.11 Non-text contrast        | Field borders 1.24–1.53:1; menu focus ring 1.92:1.                                                                                                 | Field borders 3.10–3.29:1; focus ring 15.6:1.                                                       | Computed                                            |
| 2.4.3 Focus order               | Focus was stranded after a keyboard move to the first or last row of the routine editor.                                                           | Focus moves to the row's other arrow.                                                               | Review                                              |
| 2.4.11 Focus not obscured       | Claimed: the sticky rest bar sits under the header.                                                                                                | Measured: not obscured (the bar sits at 74 px, the header ends at 66 px).                           | Render check                                        |
| 2.5.3 Label in name             | axe `label-content-name-mismatch` flagged the brand link, the calendar days and the rest and hold adjust buttons. Internal keys appeared in names. | Every name now starts with its visible text. Internal keys were replaced by visible labels.         | axe, `tests/web-audit-2026-11.spec.js`              |
| 2.5.7 Dragging movements        | Routine reordering already had Move up/down buttons, but moves were silent.                                                                        | Keyboard moves are announced ("Moved X to position N of M").                                        | Review                                              |
| 2.5.8 Target size (minimum)     | 18 px routine checkboxes; five account text buttons about 21–23 px tall.                                                                           | 24 px minimum.                                                                                      | Review, sweep (no sub-24 px controls in main pages) |
| 3.3.1 Error identification      | Invalid number fields had no `aria-invalid`.                                                                                                       | `SavedField` sets `aria-invalid`.                                                                   | Review                                              |
| 3.3.8 Accessible authentication | Password fields allow paste and use `autocomplete`; the 2FA code uses `one-time-code`.                                                             | Unchanged (already met).                                                                            | Review                                              |
| 4.1.2 Name, role, value         | Library cards changed their name and also used `aria-pressed`.                                                                                     | Constant name with `aria-pressed`.                                                                  | Specs                                               |
| 4.1.3 Status messages           | `role="status"` appeared outside the toast. The new coach token's secret sat inside a live region.                                                 | `aria-live="polite"` instead. The secret is in a named group that takes focus and is not announced. | Review                                              |
| Reduced motion                  | Global `prefers-reduced-motion` rules and Motion `reducedMotion="user"` were in place.                                                             | Unchanged. Exercise animations still read the setting only once (deferred D-10).                    | Review                                              |

## Test gap closed

`tests/accessibility.spec.js` ran axe without `wcag21a`, so
`label-content-name-mismatch` (WCAG 2.5.3) never ran in CI. The tag is now
included. That surfaced the rest-timer `−15 s`/`+15 s` buttons, which were
fixed in the same pass.

## Known remaining barriers

Listed in AUDIT.md under "Deferred": focus lands on `body` after some in-place
confirmations (D-08); headings sit inside card buttons (D-09); exercise
animations do not follow a live change to reduced motion (D-10).
