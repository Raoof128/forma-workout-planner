# Screen review and interaction graph

29 October 2026, Australia/Sydney. The audit starts at `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba` and preserves the separately approved dirty native account/sync and animated tab-bar work. The captured baseline contains **146 native paths**, including source, configuration, documents, generated resources and images; it is not a claim that all 146 paths are hand-authored source. Current optional accounts remain part of the app. The [file ledger](FILE_LEDGER.md) distinguishes every input's method and version.

Nine new full-resolution baseline PNGs were exported from the actual iOS 27 `FORMA Review` Simulator and visually inspected at original detail. They are separate from the 18 historical Commit 2 two-up JPG composites. Final light/dark tours, all six shared widget families and the actual system gallery/Home routine link passed. Original after images are indexed below; physical system contexts remain separately gated.

## Complete interaction graph

```text
Launch / protected local preparation
  -> loading OR explicit unreadable/protected-store failure
  -> guest workspace OR restored member cache/account loading gate
  -> Today / Plan / Progress / You, with independent native navigation stacks

Today
  -> actual next unarchived routine -> Start request scoped to current owner
  -> saved active workout -> Resume
  -> routine detail / latest saved workout / real weekly cadence

Plan
  -> routine detail -> exercise-specific technique guide
                   -> Edit routine -> name/description/targets/rest/RPE/cues/sides/supersets
                                   -> reorder/remove -> Save OR explicit discard
                                   -> Add exercise -> library/search/filter/guide -> add
                   -> Start
  -> Create routine -> same editor and valid prescription rules
  -> Exercise library -> native always-visible scoped search + muscle/equipment filters
                      -> technique/source guide
  -> Training days -> committed Monday-first weekday choices

Start
  -> Watch capability/pairing/installation check
  -> no Watch -> committed iPhone workout
  -> Watch sheet -> open Watch / wait for user Start / Check again / iPhone-only / Cancel
  -> saved active session -> full-screen logger

Workout
  -> select/next exercise after valid draft handling
  -> kg/reps/left-right/time/distance inputs -> durable complete / undo / add set
  -> guide / notes editor -> acknowledged save, retaining newer edits
  -> timed hold -> pause/resume/end/cancel -> single claimed save
                -> exact failed effort retained -> Retry save OR explicit Cancel
  -> persisted rest -> pause/resume/+15 seconds/skip -> deadline-derived display
  -> Save & close -> retain active session -> prior tab / queued widget destination
  -> discard confirmation -> remove active session and discard Watch recording
  -> Finish confirmation -> valid drafts + durable history commit -> receipt -> Done

Progress
  -> actual workouts/sets -> latest-eight eligible lifting-volume chart -> textual values
  -> newest-first history -> current-ID workout detail
  -> removed/reset history -> explicit removed/empty state

You
  -> local profile/weekly goal/rest/training days
  -> appearance / motion / haptics / privacy and source attribution
  -> export -> system file exporter -> success/error/cancellation outcome
  -> confirmed local reset -> committed empty workspace + new empty widget projection
  -> Training at a glance -> explicit current-owner sharing choice / failure feedback
  -> optional Account
      -> Sign in / Create account + separate consents / email verification + resend
      -> two-step code OR recovery code / password-reset email route
      -> profile/name/goal/change-email / password change
      -> two-step enrollment/recovery codes / sessions and step-up revocation
      -> read/full coach-token create/display-once/revoke
      -> cloud status/conflict -> reload account OR keep this phone
      -> Bring phone training -> counts + saved account copy + explicit replacement
                             -> durable ownership reservation before upload
      -> privacy/account -> sign out [keep OR guarded local removal]
                         -> account-deletion initiation + emailed confirmation
      -> owner switch -> clear prior private destinations and widget epoch/consent

Watch
  -> ready -> user Start -> HealthKit primary session -> mirrored metrics
  -> running / paused -> resume / End -> saving -> saved OR explicit failure
  -> disconnect/recover -> current primary recording continues -> single-flight Reconnect
  -> failed recording -> confirmation -> discard failed result
                        (already recorded Health samples may remain)

Widget entry points
  -> Home small/medium/large OR circular/rectangular/inline accessory
  -> Next session OR This week configuration
  -> strict forma://widget route -> cold-launch queue -> loaded current-owner lookup
  -> Today / Plan / Progress / settings / exact routine / exact active session
  -> protected editor/workout still open -> visible queued-link notice
       -> explicit Save/Cancel or Save & close -> requested destination
  -> deleted/archived ID, revoked sharing or old epoch -> safe unavailable/root destination
```

## State and interruption boundaries

Training success, counters, receipt and widget progress derive from acknowledged local commits. Failed validation/storage preserves numeric drafts; a finished timed effort additionally retains its exact elapsed result for explicit retry. Rapid End/deadline submissions cannot become two efforts. Valid lifecycle drafts are best-effort saved; an invalid field is not silently made durable or bypassed by a widget link.

Foreground/day changes refresh the Sydney day/week. Widgets use the same ISO calendar and half-open, nonfuture completion interval; active projections have a finite shorter expiry. Reset/owner changes publish empty/hidden/current-owner facts rather than retaining an old active ID. Local revision overlap across accounts does not authorize publication: monotonic sequence and opaque owner epochs govern the bridge and specific links.

The root now tracks actual workout-cover visibility as well as presentation intent. A route queued during Save & close waits until dismissal completes, protecting the draft and avoiding a destination being selected behind a still-visible cover. Existing routine/profile editors retain their Save/Cancel flow. Permission denial, unavailable Watch, protected storage and offline sync have visible alternatives; no widget starts Watch recording or performs a training mutation.

The final UI regressions passed for workout, routine and profile draft preservation. Passcode-device execution remains open. Complete file/extension protection and privacySensitive views do not independently prove when an already-rendered WidgetKit snapshot disappears after account exit or reset.

## Implemented composition and interaction changes

**Today:** the original artwork is retained as a decorative 112-point crop above solid ink session content. The routine/action no longer depends on white text over an uncontrolled photograph. Large accessibility text omits decorative art and marketing copy; compact landscape uses a horizontal session/action layout and folds the marketing heading. A single Start/Resume remains the primary action, with immediate pending wording while the Watch/save path runs. Source: `TodayView.swift` 24–28, 59–76, 181–263 at this checkpoint. The earlier largest-text geometry failure is retained in test history; both final compact landscape and largest-text geometry cases passed.

**Workout:** opaque, stable set cards and real saved values remain the defining surface. Changes concentrate on trust: one effort, one claim, exact failed-hold duration, visible Retry/Cancel and no dismissal/Finish that silently loses the pending effort. Rest remains deadline-based and its controls retain visible labels. No decorative success precedes persistence. The queued-widget banner now sits inside the logger scroll content. Its earlier safe-area overlay covered Save & close; the final UI test proves explicit closure works and preserves the corrected 42.5 kg draft without completing the set. Root cover visibility controls the eventual handoff.

**Library:** scoped native search now uses an always-visible navigation-bar drawer (`PlanView.swift` 801–804). This preserves the existing query/filter semantics and makes the search field discoverable without an undocumented pull-down gesture. Query typing does not animate moving result rows. The source change addresses the failed library-tour search assertion; final light and dark search/guide tours passed and were captured.

**Widgets:** the six families use the same actual shared SwiftUI view source as the extension. Each family has a deliberate composition: small identity/action, medium content plus weekly cadence, large summary, circular completed/goal gauge, rectangular brief resume/routine context and inline status. Hidden/empty/unavailable/stale/private states have nonpersonal actions. The shared renderer is useful family/state evidence; it does not replace actual SpringBoard gallery, Home/Lock Screen, tint/clear/vibrant or physical redaction tests.

The selected **Training Instrument**, and considered **Training Journal** / **Focused Cockpit** alternatives, are documented consistently in [the design system](DESIGN_SYSTEM_V3.md). No unsupported qualitative percentage or visual-quality score is assigned.

## Qualitative scorecard

Each cell is an evidence-limited judgment: **clear/coherent/guarded** describes the source composition or a named baseline observation; **pending** identifies unproven behavior. “Unmeasured” means no matched interaction-latency result exists. This is not a numerical grading system, WCAG certification or claim that every state ran successfully.

| Surface | Clarity | Efficiency | Visual character | Feedback | Accessibility | Latency |
|---|---|---|---|---|---|---|
| Launch/loading/store failure | Explicit states, source | Preparation off main | Existing canvas continuity | Real loading/error | Physical focus pending | Device launch unmeasured |
| Root tabs/navigation | Four stable destinations | Existing chosen collapse | Preserved FORMA glass bar | Selected state | Labels/traits; physical input pending | Transition unmeasured |
| Today standard | Session/action first, source | Shorter art region | Ink/lime editorial hierarchy | Start pending then saved state | Baseline shown; final geometry passed | Start response unmeasured |
| Today AX/landscape | Decorative copy folded | Action-priority layout | Calm adaptive composition | Same truthful state | Largest-text and landscape geometry passed | Unmeasured |
| Routine list/detail | Clear prescription grouping | Start/edit/guide explicit | Coherent opaque surfaces | Saved mutation semantics | Baseline detail inspected | Unmeasured |
| Create/edit prescriptions | Units/ranges/cues explicit | In-sheet add/reorder | Existing native form | Validation and guarded discard | Labels; large long-form run pending | Edit/save unmeasured |
| Library/search/filter | Visible scoped search | No pull-down discovery | Native list/filter hierarchy | Real result state | Light/dark search/guide tours passed | Keystroke unmeasured |
| Exercise guide/sources | Specific movement/credits | Local reading route | Restrained instructional surface | Unavailable guide explicit | Long text/links device pending | Decode/read unmeasured |
| Training-day editor | Monday-first choices | Immediate durable choice | Existing tokens | Commit-backed selection | Non-color semantics, source | Unmeasured |
| Watch start sheet | Device choice explicit | iPhone-only fallback | Native sheet | Waiting/failure truthful | Permission/hardware pending | Device negotiation unmeasured |
| Active set entry | Stable units/current exercise | Large direct completion | Opaque training instrument | Durable completion/error | Labels/targets; physical typing pending | Tap-to-save unmeasured |
| Hold timer/retry | Running/failed effort distinct | Single claim; exact retry | Restrained time instrument | Pending/Retry/Cancel | State tests and hold tours passed | Timer/save cost unmeasured |
| Rest dock | Remaining/pause explicit | Pause/add/skip direct | Control-layer glass | Deadline-derived visible state | Compact keyboard/device pending | Energy/hitches unmeasured |
| Notes and draft handling | Unsaved/saved ownership | Retains newer edits | Native editor | Acknowledged save/error | Queued-link draft preservation passed | Unmeasured |
| Finish/discard/receipt | Destruction separated | One confirmed path | Single restrained seal | History-commit success | Baseline receipt inspected | Handoff unmeasured |
| Progress chart/values | Real units/range | Text-value alternative | Quiet opaque chart | Saved history only | Baseline shown; spoken chart pending | Large-history unmeasured |
| History detail/removal | Current-ID truth | Direct recent lookup | Existing journal hierarchy | Removed/empty state | Reset UI passed | Unmeasured |
| You/preferences/profile | Explicit local controls | Stable native forms | Calm account/setting hierarchy | Save/export errors visible | Baseline You shown; physical settings pending | Unmeasured |
| Export/reset/privacy/credits | Copies/deletion described | System export/confirmation | Restrained legal/data surfaces | No false deletion success | Reset visibility passed | File IO unmeasured |
| Account sign-in/register/verify/MFA | Real optional account path | Website-parity steps | Existing native forms | Rejection/verification explicit | Synthetic coverage; live/physical pending | Live account unmeasured |
| Account profile/security/sessions/tokens | Credential scope explicit | Native step-up/revoke flow | Coherent existing forms | Secrets shown only as intended | Hardware/autofill/live email pending | Live service unmeasured |
| Sync/conflict/phone import/sign-out | Ownership and options explicit | Durable local-first queue | Calm status surfaces | Seven ownership regressions pass | Destructive/import flows device pending | Live sync unmeasured |
| Home small/medium/large widgets | Saved identity/week focus | Precise app links | Ink/lime typographic restraint | Honest stale/empty/private states | Shared renders plus actual Home/gallery; Lock Screen pending | Projection clock sampled |
| Circular/rectangular/inline accessories | One glance/state | One relevant destination | Monochrome-safe symbols/type | Real counts, no live-write claim | Lock Screen/Always On pending | System update budget unmeasured |
| Widget privacy/owner/stale fallback | Public state differentiated | Settings/open-app recovery | Generic nonpersonal fallback | Consent IO failures visible | Passcode-device redaction pending | Reload timing system-managed |
| Watch running/paused/reconnect/failure | Phase-specific source | Explicit reconnect/discard | Wrist-sized numbers/controls | Neutral phone end state | Physical Watch/AOD unverified | Energy/reconnect unmeasured |

## Baseline screenshot index

These are actual before-state PNGs from the recorded baseline tour, with source manifest alongside them. They are not the revised Today or finished widget screenshots.

| State | Full-resolution artifact | What it establishes |
|---|---|---|
| Today | [light-01-today.png](screenshots/before/light-01-today.png) | Original large hero/action/cadence arrangement on the recorded tall Simulator |
| Plan | [light-02-plan.png](screenshots/before/light-02-plan.png) | Original editorial header, library and routine list |
| Routine detail | [light-03-routine-detail.png](screenshots/before/light-03-routine-detail.png) | Real starter prescription labels and Start |
| Active workout | [light-04-workout.png](screenshots/before/light-04-workout.png) | Original opaque logging rows and explicit units |
| Saved set/rest | [light-05-set-completed-rest.png](screenshots/before/light-05-set-completed-rest.png) | Actual completed-set emphasis and persisted rest display |
| Receipt | [light-06-receipt.png](screenshots/before/light-06-receipt.png) | Real synthetic saved totals and restrained seal |
| Progress | [light-07-progress.png](screenshots/before/light-07-progress.png) | Actual synthetic history-derived chart and units |
| You | [light-08-you.png](screenshots/before/light-08-you.png) | Account-enabled baseline, proving accounts predate this pass |
| Today after finish | [light-09-today-after-workout.png](screenshots/before/light-09-today-after-workout.png) | Actual one-session weekly count |

## Final UI and visual evidence

The final light run executed **24 tests, zero failures**, including all three screenshot tours. The separate system widget gallery/install/link test passed; it was excluded only from the repeat 24-case run to avoid adding another Home widget after its successful dedicated run. It remains enabled in normal CI. The dark tour passed its three journeys. No assertion on durable values, owner identity or draft preservation was removed.

Earlier `/tmp/forma-widget-all-final.log` remains **24 executed/five failed**. Discovery helpers (lazy controls and portrait restoration), visible library search and the actual queued-banner overlay were repaired. Severe Watch Simulator CPU pressure was observed and extra Simulators shut down; this is context, not an excuse for app defects. The final run had settled host load and passed.

| Surface | Light final | Dark final | Visual review |
|---|---|---|---|
| 01-today | [Original](screenshots/after/light-01-today.png) | [Original](screenshots/after/dark-01-today.png) | Captured from the running app; review at original resolution |
| 02-plan | [Original](screenshots/after/light-02-plan.png) | [Original](screenshots/after/dark-02-plan.png) | Captured from the running app; review at original resolution |
| 03-routine-detail | [Original](screenshots/after/light-03-routine-detail.png) | [Original](screenshots/after/dark-03-routine-detail.png) | Captured from the running app; review at original resolution |
| 04-workout | [Original](screenshots/after/light-04-workout.png) | [Original](screenshots/after/dark-04-workout.png) | Captured from the running app; review at original resolution |
| 05-set-completed-rest | [Original](screenshots/after/light-05-set-completed-rest.png) | [Original](screenshots/after/dark-05-set-completed-rest.png) | Captured from the running app; review at original resolution |
| 06-receipt | [Original](screenshots/after/light-06-receipt.png) | [Original](screenshots/after/dark-06-receipt.png) | Captured from the running app; review at original resolution |
| 07-progress | [Original](screenshots/after/light-07-progress.png) | [Original](screenshots/after/dark-07-progress.png) | Captured from the running app; review at original resolution |
| 08-you | [Original](screenshots/after/light-08-you.png) | [Original](screenshots/after/dark-08-you.png) | Captured from the running app; review at original resolution |
| 09-today-after-workout | [Original](screenshots/after/light-09-today-after-workout.png) | [Original](screenshots/after/dark-09-today-after-workout.png) | Captured from the running app; review at original resolution |
| 10-library | [Original](screenshots/after/light-10-library.png) | [Original](screenshots/after/dark-10-library.png) | Captured from the running app; review at original resolution |
| 11-library-search | [Original](screenshots/after/light-11-library-search.png) | [Original](screenshots/after/dark-11-library-search.png) | Captured from the running app; review at original resolution |
| 12-technique-guide | [Original](screenshots/after/light-12-technique-guide.png) | [Original](screenshots/after/dark-12-technique-guide.png) | Captured from the running app; review at original resolution |
| 13-hold-ready | [Original](screenshots/after/light-13-hold-ready.png) | [Original](screenshots/after/dark-13-hold-ready.png) | Captured from the running app; review at original resolution |
| 14-hold-running | [Original](screenshots/after/light-14-hold-running.png) | [Original](screenshots/after/dark-14-hold-running.png) | Captured from the running app; review at original resolution |
| 15-hold-paused | [Original](screenshots/after/light-15-hold-paused.png) | [Original](screenshots/after/dark-15-hold-paused.png) | Captured from the running app; review at original resolution |

[Today largest accessibility text](screenshots/after/16-today-largest-accessibility-text.png) and [short landscape](screenshots/after/17-today-compact-landscape.png) prove Start's full 44pt-class target is hittable above navigation on the actual 402×874-point review device. This is not a 320-point device or spoken accessibility test.

Actual host evidence: [small gallery](widgets/system/widget-system-small-gallery.png), [medium gallery](widgets/system/widget-system-medium-gallery.png), [installed Home widget](widgets/system/widget-system-home-installed.png). The successful tap opened the exact current routine and did not start/complete a workout. Direct component renders are identified by `widgets/components/` in [visual-evidence.json](visual-evidence.json); they do not establish system tint/clear/vibrant behavior or passcode privacy.

**Coverage limits:** baseline has nine matching light primary-screen captures. Baseline Library/Search/Guide and hold-state captures were not recorded before implementation, so these final images are not fabricated before/after pairs. Failed-hold Retry/Cancel is exercised by four hosted state regressions; a running failure screenshot is not captured. Real Lock Screen/StandBy/Always On and physical VoiceOver remain unverified. No tinted/clear/vibrant system screenshot is mislabeled from a simple light/dark renderer.
