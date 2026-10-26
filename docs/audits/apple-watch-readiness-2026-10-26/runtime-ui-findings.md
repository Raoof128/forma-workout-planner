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
