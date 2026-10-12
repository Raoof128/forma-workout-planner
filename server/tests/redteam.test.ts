import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp, isSafeRedirect } from "../app.js";
import type { AppConfig } from "../config.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import {
  consumeBudget,
  recordSignInFailure,
  signInLocked,
  throttleKey,
} from "../throttle.js";

// Regression tests for findings from the 2026-10-12 red-team engagement.
// Each test names the finding it pins; see docs/security/penetration-test-report.md.

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_redteam_${suffix}`;
const appOrigin = "https://app.forma.test";
const workerSecret = `redteam-worker-secret-${suffix}`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `redteam-auth-secret-${suffix}`,
  workerSharedSecret: workerSecret,
  emailFrom: "FORMA <accounts@forma.test>",
  emailSinkEnabled: true,
};
const password = "a sufficiently long FORMA passphrase";
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
let app: Awaited<ReturnType<typeof createApp>> | undefined;
let ipCounter = 0;

before(async () => {
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "TEST_DATABASE_URL is required; red-team regressions require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  for (const name of [
    "0001-auth.sql",
    "0002-workspace.sql",
    "0003-security-throttle.sql",
  ]) {
    await pool.query(
      await readFile(join(testDir, "..", "migrations", name), "utf8"),
    );
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

type Options = {
  body?: unknown;
  raw?: string;
  cookie?: string;
  member?: string;
  origin?: string | null;
  secret?: string | null;
  ip?: string;
};

async function call(method: string, url: string, options: Options = {}) {
  assert.ok(app);
  const headers: Record<string, string> = {
    "x-forma-client-ip": options.ip ?? `198.51.100.${(ipCounter++ % 250) + 1}`,
  };
  if (options.secret !== null)
    headers["x-forma-worker-secret"] = options.secret ?? workerSecret;
  if (options.origin !== null) headers.origin = options.origin ?? appOrigin;
  if (options.cookie) headers.cookie = options.cookie;
  if (options.member) headers["x-forma-member"] = options.member;
  const payload =
    options.raw ??
    (options.body === undefined ? undefined : JSON.stringify(options.body));
  if (payload !== undefined) headers["content-type"] = "application/json";
  const response = await app.inject({
    method: method as "GET",
    url,
    headers,
    ...(payload === undefined ? {} : { payload }),
  });
  let json: any = null;
  try {
    json = response.json();
  } catch {
    json = null;
  }
  return { response, json };
}

function cookies(response: { headers: Record<string, unknown> }): string {
  return ([] as string[])
    .concat((response.headers["set-cookie"] as string[] | string) ?? [])
    .map((value) => value.split(";", 1)[0])
    .join("; ");
}

async function verifiedMember(label: string) {
  const email = `${label}-${suffix}@example.test`;
  clearEmailSink();
  const signUp = await call("POST", "/api/auth/sign-up/email", {
    body: { name: label, email, password },
  });
  assert.equal(signUp.response.statusCode, 200);
  const mail = inspectEmailSink().find(
    (message) => message.email === email && message.kind === "verify-email",
  );
  assert.ok(mail, "verification email should be captured");
  const link = new URL(mail.url);
  await call("GET", `${link.pathname}${link.search}`, { origin: null });
  return { email, ...(await signIn(email)) };
}

async function signIn(email: string, secret = password) {
  const result = await call("POST", "/api/auth/sign-in/email", {
    body: { email, password: secret },
  });
  assert.equal(result.response.statusCode, 200, result.response.body);
  const cookie = cookies(result.response);
  const session = await call("GET", "/api/auth/get-session", {
    cookie,
    origin: null,
  });
  return { cookie, member: session.json.user.id as string };
}

test("RT-01: percent-encoded paths cannot bypass the gateway secret or Origin check", async () => {
  const alice = await verifiedMember("rt01");
  for (const path of [
    "/%61pi/workspace",
    "/%61pi/account/sessions",
    "/api/%77orkspace",
    "/%61pi/workspace/export",
  ]) {
    const noSecret = await call("GET", path, {
      cookie: alice.cookie,
      member: alice.member,
      secret: null,
      origin: null,
    });
    assert.notEqual(noSecret.response.statusCode, 200, path);
    assert.doesNotMatch(noSecret.response.body, /routines|createdAt/, path);
  }
  const hostileWrite = await call("PUT", "/%61pi/workspace", {
    cookie: alice.cookie,
    member: alice.member,
    origin: "https://attacker.example",
    body: { data: {}, expectedRevision: 0, operationId: "rt01" },
  });
  assert.ok([403, 404].includes(hostileWrite.response.statusCode));

  // Deny by default: only the exact health probe is public.
  const health = await call("GET", "/healthz", { secret: null, origin: null });
  assert.equal(health.response.statusCode, 200);
  const unknown = await call("GET", "/internal/anything", {
    secret: null,
    origin: null,
  });
  assert.equal(unknown.response.statusCode, 401);
  const hostileUnknown = await call("POST", "/not-api", {
    origin: "https://attacker.example",
    body: {},
  });
  assert.equal(hostileUnknown.response.statusCode, 403);
});

test("RT-02: auth redirects cannot leave the app origin", async () => {
  for (const callback of [
    "https://evil.example/x",
    "//evil.example/x",
    "/\\evil.example",
    "https:evil.example",
    "javascript:alert(1)",
  ]) {
    const query = new URLSearchParams({ callbackURL: callback });
    for (const path of [
      `/api/auth/reset-password/not-a-token?${query}`,
      `/api/auth/verify-email?token=bad&${query}`,
    ]) {
      const { response } = await call("GET", path, { origin: null });
      assert.equal(
        response.statusCode,
        400,
        `${path} -> ${response.statusCode}`,
      );
      assert.equal(response.headers.location, undefined);
    }
  }
  const sameOrigin = await call(
    "GET",
    `/api/auth/reset-password/not-a-token?callbackURL=${encodeURIComponent(`${appOrigin}/#account`)}`,
    { origin: null },
  );
  assert.equal(sameOrigin.response.statusCode, 302);
  assert.ok(String(sameOrigin.response.headers.location).startsWith(appOrigin));

  const bodyRedirect = await call("POST", "/api/auth/request-password-reset", {
    body: { email: "nobody@example.test", redirectTo: "https://evil.example" },
  });
  assert.equal(bodyRedirect.response.statusCode, 400);

  assert.equal(isSafeRedirect("/#account", appOrigin), true);
  assert.equal(isSafeRedirect(`${appOrigin}/x?y=1`, appOrigin), true);
  assert.equal(
    isSafeRedirect("https://app.forma.test.evil.example", appOrigin),
    false,
  );
  assert.equal(isSafeRedirect("/\tevil", appOrigin), false);
});

test("RT-03: malformed requests return generic errors without parser details", async () => {
  const alice = await verifiedMember("rt03");
  const malformed = await call("PUT", "/api/workspace", {
    cookie: alice.cookie,
    member: alice.member,
    raw: "{not json",
  });
  assert.equal(malformed.response.statusCode, 400);
  assert.deepEqual(malformed.json, { error: "invalid_json" });
  const missing = await call("GET", "/api/does-not-exist", { origin: null });
  assert.equal(missing.response.statusCode, 404);
  assert.deepEqual(missing.json, { error: "not_found" });
});

test("RT-04: failed sign-ins are capped per account across rotating IPs, without an existence oracle", async () => {
  const bob = await verifiedMember("rt04");
  const ghost = `ghost-${suffix}@example.test`;
  for (const email of [bob.email, ghost]) {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const { response } = await call("POST", "/api/auth/sign-in/email", {
        body: { email, password: `wrong password attempt ${attempt}` },
      });
      assert.equal(response.statusCode, 401);
    }
  }
  // The eleventh attempt is refused even with the correct password and a new IP.
  const locked = await call("POST", "/api/auth/sign-in/email", {
    body: { email: bob.email.toUpperCase(), password },
  });
  assert.equal(locked.response.statusCode, 429);
  const ghostLocked = await call("POST", "/api/auth/sign-in/email", {
    body: { email: ghost, password },
  });
  assert.equal(ghostLocked.response.statusCode, 429);
  assert.equal(locked.response.body, ghostLocked.response.body);

  // Proving mailbox control through password reset lifts the lock.
  clearEmailSink();
  await call("POST", "/api/auth/request-password-reset", {
    body: { email: bob.email, redirectTo: `${appOrigin}/#account` },
  });
  const reset = inspectEmailSink().find((m) => m.kind === "reset-password");
  assert.ok(reset);
  const token = new URL(reset.url).pathname.split("/").at(-1);
  const newPassword = "a brand new and long FORMA passphrase";
  const changed = await call("POST", "/api/auth/reset-password", {
    body: { token, newPassword },
  });
  assert.equal(changed.response.statusCode, 200);
  await signIn(bob.email, newPassword);
});

test("RT-04b: the consecutive-failure cap locks until reset and stores no raw email", async () => {
  assert.ok(pool);
  const key = throttleKey(config.authSecret, "sign-in", "cap@example.test");
  const policy = {
    windowLimit: 1000,
    windowSeconds: 900,
    lockSeconds: 900,
    consecutiveLimit: 3,
  };
  for (let i = 0; i < 2; i += 1) await recordSignInFailure(pool, key, policy);
  assert.equal(await signInLocked(pool, key), false);
  await recordSignInFailure(pool, key, policy);
  assert.equal(await signInLocked(pool, key), true);
  const row = await pool.query(
    `SELECT locked_until = 'infinity'::timestamptz AS indefinite FROM security_throttle WHERE key_digest = $1`,
    [key],
  );
  assert.equal(row.rows[0].indefinite, true);
  const leak = await pool.query(
    `SELECT count(*)::int AS n FROM security_throttle WHERE key_digest::text LIKE '%@%'`,
  );
  assert.equal(leak.rows[0].n, 0);
});

test("RT-05: a password change revokes other sessions even if the client opts out", async () => {
  const carol = await verifiedMember("rt05");
  const stolen = await signIn(carol.email);
  const change = await call("POST", "/api/auth/change-password", {
    cookie: carol.cookie,
    member: carol.member,
    body: {
      currentPassword: password,
      newPassword: "the replacement long FORMA passphrase",
      revokeOtherSessions: false,
    },
  });
  assert.equal(change.response.statusCode, 200);
  const session = await call("GET", "/api/auth/get-session", {
    cookie: stolen.cookie,
    origin: null,
  });
  assert.equal(session.json, null);
  const workspace = await call("GET", "/api/workspace", {
    cookie: stolen.cookie,
    member: stolen.member,
    origin: null,
  });
  assert.equal(workspace.response.statusCode, 401);
});

test("RT-06: auth mail is budgeted per recipient regardless of source IP", async () => {
  const dave = await verifiedMember("rt06");
  clearEmailSink();
  for (let i = 0; i < 8; i += 1) {
    const { response } = await call(
      "POST",
      "/api/auth/request-password-reset",
      {
        body: { email: dave.email, redirectTo: `${appOrigin}/#account` },
      },
    );
    assert.equal(response.statusCode, 200);
  }
  const delivered = inspectEmailSink().filter(
    (m) => m.email === dave.email && m.kind === "reset-password",
  );
  assert.equal(delivered.length, 5);
});

test("RT-07: workspace writes are budgeted per member", async () => {
  assert.ok(pool);
  const erin = await verifiedMember("rt07");
  let limited = 0;
  for (let i = 0; i < 125; i += 1) {
    const { response } = await call("PUT", "/api/workspace", {
      cookie: erin.cookie,
      member: erin.member,
      body: { data: {}, expectedRevision: 0, operationId: `rt07-${i}` },
    });
    if (response.statusCode === 429) {
      limited += 1;
      assert.equal(response.headers["retry-after"], "60");
    } else assert.equal(response.statusCode, 400);
  }
  assert.equal(limited, 5);
  // Another member's budget is independent.
  const frank = await verifiedMember("rt07b");
  const other = await call("PUT", "/api/workspace", {
    cookie: frank.cookie,
    member: frank.member,
    body: { data: {}, expectedRevision: 0, operationId: "rt07b" },
  });
  assert.equal(other.response.statusCode, 400);
  const key = throttleKey(config.authSecret, "budget-test", "x");
  assert.equal(await consumeBudget(pool, "budget-test", key, 1, 60), true);
  assert.equal(await consumeBudget(pool, "budget-test", key, 1, 60), false);
});

test("RT-08: unused Better Auth endpoints are unreachable (password oracle, raw IDs)", async () => {
  const gina = await verifiedMember("rt08");
  for (const [method, path, body] of [
    ["POST", "/api/auth/verify-password", { password: "guess guess guess" }],
    ["GET", "/api/auth/list-accounts", undefined],
    ["GET", "/api/auth/account-info", undefined],
    ["POST", "/api/auth/two-factor/get-totp-uri", { password }],
    ["POST", "/api/auth/two-factor/view-backup-codes", { userId: "x" }],
    ["POST", "/api/auth/revoke-session", { token: "x" }],
    ["POST", "/api/auth/sign-in/social", { provider: "github" }],
    ["GET", "/api/auth/error", undefined],
    ["GET", "/api/auth/sign-in/email", undefined],
  ] as const) {
    const { response } = await call(method, path, {
      cookie: gina.cookie,
      member: gina.member,
      ...(body ? { body } : { origin: null }),
    });
    assert.equal(response.statusCode, 404, `${method} ${path}`);
    assert.doesNotMatch(response.body, new RegExp(gina.member.slice(4, 16)));
  }
});

test("RT-09: profile fields are bounded and avatars cannot point anywhere", async () => {
  const hank = await verifiedMember("rt09");
  for (const body of [
    { name: "x".repeat(900_000) },
    { name: "x".repeat(61) },
    { name: "   " },
    { name: "Hank\u0000" },
    { image: "javascript:alert(1)" },
    { image: "https://tracker.example/p.png" },
  ]) {
    const { response } = await call("POST", "/api/auth/update-user", {
      cookie: hank.cookie,
      member: hank.member,
      body,
    });
    assert.equal(response.statusCode, 400, JSON.stringify(body).slice(0, 40));
  }
  const ok = await call("POST", "/api/auth/update-user", {
    cookie: hank.cookie,
    member: hank.member,
    body: { name: "Hank Hill" },
  });
  assert.equal(ok.response.statusCode, 200);
  const longSignUp = await call("POST", "/api/auth/sign-up/email", {
    body: {
      name: "y".repeat(61),
      email: `long-${suffix}@example.test`,
      password,
    },
  });
  assert.equal(longSignUp.response.statusCode, 400);
});

test("RT-10: email-change links never mint a session that skips password and TOTP", async () => {
  assert.ok(pool);
  const ivy = await verifiedMember("rt10");
  const newEmail = `ivy-new-${suffix}@example.test`;
  clearEmailSink();
  const start = await call("POST", "/api/auth/change-email", {
    cookie: ivy.cookie,
    member: ivy.member,
    body: { newEmail, callbackURL: `${appOrigin}/#account` },
  });
  assert.equal(start.response.statusCode, 200);
  const confirm = inspectEmailSink().find((m) => m.kind === "change-email");
  assert.ok(confirm, "approval link goes to the current address");
  const sessionsBefore = await pool.query(
    `SELECT count(*)::int AS n FROM "session" s JOIN "user" u ON u.id = s."userId" WHERE u.email = $1`,
    [ivy.email],
  );
  // Click every link in a cookie-less browser, as an attacker holding both
  // inboxes would.
  const confirmUrl = new URL(confirm.url);
  const first = await call(
    "GET",
    `${confirmUrl.pathname}${confirmUrl.search}`,
    {
      origin: null,
    },
  );
  assert.doesNotMatch(
    String(first.response.headers["set-cookie"] ?? ""),
    /session_token/,
  );
  const verifyNew = inspectEmailSink().find(
    (m) => m.kind === "verify-email" && m.email === newEmail,
  );
  assert.ok(verifyNew, "new address receives a verification link");
  const newUrl = new URL(verifyNew.url);
  const second = await call("GET", `${newUrl.pathname}${newUrl.search}`, {
    origin: null,
  });
  assert.ok([200, 302].includes(second.response.statusCode));
  assert.doesNotMatch(
    String(second.response.headers["set-cookie"] ?? ""),
    /session_token/,
  );
  const sessionsAfter = await pool.query(
    `SELECT count(*)::int AS n FROM "session" s JOIN "user" u ON u.id = s."userId" WHERE u.email = $1`,
    [newEmail],
  );
  assert.equal(sessionsAfter.rows[0].n, sessionsBefore.rows[0].n);
  // The email change itself still completed.
  const changed = await pool.query(`SELECT 1 FROM "user" WHERE email = $1`, [
    newEmail,
  ]);
  assert.equal(changed.rowCount, 1);
});

test("RT-11: sessions end after an absolute 30-day lifetime even when used", async () => {
  assert.ok(pool);
  const jade = await verifiedMember("rt11");
  const token = decodeURIComponent(jade.cookie.split("=")[1]).split(".")[0];
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() - interval '31 days' WHERE token = $1`,
    [token],
  );
  const workspace = await call("GET", "/api/workspace", {
    cookie: jade.cookie,
    member: jade.member,
    origin: null,
  });
  assert.equal(workspace.response.statusCode, 401);
  const session = await call("GET", "/api/auth/get-session", {
    cookie: jade.cookie,
    origin: null,
  });
  assert.equal(session.json, null);
  const row = await pool.query(`SELECT 1 FROM "session" WHERE token = $1`, [
    token,
  ]);
  assert.equal(row.rowCount, 0);
});

test("RT-12: delete-account callback cannot redirect off-origin", async () => {
  const { response } = await call(
    "GET",
    "/api/auth/delete-user/callback?token=bad&callbackURL=https%3A%2F%2Fevil.example%2Fx",
    { origin: null },
  );
  assert.equal(response.statusCode, 400);
  assert.equal(response.headers.location, undefined);
});

test("RT-13: auth bodies must be JSON so body-based checks cannot be skipped", async () => {
  assert.ok(app);
  // Found during purple-team review of RT-04: Better Auth accepts form-encoded
  // sign-ins, which bypassed the per-account throttle.
  for (const [path, payload] of [
    ["/api/auth/sign-in/email", "email=victim%40example.test&password=guess"],
    [
      "/api/auth/change-password",
      "currentPassword=a&newPassword=b&revokeOtherSessions=false",
    ],
    [
      "/api/auth/request-password-reset",
      "email=a%40b.test&redirectTo=https%3A%2F%2Fevil.example",
    ],
  ] as const) {
    for (const type of [
      "application/x-www-form-urlencoded",
      "text/plain",
      "multipart/form-data; boundary=x",
    ]) {
      const response: { statusCode: number } = await app.inject({
        method: "POST",
        url: path,
        headers: {
          "x-forma-worker-secret": workerSecret,
          "x-forma-client-ip": "198.51.100.250",
          origin: appOrigin,
          "content-type": type,
        },
        payload,
      });
      assert.equal(response.statusCode, 415, `${path} ${type}`);
    }
  }
  const arrayBody = await call("POST", "/api/auth/sign-in/email", {
    raw: JSON.stringify([{ email: "a@b.test", password }]),
  });
  assert.equal(arrayBody.response.statusCode, 415);
});

test("RT-14: concurrent guesses cannot exceed the per-account limit (purple-team F1)", async () => {
  assert.ok(pool);
  const kim = await verifiedMember("rt14");
  const results = await Promise.all(
    Array.from({ length: 60 }, (_, i) =>
      call("POST", "/api/auth/sign-in/email", {
        body: { email: kim.email, password: `parallel wrong guess ${i}` },
      }),
    ),
  );
  const wrong = results.filter((r) => r.response.statusCode === 401).length;
  const refused = results.filter((r) => r.response.statusCode === 429).length;
  assert.ok(wrong <= 10, `only 10 guesses may be judged, got ${wrong}`);
  assert.equal(wrong + refused, 60);
  const locked = await call("POST", "/api/auth/sign-in/email", {
    body: { email: kim.email, password },
  });
  assert.equal(locked.response.statusCode, 429);
});

test("RT-15: a stolen session cannot guess the password on signed-in endpoints (purple-team F3)", async () => {
  const lee = await verifiedMember("rt15");
  const statuses: number[] = [];
  for (let i = 0; i < 12; i += 1) {
    const { response } = await call("POST", "/api/auth/change-password", {
      cookie: lee.cookie,
      member: lee.member,
      body: {
        currentPassword: `not the password ${i}`,
        newPassword: "a replacement long FORMA passphrase",
      },
    });
    statuses.push(response.statusCode);
  }
  assert.deepEqual(statuses.slice(0, 10), Array(10).fill(400));
  assert.deepEqual(statuses.slice(10), [429, 429]);
  // The lock covers every password-checking endpoint for that member.
  for (const [path, body] of [
    ["/api/auth/delete-user", { password }],
    ["/api/auth/two-factor/enable", { password }],
  ] as const) {
    const { response } = await call("POST", path, {
      cookie: lee.cookie,
      member: lee.member,
      body,
    });
    assert.equal(response.statusCode, 429, path);
  }
  // A correct password through sign-in is unaffected (separate subject).
  await signIn(lee.email);
});

test("RT-16: the deletion callback refuses sessions past the absolute lifetime (purple-team F4)", async () => {
  assert.ok(pool);
  const mo = await verifiedMember("rt16");
  clearEmailSink();
  const start = await call("POST", "/api/auth/delete-user", {
    cookie: mo.cookie,
    member: mo.member,
    body: { callbackURL: `${appOrigin}/` },
  });
  assert.equal(start.response.statusCode, 200);
  const mail = inspectEmailSink().find((m) => m.kind === "delete-account");
  assert.ok(mail);
  const token = decodeURIComponent(mo.cookie.split("=")[1]).split(".")[0];
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() - interval '31 days' WHERE token = $1`,
    [token],
  );
  const link = new URL(mail.url);
  await call("GET", `${link.pathname}${link.search}`, {
    cookie: mo.cookie,
    origin: null,
  });
  const user = await pool.query(`SELECT 1 FROM "user" WHERE email = $1`, [
    mo.email,
  ]);
  assert.equal(user.rowCount, 1, "the account must survive an expired session");
});

test("RT-17: names cannot hide behind invisible or bidi characters (purple-team F5)", async () => {
  const nia = await verifiedMember("rt17");
  for (const name of ["\u200b\u200b", "\u202eevil", "a\u2028b", "x\ufeffy"]) {
    const { response } = await call("POST", "/api/auth/update-user", {
      cookie: nia.cookie,
      member: nia.member,
      body: { name },
    });
    assert.equal(response.statusCode, 400, JSON.stringify(name));
  }
  const emoji = await call("POST", "/api/auth/update-user", {
    cookie: nia.cookie,
    member: nia.member,
    body: { name: "\u{1f4aa}".repeat(31) },
  });
  assert.equal(emoji.response.statusCode, 200, "length counts code points");
});
