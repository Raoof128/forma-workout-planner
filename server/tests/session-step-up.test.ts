import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";
import { createApp } from "../app.js";
import type { AppConfig } from "../config.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";

// Session revocation step-up: "sign out everywhere" also ends the caller's
// own session, so it needs no recent sign-in. Removing *other* sessions keeps
// the 5-minute rule, but an older session may satisfy it in the same request
// with the account password (and TOTP code when two-step is on).

const { Pool } = pg;
const databaseUrl =
  process.env.AUTH_TEST_DATABASE_URL ?? process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_stepup_test_${suffix}`;
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
const password = "a long FORMA step-up passphrase for testing";
let app: Awaited<ReturnType<typeof createApp>> | undefined;
let requestCounter = 0;

before(async () => {
  if (!databaseUrl || !adminPool || !pool) {
    throw new Error(
      "AUTH_TEST_DATABASE_URL or TEST_DATABASE_URL is required; step-up tests require real PostgreSQL.",
    );
  }
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  const migrations = (await readdir(join(testDir, "..", "migrations"))).filter(
    (name) => name.endsWith(".sql"),
  );
  for (const name of migrations.sort())
    await pool.query(
      await readFile(join(testDir, "..", "migrations", name), "utf8"),
    );
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
  assert.ok(values, "expected a session or challenge cookie");
  return (Array.isArray(values) ? values : [values])
    .map((value: string) => value.split(";", 1)[0])
    .join("; ");
}

async function request(
  method: string,
  path: string,
  body?: unknown,
  cookie?: string,
) {
  assert.ok(app);
  const headers: Record<string, string> = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": `198.51.100.${(requestCounter++ % 250) + 1}`,
    origin: appOrigin,
  };
  if (body !== undefined) headers["content-type"] = "application/json";
  if (cookie) {
    headers.cookie = cookie;
    const session = await app.inject({
      method: "GET",
      url: "/api/auth/get-session",
      headers,
    });
    const member = (session.json() as { user?: { id?: string } } | null)?.user
      ?.id;
    if (member) headers["x-forma-member"] = member;
  }
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

async function member(label: string) {
  assert.ok(pool);
  const email = `${label}-${suffix}@example.test`;
  const signup = await request("POST", "/api/auth/sign-up/email", {
    name: "Step-up Member",
    email,
    password,
  });
  assert.equal(signup.response.statusCode, 200, signup.response.body);
  const link = inspectEmailSink().find(
    (item) => item.kind === "verify-email" && item.email === email,
  );
  assert.ok(link);
  const url = new URL(link.url);
  await request("GET", `${url.pathname}${url.search}`);
  const userId = (
    await pool.query<{ id: string }>(`SELECT id FROM "user" WHERE email = $1`, [
      email,
    ])
  ).rows[0]?.id;
  assert.ok(userId);
  return { email, userId };
}

async function signIn(email: string) {
  const result = await request("POST", "/api/auth/sign-in/email", {
    email,
    password,
  });
  assert.equal(result.response.statusCode, 200, result.response.body);
  return cookieFrom(result.response);
}

async function ageSessions(userId: string) {
  assert.ok(pool);
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() - interval '10 minutes' WHERE "userId" = $1`,
    [userId],
  );
}

async function sessionCount(userId: string) {
  assert.ok(pool);
  const result = await pool.query<{ count: string }>(
    `SELECT count(*)::text AS count FROM "session" WHERE "userId" = $1`,
    [userId],
  );
  return Number(result.rows[0]?.count);
}

test("sign out everywhere works from a session older than five minutes", async () => {
  const { email, userId } = await member("everywhere");
  const current = await signIn(email);
  await signIn(email);
  await ageSessions(userId);
  const result = await request(
    "POST",
    "/api/account/sessions/revoke-all",
    undefined,
    current,
  );
  assert.equal(result.response.statusCode, 200, result.response.body);
  assert.equal(await sessionCount(userId), 0);
});

test("removing other sessions from an older session asks for the password and honours it", async () => {
  const { email, userId } = await member("others");
  const current = await signIn(email);
  await signIn(email);
  await signIn(email);
  await ageSessions(userId);

  const bare = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    undefined,
    current,
  );
  assert.equal(bare.response.statusCode, 403);
  assert.equal(bare.json?.error, "reauthentication_required");
  assert.equal(bare.json?.twoFactor, false);

  const wrong = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password: "not the right passphrase at all" },
    current,
  );
  assert.equal(wrong.response.statusCode, 401);
  assert.equal(wrong.json?.error, "invalid_password");
  assert.equal(await sessionCount(userId), 3);

  const confirmed = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password },
    current,
  );
  assert.equal(confirmed.response.statusCode, 200, confirmed.response.body);
  assert.equal(await sessionCount(userId), 1);
  const stillSignedIn = await request(
    "GET",
    "/api/auth/get-session",
    undefined,
    current,
  );
  assert.ok(stillSignedIn.json?.session);
});

test("revoking one session from an older session accepts the password", async () => {
  const { email, userId } = await member("single");
  const current = await signIn(email);
  await signIn(email);
  await ageSessions(userId);
  const listed = await request(
    "GET",
    "/api/account/sessions",
    undefined,
    current,
  );
  const other = listed.json.find((item: any) => !item.current);
  assert.ok(other);
  const bare = await request(
    "DELETE",
    `/api/account/sessions/${other.id}/revoke`,
    undefined,
    current,
  );
  assert.equal(bare.response.statusCode, 403);
  assert.equal(bare.json?.error, "reauthentication_required");
  const confirmed = await request(
    "DELETE",
    `/api/account/sessions/${other.id}/revoke`,
    { password },
    current,
  );
  assert.equal(confirmed.response.statusCode, 200, confirmed.response.body);
  assert.equal(await sessionCount(userId), 1);
});

test("two-step members must add a valid, unused authenticator code", async () => {
  const { email, userId } = await member("totp");
  let current = await signIn(email);
  const enroll = await request(
    "POST",
    "/api/auth/two-factor/enable",
    { password },
    current,
  );
  assert.equal(enroll.response.statusCode, 200, enroll.response.body);
  const secret = new TextDecoder().decode(
    base32.decode(
      new URL(enroll.json.totpURI).searchParams.get("secret") ?? "",
    ),
  );
  const enrolled = await request(
    "POST",
    "/api/auth/two-factor/verify-totp",
    { code: await createOTP(secret).totp() },
    current,
  );
  assert.equal(enrolled.response.statusCode, 200, enrolled.response.body);
  current = cookieFrom(enrolled.response);
  assert.ok(pool);
  // A second device, so there is something to sign out.
  await pool.query(
    `INSERT INTO "session" (id, token, "userId", "expiresAt", "createdAt", "updatedAt")
     VALUES ($1, $2, $3, now() + interval '1 day', now(), now())`,
    [`other-${suffix}`, `other-token-${suffix}`, userId],
  );
  await ageSessions(userId);

  const bare = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    undefined,
    current,
  );
  assert.equal(bare.response.statusCode, 403);
  assert.equal(bare.json?.twoFactor, true);

  const passwordOnly = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password },
    current,
  );
  assert.equal(passwordOnly.response.statusCode, 401);
  assert.equal(passwordOnly.json?.error, "invalid_code");

  const wrongCode = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password, code: "000000" },
    current,
  );
  assert.equal(wrongCode.response.statusCode, 401);
  assert.equal(wrongCode.json?.error, "invalid_code");
  assert.equal(await sessionCount(userId), 2);

  // Forget the enrolment code's replay record so the current code is usable.
  await pool.query(`DELETE FROM mfa_totp_replay WHERE "userId" = $1`, [userId]);
  const code = await createOTP(secret).totp();
  const confirmed = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password, code },
    current,
  );
  assert.equal(confirmed.response.statusCode, 200, confirmed.response.body);
  assert.equal(await sessionCount(userId), 1);
  const replay = await request(
    "POST",
    "/api/account/sessions/revoke-others",
    { password, code },
    current,
  );
  assert.equal(replay.response.statusCode, 401);
  assert.equal(replay.json?.error, "invalid_code");
});

test("wrong step-up passwords share the account's password-attempt limit", async () => {
  const { email, userId } = await member("throttle");
  const current = await signIn(email);
  await ageSessions(userId);
  let limited = false;
  for (let attempt = 0; attempt < 12; attempt++) {
    const result = await request(
      "POST",
      "/api/account/sessions/revoke-others",
      { password: `wrong passphrase number ${attempt} for FORMA` },
      current,
    );
    if (result.response.statusCode === 429) {
      limited = true;
      break;
    }
    assert.equal(result.response.statusCode, 401);
  }
  assert.ok(limited, "repeated wrong passwords must be throttled");
});
