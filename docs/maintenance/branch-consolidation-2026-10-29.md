# Branch consolidation — 29 October 2026

The owner authorized safe merge and deletion of the accumulated branches. The confirmed default branch is `main`; starting remote main is `2dc5ae05d82c393f271b9a060eb190b035588e37`. Integration starts from native publication `d7236536f8626b0e6b56c768ca7a88994194171a`, which already contains main and the older native work. No production service or App Store action is part of this consolidation.

## Preservation and merge design

- Captured all 17 local and 21 remote branch tips and six worktree states. Verified 38 private recovery refs under `refs/archive/branch-consolidation-20261028T201539Z`; source objects remain reachable after branch-name deletion. The recovery inventory lives in the repository's private Git metadata, not in public source.
- Preserved the local-only `work` commit and `feat/native-accounts` history through the current native branch. All 38 starting tips are ancestors of the integration candidate.
- Merged the dependency deployment record and historical Watch audit with normal merge commits. Conflicting AGENT/CHANGELOG additions were inserted verbatim into the existing logs; no log side was discarded. Added explicit historical-baseline banners to the old Watch audit rather than relabeling its old observations as current facts.
- Integrated Dependabot production/development commits with a narrow Miniflare override repair. Updated versions: Better Auth 1.7.12, lucide-react 1.61.0, Motion 14.6.0, Vite 8.3.5 and Wrangler 4.152.0. ESLint remains 9.39.5; normal peer checks stay enabled.
- Miniflare 5.20261019.2-beta otherwise installs Undici 7.29.1. Retargeted the existing exact-version override to that Miniflare and retained Undici 7.30.1. Maintainer advisories identify 7.30.1 as patched for [excessive content encodings](https://github.com/nodejs/undici/security/advisories/GHSA-xjj6-f33q-929c), [EventSource memory](https://github.com/nodejs/undici/security/advisories/GHSA-4qv8-2p9j-2685) and [integrity tokens](https://github.com/nodejs/undici/security/advisories/GHSA-f72v-6w45-q472). Sources checked 29 October 2026. No advisory is ignored or suppressed.

## Executed verification

| Check | Actual result |
|---|---|
| Branch ancestry | All 38 captured tips retained by the combined merge history |
| Existing worktrees | Five clean; native checkout has only untracked macOS metadata. No reset, clean, stash or worktree removal |
| Package install / dependency graph | Normal `npm ci` passed; exact new versions and overridden Undici 7.30.1 observed |
| Dependency security | OSV 2.7.0 scanned 498 lockfile packages and returned no vulnerable result groups; npm audit also reported zero |
| Web/Worker regressions | 151 unit and 35 Worker tests passed |
| Previously failed production-update journey | WebKit workout validation/completion/persistence test passed 20 consecutive runs, one worker, zero retries; assertions unchanged |
| Static / builds | ESLint, Prettier, TypeScript, documentation links, server and web builds passed |
| Native resource and contract checks | Generator `--check` passed; all 1,711 actual Swift-generated cases accepted by the canonical strict web validator |
| Historical audit integrity | JSON/CSV both contain 1,471 unique baseline rows; coverage proof has no missing/extra paths. Historical values were not recertified against the newer source |
| Native source provenance | The integration's native source tree is unchanged from the locally tested `d723653` publication at this preparation checkpoint. Existing signed build/UI evidence retains its stated physical-device limits |

The old Dependabot #32 CI failure was one WebKit validation assertion; #33 security failed on the newly introduced Undici 7.29.1. The local repeat and patched lockfile address those concrete observations. They do not turn old failed runs into passes. Combined GitHub CI and Native iOS CI are separate gates before the final integration merge.

## Safe deletion procedure

1. Merge the validated integration into main using a merge commit so every starting tip remains an ancestor.
2. Recheck actual remote tips and ancestry. Delete only refs whose current commit is retained by remote main; compare-and-swap leases reject concurrent branch movement.
3. For a branch held by an older clean worktree, detach that worktree at its existing HEAD first. Keep every worktree directory, ignored cache and untracked file. Do not discard local changes.
4. Delete local refs with `git branch -d`, never forced deletion. Keep main. Re-fetch and verify remaining local/remote branches, main parity and recovery refs.
5. Record actual merge/deletion outcomes below and in project logs; preserve the published native audit as dated evidence.

## Starting branch inventory

Each captured ref below is retained by the integration history. Duplicate local/remote names are intentional; notably the local `work` tip was ahead of its remote.

| Ref | Starting commit | Initially in remote main |
|---|---|---|
| `refs/heads/deps/2026-10-22` | `bcf3ba34e2785a4e889cc957016c6500aa5310bd` | Yes |
| `refs/heads/docs/release-deps-20261022` | `43065274dffd2a4f4d8dc9e89da24c60efd313f4` | No |
| `refs/heads/docs/release-holds-timer-20261022` | `378194e3f36ec3f23604e4b7779a2f3448a1ce25` | Yes |
| `refs/heads/feat/exercise-animations` | `ceea460de53bfe1c05498d13d20d724f05e12182` | Yes |
| `refs/heads/feat/exercise-overflow-menu` | `6fc258ba1c0a4731028638fdc801b43ab7cbd3d8` | Yes |
| `refs/heads/feat/frontend-widgets-2026-10` | `d7236536f8626b0e6b56c768ca7a88994194171a` | No |
| `refs/heads/feat/hold-metric-migration` | `2aa9b3163648ce3ddbe915cf09fce65c54519de8` | Yes |
| `refs/heads/feat/hold-metric-migration-2` | `470d8a814734ab491d75281f1e1527cf4198f408` | Yes |
| `refs/heads/feat/ios-commit2-premium-experience` | `f2e071e4d44f2d8232c993fa89f5ce6e93902ee4` | No |
| `refs/heads/feat/native-accounts` | `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba` | No |
| `refs/heads/feat/no-load-hold-timer` | `5c8c8cdc154430f473ba044df14caab805a97542` | Yes |
| `refs/heads/feat/routine-hold-convert` | `674bdfed3145d445ceec31b4b9c9098cf4bc2e0e` | Yes |
| `refs/heads/feat/routine-preview-demos` | `60450cb69bc2ee7a40d80956620eba571363f9ca` | Yes |
| `refs/heads/feat/workout-editing-sides` | `6ac57d60260e4a55288df08ac578fda69c14e98c` | Yes |
| `refs/heads/fix/routine-drag-flakes` | `316c5d92883b952532600de2f0a41f519c4b64e1` | Yes |
| `refs/heads/main` | `2dc5ae05d82c393f271b9a060eb190b035588e37` | Yes |
| `refs/heads/work` | `7373cf6c53c8e35066a26bd7d57ee325c32e059e` | No |
| `refs/remotes/origin/audit/apple-watch-readiness-2026-10-26` | `6aeafdaf9631d752509effbe24b81da3456fd38e` | No |
| `refs/remotes/origin/audit/runtime-quality-2026-10-23` | `4234d5e2eb99bdff9589adc32f21f1da0f9cd7b0` | Yes |
| `refs/remotes/origin/dependabot/npm_and_yarn/development-af66fbb228` | `3ccc4a76b064ceaab0e2e94fbd3d7c06495131d9` | No |
| `refs/remotes/origin/dependabot/npm_and_yarn/production-29d6e513ae` | `6577dbdc787a2686f66c7b9d834b5cf37007b283` | No |
| `refs/remotes/origin/deps/2026-10-22` | `bcf3ba34e2785a4e889cc957016c6500aa5310bd` | Yes |
| `refs/remotes/origin/docs/release-deps-20261022` | `43065274dffd2a4f4d8dc9e89da24c60efd313f4` | No |
| `refs/remotes/origin/docs/release-holds-timer-20261022` | `378194e3f36ec3f23604e4b7779a2f3448a1ce25` | Yes |
| `refs/remotes/origin/feat/exercise-animations` | `ceea460de53bfe1c05498d13d20d724f05e12182` | Yes |
| `refs/remotes/origin/feat/exercise-overflow-menu` | `6fc258ba1c0a4731028638fdc801b43ab7cbd3d8` | Yes |
| `refs/remotes/origin/feat/frontend-widgets-2026-10` | `d7236536f8626b0e6b56c768ca7a88994194171a` | No |
| `refs/remotes/origin/feat/hold-metric-migration` | `2aa9b3163648ce3ddbe915cf09fce65c54519de8` | Yes |
| `refs/remotes/origin/feat/hold-metric-migration-2` | `470d8a814734ab491d75281f1e1527cf4198f408` | Yes |
| `refs/remotes/origin/feat/ios-commit2-premium-experience` | `f2e071e4d44f2d8232c993fa89f5ce6e93902ee4` | No |
| `refs/remotes/origin/feat/no-load-hold-timer` | `5c8c8cdc154430f473ba044df14caab805a97542` | Yes |
| `refs/remotes/origin/feat/routine-hold-convert` | `674bdfed3145d445ceec31b4b9c9098cf4bc2e0e` | Yes |
| `refs/remotes/origin/feat/routine-preview-demos` | `60450cb69bc2ee7a40d80956620eba571363f9ca` | Yes |
| `refs/remotes/origin/feat/workout-editing-sides` | `6ac57d60260e4a55288df08ac578fda69c14e98c` | Yes |
| `refs/remotes/origin/fix/routine-drag-flakes` | `316c5d92883b952532600de2f0a41f519c4b64e1` | Yes |
| `refs/remotes/origin/main` | `2dc5ae05d82c393f271b9a060eb190b035588e37` | Yes |
| `refs/remotes/origin/release/runtime-audit-2026-10-26` | `268d854021c3cb4de11d48e8ea3399f0e28a6133` | Yes |
| `refs/remotes/origin/work` | `f83498ef7ec20527a9c05f1270969ac7593bed9d` | No |

## Execution status

Integration prepared and locally verified. Final combined CI, main merge, branch deletion and postflight verification are pending at this preparation commit. Their actual outcomes will be recorded after execution; no completed cleanup is implied here.

## Older-SDK compatibility repair found by CI

Native CI run `40764394234` selected Xcode 26.3 / iOS Simulator SDK 26.2 and failed to compile `FormaMotion.swift:103`: the SDK does not contain SwiftUI's `accessibilityPrefersCrossFadeTransitions` environment key. The previous runtime `#available(iOS 26.4, *)` cannot make a missing SDK symbol compile. The prior Xcode 27.1 audit did not establish older-SDK compilation.

The root motion modifier now reads [UIKit's preference](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitions) and observes its [status-change notification](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitionsstatusdidchange), plus foreground refresh. Installed SDK declarations confirm both exist from iOS 14, below the app's iOS 17 floor. The initial value is read before the first frame; notification delivery is scheduled on the main run loop. Preference priority remains Off → none, Minimal → fade, System → minimal when either accessibility signal asks for it. There is still one authoritative resolver.

A regression covers Cross-Fade, Reduce Motion, normal System, explicit Off and explicit Minimal. Local Xcode 27.1 verification passed all **33 hosted app tests + four motion/navigation UI tests** (`/tmp/forma-consolidate-motion-sdk.log`, result `Test-FORMA-2026.10.29_07-45-00-+1100.xcresult`). Strict Swift lint passed. The older-SDK CI rerun remains the actual portability gate; local compilation is not substituted for it. The published frontend ledger remains a historical source checkpoint; this repair is a later reviewed delta.

The first cleanup phase removed 11 local and 13 remote branches already contained in starting main, with expected-tip checks. Four old worktrees were detached at their unchanged HEADs; all directories and local files were preserved. Remaining incoming branches wait for the final validated main merge.

## Compact-phone integration repair

The older-SDK rerun compiled and passed all 33 hosted app tests, then exposed six UI failures on iPhone SE (3rd generation), iOS 26.2. Five focused app journeys reproduced locally on the 375 × 667 compact simulator. This was a separate integration gate from the previous full-size iOS 27 review.

At the largest accessibility size, Start extended under navigation (CI: bottom 610.5 versus navigation top 594; local: 655 versus 589). Accessibility composition now keeps the routine title and primary action before metadata, retaining every detail and the selected font size. The unchanged geometry assertion passed after this repair.

History and profile checks assumed offscreen lazy rows existed. They now reveal the same saved records before asserting the exact name, single journal entry, process-survival state and deletion behavior. Short, direction-aware drags avoid flinging past an entire section. Account journeys reveal fields and consent rows above the keyboard and explicitly assert each consent's checked/unchecked state. The CI recording showed that a consent tap had left Terms unchecked; the disabled Submit behavior was correct, and no validation was relaxed.

The widget gallery selects the named provider cell rather than its non-hittable text child. On compact Home-button phones, Home leaves editing when the system exposes no Done button. The test still requires a real installed widget and a route to routine details without starting a workout. No UI journey, assertion or device class is skipped.

Local final-source verification: **5/5 account/history UI tests passed** (`/tmp/forma-compact-consents-history.log`, result `forma-compact-consents-history.xcresult`). The preceding compact run passed the actual system widget install/link journey, queued profile save and largest-text geometry. Its added consent assertion initially compared checked `1` with `On`; it now accepts only the exact equivalent checked/unchecked representations, and the full signup journey passes. Strict Swift formatting, documentation links, signed Release build and protected widget-bundle verification pass. No assertion, consent requirement or journey was disabled. The CI iOS 26.2 rerun remains required before merge.

The complete combined web/security run [40766687510](https://github.com/Raoof128/forma-workout-planner/actions/runs/40766687510) passed at source `5756291`: 151 unit, 76 PostgreSQL identity/ownership, 35 Worker and eight operations tests; 507 development browser cases, 175 production cases and 220 account browser executions across development/production builds. No flaky/retry summary occurred. History secret scanning and dependency checks passed. The compact follow-up changes native Swift/UI tests and documentation only; the final candidate will receive its own CI runs.
