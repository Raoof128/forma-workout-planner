# Motion and accessibility matrix

| Surface | Full motion | Reduced/Minimal/Off | Semantic/focus behavior | Verification |
|---|---|---|---|---|
| Today/Plan/Progress/You | One-time reveal, no replay required on ordinary tab switch | Fade or instant via single resolver | Headers, system navigation, wrapping labels, secondary status text | Screenshot tour and layout tests; physical assistive-input gate remains |
| Bottom tabs | One discrete symbol bounce, selection capsule, bounded scroll collapse | Expanded if spatial motion disabled; opaque if reduced transparency/high contrast | Selected trait, tab position, explicit Expand label; VoiceOver prevents collapse | Navigation hosted tests + UI journey; actual spoken rotor order needs device |
| Set log | Saved state180ms + semantic haptic | Fade/instant, same visible completed value |56pt set button; numeric text editable; failed save leaves draft | Durable termination, numeric and retry regressions |
| Hold | Bounded deadline/countdown; one effort claims one save | No spatial interpolation outside full motion; paused outside active scene | Explicit End/Pause/Cancel; failed save retains exact seconds +Retry save | Four state regressions and ready/running/paused screenshots |
| Rest |1Hz bounded display and linear ring | Static/reduced transitions; task cancellation on interruption | Pause/Add/Skip, visual rest-ended message accompanies haptic | Offline rest/reopen journey; physical background/notification delivery unclaimed |
| Receipt/chart | Single commit-backed emphasis; real values always final | Fade/instant; no fake interpolated volume | Chart bars have labels/values and textual summary | Receipt/Progress tour; physical chart VoiceOver exploration remains |
| Widgets | System timeline transition only; no perpetual animation | WidgetKit/system policy; content remains readable | Semantic counts, actionable Link/widgetURL; privacySensitive and Complete protection | Pure snapshot/routes/ownership tests + build; system family/context evidence recorded separately |
| Watch | Short phase fades, still Always On | No dimmed animation or reconnect control | Large explicit controls; neutral phone end state; owner-confirmed discard on failure | Source/compile checks; paired Watch/AOD/permission-denied gates |

## Matrix limits

Installed runtime is iOS27/watchOS27. iOS17, iOS26 and watchOS10 API floors are compile/availability reviewed; those runtime journeys are NOT RUN unless a specific result is linked in final evidence. Simulator accessibility text is useful layout proof; it does not establish physical VoiceOver, Switch Control, Voice Control, Braille, Always On, Dynamic Island or real sweaty-hand reachability. No percentage accessibility score is claimed.

Pending exact screenshot/result paths are consolidated in SCREEN_REVIEW and CHANGE_SUMMARY_AND_NEXT_GATES. Repeated utterances, focus after live updates, keyboard travel and localized long names require human/device review beyond static source inspection.
