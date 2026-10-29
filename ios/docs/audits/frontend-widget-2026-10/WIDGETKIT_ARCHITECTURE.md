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
links. The provider bounds size before reading and catches missing, malformed
or protected-file failures into a nonpersonal unavailable state. This does not
promise access to a protected file while the device is locked.

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

All widget content is marked `privacySensitive`; custom privacy redaction uses
a generic view. The extension's complete Data Protection additionally causes
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
boundary. The OS controls reload timing/budget; this is not an exact-time
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

## Live Activity decision and scoped follow-up

**Not shipped in this pass.** A workout has a defined beginning and end, so it
is a reasonable ActivityKit use case. The installed SDK supports the basic
content-based ActivityKit API below the app's iOS 17 floor. API availability is
not the blocker. Lifecycle/ownership/privacy proof is incomplete, and a partial
activity could outlive reset/account exit or imply an ongoing workout after
termination. The owner's brief explicitly permits an evidenced deferral.

The follow-up is a small app-owned coordinator, using the existing widget
extension for `ActivityConfiguration`, with these acceptance boundaries:

1. Start only after a committed active workout and explicit foreground user
   action, conditional on Live Activity availability. Bind immutable attributes
   to session ID and opaque owner epoch; reconcile `Activity.activities` on
   relaunch before starting another activity.
2. Use a neutral public title, saved elapsed/rest dates and saved phase/counts.
   Exclude routine notes, account identity and Health metrics. Derive system
   timer text from saved timestamps, with a finite stale date; do not send
   high-frequency updates or introduce push infrastructure.
3. Update after acknowledged relevant workspace commits. End immediately on
   committed finish/discard/reset and owner exit. Include final content and
   immediate dismissal for privacy withdrawal. A dismissed display must not
   finish/discard training.
4. Reconcile crashes, force termination/relaunch, reboot, denied activities,
   duplicates, stale deadlines, owner switches and locked storage. Provide
   Lock Screen/Dynamic Island and supported smaller presentations with guarded
   availability. Prove public-content privacy on a physical device.

Integration points are workspace publication, account transitions, reset,
finish/discard and the existing validated active-workout route. None require
extension writes to canonical storage. No ActivityKit source, capability,
`NSSupportsLiveActivities` claim or simulated success is included now.

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
