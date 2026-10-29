# FORMA Signature Experience ·29 October2026

## Three feasible directions

| Direction | Today composition | Workout composition | Widget composition | Decision |
|---|---|---|---|---|
| Training Instrument |112pt photographic strip, solid ink session information, full-width lime action, weekly cadence immediately afterward | Stable opaque exercise cards, tabular readings, one deliberate set confirmation; timed effort retains exact failed-save value | Minimal typographic session instrument paired with weekly count; no photos; compact accessory gauge | **Chosen**. Reduces competing display text and image height, keeps saved facts legible independently of art, works in accented/vibrant modes. |
| Training Journal | Small dated masthead, generous paper surface, next routine as numbered journal entry | Margin-led set rows, date and note hierarchy | Monochrome weekly diary, seven marked weekdays | Feasible, but weaker separation between an active workout and reading/history. Retain its calm journal treatment in Progress. |
| Focused Cockpit | Full-width single Start/Resume control, no photo, numeric session summary first | Dominant current exercise plus collapsed upcoming entries | Large single progress reading, secondary routine label | Feasible, but hides useful programming context and changes the existing multi-exercise logging workflow too much. Use its task priority in accessibility/short-height layouts. |

These are annotated compositional alternatives, not fabricated screenshots of finished variants. The actual implemented direction is shown in the screen evidence.

## Tokens and usage

- Keep lime`#DFF780`, ink`#202522`, canvas`#F5F6F3`/`#151A17`, adaptive primary/secondary/error/field-border variants in FormaTheme. Lime is an action accent; primary lime controls use ink text. Widgets use semantic foregrounds with accentable marks rather than depending on color alone.
- Condensed40pt scaled display text on Today,48pt existing editorial headings elsewhere; system text for forms and numbers. Accessibility and compact-height layouts prioritize the session task over decorative artwork/marketing. Labels wrap; no text baked into art.
- Corners:24pt feature/hero,18pt reading cards,16pt primary controls, capsules for navigation. Primary controls56pt minimum, secondary controls44pt where applicable. Keep opaque workout/chart/editor reading surfaces.
- Motion remains FormaMotion:120ms press,180ms saved state,300ms reveal,380ms navigation,520ms single completion emphasis,160ms reduced fade. System Reduce Motion and Prefer Cross-Fade take precedence; Off removes app decoration. No new idle animation loop or widget timer.
- App-owned tab symbols retain discrete bounce and animated selection, scroll collapse, opaque high-contrast/reduced-transparency alternatives. Accessibility sizes/VoiceOver show expanded navigation.
- Reuse existing owned editorial asset;1536×1024 RGB,2,187,502bytes, approximately6MiB decoded.112pt crop is decorative and excluded from accessibility. No new photos were needed; generation authorization was available. Existing provenance remains authoritative.
- Widget mark is a small FORMA wordmark and system training symbol. Widget content backgrounds are removable via containerBackground; tint/vibrancy retain hierarchy through weight, labels, counts and shapes.

## Contrast and truthful states

Existing four appearance/contrast token variants remain. White text sits on solid ink rather than a variable photo. Checkmarks and explanatory text distinguish training days, not green alone. Widget gauge/count and spoken labels communicate the same saved facts. A completed set/receipt success follows SQLite acknowledgement; Watch ending is explicitly separate from Health save confirmation. Layout assertions and screenshots are evidence, not physical VoiceOver or measured WCAG certification.

## Widget accessibility composition

At accessibility text sizes, Home widgets switch from decorative brand/status/day-mark composition to title, saved detail where space permits, weekly count and an explicit Open action. Small widgets use a short Open label; full routine text remains available to accessibility. This replaces the clipped large-widget composition found during expanded rendering. All six families have light/dark saved/active/completed/long-name/private and empty/hidden/unavailable/stale renders; Home families additionally render accessibility3 and the largest accessibility5 size. These component captures do not simulate actual system tint, StandBy or passcode redaction.
