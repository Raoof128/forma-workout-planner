# FORMA iOS front-end audit: account UI slice

2 November 2026. Read-only static review of
`repository root` (branch `feat/watch-collected-data`).
No repo files were edited. Nothing was built or run: this review had no simulator or device, so
any finding marked **device** needs the owner to confirm it on iPhone.

**Files read in full:** `ios/FORMA/Account/AuthFlowView.swift`, `AccountSection.swift`,
`AccountProfileView.swift`, `AccountSecurityView.swift`, `AccountPrivacyView.swift`,
`SyncDetailsView.swift`, `TrainingDataView.swift`, `AccountSupport.swift`.

**Files skimmed for context:** `AccountModel.swift` (`call`, `busy`, sign-out notices),
`Sources/FORMACore/AccountWire.swift` (error copy), `FORMA/App/AppModel+Account.swift` (conflict
resolution return types), `DesignSystem/FormaTheme.swift`, `DesignSystem/FormaMotion.swift`,
`FORMA/FORMA.entitlements`, `project.yml`, `server/app.ts` and `server/coachRoutes.ts` (fresh-session
rules), `src/components/Account.jsx` (web parity), the repo `CLAUDE.md` "Native iOS and watchOS" and
security sections, and the four design notes named in the brief.

**Already decided, not re-reported:** the custom Liquid Glass tab bar; the 44 pt / 56 pt target
policy; email and password only, with Sign in with Apple and passkeys an open owner decision
(`native-accounts-findings.md`); errors placed above the submit button so the keyboard does not
cover them (comment at `AuthFlowView.swift:235`); and wording kept in line with the website. Where
new Apple evidence bears on one of these decisions, it is noted and left as Low.

**Tooling used:** ui-ux-pro-max (`--stack swiftui` for forms and focus; `--domain ux` for auth, error
and validation; the pro-rules Pre-Delivery Checklist), frontend-design's writing guidance, Apple
documentation (fetched as `.md` or HIG JSON), and the installed iPhoneOS 27.2 SDK `.swiftinterface`
files for API availability and deprecation.

---

## 1. HIG and Apple-rules checklist (this slice)

| Area | Result | Notes |
| --- | --- | --- |
| Password AutoFill: associated domains | **Fail** | No `webcredentials:` entitlement and no AASA file (H1) |
| `textContentType`: sign-in `username` + `password` | Pass | `AuthFlowView.swift:174,183` |
| `textContentType`: sign-up identifier | **Fail** | Uses `.emailAddress` where Apple says to use `.username` (M1) |
| `textContentType`: `newPassword` on sign-up, change and confirm | Pass | `AuthFlowView.swift:183`, `AccountSecurityView.swift:83,89` |
| `textContentType`: `oneTimeCode` on TOTP fields | Pass | `AuthFlowView.swift:401`, `AccountSecurityView.swift:327,681` |
| Keyboard types (email, number pad, ASCII for recovery codes) | Pass | |
| Submit labels and focus order | Pass, with gaps | Auth and deletion chain focus correctly; the 2FA confirm sheet sets no initial focus (L10) |
| Secure entry | Pass, **device** | The reveal control swaps the view's identity (M4) |
| Inline validation | Partial | Sign-up passes; change password validates only on submit (M5) |
| Error placement and VoiceOver announcement | Pass | `FormNotice` posts announcements, including repeats (`AccountSupport.swift:36-43`) |
| Account deletion, App Review 5.1.1(v) | Pass | In-app start, email confirmation, timing stated, completion notice |
| Destructive confirmations | Pass | Confirmation dialogs or an acknowledgement checkbox on every destructive path |
| Loading states | Mostly pass | A few buttons have no progress indicator (L9) |
| Haptics only after a confirmed save (repo rule) | **Fail** | `SyncDetailsView` plays success regardless of outcome (M3) |
| Motion routed through `FormaMotion` (repo rule) | **Fail** | One raw `withAnimation` call (M7) |
| Dynamic Type | Partial, **device** | `AdaptiveRow` is good; the gate view cannot scroll (M6) |
| Contrast | Not measured | Tokens have high-contrast variants; `ink` on `lime` is fine; disabled controls are WCAG-exempt |
| Tap targets ≥ 44 pt | Pass | Reveal button `AccountSupport.swift:259`; Revoke `:516,:828`; `SubmitButton` 56 pt |
| VoiceOver labels and traits | Mostly pass | Secrets are read as words (L4); icon noise in session rows (L6) |
| Copy and wording | Mostly pass | "We" in errors (L2); action names drift within flows (L3) |
| Deprecated APIs | **Fail (low)** | `Text + Text` is deprecated in iOS 26 (L1) |
| Sign-in methods (passkeys, Sign in with Apple, required 2FA) | Open owner decision | New HIG evidence (L11) |

---

## 2. Findings

Counts: **High 1 · Medium 7 · Low 13**

### HIGH

#### H1. Password AutoFill cannot work for the website's domain: no Associated Domains entitlement and no AASA file

- **Evidence**
  - `ios/FORMA/FORMA.entitlements` holds only `com.apple.developer.healthkit`,
    `healthkit.access` and `com.apple.security.application-groups`.
  - It has no `com.apple.developer.associated-domains` key.
  - A repo-wide search finds no `apple-app-site-association` and no `webcredentials` anywhere
    (`public/`, `worker/`, `server/`, `src/`).
  - No design note records a decision to leave this out.
  - Meanwhile the forms are tagged correctly (`.username`, `.password`, `.newPassword`,
    `.oneTimeCode`), so they are ready for AutoFill but have no domain to draw credentials from.
- **Apple guidance**
  - "New passwords. The system suggests a strong, unique password in apps that have an associated
    domain. It also saves any new credentials."
  - "Password AutoFill recommends credentials only for your app's associated domain".
  - Step 1 of "Enable Password AutoFill" is "Set up your app's associated domains."
  - Sources:
    - https://developer.apple.com/documentation/security/about-the-password-autofill-workflow
    - https://developer.apple.com/documentation/security/password-autofill
    - https://developer.apple.com/documentation/xcode/supporting-associated-domains
- **User impact**
  - The owner's stated goal is one account across the website and the app. A member who saved
    their password in Safari on `forma.raoufabedini.dev` gets no QuickType suggestion in the app
    (only the generic key icon).
  - Sign-up and Change password offer no strong-password suggestion. The member has to make up and
    type a passphrase of at least 15 characters themselves.
  - Credentials created in the app are not tied to the website.
  - Verification codes stored in Apple's Passwords app are presumably also not suggested in context
    (unconfirmed).
- **Fix** (needs owner approval: Worker/production deploy and provisioning are gated)
  1. Add to `FORMA.entitlements`, driven from a build setting so staging gets its own host:
     ```xml
     <key>com.apple.developer.associated-domains</key>
     <array><string>webcredentials:$(FORMA_ACCOUNT_HOST)</string></array>
     ```
     For a staging host behind Access, append `?mode=developer` to the entry, because Apple's CDN
     cannot fetch through Access.
  2. Serve `/.well-known/apple-app-site-association` from the Worker as `application/json`, with no
     redirect, publicly readable:
     ```json
     {"webcredentials":{"apps":["3L5A4R7JNY.dev.raoufabedini.forma"]}}
     ```
     The bundle ID is still provisional, so final values wait on that.
  3. Enable the Associated Domains capability on the App ID.
  4. **Device** check: on the iPhone, sign-up should offer "Use Strong Password" and sign-in should
    offer the website's saved credential.

### MEDIUM

#### M1. Sign-up and forgot-password tag the email as `.emailAddress`, not `.username`

- **Evidence:** `AuthFlowView.swift:174`
  ```swift
  .textContentType(screen == .signIn ? .username : .emailAddress)
  .keyboardType(.emailAddress)
  ```
- **Apple guidance:** "if your site uses email addresses as user names, set the input view's
  textContentType property to username, and set the … keyboardType property to emailAddress."
  https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view
- **User impact:** on sign-up, the field paired with `.newPassword` is the one AutoFill uses as the
  saved credential's user name. Tagged `.emailAddress`, it relies on heuristics, so the saved entry
  may have no user name or the wrong one. Forgot-password then cannot offer the saved account.
- **Related, unconfirmed:** Change password (`AccountSecurityView.swift:76-92`) has no user-name
  field at all. Apple's current page does not say one is required, but AutoFill then has to guess
  which saved entry to update. Consider a read-only `TextField` holding the profile email, tagged
  `.username`.
- **Fix:** `.textContentType(.username)` on every screen (keep `.keyboardType(.emailAddress)`).
  Keep `.emailAddress` only for the "New email address" field in Profile
  (`AccountProfileView.swift:82`).

#### M2. Coach token creation hits a dead end five minutes into any session

- **Evidence**
  - `AccountSecurityView.swift:906-908`:
    ```swift
    } catch let failure as AccountFailure where failure.kind == .reauthenticationRequired {
      fail("Sign in again before creating a coach token.")
    ```
  - The server's `requireFreshMember` (`server/coachRoutes.ts:75-89`) refuses any session created
    more than `FRESH_SESSION_MS` ago.
  - Native sessions last days, so in practice every attempt after the first five minutes fails.
  - The app has no in-place way to "sign in again": the only route is Sign out, then Sign in, then
    the account re-download gate.
  - Sessions already solves the same problem with `StepUpSheet` (password, plus a code when 2FA is
    on).
  - The website shows the same message (`src/components/Account.jsx:711-712`), so this is a parity
    gap, not a native regression.
- **Apple guidance:** HIG Writing says errors should "be clear about what someone can do to fix
  it"; frontend-design says failure needs direction. "Sign in again" points to a flow that does not
  exist on this screen.
  https://developer.apple.com/design/human-interface-guidelines/writing
- **User impact:** the feature is effectively unusable without signing out. That is
  disproportionate, and it pushes the member through the sign-out dialog's local-copy decisions.
- **Fix:** add a server step-up for coach tokens that accepts `password` plus `code` (mirroring
  `revoke-others`, with a test and an `AUTH_ROUTES` entry per repo rules). Then reuse `StepUpSheet`:
  on `.reauthenticationRequired`, set `stepUp = StepUp(action: "create-token", twoFactor:
  failure.twoFactor)` and retry `create()` with the credentials. Until then, the copy should say what
  to do: "Coach tokens need a sign-in from the last 5 minutes. Sign out and sign in again, then
  create the token."

#### M3. Conflict resolution plays a success haptic whatever the result

- **Evidence**
  - `SyncDetailsView.swift:71-76` and `:109-115`:
    ```swift
    await model.resolveConflictKeepingLocal()
    working = false
    model.accountSucceeded()
    ```
  - Both `resolveConflictKeepingLocal()` and `resolveConflictUsingAccount()` return `Void`
    (`AppModel+Account.swift:492-506`), even though `sync.resolve…` produces a `SyncStatus` that can
    be `.failed`, `.conflict` or `.waiting`.
- **Rule:** repo `CLAUDE.md`: "Call `model.haptic(_:)` after the confirmed change has saved." HIG
  Playing haptics says to use feedback consistently with what actually happened.
  https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- **User impact:** after a failed overwrite of the account copy, the member feels "success". This is
  the riskiest data operation in the slice.
- **Fix:** return the `SyncStatus` from both model methods, then branch:
  ```swift
  let status = await model.resolveConflictKeepingLocal()
  switch status {
  case .idle: model.accountSucceeded()
  case .waiting: model.haptic(.accountWarning)
  default: model.haptic(.accountFailure)
  }
  ```
  Also show the status's detail inline; today only the header label changes.

#### M4. The password reveal control swaps the field's identity (**device**)

- **Evidence**
  - `AccountSupport.swift:245-253`:
    ```swift
    Group {
      if revealed { TextField(title, text: $text) … } else { SecureField(title, text: $text) }
    }.textContentType(contentType)
    ```
  - Callers apply `.focused($focus, equals: .password)` to the whole `HStack`
    (`AuthFlowView.swift:186`, `AccountSecurityView.swift:86`).
- **Effect:** toggling destroys the focused `SecureField` and inserts a new `TextField`. The
  expected (unconfirmed) results:
  - the keyboard drops or loses focus on each tap of the eye;
  - the caret resets;
  - while revealed, a `.newPassword` field is no longer secure text entry, which may suppress the
    strong-password suggestion. Apple notes `passwordRules` and strong passwords apply to
    secure-entry fields:
    https://developer.apple.com/documentation/security/about-the-password-autofill-workflow
  - It is also unconfirmed whether `.focused` on a container reliably binds the inner field on iOS
    17.
- **Apple guidance:** HIG Text fields: "Always use a secure text field when your app asks for
  sensitive data, such as a password."
  https://developer.apple.com/design/human-interface-guidelines/text-fields
- **Fix:** keep both fields mounted and move focus between them:
  ```swift
  @FocusState private var inner: Bool?   // true = plain, false = secure
  ZStack {
    SecureField(title, text: $text).opacity(revealed ? 0 : 1).focused($inner, equals: false)
    TextField(title, text: $text).opacity(revealed ? 1 : 0).focused($inner, equals: true)
  }
  // on toggle: let had = inner != nil; revealed.toggle(); if had { inner = revealed }
  ```
  Hide the invisible one with `.accessibilityHidden`. Test on device that AutoFill, the strong
  password offer and paste all survive toggling.

#### M5. Change password validates length and match only on submit, and shows the error under the button

- **Evidence**
  - `AccountSecurityView.swift:68-73`: `missing` checks only that the fields are non-empty.
  - `:130-141`: the length and mismatch checks run in `submit()`, and the message renders in a
    `FormNotice` below the Update button (`:109-112`).
  - The footer shows a character count but never says "too short" or "doesn't match" until the tap.
- **Apple guidance**
  - HIG Text fields: "when creating a user name or password, validation needs to happen before
    people switch to another field."
  - HIG Writing: "display it as close to the problem as possible."
  - Sources:
    - https://developer.apple.com/design/human-interface-guidelines/text-fields
    - https://developer.apple.com/design/human-interface-guidelines/writing
- **User impact:** the button looks ready, the member taps, and only then sees an error under the
  button, away from the field that caused it. The sign-up form already does this better.
- **Fix:** fold both rules into `missing`, so the button stays disabled with a stated reason, as
  sign-up does:
  ```swift
  if new.count < 15 { return "Your new password needs 15 characters or more. You have \(new.count)." }
  if confirm != new { return "The new passwords don't match yet." }
  ```
  Show the mismatch in the section footer once `confirm` is non-empty.

#### M6. The account loading/unavailable gate cannot scroll (**device**)

- **Evidence**
  - `AccountSection.swift:225-260`: `VStack(spacing: 24) { … }.padding()` with no `ScrollView`.
  - The slow branch stacks a 64 pt mark, a `ProgressView` label, a 30-word paragraph, Try again,
    the error notice and Sign out.
  - This view replaces the tabs (comment at `:214`), so it is the whole screen.
- **Apple guidance:** HIG Accessibility: "Support larger text sizes … enlarge text by at least 200
  percent." HIG Typography recommends layouts that adapt at large sizes rather than clipping.
  https://developer.apple.com/design/human-interface-guidelines/accessibility
- **User impact:** at accessibility text sizes on a small iPhone, Retry and Sign out can be pushed
  off-screen. Those are the only exits from this state.
- **Fix:** wrap the content in
  `ScrollView { VStack … .frame(maxWidth: .infinity, minHeight: geometry.size.height) }`, or use
  `ViewThatFits(in: .vertical)` with a scrolling fallback. Check on device at AX5.

#### M7. A raw `withAnimation` bypasses `FormaMotion`

- **Evidence:** `AccountSecurityView.swift:841`:
  `withAnimation { proxy.scrollTo("issued-token", anchor: .top) }`. It is the only raw
  `withAnimation` in `Account/`. `AuthFlowView.swift:143` uses
  `withFormaAnimation(motion, FormaMotion.reveal)` correctly.
- **Rule:** repo `CLAUDE.md`: "All motion goes through `FormaMotion.swift`." HIG Motion and
  Accessibility say to honour Reduce Motion.
  https://developer.apple.com/design/human-interface-guidelines/motion
- **User impact:** members with Reduce Motion, or FORMA motion set to Off, still get an animated
  spatial scroll.
- **Fix:** add `@Environment(\.formaMotion) private var motion` and use
  `withFormaAnimation(motion, FormaMotion.reveal) { proxy.scrollTo("issued-token", anchor: .top) }`.

### LOW

**L1. `Text + Text` is deprecated in the iOS 26 SDK.**
- **Evidence:** `AuthFlowView.swift:274` and `:281`:
  `Text("New to FORMA? ") + Text("Create account").bold()`.
- **Source:** the iPhoneOS 27.2 `SwiftUICore.swiftinterface` declares
  `@available(iOS, introduced: 13.0, deprecated: 26.0, message: "Use string interpolation on Text instead")`.
- **Impact:** with the iOS 17 floor there is no warning today; it will warn when the floor rises.
- **Fix:** `Text("New to FORMA? \(Text("Create account").bold())")`. Text interpolation works on
  iOS 17.

**L2. "We" in errors and notices.**
- **Evidence:** for example, "We couldn't send the verification email." (`AuthFlowView.swift:379,505`),
  "We couldn't complete that request." (`AccountWire.swift:401-404`) and "We sent a request…"
  (`AccountProfileView.swift:130`).
- **Apple guidance:** HIG Writing: "Avoid using we altogether … particularly problematic in error
  messages." https://developer.apple.com/design/human-interface-guidelines/writing
- **Note:** this mirrors the website by design, so changing it means changing both.
- **Fix:** for example, "Verification email not sent. Check your connection and try again."

**L3. Action names drift within one flow.**
- **Sessions:** the row button says "Revoke" (`AccountSecurityView.swift:515`), the dialog says
  "Sign out this device" (`:561`), and step-up says "Confirm and sign out device" (`:693`).
- **Deletion:** the red "Delete account" button (`AccountPrivacyView.swift:221`) actually sends an
  email, and the result reads "Confirmation email sent".
- **Guidance:** frontend-design ("An action keeps the same name through the whole flow"); HIG
  Writing ("use consistent language throughout processes with multiple steps").
- **Fix:** use "Sign out" for sessions everywhere. Title the deletion button
  "Email deletion link" (or "Request deletion"), keeping it red.

**L4. VoiceOver reads secrets as words.**
- **Evidence:** the setup key (`AccountSecurityView.swift:314`), recovery codes (`:360`) and coach
  token (`:761`).
- **Fix:** add `.speechSpellsOutCharacters()` (present in the SDK interface) so VoiceOver users can
  transcribe them. Copy already works.

**L5. All-caps eyebrows and status.**
- **Evidence:** `"FORMA MEMBER ACCESS"` and `"TWO-STEP VERIFICATION"` with `.tracking(2)`
  (`AuthFlowView.swift:154,390`), and `model.syncDisplay?.title.uppercased()`
  (`AccountPrivacyView.swift:20`).
- **Impact:** decorative template chrome by frontend-design's criteria, and extra VoiceOver noise
  before the real header.
- **Fix:** drop them, or mark the eyebrows `.accessibilityHidden(true)`. Show the status in sentence
  case.

**L6. Session row icons are inconsistent and noisy.**
- **Evidence:** `AccountSecurityView.swift:499-503` chooses `iphone` only when the user agent
  contains `CFNetwork`. `DeviceDescription` (`AccountSupport.swift:113`) also treats a `FORMA…`
  prefix as the app, so the two disagree. Safari on iPhone gets `desktopcomputer`.
- **VoiceOver:** the image is not hidden inside the combined element, so VoiceOver says "desktop
  computer".
- **Fix:** derive the symbol from the same parse as the label, and add `.accessibilityHidden(true)`.

**L7. Long confirmation-dialog messages.**
- **Evidence:** `AccountSection.swift:98-100` (about 50 words) and `AccountPrivacyView.swift:113-122`
  (up to about 60 words).
- **Apple guidance:** HIG Alerts: "avoid displaying an alert that scrolls … including a brief
  message only when necessary." https://developer.apple.com/design/human-interface-guidelines/alerts
- **Fix:** keep one sentence in the dialog and move the rest into the section footer, which already
  explains it.

**L8. Deletion sheet: the reason for a disabled button is voice-only, and the phrase match is strict.**
- **Evidence:** `AccountPrivacyView.swift:155,226-229`. `phrase == "DELETE"` with no trimming, and
  the "Type DELETE first" reason exists only as an accessibility hint.
- **Fix:** show the reason visibly, as `AuthFlowView.swift:259-262` does. Compare against
  `phrase.trimmingCharacters(in: .whitespaces)`.
- **Context:** the flow otherwise matches the website exactly
  (`src/components/Account.jsx:2628-2662`), which the HIG asks for: "Provide a consistent
  account-deletion experience".

**L9. Some actions show no progress.**
- **Evidence:** "Sign out everywhere" sets `acting` but shows no spinner
  (`AccountSecurityView.swift:530,609-619`). StepUpSheet's confirm (`:692-699`) and the 2FA confirm
  sheet (`:270-277`) also have none. Neither sheet sets `interactiveDismissDisabled(working)`.
- **Fix:** add `ProgressView` like the other buttons, and disable dismissal while working.

**L10. The 2FA confirm sheet is cramped.**
- **Evidence:** `.presentationDetents([.medium])` only (`AccountSecurityView.swift:289,707`), and
  the 2FA sheet sets no initial focus (StepUpSheet does, `:705`).
- **Impact:** with the keyboard up at large text sizes, the confirm button may need scrolling
  (**device**).
- **Fix:** use `[.medium, .large]` and `.onAppear { sheetFocused = true }`.

**L11. Sign-in methods: new HIG evidence for an open owner decision.**
- **Apple guidance:** HIG Managing accounts: "If you don't use Sign in with Apple … prefer using a
  passkey … If you need to continue using passwords for authentication, augment security by
  requiring two-factor authentication." FORMA's 2FA is optional.
  https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- **Status:** not a defect and not an App Review requirement for email and password (4.8 only
  applies with third-party login). Recorded for the owner's open decision in
  `native-accounts-findings.md`.

**L12. Placeholder-only labels.**
- **Evidence:** every account field uses its title as a placeholder, for example
  "Type DELETE to confirm" (`AccountPrivacyView.swift:203`) and "Token name, e.g. Claude coach"
  (`AccountSecurityView.swift:775`).
- **Apple guidance:** HIG Text fields: "Because placeholder text disappears when people start
  typing, it can also be useful to include a separate label." The repo's own
  `apple-design-2026.md:157` commits to "persistent explanatory labels".
- **Fix:** for multi-field forms, use `LabeledContent("Token name") { TextField("e.g. Claude coach", text: $label) }`
  or a persistent caption above the field.

**L13. Small consistency items.**
- **Date formats:** the deletion-pending time uses device locale and time zone
  (`AccountPrivacyView.swift:124-126`), while every other account date is Sydney `en_AU`
  (`AccountDates`).
- **Stale footer:** the TwoFactor footer says "Add an authenticator app as a second layer." even
  when 2FA is on (`AccountSecurityView.swift:201`), and its sheet title is just "Turn off" (`:280`).
- **Cancel wording:** the auth sheet's cancel is "Not now" (`AuthFlowView.swift:54`); HIG Sheets
  names Cancel or Close.
- **No reason on disabled button:** `PhoneTrainingReview`'s disabled replace button gives no reason
  (`TrainingDataView.swift:217-223`).
- **No retry:** `.unavailable` phone-training has no retry (`TrainingDataView.swift:73-74`).

---

## 3. Already correct (keep)

- **Disabled until ready, with a reason.** The sign-up and sign-in submit stays disabled until the
  form is complete, and states why in visible text and in the VoiceOver hint
  (`AuthFlowView.swift:93-116,251-262`). This matches HIG Entering data: "make the button available
  only after people enter the data you require."
- **Validation timing.** Email is validated when the field loses focus (`emailTouched`,
  `AuthFlowView.swift:120-125,299-301`), and the sign-up password count is live. Both match the HIG
  Text fields timing guidance.
- **Error announcements.** `FormNotice` announces errors and successes and re-announces a repeat via
  `revision`. Error copy is specific and says how to fix the problem
  (`AccountWire.swift:383-407`, `AuthFlowView.swift:108`).
- **Password kept on a dropped connection.** A failed connection keeps the typed passphrase; only a
  rejection clears it (`AuthFlowView.swift:361-363`).
- **One-time codes.** The two-step code uses `.oneTimeCode` with the number pad and submits itself at
  six digits, because the number pad has no return key. Recovery codes switch to an ASCII keyboard
  with no content type.
- **Account deletion meets 5.1.1(v)** and Apple's "Offering account deletion" page:
  - It can be started in the app, under You → Account → Privacy & account.
  - Password plus DELETE plus an email link. Apple explicitly allows "entering a code from an email…
    already associated with the account".
  - The consequences are listed, and the 35-day backup removal is stated.
  - A pending state is shown, and a completion notice appears after the session ends
    (`AccountModel.swift:429-430`).
  - Sources:
    - https://developer.apple.com/support/offering-account-deletion-in-your-app/
    - https://developer.apple.com/app-store/review/guidelines/#5.1.1
- **Destructive confirmations.**
  - They use `confirmationDialog` with specific verb titles and the system Cancel.
  - Sign out gives a non-destructive and a destructive choice.
  - Reload cloud data needs an acknowledgement checkbox plus an offered export first.
  - Phone import needs a saved copy, an acknowledgement and a confirmation.
- **Secrets.**
  - Shown once and cleared on disappear (`AccountSecurityView.swift:291-297,852`).
  - Copied local-only with a 2-minute expiry, and the copy button says so
    (`AccountSupport.swift:170-207`).
  - Recovery codes can be shared.
- **Tap targets.** The reveal button is 44×44 with a label ("Show password"/"Hide password"). Revoke
  buttons are at least 44 pt with labels that name what they revoke. `SubmitButton` is 56 pt and says
  "working" to VoiceOver.
- **Large text.** `AdaptiveRow` stacks rows at accessibility sizes. `resendRow` uses `ViewThatFits`.
  Fonts are all Dynamic Type text styles.
- **Sheet dismissal.** `interactiveDismissDisabled(account.busy)` on the auth sheet and on the
  deletion sheet while working.
- **Privacy-first defaults.**
  - Accounts are optional, and the signed-out footer says FORMA works without one. This matches HIG
    Managing accounts: "Delay sign-in for as long as possible."
  - Consent checkboxes are separate and unticked, and link to the Terms and Privacy pages.
- **No deprecated API** found in this slice other than L1. iOS 17 APIs (`onChange` with two
  parameters, `ContentUnavailableView`, `AccessibilityNotification`) are within the deployment
  floor.

## Limits

This is static only. AutoFill behaviour, keyboard and focus transitions, VoiceOver order, AX5 layout
and contrast were not observed on a device or simulator. Items marked **device** need the owner to
check them on the iPhone. Apple HIG pages were read through the developer.apple.com HIG JSON
endpoint; the account-deletion support page and App Review Guidelines were fetched live on
2 November 2026.
