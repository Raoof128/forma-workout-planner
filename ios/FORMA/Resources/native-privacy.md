# Privacy on this iPhone

Development notice · 28 October 2026

This native FORMA build is a workout planner that works on its own and can
optionally sign in to a FORMA account. Without an account it keeps your training
on the iPhone. With one, your name, email address and workout records are also
sent to, and stored in, that account so they match the FORMA website. The same
bundled notice is shown in the app (You, Privacy & your data).

## Without an account

Your routines, sets, workout history, notes, display name and training
preferences are stored in the app's local workspace. Using FORMA without an
account sends nothing about your training anywhere. The app includes no
advertising, tracking or analytics SDK and requests no location, camera,
microphone, contacts or photo-library permission. Exercise search runs on the
device.

## With a FORMA account

Signing in is optional and uses the same account as the FORMA website. When you
create an account or sign in, the app sends FORMA's account service:

- your email address, display name and password (to sign you in; the password is
  never stored on the iPhone);
- then your workout records: routines, workouts, sets, notes, profile and
  preferences. These may include health-related information, which you consent to
  when you create the account.

They travel over an encrypted HTTPS connection (the app allows no insecure
connections) to a service operated by Raouf Abedini and hosted with Cloudflare and
DigitalOcean, which may process them outside Australia, mainly in the United
States. FORMA uses them to provide your account and to send essential account
emails. There is no advertising, tracking or analytics, signed in or not.

### Your session on this iPhone

While you are signed in, the app keeps your FORMA session cookies in the iPhone
Keychain, readable only on this device after first unlock. They are not included
in device backups, are not shared with other apps, and are deleted when you sign
out or the session ends (at most 30 days after you sign in). The account appears
in the website's list of active sessions, where you can end it, and under
Security in the app.

### Syncing and the saved copy

Each change is saved on the iPhone first and then sent to your account. Changes
made offline wait and send later. While signed in, the app keeps a saved copy of
your account's training in its own storage so it works offline, in a separate file
for each account on a shared iPhone.

Signing out leaves that copy on the iPhone, with any changes not yet sent, ready
for your next sign-in. "Sign out and remove from this iPhone" deletes it (offered
when nothing is waiting to be sent). Deleting the app removes it too.

If the account changes somewhere else while the iPhone holds unsent changes, the
app does not choose for you: you can export your unsent changes and reload the
account's copy, or keep this iPhone's copy.

### Bringing the training from this iPhone

Training recorded on this iPhone before signing in is never merged into an account
automatically. "Bring your phone training" shows the counts, asks you to save a
copy of your account's current data first and to confirm, and then replaces your
account's training with this iPhone's, as the website's import does. FORMA
remembers on this iPhone which account did this, so the same training is not
offered to a second account.

### Deleting your account

You can request account deletion in the app (You, Account, Privacy & account).
FORMA emails a confirmation link, and your account and active workout data are
removed when you confirm. Operational backups follow the service retention
schedule. Deleting your account does not delete exported files, or the training
recorded on this iPhone without an account.

## Apple Watch and Apple Health

If you start a workout on Apple Watch, FORMA asks for Apple Health permission to
save workouts and to read and save heart rate and active energy. The Watch
records them during the workout and saves the workout to Apple Health when it
ends. Your iPhone shows the live values but keeps them out of your FORMA records
and exports, and FORMA does not send them anywhere, with or without an account.
Manage these permissions in the Health app. Training without a Watch needs no
Health permission. Bundled exercise guides retain their source and licence
information.

## Training widgets

Widget sharing starts off for each training space. Enable it in You to share a
small read-only snapshot with FORMA’s own widget extension: next routine name
and identifier, exercise count and estimated time, saved active set counts, and
weekly workout totals and trained days. The main database stays private. The
snapshot contains no email, credentials, notes, full history or Health readings.
It uses complete file protection and is excluded from backups. Widget content
hides while locked and does not mirror to Mac. System scheduling means cached
widgets can take time to refresh after reset, account switching or revocation.
Remove the widget if immediate withdrawal from the screen is needed. Widget
links open the app; they do not log sets or start Health recordings.

## Local protection

The workspace uses the iPhone's file protection and is excluded from automatic
device backup by the app. This is not a claim of end-to-end encryption or a
guarantee against access on an unlocked or compromised device. Deleting the app,
losing the device or resetting local training data can remove the only copy of
training recorded without an account. Export a backup if you want to keep a
separate copy.

Export is an action you choose. A backup may contain all your training records
and notes. The Files or sharing destination you select may copy it to iCloud,
another cloud provider or another person. Their handling of that copy is outside
FORMA's control. Signing out, deleting your account or resetting FORMA does not
delete exported files.

Opening an external support, source or legal link connects to the relevant
website or email application, which may process ordinary network or contact
information. FORMA does not automatically attach your workout data. Please avoid
including medical details in support messages unless you intend to share them.

## Policies and contact

The FORMA website's Privacy Policy and Terms of Use also govern your account.
FORMA is operated by Raouf Abedini in Sydney, New South Wales, Australia. For
privacy questions, contact raoof.r12@gmail.com. This development notice needs
legal review and final-binary verification before App Store distribution.
