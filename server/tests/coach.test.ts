import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp } from "../app.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import type { AppConfig } from "../config.js";
import type { WorkspaceData } from "../schema.js";
import {
  COACH_TOKEN_LIFETIME_DAYS,
  MAX_ACTIVE_COACH_TOKENS,
} from "../coachTokens.js";
import { COACH_FAILURE_LIMIT, COACH_READ_LIMIT } from "../coachRoutes.js";

// Real-PostgreSQL coverage for read-only coach tokens: minting needs a fresh
// member session, the bearer route sees only its owner's training data, and
// guessing is budgeted.

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_coach_${suffix}`;
const appOrigin = "https://coach.forma.test";
const workerSecret = `coach-worker-secret-${suffix}`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `coach-auth-secret-${suffix}`,
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

const gateway = (ip = "203.0.113.5") => ({
  "x-forma-worker-secret": workerSecret,
  "x-forma-client-ip": ip,
});

before(async () => {
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "TEST_DATABASE_URL is required; coach token tests require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  // Apply every versioned migration in order, like the runner does, so this
  // suite follows the workspace schema whatever version is current.
  const migrationsDir = join(testDir, "..", "migrations");
  for (const name of (await readdir(migrationsDir))
    .filter((entry) => entry.endsWith(".sql"))
    .sort()) {
    await pool.query(await readFile(join(migrationsDir, name), "utf8"));
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

type Member = { cookie: string; memberRef: string; email: string };

async function registerMember(name: string): Promise<Member> {
  assert.ok(app);
  const email = `${name.toLowerCase()}-${suffix}@example.test`;
  const ip = `198.51.100.${(ipCounter += 1)}`;
  const headers = {
    ...gateway(ip),
    origin: appOrigin,
    "content-type": "application/json",
  };
  const signup = await app.inject({
    method: "POST",
    url: "/api/auth/sign-up/email",
    headers,
    payload: { name, email, password },
  });
  assert.ok([200, 201].includes(signup.statusCode), signup.body);
  const message = inspectEmailSink()
    .filter((item) => item.kind === "verify-email" && item.email === email)
    .at(-1);
  assert.ok(message);
  const link = new URL(message.url);
  const verified = await app.inject({
    method: "GET",
    url: `${link.pathname}${link.search}`,
    headers: gateway(ip),
  });
  assert.ok([200, 302].includes(verified.statusCode), verified.body);
  const signin = await app.inject({
    method: "POST",
    url: "/api/auth/sign-in/email",
    headers,
    payload: { email, password, rememberMe: true },
  });
  assert.equal(signin.statusCode, 200, signin.body);
  const setCookie = signin.headers["set-cookie"];
  const cookie = (Array.isArray(setCookie) ? setCookie : [setCookie])
    .filter((value): value is string => typeof value === "string")
    .find((value) => /session_token=/i.test(value))!
    .split(";", 1)[0];
  const session = await app.inject({
    method: "GET",
    url: "/api/auth/get-session",
    headers: { ...gateway(ip), cookie },
  });
  assert.equal(session.statusCode, 200, session.body);
  return { cookie, memberRef: session.json().user.id as string, email };
}

const asMember = (member: Member, extra: Record<string, string> = {}) => ({
  ...gateway(),
  origin: appOrigin,
  cookie: member.cookie,
  "x-forma-member": member.memberRef,
  ...extra,
});

async function mint(member: Member, label: unknown) {
  assert.ok(app);
  return app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: { ...asMember(member), "content-type": "application/json" },
    payload: { label },
  });
}

async function coachRead(
  authorization: string | undefined,
  query = "",
  ip = "203.0.113.77",
) {
  assert.ok(app);
  return app.inject({
    method: "GET",
    url: `/api/coach/workspace${query}`,
    headers: {
      ...gateway(ip),
      ...(authorization ? { authorization } : {}),
    },
  });
}

test("minting needs a fresh member session, a valid label, and stays within the active-token cap", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const alpha = await registerMember("Alpha");

  const empty = await app.inject({
    method: "GET",
    url: "/api/account/coach-tokens",
    headers: asMember(alpha),
  });
  assert.equal(empty.statusCode, 200);
  assert.deepEqual(empty.json(), []);
  assert.equal(empty.headers["cache-control"]?.includes("no-store"), true);

  const anonymous = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: {
      ...gateway(),
      origin: appOrigin,
      "content-type": "application/json",
    },
    payload: { label: "Nobody" },
  });
  assert.equal(anonymous.statusCode, 401);

  const unbound = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: {
      ...gateway(),
      origin: appOrigin,
      cookie: alpha.cookie,
      "content-type": "application/json",
    },
    payload: { label: "No member reference" },
  });
  assert.equal(unbound.statusCode, 409);
  assert.deepEqual(unbound.json(), { error: "account_changed" });

  const crossOrigin = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: {
      ...asMember(alpha, { origin: "https://attacker.example" }),
      "content-type": "application/json",
    },
    payload: { label: "CSRF" },
  });
  assert.equal(crossOrigin.statusCode, 403);

  for (const label of ["", "x".repeat(61), "zero​width", 42, undefined]) {
    const invalid = await mint(alpha, label);
    assert.equal(invalid.statusCode, 400, String(label));
    assert.deepEqual(invalid.json(), { error: "invalid_label" });
  }
  const notAnObject = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: { ...asMember(alpha), "content-type": "application/json" },
    payload: ["Claude"],
  });
  assert.equal(notAnObject.statusCode, 400);

  const issued = await mint(alpha, "  Claude coach  ");
  assert.equal(issued.statusCode, 201, issued.body);
  const body = issued.json() as {
    token: string;
    record: {
      id: string;
      label: string;
      createdAt: string;
      expiresAt: string;
      lastUsedAt: string | null;
    };
  };
  assert.match(body.token, /^forma_coach_[A-Za-z0-9_-]{43}$/);
  assert.equal(body.record.label, "Claude coach");
  assert.match(body.record.id, /^[A-Za-z0-9_-]{22}$/);
  assert.equal(body.record.lastUsedAt, null);
  const lifetimeDays =
    (Date.parse(body.record.expiresAt) - Date.parse(body.record.createdAt)) /
    86_400_000;
  assert.ok(Math.abs(lifetimeDays - COACH_TOKEN_LIFETIME_DAYS) < 0.01);
  assert.equal("token_digest" in body.record, false);
  assert.equal(JSON.stringify(body.record).includes(body.token), false);

  // Only a digest is stored; the plaintext never touches the database.
  const stored = await pool.query<{ token_digest: string; label: string }>(
    "SELECT token_digest, label FROM member_coach_token WHERE id = $1",
    [body.record.id],
  );
  assert.equal(stored.rows[0]?.label, "Claude coach");
  assert.match(stored.rows[0]?.token_digest ?? "", /^[a-f0-9]{64}$/);
  assert.equal(
    stored.rows[0]?.token_digest.includes(body.token.slice(12, 30)),
    false,
  );

  const listed = await app.inject({
    method: "GET",
    url: "/api/account/coach-tokens",
    headers: asMember(alpha),
  });
  assert.deepEqual(listed.json(), [body.record]);
  assert.equal(listed.body.includes("forma_coach_"), false);

  for (let index = 1; index < MAX_ACTIVE_COACH_TOKENS; index += 1) {
    const extra = await mint(alpha, `Device ${index}`);
    assert.equal(extra.statusCode, 201, extra.body);
  }
  const overCap = await mint(alpha, "One too many");
  assert.equal(overCap.statusCode, 409);
  assert.deepEqual(overCap.json(), { error: "token_limit" });

  // A session older than five minutes must reauthenticate to mint.
  await pool.query(
    `UPDATE "session" SET "createdAt" = now() - interval '6 minutes'
      WHERE token = $1`,
    [decodeURIComponent(alpha.cookie.split("=")[1]).split(".")[0]],
  );
  const stale = await mint(alpha, "Stale session");
  assert.equal(stale.statusCode, 403);
  assert.deepEqual(stale.json(), { error: "reauthentication_required" });
  // Listing and revoking remain available to the ordinary session.
  const listAgain = await app.inject({
    method: "GET",
    url: "/api/account/coach-tokens",
    headers: asMember(alpha),
  });
  assert.equal(listAgain.statusCode, 200);
  assert.equal((listAgain.json() as unknown[]).length, MAX_ACTIVE_COACH_TOKENS);
});

test("a coach token reads only its owner's training summary and dies with revocation or expiry", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const beta = await registerMember("Beta");
  const gamma = await registerMember("Gamma");
  const betaToken = (await mint(beta, "Beta coach")).json() as {
    token: string;
    record: { id: string };
  };
  const gammaToken = (await mint(gamma, "Gamma coach")).json() as {
    token: string;
    record: { id: string };
  };

  // Give Beta a private routine and one logged workout through the normal API.
  const betaWorkspace = (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(beta),
    })
  ).json() as { data: WorkspaceData; revision: number };
  const [routine] = betaWorkspace.data.routines;
  const loaded = routine.exercises[0];
  const now = Date.now();
  const saved = await app.inject({
    method: "PUT",
    url: "/api/workspace",
    headers: { ...asMember(beta), "content-type": "application/json" },
    payload: {
      data: {
        ...betaWorkspace.data,
        routines: betaWorkspace.data.routines.map((item, index) =>
          index === 0 ? { ...item, name: "Beta private routine" } : item,
        ),
        history: [
          {
            id: `beta-session-${suffix}`,
            name: "Beta private routine",
            routineId: routine.id,
            startedAt: now - 3_600_000,
            notes: "Felt strong. Secret note for Beta only.",
            restSeconds: 90,
            restEnd: null,
            restPaused: null,
            date: new Date(now - 60_000).toISOString(),
            duration: 3540,
            exercises: [
              {
                exerciseId: loaded.exerciseId,
                sets: [
                  { weight: 40, reps: 10, done: true },
                  { weight: 42.5, reps: 8, done: true },
                ],
              },
            ],
          },
        ],
      },
      expectedRevision: betaWorkspace.revision,
      operationId: `beta-coach-${suffix}`,
    },
  });
  assert.equal(saved.statusCode, 200, saved.body);

  const read = await coachRead(`Bearer ${betaToken.token}`, "?days=7");
  assert.equal(read.statusCode, 200, read.body);
  assert.equal(read.headers["cache-control"]?.includes("no-store"), true);
  const summary = read.json() as {
    member: { name: string };
    days: number;
    routines: { name: string }[];
    sessions: { id: string; notes: string; exercises: { name: string }[] }[];
    personalBests: { exerciseId: string; bestWeight: number }[];
  };
  assert.equal(summary.member.name, "Beta");
  assert.equal(summary.days, 7);
  assert.equal(summary.routines[0].name, "Beta private routine");
  assert.equal(summary.sessions.length, 1);
  assert.equal(
    summary.sessions[0].notes,
    "Felt strong. Secret note for Beta only.",
  );
  assert.equal(
    summary.personalBests.find((item) => item.exerciseId === loaded.exerciseId)
      ?.bestWeight,
    42.5,
  );
  // No identity, revision or operation data leaves with the summary.
  assert.equal(read.body.includes(beta.email), false);
  assert.equal(read.body.includes(beta.memberRef), false);
  for (const key of ["email", "revision", "operationId", "owner_id", "userId"])
    assert.equal(read.body.includes(`"${key}"`), false, key);

  // Gamma's token sees Gamma's workspace, never Beta's.
  const gammaRead = await coachRead(`Bearer ${gammaToken.token}`);
  assert.equal(gammaRead.statusCode, 200);
  assert.equal(gammaRead.json().member.name, "Gamma");
  assert.equal(gammaRead.body.includes("Beta private routine"), false);
  assert.equal(gammaRead.body.includes("Secret note"), false);
  assert.deepEqual(gammaRead.json().sessions, []);

  // The bearer route ignores cookies and member references entirely.
  const cookieOnly = await app.inject({
    method: "GET",
    url: "/api/coach/workspace",
    headers: asMember(beta),
  });
  assert.equal(cookieOnly.statusCode, 401);
  assert.equal(
    cookieOnly.headers["www-authenticate"],
    'Bearer realm="forma-coach"',
  );
  assert.equal("member" in cookieOnly.json(), false);

  for (const query of ["?days=0", "?days=366", "?days=abc", "?days=7.5"]) {
    const invalid = await coachRead(`Bearer ${betaToken.token}`, query);
    assert.equal(invalid.statusCode, 400, query);
    assert.deepEqual(invalid.json(), { error: "invalid_days" });
  }

  // Last use is recorded without exposing anything else.
  const listed = (
    await app.inject({
      method: "GET",
      url: "/api/account/coach-tokens",
      headers: asMember(beta),
    })
  ).json() as { id: string; lastUsedAt: string | null }[];
  assert.equal(typeof listed[0].lastUsedAt, "string");

  // Gamma cannot revoke Beta's token by ID; Beta can.
  const foreignRevoke = await app.inject({
    method: "DELETE",
    url: `/api/account/coach-tokens/${betaToken.record.id}`,
    headers: asMember(gamma),
  });
  assert.equal(foreignRevoke.statusCode, 404);
  assert.equal((await coachRead(`Bearer ${betaToken.token}`)).statusCode, 200);
  const badId = await app.inject({
    method: "DELETE",
    url: "/api/account/coach-tokens/not-a-real-id",
    headers: asMember(beta),
  });
  assert.equal(badId.statusCode, 404);
  const revoke = await app.inject({
    method: "DELETE",
    url: `/api/account/coach-tokens/${betaToken.record.id}`,
    headers: asMember(beta),
  });
  assert.equal(revoke.statusCode, 200);
  assert.deepEqual(revoke.json(), { status: true });
  assert.equal((await coachRead(`Bearer ${betaToken.token}`)).statusCode, 401);
  const revokeAgain = await app.inject({
    method: "DELETE",
    url: `/api/account/coach-tokens/${betaToken.record.id}`,
    headers: asMember(beta),
  });
  assert.equal(revokeAgain.statusCode, 404);
  assert.deepEqual(
    (
      await app.inject({
        method: "GET",
        url: "/api/account/coach-tokens",
        headers: asMember(beta),
      })
    ).json(),
    [],
  );

  // Expiry is enforced by the database clock, not by the client.
  await pool.query(
    `UPDATE member_coach_token
        SET created_at = now() - interval '91 days',
            expires_at = now() - interval '1 second'
      WHERE id = $1`,
    [gammaToken.record.id],
  );
  assert.equal((await coachRead(`Bearer ${gammaToken.token}`)).statusCode, 401);
  assert.deepEqual(
    (
      await app.inject({
        method: "GET",
        url: "/api/account/coach-tokens",
        headers: asMember(gamma),
      })
    ).json(),
    [],
  );

  // Deleting the member row removes every token with it.
  const deltaUserId = (
    await pool.query<{ id: string }>(
      `SELECT "userId" AS id FROM "session" WHERE token = $1`,
      [decodeURIComponent(gamma.cookie.split("=")[1]).split(".")[0]],
    )
  ).rows[0].id;
  await pool.query(`DELETE FROM "user" WHERE id = $1`, [deltaUserId]);
  const orphaned = await pool.query(
    "SELECT count(*)::int AS count FROM member_coach_token WHERE owner_id = $1",
    [deltaUserId],
  );
  assert.equal(orphaned.rows[0].count, 0);
});

test("bearer guessing and polling are budgeted and malformed credentials never reach the lookup", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const delta = await registerMember("Delta");
  const minted = (await mint(delta, "Delta coach")).json() as { token: string };
  const wrong = `forma_coach_${"Z".repeat(43)}`;

  // Malformed credentials count as failures but never query the token table.
  for (const header of [
    undefined,
    "Basic abc",
    "Bearer",
    "Bearer not-a-forma-token",
    `Bearer ${minted.token} trailing`,
    `Bearer ${minted.token.toUpperCase()}`,
  ]) {
    const response = await coachRead(header, "", "203.0.113.90");
    assert.equal(response.statusCode, 401, String(header));
    assert.deepEqual(response.json(), { error: "unauthorized" });
  }

  const guessIp = "203.0.113.91";
  for (let attempt = 1; attempt <= COACH_FAILURE_LIMIT; attempt += 1) {
    const response = await coachRead(`Bearer ${wrong}`, "", guessIp);
    assert.equal(response.statusCode, 401, `attempt ${attempt}`);
  }
  const locked = await coachRead(`Bearer ${wrong}`, "", guessIp);
  assert.equal(locked.statusCode, 429);
  assert.deepEqual(locked.json(), { error: "too_many_attempts" });
  // The real token still works from another client; failures are per source.
  const elsewhere = await coachRead(
    `Bearer ${minted.token}`,
    "",
    "203.0.113.92",
  );
  assert.equal(elsewhere.statusCode, 200);
  // Only digests of the client key are stored, never the IP itself.
  const throttleRows = await pool.query<{ key_digest: string }>(
    "SELECT key_digest FROM security_throttle WHERE scope = 'coach-token-failure'",
  );
  assert.ok(throttleRows.rows.length > 0);
  for (const row of throttleRows.rows)
    assert.equal(row.key_digest.includes(guessIp), false);

  // Reads per token are capped per hour; the budget is on the token, not the IP.
  let allowed = 1; // the successful read above
  for (let attempt = allowed + 1; attempt <= COACH_READ_LIMIT; attempt += 1) {
    const response = await coachRead(
      `Bearer ${minted.token}`,
      "",
      `203.0.113.${100 + (attempt % 50)}`,
    );
    assert.equal(response.statusCode, 200, `read ${attempt}`);
    allowed += 1;
  }
  const exhausted = await coachRead(
    `Bearer ${minted.token}`,
    "",
    "203.0.113.93",
  );
  assert.equal(exhausted.statusCode, 429);
  assert.deepEqual(exhausted.json(), { error: "rate_limited" });
  assert.equal(exhausted.headers["retry-after"], "3600");
});

type Ack = { data: WorkspaceData; revision: number; updatedAt: string };

async function coachData(
  authorization: string,
  method: "GET" | "PATCH" = "GET",
  payload?: unknown,
  extra: Record<string, string> = {},
) {
  assert.ok(app);
  return app.inject({
    method,
    url: "/api/coach/workspace/data",
    headers: {
      ...gateway("203.0.113.140"),
      authorization,
      ...(payload === undefined ? {} : { "content-type": "application/json" }),
      ...extra,
    },
    ...(payload === undefined ? {} : { payload: payload as object }),
  });
}

test("a full-access token reads the whole workspace and edits it safely; a read-only token cannot", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const delta = await registerMember("Kappa");
  const epsilon = await registerMember("Lambda");

  // Scope is explicit, defaults to read, and rejects anything unknown.
  const unknownScope = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: { ...asMember(delta), "content-type": "application/json" },
    payload: { label: "Admin", scope: "admin" },
  });
  assert.equal(unknownScope.statusCode, 400);
  assert.deepEqual(unknownScope.json(), { error: "invalid_scope" });
  const readToken = (await mint(delta, "Reader")).json() as {
    token: string;
    record: { scope: string };
  };
  assert.equal(readToken.record.scope, "read");
  const fullMint = await app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: { ...asMember(delta), "content-type": "application/json" },
    payload: { label: "Claude coach", scope: "full" },
  });
  assert.equal(fullMint.statusCode, 201, fullMint.body);
  const fullToken = fullMint.json() as {
    token: string;
    record: { id: string; scope: string };
  };
  assert.equal(fullToken.record.scope, "full");
  const listed = await app.inject({
    method: "GET",
    url: "/api/account/coach-tokens",
    headers: asMember(delta),
  });
  assert.deepEqual(
    (listed.json() as { label: string; scope: string }[])
      .map((item) => `${item.label}:${item.scope}`)
      .sort(),
    ["Claude coach:full", "Reader:read"],
  );
  const full = `Bearer ${fullToken.token}`;
  const reader = `Bearer ${readToken.token}`;

  // Read-only tokens keep the summary and catalogue but nothing more.
  assert.equal((await coachRead(reader)).json().access, "read");
  assert.equal((await coachRead(full)).json().access, "full");
  for (const response of [
    await coachData(reader),
    await coachData(reader, "PATCH", {
      expectedRevision: 0,
      operationId: "nope",
      changes: { schedule: [] },
    }),
  ]) {
    assert.equal(response.statusCode, 403, response.body);
    assert.equal(response.json().error, "insufficient_scope");
  }

  const exercises = await app.inject({
    method: "GET",
    url: "/api/coach/exercises?q=reverse%20lunge&limit=5",
    headers: { ...gateway(), authorization: reader },
  });
  assert.equal(exercises.statusCode, 200, exercises.body);
  const lunge = (
    exercises.json() as {
      exercises: {
        id: string;
        logs: string[];
        perSideByDefault: boolean;
        side?: string;
      }[];
    }
  ).exercises.find((item) => item.id === "lunge");
  assert.deepEqual(lunge, {
    ...lunge,
    logs: ["weight", "reps"],
    perSideByDefault: true,
    side: "leg",
  });
  for (const query of [
    "?limit=0",
    "?limit=101",
    "?limit=x",
    `?q=${"a".repeat(101)}`,
  ]) {
    const bad: Awaited<ReturnType<NonNullable<typeof app>["inject"]>> =
      await app.inject({
        method: "GET",
        url: `/api/coach/exercises${query}`,
        headers: { ...gateway(), authorization: reader },
      });
    assert.equal(bad.statusCode, 400, query);
  }

  // The full read is exactly what the member's own app loads.
  const own = (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(delta),
    })
  ).json() as Ack;
  const fullRead = await coachData(full);
  assert.equal(fullRead.statusCode, 200, fullRead.body);
  assert.deepEqual(fullRead.json(), own);
  assert.equal(fullRead.body.includes(delta.email), false);

  // A tool calling from a server sends no Origin and can edit any section.
  const now = Date.now();
  const session = {
    id: `delta-session-${suffix}`,
    name: "Coach logged legs",
    startedAt: now - 3_600_000,
    notes: "Logged by the coach",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    date: new Date(now - 60_000).toISOString(),
    duration: 3_000,
    exercises: [
      {
        exerciseId: "lunge",
        perSide: true,
        sets: [
          {
            weight: 12,
            reps: 18,
            sides: { left: 8, right: 10 },
            rpe: 8,
            done: true,
          },
        ],
      },
    ],
  };
  const editedRoutines = own.data.routines.map((routine, index) =>
    index === 0
      ? {
          ...routine,
          name: "Coach upper",
          exercises: routine.exercises.map((item, itemIndex) =>
            itemIndex === 0
              ? { ...item, reps: 6, repsMax: 8, rpe: 8, restSeconds: 120 }
              : item,
          ),
        }
      : routine,
  );
  const editChanges = {
    routines: editedRoutines,
    history: [session],
    profile: { ...own.data.profile, goal: 5, fillSets: false },
    schedule: [0, 2, 4],
  };
  const edit = await coachData(full, "PATCH", {
    expectedRevision: own.revision,
    operationId: `delta-edit-${suffix}`,
    changes: editChanges,
  });
  assert.equal(edit.statusCode, 200, edit.body);
  assert.deepEqual(Object.keys(edit.json()).sort(), [
    "replayed",
    "revision",
    "updatedAt",
  ]);
  assert.equal(edit.json().revision, own.revision + 1);
  const after = (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(delta),
    })
  ).json() as Ack;
  assert.equal(after.revision, own.revision + 1);
  assert.equal(after.data.routines[0].name, "Coach upper");
  assert.equal(after.data.routines[0].exercises[0].repsMax, 8);
  assert.deepEqual(after.data.schedule, [0, 2, 4]);
  assert.equal(after.data.profile.fillSets, false);
  assert.deepEqual(after.data.history[0].exercises[0].sets[0].sides, {
    left: 8,
    right: 10,
  });
  // Sections the edit did not name are untouched.
  assert.deepEqual(after.data.routines.slice(1), own.data.routines.slice(1));
  assert.equal(after.data.active, own.data.active);

  // The same operation replays; reusing its ID for something else conflicts.
  const replay = await coachData(full, "PATCH", {
    expectedRevision: own.revision,
    operationId: `delta-edit-${suffix}`,
    changes: editChanges,
  });
  assert.equal(replay.statusCode, 200, replay.body);
  assert.equal(replay.json().replayed, true);
  assert.equal(replay.json().revision, own.revision + 1);
  const reused = await coachData(full, "PATCH", {
    expectedRevision: own.revision,
    operationId: `delta-edit-${suffix}`,
    changes: { schedule: [1] },
  });
  assert.equal(reused.statusCode, 409);
  assert.equal(reused.json().error, "operation_id_reused");

  // A stale revision is refused with the revision to reload from.
  const stale = await coachData(full, "PATCH", {
    expectedRevision: own.revision,
    operationId: `delta-stale-${suffix}`,
    changes: { schedule: [1] },
  });
  assert.equal(stale.statusCode, 409);
  assert.equal(stale.json().error, "stale_revision");
  assert.equal(stale.json().revision, after.revision);
  assert.equal("data" in stale.json(), false);

  // Invalid content is refused with the field that is wrong.
  const invalid = await coachData(full, "PATCH", {
    expectedRevision: after.revision,
    operationId: `delta-invalid-${suffix}`,
    changes: {
      history: [
        {
          ...session,
          exercises: [
            {
              ...session.exercises[0],
              sets: [{ ...session.exercises[0].sets[0], reps: 30 }],
            },
          ],
        },
      ],
    },
  });
  assert.equal(invalid.statusCode, 400, invalid.body);
  assert.equal(invalid.json().error, "invalid_workspace");
  assert.ok(
    (invalid.json().issues as { path: string }[]).some((issue) =>
      issue.path.startsWith("history.0.exercises.0.sets.0"),
    ),
    invalid.body,
  );
  for (const changes of [{}, { revision: 99 }, { email: "x@example.test" }]) {
    const refused = await coachData(full, "PATCH", {
      expectedRevision: after.revision,
      operationId: `delta-shape-${JSON.stringify(changes)}`,
      changes,
    });
    assert.equal(refused.statusCode, 400, JSON.stringify(changes));
  }

  // Dropping logged workouts needs their exact count.
  const unconfirmed = await coachData(full, "PATCH", {
    expectedRevision: after.revision,
    operationId: `delta-drop-${suffix}`,
    changes: { history: [] },
  });
  assert.equal(unconfirmed.statusCode, 400);
  assert.equal(unconfirmed.json().error, "history_removal_unconfirmed");
  assert.equal(unconfirmed.json().removedSessions, 1);
  const wrongCount = await coachData(full, "PATCH", {
    expectedRevision: after.revision,
    operationId: `delta-drop-2-${suffix}`,
    changes: { history: [] },
    removesSessions: 2,
  });
  assert.equal(wrongCount.statusCode, 400);
  const confirmed = await coachData(full, "PATCH", {
    expectedRevision: after.revision,
    operationId: `delta-drop-3-${suffix}`,
    changes: { history: [] },
    removesSessions: 1,
  });
  assert.equal(confirmed.statusCode, 200, confirmed.body);

  // A foreign Origin is refused even with a valid token.
  const foreign = await coachData(
    full,
    "PATCH",
    {
      expectedRevision: after.revision + 1,
      operationId: `delta-foreign-${suffix}`,
      changes: { schedule: [6] },
    },
    { origin: "https://attacker.example" },
  );
  assert.equal(foreign.statusCode, 403);

  // The token decides whose workspace changes; a cookie riding along does not.
  const epsilonBefore = (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(epsilon),
    })
  ).json() as Ack;
  const mixed = await coachData(
    full,
    "PATCH",
    {
      expectedRevision: after.revision + 1,
      operationId: `delta-mixed-${suffix}`,
      changes: { schedule: [3] },
    },
    { cookie: epsilon.cookie, "x-forma-member": epsilon.memberRef },
  );
  assert.equal(mixed.statusCode, 200, mixed.body);
  const epsilonAfter = (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(epsilon),
    })
  ).json() as Ack;
  assert.deepEqual(epsilonAfter, epsilonBefore);
  // A member cookie alone never reaches the coach routes.
  const cookieOnly = await app.inject({
    method: "GET",
    url: "/api/coach/workspace/data",
    headers: asMember(delta),
  });
  assert.equal(cookieOnly.statusCode, 401);

  // Revocation ends full access immediately.
  const revoked = await app.inject({
    method: "DELETE",
    url: `/api/account/coach-tokens/${fullToken.record.id}`,
    headers: asMember(delta),
  });
  assert.equal(revoked.statusCode, 200);
  assert.equal((await coachData(full)).statusCode, 401);
  assert.equal(
    (
      await coachData(full, "PATCH", {
        expectedRevision: after.revision + 2,
        operationId: `delta-late-${suffix}`,
        changes: { schedule: [] },
      })
    ).statusCode,
    401,
  );
});
