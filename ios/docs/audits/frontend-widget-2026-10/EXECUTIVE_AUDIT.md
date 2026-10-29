# Executive audit

29 October 2026, Australia/Sydney. FORMA now has an integrated WidgetKit extension, a protected projection of committed training facts, precise app links and a compact Today composition. The audit also repaired timed-hold retry/duplication, recovery ownership, phone-import ownership and Watch failure/reconnect/status paths. The signed Release app and embedded widget passed build/signature/bundle checks. The complete 24-case UI matrix and separate real system-gallery journey passed. Physical lock-screen privacy and Watch operation remain explicit gates.

## Baseline and authority

| Item | Recorded evidence |
|---|---|
| Native starting point | `feat/native-accounts`, HEAD `c0883a337f6ab6f5795fde7d349ae9f397b7b8ba`, with important existing dirty account and animated-navigation work |
| Audit working branch | `feat/frontend-widgets-2026-10`, same starting HEAD; existing dirty input preserved |
| Captured native inventory | 146 baseline source/doc/config/resource/image paths, backed up before new edits |
| Toolchain and host | Xcode 27.1 build 27A9275, Swift 6.4, XcodeGen 2.46.0; macOS 27.0.1 build 26A434 |
| Review Simulator | iOS 27, `FORMA Review`, `B84DC3C8-D015-4BB6-9408-E5522F6D0346` |
| Deployment floors | iOS 17 / watchOS 10; earlier runtime journeys unavailable locally |
| Fresh baseline verification | 138 core tests passed; nine full-resolution baseline tour attachments captured |
| Final device checkpoint | Final signed Release app reinstalled after final widget changes; launch attempt blocked because the phone was locked. This is not an observed interactive device run |
| Watch device checkpoint | Installation remains blocked by CoreDevice 4000 / RemotePairing 1035; reconnect the companion iPhone by USB to repair pairing |

App Group provisioning was resolved using the existing team `3L5A4R7JNY` and Xcode-managed profiles; team identity was not changed. The app and extension's matching group/protection entitlements were checked in the signed Release bundle. The owner subsequently authorized publication: implementation commit [076e267](https://github.com/Raoof128/forma-workout-planner/commit/076e267c6a4b3b5081348ddbd40cf53e22700ffd) was pushed to `origin/feat/frontend-widgets-2026-10` and the remote ref verified. No merge, deployment, App Store submission, production-service change or new credential authority is claimed.

The separately approved account implementation is part of the actual baseline. Early guest-only native documents remain dated historical evidence; their old account statements do not override current source, disclosures or account-deletion requirements.

## Findings and actual source repairs

No new confirmed P0 is claimed. Each defect below was identified from a concrete source path and failure sequence; source repair is distinct from physical-device proof.

| Finding | Prior behavior / evidence | Implemented disposition |
|---|---|---|
| C-01 / A1, P1 recovery ownership | `Sources/FORMACore/WorkspaceStore.swift` used one directory-wide recovery prefix, so a guest reset could delete another member's original. Cache removal left unreadable copies and swallowed errors | Recovery JSON is scoped to the exact database filename. Reset removes only that store's originals. The captured leaving-store actor closes SQLite before exact base/WAL/SHM/recovery/unreadable removal and surfaces failures. Three core regressions protect guest/member A/member B isolation and reject recursive directory deletion. Old unscoped evidence is preserved because its owner cannot safely be inferred |
| IF-01 / IF-02, P1 timed holds | `FORMA/Features/WorkoutView.swift` cleared a finished effort before acknowledgement; failure lost retry state. Concurrent End/deadline callbacks could complete two sets | `HoldLogState` retains exact elapsed seconds until successful persistence, synchronously claims one attempt, rejects duplicate/stale callbacks and provides explicit Retry/Cancel. Four hosted state regressions passed |
| IF-03, P1 delayed Start owner | `FORMA/App/AppModel.swift` awaited Watch refresh without binding Start to its initiating owner | Delayed Start is scoped to the initiating store generation and current routine; it cannot use a previous owner's captured routine after a switch |
| IF-04 / C-02, P2 calendar truth | Today had no deterministic midnight refresh; closed `DateInterval.contains` admitted the next week's exact Monday boundary | Shared `TrainingCalendar` fixes Sydney semantics across app/projection. Foreground/day refresh and half-open, nonfuture completion filtering prevent stale day/week counts. Projection expires at calendar midnight, or sooner for a saved active workout |
| A2, P1 phone-training ownership | `FORMA/Account/PhoneTraining.swift` silently lost its ownership marker after an import, permitting another account offer | A protected, flushed reservation is required before account replacement/upload. Only the same member can retry uncertain imports; corrupt/unwritable records fail visibly. Seven hosted regressions passed, including transport observation of reservation before PUT |
| W1, P1 failed Watch session | Watch failure retained a session/builder while displaying a Start action that refused the retained session | Explicit confirmed failed-recording discard replaces the dead Start path. Saving-in-flight blocks conflicting discard; session/builder identity guards reject late callbacks. Copy explains that already-recorded Health samples may remain. Physical lifecycle proof remains open |
| W2 / W3, P1 Watch recovery/status | Recovered workouts did not remirror; iPhone could claim saved to Health after a send/stopped callback without confirmation | Recovery remirrors and offers single-flight Reconnect. Phone state distinguishes ending/ended, propagates failed delivery and uses neutral Health-save wording. Physical sensing/reconnect/Health deduplication remains open |

Current [Swift Foundation DateInterval source](https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/DateInterval.swift) confirms the closed-end behavior underlying C-02. The fix uses the domain's half-open week rather than changing canonical workout units or validation.

## Design result and widget suite

The selected **Training Instrument** direction uses a 112-point decorative photo strip, solid ink session information, a full-width lime Start/Resume and immediate weekly cadence. Accessibility and compact-height layouts prioritize the action over decorative artwork. Stable opaque logging cards, system numeric text and the existing owner-selected animated glass bar retain the established FORMA identity.

The two considered alternatives match [DESIGN_SYSTEM_V3.md](DESIGN_SYSTEM_V3.md): **Training Journal** offers a quieter dated diary hierarchy, while **Focused Cockpit** gives the current action and reading more dominance. The implemented direction keeps useful programming context while borrowing their calmness and task priority.

The configurable extension supports small, medium and large Home Screen widgets plus circular, rectangular and inline accessories. Next session and This week focus display real saved facts; routine/active links require the current opaque owner epoch and a still-existing current-store ID. A widget link waits for protected workout/profile/routine drafts to be explicitly saved or cancelled. The extension never starts a Watch workout or writes canonical training data.

The independent `FORMASurfaces` target contains the bounded versioned snapshot, Sydney calendar, atomic writer and strict route grammar. The app publishes after acknowledged current-owner state, with explicit sharing consent off by default. Complete protection, private-content redaction, bounded decode, expiry and monotonic publication keep account/Health credentials, notes and full history outside the group. Existing SQLite protection is unchanged. See [WidgetKit architecture](WIDGETKIT_ARCHITECTURE.md) for cache/reload limitations; the source does not promise instantaneous withdrawal of an already-rendered widget.

Live Activity and Watch complications are deliberately deferred with researched lifecycle/privacy/provisioning gates. The iPhone App Group does not create a Watch data path. No ActivityKit capability or working Live Activity is implied by the widget extension.

## Verification checkpoint and visual evidence

| Check | Actual outcome / limitation |
|---|---|
| Baseline core | 138 passed, zero failures |
| Final package | 141 core + four surfaces passed in `/tmp/forma-widget-package-complete.log`; includes shared calendar relocation |
| Final hosted app | 32 passed in `/tmp/forma-widget-widget-complete.log`: account lifecycle, holds, import ownership, projection/privacy/performance and the actual shared widget renderer |
| Final complete UI matrix | 24 passed, zero failures in `/tmp/forma-widget-regression-complete.log`; includes cold links, three protected draft types, largest-text/landscape geometry, motion, account forms, offline/reset/termination and three light tours |
| Actual WidgetKit host | Separate gallery/install/routine-link journey passed in `/tmp/forma-widget-widget-complete.log`; installed Home widget showed actual saved 0/4, gallery uses illustrative 2/4 |
| Dark visual tour | All three journeys passed in `/tmp/forma-widget-dark-tour.log`; 15 original attachments exported |
| Signed Release / widget bundle | Build and actual bundle/signature validator passed; matching app/extension group, Complete extension protection, embedded extension and absence of SQLite/Health linkage verified |
| Physical iPhone / Watch | iPhone install passed, launch blocked while locked; Watch installation/pairing blocked. No physical interactive/privacy/Watch success is inferred |
| Performance | Hosted ten-sample projection measurement exists for 10,000 history records / 200 routines; exact samples/configuration and Release Instruments limits belong in [performance evidence](PERFORMANCE_BASELINE_AND_RESULTS.md) |

All 18 historical Commit 2 JPEG comparisons were visually inspected. They are old 744 × 783 two-up composites, not current full-resolution proof. Fresh baseline screenshots were captured from the actual Simulator and copied into the audit's screenshot evidence. Final screenshot pairs, shared-widget rendering versus system-gallery results, theme/state coverage and missing cases belong in [screen review](SCREEN_REVIEW.md) and [test evidence](TEST_AND_APP_REVIEW_EVIDENCE.md). Shared-view rendering does not prove SpringBoard placement, tint/clear/vibrant contexts or locked-device protection.

## File coverage and remaining gates

[FILE_LEDGER.md](FILE_LEDGER.md) and [file-ledger.json](file-ledger.json) account for all 146 captured baseline paths and current new widget/shared/test/report inputs. They distinguish complete source reads, generated-record validation, image inspection, historical evidence, changed-after-read versions and exact-hash omissions. Final reconciliation records settled source hashes; changed-since-read flags preserve prior review provenance. Ledger self-hashes are recorded out of band to avoid recursive claims.

The remaining priorities are physical Lock Screen and system tinted/clear/vibrant/StandBy appearance evidence; passcode-device lock/reboot/account-exit/reset privacy; physical Watch failure/reconnect/finish/discard/Health deduplication; iOS 17 fallback runtime coverage; and on-device VoiceOver/large text/contrast/energy/performance review. Legal/provider eligibility, content-rights clearance, final archive privacy declarations and App Store acceptance remain owner/distribution gates. Signing/build success does not close those gates.
