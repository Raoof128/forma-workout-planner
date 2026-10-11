# Frontend design audit and polish

Completed 12 October 2026 (Australia/Sydney) for the browser-local FORMA app. This pass follows the functional repairs in [audit-fixes.md](audit-fixes.md).

## Approach

Applied the installed **frontend-design** skill (`skill://user/6acc181e8bbc8191b531ee10b7cc8671/frontend-design/SKILL.md`). Reviewed all 21 files under `src/`, including the complete stylesheet, along with the HTML entry point, build/lint/browser-test configuration, assets, and existing tests. Review covered rendering, state transitions, labels, keyboard behavior, responsive sizing, and failure feedback. Generated dependencies, lockfile package entries, and binary image/font contents were not treated as handwritten frontend code.

The visual direction is athletic editorial: Barlow Condensed for strong, compact display headings; DM Sans for reading and input; charcoal photography; warm neutral surfaces; and lime reserved for primary actions and progress. Fonts are served from this app, with their OFL licenses included. The layout keeps workout entry controls large on phones and puts the mobile rest timer within reach while scrolling.

## Findings resolved in this pass

| Finding | Fix |
| --- | --- |
| Repeated CSS overrides made responsive behavior hard to predict. | Reorganized the stylesheet around shared tokens, components, and consolidated breakpoints. |
| Display and body text had little distinction. | Added condensed display typography, clearer hierarchy, restrained page entry motion, and consistent spacing. Reduced-motion preference disables entry animation. |
| Narrow routine editor squeezed numbers into tiny columns. | At phone widths, each selected exercise gets a heading and three labeled fields. Tested 999.5 kg, 100 reps, and 12 sets. |
| Long profile/routine names and unbroken notes could stretch flex/grid children. | Added shrinkable children and wrapping across navigation, cards, history, notes, and headings. |
| Short landscape navigation could hide lower actions. | Made the drawer independently scrollable without shrinking its controls. |
| External font requests added a dependency for the page's primary typography. | Added local WOFF2 fonts and preload hints; removed Google Fonts requests. |
| Empty routine lists and exercise searches lacked a clear next step. | Added creation actions and an announced no-match message. |
| Calendar markers needed an explanation. | Added a visible planned/logged legend alongside accessible date descriptions. |
| Imported history order could show the wrong latest session. | Sort history and recent progress by parsed timestamps, including mixed fractional-second precision; next-routine selection uses the newest dated workout. |
| Personal bests looked tabular but lacked table semantics. | Added table, column headers, row headers, and an accessible caption label. |
| Large history arrays were spread into maximum calculations. | Used reductions for personal-best calculations and cached date formatters. |
| The browser tab title did not identify the current screen. | Added route-specific document titles. |
| Unsaved history corrections lacked an unload warning. | Added a dirty-draft warning and blocked dismissal during save. |
| A later storage-read failure could replace the current snapshot with starter data. | Preserve the existing in-memory session and expose temporary-mode/export guidance. |
| Settings still described data as saved when saving was blocked. | Made data guidance conditional on actual storage availability. |
| Recovery treated a valid backup that could not be saved as an invalid file. | Separated validation errors from write errors, disabled duplicate recovery actions while pending, and retained the original data. |
| Download failures were silent or prematurely reported success. | Added visible failure feedback and accurately report that the download has started. |
| Test screenshots used an absolute workspace path. | Moved captures to the operating system's temporary directory with a configurable `FORMA_ARTIFACT_DIR`. |

## File-by-file coverage

| Source file | Review and outcome |
| --- | --- |
| `src/main.jsx` | App mount and error boundary reviewed; no new change needed. |
| `src/App.jsx` | Route branches, mutation/conflict handling, routine/session dialogs, recovery, and save status reviewed; added screen marker, correct empty-workout heading, and storage-aware settings. |
| `src/data.js` | Exercise/routine data, date boundaries, session totals, and 1RM reviewed; cached formatters without changing Sydney date semantics. |
| `src/storage.js` | Nested schema, known exercise IDs, recovery preservation, and downloads reviewed; regression checks cover malformed and denied storage. |
| `src/styles.css` | Reviewed and reorganized all rules; polished hierarchy, controls, tables, empty states, responsive layouts, safe areas, focus, and reduced motion. |
| `src/hooks/useNavigation.js` | Hash/Back handling and heading focus reviewed; added page titles. |
| `src/hooks/useWorkoutStore.js` | Initialization, cross-tab events, locks, validation, pending writes, and temporary mode reviewed; preserve current data on read failure. |
| `src/components/UI.jsx` | Shared buttons/dialogs/empty states reviewed; added eyebrow and heading-level support. |
| `src/components/Navigation.jsx` | Drawer focus trap, inert states, Escape, active navigation, profile, and resume action reviewed; responsive fixes applied in CSS. |
| `src/components/Overview.jsx` | Hero, next routine, calendar, weekly counts, and empty states reviewed; fixed newest-session selection and added clearer empty/legend copy. |
| `src/components/Routines.jsx` | Editor validation, selection, prescriptions, reorder, save, and discard reviewed; added mobile field labels and no-match feedback. |
| `src/components/Library.jsx` | Search, filters, card buttons, and details reviewed; added announced result count and page eyebrow. |
| `src/components/ExerciseGuide.jsx` | Instructions, equipment/muscles, and close action reviewed; retained existing behavior. |
| `src/components/Workout.jsx` | Live set entry, completion, timer persistence, notes, finish/discard, and instructions reviewed; responsive logging/timer styling polished. |
| `src/components/SavedField.jsx` | Editing state and asynchronous acknowledgment behavior reviewed; rapid-input regression retained. |
| `src/components/Insights.jsx` | History ordering, totals, progress bars, records, details, and delete flow reviewed; chronological ordering and semantic records table fixed. |
| `src/components/HistoryEditor.jsx` | Correction validation, keep-set controls, save/discard, and notes reviewed; unload and pending-save safeguards added. |
| `src/components/Preferences.jsx` | Profile, goal, schedule, export/import, confirmation, and error feedback reviewed; accurate temporary-mode and download copy added. |
| `src/components/Recovery.jsx` | Original download, validation, restore, reset, and error states reviewed; distinct errors and pending states added. |
| `src/components/ErrorBoundary.jsx` | Render fallback, reload, and data download reviewed; download failures now visible. |
| `src/components/Notification.jsx` | Live region and open-dialog notification placement reviewed; retained behavior. |

`index.html` now preloads local fonts and supports safe-area insets. Vite, ESLint, dependency scripts, favicon, image assets, font licenses, and Git ignore rules were reviewed. Playwright now runs Chromium and Firefox; four spec files cover workflows, functional regressions, accessibility, and responsive edge cases.

## Validation

See [verification.md](verification.md) for final command results, tested sizes, browser coverage, and limitations. An audit and automated tests provide evidence for the reviewed behavior; they cannot prove the absence of every possible defect.
