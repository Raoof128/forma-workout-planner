# Required skill evidence

Reviewed 4 November 2026, Australia/Sydney. This supporting record documents the two explicitly required design skills, the decisions they informed and their verification limits. Runtime and performance results belong to the audit's test, screen and performance reports.

## UI UX Pro Max

Loaded the full skill at `/tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/SKILL.md`. SHA256: `1bdfb422c97d5e813768af422750882b71ff1554978da0b8a43c95de242765f7`. The quick reference and applicable pro-rules were also read. Official source: [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill). Checkout commit: `dd9a1b4cf9f67ca2e326f646d93e101b2778db30`. Its CLI package manifest reports `2.5.0`; that is not asserted as a separate SKILL version.

The skill was missing from the initially searched project/global locations. The official source was reviewed and checked out under `/tmp/forma-native-design-20261104/ui-ux-pro-max-source`; the website phase reused that checkout. The Python search workflow was inspected before execution. No `npx` installer, third-party package script, global installation or repository skill injection was used.

Commands executed during website discovery:

```sh
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'fitness training precision editorial' --design-system -p 'FORMA Web' -f markdown
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'fitness workout app' --design-system -p 'FORMA Web' -f markdown
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'focus not obscured' --domain ux -n 3
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'dragging movements' --domain ux -n 2
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'controlled input asynchronous state' --stack react -n 4
python3 /tmp/forma-native-design-20261104/ui-ux-pro-max-source/.claude/skills/ui-ux-pro-max/scripts/search.py 'time series training progress' --domain chart -n 2
```

Both system-level queries proposed a Feature-Rich Showcase / Vibrant & Block-based marketing treatment, orange/green and gamification. That generic direction was rejected because it conflicts with FORMA's established training workspace and brand. It was not persisted as a verified design system. The narrower searches contributed bounded guidance for focus visibility, non-drag pointer alternatives, controlled asynchronous drafts and readable chart units; they did not justify new dependencies, debouncing, a chart library or a broad visual rewrite. The search output/decisions were recorded in the discovery tool receipts and `/tmp/forma-web-design-discovery-20261104.md`; no standalone original stdout artifact is claimed.

## Frontend Design

Loaded the full local skill at `/Users/raoof.r12/.agents/skills/frontend-design/SKILL.md`. SHA256: `b81e2ff87ed8fa4d6c377ccb127a7254c9e6a77e3ae94f21e6b514f7bb2945a0`. Its applicable principles were deliberate art direction, clear hierarchy, typography, precise spacing and purposeful motion. The local file carries no verified upstream commit/version. The [official directory](https://github.com/anthropics/skills/tree/main/skills/frontend-design) request returned a restricted-URL error; the readable local skill remained available. No remote-version verification is invented.

## Applied decisions and public provenance

- Retained FORMA lime `#dff780`, ink `#202522`, neutral canvas `#f5f6f3`, original monochrome photography and forward-F mark. Existing recognizable art direction did not require replacing its palette, layouts or assets to demonstrate skill use.
- Retained locally hosted DM Sans variable for body/form text and Barlow Condensed 700 for display. Both bundled OFL 1.1 copyright/licence files were fully read. WOFF2 headers and Fontconfig family/style/version metadata decoded successfully. This verifies local metadata/provenance, not every glyph or fresh legal approval. Licence paths: `public/fonts/dmsans-OFL.txt` and `public/fonts/barlowcondensed-OFL.txt`.
- Preserved original source sheets, reviewed atlas assignments, guide fingerprints, licence/credit separation, local previews, clip ordering and still alternatives. Hero/routine source/export/runtime hashes match the provenance records in `docs/research/site-visuals/`. Archived held sheets and historical third-party photo candidates were not newly approved. Image generation prompts and historic review notes remain provenance, not current visual proof.
- Preserved the tuned drag lift/settle springs, 400 ms touch hold, quick-swipe scrolling, exact entry identities and keyboard/single-pointer move alternatives. No ornamental animation library or row scaling was added. The initial measured defect was the phone completion grid column, so its track changed from 34 to 44 px while drag behavior stayed intact. A subsequent actual-font check exposed internal numeric clipping at 320 px; the exact tested weighted tracks now reserve room for measurements, retain 16 px text/44 px Done, and allocate 32 px to bounded RPE. Six actual-source numeric cases passed across three engines; temporary candidate images remain separate from final captures.
- Corrected confirmed rendered account contrast, phone input sizing and tablet account content width with existing tokens/layouts. Account-muted `#68716a` calculates 5.050:1 on white; informative summary detail increased from 9 to 11 px. Phone text inputs use 16 px text/minimum 44 px height. The existing horizontal account subnav now starts at 960 px.
- Prepared a late authenticated heading for Skip to content without taking focus from a control the member already used. Live Reduce Motion now pauses the SVG through its still asset and does not automatically resume it. Explicit Play remains supported. Async retry/profile/editor corrections follow actual read/write acknowledgement and local draft ownership.

A later controlled focus triage reproduced six unchanged WebKit failures against the frozen original source. Bare-control calibration separated native Tab preferences from mouse focus: a volatile, macOS-only NSArgumentDomain launch option normalizes keyboard tests, while explicitly focusing each known dialog opener repairs return focus. The shared helper preserves the exact pinned nonpersistent WebKit flags and documents rechecking them on upgrades. Native anchors still skip under the link preference, exposing the original mobile drawer endpoint trap: its final Terms link was never reached before focus escaped to body. The existing open-drawer handler now explicitly steps through visible enabled tabbable controls and wraps; nested profile-menu Tab closes to its trigger first. Desktop native Tab and local menu Escape/arrow handling remain. A focused member regression protects this interaction. No global OS preference, global pointer handler or page-wide Tab override was added. The primary Apple/WebKit/Playwright references and verification owners are recorded in SOURCE_REGISTER.

All 627 static raster files subsequently decoded and drew completely through ImageIO with zero failures. All 22 video streams decoded to null in a sequential single-thread FFmpeg check, totaling 6,924 frames with zero errors. These integrity checks do not create fresh visual, technique or rights approval.

Late actual rendering also exposed a wrapped coach-access column below 380 px and hidden tablet auth-grid clipping. The smallest corrections keep the existing form stacked and extend its existing auth pattern through 960 px. Both were proved against frozen original controls and temporary browser-only candidates before product changes; each passed five focused profiles. The final 88-state account sweep checks visible auth panels and controls as well as document width.

The current source patch and supporting tests were reviewed after implementation; scoped formatting/lint checks passed. Baseline rendered evidence justified changes before source edits. Matched actual guest/account/numeric after-screen critique is recorded in SCREEN_REVIEW. Final official full-suite, account, production and performance outcomes remain root-owned; skill use is not a test-pass assertion.

## Versions and source attribution

Manifest pins and directly rechecked installed versions: React/React DOM 19.3.1, Vite 8.3.5, Motion 14.6.0, Playwright 1.64.1, axe-core 4.14.0 and Lucide React 1.61.0. Host Node 24.21.0/npm 11.19.0. Full manifest pins and per-entry verification limits are in [SOURCE_REGISTER.json](SOURCE_REGISTER.json).

That register combines primary references fetched by this reviewer, the account reviewer's source receipt and root's performance/reference handoff. It records who checked each source on 4 November 2026. Retrieval dates are not publication dates. W3C Understanding pages explain criteria; 24 CSS px is the AA target criterion or an allowed exception, while 44 px is FORMA's stronger ergonomic choice. Native 44 pt guidance is not presented as a web WCAG requirement. Synthetic profiling/latency does not establish field INP, physical-device performance or a p75 improvement.
