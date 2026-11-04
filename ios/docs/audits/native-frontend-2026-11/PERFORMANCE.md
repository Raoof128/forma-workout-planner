# Physical performance evidence

Method: actual iPhone Air, iOS 27.2, Xcode 27.2, separately signed Debug audit bundle, deterministic synthetic data. Existing 10,000-history/200-routine widget-projection benchmark excludes fixture construction from its measured block. New launch/tab metrics use XCTest; tab wall-clock includes automation and synchronization overhead. These are development measurements, not Release frame-time, energy, thermal or battery claims.

Baseline raw sample arrays, units and variance: [PERFORMANCE_BASELINE.json](PERFORMANCE_BASELINE.json). Responsive-launch baseline returned only four measurements and an Xcode unexpected-metric-count warning; it is incomplete even though the test itself passed. Memory delta and absolute/peak metrics must be named separately; neither proves absence of leaks.

Final matched measurements and comparison will be appended after the final physical run. No speedup, FPS or battery improvement is claimed. Instruments Time Profiler/Animation Hitches/Allocations/Leaks/Energy/thermal soak and long training-session profiling remain outstanding.
