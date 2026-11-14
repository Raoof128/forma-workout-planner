# App Store submission checklist

Recorded 13 November 2026 against `integ/app-store-1.0`, which was merged into
`main` the same day as `3a2f2fc` (PR #48). Apple's pages were read on that date; recheck
the [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
and the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
on the day of submission. Nothing here has been uploaded or declared to Apple.

## Verified in the Release archive

| Check             | Evidence                                                                                                                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SDK               | Xcode 27.2, `iphoneos27.2` and `watchos27.2` (Apple requires Xcode 26+ now, the 27 SDKs from April 2027)                                                                                      |
| Watch 64-bit      | `FORMAWatch` contains `arm64` and `arm64_32`                                                                                                                                                  |
| Privacy manifests | One in each of the app, Watch app, widget and Live Activity extensions; the widget declares file timestamp reason `C617.1`; no other required-reason API in source or binaries                |
| Third-party SDKs  | None                                                                                                                                                                                          |
| Icons             | 1024×1024, no alpha; dark and tinted variants for iPhone                                                                                                                                      |
| HealthKit         | Purpose strings on iPhone and Watch; no Clinical Health Records entitlement                                                                                                                   |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS and SHA-256 only)                                                                                                                           |
| Version           | 1.0.0 (1)                                                                                                                                                                                     |
| Shipped copy      | The in-app privacy notice (`legal.json`) has no "development build" or "prototype" wording; `unit/ios-resources.test.js` guards it                                                            |
| Debug hooks       | The `--ui-testing` workspace partition and reset, and the staging Access headers, are compiled out of Release. In any build the argument also silences rest notifications and Live Activities |

## Open before submission

1. **Watch on hardware.** The Watch was re-paired and 1.0 installed on
   13 November 2026 (Apple Watch Ultra 3). Still to verify by hand: start on
   Watch, heart rate and energy on the iPhone, save to Apple Health, the Watch
   summary on the finished workout, Health permission denied and revoked, Live
   Activity start and end.
2. **Back end.** Released on 13 November 2026: the production API accepts
   the Apple Watch summary and the site serves Privacy Policy 1.4; see the
   [release record](../../docs/qa/app-store-1.0-2026-11-13/README.md). The back
   end must stay up during review.
3. **Upload.** The `app-store-connect` export succeeded on 13 November 2026
   (distribution certificate and store profiles for all four bundles). Upload
   needs the App Store Connect app record first.
4. **Simulator and server suites.** App and UI tests, `test:server` and
   `test:accounts` were not run locally. CI ran them on PR #48 and passed; see
   the [release record](../../docs/qa/app-store-1.0-2026-11-13/README.md).
5. **Screenshots.** iPhone and Apple Watch sets from the final binary, at the
   sizes in the table below.
6. **Accessibility.** VoiceOver and Dynamic Type passes on device.

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
| Apple Watch screenshots  | One size; 422×514 from the owner's Apple Watch Ultra 3 (416×496 if taken on Series 10 to 12)                                                               |
| Review notes             | Guest use needs no account. Accounts ship in 1.0: a demo account with two-step verification off, and how to reach Apple Watch features                     |
| Sign in with Apple       | Not required: only FORMA's own email sign-up is offered (4.8)                                                                                              |

## Not established

Whether age-assurance laws (Texas, Utah, Louisiana, Australia) apply to a
non-social fitness app rated below 18+ is not stated on Apple's pages. Content
rights for the bundled exercise guides (share-alike) still need the owner's
review; see `app-review-matrix.md`.
