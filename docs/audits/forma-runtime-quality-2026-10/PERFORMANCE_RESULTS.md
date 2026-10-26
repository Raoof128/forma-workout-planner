# Performance results

## Outcome and comparison conditions

The largest demonstrated interaction gain is the populated Progress screen:
**344→48 ms median (86.0% lower)** at 390px with 4× CPU slowdown, and
**91→35 ms (61.5% lower)** at native desktop speed. Both variants render the
same validated 1,000-session history. Established authenticated workspace GETs
perform **six→three SQL statements**, including the unchanged authentication
queries. Cold startup remains approximately **5.1 seconds** under the lab
throttle and does not meet the 2.5-second LCP target. No startup win is claimed.

Browser comparisons below were captured on 26 October 2026 in an exclusive
profiling window: Linux headless Chromium **156.0.8078.4**, production guest
Vite preview, host Node **24.19.0**, original commit `678b483` versus final source.
The host exposes five CPUs with a four-CPU cgroup quota and 16 GiB memory limit.
Each startup profile uses three fresh-context cold loads and three warm reloads:
**12 loads per variant**. Startup viewport is 1440×1000. The slow profile uses
4× CPU slowdown, 40 ms configured latency, download **209,715.2 bytes/sec** and
upload **96,000 bytes/sec**. It is a mobile-like resource throttle at a desktop
viewport; the separate Progress interaction profile uses 390×844.

Both builds' served JavaScript hashes match their frozen local files. The final
source produces identical frontend assets with the original and patched npm
dependency trees. The measured server gzip body is decompressed and hash-checked;
rounded Vite console sizes and its compression estimate are not substituted
for observed HTTP bytes. Raw samples, methodology scripts and build proofs are
included in the selected evidence bundle.

## Loading, transfer and main-thread work

Values are medians; brackets show minimum–maximum. Each cell has three samples.
These small samples describe variation, not statistical significance or field p75.

| Metric | Baseline | Final | Assessment |
| --- | ---: | ---: | --- |
| Native cold LCP / FCP | 276 ms [272–304] | 280 ms [280–304] | +4 ms; overlapping range, no established change |
| Native warm LCP / FCP | 128 ms [112–168] | 140 ms [136–152] | +12 ms; overlapping range, no established change |
| Throttled cold LCP | 5,056 ms [5,044–5,300] | 5,088 ms [5,020–5,244] | +32 ms; target still missed |
| Throttled cold FCP | 3,884 ms [3,876–4,264] | 3,912 ms [3,852–3,932] | +28 ms; overlapping range |
| Throttled warm LCP | 572 ms [564–784] | 520 ms [508–564] | −52 ms observed; insufficient evidence of a startup optimisation |
| Throttled warm FCP | 552 ms [536–768] | 496 ms [480–536] | −56 ms observed; same qualification |
| CLS, all 12 loads | 0 | 0 | Within 0.1 target in these samples |
| Native cold navigation TTFB | 3.4 ms [2.8–11.9] | 4.1 ms [3.6–5.5] | Loopback only; not hosted response latency |
| Throttled cold navigation TTFB | 5.1 ms [4.8–9.2] | 3.5 ms [2.9–10.1] | Loopback only; no hosted claim |
| Cold initial JavaScript, gzip body | 560,332 bytes | 560,862 bytes | +530 bytes / 0.095%; no payload reduction |
| Cold initial JavaScript, decoded | 2,947,063 bytes | 2,947,944 bytes | +881 bytes / 0.030% |
| Initial resource entries after HTML | 6 | 6 | Entry JS, CSS, two fonts and two WebPs |
| Native cold script execution | 116.9 ms [111.8–118.1] | 124.6 ms [124.5–124.8] | +7.7 ms observed; no execution-time win |
| Throttled cold script execution | 594.8 ms [572.3–790.6] | 586.3 ms [544.0–631.0] | −8.6 ms; overlapping range |
| Native cold long tasks | 1; excess 41 ms [35–42] | 1; excess 45 ms [43–46] | +4 ms observed; no blocking-work win |
| Throttled cold long tasks | Median 2; excess 517 ms [492–756] | Median 2; excess 511 ms [479–568] | Essentially unchanged |
| Native warm long-task excess | 0 ms | 0 ms | No task over 50 ms observed |
| Throttled warm long-task excess | 180 ms [173–402] | 143 ms [123–147] | Lower in this sample; no broad startup claim |

Script execution is CDP `ScriptDuration` from cold documents. “Long-task
excess” sums `max(task duration − 50 ms, 0)` over the observation interval;
it is **not Lighthouse Total Blocking Time**. Resource-entry counts include
cached resources and exclude HTML; they are not a count of warm wire requests.
Warm cache/304 entries can report zero JavaScript body bytes while the code
still executes. TTFB uses navigation start→responseStart. Original 23 October
samples used a narrower requestStart→responseStart field and are not mixed in.

CSS remains 87,298 decoded / 17,909 gzip bytes. The two local fonts are
36,932 and 22,444 encoded bytes; hero and routine backgrounds are 127,994 and
119,526 bytes. Media, fonts and CSS were not changed or recompressed. Native
script/long-task observations are slightly higher; the retained changes are
justified by specific correctness defects and the measured heavy-history gain,
not by claiming every metric improved.

## Interactions and rendering

Each browser interaction has five trials. Timings end after the exact target
heading commits and two animation frames, or after a weight edit and two
frames. They are lab proxies, **not INP**. There is no valid field INP/p75 dataset.
The 390px/4×CPU Progress profile is a warm in-app transition using native
loopback networking; it does not also apply the startup network throttle.

| Interaction | Baseline median [range] | Final median [range] | Assessment |
| --- | ---: | ---: | --- |
| Progress, 1,000 sessions, desktop native | 91 ms [90–95] | 35 ms [22–37] | 61.5% lower; non-overlapping ranges |
| Progress, same history, 390×844 and 4× CPU | 344 ms [318–383] | 48 ms [46–131] | 86.0% lower; non-overlapping ranges |
| Workout weight input, desktop native | 25 ms [20–37] | 31 ms [29–32] | +6 ms; overlapping frame-scale range, no input-speed improvement claimed |

The history fixture is 1,979,980 bytes; the rendered 1,000-session total is
asserted in both variants. Exact helper output parity and saved-ID ordering
are tested, and populated Progress screenshots are compared. Weight edits
persist the final weight, reps and completed state with no page errors.
No profiler page errors were recorded in the measured flows.

Production React root-hook observations are startup **2→2** commits, idle
workout **4→4** per 1.1 seconds, running rest **4→4** per 1.1 seconds, and five
sequential weight fills plus 300 ms **18→17**. These include persistence and
250 ms timer work; they are not per-component render counts. One fewer commit
in a short window is not a claimed structural rendering improvement. The
existing workout tick remains; blanket memoisation and timer restructuring
were not justified by a demonstrated input bottleneck.

An isolated exact-output Progress helper comparison independently confirms
that one aggregation pass removes the repeated catalog-by-history scans:
eight samples gave 91.67→0.50 ms median. That original function experiment is
supporting algorithm evidence, not a substitute for the contemporary browser
results above. Search profiling uses Node 24.19.0, 1,411 records, 30 alternating
samples with 30 filters per sample after warmup:

| Full-catalog query | Baseline median | Final median |
| --- | ---: | ---: |
| Empty | 2.075 ms | 0.022 ms |
| `pushup` | 3.503 ms | 1.164 ms |
| `chest dumbbell` | 3.998 ms | 1.336 ms |

These are small absolute CPU savings. The last-query cache is bounded and
normalized metadata uses a WeakMap keyed by object, with mutation invalidation;
there is no accumulating query-result cache. The backup-fingerprint correction
has only a deterministic claim: hash the same captured snapshot once per mount,
rather than on each render. Unverified old timing metadata is excluded.

## API and database

Final paired measurements use **Node 26.12.1 / bundled Undici 8.12.2 for both
variants**, isolated PostgreSQL 18.4 and synthetic verified member sessions.
The baseline retains original source and npm dependencies; the candidate uses
final security patches. Each fixture has 10 warmup pairs and **100 sequential
AB/BA measured pairs**, warm pool connections, maximum pool size 10 and request
concurrency 1. Timing covers real HTTP GET through full response-body receipt,
including authentication, validation and serialization; client JSON parsing,
Worker/Access/Tunnel, TLS and public network are excluded.

| Authenticated GET | Baseline p50 / p95 | Final p50 / p95 | Assessment |
| --- | ---: | ---: | --- |
| Empty workspace, 3,262-byte response | 3.970 / 5.159 ms | 3.088 / 3.851 ms | Median −22.2%, p95 −25.4%; 96/100 candidate pairs faster |
| 100 sessions, 570,751-byte response | 22.138 / 40.153 ms | 20.918 / 35.132 ms | Median −5.5%, p95 −12.5%; 65/100 pairs faster |
| SQL statements, established authenticated GET | 6 | 3 | Deterministic 50% reduction; two auth queries remain |
| Workspace-read SQL alone | 4 | 1 | Deterministic 75% reduction |

Larger-response tails remain variable: the candidate maximum is **160.349 ms**
versus **86.540 ms** before. The measured p95 improvement does not establish
uniform tail improvement or a production percentile. Whole-workspace validation
and serialization still scale with history size. The strongest conclusion is
the removed queries with ownership, validation and write consistency preserved.

The older function-level paired experiment (Node 24) measured empty-workspace
p50/p95 1.734/2.564→0.652/0.904 ms and 100-session 17.016/23.215→14.174/21.655 ms.
It is a different boundary and is not merged with the final HTTP figures.
A 10,002-owner query plan uses the existing primary-key index, one returned row,
three shared-buffer hits and 0.030 ms execution. No new index or migration was
justified. A missing owner's first read now pays one additional SELECT before
the original transactional creation; established reads receive the benefit.
Twenty concurrent mixed-owner first reads confirm correct one-row creation.

## Memory, repeated use and motion

Post-GC measurements return to the same terminal screen. Heap figures below
use decimal MB (1,000,000 bytes); each row is one repeated-use sequence per
variant, not a multi-hour device endurance test.

| Sequence | Baseline start→end | Final start→end | Interpretation |
| --- | --- | --- | --- |
| 90 route changes, heap | 15.385→15.818 MB | 15.419→15.834 MB | Similar small growth; no memory-reduction claim |
| 90 route changes, DOM nodes / listeners | 309→308 / 178→178 | 309→308 / 178→178 | Same terminal route; listeners do not accumulate |
| 40 guide cycles / 120 searches, heap | 12.254→12.908 MB | 12.594→13.270 MB | Final warmed footprint is about 0.36 MB higher; bounded metadata caching has a memory cost |
| Same guide/search sequence, nodes / listeners | 924→964 / 260→260 | 924→964 / 260→260 | The identical +1-node/cycle counter warranted investigation |

The counter increase was isolated rather than dismissed. Guide-only, native
dialog and idle controls have flat node counts. Search through Playwright
`fill` reproduces it, while connected application DOM remains **620 nodes**,
listeners **260**, and Chromium's detached-DOM query reports no retained trees.
A bare native input with **no FORMA or React code** reproduces **9→29→49 nodes**
after 0/20/40 cycles, with connected DOM four nodes and listeners unchanged.
Programmatic input events leave both the bare input (**7 nodes**) and the
application (**877 nodes**) flat. This identifies browser/automation input-editing
behavior as the source of that counter pattern; it does not demonstrate an
application modal leak. The original observations and all controls are retained.
No speculative application patch was added. These short controls do not prove
absence of every possible long-session leak.

Motion checks open routine overview, start an animated preview, and exercise
pause/play in three runs per version. Both versions start paused under reduced
motion. Median frame intervals are about **33.4 ms** in this headless environment;
per-run p95 spans 66.7–83.4 ms before and 50.1–66.7 ms after. Software-rendered
RAF scheduling is not a physical-display dropped-frame measure, and motion code
was not changed, so no 60fps or animation-speedup claim is made. No page errors
were recorded in these profiles. Wake-lock acquisition/release races have
separate deterministic browser regressions.

The effective **75 guest screenshot pairs** comprise 68 exact pixel matches
and seven with only 10–48 pixels differing by a single 8-bit channel level.
Dimensions match; the measured layouts have no horizontal overflow. Eight
Library pairs were recaptured after every lazy thumbnail decoded; premature
originals remain separately identified. Four extra account pairs show only
the intentional Sydney date/week/hint corrections. The visual bundle preserves
all original and replacement captures, and the regression report describes
manual inspection and responsive coverage.

## Rejected optimisation and remaining work

A scratch training-route split reduced entry gzip bytes by 29%, but the first
Routines transition rose **190→1,443 ms** median over three paired throttled
runs. Loading Overview and then disconnecting also broke first training use.
The split was rejected and never entered final source. No asset degradation,
feature removal, new caching system or dependency was added to force a score.

The primary remaining performance opportunity is cold startup: investigate
ways to reduce eager catalog/media metadata while preserving immediate training
navigation and offline behavior. Physical-device motion, keyboard, battery and
wake-lock behavior, field INP/LCP, hosted API percentiles and production capacity
require separate environment access or a release-stage check. No claim is made
that this local audit establishes those results.
