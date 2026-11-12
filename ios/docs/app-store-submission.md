# App Store submission checklist

Recorded 13 November 2026 against `main` (`2de16d3`) plus the
`fix/app-store-readiness` branch. Apple's pages were read on that date; recheck
the [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
and the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
on the day of submission. Nothing here has been uploaded or declared to Apple.

## Verified in the Release archive

| Check | Evidence |
| --- | --- |
| SDK | Xcode 27.2, `iphoneos27.2` and `watchos27.2` (Apple requires Xcode 26+ now, the 27 SDKs from April 2027) |
| Watch 64-bit | `FORMAWatch` contains `arm64` and `arm64_32` |
| Privacy manifests | One in each of the app, Watch app and widget extension; the widget declares file timestamp reason `C617.1`; no other required-reason API in source or binaries |
| Third-party SDKs | None |
| Icons | 1024×1024, no alpha; dark and tinted variants for iPhone |
| HealthKit | Purpose strings on iPhone and Watch; no Clinical Health Records entitlement |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS and SHA-256 only) |
| Version | 1.0.0 (1) |
| Shipped copy | No "development build" or "prototype" wording; `unit/ios-resources.test.js` guards it |
| Debug hooks | `--ui-testing` and staging Access headers are compiled out of Release |

## Open before submission

1. **Watch on hardware.** Installing to the Watch from the Mac fails with
   RemotePairing 1035. Re-pair in Xcode (Devices and Simulators), then verify:
   start on Watch, heart rate and energy on the iPhone, save to Apple Health,
   Health permission denied and revoked, Live Activity start and end.
2. **Accounts.** The app points at `https://forma.raoufabedini.dev`, where
   sign-up is live. The 12 October 2026 verdict was no real members until the
   restore, alerting and infrastructure gates pass. Close those gates, or build
   a guest-only release. The back end must be up during review.
3. **Open pull requests.** #43 (Watch collected data, 2 November audit fixes)
   conflicts with `main`; #37 and #38 are unmerged. They are not in this
   build. If #43 ships, heart rate and energy leave the device, so the privacy
   manifest, the in-app notice, `privacy-inventory.md` and the App Privacy
   answers must change first (add Health; guideline 5.1.3).
4. **Distribution signing.** Export the archive with the `app-store-connect`
   method and run validation. Not run: it creates a distribution certificate.
5. **Accessibility.** VoiceOver and Dynamic Type passes on device.

## App Store Connect entries

| Item | Answer or asset |
| --- | --- |
| Bundle IDs | `dev.raoufabedini.forma`, `.watchkitapp`, `.widgets`; app group `group.dev.raoufabedini.forma` |
| Category | Health & Fitness |
| Privacy policy URL | `https://forma.raoufabedini.dev/#privacy` (confirm it renders signed out) |
| Support URL | A web page that offers contact; in-app support is email only |
| App Privacy | Email address, name, user ID, fitness: linked to the user, App Functionality, not used for tracking. Add Health if #43 ships |
| Age rating | Health or wellness topics (exercise guidance): expect 9+. Social media, shared location, dating: No. Unrestricted web access: No |
| Regulated medical device | No (App Information, App Store Regulations & Permits) |
| EU trader status | Required for EU storefronts and publishes contact details; otherwise leave the EU off |
| Export compliance | Answered by the Info.plist key |
| iPhone screenshots | At least one set at 1206×2622 or 1179×2556, from the final binary with synthetic data |
| Apple Watch screenshots | One size, 416×496 (Series 10 to 12) |
| Review notes | Guest use needs no account. If accounts ship: a demo account with two-step verification off, and how to reach Apple Watch features |
| Sign in with Apple | Not required: only FORMA's own email sign-up is offered (4.8) |

## Not established

Whether age-assurance laws (Texas, Utah, Louisiana, Australia) apply to a
non-social fitness app rated below 18+ is not stated on Apple's pages. Content
rights for the bundled exercise guides (share-alike) still need the owner's
review; see `app-review-matrix.md`.
