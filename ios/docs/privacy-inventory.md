# Native privacy inventory

Development scope: offline guest slice, recorded 23 October 2026. This is a
source-level inventory and submission draft, not a final App Privacy declaration.

| Data or capability | First native slice | Required evidence before distribution |
| --- | --- | --- |
| Routines, sets, weights, repetitions, time/distance, history and notes | Local guest workspace; no native cloud transport | Inspect final binary/network traffic; confirm no implicit telemetry or SDK collection |
| Display name, weekly goal, rest preferences and schedule | Local workspace | Verify local export, reset and retention behavior |
| Email/password, session cookies, MFA and account IDs | Native accounts not implemented | New consent, security, privacy and deletion review before introduction |
| Exercise queries | On-device catalogue search | Verify no query transmission |
| Catalogue and guide attribution | Bundled source/licence metadata | Review source rights and rendered attribution, including share-alike obligations |
| Decorative generated artwork | Bundled asset, no user imagery sent | Preserve original source/prompt and review the final asset |
| Analytics, ads, tracking identifiers | No SDK or native feature introduced | Inspect linked frameworks, privacy report and outgoing requests |
| HealthKit, clinical inference and biometric data | Outside this slice | No entitlement or permission string; separate review if introduced |
| Files/share export | User explicitly selects a destination | Explain that the destination may be cloud-backed and exported copies outlive local reset |
| External source/support/legal links | Open only following a user action | Ordinary website/email handling; never attach workout contents automatically |
| Device diagnostics and OS services | Platform-controlled behavior | Avoid absolute claims covering Apple's independent collection |

## Local protection and retention

The app's workspace directory must be protected with `FileProtectionType.complete`
and excluded from automatic device backups through
`URLResourceValues.isExcludedFromBackup`. Protection must cover SQLite main,
write-ahead-log, shared-memory and recovery files through their enclosing
directory. Verify actual attributes and behavior on a passcode-protected physical
device; Linux package tests cannot establish iOS protection.

Do not log raw workouts, notes, account identifiers or exported content. Keep
corrupt/unsupported workspaces intact for recovery rather than silently clearing
them. An explicit reset must explain its scope and require confirmation. It cannot
delete copies a user previously exported to Files or another destination.

## Privacy manifest

`FORMA/Resources/PrivacyInfo.xcprivacy` starts with tracking disabled, no tracking
domains, no developer-collected data categories and no declared required-reason
API categories. This reflects the scoped guest implementation; it must be checked
against the **final binary and all linked dependencies**. An empty API list is
not evidence that an audit has passed. Add only the actual Apple-approved reasons
for APIs that the final app uses; never invent a justification to silence an
upload warning.

The full source audit rechecked the recovery-copy file-size/type metadata keys
against Apple's current direct required-reason API lists; those keys are absent.
This adds no reason to the draft manifest. See the
[retrieval record](apple-design-2026.md#additional-sources-for-the-full-bug-audit).
It does not replace inspection of the archive and its linked implementations.

No `UserDefaults`, location, notification, camera, microphone, contacts, Photos,
HealthKit or advertising capability is required for the scoped loop. The app
does not request these permissions merely because they appear in future plans.

## App Privacy and legal decisions

An offline app whose operator does not collect records may qualify for Apple's
“Data Not Collected” answer only after verifying the exact shipping implementation
and third-party behavior. This document does not submit that answer. If native
account sync is added, linked workout records align with Apple's Fitness data
category; notes may also require Health or User Content assessment. Account data
cannot be hidden behind the presence of guest mode.

The bundled `native-privacy.md` is separate from website policy v1.3 because
browser storage and an account-backed service describe different behavior. Have
the final native notice, operator details, support contact, age policy and
storefront commitments legally reviewed. Entity eligibility under guideline
5.1.1(ix) is an independent question, especially for a later account-backed build.

Primary references:

- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

No native App Privacy form, export-compliance declaration or App Store Connect
record has been created or submitted by this milestone.
