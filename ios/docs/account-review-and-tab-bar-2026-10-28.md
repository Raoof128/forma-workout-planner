# Native account review and animated tab bar

28 October 2026 (Australia/Sydney). Worktree: `worktrees/ios-app`, branch
`feat/native-accounts`. This completes a local review of the previous builder's
uncommitted app layer; it does not publish the app or deploy the account service.

## Account fixes

- **Download versus local edit.** A returning member could edit their cached
  training while the sign-in download was in flight. The old unconditional
  replacement discarded that edit. The full fetch now uses the refresh path's
  transaction-time clean check: upload the edit if the account is unchanged,
  or offer a conflict if both copies changed. Both regression tests failed
  before the fix.
- **Late authentication replies.** A delayed reply could restore a signed-out
  cookie, replace the next member's cookie, or resurrect the old profile. Request
  generations and cookie-jar snapshots reject those replies. A retained sync
  transport is refused before sending if its member no longer matches. Four
  hosted app tests reproduced these failures before the fix.
- **Sync shutdown.** Leaving a member store terminates the old engine, closes
  its status stream and drains queued store operations. A late acknowledgement
  keeps its durable operation for an idempotent retry at the next sign-in.
- **Store switches and sign-out.** Queued edits are pinned to their original
  owner. Sign-out checks durable dirty/pending metadata rather than trusting a
  lagging status label, and checks again after draining commits before removing
  a member cache. Both regressions failed before their fixes.
- **Environment isolation.** Staging and other development origins get separate
  Keychain identities, install markers, member caches and phone-import ledgers.
  The original production paths are preserved for existing installs.
- **Staging Access.** Debug builds accept the two staging Access credentials
  from the launch environment, restricted to the exact staging origin. Release
  builds exclude that code. No credential is stored in source or resources.

The guest store remains separate. Account service calls retain native headers,
HTTPS, redirect refusal, explicit import review and local-first persistence.

## Tab bar design

The owner selected a SwiftUI Liquid Glass bar with animated icons and scroll
collapse, after being told that the system tab label does not expose custom
SF Symbol effects. `TabView` and each tab's `NavigationStack` still own the
screen and navigation history. The system bar is hidden on the tab contents;
the app's four named buttons expose selected state and tab position.

- The selected icon bounces once; a capsule highlight follows the selection.
- Scrolling down collapses the bar to the current tab and an expand control.
  Scrolling back up, returning to the top, tapping expand or selecting a tab
  restores it. Thresholds are app design choices, not Apple recommendations.
- The expanded height remains reserved during collapse, preventing a change to
  the scroll viewport from feeding back into the collapse gesture.
- Only the four root scroll views drive collapse. Editors and workout controls
  retain their normal behavior. The workout resume control remains reachable.
- Minimal/Off motion, Reduce Motion, Prefer Cross-Fade Transitions, VoiceOver
  and accessibility text sizes retain expanded navigation without icon bounce.
  Reduce Transparency and increased contrast use an opaque control surface.
- Liquid Glass requires iOS 26. Scroll geometry requires iOS 18. iOS 17 keeps
  the expanded material bar. The deployment floor stays iOS 17.

## Apple documentation checked in 2026

| Source                                                                                                                           | Use                                                                                            |
| -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [What's new in SwiftUI, WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)                                           | Refreshed system Liquid Glass and current platform direction. This is the actual 2026 session. |
| [Tab bar minimization](<https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)>)                      | Reference behavior for scroll collapse. The custom bar owns its equivalent interaction.        |
| [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) | Public `glassEffect` material on the app-owned control surface.                                |
| [Symbol effects](https://developer.apple.com/documentation/symbols/symboleffect)                                                 | Discrete bounce on app-owned symbols.                                                          |
| [Toolbar visibility](<https://developer.apple.com/documentation/swiftui/view/toolbar(_:for:)>)                                   | Hide the system tab bar from inside each tab container.                                        |
| [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)                                               | Stable destinations and accessible navigation labels.                                          |

API availability was also checked in the installed Xcode 27.1 SDK interfaces.
The older WWDC25 design session remains relevant background; it is not relabeled
as a 2026 session.

## Verification and remaining boundaries

| Check                                     | Result                                                                                                                                                                                                                                                              |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Swift package                             | 138/138 pass.                                                                                                                                                                                                                                                       |
| Hosted app tests, ad-hoc signed simulator | 13/13 pass, including real Keychain origin isolation and mocked sign-in → download → upload → sign-out → guest restoration.                                                                                                                                         |
| UI journeys                               | The full run passed 15/16; the consent test was repaired for the system password suggestion and keyboard/scroll geometry. Its final three-case account UI rerun passed 3/3. All 16 journeys have passing coverage; this is not a claim of a single final 16/16 run. |
| JavaScript unit tests / Worker tests      | 151/151 and 35/35 pass.                                                                                                                                                                                                                                             |
| Resources                                 | Deterministic check and all 14 resource tests pass.                                                                                                                                                                                                                 |
| Static checks                             | ESLint, TypeScript, Prettier, documentation, Swift formatting and whitespace checks pass.                                                                                                                                                                           |
| Secret review                             | Added/changed-line scan: zero findings. A full-file scan also identified three pre-existing historical prose matches; the synthetic enrollment fixture was rewritten to avoid a misleading match, without a scanner exception.                                      |
| Device build                              | Signed Release iPhone + embedded Watch build passes; signature verifies. Only the routine App Intents metadata message is emitted.                                                                                                                                  |
| iPhone                                    | Updated build installed and launched; installed bundle queried successfully.                                                                                                                                                                                        |
| Apple Watch                               | Not installed: the Watch rejects the Mac connection with CoreDevice 4000 / RemotePairing 1035. Xcode recommends connecting the companion phone by USB to repair pairing.                                                                                            |

The owner later authorized live tests on **both staging and production** using
local `.env` credentials. No real account or member training was changed. The
staging session GET returned an Access login redirect; anonymous native sign-in
validation probes returned HTTP 403 on both hosts. The home `.env` destination
token was rejected with HTTP 401, and the other token could not see FORMA's
Access applications. No project credential file was found. Live sign-up, email
verification, account revocation and website-to-device sync remain blocked on
usable FORMA access credentials; these are not counted as passes.

No backend deployment, push, App Store submission or publication occurred.
The iOS 17 runtime, on-device VoiceOver, largest text sizes, transparency/contrast
settings and Instruments were not exercised in this run; their code paths are
not relabeled as device verification. A recorded simulator navigation journey
passed again while capturing the icon animation and collapse/expand behavior.
Physical Watch sensing,
mirroring, reconnection and Health workout deduplication require paired hardware.

## Run locally

From the repository root:

```sh
swift test --package-path ios
node scripts/build-ios-resources.mjs --check
node --test unit/ios-resources.test.js
cd ios
xcodegen generate
xcodebuild test -project FORMA.xcodeproj -scheme FORMA \
  -destination 'platform=iOS Simulator,name=FORMA Review' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=3L5A4R7JNY
```

For an authorized staging account test, build with
`FORMA_ACCOUNT_ORIGIN=https://forma-staging.raoufabedini.dev`; supply
`FORMA_STAGING_ACCESS_ID` and `FORMA_STAGING_ACCESS_SECRET` only to the Debug
app's launch environment. No service credential belongs in a project setting.
