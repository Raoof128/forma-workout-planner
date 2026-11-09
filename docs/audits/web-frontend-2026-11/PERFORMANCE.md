# Performance

## Change measured

The browser bundle no longer carries each exercise's `description`. That field
is a 360-character preview of the full instructions, which the guide already
loads lazily from `instructions.json`. A build-time Vite transform
(`scripts/vite-lean-catalog.mjs`) drops it from the browser copy of
`src/catalog/exercises.json` only. The API reads the JSON through Node, and
the native resource build reads the file directly, so neither is affected.
`unit/lean-catalog.test.js` checks that every sourced exercise still has
lazily loaded full text.

## Build output (Vite 8.3.5, guest build)

| Asset                     | Before                       | After                        | Change                  |
| ------------------------- | ---------------------------- | ---------------------------- | ----------------------- |
| Main JS chunk             | 2,949.63 kB (560.29 kB gzip) | 2,593.21 kB (444.02 kB gzip) | −12.1% raw, −20.8% gzip |
| Lazy `instructions` chunk | 888.78 kB (241.10 kB gzip)   | 888.78 kB (241.10 kB gzip)   | Unchanged               |
| CSS                       | 87.29 kB (18.04 kB gzip)     | 87.34 kB (17.99 kB gzip)     | ≈0                      |

## Lab startup comparison

**Method.** The script (`perf.mjs`) is kept as session evidence and was not
committed.

- **Builds:** the baseline guest build of `53c4877` against the final guest
  build, each served by the same minimal gzip static server (level 6), so the
  transfer size is compressed as it would be in production.
- **Browser:** headless Chromium 1243 at a 1440 × 1000 viewport, with a fresh
  context and the cache disabled for every load.
- **Samples:** each variant was loaded once as an unmeasured warm-up, then
  measured 5 times. The table shows the median with the range in brackets.
- **Throttled profile:** the same profile as the October audit: CDP 4× CPU
  slowdown, 40 ms latency, 209,715.2 B/s down and 96,000 B/s up.
- **Quiet machine:** nothing else was running during the measurement.

| Metric                         | Before                 | After                  | Change                                  |
| ------------------------------ | ---------------------- | ---------------------- | --------------------------------------- |
| JS transfer (gzip on the wire) | 561,573 B              | 446,053 B              | −115,520 B (−20.6%)                     |
| Throttled cold LCP             | 5,212 ms [5,148–5,508] | 4,736 ms [4,580–4,760] | −476 ms (−9.1%); ranges do not overlap  |
| Throttled cold FCP             | 4,080 ms [3,964–4,332] | 3,572 ms [3,424–3,636] | −508 ms (−12.5%); ranges do not overlap |
| Native cold LCP                | 364 ms [324–392]       | 336 ms [296–368]       | −28 ms; ranges overlap                  |
| CLS (all loads)                | 0                      | 0                      | Within the 0.1 target                   |

## Targets

| Target       | Status                                                                                                                                                                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LCP ≤ 2.5 s  | **Not met under the throttled lab profile** (4.7 s). Met at native speed. The remaining cost is about 444 kB of gzip JavaScript, mostly the exercise catalogue the app needs offline. |
| INP ≤ 200 ms | Not measured. No field data exists, and the October audit's interaction proxies were not repeated.                                                                                    |
| CLS ≤ 0.1    | Met in every sample (0).                                                                                                                                                              |

These are lab numbers on loopback. There is no field (CrUX or RUM) data, and
no hosted or real-device measurement.

## Further options, not done

- **Guide images:** a mid-size WebP tier for guide images (item D-02 in
  AUDIT.md). The 1.5–2.0 MB PNG atlases dominate the bytes when a guide is
  opened, though they do not affect startup.
- **Catalogue split:** move catalogue attribution (`source`) to a lazy chunk,
  for a further estimated 22 kB gzip. It is also needed for the guide credits,
  so the loading state would cover them too.
- **Route split:** rejected in October because it broke first navigation
  offline. Revisit only with a service worker.
