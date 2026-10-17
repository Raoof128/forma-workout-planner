import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp } from "../app.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import type { AppConfig } from "../config.js";
import type { WorkspaceData } from "../schema.js";

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_http_security_${suffix}`;
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

const apiHeaders = {
  "x-forma-worker-secret": workerSecret,
  "x-forma-client-ip": "192.0.2.23",
  origin: appOrigin,
};

before(async () => {
  // A missing database is a failed security run, never a silent skip.
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "TEST_DATABASE_URL is required; HTTP security tests require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  for (const name of [
    "0001-auth.sql",
    "0002-workspace.sql",
    "0003-security-throttle.sql",
    "0004-routine-programming.sql",
  ]) {
    const sql = await readFile(join(testDir, "..", "migrations", name), "utf8");
    await pool.query(sql);
  }
  app = await createApp({ pool, config });
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

function cookieFrom(response: { headers: Record<string, unknown> }): string {
  const header = response.headers["set-cookie"];
  const candidates = Array.isArray(header) ? header : [header];
  const sessionCookie = candidates
    .filter((value): value is string => typeof value === "string")
    .find((value) => /session_token=/i.test(value));
  assert.ok(sessionCookie, "Better Auth sign-in should set a session cookie");
  return sessionCookie.split(";", 1)[0];
}

async function registerVerifiedMember(name: string, email: string) {
  assert.ok(app);
  const password = "FORMA-http-integration-passphrase-2026";
  const signup = await app.inject({
    method: "POST",
    url: "/api/auth/sign-up/email",
    headers: { ...apiHeaders, "content-type": "application/json" },
    payload: { name, email, password },
  });
  assert.ok([200, 201].includes(signup.statusCode), signup.body);

  const message = inspectEmailSink()
    .filter((item) => item.kind === "verify-email" && item.email === email)
    .at(-1);
  assert.ok(
    message,
    "registration should send a verification email to the local sink",
  );
  const verificationUrl = new URL(message.url);
  assert.equal(verificationUrl.origin, appOrigin);
  const verified = await app.inject({
    method: "GET",
    url: `${verificationUrl.pathname}${verificationUrl.search}`,
    headers: {
      "x-forma-worker-secret": workerSecret,
      "x-forma-client-ip": "192.0.2.23",
    },
  });
  assert.ok([200, 302].includes(verified.statusCode), verified.body);

  const signin = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: { ...apiHeaders, "content-type": "application/json" },
    payload: { email, password, rememberMe: true },
  });
  assert.equal(signin.statusCode, 200, signin.body);
  const cookie = cookieFrom(signin);
  const session = await app.inject({
    method: "GET",
    url: "/api/auth/get-session",
    headers: { ...apiHeaders, cookie },
  });
  assert.equal(session.statusCode, 200, session.body);
  const memberRef = session.json().user.id as string;
  assert.match(memberRef, /^mem_[A-Za-z0-9_-]+$/);
  return { cookie, memberRef, password };
}

function withCookie(cookie: string, origin = appOrigin, memberRef?: string) {
  return {
    ...apiHeaders,
    cookie,
    origin,
    ...(memberRef ? { "x-forma-member": memberRef } : {}),
  };
}

test("HTTP boundary rejects missing or forged gateway credentials and hostile mutation origins", async () => {
  assert.ok(app);
  const missingGateway = await app.inject({
    method: "GET",
    url: "/api/workspace",
  });
  assert.equal(missingGateway.statusCode, 401);
  assert.deepEqual(missingGateway.json(), { error: "unauthorized" });

  const forgedGateway = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: { "x-forma-worker-secret": "attacker-controlled-value" },
  });
  assert.equal(forgedGateway.statusCode, 401);

  const hostileOrigin = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers: {
      ...apiHeaders,
      origin: "https://attacker.example",
      "content-type": "application/json",
    },
    payload: {
      email: "nobody@example.test",
      password: "not-a-real-password",
    },
  });
  assert.equal(hostileOrigin.statusCode, 403);
  assert.deepEqual(hostileOrigin.json(), { error: "forbidden" });
});

test("two real sessions cannot read, mutate, or export another member's workspace", async () => {
  assert.ok(app);
  clearEmailSink();
  const a = await registerVerifiedMember(
    "Security Alpha",
    `alpha-${suffix}@example.test`,
  );
  const b = await registerVerifiedMember(
    "Security Beta",
    `beta-${suffix}@example.test`,
  );

  const unauthenticated = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: apiHeaders,
  });
  assert.equal(unauthenticated.statusCode, 401);
  assert.equal(
    unauthenticated.headers["cache-control"]?.includes("no-store"),
    true,
  );
  assert.equal(
    JSON.stringify(unauthenticated.json()).includes("Security Alpha"),
    false,
  );

  const malformedCookie = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(
      "forma.session_token=forged.invalid",
      appOrigin,
      a.memberRef,
    ),
  });
  assert.equal(malformedCookie.statusCode, 401);
  assert.equal("data" in malformedCookie.json(), false);

  const workspaceAResponse = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(a.cookie, appOrigin, a.memberRef),
  });
  const workspaceBResponse = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(b.cookie, appOrigin, b.memberRef),
  });
  assert.equal(workspaceAResponse.statusCode, 200, workspaceAResponse.body);
  assert.equal(workspaceBResponse.statusCode, 200, workspaceBResponse.body);
  assert.equal(
    workspaceAResponse.headers["cache-control"]?.includes("no-store"),
    true,
  );
  assert.equal(
    workspaceBResponse.headers["cache-control"]?.includes("no-store"),
    true,
  );
  const missingBinding = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(a.cookie),
  });
  assert.equal(missingBinding.statusCode, 409);
  assert.deepEqual(missingBinding.json(), { error: "account_changed" });

  const workspaceA = workspaceAResponse.json() as {
    data: WorkspaceData;
    revision: number;
  };
  const workspaceB = workspaceBResponse.json() as {
    data: WorkspaceData;
    revision: number;
  };
  assert.equal(workspaceA.data.profile.name, "Security Alpha");
  assert.equal(workspaceB.data.profile.name, "Security Beta");
  assert.notEqual(workspaceA.data.profile.name, workspaceB.data.profile.name);

  const staleTabRead = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(b.cookie, appOrigin, a.memberRef),
  });
  const staleTabExport = await app.inject({
    method: "GET",
    url: "/api/workspace/export",
    headers: withCookie(b.cookie, appOrigin, a.memberRef),
  });
  const staleTabWrite = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: {
      ...withCookie(b.cookie, appOrigin, a.memberRef),
      "content-type": "application/json",
    },
    payload: {
      data: {
        ...workspaceA.data,
        profile: { ...workspaceA.data.profile, goal: 1 },
      },
      expectedRevision: workspaceA.revision,
      operationId: `stale-tab-${suffix}`,
    },
  });
  const staleTabSessions = await app.inject({
    method: "GET",
    url: "/api/account/sessions",
    headers: withCookie(b.cookie, appOrigin, a.memberRef),
  });
  const staleSensitiveAuth = await app.inject({
    method: "POST",
    url: "/api/auth/update-user",
    headers: {
      ...withCookie(b.cookie, appOrigin, a.memberRef),
      "content-type": "application/json",
    },
    payload: { name: "Attacker edit" },
  });
  for (const response of [
    staleTabRead,
    staleTabExport,
    staleTabWrite,
    staleTabSessions,
    staleSensitiveAuth,
  ]) {
    assert.equal(response.statusCode, 409);
    assert.deepEqual(response.json(), { error: "account_changed" });
    assert.equal("data" in response.json(), false);
  }

  const csrf = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: {
      ...withCookie(a.cookie, "https://attacker.example", a.memberRef),
      "content-type": "application/json",
    },
    payload: {
      data: {
        ...workspaceA.data,
        profile: { ...workspaceA.data.profile, goal: 1 },
      },
      expectedRevision: workspaceA.revision,
      operationId: `csrf-${suffix}`,
    },
  });
  assert.equal(csrf.statusCode, 403);

  const ownershipForgery = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: {
      ...withCookie(b.cookie, appOrigin, b.memberRef),
      "content-type": "application/json",
    },
    payload: {
      data: {
        ...workspaceB.data,
        profile: { ...workspaceB.data.profile, goal: 7 },
      },
      expectedRevision: workspaceB.revision,
      operationId: `owner-forgery-${suffix}`,
      ownerId: "member-a",
      userId: "member-a",
    },
  });
  assert.equal(ownershipForgery.statusCode, 400);

  const changedA = {
    ...workspaceA.data,
    profile: { ...workspaceA.data.profile, goal: 5 },
    routines: workspaceA.data.routines.map((routine, index) =>
      index === 0 ? { ...routine, name: "Alpha private routine" } : routine,
    ),
  };
  const savedA = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: {
      ...withCookie(a.cookie, appOrigin, a.memberRef),
      "content-type": "application/json",
    },
    payload: {
      data: changedA,
      expectedRevision: workspaceA.revision,
      operationId: `alpha-save-${suffix}`,
    },
  });
  assert.equal(savedA.statusCode, 200, savedA.body);

  const latestA = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(a.cookie, appOrigin, a.memberRef),
  });
  const latestB = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(b.cookie, appOrigin, b.memberRef),
  });
  assert.equal(latestA.json().data.profile.goal, 5);
  assert.equal(latestA.json().data.routines[0].name, "Alpha private routine");
  assert.equal(latestB.json().data.profile.name, "Security Beta");
  assert.equal(
    latestB.json().data.routines[0].name,
    workspaceB.data.routines[0].name,
  );
  assert.equal(latestB.json().data.profile.goal, workspaceB.data.profile.goal);

  const exportA = await app.inject({
    method: "GET",
    url: "/api/workspace/export",
    headers: withCookie(a.cookie, appOrigin, a.memberRef),
  });
  const exportB = await app.inject({
    method: "GET",
    url: "/api/workspace/export",
    headers: withCookie(b.cookie, appOrigin, b.memberRef),
  });
  assert.equal(exportA.statusCode, 200);
  assert.equal(exportB.statusCode, 200);
  assert.equal(exportA.headers["cache-control"]?.includes("no-store"), true);
  assert.equal(exportA.json().profile.name, "Security Alpha");
  assert.equal(JSON.stringify(exportA.json()).includes("Security Beta"), false);
  assert.equal(exportB.json().profile.name, "Security Beta");

  const replay = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: {
      ...withCookie(a.cookie, appOrigin, a.memberRef),
      "content-type": "application/json",
    },
    payload: {
      data: changedA,
      expectedRevision: workspaceA.revision,
      operationId: `alpha-save-${suffix}`,
    },
  });
  assert.equal(replay.statusCode, 200);
  assert.deepEqual(replay.json(), savedA.json());

  const token = a.cookie.split("=", 2)[1];
  const revoked = await app.inject({
    method: "POST",
    url: "/api/auth/sign-out",
    headers: {
      ...withCookie(a.cookie, appOrigin, a.memberRef),
      "content-type": "application/json",
    },
    payload: {},
  });
  assert.equal(revoked.statusCode, 200, revoked.body);
  assert.ok(token);
  const afterLogout = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(a.cookie, appOrigin, a.memberRef),
  });
  assert.equal(afterLogout.statusCode, 401);

  // The second synthetic member remains usable after revoking A's session.
  const remainsIsolated = await app.inject({
    method: "GET",
    url: "/api/workspace",
    headers: withCookie(b.cookie, appOrigin, b.memberRef),
  });
  assert.equal(remainsIsolated.statusCode, 200);
  assert.equal(remainsIsolated.json().data.profile.name, "Security Beta");
});
