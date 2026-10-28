# Asset-file audit

All 719 assigned asset/public paths received individual checks against the audit manifest. The per-file ledger records the exact method; none is labeled visually reviewed.

- 627 PNG/JPEG/WebP files: image integrity verification followed by full raster decode and dimensions.
- 22 MP4 files: metadata plus full ffmpeg decoding.
- 65 SVG files: XML parse, element scan, event-handler/script and external-href inspection. No flagged active content or external hrefs found.
- 2 WOFF2 fonts: full FontTools table decompression/parse; isolated Brotli dependency was installed in the scratch audit directory after the initial environment lacked it.
- README and two SIL font licenses: complete authored-text review.

No corruption was detected by these checks. This does not establish anatomical/technique accuracy, visual accessibility, licensing ownership, or Apple-device performance. The exercise animation README explicitly says the poses have not been coach reviewed. Runtime mapping/hash/default checks are reported separately by the runtime auditor.

The public directory totals 354,876,564 bytes across506 files; it contains original high-resolution images as well as web previews. This is a distribution footprint, not a measured initial page payload. The native Watch should receive compact prescriptions and selected appropriately sized assets; copying the public asset tree to Watch is not recommended. No unsupported claim that all assets load at startup is made.
