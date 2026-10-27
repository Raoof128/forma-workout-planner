# FORMA motion specification (Commit 2)

FORMA moves to confirm, orient and reward real progress. It stays still when
the user is concentrating. Every animated change has a complete static
equivalent.

Implementation: [`FormaMotion.swift`](../../FORMA/DesignSystem/FormaMotion.swift)
(levels, tokens, helpers) and [`FormaComponents.swift`](../../FORMA/DesignSystem/FormaComponents.swift)
(loading mark, completion seal). Apple sources and API availability:
[APPLE_RESEARCH.md](APPLE_RESEARCH.md); settled platform decisions:
[apple-design-2026.md](../apple-design-2026.md).

## Levels

One level is resolved at the root and read from the environment
(`\.formaMotion`). Views never read the preference or Reduce Motion directly.

| System Reduce Motion | You › Motion | Level | Behaviour |
| --- | --- | --- | --- |
| Off | System | `full` | Springs, spatial transitions, one-time emphasis |
| On | System | `minimal` | Movement and scale become a 160 ms cross-fade |
| Any | Minimal | `minimal` | Same as above |
| Any | Off | `off` | No FORMA animation; final states appear at once |

System Reduce Motion always wins. On iOS 26.4 and later, Accessibility ›
Motion › Prefer Cross-Fade Transitions counts the same as Reduce Motion.
"Off" removes FORMA's own motion; native system transitions (navigation push,
sheets, tab changes) remain the system's.

## Tokens

Durations are FORMA design choices for gym use, not Apple requirements. All
are springs without overshoot on data, except one-time emphasis.

| Token | Duration | Bounce | Use |
| --- | --- | --- | --- |
| `press` | 120 ms | 0 | Press acknowledgement on buttons and cards |
| `state` | 180 ms | 0.12 | A set completing, a toggle, a status label |
| `reveal` | 300 ms | 0.08 | Content appearing or disappearing; card expansion |
| `navigation` | 380 ms | 0.1 | Larger choreography between states of one screen |
| `emphasis` | 520 ms | 0.22 | One-time reward: a finished workout, a newly completed day |
| `fade` | 160 ms | ease-out | The minimal-level substitute for any spatial motion |
| `stagger` | 50 ms | – | Delay between siblings in a one-time reveal |

## Rules

1. **Truth before motion.** A saved check, completed-set state or success
   haptic happens only after the durable local commit. Animations are keyed to
   committed model state (`set.done`, a new history entry), never to a tap.
2. **Repeated actions stay quick and in place.** Set completion is the most
   repeated action: a 180 ms fill and symbol change in the button's own frame.
   Adjacent fields never move.
3. **Never block input.** No artificial delays, no gating a control on an
   animation finishing. Elapsed and remaining time come from persisted
   timestamps, never from rendered frames.
4. **Once, not every time.** Screen entrances play once per view lifetime;
   switching tabs does not replay them. Emphasis plays once per real event.
5. **No fabricated values.** Charts may fade marks in; they never animate
   through invented intermediate data. Numbers change with
   `contentTransition(.numericText)` from one real value to the next.
6. **Typing is sacred.** Text fields and their containers are not animated
   while focused; validation messages appear with `state` without moving the
   field being edited.
7. **Haptics are opt-out and single-shot.** `sensoryFeedback` with a trigger
   that changes once per real event, gated by You › Set confirmation haptics.
   SwiftUI re-evaluation cannot fire it twice.
8. **Glass stays on controls.** Motion never introduces glass into the
   content layer (see apple-design-2026.md).
9. **Always On is still.** On watchOS, reduced luminance shows static states
   with no decorative motion.

## Screen choreography

| Moment | Full | Minimal | Off |
| --- | --- | --- | --- |
| Opening (genuine loading only) | Three FORMA facets assemble once (staggered fade and lift), then hold | Mark fades in | Static mark |
| Today entrance | Header, hero, week and lists reveal once, staggered | Present at once | Present at once |
| Active workout appears on Today | Hero cross-fades between "next session" and "in progress" | Fade | Instant |
| A day completes in the week strip | Circle fills, check scales in (`emphasis`); VoiceOver label already states it | Fade | Instant |
| Set completes (after commit) | Button fill and checkmark replace (`state`); set counter ticks numerically | Fade | Instant |
| Rest countdown | Ring shrinks per second toward the persisted deadline; running/paused/over states cross-fade | Ring updates per second without easing | Same |
| Workout receipt | Seal assembles (`emphasis`), statistics reveal staggered, success haptic once | Fade | Static |
| Progress chart first data | Bars fade in once | Present | Present |
| Chart selection | Highlight follows selection (`state`) | Instant | Instant |
