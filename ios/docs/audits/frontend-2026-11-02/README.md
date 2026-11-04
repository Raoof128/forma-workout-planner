# iOS and watchOS front-end audit, 2 November 2026

Eight parallel read-only reviews of the native front end against Apple's current
Human Interface Guidelines and SwiftUI documentation, each using the
`frontend-design` and `ui-ux-pro-max` review guidance. Static review only: nothing
was run on a simulator, and items marked "device" in the reports still need the
iPhone Air or the Watch. Every high finding below was re-checked against the code.

| Slice                             | Report                                               | High   | Medium | Low    |
| --------------------------------- | ---------------------------------------------------- | ------ | ------ | ------ |
| App shell, tab bar, design system | [shell-design-system.md](shell-design-system.md)     | 2      | 5      | 11     |
| Today and the workout start sheet | [today-start.md](today-start.md)                     | 2      | 6      | 10     |
| Plan: routines, library, editor   | [plan.md](plan.md)                                   | 1      | 9      | 14     |
| Active workout and receipt        | [workout.md](workout.md)                             | 2      | 5      | 12     |
| Progress, You, exercise media     | [progress-you-media.md](progress-you-media.md)       | 2      | 9      | 13     |
| Account screens                   | [account.md](account.md)                             | 1      | 7      | 13     |
| Widgets and Live Activity         | [widgets-live-activity.md](widgets-live-activity.md) | 2      | 4      | 11     |
| Apple Watch interface and motion  | [watch-ui.md](watch-ui.md)                           | 2      | 6      | 9      |
| **Total**                         |                                                      | **14** | **51** | **93** |

## High findings

| #   | Where                | Finding                                                                                                           | Needs                                       |
| --- | -------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 1   | Watch summary        | Rows and seal stay invisible if the summary first appears on a dimmed wrist (`Reveal` never runs)                 | Code fix                                    |
| 2   | Watch start          | The 3-2-1 countdown runs before the session and the Health prompt, so it hides nothing and the wait happens twice | Code fix                                    |
| 3   | Plan editor          | A new, untouched routine counts as changed (`?? true`): Cancel always asks to discard, swipe-down does nothing    | Code fix                                    |
| 4   | Workout receipt      | Full-screen, swipe-down disabled, no toolbar dismiss; the only exit is at the bottom of the scroll                | Code fix                                    |
| 5   | Tab bar              | The floating bar has no keyboard handling and covers search results and fields                                    | Code fix                                    |
| 6   | Progress chart       | Unfocused bars 1.8:1 in light mode (needs 3:1)                                                                    | Code fix                                    |
| 7   | Progress chart       | Bars are plotted by workout ID and there is no chart descriptor, so Audio Graph likely reads IDs                  | Code fix, device check                      |
| 8   | Start sheet          | VoiceOver focus is lost after "Open FORMA on Apple Watch"; status changes are not announced                       | Code fix                                    |
| 9   | Watch strip (iPhone) | VoiceOver says "Recording" while the Watch is paused                                                              | Code fix                                    |
| 10  | Live Activity        | No deep link: tapping it lands on Today, not the workout                                                          | Code fix (new route)                        |
| 11  | Tab bar              | Brand colours on glass may drop to 2.6–2.8:1 over the dark Today panel                                            | Device check, then fix                      |
| 12  | Workout toolbar      | Finish has a lime label on standard glass; Apple tints a primary action's background, not its label               | Owner choice                                |
| 13  | Account              | No `webcredentials` Associated Domains, so Password AutoFill can't use the website's saved passwords              | Owner approval: capability and website file |
| 14  | Live Activity        | May be hidden on a locked iPhone because it shares a fully protected extension (unconfirmed)                      | Device check                                |

## Owner decisions

- **Finish in the workout toolbar:** (A) plain text "Finish", or (B) a checkmark
  icon with lime as the background tint, so all three bar buttons are identical circles.
- **Password AutoFill:** add the Associated Domains capability and serve
  `/.well-known/apple-app-site-association` from the Worker (a website deploy).
- **Coach-token step-up** (account medium): needs a server change, as Active
  sessions already has.
- **Live Activity extension split:** only if the locked-iPhone test shows it hidden.

The medium and low findings, each with file and line, Apple source and a SwiftUI
fix, are in the slice reports.
