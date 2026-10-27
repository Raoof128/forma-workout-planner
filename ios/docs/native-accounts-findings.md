# Native sign-up and log-in: findings (2026-10-27)

Goal from the owner: one FORMA account that works on the website and in the
iOS app. This note records what exists today and what a native sign-in has to
satisfy. Nothing was built yet. It is the starting point for that work, not a
design.

## What exists

- **Web accounts are live in production** (`forma.raoufabedini.dev`,
  account mode since 13 Oct 2026; see `docs/accounts/production-launch.md`).
  The `AGENT.md` line saying production must stay guest-only predates that
  launch.
- **Auth:** better-auth with email and password, required email
  verification, and optional TOTP two-factor with backup codes
  (`server/auth.ts`). There is no OAuth, passkey, magic link or Sign in with
  Apple.
- **Sessions are browser-only:**
  - Sessions use HttpOnly `forma.` cookies, with a 7-day session refreshed
    daily and a 30-day absolute limit.
  - Requests carry an `X-Forma-Member` HMAC binding.
  - The proxy strips session tokens from auth responses
    (`server/app.ts:169-171`).
  - The Worker and the server both require `Origin === APP_ORIGIN` on every
    write, sign-in included (`worker/index.ts:371-387`,
    `server/app.ts:535-548`).
- **Sync:**
  - Each member has one JSONB workspace with a server-assigned revision
    (`GET`/`PUT /api/workspace`).
  - A `PUT` with a stale `expectedRevision` gets 409 `stale_revision` plus the
    latest copy.
  - An `operationId` makes a `PUT` idempotent for 30 days.
  - The shape matches the iOS `Workspace` v2 model.
- **The only bearer API is coach tokens** (`forma_coach_…`). The iOS review
  docs say native accounts must not reuse them
  (`ios/docs/app-review-matrix.md:44`).
- **The iOS app has no networking, keychain, auth or sync code.** Its privacy
  notice, privacy manifest and review docs state that the app is offline-only
  (`ios/FORMA/Resources/native-privacy.md`, `ios/docs/privacy-inventory.md`).

## What native sign-in must satisfy

1. **A new bearer-token route family for native clients.** It must not
   relax the browser's Origin check or fake an Origin header. It needs a
   Worker allowlist entry, a security review and tests. The Worker's Access
   credentials must never ship in the app.
2. **Session parity with the web:**
   - email verification;
   - TOTP two-factor challenge;
   - the 30-day absolute expiry;
   - server-side revocation that appears in the web's sessions list;
   - tokens stored in the Keychain.
3. **Sync on top of local-first storage:**
   - a separate server base revision;
   - a durable `operationId` queue that survives restarts;
   - explicit handling of 409 conflicts;
   - an explicit, member-bound import of existing on-device data, never an
     automatic merge into the wrong account.
4. **App Store rules:**
   - account deletion inside the app (5.1.1(v));
   - if any third-party login is ever added, Sign in with Apple as well
     (4.8). Email and password alone do not trigger 4.8.
5. **Privacy:**
   - synced workouts become linked Fitness data;
   - express in-app consent (as the web's sign-up checkbox does);
   - an updated privacy manifest, App Privacy answers and the native privacy
     notice.
6. **Rollout:** production has real members. Build and test against staging
   (`forma-staging`), and change production only with the owner's go-ahead.

## Open decisions for the owner

- **Sign-in methods:** email and password only (parity with the web), or
  also Sign in with Apple and passkeys?
- **Workout data:** full sync of workouts between devices, or the account
  only (sign-in, profile, deletion) at first?
- **Existing data:** what happens to workouts already on the phone when
  someone signs in to an account that already has data: import, keep
  separate, or ask?
