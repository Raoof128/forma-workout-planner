import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp } from "../app.js";
import type { AppConfig } from "../config.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import { issueCoachToken } from "../coachTokens.js";
import { revokeCredentialArtifacts } from "../auth.js";
import {
  pruneExpiredAuthRows,
  refundBudget,
  consumeBudget,
  throttleKey,
} from "../throttle.js";

// Real-PostgreSQL regression tests for the credential-change, email-budget,
// timing, account-deletion and housekeeping hardening batch.

const { Pool } = pg;
const databaseUrl =
  process.env.AUTH_TEST_DATABASE_URL ?? process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_auth_hardening_${suffix}`;
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
const appOrigin = "http://127.0.0.1:5176";
const workerSecret = `test-worker-secret-${suffix}-long`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `test-auth-secret-${suffix}-long-enough`,
  workerSharedSecret: workerSecret,
  emailFrom: "FORMA <accounts@forma.test>",
  emailSinkEnabled: true,
};
const password = "a long FORMA passphrase with 15+ characters";
type TestApp = Awaited<ReturnType<typeof createApp>>;
let app: TestApp | undefined;
let requestCounter = 0;

before(async () => {
  if (!databaseUrl || !adminPool || !pool) {
    throw new Error(
      "AUTH_TEST_DATABASE_URL or TEST_DATABASE_URL is required; auth hardening tests require real PostgreSQL.",
    );
  }
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  for (const migrationName of [
    "0001-auth.sql",
    "0002-workspace.sql",
    "0003-security-throttle.sql",
    "0004-routine-programming.sql",
    "0005-coach-tokens.sql",
    "0006-coach-token-scope.sql",
  ]) {
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

function nextIp(): string {
  return `198.51.100.${(requestCounter++ % 250) + 1}`;
}

async function post(
  testApp: TestApp,
  path: string,
  body: unknown,
  cookie?: string,
  memberRef?: string,
) {
  const headers: Record<string, string> = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": nextIp(),
    origin: appOrigin,
    "content-type": "application/json",
  };
  if (cookie) headers.cookie = cookie;
  // Member-bound routes (delete-user) must name the session's member reference.
  if (memberRef) headers["x-forma-member"] = memberRef;
  const response = await testApp.inject({
    method: "POST",
    url: path,
    headers,
    payload: JSON.stringify(body),
  });
  return response;
}

async function get(testApp: TestApp, pathAndQuery: string, cookie?: string) {
  const headers: Record<string, string> = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": nextIp(),
  };
  if (cookie) headers.cookie = cookie;
  return testApp.inject({ method: "GET", url: pathAndQuery, headers });
}

function cookieFrom(response: { headers: Record<string, unknown> }): string {
  const values = response.headers["set-cookie"];
  assert.ok(values, "expected Better Auth to set a session cookie");
  return (Array.isArray(values) ? values : [values])
    .map((value) => String(value).split(";", 1)[0])
    .join("; ");
}

/** Signs up, verifies the mailbox through the sink link, and returns the user id. */
async function verifiedMember(label: string) {
  assert.ok(app && pool);
  const email = `${label}-${suffix}@example.test`;
  const signup = await post(app, "/api/auth/sign-up/email", {
    name: "Member",
    email,
    password,
  });
  assert.equal(signup.statusCode, 200, signup.body);
  const message = inspectEmailSink()
    .filter((item) => item.kind === "verify-email" && item.email === email)
    .at(-1);
  assert.ok(message, "expected a verification email in the sink");
  const link = new URL(message.url);
  const verified = await get(app, `${link.pathname}${link.search}`);
  assert.ok([200, 302].includes(verified.statusCode), verified.body);
  const row = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  assert.ok(row.rows[0]?.id);
  return { id: row.rows[0].id, email };
}

async function insertTrustRecord(userId: string): Promise<void> {
  assert.ok(pool);
  // Same shape as Better Auth's trusted-device record: identifier
  // `trust-device-<random>`, value = user id, expiry in the future.
  await pool.query(
    `INSERT INTO verification (id, identifier, value, "expiresAt")
     VALUES ($1, $2, $3, now() + interval '30 days')`,
    [randomUUID(), `trust-device-${randomUUID()}`, userId],
  );
}

async function trustRecordCount(userId: string): Promise<number> {
  assert.ok(pool);
  const result = await pool.query<{ count: number }>(
    `SELECT count(*)::int AS count FROM verification
      WHERE starts_with(identifier, 'trust-device-') AND value = $1`,
    [userId],
  );
  return result.rows[0]?.count ?? 0;
}

async function coachRevokedAt(
  tokenId: string,
): Promise<Date | null | undefined> {
  assert.ok(pool);
  const result = await pool.query<{ revoked_at: Date | null }>(
    `SELECT revoked_at FROM member_coach_token WHERE id = $1`,
    [tokenId],
  );
  return result.rows[0]?.revoked_at;
}

test("password reset revokes coach tokens and trusted devices for that member only", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const target = await verifiedMember("reset-target");
  const bystander = await verifiedMember("reset-bystander");
  const targetToken = await issueCoachToken(
    pool,
    config.authSecret,
    target.id,
    "Target coach",
  );
  const bystanderToken = await issueCoachToken(
    pool,
    config.authSecret,
    bystander.id,
    "Bystander coach",
  );
  await insertTrustRecord(target.id);
  await insertTrustRecord(target.id);
  await insertTrustRecord(bystander.id);

  const requested = await post(app, "/api/auth/request-password-reset", {
    email: target.email,
    redirectTo: `${appOrigin}/reset-password`,
  });
  assert.equal(requested.statusCode, 200, requested.body);
  const resetEmail = inspectEmailSink()
    .filter(
      (item) => item.kind === "reset-password" && item.email === target.email,
    )
    .at(-1);
  assert.ok(resetEmail);
  const resetToken = new URL(resetEmail.url).pathname
    .split("/")
    .filter(Boolean)
    .at(-1);
  assert.ok(resetToken);
  const reset = await post(app, "/api/auth/reset-password", {
    newPassword: "a brand new FORMA passphrase after reset",
    token: resetToken,
  });
  assert.equal(reset.statusCode, 200, reset.body);

  assert.notEqual(await coachRevokedAt(targetToken.record.id), null);
  assert.equal(await coachRevokedAt(bystanderToken.record.id), null);
  assert.equal(await trustRecordCount(target.id), 0);
  assert.equal(await trustRecordCount(bystander.id), 1);
});

test("revokeCredentialArtifacts changes only the named member's coach tokens and trust records", async () => {
  assert.ok(pool);
  const named = await verifiedMember("revoke-named");
  const other = await verifiedMember("revoke-other");
  const namedToken = await issueCoachToken(
    pool,
    config.authSecret,
    named.id,
    "Named coach",
  );
  const otherToken = await issueCoachToken(
    pool,
    config.authSecret,
    other.id,
    "Other coach",
  );
  await insertTrustRecord(named.id);
  await insertTrustRecord(other.id);

  await revokeCredentialArtifacts(pool, named.id);

  assert.notEqual(await coachRevokedAt(namedToken.record.id), null);
  assert.equal(await coachRevokedAt(otherToken.record.id), null);
  assert.equal(await trustRecordCount(named.id), 0);
  assert.equal(await trustRecordCount(other.id), 1);
});

test("refundBudget gives back a spent unit, never drops below zero, and restores capacity", async () => {
  assert.ok(pool);
  const scope = `email:refund-test-${suffix}`;
  const key = throttleKey(config.authSecret, scope, "member@example.test");
  const limit = 2;
  const windowSeconds = 3600;

  // Two sends are granted, then the second one fails at the provider.
  assert.equal(
    await consumeBudget(pool, scope, key, limit, windowSeconds),
    true,
  );
  assert.equal(
    await consumeBudget(pool, scope, key, limit, windowSeconds),
    true,
  );
  await refundBudget(pool, scope, key);
  // The refunded unit lets the next legitimate send through within the limit.
  assert.equal(
    await consumeBudget(pool, scope, key, limit, windowSeconds),
    true,
    "a refunded unit must let the next send through",
  );
  // The limit is still enforced after the refund.
  assert.equal(
    await consumeBudget(pool, scope, key, limit, windowSeconds),
    false,
  );

  for (let index = 0; index < 5; index += 1) {
    await refundBudget(pool, scope, key);
  }
  const counter = await pool.query<{ window_count: number }>(
    `SELECT window_count FROM security_throttle WHERE scope = $1 AND key_digest = $2`,
    [scope, key],
  );
  assert.equal(counter.rows[0]?.window_count, 0);

  await refundBudget(
    pool,
    scope,
    throttleKey(config.authSecret, scope, "missing"),
  );
});

test("production-like background email: sign-up answers promptly while the sender never resolves", async () => {
  assert.ok(pool);
  let sends = 0;
  const backgroundApp = await createApp({
    pool,
    config: { ...config, environment: "production", emailSinkEnabled: false },
    email: () => {
      sends += 1;
      return new Promise<void>(() => {});
    },
  });
  await backgroundApp.ready();
  try {
    const started = Date.now();
    const response = await Promise.race([
      post(backgroundApp, "/api/auth/sign-up/email", {
        name: "Member",
        email: `background-${suffix}@example.test`,
        password,
      }),
      new Promise<never>((_, reject) =>
        setTimeout(
          () => reject(new Error("sign-up waited for the email sender")),
          2000,
        ),
      ),
    ]);
    const elapsed = Date.now() - started;
    assert.equal(response.statusCode, 200, response.body);
    assert.ok(elapsed < 2000, `sign-up took ${elapsed} ms`);
    for (let attempt = 0; attempt < 50 && sends === 0; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    assert.equal(sends, 1, "the background task still dispatches the email");
  } finally {
    await backgroundApp.close();
  }
});

test("background email failures log a fixed event and error class, never the address", async () => {
  assert.ok(pool);
  const leakingAddress = `leak-${suffix}@example.test`;
  const captured: string[] = [];
  const originalWrite = process.stderr.write.bind(process.stderr);
  process.stderr.write = ((chunk: string | Uint8Array) => {
    captured.push(String(chunk));
    return true;
  }) as typeof process.stderr.write;
  const failingApp = await createApp({
    pool,
    config: { ...config, environment: "production", emailSinkEnabled: false },
    email: async () => {
      throw new Error(`provider rejected ${leakingAddress}`);
    },
  });
  await failingApp.ready();
  try {
    const response = await post(failingApp, "/api/auth/sign-up/email", {
      name: "Member",
      email: leakingAddress,
      password,
    });
    assert.equal(response.statusCode, 200, response.body);
    for (let attempt = 0; attempt < 50; attempt += 1) {
      if (captured.some((line) => line.includes("auth_email_failed"))) break;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
  } finally {
    process.stderr.write = originalWrite;
    await failingApp.close();
  }
  const logged = captured.join("");
  assert.match(logged, /"event":"auth_email_failed"/);
  assert.match(logged, /"errorClass":"Error"/);
  assert.equal(logged.includes(leakingAddress), false);
  assert.equal(logged.includes("provider rejected"), false);
});

test("account deletion uses a one-hour token and removes the member's leftover verification rows only", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const leaver = await verifiedMember("delete-leaver");
  const stayer = await verifiedMember("delete-stayer");
  await insertTrustRecord(leaver.id);
  await insertTrustRecord(stayer.id);
  await pool.query(
    `INSERT INTO verification (id, identifier, value, "expiresAt") VALUES
       ($1, $2, $3, now() + interval '1 day'),
       ($4, $5, $3, now() + interval '1 day'),
       ($6, $7, $3, now() + interval '1 day')`,
    [
      randomUUID(),
      `reset-password:${randomUUID()}`,
      leaver.id,
      randomUUID(),
      `2fa-${randomUUID()}`,
      randomUUID(),
      `delete-account-${randomUUID()}`,
    ],
  );

  const signin = await post(app, "/api/auth/sign-in/email", {
    email: leaver.email,
    password,
  });
  assert.equal(signin.statusCode, 200, signin.body);
  const cookie = cookieFrom(signin);
  const session = await get(app, "/api/auth/get-session", cookie);
  assert.equal(session.statusCode, 200, session.body);
  const memberRef = session.json().user.id as string;
  assert.match(memberRef, /^mem_/);
  const requested = await post(
    app,
    "/api/auth/delete-user",
    { password },
    cookie,
    memberRef,
  );
  assert.equal(requested.statusCode, 200, requested.body);

  const deleteToken = await pool.query<{ expires_in: number }>(
    `SELECT extract(epoch FROM ("expiresAt" - now()))::int AS expires_in
       FROM verification
      WHERE value = $1 AND starts_with(identifier, 'delete-account-')
      ORDER BY "createdAt" DESC LIMIT 1`,
    [leaver.id],
  );
  assert.ok(deleteToken.rows[0], "expected a delete-account token");
  assert.ok(
    deleteToken.rows[0].expires_in > 3500 &&
      deleteToken.rows[0].expires_in <= 3600,
    `delete token lifetime was ${deleteToken.rows[0].expires_in} seconds`,
  );

  const deleteEmail = inspectEmailSink()
    .filter(
      (item) => item.kind === "delete-account" && item.email === leaver.email,
    )
    .at(-1);
  assert.ok(deleteEmail);
  const deletionUrl = new URL(deleteEmail.url);
  const deleted = await get(
    app,
    `${deletionUrl.pathname}${deletionUrl.search}`,
    cookie,
  );
  assert.ok([200, 302].includes(deleted.statusCode), deleted.body);

  const remainingUser = await pool.query(`SELECT 1 FROM "user" WHERE id = $1`, [
    leaver.id,
  ]);
  assert.equal(remainingUser.rowCount, 0);
  const leftovers = await pool.query(
    `SELECT 1 FROM verification WHERE value = $1`,
    [leaver.id],
  );
  assert.equal(
    leftovers.rowCount,
    0,
    "no verification row may name the deleted member",
  );
  assert.equal(await trustRecordCount(stayer.id), 1);
});

test("housekeeping removes expired auth rows in batches and leaves active rows alone", async () => {
  assert.ok(pool);
  const owner = await verifiedMember("prune-owner");
  const activeSessionId = randomUUID();
  const expiredSessionId = randomUUID();
  const recentlyExpiredSessionId = randomUUID();
  await pool.query(
    `INSERT INTO "session" (id, "expiresAt", token, "userId") VALUES
       ($1, now() + interval '7 days', $2, $3),
       ($4, now() - interval '2 days', $5, $3),
       ($6, now() - interval '1 hour', $7, $3)`,
    [
      activeSessionId,
      randomUUID(),
      owner.id,
      expiredSessionId,
      randomUUID(),
      recentlyExpiredSessionId,
      randomUUID(),
    ],
  );
  const activeVerificationId = randomUUID();
  const expiredVerificationId = randomUUID();
  await pool.query(
    `INSERT INTO verification (id, identifier, value, "expiresAt") VALUES
       ($1, $2, $3, now() + interval '1 day'),
       ($4, $5, $3, now() - interval '1 minute')`,
    [
      activeVerificationId,
      `reset-password:${randomUUID()}`,
      owner.id,
      expiredVerificationId,
      `reset-password:${randomUUID()}`,
    ],
  );
  // More than one batch of expired verification rows, to exercise the loop.
  await pool.query(
    `INSERT INTO verification (id, identifier, value, "expiresAt")
     SELECT gen_random_uuid()::text, 'bulk-' || g, 'bulk', now() - interval '1 minute'
       FROM generate_series(1, 2500) AS g`,
  );

  const coachRow = async (
    expiresSql: string,
    revokedSql: string,
    createdSql = "now() - interval '60 days'",
  ) => {
    const id = randomUUID().replaceAll("-", "");
    await pool!.query(
      `INSERT INTO member_coach_token
         (id, owner_id, token_digest, label, created_at, expires_at, revoked_at)
       VALUES ($1, $2, encode(sha256(gen_random_uuid()::text::bytea), 'hex'),
               'Prune check', ${createdSql}, ${expiresSql}, ${revokedSql})`,
      [id, owner.id],
    );
    return id;
  };
  const staleCoach = await coachRow("now() - interval '31 days'", "NULL");
  const staleRevokedCoach = await coachRow(
    "now() - interval '31 days'",
    "now() - interval '31 days'",
  );
  const recentlyRevokedCoach = await coachRow(
    "now() - interval '31 days'",
    "now() - interval '1 day'",
  );
  const revokedButUnexpiredCoach = await coachRow(
    "now() + interval '10 days'",
    "now() - interval '31 days'",
  );
  const activeCoach = (
    await issueCoachToken(pool, config.authSecret, owner.id, "Active coach")
  ).record.id;

  await pruneExpiredAuthRows(pool);

  const sessions = await pool.query<{ id: string }>(
    `SELECT id FROM "session" WHERE "userId" = $1`,
    [owner.id],
  );
  const sessionIds = sessions.rows.map((row) => row.id);
  assert.ok(sessionIds.includes(activeSessionId));
  assert.ok(sessionIds.includes(recentlyExpiredSessionId));
  assert.equal(sessionIds.includes(expiredSessionId), false);

  const verifications = await pool.query<{ id: string }>(
    `SELECT id FROM verification WHERE id = ANY($1::text[])`,
    [[activeVerificationId, expiredVerificationId]],
  );
  const verificationIds = verifications.rows.map((row) => row.id);
  assert.ok(verificationIds.includes(activeVerificationId));
  assert.equal(verificationIds.includes(expiredVerificationId), false);
  const bulkLeft = await pool.query<{ count: number }>(
    `SELECT count(*)::int AS count FROM verification WHERE identifier LIKE 'bulk-%'`,
  );
  assert.equal(bulkLeft.rows[0]?.count, 0);
  const expiredLeft = await pool.query<{ count: number }>(
    `SELECT count(*)::int AS count FROM verification WHERE "expiresAt" < now()`,
  );
  assert.equal(expiredLeft.rows[0]?.count, 0);

  const coach = await pool.query<{ id: string }>(
    `SELECT id FROM member_coach_token WHERE owner_id = $1`,
    [owner.id],
  );
  const coachIds = coach.rows.map((row) => row.id);
  assert.equal(coachIds.includes(staleCoach), false);
  assert.equal(coachIds.includes(staleRevokedCoach), false);
  assert.ok(coachIds.includes(recentlyRevokedCoach));
  assert.ok(coachIds.includes(revokedButUnexpiredCoach));
  assert.ok(coachIds.includes(activeCoach));
});
