# Runtime findings — fresh full-source review

Commit: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`. Read-only review; no repository changes. Findings below are established from current source, with exact-source synthetic timer reproduction where stated. Earlier browser reports supplied context only. Severity describes the current web behavior; missing Watch features are listed separately.

## Confirmed current behavior defects

### RT01 — P2: hold completion can log a different set after its original target is already completed

`src/components/Workout.jsx:375–377` replaces the timer's captured set index with the first unfinished set when the captured set is already done. The guard at `:413–416` is confined to one mounted component, and set records have no IDs (`src/storage.js:52–86`). Thus a running timer for set 1 can complete set 2 after set 1 is manually ticked, or after another tab's timer already completed it. The resulting training history overstates the completed sets.

Fresh proof: `runtime-timer-probe.mjs` extracts and executes the exact current `restAfter` and `logHold` functions with a synthetic three-set plank. Replaying the same timer target yields `[true, true, false]`; the second set was never a distinct requested target. `runtime-timer-results.json` retains the result. This is a function-level reproduction, not a new browser/hardware run. Completion should address one immutable target and become a no-op/acknowledgement when that target is already complete. The issue is a release blocker for multi-device workout control.

### RT02 — P2: delayed automatic hold completion starts a new full rest interval on resume

`src/components/Workout.jsx:368` samples `Date.now()` inside `logHold`; `:397` uses that callback time for rest even when automatic completion at `:416` is catching up after suspension. The timer already has its scheduled deadline at `:356–360`.

Fresh proof: exact-source synthetic execution resumes five minutes after a 60-second hold began. It records the intended 60 seconds but creates 90 seconds of remaining rest at resume, although the scheduled hold-plus-rest interval ended 150 seconds before resume. See `runtime-timer-results.json`. Automatic completion should use the scheduled completion timestamp; an explicit early end should use its action time.

### RT03 — P2: a manual rest timer on a fresh workout screen cannot produce its enabled audio cue

`src/components/Workout.jsx:78–85` creates/resumes the AudioContext only through `prepareCue`. Calls exist at `:273` (set check) and `:353` (hold start). Neither manual rest presets at `:1017–1025` nor start/resume at `:1087–1089` calls or receives it. `playCue` at `:178` requires an already-running context.

Source-established reproduction: enter a fresh Workout screen with sound unmuted, start rest without completing a set or starting a hold, and allow it to expire. The audio reference is still null, so the audio branch cannot execute. No platform background audio guarantee is inferred. Prepare/resume audio in the relevant user gesture.

### RT04 — P2: leaving the workout screen silently discards a running or paused hold timer

The hold and paused remainder exist only in React state (`src/components/Workout.jsx:117–122`). `src/App.jsx:535–561` conditionally mounts Workout only on the workout route. The visible back action says the workout stays active (`src/components/Workout.jsx:512–515`), but navigating away/reloading destroys the timer without recording its target or pause state. The persisted session retains rest timing but no hold timing (`src/storage.js:92–123`).

Fresh evidence is full source/lifecycle inspection; prior browser reproduction is not counted as a fresh run here. Reproduce with a synthetic plank: start or pause the hold, select Overview, and return. The active workout exists while the hold is reset. Timer ownership/state should survive the screen's lifetime, or navigation must explicitly resolve a running timer. Native Watch recording requires durable lifecycle ownership rather than component state.

## Watch implementation gaps, separate from current defects

### RT-W01 — P1 before Watch release: no durable account-bound offline workout outbox

`src/account/cloudRepository.js:46–57` keeps workspace state and queue in memory. Failed-save candidates remain in `retryPayload` at `:398–405`; subsequent mutations are blocked at `:336–339`. `src/hooks/useWorkoutStore.js:41–48` offers a beforeunload warning but does not persist the candidate. Reload/process termination loses unsent work. This is a present limitation of the web design, not evidence of a server write losing an acknowledgement. Native phone/Watch clients need durable member/device-bound events, retry IDs, acknowledgements and explicit local-versus-cloud save status.

### RT-W02 — P1 before health sync: no health/lifecycle schema or old-client compatibility contract

`src/storage.js:52–123` represents sets and sessions without sensor samples, HealthKit workout identity, pause intervals, device provenance or workout lifecycle state. `validateData` defaults to stripping unknown fields (`:273–276`); cloud decoding uses that mode (`src/account/cloudRepository.js:11`). Strict server writes reject unknown keys through `assertKnownKeys` (`src/storage.js:259–276`). Adding health fields to this whole-workspace document would therefore require a tested version/migration strategy; an old reader can discard fields in its next replacement write. Prefer separate versioned consented health summaries/events and preserve legacy IDs/units.

### RT-W03 — P1 before Watch release: the reviewed runtime is a React browser application

`src/main.jsx:1–17` mounts DOM React; account access uses same-origin browser credentials (`src/account/client.js:6–9` and `cloudRepository.js:224`). No native workout engine, HealthKit recorder or Watch transport exists in these 64 runtime files. Whole-repository native target/toolchain inventory and Apple API/hardware requirements must be taken from the parent audit, not inferred solely from this subtree. A native watchOS workout owner, iOS companion, secure native authentication and physical paired-device validation remain implementation work.

### RT-W04 — P1 before multi-device writes: sets lack stable identities and commands are array-targeted

Exercises can have stable `entryId` values (`src/workoutSession.js:15–20`, `:44–49`), but sets are constructed as anonymous records (`:28–38`) and schema `src/storage.js:52–86` has no set ID. Workout updates address array indices (`src/components/Workout.jsx:269–325`), while automatic hold completion can retarget them (RT01). Cross-device durable commands must carry stable session/exercise/set/event IDs, versioned explicit operations and idempotent acknowledgements. Existing operation IDs protect exact whole-workspace retries; they do not make arbitrary repeated set commands safe.

## Catalog validation and limitations

All 11 catalog JSON paths were parsed and every record processed by `runtime-catalog-probe.mjs`: 1,645 imported exercises, 50 supplemental records, 1,645 instructions, 280 aliases, 20 hidden IDs, 363 overrides, 6 programming aliases, 413 unilateral mappings, all 1,411 load classifications, 13 timer exclusions, 24 equipment corrections, 32 animations, 4 demo sources/22 clips/22 mappings, and 1,263 media assets/185 previews/1,411 mappings. All 1,711 exercise defaults and all 1,411 selectable exercise workspaces were validated. The 392 unique hash-bearing local media/video files match their manifest SHA256 values. The final run performed 65,404 assertions with no structural/referential/default-validation errors; a separate all-file parser check found no duplicate JSON object keys.

The probe records 127 imported blank taxonomy labels (runtime search filters blank labels) and 18 legacy HTTP attribution URLs. These are data-quality/maintenance notes, not demonstrated workout-state or security failures. External sites were not fetched. Structured validation does **not** mean every technique sentence, licensing status, animation or AI-assisted artwork received new expert/visual review.

UI, legal and CSS findings are appended from `runtime-ui-findings.md`. `runtime-review.json` reconciles every manifest path with exactly one source-review or structured-validation row; it is the coverage authority.


---

# Fresh UI/runtime subreview

Commit: `1794dd27fad87e8f0cc6f4923d37eedf713783ed`.

All 28 assigned files were read in full: 23 JSX files, the complete legal content module, and four CSS files (12,072 lines). Each path and SHA-256 was checked against the runtime manifest. The 28-row ledger is `runtime-ui-review.json`. This is read-only repository work: scratch artifacts/probes only; no source changes, account mutations, production requests or real member data.

## Confirmed defects

### RUI01 — P2 — Privacy sharing language omits the offered coach/AI disclosure

- `src/legal/content.js:74–85` lists Cloudflare/DigitalOcean, then says “We do not otherwise disclose your personal information to third parties” outside legal/safety cases.
- `src/components/Account.jsx:2104–2109` explicitly offers coaching tools/AI assistants read or full-workspace access; `:2124–2128` describes full token access to routines, workouts, history, profile and schedule.
- Source reproduction: read Privacy → “Who we share it with”, then Account → Security → Coach access. The two descriptions conflict; user-authorized coach disclosure has no policy carve-out. This is a factual product/disclosure mismatch, not a conclusion that authorization is bypassed or a legal compliance judgment.
- Correction direction: describe voluntary token-based third-party sharing, scope, revocation, recipients' independent handling and future health-data exclusions. Runtime/server reviewer owns the exact exported fields.

### RUI02 — P2 — Account crash recovery exports the guest store or an empty file

- `src/components/ErrorBoundary.jsx:20–26` always calls `downloadData(localStorage.getItem(STORAGE_KEY) || "", ..., true)`; `:35` labels this “Download saved data”.
- `src/main.jsx:9–13` places this same error boundary above both the AccountProvider and App, so it handles signed-in cloud workspace rendering failures too. There is no account-scoped export path or explanation that the button reads guest data only.
- Isolated fresh callback reproduction: the actual JSX was transformed in memory, the failed boundary rendered and its download handler invoked with synthetic localStorage/download mocks. With a synthetic guest record the exported payload was exactly that guest record; with no guest record it was an empty string. See `runtime-ui-probes.json` and rerun `node runtime-ui-probes.mjs` from the evidence directory.
- Result: a signed-in user following the recovery instruction does not receive their account workspace. This does not prove a server data-loss event or expose another account's server data. Make recovery exports match the failed storage scope or clearly label the guest-only fallback and provide account recovery instructions.

### RUI03 — P3 — The account dashboard claims persistence on the device

- `src/components/Overview.jsx:308–312` uses only `saved` to emit “Saved on this device.”
- `src/App.jsx:505–508` supplies `saved={issue !== "unavailable"}` for both guest and account workspaces. It does not pass the persistence mode into Overview.
- Source reproduction: open Overview in authenticated account mode with available cloud data. It uses the same local-device guarantee as guest mode even though account persistence uses the cloud repository. The same flag also affects active-session saved copy at `Overview.jsx:201–206`.
- Scope: inaccurate status copy, not evidence that cloud acknowledgements are broken. Pass and display the actual storage/sync mode; avoid implying a durable on-device account backup.

### RUI04 — P2 — Account summary captions fail normal-text contrast

- `src/account.css:282–291` gives `.account-summary-card` a white background; `:313–315` gives its captions `#858d86` at 9px.
- Examples are the `SummaryCard` detail text in `src/components/Account.jsx:476`, populated at `:1362`, `:1368`, `:1374`.
- Fresh calculation using WCAG sRGB relative luminance: `#858d86` against `#ffffff` = **3.4138:1**, below 4.5:1 for normal-size text. The exact chosen colors/font were also confirmed in a fresh headless Chromium computed-style probe at 390×844 using the complete actual stylesheets and matching synthetic class markup, with all network requests aborted (`runtime-ui-css-probe.json`).
- This is a concrete source/computed-style contrast failure, not a fresh full-app axe total. Use a darker caption color and verify all affected statuses/text in the full UI.

### RUI05 — P3 — Auth screens reference color variables defined only on the signed-in wrapper

- `src/account.css:1–6` defines `--ac-lime`, `--ac-muted` and related variables on `.account-page` only.
- `src/components/Account.jsx:179` renders the signed-out root as `.account-auth-layout`, before the authenticated `.account-page` return at `:1184`. It therefore does not inherit those variables.
- `src/account.css:1031`, `:1043`, `:1100` use the undefined tokens for the auth dot, emphasized heading and subtitle. The guest/error `.account-workspace-state` also uses `--ac-muted` at `:970–972` outside `.account-page`.
- Fresh 390px Chromium computed-style probe with actual CSS confirmed the auth accent variable is empty, the dot background is transparent and the heading accent inherits `rgb(245,246,242)` rather than lime. See `runtime-ui-css-probe.json` / `runtime-ui-css-probe.mjs`.
- Move common account tokens to a shared ancestor or define them on each relevant root. This is a visual consistency defect, with no account-boundary impact.

## Watch-specific gaps and verification limits

- Account currently offers browser account security, training import/export and broad coach tokens; it has no Watch connection/setup, HealthKit permission, source/sample availability or per-destination saved/synced UI. Those belong to a native integration contract, not to the decorative Smartphone icon.
- Legal health text (`src/legal/content.js:56–58`) describes manually entered workout records and account consent. It does not specify future sensor collection, HealthKit read/write purpose, Watch/device caches, HealthKit versus cloud export/deletion outcomes, or separate coach access to health summaries. Define these before adding health sync.
- HoldTimer is a controlled web display and exposes callbacks, not a native session recorder or background/haptic owner. The parent runtime review owns its actual timing/persistence defects in Workout.jsx.
- Important correction to the previous mobile-input observation: ordinary inputs/selects/textarea become **16px** under `src/styles.css:2931–2936` for widths at most700px. Account inputs remain **12px** because `src/account.css:532–541` has more-specific class selectors. Both values were freshly confirmed in the synthetic Chromium style probe. Actual iPhone focus zoom/keyboard behavior remains untested; do not present the 14px desktop base as proof of general mobile zoom failure.
- Four CSS files parsed completely with PostCSS: account258 rules/870 declarations; brand-motion57/196; styles688/2,133; workout-history79/237. Full source review checked responsive rules, focus styles, safe areas and reduced-motion overrides. This does not certify every screen visually or establish VoiceOver/Dynamic Type/physical Watch usability.
- Initial style probe could not launch Playwright's missing bundled browser. It was rerun successfully using the installed `/usr/bin/chromium`. No browser installation or repository mutation occurred. A first Node callback probe attempted the TypeScript compiler API, but TypeScript7 here exports version metadata; the successful evidence uses the installed esbuild transform in memory instead.
