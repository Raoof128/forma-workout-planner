// Real-PostgreSQL regressions for the November 2026 backend audit
// (docs/audits/backend-2026-11/). Each test fails on the code before the fix.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp, memberReference } from "../app.js";
import { signInThrottleKey } from "../auth.js";
import { COACH_DATA_PATH } from "../coachRoutes.js";
import { loadConfig, type AppConfig } from "../config.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import { migrate } from "../migrate.js";
import { workspacePutSchema } from "../schema.js";
import { SIGN_IN_SCOPE } from "../throttle.js";
import {
  exportWorkspace,
  getWorkspace,
  patchWorkspace,
  putWorkspace,
  UnconfirmedActiveRemoval,
} from "../workspace.js";
import { freshData } from "../../src/storage.js";

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_backend_hardening_${suffix}`;
const appOrigin = "http://127.0.0.1:3001";
const workerSecret = "test-worker-shared-secret-with-at-least-32-bytes";
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: "test-auth-secret-with-at-least-32-characters",
  workerSharedSecret: workerSecret,
  emailFrom: "FORMA <accounts@test.local>",
  emailSinkEnabled: true,
};
const apiHeaders = {
  "x-forma-worker-secret": workerSecret,
  "x-forma-client-ip": "192.0.2.61",
  origin: appOrigin,
};
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
let app: Awaited<ReturnType<typeof createApp>> | null = null;
// Fails the next query that starts with this text, once.
let failNextQuery: string | null = null;

before(async () => {
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "TEST_DATABASE_URL is required; backend hardening tests require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  for (const name of [
    "0001-auth.sql",
    "0002-workspace.sql",
    "0003-security-throttle.sql",
    "0004-routine-programming.sql",
    "0005-coach-tokens.sql",
    "0006-coach-token-scope.sql",
  ])
    await pool.query(
      await readFile(join(testDir, "..", "migrations", name), "utf8"),
    );
  const injecting = new Proxy(pool, {
    get(target, property) {
      if (property === "query")
        return (...args: unknown[]) => {
          const text =
            typeof args[0] === "string"
              ? args[0]
              : (args[0] as { text?: string })?.text;
          if (failNextQuery && text?.startsWith(failNextQuery)) {
            failNextQuery = null;
            return Promise.reject(new Error("injected failure"));
          }
          return (target.query as (...a: unknown[]) => unknown)(...args);
        };
      const value = Reflect.get(target, property);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
  app = await createApp({ pool: injecting, config });
  await app.ready();
});

after(async () => {
  if (app) await app.close();
  if (pool) await pool.end();
  if (adminPool) {
    await adminPool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await adminPool.end();
  }
  clearEmailSink();
});

const password = "FORMA-backend-hardening-passphrase-2026";

let nextIp = 10;
async function registerMember(name: string) {
  assert.ok(app && pool);
  // Better Auth limits sign-in per IP; each synthetic member gets its own.
  const ip = `198.51.100.${nextIp++}`;
  const headers = { ...apiHeaders, "x-forma-client-ip": ip };
  const email = `${name.toLowerCase()}-${suffix}@example.test`;
  const signup = await app.inject({
    method: "POST",
    url: "/api/auth/sign-up/email",
    headers: { ...headers, "content-type": "application/json" },
    payload: { name, email, password },
  });
  assert.ok([200, 201].includes(signup.statusCode), signup.body);
  const message = inspectEmailSink()
    .filter((item) => item.kind === "verify-email" && item.email === email)
    .at(-1);
  assert.ok(message);
  const link = new URL(message.url);
  await app.inject({
    method: "GET",
    url: `${link.pathname}${link.search}`,
    headers: {
      "x-forma-worker-secret": workerSecret,
      "x-forma-client-ip": ip,
    },
  });
  const signin = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: { ...headers, "content-type": "application/json" },
    payload: { email, password },
  });
  assert.equal(signin.statusCode, 200, signin.body);
  const header = signin.headers["set-cookie"];
  const cookie = (Array.isArray(header) ? header : [header])
    .filter((value): value is string => typeof value === "string")
    .find((value) => /session_token=/i.test(value))!
    .split(";", 1)[0];
  const user = await pool.query<{ id: string }>(
    `SELECT id FROM "user" WHERE email = $1`,
    [email],
  );
  return { email, cookie, userId: user.rows[0].id };
}

test("readiness reports the database, while liveness stays process-only", async () => {
  assert.ok(app && databaseUrl);
  const ready = await app.inject({ method: "GET", url: "/readyz" });
  assert.equal(ready.statusCode, 200);
  assert.deepEqual(ready.json(), { status: "ready" });

  const deadPool = new Pool({ connectionString: databaseUrl });
  const deadApp = await createApp({ pool: deadPool, config });
  await deadApp.ready();
  await deadPool.end();
  try {
    const down = await deadApp.inject({ method: "GET", url: "/readyz" });
    assert.equal(down.statusCode, 503);
    assert.deepEqual(down.json(), { status: "unavailable" });
    const live = await deadApp.inject({ method: "GET", url: "/healthz" });
    assert.equal(live.statusCode, 200);
  } finally {
    await deadApp.close();
  }
});

test("a session store outage is 503, not a sign-out 401", async () => {
  assert.ok(databaseUrl);
  const member = await registerMember("Outage");
  const outagePool = new Pool({
    connectionString: databaseUrl,
    options: `-c search_path=${schema}`,
  });
  const outageApp = await createApp({ pool: outagePool, config });
  await outageApp.ready();
  await outagePool.end();
  try {
    const response = await outageApp.inject({
      method: "GET",
      url: "/api/workspace",
      headers: {
        ...apiHeaders,
        cookie: member.cookie,
        "x-forma-member": memberReference(member.userId, config.authSecret),
      },
    });
    assert.equal(response.statusCode, 503);
    assert.equal(response.json().error, "temporarily_unavailable");
    assert.equal(response.headers["retry-after"], "5");
  } finally {
    await outageApp.close();
  }
});

test("the origin refuses an explicit cross-site coach edit even without Origin", async () => {
  assert.ok(app);
  const headers = {
    "x-forma-worker-secret": workerSecret,
    "x-forma-client-ip": "192.0.2.61",
    "content-type": "application/json",
  };
  const crossSite = await app.inject({
    method: "PATCH",
    url: COACH_DATA_PATH,
    headers: { ...headers, "sec-fetch-site": "cross-site" },
    payload: {},
  });
  assert.equal(crossSite.statusCode, 403);
  const tool = await app.inject({
    method: "PATCH",
    url: COACH_DATA_PATH,
    headers,
    payload: {},
  });
  // A server-side tool (no Origin, no Sec-Fetch) reaches token checks.
  assert.equal(tool.statusCode, 401);
});

test("a server failure after a reserved sign-in attempt refunds it", async () => {
  assert.ok(app && pool);
  const member = await registerMember("Refund");
  const key = signInThrottleKey(config.authSecret, member.email);
  // The password is right, but clearing the counter fails afterwards.
  failNextQuery = "DELETE FROM security_throttle WHERE scope = $1";
  const response = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: { ...apiHeaders, "content-type": "application/json" },
    payload: { email: member.email, password },
  });
  assert.equal(failNextQuery, null, "the injected failure was reached");
  assert.equal(response.statusCode, 500);
  const row = await pool.query<{ consecutive_failures: number }>(
    `SELECT consecutive_failures FROM security_throttle
      WHERE scope = $1 AND key_digest = $2`,
    [SIGN_IN_SCOPE, key],
  );
  assert.equal(row.rows[0]?.consecutive_failures ?? 0, 0);
});

test("member saves replay by canonical content, including pre-upgrade ledger rows", async () => {
  assert.ok(pool);
  const member = await registerMember("Replay");
  const start = await getWorkspace(pool, member.userId, "Replay");
  const data = { ...start.data, profile: { ...start.data.profile, goal: 6 } };
  const operationId = randomUUID();
  const first = await putWorkspace(pool, member.userId, "Replay", {
    data,
    expectedRevision: start.revision,
    operationId,
  });
  // A retry whose JSON keys arrive in another order is the same operation.
  const reversed = (value: unknown): unknown =>
    Array.isArray(value)
      ? value.map(reversed)
      : value && typeof value === "object"
        ? Object.fromEntries(
            Object.entries(value)
              .reverse()
              .map(([key, item]) => [key, reversed(item)]),
          )
        : value;
  const retried = await putWorkspace(
    pool,
    member.userId,
    "Replay",
    reversed({ data, expectedRevision: start.revision, operationId }),
  );
  assert.equal(retried.revision, first.revision);

  // An operation recorded by the previous release used the sorted-key hash.
  const legacyOperation = randomUUID();
  const next = { ...data, profile: { ...data.profile, goal: 3 } };
  const legacy = await putWorkspace(pool, member.userId, "Replay", {
    data: next,
    expectedRevision: first.revision,
    operationId: legacyOperation,
  });
  const stable = (value: unknown): string =>
    Array.isArray(value)
      ? `[${value.map(stable).join(",")}]`
      : value && typeof value === "object"
        ? `{${Object.keys(value)
            .sort()
            .map(
              (key) =>
                `${JSON.stringify(key)}:${stable((value as Record<string, unknown>)[key])}`,
            )
            .join(",")}}`
        : JSON.stringify(value);
  const parsed = workspacePutSchema.parse({
    data: next,
    expectedRevision: first.revision,
    operationId: legacyOperation,
  }).data;
  const { createHash } = await import("node:crypto");
  const legacyHash = createHash("sha256")
    .update(
      stable({
        data: { ...parsed, revision: 0 },
        expectedRevision: first.revision,
      }),
    )
    .digest("hex");
  await pool.query(
    `UPDATE member_workspace_operations SET request_hash = $3
      WHERE owner_id = $1 AND operation_id = $2`,
    [member.userId, legacyOperation, legacyHash],
  );
  const replayed = await putWorkspace(pool, member.userId, "Replay", {
    data: next,
    expectedRevision: first.revision,
    operationId: legacyOperation,
  });
  assert.equal(replayed.revision, legacy.revision);
});

test("a coach edit cannot silently discard the workout in progress", async () => {
  assert.ok(pool);
  const member = await registerMember("Active");
  const start = await getWorkspace(pool, member.userId, "Active");
  const active = {
    id: randomUUID(),
    routineId: start.data.routines[0].id,
    name: "In progress",
    startedAt: Date.now(),
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        exerciseId: "bench",
        sets: [{ weight: 60, reps: 8, done: true, rpe: null }],
      },
    ],
  };
  const withActive = await putWorkspace(pool, member.userId, "Active", {
    data: { ...start.data, active },
    expectedRevision: start.revision,
    operationId: randomUUID(),
  });
  await assert.rejects(
    patchWorkspace(pool, member.userId, "Active", {
      expectedRevision: withActive.revision,
      operationId: randomUUID(),
      changes: { active: null },
    }),
    UnconfirmedActiveRemoval,
  );
  const unchanged = await getWorkspace(pool, member.userId, "Active");
  assert.equal(unchanged.revision, withActive.revision);
  assert.equal(unchanged.data.active?.id, active.id);

  // Finishing it into history keeps its id: not a removal.
  const finished = await patchWorkspace(pool, member.userId, "Active", {
    expectedRevision: withActive.revision,
    operationId: randomUUID(),
    changes: {
      active: null,
      history: [
        { ...active, date: new Date().toISOString(), duration: 600 },
        ...unchanged.data.history,
      ],
    },
  });
  assert.equal(finished.revision, withActive.revision + 1);

  // An explicit confirmation may discard one.
  const again = await putWorkspace(pool, member.userId, "Active", {
    data: {
      ...(await getWorkspace(pool, member.userId)).data,
      active: { ...active, id: randomUUID() },
    },
    expectedRevision: finished.revision,
    operationId: randomUUID(),
  });
  const discarded = await patchWorkspace(pool, member.userId, "Active", {
    expectedRevision: again.revision,
    operationId: randomUUID(),
    changes: { active: null },
    removesActive: true,
  });
  assert.equal(discarded.revision, again.revision + 1);
});

test("export returns stored data even when a newer validator rejects it", async () => {
  assert.ok(app && pool);
  const member = await registerMember("Export");
  await getWorkspace(pool, member.userId, "Export");
  // Simulate data saved under an older, looser bound.
  await pool.query(
    `UPDATE member_workspace
        SET data = jsonb_set(data, '{profile,goal}', '99'::jsonb)
      WHERE owner_id = $1`,
    [member.userId],
  );
  const raw = (await exportWorkspace(pool, member.userId)) as {
    profile: { goal: number };
  };
  assert.equal(raw.profile.goal, 99);
  const response = await app.inject({
    method: "GET",
    url: "/api/workspace/export",
    headers: {
      ...apiHeaders,
      cookie: member.cookie,
      "x-forma-member": memberReference(member.userId, config.authSecret),
    },
  });
  assert.equal(response.statusCode, 200);
  assert.equal(JSON.parse(response.body).profile.goal, 99);
});

test("workspace validation reports the real invariant that failed", () => {
  const data = freshData();
  const routine = data.routines[0];
  const tooMany = {
    ...data,
    routines: Array.from({ length: 201 }, () => ({
      ...routine,
      id: randomUUID(),
    })),
  };
  const result = workspacePutSchema.safeParse({
    data: tooMany,
    expectedRevision: 0,
    operationId: "bounds",
  });
  assert.equal(result.success, false);
  const messages = result.error!.issues.map((issue) => issue.message);
  assert.ok(
    messages.some((message) => /at most/.test(message)),
    messages.join("; "),
  );
  assert.ok(
    !messages.some((message) => /already present in history/.test(message)),
  );
});

test("production refuses template, reused and low-entropy secrets, and an implicit environment", () => {
  const base = {
    NODE_ENV: "production",
    APP_ORIGIN: "https://forma.example",
    AUTH_SECRET: "q8Vt2LmZr6Xc1NbH4sKdY7pWf0JgUe3A",
    ORIGIN_SHARED_SECRET: "M5nB9vC2xZ7aS4dF1gH6jK3lP8oI0uYt",
    EMAIL_FROM: "FORMA <accounts@forma.example>",
    CLOUDFLARE_EMAIL_API_TOKEN: "synthetic-token",
    CLOUDFLARE_ACCOUNT_ID: "0123456789abcdef0123456789abcdef",
  };
  assert.equal(loadConfig(base).environment, "production");
  assert.throws(
    () =>
      loadConfig({
        ...base,
        AUTH_SECRET: "REPLACE_WITH_AT_LEAST_32_RANDOM_BYTES",
      }),
    /placeholder/,
  );
  assert.throws(
    () => loadConfig({ ...base, ORIGIN_SHARED_SECRET: base.AUTH_SECRET }),
    /must differ/,
  );
  assert.throws(
    () => loadConfig({ ...base, AUTH_SECRET: "ab".repeat(20) }),
    /random value/,
  );
  const implicit: NodeJS.ProcessEnv = { ...base };
  delete implicit.NODE_ENV;
  assert.throws(() => loadConfig(implicit), /NODE_ENV/);
  // Local development over http keeps its default.
  assert.equal(
    loadConfig({
      ...implicit,
      APP_ORIGIN: "http://127.0.0.1:5173",
    }).environment,
    "development",
  );
});

// Migration runner: each case gets its own throwaway database.
async function withDatabase(run: (url: string) => Promise<void>) {
  assert.ok(adminPool && databaseUrl);
  const name = `forma_migrate_${randomUUID().replaceAll("-", "").slice(0, 16)}`;
  await adminPool.query(`CREATE DATABASE ${name}`);
  const url = new URL(databaseUrl);
  url.pathname = `/${name}`;
  try {
    await run(url.toString());
  } finally {
    // Wait for every connection to close rather than terminating them: a
    // forced drop can hit a socket pg has not finished closing, which then
    // surfaces as an uncaught error in whichever test is running.
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const open = await adminPool.query(
        "SELECT 1 FROM pg_stat_activity WHERE datname = $1",
        [name],
      );
      if (!open.rowCount) break;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    await adminPool.query(`DROP DATABASE IF EXISTS ${name}`);
  }
}

async function fixtures(files: Record<string, string>) {
  const dir = await mkdtemp(join(tmpdir(), "forma-migrations-"));
  for (const [name, sql] of Object.entries(files))
    await writeFile(join(dir, name), sql);
  return dir;
}

test("concurrent migration runners apply each migration once", async () => {
  const dir = await fixtures({
    "0001-a.sql": "CREATE TABLE a (id int)",
    "0002-b.sql": "CREATE TABLE b (id int)",
  });
  try {
    await withDatabase(async (url) => {
      await Promise.all([
        migrate(url, { migrationsDir: dir }),
        migrate(url, { migrationsDir: dir }),
      ]);
      const check = new Pool({ connectionString: url });
      const ledger = await check.query(
        "SELECT name FROM forma_schema_migrations ORDER BY name",
      );
      await check.end();
      assert.deepEqual(
        ledger.rows.map((row) => row.name),
        ["0001-a.sql", "0002-b.sql"],
      );
    });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a migration waiting on a table lock fails fast instead of stalling traffic", async () => {
  const dir = await fixtures({ "0001-a.sql": "CREATE TABLE a (id int)" });
  try {
    await withDatabase(async (url) => {
      await migrate(url, { migrationsDir: dir });
      await writeFile(
        join(dir, "0002-alter.sql"),
        "ALTER TABLE a ADD COLUMN note text",
      );
      const reader = new pg.Client({ connectionString: url });
      await reader.connect();
      await reader.query("BEGIN");
      await reader.query("SELECT * FROM a");
      const started = Date.now();
      try {
        await assert.rejects(
          migrate(url, { migrationsDir: dir, lockTimeout: "300ms" }),
          /lock timeout/,
        );
        assert.ok(Date.now() - started < 10_000);
      } finally {
        await reader.query("ROLLBACK");
        await reader.end();
      }
      const check = new Pool({ connectionString: url });
      const ledger = await check.query(
        "SELECT name FROM forma_schema_migrations WHERE name = '0002-alter.sql'",
      );
      await check.end();
      assert.equal(ledger.rowCount, 0);
    });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("a release that lost or misordered a migration stops before changing anything", async () => {
  const dir = await fixtures({
    "0001-a.sql": "CREATE TABLE a (id int)",
    "0003-c.sql": "CREATE TABLE c (id int)",
  });
  try {
    await withDatabase(async (url) => {
      await migrate(url, { migrationsDir: dir });
      await writeFile(join(dir, "0002-late.sql"), "CREATE TABLE late (id int)");
      await assert.rejects(
        migrate(url, { migrationsDir: dir }),
        /sorts before applied/,
      );
      await rm(join(dir, "0002-late.sql"));
      await rm(join(dir, "0003-c.sql"));
      await assert.rejects(
        migrate(url, { migrationsDir: dir }),
        /missing from this release/,
      );
    });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

async function plantCredentials(userId: string) {
  assert.ok(pool);
  const tokenId = randomUUID().replaceAll("-", "");
  await pool.query(
    `INSERT INTO member_coach_token
       (id, owner_id, token_digest, label, expires_at, scope)
     VALUES ($1, $2, $3, 'Planted', now() + interval '30 days', 'full')`,
    [tokenId, userId, randomUUID().replaceAll("-", "").padEnd(64, "0")],
  );
  await pool.query(
    `INSERT INTO verification (id, identifier, value, "expiresAt", "createdAt", "updatedAt")
     VALUES ($1, $2, $3, now() + interval '30 days', now(), now())`,
    [randomUUID(), `trust-device-${randomUUID()}`, userId],
  );
  return tokenId;
}

async function credentialState(userId: string, tokenId: string) {
  assert.ok(pool);
  const token = await pool.query<{ revoked: boolean }>(
    `SELECT revoked_at IS NOT NULL AS revoked FROM member_coach_token WHERE id = $1`,
    [tokenId],
  );
  const trust = await pool.query(
    `SELECT 1 FROM verification
      WHERE starts_with(identifier, 'trust-device-') AND value = $1`,
    [userId],
  );
  return { revoked: token.rows[0].revoked, trusted: trust.rowCount ?? 0 };
}

test("changing the password and signing out everywhere end coach tokens and trusted devices", async () => {
  assert.ok(app);
  const changer = await registerMember("Changer");
  const bystander = await registerMember("Bystander");
  const changerToken = await plantCredentials(changer.userId);
  const bystanderToken = await plantCredentials(bystander.userId);
  const memberHeaders = (member: typeof changer) => ({
    ...apiHeaders,
    "x-forma-client-ip": "198.51.100.200",
    cookie: member.cookie,
    "x-forma-member": memberReference(member.userId, config.authSecret),
    "content-type": "application/json",
  });

  const changed = await app.inject({
    method: "POST",
    url: "/api/auth/change-password",
    headers: memberHeaders(changer),
    payload: {
      currentPassword: password,
      newPassword: "FORMA-backend-hardening-new-passphrase-2026",
    },
  });
  assert.equal(changed.statusCode, 200, changed.body);
  assert.deepEqual(await credentialState(changer.userId, changerToken), {
    revoked: true,
    trusted: 0,
  });
  assert.deepEqual(await credentialState(bystander.userId, bystanderToken), {
    revoked: false,
    trusted: 1,
  });

  const signedOut = await app.inject({
    method: "POST",
    url: "/api/account/sessions/revoke-all",
    headers: memberHeaders(bystander),
    payload: {},
  });
  assert.equal(signedOut.statusCode, 200, signedOut.body);
  assert.deepEqual(await credentialState(bystander.userId, bystanderToken), {
    revoked: true,
    trusted: 0,
  });
});
