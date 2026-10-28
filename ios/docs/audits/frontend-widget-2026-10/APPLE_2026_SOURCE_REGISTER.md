# Apple source register — 29 October 2026

Retrieved 29 October 2026, Australia/Sydney. This register separates current
platform policy, design guidance and API availability. Session evidence is
substantive transcript reading; videos were not reviewed frame by frame. HIG
reference images embedded in these pages were not visually inspected during this
research pass. Living documentation can describe APIs newer than the deployment
floor. A session's 2026 publication date does not establish iOS 26 availability.

Raw research responses, extracted transcripts and SHA-256 retrieval manifests
are in `/tmp/forma-widget-watch-audit/research/manifest.json`,
`/tmp/forma-widget-watch-audit/source-register.json` and
`/tmp/forma-apple-widget-research/manifest.json`. These are session scratch files,
not shipped resources. Source hashes identify retrieved responses, including
page-generated material; they may differ from historical retrievals.

## Claim-to-decision register

| Source and evidence | FORMA decision | Availability / status |
| --- | --- | --- |
| [WWDC26 251: Communicate your brand identity on iOS](https://developer.apple.com/videos/play/wwdc2026/251/), 2:24–3:49, 9:39–10:42, 12:14–13:51, 15:59–16:24: familiar controls, content-led identity, purposeful color, scalable typography and restrained logos | Preserve the existing FORMA mark, lime/ink palette and editorial content. Retain the separately authorized custom tab bar; audit its platform semantics/accessibility rather than silently replacing it. Let labels wrap at large text sizes. | Design guidance, not an API or an App Review rule. Rendered verification remains separate. |
| [WWDC26 250: Principles of great design](https://developer.apple.com/videos/play/wwdc2026/250/), 1:50–3:33 and 14:46–16:13: agency, recoverability, confirmation for destructive actions and craft through iteration | Preserve explicit finish/discard/import/reset choices. Keep success feedback tied to durable outcomes. Avoid decorative additions that compete with logging. | Design guidance. Existing transaction and confirmation paths are source evidence; device behavior needs verification. |
| [WWDC26 269: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/), 1:45–2:24 and 5:31–7:22: 2027 release appearance and new toolbar placement/priority APIs | No new toolbar/visibility symbol is justified solely by this talk. Compile against the installed SDK and guard each newer API against the iOS 17 floor. | The transcript explicitly calls these 2027 releases. Existing iOS 26/26.1 guards remain necessary. |
| [WWDC26 220: Refine accessibility for custom controls](https://developer.apple.com/videos/play/wwdc2026/220/), 3:34–3:56 and 9:34–10:41: expose purpose, value, action and feedback; named actions can replace complex gestures | Audit the custom tab bar, set completion, rest controls and widget destinations as controls. Pair color/motion with readable state; provide meaningful labels and actions. | Design guidance using existing accessibility APIs; no iOS 27-only dependency required. VoiceOver/device tests remain gates. |
| [WWDC26 292: Design intuitive search experiences](https://developer.apple.com/videos/play/wwdc2026/292/), 3:55–4:39 and 7:04–7:40: placement conveys search scope | Keep exercise search scoped to Plan/library and picker. A separate global search destination would imply capabilities the app does not provide. | Design guidance; use deployment-compatible search APIs. |
| [WWDC26 268: Profile, fix, and verify](https://developer.apple.com/videos/play/wwdc2026/268/), 1:46–3:59 and 24:35–25:58: distinguish busy CPU from blocked main thread, profile Release, compare the same workflow after repair | Record real startup/search/set-save traces before claiming faster performance. Use Time Profiler, Swift Concurrency and System Trace according to the symptom. | Instruments 27 is discussed. No device-performance improvement is established by source inspection or Debug simulator timing. |
| [WWDC26 277: WidgetKit foundations](https://developer.apple.com/videos/play/wwdc2026/277/), 2:34–3:41, 9:39–11:22, 13:15–14:22 and 17:04–18:33: separate extension process, shared data, timeline budgets, contextual links, tint/clear adaptation | Use a minimal app-authored snapshot, meaningful timeline reloads and precise routes. Compose each family for its bounds and test rendering modes. A widget must not become another workout-store writer. | Basic WidgetKit precedes the deployment floor; some rendering enhancements are newer. Check declarations and guard newer modifiers. |
| [WWDC26 223: Live Activities essentials](https://developer.apple.com/videos/play/wwdc2026/223/), 7:46–9:39 and 11:28–13:06: authorization, static/dynamic state, stale dates and additional presentations | Live Activity remains a separate ownership/lifecycle feature. Use a privacy-safe title, saved timestamps and a stale state; reconcile orphan activities after relaunch before enabling it for release. | Basic ActivityKit is iOS 16.1; current content-based request/update APIs are iOS 16.2. Small-family and other newer additions need independent availability checks. |
| [HIG Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets), anatomy/appearances, rendering modes, previews/placeholders | Distinguish an illustrative gallery preview from real empty/reset/unavailable/private states. Design full-color, accented and vibrant presentations without relying on lime alone. | Design guidance. Widget rendering mode availability must be checked per API. No screenshot/appearance acceptance implied. |
| [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion), best practices and feedback | Keep `FormaMotion` authoritative on iPhone; brief, optional motion follows real state. Do not delay frequently repeated logging operations for decoration. | Current guidance; the page's Liquid Glass change log is September 2025, not a new 2026 feature. |
| [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), best practices, layout and interactivity | A bounded workout is a plausible use case. Keep private details out of public presentations and provide a direct Resume destination. Ending/removing the display must not mutate a workout implicitly. | Design guidance. Implementation remains gated on persistence ownership, lifecycle and physical lock-screen proof. |
| [HIG Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), device characteristics and best practices | Keep Watch interactions short and legible. Preserve primary Health recording independently of iPhone mirroring; expose explicit reconnection rather than background polling. | watchOS 10 baseline. New complications require a Watch-local projection and separate provisioning/test evidence. |
| [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension), Hide sensitive content | Apply complete Data Protection to the extension and protected snapshot. Mark sensitive views and use genuine redacted/unavailable states. Do not weaken the private SQLite store. | Apple documents that complete protection hides content while locked and prevents iPhone widget mirroring on Mac. Simulator appearance does not prove device protection. |
| [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy), platform contexts and data updates | Keep widgets/timelines separate from Live Activities. An iPhone App Group does not create a Watch data bridge. | Plan platform-specific targets and data flow. |
| [App Groups entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups) | The iPhone app and its extension need the same owner-controlled group and matching signing team. Keep cookies, account profiles and the full SQLite database outside that group. | Capability/provisioning gate; adding entitlement text alone does not register or authorize the group. |
| [Describing required-reason API use](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), executable/bundle responsibility | Inspect every final executable and linked dependency. Existing empty API lists cannot certify the final archive. Declare only actual uses with matching approved reasons. | Required for covered APIs; not permission to fingerprint. Applies to each affected bundle. |
| [Required-reason categories and approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), FileTimestamp/UserDefaults categories | Source inventory found no direct UserDefaults, uptime, disk-space or timestamp call in the reviewed native source. Plain URL file-size/type keys do not establish a listed direct timestamp call. A future App Group UserDefaults bridge would need the actual group-scoped reason `1C8F.1` in each using target. | Current official indexed category text checked. Do not add `CA92.1` to justify sharing outside the app's own defaults domain. Archive inspection remains open. |
| [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) | Keep a manifest in each shipping app/extension bundle. Reconcile collected account fitness/name/email/user ID with App Privacy answers and native policy. | Manifest presence/source parsing is not final privacy-report acceptance. |
| [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), stale content, ending and observing activities | Any future coordinator must enumerate existing activities on relaunch, end irrelevant activities and provide final content. Use immediate dismissal on reset/account exit. A stale display must not imply a still-current workout. | Installed SDK confirms `Activity.request(attributes:content:pushType:)` is iOS 16.2 and `ActivityConfiguration` iOS 16.1. No push infrastructure is necessary for an app-driven local feature. |

## Distribution and policy sources

- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/):
  the retrieved page states that uploads have required Xcode 26+ and the relevant
  iOS/watchOS 26+ SDK since 28 April 2026. Since 9 September 2026, iOS/iPadOS
  deployment targets must be iOS 13+. FORMA's iOS 17 deployment target is distinct
  from its SDK choice and satisfies that deployment floor. Recheck on upload day.
- [Xcode compatibility](https://developer.apple.com/support/xcode/): the retrieved
  Xcode 27.1 row lists macOS 26.6+, iOS 27.1/watchOS 27 SDKs, Swift 6.4, deployment
  support iOS 15–27/watchOS 9–27 and device/simulator support iOS 17+/watchOS 10+.
  The local SDK headers were read directly; this research did not run a build.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/):
  5.1.1 requires accessible privacy information, appropriate consent and in-app
  account deletion where accounts can be created. Section 5.1.1(ix) links
  sensitive-information services with provider legal-entity submission; the
  owner's eligibility requires Apple/legal assessment, not an assumed fitness
  exemption or automatic rejection. Section 5.1.3 restricts health/fitness uses,
  requires accurate Health data and rules out storing personal health information
  in iCloud. The existing account system changes the App Privacy assessment even
  while guest use remains available. These are release gates, not legal advice.
- [Apple Health and fitness](https://developer.apple.com/health-fitness/): use
  documented HealthKit authorization and Health integration. FORMA's Watch
  metrics remain separate from synced training records; verify that boundary on
  paired physical hardware before distribution.

## Installed-SDK checks

Read directly from Xcode.app's iPhoneOS 27.1 ActivityKit/WidgetKit Swift
interfaces and watchOS 27.0 HealthKit headers:

| Declaration | Installed availability | Consequence |
| --- | --- | --- |
| `Activity` / `ActivityConfiguration` | iOS 16.1; unavailable as Watch-hosted ActivityKit | iOS 17 supports the baseline; a Watch complication is a separate feature. |
| Content-based `Activity.request` | iOS 16.2 | Suitable baseline; newer style/scheduling overloads are not needed. |
| `HKWorkoutSession.startMirroringToCompanionDevice` | watchOS 10; unavailable on iOS | Only the Watch starts mirroring. |
| `HKHealthStore.recoverActiveWorkoutSession` | watchOS 5, iOS 26 | Existing Watch recovery is compatible; do not add an unguarded phone recovery call at iOS 17. |
| `HKHealthStore.startWatchApp(toHandle:)` | iOS 10; unavailable on watchOS | The iPhone may open the Watch, but the user's Watch Start remains the recording boundary. |

No unavailable API was inferred from a 404 or JavaScript-only response. Apple
Markdown endpoints supplied readable article text; indexed official category
text supplied the approved UserDefaults reason when the Markdown symbol page
omitted its possible-values table.

## Final build-setting verification

[Apple build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference), retrieved 29 October 2026: `ENABLE_CODE_COVERAGE` controls coverage instrumentation; explicit test coverage collection remains supported. Installed Xcode 27.1 confirmed a scheme-wide coverage default also instrumented Swift-package dependencies in Release. Set coverage collection to opt-in, disable Release coverage/mapping and inspect actual signed Mach-O sections. This is an applied build correctness decision, not a measured performance claim. The final app/widget/Watch binaries contain no `__llvm_prf*` sections.

## Consolidation follow-up: older SDK symbol availability

On 29 October, the consolidation CI using Xcode 26.3 / SDK 26.2 exposed the SwiftUI Cross-Fade environment key as unavailable at compile time. Runtime availability guarding did not solve symbol lookup. The follow-up uses UIKit's [Cross-Fade preference](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitions) and [notification](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitionsstatusdidchange), both declared from iOS 14 in the installed UIKit headers. See the [consolidation record](../../../../docs/maintenance/branch-consolidation-2026-10-29.md) for source changes, local 33 hosted/four UI tests and the separate older-SDK CI gate.
