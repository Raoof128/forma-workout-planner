# Change summary

Branch `claude/practical-planck-xi0wq2`, from baseline `53c4877`. **Not
deployed.** This is a frontend-only change. No file that the API imports
(`src/data.js`, `src/storage.js`, `src/exerciseMetrics.js`,
`src/routineProgramming.js`, `src/catalog/search.js`) and no input to the
native resource manifest changed. `node scripts/build-ios-resources.mjs --check`
passes with no `ios/` diff. The release needs only a staging, then production,
Worker deploy. No API image, migration or database step is required.

## What changed

**Data safety**

- **Timed holds survive navigation.** A running hold survives leaving the
  workout screen, and a second hold cannot replace it
  (`src/components/Workout.jsx`).
- **Notes save in batches.** Session notes save after a 700 ms pause, on blur
  and on leaving the screen, not on every keystroke
  (`src/components/Workout.jsx` `SessionNotes`).
- **Cloud requests time out.** They now time out after 45 s, covering the
  response body too. A stalled save becomes a retryable offline state with
  its exact payload and operation ID. "Retry" re-reads the cloud when there is
  nothing to resend (`src/account/cloudRepository.js`).
- **Sign-out warns first.** Signing out, on this device or everywhere, warns
  while edits have not reached the cloud (`src/App.jsx` `workspace.unsynced`,
  `src/components/Account.jsx`).
- **Dialogs keep drafts.** A dialog no longer closes, discarding its draft,
  when a text selection ends on the backdrop (`src/components/UI.jsx`).
- **No empty crash downloads.** The crash screen no longer downloads an empty
  file (`src/components/ErrorBoundary.jsx`).

**Account security hygiene**

- **Coach token is cleared.** The token's plaintext clears on leaving Security,
  is not inside a live region, and takes focus when issued.
- **Recovery codes are cleared.** They are removed when two-step verification
  is turned off.
- **Dev proxy is loopback-only.** It attaches the local Worker secret only for
  loopback peers (`vite.config.js`).

**Accessibility and responsive layout**

- **Names include visible text.** Accessible names now include the visible
  text: brand link, calendar days, timer adjust buttons, set fields and
  routine-editor fields.
- **Valid ARIA roles.** Roles are valid, `aria-live` replaces stray
  `role="status"`, `aria-invalid` is set on invalid fields, and Library and
  picker names are clearer.
- **Contrast and target sizes.** Field borders, focus rings, the account
  caption, legal links and 24 px minimum targets were fixed.
- **No overflow.** Set rows fit at 320 px, the routine editor's options column
  fits, and safe areas apply on every side.
- **Routine editor.** Keyboard moves are announced and keep focus, the
  100-exercise cap is enforced, and the create card no longer shows under
  Archived.

**Performance**

- **Smaller startup bundle.** It no longer carries exercise description
  previews (`scripts/vite-lean-catalog.mjs`): 560.3 to 443.8 KB gzip. See
  PERFORMANCE.md.

**Correctness**

- **Reviewed names in Progress.** The personal-best table shows the reviewed
  names used everywhere else (`src/progressSummary.js`).

## Tests added or strengthened

- `tests/web-audit-2026-11.spec.js`: 5 browser regressions. Each fails on the
  baseline and passes after.
- `unit/cloud-repository.test.js`: 4 cases (retry without payload, stalled
  save, stalled first read, stalled response body). Each fails before its fix.
- `unit/progress-summary.test.js`: reviewed-name case, which fails before.
- `unit/lean-catalog.test.js`: covers the bundle transform. It also guards the
  invariant that every sourced guide still has lazily loaded full text.
- `tests/accessibility.spec.js`: now runs axe's `wcag21a` rules, which include
  2.5.3.
- Existing specs were updated only where an accessible name changed. Every
  assertion keeps its strictness.

## Risks

- **Behaviour change: notes.** Notes typed in another tab appear after the
  700 ms pause rather than per keystroke.
- **Behaviour change: second hold.** Starting a second hold while one runs now
  shows a message instead of replacing it.
- **Offline guide text.** If the instructions chunk cannot load (offline on
  first visit), a catalogue guide shows the "full guide could not load" message
  without the old 360-character preview.
- **Timeout length.** The 45 s request timeout is a fixed value. A very slow
  uplink sending a very large workspace could time out and need a retry. That
  retry is idempotent.
- **Renamed accessible names.** External automation that relied on the old
  names ("Add 15 seconds", "Plank set 1 durationSeconds", "Add X to routine")
  must be updated.

## Outstanding

See "Deferred" in AUDIT.md (D-01 to D-11). The most valuable follow-ups:

- **D-01:** keep unsaved edits across a session expiry.
- **D-02:** add a mid-size WebP tier for guide images.
- **D-11:** startup LCP under throttling is still above 2.5 s.
