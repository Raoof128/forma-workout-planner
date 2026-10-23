# First native milestone: observed verification

23 October 2026, Australia/Sydney. Starting repository commit:
`678b48325189f83beb942bc6759e7c519eb26b19`. This records the local draft, not a
published app or an Apple approval.

## What was built

- A SwiftUI iOS 17 app source with native Today, Plan, Progress and You tabs.
- Editable routines, native exercise search/filtering, reviewed text guides and
  visible per-entry source/licence attribution.
- Measurement-specific set inputs, completion/undo, session notes, deadline-based
  rest with pause/resume/adjust/skip, and a committed workout receipt.
- Real local history/volume chart and an accessible equivalent list. New progress
  is empty; starter routines are editable examples.
- Actor-isolated SQLite workspace transactions, optimistic local revisions,
  previous-commit recovery and explicit corruption/schema failure states.
- Backup export through Files and confirmed logical deletion of training,
  previous snapshots and app recovery copies. Exported copies remain separate.
- System/light/dark appearance, System/Minimal/Off motion and optional confirmation
  haptics. Presentation settings use a separate protected local JSON file.
- Original editorial decorative artwork and an opaque 1024 px icon preserving
  the exact three-facet F geometry. See [provenance](../design/artwork-provenance.md).
- Reproducible XcodeGen configuration, three iPhone UI journeys and a macOS
  verification workflow. No account transport, signing or deployment was added.

## Checks actually run

| Check | Observed result |
| --- | --- |
| Swift 6.2 native package tests | **30 passed, 0 failed** on Linux |
| Actual Swift start → complete → finish exports checked by `src/storage.js` | **1,711 passed, 0 failed**, strict validation |
| JavaScript unit suite | **127 passed, 0 failed**, including ten native-resource checks |
| Native resource regeneration/check | Six deterministic outputs match; 1,711 accepted IDs / 1,411 selectable movements |
| `npm run lint` | Passed |
| `npm run typecheck` | Passed for the existing JS/TS project; does not typecheck SwiftUI |
| `npm run format:check` | Passed |
| `npm run docs:check` | Passed |
| `npm run build` | Existing web build passed; existing large-chunk warning remains |
| `swift-format lint` | Passed for native source/tests |
| Swift frontend syntax parse | Passed for app/UI-test Swift sources; **not** a SwiftUI typecheck |
| Plists/privacy manifest, asset JSON, project/workflow YAML | Parse successfully |
| Whitespace checks | Passed |

Native tests include every catalogue default, twelve web-generated golden cases,
per-side units, timed/distance/carry exclusions, rest deadlines, finish-once
behavior, committed-set restoration, two-writer conflicts, injected SQLite abort,
invalid-write preservation, corruption, unsupported schema and deliberate reset.
Input tests cover comma/dot decimals, nonfinite/ambiguous values, side totals and
preserving a load's full precision while another field is edited. Search tests
cover words across fields, diacritics, punctuation and negative matches.

The cross-language probe caught an actual serialization defect: missing `active`
must be explicit `null` after completion. A regression assertion now guards it.
Tests also exposed and fixed timed prescriptions incorrectly acquiring per-side
rep fields. Review fixed an unsupported accessibility modifier, private cross-file
view access, misleading saved status during draft editing, lossy input formatting,
obsolete raw guide display and ineffective UI-test assertions.

The existing workspace's installed dependencies lagged behind its lockfile and
initially lacked `motion/react`. Restoring with `npm ci --ignore-scripts` fixed the
web build. `package.json` and `package-lock.json` remain byte-identical.

## Reproduce

See [Mac build instructions](../README.md). From the repository root:

```sh
node scripts/build-ios-resources.mjs --check
node --test unit/*.test.js
swift test --package-path ios
swift run --package-path ios FORMAContractProbe . /tmp/forma-native-contracts.json
node scripts/check-ios-contracts.mjs /tmp/forma-native-contracts.json
```

This sandbox requires `node --test --test-isolation=none unit/*.test.js` because
its subprocess isolation can fail with `EPERM`. The verified local Swift compiler
was `/tmp/forma-swift/usr/bin/swift`; its official detached signature verified
successfully. Local module caches and SQLite headers were configured under `/tmp`.
Those tools are environment preparation, not repository dependencies or secrets.

## Explicit remaining gates

No Xcode project generation, SwiftUI compilation, simulator launch, XCUITest,
native screenshot, VoiceOver/Dynamic Type/keyboard rendering check, physical-device
interruption/file-protection test, performance/energy measurement, signed archive,
TestFlight or App Store submission ran on this Linux host. The workflow is
prepared but has not been pushed or executed remotely.

Numeric drafts remain explicitly unsaved until committed. Background saving of
valid drafts is best effort; incomplete raw text is not promised to survive
termination. The local-store tests prove tested committed operations on Linux,
not an absolute guarantee against every device/storage failure.

Web import, account authentication/sync, comprehensive rejection-corpus parity, history
correction, hold auto-completion timers, notifications and advanced superset
creation remain follow-on work. Current fields/units are preserved. Account sync
must not borrow coach tokens, weaken browser Origin checks or embed service secrets.

Complete the [App Review matrix](app-review-matrix.md), native legal/content
rights review, operator/entity/storefront decisions, privacy archive inspection
and device matrix before distribution. No native compliance certification or
guaranteed Apple acceptance is asserted.

## Honest milestone scorecard

These are engineering judgments, not benchmarks or Apple ratings.

| Axis | Current score | Concrete artifact needed to raise it |
| --- | --- | --- |
| Emitted data compatibility | 8/10 | Cross-language rejection corpus and lossless v1/v2 import/migration tests |
| Local durability | 7/10 | Passcode-device kill/lock/storage-pressure fault runs at maximum workspace size |
| Visual/interaction craft | 5/10 | Native screenshot/interaction matrix with Dynamic Type, keyboard and contrast evidence |
| Store readiness | 2/10 | Signed archive, final privacy/legal/rights decisions, device evidence and review dossier |

## Apple design and Liquid Glass refinement pass

23 October 2026, Australia/Sydney. This is a second source refinement of the
existing uncommitted native draft, preserving the initial evidence above.

Research covered 52 official Apple text/API/session sources, including five
complete WWDC26 transcripts, and three inspected HIG reference images. See the
[source register](apple-design-2026.md) and [complete file review](native-design-review.md).
The relevant native files were read individually; every generated catalogue and
credit record was checked programmatically and both original app PNGs decoded
and inspected. Generated build caches are excluded from authored-source review.

Changes include native active-workout tab accessories, a single functional glass
rest pane with safe-area/scroll-edge integration, semantic glass foregrounds,
opaque Reduce Transparency/Increase Contrast alternatives and stronger contrast
variants. Fields, charts, guides, receipts and history remain opaque. Header,
metric, week, set-row and rest layouts now adapt to narrow widths and large text;
rest text reserves its maximum width/height to avoid timer-driven geometry shifts.
Completion and undo remain in place, and Finish is directly available in the toolbar.

Routine targets now support direct validated numeric input. Workout and routine
editors share a full-string locale-aware parser that preserves precision and
accepts appropriate localized digits/decimal separators. Invalid drafts remain
visible and block saving. Profile/notes editors protect unsaved changes; the
routine picker navigates inside its existing editing sheet. Charts retain native
mark accessibility/Audio Graphs and also offer their actual values as text.

Local mutations now wait in a tested FIFO gate instead of dropping valid lifecycle
saves behind rest writes. Each queued active-session action rechecks the session
identity before applying. Unequal side counts remain editable and SQLite checks
BLOB bounds before copying data. These changes improve the tested behavior; they
do not turn background raw-draft saving into a guarantee against OS termination.

Fresh results:

- **44/44** Swift package tests passed on Linux.
- **129/129** JavaScript unit tests passed, including **12** native-resource cases.
- **1,711/1,711** fresh actual Swift-generated finished workspaces passed strict
  web validation.
- Six generated outputs reproduce; icon rasterization matches existing pixels
  and SHA-256. Both original PNG files remain unchanged.
- Repository lint, types, formatting, docs and existing web build pass. Native
  source syntax/format and config/plist parsing pass.
- **37** normal/increased-contrast solid-color text and border pairs were
  mathematically checked against their 4.5:1 or 3:1 targets. Translucent,
  composited and rendered combinations still require native QA.

The macOS workflow now selects and verifies Xcode/iOS SDK **26.1+**, requires a
26.1+ primary simulator, and reports optional iOS 17 and 26.0 runs separately.
The deployment floor remains iOS 17. Five UI journeys are authored, including
resume/tab preservation and decimal-entry/rest restoration; they were **not run**
on this Linux host. No workflow was pushed or remotely executed.

Xcode compilation, native rendering, accessibility/device/energy checks, signing
and App Store release gates remain open. This pass establishes source changes,
research traceability and the results above; it does not establish native visual
sign-off or App Store approval. The visual/interaction score remains **5/10**
until the native screenshot/interaction matrix is available. Data compatibility
remains **8/10**, local durability **7/10** and Store readiness **2/10**; the
missing artifacts named in the first scorecard still govern higher scores.

## Full file-by-file correctness audit

23 October 2026, Australia/Sydney. This audits the current native draft after
the refinement pass, rather than reapplying it. Coverage is all **68 authored
native files** (including two review reports), eight integration files and six
shared contract modules. The [file report](native-design-review.md) and
[SHA-256 ledger](native-file-review.json) distinguish complete source reading,
exhaustive generated-record checks and binary image inspection. No authored
native input was skipped; build/package caches are excluded.

New repairs include:

- Freeze submitted workout and notes drafts before awaiting SQLite; clear only
  the exact values acknowledged. Newer drafts remain editable and prevent
  programmatic close/Finish. Lifecycle saves still queue behind other writes.
- Resolve queued completion/add-set work by captured session and entry identity.
  Search every duplicate exercise occurrence for the actual latest completed set.
- Keep deleted journal details tied to current stored IDs, removing stale personal
  content after reset. Successful deletion clears prior error presentation.
- Avoid invalid per-side stepper ranges, preserve another row's invalid input
  when IDs share a prefix, and guard duplicate routine Save tasks.
- Preserve saved load in time-and-distance controls/history and label lifting
  volume consistently as kg × reps.
- Use portable ISO Sydney dates in backup names and release the temporary backup
  snapshot when the system export dialog finishes or cancels.
- Export compact canonical JSON: an actual valid 150,000-set synthetic backup is
  **11,580,553 bytes**, versus **36,416,138 bytes** with pretty-printing. The compact
  output passes both `parseBackup` and strict web validation within the 20 MiB cap.
- Reject optional zero routine targets, completion-only active metadata and
  invalid/noncanonical UTC completion dates with a shared **38-case** corpus.
- Preserve each distinct corrupt original once instead of making a new full copy
  on every Retry. Distinct damaged originals remain preserved separately.
- Compare probe measurements/defaults/completion independently of schema
  acceptance; seven schema-valid corruptions are now rejected by the checker.

Fresh combined verification:

| Check | Observed result |
| --- | --- |
| Swift 6.2 package | **62 passed, 0 failed**, Linux |
| JavaScript units | **134 passed, 0 failed**, including 14 resource cases and 3 boundary groups |
| Fresh actual Swift start → complete → finish exports | **1,711/1,711** strict schema and default-measurement/completion comparisons pass |
| Shared validation fixture | **38/38** records satisfy their independently checked Swift/web expectations |
| Session exploratory boundary probe | 422 inputs; all 168 native-accepted canonical outputs pass strict web validation |
| Resource generation, icon pixels/hashes | Reproduce unchanged |
| Repository lint, types, formatting, docs and web build | Pass; existing large-chunk warning remains |
| Swift app/UI-test syntax, strict source formatting, JSON/plist/YAML parsing | Pass; **not a SwiftUI SDK typecheck** |

The exploratory probe retains three intentional stronger native whitespace-name
rejections. It is session evidence, not support for arbitrary web imports. The
38-case fixture is repository test input; larger synthetic records remain scratch
data. Fresh root logs are `/tmp/forma-full-audit-{swift,js}-tests.log`; actual native
probe output is `/tmp/forma-full-audit-contracts.json`.

An optimized Foundation/Linux harness measured unchanged-history parse/sort at
191–341 ms for 1,500 sessions. The equality guard measured 0.020–0.066 ms over
the same five samples and detected changed names/sets. AppModel now rebuilds its
history cache only when history changes. This establishes avoidable source work;
it is **not** an iPhone frame-time or energy measurement.

The [source register](apple-design-2026.md) now contains **62** official Apple
text/API/session sources plus the same three inspected reference images. The new
metadata keys were checked against the current direct required-reason API lists;
no unneeded manifest reason was added. Final archive inspection remains required.

Eight UI journeys are authored, including invalid-draft correction, notes
save/discard and already-open journal removal after reset. They remain **unrun**.
Xcode/SwiftUI compilation, simulator rendering, VoiceOver/keyboard/device fault
and performance tests, signed archive and App Store approval remain open. The
previous scorecard is unchanged. No push, publication or store action occurred.
