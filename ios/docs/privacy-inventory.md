# Native privacy inventory

Development scope: offline guest use plus optional FORMA account sign-in and
sync, updated 28 October 2026 (first recorded 23 October 2026 for the offline
guest slice). This is a source-level inventory and submission draft, not a final
App Privacy declaration.

| Data or capability | Where it goes | Required evidence before distribution |
| --- | --- | --- |
| Routines, sets, weights, repetitions, time/distance, history and notes | Guest: local workspace only. Signed in: also the member's FORMA account (`GET`/`PUT /api/workspace` over HTTPS, `forma.raoufabedini.dev`) and a per-member saved copy on the device | Inspect final binary/network traffic; confirm the only destination is the account origin and nothing is sent signed out |
| Display name, weekly goal, rest preferences and schedule | Same as above (they are part of the workspace); the display name is also the account name | Verify export, reset, sign-out and deletion behaviour |
| Email address | Signed in only: sent at sign-up/sign-in, change-email and reset requests; held in the Keychain session record on the device | Account deletion flow; confirm no logging of the address |
| Password | Sent to the account for sign-in, password change, two-step and deletion steps; never stored on the device | Confirm it is not logged, cached, put in a URL or kept after the request |
| Session cookies (`forma.*`, `__Secure-forma.*`) and the member reference (`mem_…`, the account's opaque id) | Keychain item, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, one item for the cookies and last-known profile; cleared on sign-out, session end, and when found without the install marker (after a reinstall). The URLSession has cookies, cache and credential storage off | Verify on a device: not in backups, removed on sign-out |
| Two-step codes, recovery codes, coach tokens | Shown once on screen; copied only if the member asks (local-only, two-minute pasteboard expiry); never stored | Confirm the screens clear them on leaving |
| Which member brought this phone's guest training into an account | `phone-training-import.json` in Application Support (opaque member reference and date), not UserDefaults | Verify it is excluded from backup with the directory |
| Exercise queries | On-device catalogue search | Verify no query transmission |
| Catalogue and guide attribution | Bundled source/licence metadata | Review source rights and rendered attribution, including share-alike obligations |
| Decorative generated artwork | Bundled asset, no user imagery sent | Preserve original source/prompt and review the final asset |
| Analytics, ads, tracking identifiers | No SDK or native feature introduced | Inspect linked frameworks, privacy report and outgoing requests |
| Apple Watch workout: heart rate, active and basal energy, workout record | Watch records into Apple Health after permission; iPhone shows live values via the mirrored session and never stores, exports or syncs them; no clinical inference | HealthKit entitlement and purpose strings on both apps; verify on paired hardware, Health permission revocation, and that nothing leaves the device, signed in or not |
| Files/share export | User explicitly selects a destination | Explain that the destination may be cloud-backed and exported copies outlive local reset, sign-out and account deletion |
| External source/support/legal links | Open only following a user action (including the website's Terms and Privacy Policy) | Ordinary website/email handling; never attach workout contents automatically |
| Device diagnostics and OS services | Platform-controlled behavior | Avoid absolute claims covering Apple's independent collection |

## Accounts: network and storage

- **One destination.** `FORMA_ACCOUNT_ORIGIN` (project.yml, surfaced as
  `FORMAAccountOrigin` in Info.plist) is the only host the app talks to,
  `https://forma.raoufabedini.dev`. `NSAppTransportSecurity` is the default (an
  empty dictionary) with no exceptions, so HTTP is refused by the system. Redirects
  are never followed, so cookies and the member header cannot reach another host.
- **Native requests.** Every request sends `X-Forma-Client: ios` and, once known,
  `X-Forma-Member`. The app never sends `Origin`, `Referer` or `Sec-Fetch-*`;
  the account recognises it by their absence. No Cloudflare Access header or
  secret exists in the app.
- **Member cache.** One SQLite file per member, `member-<reference>.sqlite`, in the
  same protected, backup-excluded directory as the guest store. Signing out keeps
  it (with any unsent changes); "Sign out and remove from this iPhone" deletes it
  and is only offered when nothing is waiting. The guest store is never written
  while a member is signed in, and is never merged into a member except by the
  explicit "Bring your phone training" review.
- **Nothing is logged** that contains workout content, notes, emails, passwords,
  cookies or tokens.

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

`FORMA/Resources/PrivacyInfo.xcprivacy` has tracking disabled, no tracking
domains and no declared required-reason API categories. It declares four
collected data types, all **linked to the user** and used for **App
Functionality** only (the account exists to run the app), none used for
tracking: email address, name, fitness (workout records) and user ID (the
account's member reference and session). Whether workout notes also count as
Other User Content, and whether the records count as Health as well as Fitness,
is an App Store Connect decision still to be made (see below). The manifest must
be checked against the **final binary and all linked dependencies**. An empty API list is
not evidence that an audit has passed. Add only the actual Apple-approved reasons
for APIs that the final app uses; never invent a justification to silence an
upload warning.

The full source audit rechecked the recovery-copy file-size/type metadata keys
against Apple's current direct required-reason API lists; those keys are absent.
This adds no reason to the draft manifest. See the
[retrieval record](apple-design-2026.md#additional-sources-for-the-full-bug-audit).
It does not replace inspection of the archive and its linked implementations.

No `UserDefaults`, location, notification, camera, microphone, contacts, Photos
or advertising capability is required; the Keychain and the Network framework's
path monitor (reachability only, used to retry a waiting sync) are not
required-reason APIs. HealthKit is requested only when a
workout is started with Apple Watch, for the types listed above. The app
does not request these permissions merely because they appear in future plans.

## App Privacy and legal decisions

The app now collects data when a member signs in, so “Data Not Collected” no
longer applies to the build as a whole: the App Privacy answers must list the
account data above, linked to the user, for App Functionality, and not used for
tracking. Linked workout records align with Apple's Fitness data category; notes
may also require Health or Other User Content assessment. Account data cannot be
hidden behind the presence of guest mode. Account deletion is available inside
the app (guideline 5.1.1(v)); it completes when the member confirms the emailed
link. This document does not submit any answer.

The bundled `native-privacy.md` (shown in the app as `legal.json`'s
`nativeGuestNotice`, generated by `scripts/build-ios-resources.mjs`) is separate
from website policy v1.3 because browser storage and an account-backed service
describe different behavior; keep the two texts in step. Have
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

## October2026 widget boundary

The app and `FORMAWidgets` share only `training-widget-v1.json` in
`group.dev.raoufabedini.forma`. It contains a random owner epoch, local revision,
generation/expiry times, next routine name/id/count/estimate, saved active set
counts and seven weekly day flags/session count/goal. No SQLite, credentials,
member reference, profile name, notes, full history or Health readings enter it.
Sharing is off by default per service origin/owner. Main app-only atomic writer;
read-only extension; complete protection and backup exclusion. Widget entitlement
`NSFileProtectionComplete` hides content while locked and disables Mac mirroring.
System-cached views may outlive app revocation/reload requests temporarily.

The widget makes no network calls, declares no collected data/tracking/required
reason API, and uses file size/type metadata only (not file timestamps/disk space).
The new bundle validator inspects actual embedding, declarations and linkage;
final archive-linked privacy reports and device lock/cache checks remain gates.
Consent write failures are visible; failed revocation tries durable file removal
before restoring the actual prior persisted state with an explicit error.
