// Signing out disposes the cloud repository and with it any edit that has not
// reached the server yet (a save in flight, a failed save waiting for retry,
// or a conflict). Every sign-out entry point asks before discarding them.
export const UNSYNCED_SIGN_OUT =
  "Some training changes have not reached the cloud yet, and signing out removes them from this browser. Choose Cancel to keep them: use Retry sync on the Account page, or, after a conflict, export your unsynced changes.";

export function confirmUnsyncedSignOut(unsynced, confirm = window.confirm) {
  return !unsynced || confirm(`${UNSYNCED_SIGN_OUT} Sign out anyway?`);
}
