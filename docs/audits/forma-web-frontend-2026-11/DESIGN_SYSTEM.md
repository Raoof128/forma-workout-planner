# FORMA web design system

FORMA remains an athletic training workspace with editorial typography. Useful training state, readable measurements and the next action lead each screen. Both required skills were fully read; their generic orange marketing/gamification direction was rejected because the existing brand and observed training workflows gave a stronger basis for decisions. Exact skill paths, hashes, commands and source attribution are in [skill evidence](SKILL_EVIDENCE.md) and the [source register](SOURCE_REGISTER.json).

| Role                   | Retained treatment                                                                 |
| ---------------------- | ---------------------------------------------------------------------------------- |
| Ink / canvas / surface | `#202522` / `#f5f6f3` / white                                                      |
| Lime / supporting lime | `#dff780` / `#f0f8d8`                                                              |
| Muted / account muted  | `#59635d` / `#68716a`                                                              |
| Border / core radius   | `#dfe4dc` / 14 px                                                                  |
| Display / reading      | Locally hosted Barlow Condensed 700 / DM Sans variable                             |
| Numbers / icons        | Tabular workout/timer numerals / existing Lucide                                   |
| Composition            | Desktop sidebar, mobile drawer, original monochrome photography and forward-F mark |

The existing 4/8 px spacing rhythm and native dialog/form semantics remain. Photography and atlases retain their original source files, approved mappings, crop geometry and separate guide/media attribution. Both bundled OFL 1.1 notices were read; Fontconfig decoded the font metadata. No new font, palette, theme, illustration set or decorative glass layer was needed.

## Responsive controls

| Boundary | Resulting behavior                                                                                                                                          |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 960 px   | Account subsections use horizontal navigation. Authentication uses its existing stacked brand/form pattern so both intrinsic columns cannot clip the panel. |
| 700 px   | Existing global mobile shell/drawer; phone account text fields use 16 px text and at least 44 px height.                                                    |
| 540 px   | Existing unilateral/single-measure row layouts and compact controls.                                                                                        |
| 380 px   | The column coach-access form does not wrap into a second column; token name, access choices and Create action remain inside the panel.                      |
| 360 px   | Weighted numeric tracks reserve room for long measurements, with 3 px gaps, 32 px bounded RPE and 44 px Done; numeric text remains 16 px.                   |

The narrow-row correction follows actual clipped-value screenshots and loaded-font measurements. A gap-only candidate was insufficient at 320 px. The final three-rule track allocation passed six actual-source cases across Chromium, Firefox and WebKit at 320/360 px, including bilateral, unilateral, duration/distance and single-duration rows. RPE remains above the 24 CSS px AA target minimum; 44 px is the stronger ergonomic goal used for Done and control height, not a claim that every narrow input is 44 px wide.

## State, focus and motion

Pending writes show pending state; success follows acknowledgement. Profile drafts preserve edits made after a save began. Routine/history editor snapshots freeze while saving and unlock on rejection. Order placement remains responsive while its success treatment waits for persistence. Failures preserve the draft or saved order rather than displaying an unearned success.

Known dialog openers explicitly receive focus before opening so WebKit can restore the actual invoking control. Only the open mobile drawer steps Tab through its visible enabled controls; nested profile-menu Tab closes to its trigger first. Desktop native Tab, local menu Escape/arrow handling and meaningful existing user focus remain. The calibrated macOS WebKit launch preference is volatile and isolated to tests, not an application or OS setting change.

The established drag springs, lift/settle curves, 400 ms card touch hold and quick-swipe scrolling remain. Live Reduce Motion pauses demonstrations without restarting them when the preference is removed; explicit Play remains available. See [motion](MOTION_REVIEW.md), [responsive evidence](RESPONSIVE_AUDIT.md) and [accessibility](ACCESSIBILITY_AUDIT.md). Matched final guest/account and actual numeric screen critique is recorded separately in [screen review](SCREEN_REVIEW.md).

The final local account matrices passed **development 200/200** and **production-build 200/200** across all five profiles, with zero failures, skips or retries. Each matrix includes seven account-design cases per profile: 35 design executions within its 200 passes. The 193 audited source-input hashes remain unchanged. The five profiles cover desktop Chromium, emulated phone Chromium, Firefox, desktop WebKit and emulated phone WebKit.

[Aggregate CI run 41840783732](https://github.com/Raoof128/forma-workout-planner/actions/runs/41840783732) completed **SUCCESS** for `c247e9e`: both jobs and every browser stage succeeded, including the remote account stages. The completed Verify logs confirm **540 guest-development passes**, **175 production-smoke passes**, **200 account-development passes** and **200 account-production passes**, with no failed, skipped or interrupted final summaries. These CI executions are recorded separately from the completed local account matrices. See [test results](TEST_RESULTS.md).

The completed CI used Node 24.22.1, npm 11.19.1, Ubuntu 24.04.5 and PostgreSQL 18.4. The supporting version register retains the recorded local tool versions and capture environment; CI results are a separate execution context. Server checks (77), Worker checks (35), unit checks (151) and operations checks (8 Python plus 8 Node) also passed; consolidated receipts are in [test results](TEST_RESULTS.md).
