# Native FORMA accounts: sign-up, log-in and workout sync on iOS

Date: 2026-10-28. Owner request: "Build native sign-up and log-in with email
and password, same account as the website, with workout sync. Design it
first, test on staging only." Follow-up: "if you cover all the website has to
offer, do a full fetch and proceed to implement."

Background: [native-accounts-findings.md](../../../ios/docs/native-accounts-findings.md).

## Intent

A FORMA member signs in on the iPhone and sees exactly what the website
shows: profile, routines, full workout history and any workout in progress.
Training logged on either side appears on the other. The app keeps working
signed out, offline and on-device, exactly as it does today.

## Goals

1. **One account.** The same email/password account and session rules as the
   website: verification, password reset, TOTP two-step with backup codes,
   the 30-day absolute session limit and revocation from the sessions list.
2. **Account parity with the website**, in native screens: sign up, sign in,
   two-step challenge, resend verification, forgot password, profile name,
   change email, change password, two-step on/off and backup codes, active
   sessions (list, revoke one, revoke others), coach access tokens (list,
   create, revoke), export, import of phone training, sign out and delete
   account.
3. **Full fetch on sign-in.** After signing in, the app loads the account's
   whole workspace and shows it.
4. **Sync.** Every local change is saved on the phone first and then sent to
   the account. Offline changes wait and send later. Changes from the website
   arrive when the app refreshes.
5. **Phone data handled like the website.** Training recorded on the phone
   before signing in is never mixed in silently. An explicit "Bring your phone
   training" step shows counts, makes the member save a copy of the account
   data first, then replaces the account copy (the website's import
   semantics).

## Non-goals

- Sign in with Apple, passkeys, magic links (owner chose email and password).
- Merging two workspaces. Like the website, an import replaces.
- Production. Everything is built and tested against staging. Production
  needs the owner's go-ahead.
- App Store submission.

## Anti-goals (would be a failure even if it "works")

- Weakening the website's browser protections (Origin and same-site checks,
  HttpOnly cookies) or compiling Cloudflare Access or Worker secrets into the
  app.
- A second account system or token format beside better-auth.
- Silent data loss: an offline edit or a conflicting edit must never be
  dropped without the member choosing it.
- Breaking signed-out use, or making sign-in mandatory.

## Design

### Server and Worker: a narrow "native client" mode

The website's protections assume a browser: every write needs
`Origin === APP_ORIGIN`, and better-auth itself refuses a request that
carries cookies without an Origin. A native app has no Origin.

A request is a **native request** when all of these hold:

- it carries `X-Forma-Client: ios`;
- it has **no** `Origin`, `Referer` or `Sec-Fetch-*` headers.

A browser cannot produce such a request with the member's ambient cookies:

- every cross-origin fetch carries `Origin`;
- a custom header forces a CORS preflight that FORMA never approves;
- forms and navigations cannot set headers;
- every browser request carries `Sec-Fetch-Site`.

This is the same argument the coach-token PATCH exemption already relies on.

For native requests only:

- **Worker** (`worker/index.ts`): forwards `x-forma-client`, and lets a
  native request through the same-origin write rule. Everything else is
  unchanged: route allowlist, body limits, cookie filtering and the
  foreign-Origin refusal.
- **Server** (`server/app.ts`):
  - the `onRequest` Origin rule accepts native requests;
  - the `/api/auth/*` proxy adds `origin: APP_ORIGIN` to the internal request
    it hands to better-auth. The proxy has already established that no
    browser sent it, so it vouches.
  - All other proxy checks run unchanged: the route allowlist, JSON-only
    bodies, safe redirects, password-attempt throttles, `X-Forma-Member`
    binding, fresh-session step-ups and TOTP replay.
- **Sessions are ordinary better-auth cookie sessions.** The app keeps its own
  cookie jar for FORMA cookies, stored in the Keychain, and sends it as a
  `Cookie` header. No new token type and no better-auth plugin. Native
  sessions appear in the website's sessions list and can be revoked there.
- **Security events** log native requests like any other.

Tests cover each rule and its negatives in both the Worker and the server:
a native marker together with an Origin, or with `Sec-Fetch-Site`, is still
refused.

### iOS: account client

- `ios/FORMA/Account/` (new):
  - `AccountClient`: async URLSession over the existing endpoints. The base
    origin is a build setting (`FORMA_ACCOUNT_ORIGIN`, staging for now).
  - `CookieJar`: FORMA cookies only, persisted in the Keychain with
    `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, never in
    `HTTPCookieStorage`.
  - Every request sends `X-Forma-Client: ios`, plus `X-Forma-Member` once
    known.
- **Debug builds only:** Cloudflare Access service-token headers for the
  Access-protected staging site, read at runtime from the launch environment
  (`FORMA_STAGING_ACCESS_ID`, `FORMA_STAGING_ACCESS_SECRET`). They are never
  in source, in the project file or in Release builds.
- **Errors** map to the website's wording (`account_changed`,
  `TOO_MANY_ATTEMPTS`, `reauthentication_required`, `stale_revision` and so
  on).

### iOS: storage and sync (FORMACore, testable with `swift test`)

- **Separate stores:**
  - signed out: the existing guest store, unchanged;
  - signed in: a member cache store per member reference (its own SQLite
    file), so a shared phone never mixes accounts.
- **Sync state** (persisted in the member store):
  - `serverRevision`, the last revision the account acknowledged;
  - at most one `pending` operation: `{operationId, payload,
    expectedRevision}`, written durably before it is sent.
- **Sync engine** (`AccountSync`, pure logic behind a transport protocol):
  - **Local commit:** save locally as today, then mark the workspace dirty.
  - **Flush** (serialised): if there is no pending operation, snapshot the
    local workspace into a new one. Send `PUT /api/workspace` with
    `{data, expectedRevision, operationId}`.
    - On 200: set `serverRevision`, clear the pending operation, and flush
      again if the workspace changed meanwhile.
    - On a network error or 5xx: keep the pending operation and retry later
      with the same `operationId` and payload.
    - On 409 `stale_revision`: enter **conflict**. Keep the local copy and
      show the website's choice ("Training changed on another device…"):
      use the account copy, which replaces local, or keep editing here.
      Keeping local re-sends against the latest revision only after the
      member confirms.
    - On 409 `account_changed` or 401: sign out locally. The member cache
      stays on disk until the member signs in again or removes it.
  - **Refresh:** `GET /api/workspace` on sign-in (the full fetch), on
    returning to the foreground and on pull-to-refresh. A newer server
    revision replaces the local copy only when nothing is pending; otherwise
    it is treated as a conflict.
- The server's `revision` counter is separate from FORMACore's local
  revision; the payload sent is the workspace v2 JSON exactly as the
  contract check produces it.

### iOS: screens

You › Account (new section at the top of You):

- **Signed out:** Sign in and Create account. Create account asks for name,
  email and password (15+ characters) with the website's two consent boxes
  (Terms; storing workout records). After sign-up: "Check your email" with
  resend. Sign in handles the two-step challenge (code or backup code) and
  "Forgot password", which sends the reset email; the reset itself completes
  on the website, as it does today.
- **Signed in:**
  - **Header:** profile with name and email, and sync status (saved / saving /
    offline / conflict).
  - **Sections mirroring the website:**
    - Profile: name, change email.
    - Security: change password, two-step (enable with QR code and secret,
      disable, regenerate backup codes), active sessions, coach access.
    - Training data: bring phone training, export.
    - Privacy and account: cloud storage explanation, sign out, delete
      account.
- Haptics follow the existing `FormaHaptic` map. Motion follows `FormaMotion`.

### Privacy

- Update `ios/FORMA/Resources/native-privacy.md`, the privacy inventory and
  `PrivacyInfo.xcprivacy`: signed in, workout records, the name and the email
  address are linked to the account for app functionality.
- Heart rate from the Watch stays on the device unless it is already part of
  the workspace.

## Testing (staging only)

- **Server** (`npm run test:server`, local PostgreSQL) and **Worker**
  (`npm run test:worker`): native-mode rules and their negatives, plus the
  full existing suites.
- **FORMACore:** sync engine against a fake transport (ack, retry with the
  same operation, conflict, account changed, refresh with and without a
  pending operation), keychain-free.
- **Staging release:** the API image via `docs/qa/holds-timer/api-release.sh
  staging …` and the Worker via `npm run worker:deploy:staging`. Production is
  untouched.
- **End to end on staging** (simulator, Access headers from the launch
  environment) with a disposable member:
  - sign up, verify, sign in, full fetch;
  - log a set and see it on the website;
  - change on the website and see it in the app;
  - offline edit, then reconnect;
  - conflict;
  - import;
  - sessions list shows the iPhone;
  - sign out and delete.

## Left to the builder

Exact SwiftUI layout and copy (match the website's wording), file splits,
retry timing, and whether coach-token creation lives on the iPhone or links
to the website if the screen gets too dense.

## Calls made without the owner (check these)

- **Native mode** is a header marker plus "no browser headers", reusing
  better-auth cookie sessions, rather than the better-auth `bearer` plugin.
  This avoids a second credential type and keeps every existing proxy check
  in force.
- **Import replaces** the account copy, as on the website.
- **Production** stays untouched. The app's account origin is staging until
  the owner approves a production release.
