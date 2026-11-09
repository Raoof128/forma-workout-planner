# Motion and accessibility verification

The motion resolver retains System/Minimal/Off, Reduce Motion precedence and UIKit Prefer Cross-Fade support. Workout completion remains dependent on durable storage; field entry does not trigger decorative container movement. The coach token scroll is now resolved through `withFormaAnimation`.

The physical test harness follows the actual paired-Watch start sheet with **Start on iPhone only**, then still requires the first set. It never invokes Watch Start or writes a synthetic Health workout. Simulator-only keyboard and Home Screen fixtures are explicitly classified separately; their physical skips are not passes.

| Check                                                                        | Evidence boundary                                                                                                 |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Largest Dynamic Type Today start action                                      | Physical baseline and final layout tests/screenshots passed                                                       |
| Low-height landscape start action                                            | Physical baseline and final layout tests/screenshots passed on actual Air viewport                                |
| Four tabs and scroll collapse                                                | Physical baseline and final navigation journeys passed                                                            |
| Token contrast                                                               | Hosted app assertions ran on physical iPhone; composited glass still requires image/device judgement              |
| Motion Off, stable set frames, confirmed receipt                             | All three actual physical motion journeys passed in the final suite                                               |
| Watch paused state                                                           | Patched semantic text and hosted regression passed on the phone; actual Watch/VoiceOver speech remains unverified |
| VoiceOver, Voice Control, Switch Control, Bold Text and Full Keyboard Access | Full hands-on assistive-technology matrix remains outstanding                                                     |
| Haptic feel                                                                  | Programmatic routing/semantic assertions are distinct from a person feeling hardware feedback                     |

No device security, AutoFill, Auto-Lock or accessibility setting was changed. Dynamic Type in tests is a launch-only setting for the isolated audit app. Real notifications/Live Activities are disabled in the existing UI-testing harness; UI-test success cannot establish actual locked-screen behavior.
