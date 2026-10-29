# WidgetKit architecture — 29 October 2026

This describes the implemented source and its verification boundaries. WidgetKit
is implemented; ActivityKit and a Watch widget extension are deliberately
deferred. Source review is not proof of signed App Group access, locked-device
privacy, installed widget operation or Apple approval.

## Targets and ownership

`FORMAWidgets` is an iOS 17 app extension in `ios/project.yml`, embedded by the
FORMA target and built from `ios/FORMAWidgets` and the shared `ios/WidgetPresentation` views.
The app compiles those same views only in DEBUG for the renderer; Release app
code excludes them. The widget always compiles them through its target flag. Its bundle identifier is
`dev.raoufabedini.forma.widgets`, under the existing app identifier. It uses
`APPLICATION_EXTENSION_API_ONLY`, a WidgetKit extension Info.plist and its own
privacy manifest. App and extension declare
`group.dev.raoufabedini.forma`; the extension also declares complete Data
Protection. Both targets use the existing signing team3L5A4R7JNY. Matching entitlements
were verified in the signed Release bundle after Xcode refreshed the existing
managed profiles and assigned the group. This does not prove locked-device rendering.

The local package's independent `FORMASurfaces` library contains only the
snapshot contract, atomic writer, canonical Sydney calendar and route grammar. It does not depend on
SQLite, the account protocol or HealthKit. The app also imports FORMACore; the
widget imports FORMASurfaces. The main SQLite database remains in the app's
private, completely protected, backup-excluded directory. Neither extension nor
App Intent writes workouts.

```text
WorkspaceStore durable commit / account replacement / initial load / reset
    → AppModel.workspace
    → WidgetSnapshotBridge projection (current owner + explicit consent)
    → SnapshotFileWriter actor (monotonic publication sequence)
    → atomic protected App Group JSON
    → TrainingProvider decode + expiry timeline
    → family-specific read-only SwiftUI + validated app URLs
```

## Projection contract

`TrainingSnapshot` schema 1 stores an opaque random owner epoch, local workspace
revision, generation and expiry dates, display state and three small optional
summaries:

- Routine ID/name, exercise count and estimated minutes. The current suggestion
  is the first unarchived routine, consistent with the app's default selection;
  it is not a claim that this routine has a separate scheduled appointment.
- Active saved session ID/name and completed/total set counts.
- Actual completed sessions this Sydney week, current goal and Monday-first
  trained-day flags. Multiple sessions count separately; a day flag counts once.

It excludes profile name, member reference, email, cookies, passwords, account
metadata, exercise details, notes, full history and all live Health metrics.
The owner epoch permits precise stale-link rejection without putting a member
identity in the group. It is not an authorization credential for account APIs.

`WidgetSnapshotBridge` projects only the opened workspace. Normal training
mutations update that property after the durable store transaction; remote
replacements reload from the store. An archived routine is excluded. Actual
history dates determine weekly counts; future records do not inflate progress.
Expiry uses the next Sydney calendar midnight, including23/25-hour DST days;
saved active workout snapshots expire sooner, after at most30minutes.
The app publishes at that boundary while foregrounded and when it returns to
the foreground; no per-second polling is introduced.

## Publication and failure behavior

The main-actor bridge allocates a monotonically increasing publication sequence
before launching a cancellable Task. The bounded projection runs on a
concurrent executor, then returns to the bridge; the latest-sequence check and
writer actor reject outdated work. This avoids parsing10,000dates on the UI actor. `SnapshotFileWriter` is the single writer actor;
publication numbers older than its latest accepted number cannot overwrite a
newer owner's projection, even when their workout revision is numerically
larger. A reset or owner change does not compare unrelated workspace revisions.
Writes use atomic replacement with complete file protection on iOS, and the
group directory is marked excluded from backup. The extension only reads.

Decode rejects unsupported schema, payloads over 32 KiB, invalid time bounds,
invalid names/IDs/counts and private summaries in non-ready states. Ready
snapshots expire into a stale state that removes their summaries and precise
links, with one exception added on 29 October 2026: the next routine and the
weekly count are carried for up to 72 hours past expiry (the count resets only
when a new training week starts), because neither changes at midnight. A saved
active workout is never carried. The provider bounds size before reading and catches missing, malformed
or protected-file failures into a nonpersonal unavailable state. This does not
promise access to a protected file while the device is locked. A protected-data
read failure is treated as a lock, not a fault: the extension shows an
"Updating after unlock" entry and retries after 2, 5, 15 or 30 minutes depending
on how long ago the app last published (the shared file's modification time,
readable while locked). An overnight lock stays under about 30 reloads, inside
WidgetKit's budget; the app also reloads timelines when protected data becomes
available and when it becomes active, which is the main recovery path.

There is no cross-process database lock because the extension has no write
operation and never opens the canonical SQLite store. Atomic replacement and a
single app writer protect readers from partial JSON. Final device tests must
still exercise failed writes, out-of-order publication, resets and account
transitions. Source sequencing cannot retract an already rendered WidgetKit
snapshot immediately.

## Consent, ownership and privacy

Widgets start hidden. You → Training at a glance exposes the explicit sharing
toggle. The consent owner/epoch/sharing record lives in the private protected
`widget-consent.json`, outside the group. The private owner key includes the service origin and guest/member store.
Selecting another training owner
creates a new epoch with sharing off. Revocation rotates the epoch, so cached
specific-content links cannot open a stale owner's routine/session. Account
activation publishes an unavailable/hidden projection before store opening;
account exit selects guest ownership before publishing the guest workspace.

Personal layouts are marked `privacySensitive`; the privacy and fallback tiles
are not, so the lock symbol and "Training is private" stay readable under
redaction (a render test fails if they are redacted again). The extension's complete Data Protection additionally causes
WidgetKit to hide private content while locked. Apple documents that this choice
also prevents iPhone widget mirroring on Mac. This deliberately prioritizes
privacy over Mac mirroring. The app's SQLite protection was not relaxed.

The public states are intentionally distinct: gallery example, hidden consent,
empty training, unavailable/protected/corrupt read, stale projection and ready
committed facts. Gallery data is synthetic and is not used to repair a real
missing timeline. A ready empty numeric fallback is not a substitute for a
validated workspace.

Revocation persists the new choice, with durable deletion as a fallback if
replacement fails. If both fail, the prior toggle value remains visible with an
actionable error rather than pretending that revocation persisted. Consent and
publication errors have separate lifetimes. Fault tests and relaunch must verify
this behavior. WidgetKit may also retain an old unlocked-device rendered timeline
until it processes a reload. Monotonic writes
and epoch checks protect data publication and navigation; they do not establish
instant visual withdrawal. Test account exit/reset on a passcode-protected
physical device with an installed widget. Do not describe these unrun cases as
an immediate-redaction guarantee.

## Families and interaction

One configurable widget offers Next session or This week focus. It supports:

| Family | Composition |
| --- | --- |
| Small | Routine/active identity and saved facts, or weekly count, with one app-opening destination. |
| Medium | Routine/active or weekly focus beside actual weekly totals/day flags; separate links to content and Progress. |
| Large | Larger editorial identity, saved detail and weekly summary with direct app links. |
| Accessory circular | Actual completed/goal ring and accessible textual equivalent. |
| Accessory rectangular | Short routine/resume or weekly status with one contextual detail line. |
| Accessory inline | Brief FORMA status. |

Views use system typography, simple SF Symbols, content margins and
`containerBackground(for: .widget)`. `widgetRenderingMode` changes color strategy;
`widgetAccentable` identifies key elements. Full color, accented/clear and vibrant
Lock Screen appearances need actual rendering proof. No animated number passes
through invented intermediate workout counts. Existing static previews cover
the four mandatory families; the full family/state/appearance matrix still needs
capture from the running extension.

`TrainingProvider` builds an immediate entry and an expiry entry removing private
facts. It requests a reload after the later of thirty minutes or the validity
boundary, or sooner after a locked read as described above. The OS controls reload timing/budget; this is not an exact-time
promise. Relevance is limited to at most thirty minutes for a saved active
session. The extension runs no polling timer or remote account request.

Widget links use `forma://widget` with an allowlisted path and bounded,
percent-encoded query values. The parser rejects arbitrary hosts/schemes,
credentials, ports, fragments, extra fields and ambiguous duplicate keys.
Routine/active destinations require sharing, the current epoch and a still
existing current-owner identifier. Deleted, archived, revoked or wrong-owner
links fall back safely. Root routing queues a cold-launch URL until a workspace
has loaded. Links open views; there is no fake mutating intent or background
Watch start.

Routing acceptance must include existing workout/receipt/start covers and
previously pushed Plan/Progress/You details. Selecting a tab behind a cover or
retaining an unrelated pushed screen does not satisfy a precise widget
destination. The circular ring must open weekly progress independently of
Next session focus. UI regressions cover cold roots and queued workout/profile/routine drafts.
The root resets only the requested destination stack, waits for protected
editors and explicit workout Save & close, and never bypasses invalid numeric
drafts. A banner explains the queued link. Current results are in the final
evidence report; cached-view protection remains a separate physical-device gate.

## Live Activity

**Shipped (29 October 2026), pending the physical-device gates below.** A workout
has a defined start and end, so it is shown as one app-driven, local Live
Activity on the Lock Screen, in the Dynamic Island, in StandBy, and on iOS 18 and
later in the compact `.small` layout used by the Apple Watch Smart Stack and
CarPlay. The earlier deferral set four acceptance boundaries; each is
implemented as follows.

| Piece | Where |
| --- | --- |
| `NSSupportsLiveActivities` | `ios/FORMA/Info.plist` (app only; the extension has none) |
| Pure payload model, mapping and stale date | `FORMASurfaces/WorkoutActivityState.swift` (Foundation only, also built for macOS) |
| Session to state mapping | `FORMA/App/WorkoutLiveActivityMapping.swift` (current exercise is `WorkoutEngine.resumeIndex`, the one the workout screen opens on) |
| Lifecycle controller and ActivityKit wrapper | `FORMA/App/WorkoutLiveActivityController.swift` (`WorkoutActivityHost` protocol, faked in tests, like `RestNotificationCenter`) |
| Single hook | `AppModel.workspace` `didSet` calls `syncLiveActivity()`; `sceneBecameActive()` repeats it with `force` |
| Attributes, intents, views | `WidgetPresentation/WorkoutActivity*.swift` (attributes and intents are in both targets; views only in the extension and Debug app) |
| `ActivityConfiguration` and bundle | `FORMAWidgets/WorkoutLiveActivity.swift`, `FORMAWidgets/FORMAWidgetBundle.swift` |

**Lifecycle.**

1. *Start.* Only for an active workout in the saved workspace, with the app in
   the foreground and `ActivityAuthorizationInfo().areActivitiesEnabled`.
   Immutable attributes are the session ID and the widget bridge's opaque owner
   epoch; no account identifier is ever an attribute or state field. A refused
   request leaves training untouched and is retried on the next trigger.
2. *Update.* Only when the mapped `WorkoutActivityState` differs from the one on
   screen, so logging a set, starting, pausing, extending or skipping a rest
   send one update each and nothing is sent per second. Elapsed time and the
   rest countdown are system timers over saved dates. A repeat commit while a
   rest runs maps to an equal state on purpose (the ring length is the
   programmed rest, not "remaining at the time of the commit"). Payload: the
   current exercise only, names clipped to 40 characters and 96 bytes, under
   1 KB encoded (tested; ActivityKit allows 4 KB).
3. *Stale.* A running rest goes stale one second after it ends, and the views
   then say "Rest over" instead of a timer parked at zero when the app is
   suspended and cannot send the update. Anything else goes stale after three
   idle hours and shows "Open FORMA to update". Any update refreshes it.
4. *End.* `dismissalPolicy: .immediate` on finish, discard, reset, sign-out,
   account switch (owner epoch change) and a changed session ID, all of which
   reach the controller as an inactive or different workspace through the one
   `didSet`. There is deliberately no final "Workout saved" card: the receipt
   belongs to the app, and an ended workout should not stay readable on a
   locked screen. Dismissing the display never finishes or discards training.
5. *Relaunch.* Every pass compares against `Activity.activities`: the one that
   matches the saved session and owner epoch is adopted (and updated only if its
   state differs); every other one is ended, including ones left by a crash or
   another owner. The first pass after launch runs even with no workout, to end
   orphans. Two activities never coexist. An activity the person swipes away is
   not restarted for that workout until the next launch.
6. *Preference.* "Show workout on Lock Screen" (You tab, identifier
   `live-activity-toggle`, on by default) is stored with the other presentation
   preferences in `presentation.json`: local to this iPhone, never synced and not
   tied to the widget-sharing consent. Off means no target, so a running activity
   ends at once and none starts; on starts one for an active workout while the
   app is in front. The person can also turn Live Activities off for FORMA in
   Settings.
7. *Opening.* A workspace that has not opened yet is not "no workout": on a cold
   launch the scene becomes active while `load()` runs, and the controller is
   not synced until the workspace arrives, so the running activity is neither
   ended nor restarted. A workspace that closes (sign-out, account switch) or
   fails to open (`loadFailure`) ends it.
8. *Denied or unavailable.* No request is made; the in-app workout and the
   rest notification are unaffected.

**Presentations.** Lock Screen/banner: "FORMA workout" title, routine and
exercise names (`.privacySensitive()`), "Set 3 of 4 · 7 of 18 done", elapsed
time, rest ring and countdown or paused time, and the "Complete set" and (while
resting) "Skip rest" buttons. Dynamic Island: compact leading is the FORMA
symbol (the rest ring while resting; it fits a 28 pt circle and carries the
meaning alone, as the limited-width guidance requires), compact trailing is the
rest countdown or elapsed time, minimal is the ring or symbol, and expanded
splits name, set, timer and buttons. No `isDynamicIslandLimitedInWidth` is used
(iOS 27 only). Fixed colours: ink on lime in light, lime on ink in dark
(`BrandPalette`), always the dark palette inside the Island.

**Buttons.** `CompleteSetIntent` and `SkipRestIntent` are `LiveActivityIntent`s
(iOS 17) with `authenticationPolicy = .requiresAuthentication`: the workout is in
Complete-protected storage and unreadable while locked, so a press asks to
unlock. The system runs them in the app's process. They call
`LiveActivityActions.handler`, installed in `FORMAApp.init` before any scene
exists, which awaits the model's `load()` if needed (a press can launch the app
with no window), checks the session ID still matches the active workout, and
otherwise does nothing. "Complete set" ticks the next unfinished set of the
current exercise through `AppModel.toggleSet`; "Skip rest" uses the same
`WorkoutEngine.skipRest` commit as the rest dock. Both then bring the pending
rest-end notification in line (`RestReminder`), so a rest started from the Lock
Screen still cues the end on a locked phone. The extension never writes
storage.

**Availability.** Deployment target iOS 17.0. `supplementalActivityFamilies` and
`activityFamily` are iOS 18, and a `Widget.body` cannot branch between two
configurations at run time, so the extension has two bundles that differ only in
the Live Activity widget type and a `main` that picks one with `#available`.
CI builds with the iOS 26.2 SDK; nothing newer is used, and
`scripts/check-ios-widget-bundle.py` asserts the plist key, the bundle, the six
Training families and one kind, `pushType: nil` and the absence of
`isDynamicIslandLimitedInWidth`.

**Remaining physical-device gates** (not provable in the simulator or by source):

- No leftover activity after discard, finish, sign-out, force-quit and relaunch,
  or reboot; exactly one after relaunch mid-workout.
- A locked phone shows nothing private: routine and exercise names are redacted
  where the system hides sensitive content; counts and timers are not private.
- Landscape and the iPhone 17 family: compact leading and minimal fit, expanded
  is not truncated, and the Lock Screen card is not cut at 160 pt at the larger
  text sizes.
- The circular `ProgressView(timerInterval:)` ring renders as a ring in the
  compact leading and minimal Island, not a spinner.
- StandBy and Always-On tint, plus Smart Stack and CarPlay `.small` rendering;
  the Watch shows no duplicate FORMA surface next to the mirrored workout.
- Buttons: unlock prompt, a set ticked from a cold background launch, and a
  press after the workout ended doing nothing.
- The bundle `main` dispatch loads the right bundle on an iOS 17 and an iOS 18
  device.

## Watch complications and Smart Stack

**Evaluated and deferred.** A Watch widget needs its own target and Watch-local
projection. An iPhone App Group file does not travel to the Watch. A future
explicit data flow may provide a generic saved-session state, with stale expiry,
privacy protection and a precise Watch entry point; it must not expose heart
rate or depend on an always-reachable phone. Existing Watch recording remains
independent and has explicit reconnect support. The failed-session screen now offers an explicit, confirmed discard of the
failed workout result; already recorded Health samples may remain. Session- and
builder-bound callback guards reject late messages from discarded recordings.
Current physical Watch connectivity and this recovery lifecycle remain
release-validation gates. Do not jeopardize
Health recording to add a complication.

## Verification references

Source tests cover snapshot round trip/expiry, malformed contracts/routes,
monotonic owner publication, Sydney week/future dates, DST midnight, projection
minimization and stale owner/deleted IDs. These assertions are meaningful but do
not establish WidgetKit cached-view behavior, entitlement provisioning or
device protection. Actual integration results are recorded in the audit's test
and change-summary reports, separately from this source architecture.

Current Apple rationale and availability are linked in
[the source register](APPLE_2026_SOURCE_REGISTER.md). Privacy, rights, signing,
hardware and distribution gates are in
[test and App Review evidence](TEST_AND_APP_REVIEW_EVIDENCE.md).

## Final composition verification

The shared real view renderer exports 120 family/theme/state images, including all six families' saved, active, completed-week focus, long-name, privacy-redacted and four fallback states, plus all Home families at accessibility3/accessibility5. A compact accessibility composition prevents title/status decoration from hiding the Open action. Normal-size system gallery/Home behavior was exercised separately. Provider timeline scheduling and nondefault configuration changes are source-reviewed; exact system refresh budgets and locked/StandBy/tint/clear/vibrant contexts remain hardware/system gates.
