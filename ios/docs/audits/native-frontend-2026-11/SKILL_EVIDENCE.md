# FORMA native design skill evidence

Date: 4 November 2026 (Australia/Sydney).

## Skill source and execution

- UI UX Pro Max was absent from the searched project, `~/.agents/skills` and `~/.codex/skills` directories.
- Official source checked out at `/tmp/forma-native-design-20261104/ui-ux-pro-max-source`.
- Revision: `dd9a1b4cf9f67ca2e326f646d93e101b2778db30`; CLI manifest version: 2.5.0.
- Loaded `.claude/skills/ui-ux-pro-max/SKILL.md` in full, `references/pro-rules.md`, quick-reference sections 1–3 and the SwiftUI stack dataset.
- Reviewed the official README installation route, Codex platform template, search entry point, imported modules, CSV reads and optional atomic persistence implementation. No third-party package installer ran. Search uses the existing Python runtime and standard-library code. No application runtime dependency or global skill installation was added.
- Verified SwiftUI from FORMA's `ios/Package.swift` and current theme implementation before choosing stack guidance.

Executed from the source checkout (absolute script path):

```sh
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/src/ui-ux-pro-max/scripts/search.py 'fitness training premium ios' --design-system -p FORMA -f markdown
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/src/ui-ux-pro-max/scripts/search.py 'fitness training app' --design-system -p FORMA -f markdown
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/src/ui-ux-pro-max/scripts/search.py 'fitness workout' --domain product --full
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/src/ui-ux-pro-max/scripts/search.py 'dynamic type accessibility' --stack swiftui --full
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/src/ui-ux-pro-max/scripts/search.py 'touch target size' --domain ux --full
```

The first system search was off-topic: a marketing storytelling pattern, fashion typography and gold palette. The narrower retry correctly identified fitness but still proposed a marketing showcase, orange palette and gamification assumptions. These raw search outputs are evidence of the queries, not an adopted design system. No generated MASTER.md was persisted and no new token system was introduced. There was no verified full native product design-system match; the direction below synthesizes applicable verified SwiftUI/touch results, the skill's platform rules and FORMA's explicit product constraints.

## Adopted direction: precision meets performance

Retain the existing lime/ink identity, semantic palette, native scalable typography, numeral tokens, spacing scale and motion resolver. Use the dark ink Today hero as a single signature element, with a clear workout action and quieter supporting content. The active workout should read as a practical training instrument: stable aligned numbers, large native controls, clear saved/draft states and visible errors next to the action that failed.

Apply these skill-backed decisions while reviewing individual screens:

1. Keep iOS touch regions at least 44 by 44 points where appropriate; investigate crowded controls rather than importing web pixel units.
2. Use scalable semantic text and layouts that reflow at accessibility sizes. Preserve existing native SF typography; do not fetch web fonts.
3. Use Button, Toggle, Form and type-safe navigation semantics; provide contextual labels and hide decorative icons from accessibility where equivalent text exists.
4. Preserve the central motion resolver and animate committed state only. Do not apply generic skill suggestions for instantaneous success, gamification, scroll storytelling, CSS, GSAP or decorative motion.
5. Measure composed contrast and verify both appearances, Increase Contrast and Reduce Transparency. Glass belongs to supported native chrome and controls; training data stays readable on stable surfaces.
6. Reuse existing tokens. Preserve account boundaries, generated resources, training units and history. Do not add new product features or fake activity for visual presentation.
7. Evaluate expensive body work and long lists only after reading the owning implementation; profile before claiming an improvement.

No application edits, visual inspection, build, benchmark, simulator run or physical-device validation was performed by this skill-discovery subtask.

## Official source

- [UI UX Pro Max source and README](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/tree/dd9a1b4cf9f67ca2e326f646d93e101b2778db30)
- [Skill instructions](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/blob/dd9a1b4cf9f67ca2e326f646d93e101b2778db30/.claude/skills/ui-ux-pro-max/SKILL.md)

## Other skill provenance

Frontend Design instructions were read fully from the installed skill; SHA-256 `b81e2ff87ed8fa4d6c377ccb127a7254c9e6a77e3ae94f21e6b514f7bb2945a0`. Adapted its hierarchy/composition principles to existing native scalable typography and FORMA tokens. SwiftUI UI Patterns and SwiftUI Performance Audit were also read; native system and repository contracts override incompatible web-specific examples.
