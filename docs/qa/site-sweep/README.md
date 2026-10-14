# Whole-site review — 14 October 2026

All 1,414 selectable exercises have reviewed, guide-matched original artwork.
The subsequent desktop/mobile site review is complete. Fixes and generated
sources are pushed to main; the live deployment has not been updated.

## What changed

- Library cards use small WebP previews; guides retain the original PNGs.
  Reviewed atlas proportions are unchanged. Byte hashes, cache versions,
  dimensions and provenance are verified against the original registry.
- Legal contents links focus the destination heading and respect reduced motion.
  Phone scroll margins keep those headings below the sticky navigation header.
- Account backup import shows keyboard focus. Registration, recovery and MFA
  transitions focus their new visible heading; initial route focus is preserved.
- Original generated monochrome hero and routine photos replace photographs
  whose redistribution terms were undocumented. Phone hero crops retain the
  face; routine crops retain the bar/bell grip. Mobile routine-detail banners
  show the selected sprite column rather than the whole sheet.
- Workout lookup uses the existing exercise-ID map. Singular exercise counts
  are displayed correctly. Saved identities, measurement units, API methods,
  authentication and ownership boundaries are unchanged.
- Generated traces/scratch are excluded from Vite's watcher and source checks.
  Test runners use distinct artifact folders; trace HTML previously triggered
  full reloads and shared output folders collided.

## Measured image payload

These are cold local development-browser resource measurements, not production
network benchmarks or Core Web Vitals claims. Native lazy-loading thresholds
affect which offscreen images are requested.

| Viewport | Before encoded image bytes | After encoded image bytes |
| --- | ---: | ---: |
| Desktop 1536×1024 | 15,047,445 | 278,134 |
| Mobile 390×844 | 7,330,382 | 155,102 |

Observed image payload fell about 98%. All 186 preview files total 5,681,534
bytes. Source PNGs and registry remain unchanged. Preview export needs FFmpeg
with libwebp only when a derivative is missing; normal builds use committed files.
Runtime JSON is smaller, while gzip size rose slightly with new hash metadata.

## Verification

| Check | Result |
| --- | --- |
| Strict artwork coverage | 1,414/1,414; zero remaining |
| Unit cases | 62 passed |
| Guest cases | 112 unique cases verified across full run and exact failed replay |
| Account service journeys | 18 passed; desktop/mobile Chromium |
| Account form-focus regressions | 4 passed; real app with mocked local responses |
| Production cases | 40 passed across Chromium, Firefox and WebKit |
| Final legal/import-focus checks | 7 passed |
| Lint, formatting, types, docs and build | Passed; logs preserved |

The system Chromium two-worker run recorded 86 passes and 26 failures. Most
were aggregate time limits; the others were a late fallback heading, a 24ms
clock bracket overshoot and a 10.712s large-history measurement against a 10s
bound. The exact 26 failed cases passed with matching bundled Chromium and one
worker. Accessibility setup now seeds before one direct navigation. Timer
assertions bracket actual browser timestamps around the click. Saved-data
assertions, ordinary 30s guest budgets and the 10s performance bound remain intact.
This is complete case coverage, not a one-shot green full-suite claim.

The 18 real-service account journeys used a 120s CLI budget after diagnosing
long multi-step flows. They use disposable PostgreSQL schemas, synthetic members
and a local email sink. Test services and the database are stopped. New form-focus
tests separately mock local responses; no external email or live member operation
occurred. Four focus regressions failed before the fix. A further phone legal
regression failed because the heading was behind the header; it passes now.

Production checks used the freshly built guest app with matching Chromium 156,
Firefox 157 and WebKit 27.2 builds. WebKit's downloaded wrapper was locally amended
to preserve the dependency library path. Actual browser launches and all 40 cases
passed. Mobile checks are emulation; these results do not certify physical devices,
assistive technologies or live account infrastructure.

## Evidence and sources

Fresh captures cover all ten guest routes, guides, active workouts, account
screens and routine-detail covers. Capture reports, accepted images and rejection
notes are included. Early paint-incomplete library captures were replaced after
visible images decoded. The mobile registration capture was replaced after the
form-focus repair. Prompts, original PNGs, exports and hashes live in
`assets/site-visuals` and `docs/research/site-visuals`.

Official documentation was fetched on 14 October 2026; receipts are preserved.
This establishes API guidance as retrieved, not that every dependency is the
newest release:

- [React lazy](https://react.dev/reference/react/lazy) and
  [deferred values](https://react.dev/reference/react/useDeferredValue).
- [Vite features](https://vite.dev/guide/features) and
  [production builds](https://vite.dev/guide/build).
- [MDN images](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img),
  [scrollIntoView](https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView)
  and [reduced motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion).
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/),
  [focus visibility](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html)
  and [focus order](https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html).
- [Playwright browser builds](https://playwright.dev/docs/browsers).

The source audits also identify possible future work: broader catalog/route
splitting, timer render isolation and near-limit storage profiling. Those are
structural recommendations, not proven failing behaviors or completed rewrites.
Preserve historical IDs, source attribution and recovery/transaction semantics
before attempting them.
