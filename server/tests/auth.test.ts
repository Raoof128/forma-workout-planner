import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";
import { signJWT } from "better-auth/crypto";
import { createApp } from "../app.js";
import type { AppConfig } from "../config.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";

const { Pool } = pg;
const databaseUrl =
  process.env.AUTH_TEST_DATABASE_URL ?? process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_auth_test_${suffix}`;
const adminPool = databaseUrl
  ? new Pool({ connectionString: databaseUrl })
  : null;
const pool = databaseUrl
  ? new Pool({
      connectionString: databaseUrl,
      options: `-c search_path=${schema}`,
      max: 8,
    })
  : null;
const appOrigin = "http://127.0.0.1:5175";
const workerSecret = `test-worker-secret-${suffix}-long`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `test-auth-secret-${suffix}-long-enough`,
  workerSharedSecret: workerSecret,
  emailFrom: "FORMA <accounts@forma.test>",
  emailSinkEnabled: true,
};
let app: Awaited<ReturnType<typeof createApp>> | undefined;
let requestCounter = 0;

before(async () => {
  if (!databaseUrl || !adminPool || !pool) {
    throw new Error(
      "AUTH_TEST_DATABASE_URL or TEST_DATABASE_URL is required; auth tests require real PostgreSQL.",
    );
  }
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  for (const migrationName of ["0001-auth.sql", "0002-workspace.sql"]) {
    const migration = await readFile(
      join(testDir, "..", "migrations", migrationName),
      "utf8",
    );
    await pool.query(migration);
  }
  app = await createApp({ pool, config });
  await app.ready();
});

after(async () => {
  clearEmailSink();
  if (app) await app.close();
  if (pool) await pool.end();
  if (adminPool) {
    await adminPool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await adminPool.end();
  }
});

function cookieFrom(response: any): string {
  const values = response.headers["set-cookie"];
  assert.ok(
    values,
    "expected Better Auth to set a session or challenge cookie",
  );
  return (Array.isArray(values) ? values : [values])
    .map((value) => value.split(";", 1)[0])
    .join("; ");
}

async function request(
  method: string,
  path: string,
  body?: unknown,
  cookie?: string,
  origin: string | undefined = appOrigin,
  memberOverride?: string | false,
  clientIp = `198.51.100.${(requestCounter++ % 250) + 1}`,
) {
  assert.ok(app);
  const headers: Record<string, string> = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": clientIp,
  };
  if (origin) headers.origin = origin;
  if (body !== undefined) headers["content-type"] = "application/json";
  if (cookie) {
    headers.cookie = cookie;
    const sessionResponse = await app.inject({
      method: "GET",
      url: "/api/auth/get-session",
      headers,
    });
    const sessionJson = sessionResponse.json() as {
      user?: { id?: string };
    } | null;
    if (sessionJson?.user?.id) headers["x-forma-member"] = sessionJson.user.id;
  }
  if (memberOverride === false) delete headers["x-forma-member"];
  else if (typeof memberOverride === "string")
    headers["x-forma-member"] = memberOverride;
  const response = await app.inject({
    method,
    url: path,
    headers,
    ...(body === undefined ? {} : { payload: JSON.stringify(body) }),
  });
  let json: any;
  try {
    json = response.json();
  } catch {
    json = null;
  }
  return { response, json };
}

test("Better Auth account journeys use verified email, secure cookies, protected sessions, MFA, and deletion", async () => {
  assert.ok(pool);
  clearEmailSink();
  const email = `member-${suffix}@example.test`;
  const originalPassword = "a long FORMA passphrase with 15+ characters";
  const newPassword = "another longer and memorable FORMA passphrase";

  const tooShort = await request("POST", "/api/auth/sign-up/email", {
    name: "Member",
    email,
    password: "short",
  });
  assert.ok(tooShort.response.statusCode >= 400);

  const wrongOrigin = await request(
    "POST",
    "/api/auth/sign-up/email",
    { name: "Member", email, password: originalPassword },
    undefined,
    "https://attacker.example",
  );
  assert.equal(wrongOrigin.response.statusCode, 403);

  const missingWorkerIdentity = await app!.inject({
    method: "GET",
    url: "/api/auth/get-session",
    headers: { origin: appOrigin },
  });
  assert.equal(missingWorkerIdentity.statusCode, 401);

  const signup = await request("POST", "/api/auth/sign-up/email", {
    name: "Member",
    email,
    password: originalPassword,
  });
  assert.equal(signup.response.statusCode, 200, signup.response.body);
  assert.equal(signup.json?.token, undefined);
  assert.match(signup.json?.user?.id ?? "", /^mem_/);
  const databaseUser = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  assert.notEqual(signup.json.user.id, databaseUser.rows[0]?.id);
  assert.ok(
    inspectEmailSink().some(
      (item) => item.kind === "verify-email" && item.email === email,
    ),
  );
  const duplicateSignup = await request("POST", "/api/auth/sign-up/email", {
    name: "Another Member",
    email,
    password: originalPassword,
  });
  assert.equal(duplicateSignup.response.statusCode, 200);
  assert.equal(duplicateSignup.json?.user?.email, email);
  assert.equal(duplicateSignup.json?.user?.emailVerified, false);
  assert.match(duplicateSignup.json?.user?.id ?? "", /^mem_/);
  assert.notEqual(duplicateSignup.json?.user?.id, databaseUser.rows[0]?.id);

  const preVerificationSignIn = await request(
    "POST",
    "/api/auth/sign-in/email",
    {
      email,
      password: originalPassword,
    },
  );
  assert.equal(preVerificationSignIn.response.statusCode, 401);
  const unknownSignIn = await request("POST", "/api/auth/sign-in/email", {
    email: `missing-${suffix}@example.test`,
    password: originalPassword,
  });
  assert.equal(unknownSignIn.response.statusCode, 401);
  assert.equal(preVerificationSignIn.json?.code, unknownSignIn.json?.code);
  assert.equal(
    preVerificationSignIn.json?.message,
    unknownSignIn.json?.message,
  );

  const verificationEmail = inspectEmailSink().find(
    (item) => item.kind === "verify-email" && item.email === email,
  );
  assert.ok(verificationEmail);
  const verificationUrl = new URL(verificationEmail.url);
  const expiredVerificationToken = await signJWT(
    { email },
    config.authSecret,
    -1,
  );
  const expiredVerification = await request(
    "GET",
    `/api/auth/verify-email?token=${encodeURIComponent(expiredVerificationToken)}&callbackURL=${encodeURIComponent(`${appOrigin}/account`)}`,
  );
  assert.equal(expiredVerification.response.statusCode, 302);
  assert.match(
    expiredVerification.response.headers.location ?? "",
    /error=TOKEN_EXPIRED/,
  );
  const stillUnverified = await pool.query<{ emailVerified: boolean }>(
    `SELECT "emailVerified" FROM "user" WHERE id = $1`,
    [databaseUser.rows[0]?.id],
  );
  assert.equal(stillUnverified.rows[0]?.emailVerified, false);
  const verified = await request(
    "GET",
    `${verificationUrl.pathname}${verificationUrl.search}`,
  );
  assert.ok(
    [200, 302].includes(verified.response.statusCode),
    verified.response.body,
  );

  const signin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: originalPassword,
  });
  assert.equal(signin.response.statusCode, 200, signin.response.body);
  assert.equal(signin.json?.token, undefined);
  assert.equal(signin.json?.user?.id, signup.json?.user?.id);
  const cookie = cookieFrom(signin.response);
  const setCookies = signin.response.headers["set-cookie"];
  const cookieValues = Array.isArray(setCookies)
    ? setCookies
    : [setCookies ?? ""];
  assert.ok(cookieValues.some((value) => /HttpOnly/i.test(value)));
  assert.ok(cookieValues.some((value) => /SameSite=Lax/i.test(value)));
  assert.ok(
    cookieValues.some((value) => /^forma\.session_token=/i.test(value)),
  );

  const session = await request(
    "GET",
    "/api/auth/get-session",
    undefined,
    cookie,
  );
  assert.equal(session.response.statusCode, 200);
  assert.equal(session.json?.session?.token, undefined);
  assert.equal(session.json?.session?.id, undefined);
  assert.equal(session.json?.user?.id, signup.json?.user?.id);
  assert.equal(session.json?.session?.userId, undefined);

  const unboundUpdate = await request(
    "POST",
    "/api/auth/update-user",
    { name: "Wrong Member" },
    cookie,
    appOrigin,
    false,
  );
  assert.equal(unboundUpdate.response.statusCode, 409);
  assert.equal(unboundUpdate.json?.error, "account_changed");
  const mismatchedUpdate = await request(
    "POST",
    "/api/auth/update-user",
    { name: "Wrong Member" },
    cookie,
    appOrigin,
    "mem_wrong-account",
  );
  assert.equal(mismatchedUpdate.response.statusCode, 409);
  const update = await request(
    "POST",
    "/api/auth/update-user",
    { name: "FORMA Member" },
    cookie,
  );
  assert.equal(update.response.statusCode, 200, update.response.body);
  const updatedSession = await request(
    "GET",
    "/api/auth/get-session",
    undefined,
    cookie,
  );
  assert.equal(updatedSession.json?.user?.name, "FORMA Member");
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() - interval '6 minutes' WHERE "userId" = $1`,
    [databaseUser.rows[0]?.id],
  );
  const staleRawRevoke = await request(
    "POST",
    "/api/auth/revoke-sessions",
    {},
    cookie,
  );
  assert.equal(staleRawRevoke.response.statusCode, 403);
  assert.equal(staleRawRevoke.json?.error, "reauthentication_required");
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() WHERE "userId" = $1`,
    [databaseUser.rows[0]?.id],
  );

  const enroll = await request(
    "POST",
    "/api/auth/two-factor/enable",
    { password: originalPassword },
    cookie,
  );
  assert.equal(enroll.response.statusCode, 200, enroll.response.body);
  assert.ok(enroll.json?.totpURI);
  assert.ok(
    Array.isArray(enroll.json?.backupCodes) &&
      enroll.json.backupCodes.length > 0,
  );
  const provisioning = new URL(enroll.json.totpURI);
  const encodedSecret = provisioning.searchParams.get("secret");
  assert.ok(encodedSecret);
  const secret = new TextDecoder().decode(base32.decode(encodedSecret));
  const verificationCode = await createOTP(secret).totp();
  const verifiedMfa = await request(
    "POST",
    "/api/auth/two-factor/verify-totp",
    { code: verificationCode },
    cookie,
  );
  assert.equal(verifiedMfa.response.statusCode, 200, verifiedMfa.response.body);
  const mfaCookie = cookieFrom(verifiedMfa.response);
  const mfaEnabled = await pool.query<{ twoFactorEnabled: boolean }>(
    `SELECT "twoFactorEnabled" FROM "user" WHERE email = $1`,
    [email],
  );
  assert.equal(mfaEnabled.rows[0]?.twoFactorEnabled, true);
  const expiredSessionSignIn = await request(
    "POST",
    "/api/auth/sign-in/email",
    {
      email,
      password: originalPassword,
    },
  );
  const expiredSessionChallenge = cookieFrom(expiredSessionSignIn.response);
  const expiredSessionMfa = await request(
    "POST",
    "/api/auth/two-factor/verify-backup-code",
    { code: enroll.json.backupCodes[1] },
    expiredSessionChallenge,
  );
  assert.equal(
    expiredSessionMfa.response.statusCode,
    200,
    expiredSessionMfa.response.body,
  );
  const expiredSessionCookie = cookieFrom(expiredSessionMfa.response);
  const newestSession = await pool.query<{ id: string }>(
    `SELECT id FROM "session" WHERE "userId" = $1 ORDER BY "createdAt" DESC LIMIT 1`,
    [databaseUser.rows[0]?.id],
  );
  assert.ok(newestSession.rows[0]?.id);
  await pool.query(
    `UPDATE "session" SET "expiresAt" = now() - interval '1 second' WHERE id = $1`,
    [newestSession.rows[0]?.id],
  );
  const expiredSessionRequest = await request(
    "GET",
    "/api/workspace",
    undefined,
    expiredSessionCookie,
  );
  assert.equal(expiredSessionRequest.response.statusCode, 401);
  assert.deepEqual(expiredSessionRequest.json, { error: "unauthorized" });

  const secondSignin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: originalPassword,
  });
  assert.equal(
    secondSignin.response.statusCode,
    200,
    secondSignin.response.body,
  );
  assert.equal(secondSignin.json?.twoFactorRedirect, true);
  const challengeCookie = cookieFrom(secondSignin.response);
  const verifiedChallenge = await request(
    "POST",
    "/api/auth/two-factor/verify-backup-code",
    { code: enroll.json.backupCodes[0] },
    challengeCookie,
  );
  assert.equal(
    verifiedChallenge.response.statusCode,
    200,
    verifiedChallenge.response.body,
  );
  const secondDeviceCookie = cookieFrom(verifiedChallenge.response);
  assert.ok(secondDeviceCookie);

  const replaySignin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: originalPassword,
  });
  const replayChallenge = cookieFrom(replaySignin.response);
  const beforeReplaySessionCount = await pool.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM "session" WHERE "userId" = $1`,
    [databaseUser.rows[0]?.id],
  );
  const replayedTotp = await request(
    "POST",
    "/api/auth/two-factor/verify-totp",
    { code: verificationCode },
    `${replayChallenge}; forma.session_token=forged-session-cookie`,
  );
  assert.ok(
    replayedTotp.response.statusCode >= 400,
    "the same TOTP code must not be accepted twice",
  );
  const replaySetCookies = replayedTotp.response.headers["set-cookie"];
  const replaySetCookieValues = Array.isArray(replaySetCookies)
    ? replaySetCookies
    : [replaySetCookies ?? ""];
  assert.ok(
    replaySetCookieValues.every(
      (value) => !/^forma\.(session_token|trust_device)=/i.test(value),
    ),
  );
  const afterReplaySessionCount = await pool.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM "session" WHERE "userId" = $1`,
    [databaseUser.rows[0]?.id],
  );
  assert.equal(
    afterReplaySessionCount.rows[0]?.count,
    beforeReplaySessionCount.rows[0]?.count,
  );

  const reusedBackupSignin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: originalPassword,
  });
  const reusedBackupChallenge = cookieFrom(reusedBackupSignin.response);
  const reusedBackup = await request(
    "POST",
    "/api/auth/two-factor/verify-backup-code",
    { code: enroll.json.backupCodes[0] },
    reusedBackupChallenge,
  );
  assert.ok(
    reusedBackup.response.statusCode >= 400,
    "a recovery code must be single use",
  );

  const listed = await request(
    "GET",
    "/api/account/sessions",
    undefined,
    mfaCookie,
  );
  assert.equal(listed.response.statusCode, 200, listed.response.body);
  assert.ok(listed.json.length >= 2);
  assert.ok(listed.json.every((item: any) => !("token" in item)));
  assert.ok(listed.json.some((item: any) => item.current));
  const secondSession = listed.json.find((item: any) => !item.current);
  assert.ok(secondSession && !secondSession.current);
  const revoked = await request(
    "DELETE",
    `/api/account/sessions/${secondSession.id}/revoke`,
    undefined,
    mfaCookie,
  );
  assert.equal(revoked.response.statusCode, 200, revoked.response.body);
  const stillCurrent = await request(
    "GET",
    "/api/auth/get-session",
    undefined,
    mfaCookie,
  );
  assert.ok(stillCurrent.json?.session);
  const afterRevokeList = await request(
    "GET",
    "/api/account/sessions",
    undefined,
    mfaCookie,
  );
  assert.equal(afterRevokeList.json.length, listed.json.length - 1);

  const rawSessionList = await request(
    "GET",
    "/api/auth/list-sessions",
    undefined,
    mfaCookie,
  );
  assert.equal(rawSessionList.response.statusCode, 200);
  assert.ok(
    rawSessionList.json.every(
      (item: any) => !("token" in item) && !("id" in item),
    ),
  );

  const changedPassword = "one more long memorable FORMA account passphrase";
  const changed = await request(
    "POST",
    "/api/auth/change-password",
    {
      currentPassword: originalPassword,
      newPassword: changedPassword,
      revokeOtherSessions: true,
    },
    mfaCookie,
  );
  assert.equal(changed.response.statusCode, 200, changed.response.body);
  const changedPasswordLogin = await request(
    "POST",
    "/api/auth/sign-in/email",
    { email, password: changedPassword },
  );
  assert.equal(changedPasswordLogin.json?.twoFactorRedirect, true);

  const unknownReset = await request(
    "POST",
    "/api/auth/request-password-reset",
    {
      email: `missing-${suffix}@example.test`,
      redirectTo: `${appOrigin}/reset-password`,
    },
  );
  assert.equal(unknownReset.response.statusCode, 200);
  const forgot = await request("POST", "/api/auth/request-password-reset", {
    email,
    redirectTo: `${appOrigin}/reset-password`,
  });
  assert.equal(forgot.response.statusCode, 200, forgot.response.body);
  assert.equal(forgot.json?.message, unknownReset.json?.message);
  const resetEmail = inspectEmailSink().find(
    (item) => item.kind === "reset-password" && item.email === email,
  );
  assert.ok(resetEmail);
  const resetUrl = new URL(resetEmail.url);
  const resetToken = resetUrl.pathname.split("/").filter(Boolean).at(-1);
  assert.ok(resetToken);
  const reset = await request("POST", "/api/auth/reset-password", {
    newPassword,
    token: resetToken,
  });
  assert.equal(reset.response.statusCode, 200, reset.response.body);
  const replayedReset = await request("POST", "/api/auth/reset-password", {
    newPassword: "a different replayed reset password",
    token: resetToken,
  });
  assert.ok(replayedReset.response.statusCode >= 400);
  const oldPasswordLogin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: originalPassword,
  });
  assert.ok(oldPasswordLogin.response.statusCode >= 400);
  const staleChangedPasswordLogin = await request(
    "POST",
    "/api/auth/sign-in/email",
    { email, password: changedPassword },
  );
  assert.ok(staleChangedPasswordLogin.response.statusCode >= 400);
  const afterResetLogin = await request("POST", "/api/auth/sign-in/email", {
    email,
    password: newPassword,
  });
  assert.equal(
    afterResetLogin.response.statusCode,
    200,
    afterResetLogin.response.body,
  );
  assert.equal(afterResetLogin.json?.twoFactorRedirect, true);

  const expiredResetRequest = await request(
    "POST",
    "/api/auth/request-password-reset",
    { email, redirectTo: `${appOrigin}/reset-password` },
  );
  assert.equal(expiredResetRequest.response.statusCode, 200);
  const resetMessages = inspectEmailSink().filter(
    (item) => item.kind === "reset-password" && item.email === email,
  );
  const expiredResetUrl = new URL(resetMessages.at(-1)!.url);
  const expiredResetToken = expiredResetUrl.pathname
    .split("/")
    .filter(Boolean)
    .at(-1);
  assert.ok(expiredResetToken);
  const resetVerification = await pool.query<{ id: string }>(
    `SELECT id FROM verification WHERE identifier = $1`,
    [`reset-password:${expiredResetToken}`],
  );
  assert.equal(resetVerification.rowCount, 1);
  await pool.query(
    `UPDATE verification SET "expiresAt" = now() - interval '1 second' WHERE id = $1`,
    [resetVerification.rows[0]?.id],
  );
  const expiredResetCallback = await request(
    "GET",
    `${expiredResetUrl.pathname}${expiredResetUrl.search}`,
  );
  assert.equal(expiredResetCallback.response.statusCode, 302);
  assert.match(
    String(expiredResetCallback.response.headers.location ?? ""),
    /error=INVALID_TOKEN/,
  );
  const expiredReset = await request("POST", "/api/auth/reset-password", {
    newPassword: "must not replace the current password",
    token: expiredResetToken,
  });
  assert.ok(expiredReset.response.statusCode >= 400);
  const stillCurrentPassword = await request(
    "POST",
    "/api/auth/sign-in/email",
    {
      email,
      password: newPassword,
    },
  );
  assert.equal(stillCurrentPassword.response.statusCode, 200);
  assert.equal(stillCurrentPassword.json?.twoFactorRedirect, true);

  const resetChallenge = cookieFrom(stillCurrentPassword.response);
  const resetMfa = await request(
    "POST",
    "/api/auth/two-factor/verify-totp",
    { code: await createOTP(secret).hotp(Math.floor(Date.now() / 30_000) + 1) },
    resetChallenge,
  );
  assert.equal(resetMfa.response.statusCode, 200, resetMfa.response.body);
  const deletionCookie = cookieFrom(resetMfa.response);
  const userRow = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  const userId = userRow.rows[0]?.id;
  assert.ok(userId);
  const { getWorkspace } = await import("../workspace.js");
  await getWorkspace(pool, userId, "FORMA Member");

  const newEmail = `updated-${suffix}@example.test`;
  const changeEmail = await request(
    "POST",
    "/api/auth/change-email",
    { newEmail, callbackURL: `${appOrigin}/account` },
    deletionCookie,
  );
  assert.equal(changeEmail.response.statusCode, 200, changeEmail.response.body);
  const expiredChangeEmailToken = await signJWT(
    {
      email: email.toLowerCase(),
      updateTo: newEmail.toLowerCase(),
      requestType: "change-email-confirmation",
    },
    config.authSecret,
    -1,
  );
  const expiredChangeEmail = await request(
    "GET",
    `/api/auth/verify-email?token=${encodeURIComponent(expiredChangeEmailToken)}&callbackURL=${encodeURIComponent(`${appOrigin}/account`)}`,
    undefined,
    deletionCookie,
    appOrigin,
    false,
  );
  assert.equal(expiredChangeEmail.response.statusCode, 302);
  assert.match(
    String(expiredChangeEmail.response.headers.location ?? ""),
    /error=TOKEN_EXPIRED/,
  );
  const emailChangeRequest = inspectEmailSink().find(
    (item) => item.kind === "change-email" && item.email === email,
  );
  assert.ok(emailChangeRequest);
  const emailChangeUrl = new URL(emailChangeRequest.url);
  const approvedChange = await request(
    "GET",
    `${emailChangeUrl.pathname}${emailChangeUrl.search}`,
    undefined,
    deletionCookie,
  );
  assert.ok(
    [200, 302].includes(approvedChange.response.statusCode),
    approvedChange.response.body,
  );
  const emailBeforeNewAddressVerification = await pool.query<{ email: string }>(
    `SELECT email FROM "user" WHERE id = $1`,
    [userId],
  );
  assert.equal(emailBeforeNewAddressVerification.rows[0]?.email, email);
  const replayedEmailChangeConfirmation = await request(
    "GET",
    `${emailChangeUrl.pathname}${emailChangeUrl.search}`,
    undefined,
    deletionCookie,
    appOrigin,
    false,
  );
  assert.equal(replayedEmailChangeConfirmation.response.statusCode, 302);
  const newAddressVerificationEmails = inspectEmailSink().filter(
    (item) => item.kind === "verify-email" && item.email === newEmail,
  );
  assert.ok(newAddressVerificationEmails.length >= 2);
  const newAddressVerification = newAddressVerificationEmails.at(-1);
  assert.ok(newAddressVerification);
  const newAddressUrl = new URL(newAddressVerification.url);
  const confirmedNewAddress = await request(
    "GET",
    `${newAddressUrl.pathname}${newAddressUrl.search}`,
    undefined,
    deletionCookie,
  );
  assert.ok(
    [200, 302].includes(confirmedNewAddress.response.statusCode),
    confirmedNewAddress.response.body,
  );
  const changedEmailRow = await pool.query<{
    email: string;
    emailVerified: boolean;
  }>(`SELECT email, "emailVerified" FROM "user" WHERE id = $1`, [userId]);
  assert.equal(changedEmailRow.rows[0]?.email, newEmail);
  assert.equal(changedEmailRow.rows[0]?.emailVerified, true);
  const replayedNewAddressVerification = await request(
    "GET",
    `${newAddressUrl.pathname}${newAddressUrl.search}`,
    undefined,
    deletionCookie,
    appOrigin,
    false,
  );
  assert.equal(replayedNewAddressVerification.response.statusCode, 302);
  assert.match(
    String(replayedNewAddressVerification.response.headers.location ?? ""),
    /error=USER_NOT_FOUND/,
  );
  const unchangedEmail = await pool.query<{ email: string }>(
    `SELECT email FROM "user" WHERE id = $1`,
    [userId],
  );
  assert.equal(unchangedEmail.rows[0]?.email, newEmail);

  const deleteRequested = await request(
    "POST",
    "/api/auth/delete-user",
    { password: newPassword },
    deletionCookie,
  );
  assert.equal(
    deleteRequested.response.statusCode,
    200,
    deleteRequested.response.body,
  );
  const deleteEmail = inspectEmailSink().find(
    (item) => item.kind === "delete-account" && item.email === newEmail,
  );
  assert.ok(deleteEmail);
  const deletionUrl = new URL(deleteEmail.url);
  // Email-link navigation has no custom X-Forma-Member header; Better Auth
  // validates its single-use confirmation token and the current session.
  const deleted = await request(
    "GET",
    `${deletionUrl.pathname}${deletionUrl.search}`,
    undefined,
    deletionCookie,
    appOrigin,
    false,
  );
  assert.ok(
    [200, 302].includes(deleted.response.statusCode),
    deleted.response.body,
  );
  const deletedUser = await pool.query(`SELECT 1 FROM "user" WHERE id = $1`, [
    userId,
  ]);
  const deletedWorkspace = await pool.query(
    `SELECT 1 FROM member_workspace WHERE owner_id = $1`,
    [userId],
  );
  assert.equal(deletedUser.rowCount, 0);
  assert.equal(deletedWorkspace.rowCount, 0);
});

test("default auth configuration rate-limits the sixth sign-in attempt per trusted IP", async () => {
  const sourceIp = "203.0.113.199";
  const attempts = [];
  for (let index = 0; index < 6; index += 1) {
    attempts.push(
      await request(
        "POST",
        "/api/auth/sign-in/email",
        {
          email: `rate-limit-missing-${suffix}@example.test`,
          password: "a sufficiently long test password",
        },
        undefined,
        appOrigin,
        undefined,
        sourceIp,
      ),
    );
  }
  assert.ok(
    attempts.slice(0, 5).every(({ response }) => response.statusCode === 401),
  );
  assert.equal(attempts[5]?.response.statusCode, 429);
});

test("rate-limit override is honored only by an explicit NODE_ENV=test app", async () => {
  assert.ok(pool);
  const previousNodeEnv = process.env.NODE_ENV;
  const signInSixTimes = async (
    testApp: Awaited<ReturnType<typeof createApp>>,
    sourceIp: string,
  ) => {
    const responses = [];
    for (let index = 0; index < 6; index += 1) {
      responses.push(
        await testApp.inject({
          method: "POST",
          url: "/api/auth/sign-in/email",
          headers: {
            "x-forma-worker-secret": workerSecret,
            "x-forma-client-ip": sourceIp,
            origin: appOrigin,
            "content-type": "application/json",
          },
          payload: {
            email: `rate-limit-override-${suffix}@example.test`,
            password: "a sufficiently long test password",
          },
        }),
      );
    }
    return responses;
  };
  const getSession101Times = async (
    testApp: Awaited<ReturnType<typeof createApp>>,
    sourceIp: string,
  ) => {
    const responses = [];
    for (let index = 0; index < 101; index += 1) {
      responses.push(
        await testApp.inject({
          method: "GET",
          url: "/api/auth/get-session",
          headers: {
            "x-forma-worker-secret": workerSecret,
            "x-forma-client-ip": sourceIp,
          },
        }),
      );
    }
    return responses;
  };

  try {
    process.env.NODE_ENV = "test";
    const overrideApp = await createApp({
      pool,
      config: { ...config, authRateLimitMax: 6 },
    });
    await overrideApp.ready();
    const overrideResponses = await signInSixTimes(
      overrideApp,
      "203.0.113.198",
    );
    assert.ok(overrideResponses.every(({ statusCode }) => statusCode === 401));
    await overrideApp.close();

    const developmentApp = await createApp({
      pool,
      config: { ...config, environment: "development", authRateLimitMax: 1000 },
    });
    await developmentApp.ready();
    const developmentResponses = await signInSixTimes(
      developmentApp,
      "203.0.113.197",
    );
    assert.ok(
      developmentResponses
        .slice(0, 5)
        .every(({ statusCode }) => statusCode === 401),
    );
    assert.equal(developmentResponses[5]?.statusCode, 429);
    const developmentGlobalResponses = await getSession101Times(
      developmentApp,
      "203.0.113.196",
    );
    assert.ok(
      developmentGlobalResponses
        .slice(0, 100)
        .every(({ statusCode }) => statusCode === 200),
    );
    assert.equal(developmentGlobalResponses[100]?.statusCode, 429);
    await developmentApp.close();

    const raisedGlobalApp = await createApp({
      pool,
      config: { ...config, authRateLimitMax: 1000 },
    });
    await raisedGlobalApp.ready();
    const raisedGlobalResponses = await getSession101Times(
      raisedGlobalApp,
      "203.0.113.195",
    );
    assert.ok(
      raisedGlobalResponses.every(({ statusCode }) => statusCode === 200),
    );
    await raisedGlobalApp.close();
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
  }
});
