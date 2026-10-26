# Performance baseline and methodology

## Baseline and environment

The unchanged source baseline is commit
`678b48325189f83beb942bc6759e7c519eb26b19`, preserved in an isolated worktree.
Measurements began on 23 October 2026 before retaining the audit fixes. The
restored dependency directory initially lacked a pinned Motion dependency;
`npm ci` restored the committed lockfile before the successful baseline build.
That initial build failure is an environment-restoration event, not a measured
application regression.

Browser measurements use a production guest build served by Vite preview on
loopback, Chromium **156.0.8078.4**, Linux headless, Node **24.19.0** and synthetic
data. The original API image used Node **26.12.0**; the final security correction
pins Node **26.12.1** with bundled Undici **8.12.2** and validates that runtime
separately. The diagnostic host remains Node 24.19.0.
The database is isolated local **PostgreSQL 18.4**. No live member data or public
production service was used.

The session resumed on 26 October. Contemporary baseline and final runs use
the same restored host and build mode; they are the comparison reported in
[PERFORMANCE_RESULTS.md](PERFORMANCE_RESULTS.md). The original samples below
remain useful initial evidence, but are not silently compared with a later
host's timings.

## Browser measurement protocol

- Native and mobile lab profiles each have three fresh-context cold loads and
  three subsequent warm reloads: twelve loads per variant.
- Mobile profile: CPU slowdown factor 4; 40ms simulated network latency;
  download `1.6 × 1024 × 1024 / 8` bytes/sec and upload `750 × 1024 / 8`
  bytes/sec. The exact rates are stated because browser throttle labels alone
  are ambiguous.
- PerformanceObserver records LCP, layout shifts excluding recent-input
  shifts, long tasks and available event timings. Navigation/resource timing
  supplies FCP, loopback TTFB, request counts and encoded/decoded bytes.
- Sampling waits for the exact Overview heading, completed resource-timing
  entries for both background WebPs, font readiness and a further observation
  interval. A generic `h1` can match the loading screen; network idle alone can
  precede later CSS image requests. Those earlier premature samples are retained
  separately and excluded.
- Input timing spans a weight edit through two animation frames. Progress
  navigation uses five trials with an asserted 1,000-session synthetic fixture
  (1,979,980 bytes). These are lab action-to-paint proxies, not field INP.
- Memory observations use Chromium's post-GC counters with equivalent terminal
  routes before/after ninety navigations. Root render counts use the production
  React DevTools hook; they include timer and persistence commits, not a count
  of every component render.
- Screenshots cover nine routes at widths 320, 375, 390, 430, 768, 1024, 1440
  and 1920, plus an active workout and two populated Progress views: 75 images
  per variant. The screenshot/input clock is fixed to 23 October at 01:00 UTC
  for comparable calendar content; performance timing remains monotonic.

The original October 23 `ttfb` field measured requestStart→responseStart only.
The contemporary baseline/final runs use navigation start→responseStart for
standard navigation TTFB; the old narrower field is not substituted for it.

The original heavy-history setup changed only the URL hash after seeding
storage, so the mounted repository never loaded the intended fixture. Those
samples were discarded. Corrected runs inject the fixture before mounting and
assert the rendered 1,000-session total. No invalid sample is used for a gain.

## Initial valid browser observations, 23 October

All values below are medians; brackets give the range of the three runs.

| Profile | LCP | FCP | CLS |
| --- | ---: | ---: | ---: |
| Native cold | 340ms [272–360] | See raw per-run samples | 0 |
| Native warm | 140ms [132–180] | See raw per-run samples | 0 |
| Throttled cold | 5,248ms [4,936–5,332] | 4,168ms [3,756–4,184] | 0 |
| Throttled warm | 480ms [472–492] | See raw per-run samples | 0 |

The throttled cold LCP exceeds the 2.5-second target. Native and warm loads do
not establish field p75 performance. All twelve observed CLS values are zero.

The initial entry script is **2,947,063 decoded / 560,332 gzip bytes**. Overview
loads six resources after the document: entry JS, CSS, two local fonts and two
WebP backgrounds. Fonts cost 36,932 and 22,444 encoded bytes; the backgrounds
cost 127,994 and 119,526 bytes. Styles are 87,298 decoded / 17,909 gzip bytes.
These are measured delivery bytes, not a claim about JavaScript CPU execution.

Five weight-input trials had a median of **24ms** [22–29]. Five populated
Progress navigation trials had a median of **93ms** [85–97]. Ninety route
changes returned to the same screen with event listeners **178→178**, DOM nodes
**309→308**, and post-GC heap approximately **15.39→15.83MB**. That short lab
sequence did not show unbounded retention; it does not prove absence of all leaks.

The React hook observed startup 2 commits, an active workout without running
rest 4 commits/1.1s, running rest 5 commits/1.1s, and five sequential weight fills
plus 300ms yielding 18 commits. The existing 250ms workout tick explains the
idle commits. Render count alone did not justify a risky state rewrite.

## Backend and algorithm baseline methods

The database comparison uses two distinct boundaries. A function benchmark
includes PostgreSQL read and workspace validation. A separate real HTTP
benchmark registers/verifies/signs in synthetic members, then measures the
authenticated request through complete response-body receipt. Both use ten
warmup pairs and 100 measured reads per variant/fixture in alternating AB/BA
order. The pool maximum is ten, concurrency one. The fixtures are an empty
workspace and a 100-session workspace of approximately 571KB.

These local HTTP measurements include session queries, validation and
serialization, but exclude Cloudflare, Access, Tunnel, TLS and the public
network. They are not production API p95. Client JSON parsing occurs after the
HTTP timer. Initial separate-run function measurements were noisy and are
superseded by the paired samples. An early HTTP harness with an undersized
single-connection pool produced no valid samples and is also excluded.

The final HTTP comparison is `http-workspace-final-paired.json`. Both variants
run under **Node 26.12.1 / bundled Undici 8.12.2**, while the baseline retains
its original application source and frozen npm dependencies. This matched
runtime comparison supersedes the earlier Node 24 HTTP series for final
claims. The older Node 24 function-level series remains separately identified.

Progress helper profiling uses identical 1,000-session input and exact output
parity. Search profiling compares the baseline function directly from Git with
the candidate over 1,411 selectable records, thirty alternating-order samples
per query, thirty complete filters per sample after warmup. Their CPU savings
are microbenchmarks, separate from browser responsiveness.

Historical backup-fingerprint timing numbers are not used because their
runtime-version metadata could not be verified after resumption. The retained
claim is simply removal of repeated hashing of an unchanged captured value.

## Interpretation limits

The Core Web Vitals targets used are LCP ≤2.5s, INP ≤200ms and CLS ≤0.1. No
valid real-user INP or field percentile is available. Three load samples show
variation rather than statistical significance. A fast loopback TTFB does not
represent the hosted service. Software-rendered headless frame timing cannot
certify physical-device 60fps motion. Contemporary measurements, long-task
observations, final memory checks and the retained/rejected changes are reported
in the results document.

Selected evidence names: `runtime/baseline/results.json`,
`runtime/baseline/heavy-results.json`, `runtime/baseline/react-profile.json`,
`workspace-paired.json`, `http-workspace-paired.json` (historical),
`http-workspace-final-paired.json` (final Node 26 comparison),
`ui/progress-comparison.json`, `search-final-benchmark.json`, and their matching
scripts. Superseded sample files are explicitly named as premature or invalid.
