# FORMA native design decisions

4 November 2026, Australia/Sydney. Retain the existing precision/performance direction: lime actions, ink editorial hero, warm adaptive canvas, native scalable type and calm training controls. The source already contains the October redesign; rebuilding a parallel design system would discard reviewed work.

## Skills actually loaded

Frontend Design: `/Users/raoof.r12/.agents/skills/frontend-design/SKILL.md`, read fully. UI UX Pro Max: official source revision `dd9a1b4cf9f67ca2e326f646d93e101b2778db30`, CLI manifest 2.5.0; full skill, relevant rules and supported searches read/run. See [skill evidence](SKILL_EVIDENCE.md). The generated marketing palette/fonts were rejected as a poor native product fit. SwiftUI UI Patterns and SwiftUI Performance Audit were also read.

Frontend Design informed deliberate hierarchy and the retained single Today hero. UI UX Pro Max informed native touch targets, Dynamic Type reflow, contextual validation and accessibility. Apple API correctness, data integrity and accessibility take precedence over web-specific font, CSS and motion suggestions.

## Existing tokens retained

`FormaTheme`, `FormaPalette`, shared `BrandPalette`, `FormaSpacing`, `FormaRadius`, `FormaFont`, `FormaMotion` and `FormaHaptics` remain the owners. Semantic primary/secondary/accent/error/boundary colours retain light/dark and increased-contrast variants. Primary actions retain ink text on lime, a meaningful edge on light surfaces and minimum 56-point height; compact actions retain 44-point minimum height. Data surfaces remain opaque. Native glass is availability-gated and has Reduce Transparency/Increase Contrast alternatives.

The existing four-tab glass bar remains the owner-selected navigation. Its collapse yields to accessibility text sizes, VoiceOver and motion preferences. No alternate navigation system, runtime dependency, remote font or decorative loop was added.

## Changes in this pass

Coach-token scrolling now uses the motion resolver. Conflict resolution only emits success feedback after successful resolution. Watch discard wording accurately separates saved workouts from already-recorded Health samples. Widget-sharing changes reconcile the independent Live Activity to its current opaque owner epoch. Profile-save handling preserves the same data integrity standard as workout drafts. These refinements improve trust and interaction consistency without an arbitrary visual rewrite.

Declared colour contrast tests and source inspection do not certify rendered glass contrast. Fresh physical screenshot evidence and its limits are recorded in [screen review](SCREEN_REVIEW.md).
