# App Review readiness matrix

Recorded 23 October 2026. The project is an **offline guest development slice**.
These are engineering gates, not a legal opinion or promise that Apple will
approve a later submission. The supplied plans are research references; the
current official rules and actual shipping binary control the submission.

| Area | Scoped design and evidence | Status before distribution |
| --- | --- | --- |
| 4.2 Minimum functionality | Real SwiftUI navigation, on-device routine/workout utility and local persistence; no web wrapper | Design implemented in source; Xcode/device evidence required |
| 2.1 Completeness | No native account placeholders or hidden remote feature activation; useful offline loop | Full native build, UI/device test and recovery evidence required |
| 1.4 Physical harm | General workout log; no diagnosis, treatment, readiness inference or medical claims | Review every bundled guide, safety copy and final marketing claim |
| 5.1.1 Privacy | Guest records stay in the local workspace; separate native notice; explicit export | Verify final binary, backup treatment, retention, permissions and App Privacy answers |
| 5.1.1(v) Account deletion | No account creation or sign-in in the native slice | Before native accounts: build findable in-app deletion initiation and verify real deletion states |
| 5.1.1(ix) Provider eligibility | No healthcare service claimed; seller/operator identity must be genuine | Assess the exact service and sensitive-data handling with Apple/legal counsel; neither fitness-category exemption nor mandatory incorporation is assumed |
| 5.1.3 Health and fitness data | Apple Watch workouts save to Apple Health; heart rate and energy stay on device, out of FORMA records, iCloud and exports; no advertising or tracking | Verify the data flow on hardware, Health disclosures and App Privacy answers; reassess if account sync is introduced |
| 5.2 Intellectual property | Original F geometry, generated decorative art, bundled per-guide source metadata | Verify brand/font/image/guide rights and attribution/share-alike obligations with a human reviewer |
| 2.3 Accurate metadata | No fabricated history or claimed native features; images are decorative | Screenshots and previews must come from the final running binary with clearly synthetic review data |
| Privacy manifests | Initial no-tracking manifest included | Audit required-reason APIs and SDK manifests in the actual archive |
| Accessibility | Native semantic controls, scalable text, Reduced Motion design and large targets | VoiceOver, Dynamic Type, contrast, motor control and device testing remain open |
| SDK and signing | iOS 17 deployment target; local package and shared scheme | Verify Apple's current upload SDK requirement on submission date; confirm final bundle ID/team and sign/archive on Mac |
| Encryption | SQLite plus system file protection; no custom cryptographic feature added | Complete the export-compliance assessment for the final archive; no declaration submitted here |
| Review access | Guest loop available without registration | Provide exact reviewer instructions and verify any future demo account without real member data |
| Seller, age and regions | Provisional development bundle ID only | Confirm membership/entity, operator/support details, age/guardian policy, storefronts and applicable medical-device fields |

## Evidence ledger

- Starting source SHA and reconciled contract facts: [baseline evidence](baseline-evidence.md).
- Source/resource and package results: record actual commands in the root change
  log; do not infer UI results from them.
- Xcode project generation/build: **not established by Linux checks**.
- iPhone simulator journeys and screenshots: **not run in this environment**.
- Physical-device interruption, locked-device file protection, accessibility,
  performance and energy: **not run in this environment**.
- Signed archive, privacy report and App Store validation: **not run**.
- TestFlight and App Review: **not submitted**.

## Submission constraints

The earlier user instruction prohibits publishing. This milestone must not upload
a binary, create an App Store Connect record, change production infrastructure,
enable new collection or contact Apple/other people on the user's behalf.

Native accounts need a reviewed protocol rather than reusing a coach token,
relaxing the browser Origin boundary or compiling Worker credentials into the
app. Before account distribution, complete member-partition isolation,
revision/idempotency/conflict recovery, explicit guest migration, consent, MFA,
session expiry and deletion tests as one coherent release.

Official references:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Health and fitness apps](https://developer.apple.com/health-fitness/)
- [Account deletion requirement](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)

Recheck these living sources at submission time. The versioned research document
does not freeze Apple's rules, SDK deadlines or screenshot requirements.
