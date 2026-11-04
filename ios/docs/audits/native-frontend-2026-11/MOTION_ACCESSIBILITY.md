# Motion and accessibility verification

The motion resolver retains System/Minimal/Off, Reduce Motion precedence and UIKit Prefer Cross-Fade support. Workout completion remains dependent on durable storage; field entry does not trigger decorative container movement. The coach token scroll is now resolved through `withFormaAnimation`.

The physical test harness follows the actual paired-Watch start sheet with **Start on iPhone only**, then still requires the first set. It never invokes Watch Start or writes a synthetic Health workout. Simulator-only keyboard and Home Screen fixtures are explicitly classified separately; their physical skips are not passes.

| Check | Evidence boundary |
| --- | --- |
| Largest Dynamic Type Today start action | Physical baseline layout test and screenshot passed |
| Low-height landscape start action | Physical baseline layout test and screenshot passed on actual Air viewport |
| Four tabs and scroll collapse | Physical baseline navigation journey passed |
| Token contrast | Hosted app assertions ran on physical iPhone; composited glass still requires image/device judgement |
| Motion Off, stable set frames, confirmed receipt | Authored journeys retained; final execution recorded in VERIFICATION |
| Watch paused state | Source review identified that its combined spoken label omitted Paused; final patch addresses the semantic text |
| VoiceOver, Voice Control, Switch Control, Bold Text and Full Keyboard Access | Full hands-on assistive-technology matrix remains outstanding |
| Haptic feel | Programmatic routing/semantic assertions are distinct from a person feeling hardware feedback |

No device security, AutoFill, Auto-Lock or accessibility setting was changed. Dynamic Type in tests is a launch-only setting for the isolated audit app. Real notifications/Live Activities are disabled in the existing UI-testing harness; UI-test success cannot establish actual locked-screen behavior.
