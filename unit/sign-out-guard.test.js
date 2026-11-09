import test from "node:test";
import assert from "node:assert/strict";
import { confirmUnsyncedSignOut } from "../src/account/signOutGuard.js";

test("sign-out asks only while edits have not reached the cloud", () => {
  const asked = [];
  const confirm = (message) => {
    asked.push(message);
    return false;
  };
  assert.equal(confirmUnsyncedSignOut(false, confirm), true);
  assert.deepEqual(asked, []);
  assert.equal(confirmUnsyncedSignOut(true, confirm), false);
  assert.match(asked[0], /not reached the cloud/);
  assert.equal(
    confirmUnsyncedSignOut(true, () => true),
    true,
  );
});
