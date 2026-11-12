# App Store submission checklist

Recorded 13 November 2026 against `integ/app-store-1.0` (`main` at `2de16d3`,
the readiness fixes and PR #43). Apple's pages were read on that date; recheck
the [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
and the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
on the day of submission. Nothing here has been uploaded or declared to Apple.

## Verified in the Release archive

| Check             | Evidence                                                                                                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| SDK               | Xcode 27.2, `iphoneos27.2` and `watchos27.2` (Apple requires Xcode 26+ now, the 27 SDKs from April 2027)                                                                       |
| Watch 64-bit      | `FORMAWatch` contains `arm64` and `arm64_32`                                                                                                                                   |
| Privacy manifests | One in each of the app, Watch app, widget and Live Activity extensions; the widget declares file timestamp reason `C617.1`; no other required-reason API in source or binaries |
| Third-party SDKs  | None                                                                                                                                                                           |
| Icons             | 1024×1024, no alpha; dark and tinted variants for iPhone                                                                                                                       |
| HealthKit         | Purpose strings on iPhone and Watch; no Clinical Health Records entitlement                                                                                                    |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS and SHA-256 only)                                                                                                            |
| Version           | 1.0.0 (1)                                                                                                                                                                      |
| Shipped copy      | No "development build" or "prototype" wording; `unit/ios-resources.test.js` guards it                                                                                          |
| Debug hooks       | `--ui-testing` and staging Access headers are compiled out of Release                                                                                                          |

## Open before submission

1. **Watch on hardware.** Installing to the Watch from the Mac fails with
   RemotePairing 1035. Re-pair in Xcode (Devices and Simulators), then verify:
   start on Watch, heart rate and energy on the iPhone, save to Apple Health,
   Health permission denied and revoked, Live Activity start and end.
2. **Release order.** This build includes PR #43, so a finished workout
   carries an Apple Watch summary (recorded time, average and highest heart
   rate, active energy) that syncs to the account. `main`'s API does not accept
   that field. Deploy the API and Worker from this branch to staging, then
   production, before the app goes to review; that also publishes Privacy
   Policy 1.4, which the app bundles. The back end must be up during review.
   The account verdict is GO (13 October 2026,
   `docs/security/release-security-verdict.md`).
3. **Upload.** The `app-store-connect` export succeeded on 13 November 2026
   (distribution certificate and store profiles for all four bundles). Upload
   needs the App Store Connect app record first.
4. **Simulator and server suites.** App and UI tests, `test:server` and
   `test:accounts` were not run locally; CI runs them on the pull request.
5. **Accessibility.** VoiceOver and Dynamic Type passes on device.

## App Store Connect entries

| Item                     | Answer or asset                                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bundle IDs               | `dev.raoufabedini.forma`, `.watchkitapp`, `.widgets`, `.workoutactivity`; app group `group.dev.raoufabedini.forma`                                         |
| Category                 | Health & Fitness                                                                                                                                           |
| Privacy policy URL       | `https://forma.raoufabedini.dev/#privacy` (confirm it renders signed out)                                                                                  |
| Support URL              | A web page that offers contact; in-app support is email only                                                                                               |
| App Privacy              | Email address, name, user ID, fitness and health (Apple Watch heart rate and energy summary): linked to the user, App Functionality, not used for tracking |
| Age rating               | Health or wellness topics (exercise guidance): expect 9+. Social media, shared location, dating: No. Unrestricted web access: No                           |
| Regulated medical device | No (App Information, App Store Regulations & Permits)                                                                                                      |
| EU trader status         | Required for EU storefronts and publishes contact details; otherwise leave the EU off                                                                      |
| Export compliance        | Answered by the Info.plist key                                                                                                                             |
| iPhone screenshots       | At least one set at 1206×2622 or 1179×2556, from the final binary with synthetic data                                                                      |
| Apple Watch screenshots  | One size, 416×496 (Series 10 to 12)                                                                                                                        |
| Review notes             | Guest use needs no account. If accounts ship: a demo account with two-step verification off, and how to reach Apple Watch features                         |
| Sign in with Apple       | Not required: only FORMA's own email sign-up is offered (4.8)                                                                                              |

## Not established

Whether age-assurance laws (Texas, Utah, Louisiana, Australia) apply to a
non-social fitness app rated below 18+ is not stated on Apple's pages. Content
rights for the bundled exercise guides (share-alike) still need the owner's
review; see `app-review-matrix.md`.
