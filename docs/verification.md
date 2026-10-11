# Verification after frontend audit fixes

Verified 12 October 2026 (Sydney) using Playwright Chromium. The Browser plugin was unavailable, so the installed Chromium automation was used directly.

## Automated results

- `npm run lint`: passed, including React Hooks and JSX accessibility checks.
- `npm run format:check`: passed.
- `npm run build`: passed; production React/Vite bundle generated.
- `npm test`: **23 tests passed**.
- Production preview smoke test: start → complete set → save → reload passed with one persisted workout and no page errors.
- axe WCAG 2 A/AA, 2.1 AA, and 2.2 AA scans: **zero violations across 24 tested page/dialog states**, at 1536px and 390px.

Tests are in `tests/workflows.spec.js`, `tests/regressions.spec.js`, and `tests/accessibility.spec.js`.

## Verified behavior

The full create/edit routine → log sets → pause/skip rest → reload → finish → history → progress workflow passes. Two sets of 8 reps at 50 kg produce 800 kg volume and 63.3 kg estimated 1RM. A single rep at 100 kg correctly reports 100 kg. Correcting a logged set to 80 kg × 5 updates volume to 400 kg and estimated 1RM to 93.3 kg; deleting the workout removes its contribution.

Concurrent-tab tests cover independent profile/session updates, independent fields in the same workout, finishing a session while updating preferences, and stale routine edits. The newest unrelated data survives. Invalid JSON, invalid nested profile data, and unknown exercise IDs are preserved without overwriting; original-data downloads match byte for byte. Export/import round trips and recovery from a valid backup pass. Blocked storage remains usable with explicit temporary-state copy and data export.

Rapid typing retains every character. Rest duration, deadline, and paused remainder survive navigation/reload, and chosen duration is reused after the next set. Dialog focus remains on the selected button across timer ticks, wraps on Tab/Shift+Tab, and restores on Escape. Hidden mobile navigation is inert; open navigation traps focus and closes on Escape.

Routine drafts survive attempted dismissal. Renames preserve duration, exercise reordering preserves values, and removing/re-adding an exercise retains its prescriptions. The hero identifies the active session, and a different routine cannot silently replace it. Hash navigation, bookmarks, and browser Back work.

## Responsive and visual checks

- Maximum 60-character routine title retains a visible start action at 320, 390, 768, 1024, and 1536px.
- Eight progress bars fit inside the panel at 320px. Weekly zero-count bars have zero height.
- All seven main pages pass horizontal-overflow checks at 390px and 1536px.
- At 320px, mobile rest controls remain reachable while scrolling the workout. Detailed timer controls and exercise instructions work.
- Fresh desktop/mobile screenshots were reviewed for dashboard hierarchy, readable labels, flexible hero layout, workout controls, and chart spacing. Captures are under `/workspace/scratch/forma-fixed/`.

The original `design-concept.png`, `desktop-preview.png`, and `mobile-preview.png` are historical design/build artifacts, not screenshots of the remediated build. The implemented typeface is DM Sans. The hero now grows to fit its content rather than relying on the old fixed-height constraint.

## Limits

These results establish the tested Chromium behavior; Safari/Firefox and physical assistive-technology testing were not run. Automated accessibility scans supplement the keyboard and visual checks and do not establish complete WCAG conformance. Local data remains tied to this browser; downloadable backups are the recovery path after site data is cleared. Persistent writes require Web Locks and available browser storage; unsupported or blocked saving uses the documented temporary mode.

See [audit-fixes.md](audit-fixes.md) for the finding-to-file remediation record.
