# Browser release evidence

This package contains 63 original browser PNGs: 21 public production BEFORE, 21 final protected staging and 21 public production AFTER captures. Each phase covers sign-in, sign-up, password-reset entry, Overview, Library, Progress and Privacy at 320, 390 and 1440px. Auth forms were never submitted.

- [Browse the 21 matched production pairs](comparison.html)
- [Matched pair paths, timestamps and hashes](PAIRS.json)
- [Manifest and all 63 PNG hashes](MANIFEST.json)
- [Production BEFORE receipt](public-before/receipt.json): observed Worker `ed075a4c-250f-499f-9417-048138eac630`. Frontend Git source is unverified; native asset URLs/body hashes identify the observed frontend. The separately observed backend tag maps to `55d6dc10c5924d37b9b8335704095269f4838d28` and does not establish frontend source.
- [Final staging receipt](staging-final/receipt.json): Worker `98eecbb4-4c5e-49ad-9e9d-7d062f9c252c`, exact `af8f476420e2e4451c03ae0537e936eba457c2c7` build verified through native HTML/entry-body hashes. Staging verification remains distinct from production acceptance.
- [Production AFTER receipt](public-after/receipt.json): Worker `3a5980c7-d697-49b0-bd23-d4a5cd808631`, the same exact `af8f476420e2e4451c03ae0537e936eba457c2c7` build independently verified through native production HTML/entry-body hashes after the release signal.

Production BEFORE completed 18 frames before an ENOSPC PNG-write interruption. The remaining three 1440px frames were captured after disk recovery while production was unchanged. Both attempts remain distinct: 22 actual focus checks cover 21 unique states because the continuation repeated one check. The earlier staging 212 set remains private historical evidence.

All three phases have zero attempted mutations and zero measured page, console, HTTP, external-request, focus, overflow or media errors. BEFORE records 66 requests; final staging and production AFTER each record 51. Each phase contains 21 font-ready captures, 72 decoded Library thumbnail instances (24 at every width) and six decoded background-photo instances. Final staging and production AFTER each pass six live loaded-font text-line/emblem checks at 320, 360, 375, 390, 430 and 540px. The pre-existing narrow copy/emblem intersection is visible in BEFORE and resolved in both final phases.

All PNG bytes are unchanged. Relative paths in receipts, manifests and the standalone comparison resolve within this checkout. The comparison uses inline CSS and local images, with no scripts, external fonts or network dependencies. It compares production with production, retaining actual dates and capture times. A changed PNG hash alone is not a visual regression finding.

Critical production AFTER images were inspected individually: 320px signup, 1440px Overview and 320px Library structural capture. All 21 states have recorded automated media, focus and geometry checks. The resized full-page Library preview is not a fine-detail review of every thumbnail. No account data, access material, private host paths, raw traces or header payloads are published. No new accessibility-conformance, physical Safari, real-account submission or performance claim is made.
