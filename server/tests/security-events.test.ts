import assert from "node:assert/strict";
import { test } from "node:test";
import { securityEvent } from "../securityEvents.js";

test("security events classify failures without retaining URLs or client identities", () => {
  const event = securityEvent(
    "/api/auth/sign-in/email?token=private",
    401,
    "client-ip",
    "secret-key",
  );
  assert.equal(event?.event, "sign_in_failure");
  assert.match(event?.actor ?? "", /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(event).includes("private"), false);
  assert.equal(JSON.stringify(event).includes("client-ip"), false);
  assert.equal(securityEvent("/api/auth/get-session", 401, "a", "s"), null);
  assert.equal(securityEvent("/api/workspace", 200, "a", "s"), null);
});

test("locks and stale-member conflicts produce distinct monitor signals", () => {
  assert.equal(
    securityEvent("/api/auth/sign-in/email", 429, "a", "s")?.event,
    "sign_in_lockout",
  );
  assert.equal(
    securityEvent("/api/auth/two-factor/verify-totp", 429, "a", "s")?.event,
    "mfa_lockout",
  );
  assert.equal(
    securityEvent("/api/workspace", 409, "a", "s", "account_changed")?.event,
    "account_changed",
  );
  assert.notEqual(
    securityEvent("/api/workspace", 409, "b", "s", "account_changed")?.actor,
    securityEvent("/api/workspace", 409, "a", "s", "account_changed")?.actor,
  );
  assert.equal(
    securityEvent("/api/workspace", 409, "a", "s", "revision_conflict"),
    null,
  );
});
