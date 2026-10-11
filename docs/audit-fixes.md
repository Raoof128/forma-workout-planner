# Frontend audit remediation

Implemented 12 October 2026 (Sydney). Scope: the personal, browser-local FORMA app.

| Finding | Resolution | Main files |
| --- | --- | --- |
| Cross-tab snapshots overwrite newer workouts | Origin-wide Web Locks serialize transactions. Each mutation reads the latest storage, changes only its intended fields, validates, then saves. Stale routine/profile/history/schedule edits produce a conflict message. | `src/hooks/useWorkoutStore.js`, `src/App.jsx` |
| Invalid nested data crashes; malformed JSON is overwritten | Zod validates the complete saved structure and known exercise IDs. Invalid content opens recovery without modifying it. Download, validated restore, and explicit reset preserve the original. | `src/storage.js`, `src/components/Recovery.jsx` |
| Dialog focus resets every second or escapes on Shift+Tab | Native modal dialogs, stable lifecycle, explicit keyboard wrap, Escape/backdrop handling, and focus restoration. Notifications render inside an open dialog so feedback remains accessible. | `src/components/UI.jsx`, `src/components/Notification.jsx` |
| Closed mobile drawer remains tabbable | Closed drawer is inert. Open drawer traps focus, makes main content inert, supports Escape, and exposes expanded state. | `src/components/Navigation.jsx` |
| Low contrast, tiny labels, undersized controls | Darkened muted text, tags, focus outlines, and icons; minimum 11px metadata and 16px mobile inputs; 44px principal icon controls/week arrows. Completed sets have a check versus an empty box. | `src/styles.css`, `src/components/Workout.jsx` |
| Long routine names hide the hero action | Hero grows with its contents; footer stays in normal flow; long words wrap. Verified the maximum 60-character name at five widths. | `src/styles.css` |
| Timer resets across navigation/reload and ignores chosen duration | Persisted deadline, paused remainder, and selected duration. Every completed set starts the selected rest duration. Expiration cannot clear a newer timer from another tab. | `src/components/Workout.jsx`, `src/storage.js` |
| Dashboard misidentifies active workout; another Start silently resumes it | Hero uses the active session snapshot. Starting a different routine explicitly offers resume or discard-and-start. Next routine rotates after the last completed session and can be selected. | `src/components/Overview.jsx`, `src/App.jsx` |
| Misleading zero bars and overflowing progress chart | Weekly bar height represents actual counts, including true zero. Eight progress columns shrink to fit 320px. Count labels accompany the bars. | `src/components/Overview.jsx`, `src/components/Insights.jsx`, `src/styles.css` |
| Dirty routine drafts disappear | Close, backdrop, Escape, and Cancel lead to a keep-editing/discard choice. Unload warns about a dirty routine. | `src/components/Routines.jsx` |
| Selection and calendar markers lack accessible meaning | Pressed states on filters, picker, schedule, rest options, and dates; dates announce planned/logged status. Calendar uses check/circle/dot markers. | `src/components/Library.jsx`, `Routines.jsx`, `Overview.jsx`, `Preferences.jsx`, `Workout.jsx` |
| Renaming changes routine duration | Explicit duration field retains the original duration independently of exercise count. | `src/components/Routines.jsx` |
| No Back/bookmark navigation or error boundary | Hash routes preserve URLs, browser Back, and reload destinations. Render failures provide reload/download recovery. | `src/hooks/useNavigation.js`, `src/components/ErrorBoundary.jsx`, `src/main.jsx` |
| Plank convention unclear; no active-session instructions | Explicit 1 rep = 10-second hold convention; shared exercise guide accessible from every logged exercise. | `src/components/ExerciseGuide.jsx`, `src/components/Workout.jsx` |
| Reordering loses prescriptions | Move-up/down controls preserve prescriptions; removing and re-adding an exercise in a draft restores its values. | `src/components/Routines.jsx` |
| Incorrect single-rep estimate | One rep uses actual weight; 2–12 reps use Epley. | `src/data.js`, `src/components/Insights.jsx` |
| No history correction/deletion or backup restore | Edit logged sets/name/notes, remove a workout with confirmation, and recalculate progress. Import validates before replacement; a previous copy is preserved. | `src/components/HistoryEditor.jsx`, `src/components/Insights.jsx`, `src/components/Preferences.jsx` |
| Mobile timer/notes precede and displace the primary logging task | Exercises come first in the content flow. Compact sticky mobile timer opens detailed controls; notes follow exercises. | `src/components/Workout.jsx`, `src/styles.css` |
| Saving failures contradict success claims | Persistent temporary-mode warning, accurate overview copy, export of the in-memory state, and no unsafe retry that could overwrite another tab. | `src/hooks/useWorkoutStore.js`, `src/App.jsx`, `src/components/Overview.jsx` |
| Rapid typing loses characters (found during remediation) | Synchronous editing values are isolated from asynchronous acknowledgments. Pending writes show a saving indicator and trigger an unload warning. | `src/components/SavedField.jsx`, `src/hooks/useWorkoutStore.js` |
| Dense source, redundant styles, missing tooling, stale docs | Formatted all source, extracted persistence/navigation/recovery/shared controls, removed superseded CSS declarations, pinned dependency versions, enabled the React Vite plugin, removed unused TypeScript, and added ESLint/format checks. Documentation describes the current fonts and behavior. | `eslint.config.js`, `vite.config.js`, `package.json`, `README.md`, `docs/` |

Regression evidence and browser limitations are recorded in [verification.md](verification.md).

The subsequent typography, responsive, and error-feedback pass is recorded in [frontend-design-audit.md](frontend-design-audit.md), including coverage of every source file.
