# Physical performance evidence

Actual iPhone Air, iOS 27.2, Xcode 27.2, separately signed Debug audit bundle, synthetic fixtures. Before and after use the same hardware and harness. Fixture allocation is outside the 10,000-history/200-routine projection measurement. Tab clock includes XCTest interaction and synchronization; CPU and memory are app scoped.

| Measurement                     |  Before mean |   After mean | Samples before/after |
| ------------------------------- | -----------: | -----------: | -------------------: |
| 10,000-record widget projection |    20.188 ms |    19.926 ms |                10/10 |
| Four-tab XCTest clock           |      5.712 s |      5.749 s |                  5/5 |
| Four-tab app CPU time           |      1.472 s |      1.493 s |                  5/5 |
| Absolute app physical memory    | 80155.717 kB | 80018.067 kB |                  5/5 |
| Peak app physical memory        | 82865.630 kB | 82187.309 kB |                  5/5 |
| Responsive launch, incomplete   |   455.301 ms |   458.368 ms |                  4/4 |

Raw samples, units and variance are in [baseline](PERFORMANCE_BASELINE.json), [final](PERFORMANCE_FINAL.json) and [comparison](PERFORMANCE_COMPARISON.json). These small observed differences do not establish a speedup. The launch test passed but returned only four measurements with Xcode's unexpected-metric-count warning, so the launch benchmark is incomplete. Negative memory-delta values are deallocation during a measured interval; absolute/peak memory is reported separately and does not prove absence of leaks.

No Release frame-time, FPS, p95 response, battery, thermal or energy improvement is claimed. Instruments Time Profiler, Animation Hitches, Allocations, Leaks, energy/thermal soak and long training sessions remain outstanding. Host-heavy website work began only after native resource measurements completed.
