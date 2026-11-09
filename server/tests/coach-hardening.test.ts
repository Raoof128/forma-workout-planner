import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { PassThrough } from "node:stream";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import { createApp } from "../app.js";
import { clearEmailSink, inspectEmailSink } from "../email.js";
import type { AppConfig } from "../config.js";
import type { WorkspaceData } from "../schema.js";
import {
  assertCoachTokenActive,
  CoachTokenInactive,
  MAX_ACTIVE_COACH_TOKENS,
  revokeCoachToken,
} from "../coachTokens.js";
import {
  COACH_DATA_PATH,
  COACH_MEMBER_WRITE_LIMIT,
  COACH_MINT_LIMIT,
} from "../coachRoutes.js";

// Real-PostgreSQL regression coverage for coach-token hardening: last-use
// recording, the mint budget, the member-wide write budget and revocation that
// lands while an edit is in flight.

const { Pool } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_coach_hard_${suffix}`;
const appOrigin = "https://coach-hardening.forma.test";
const workerSecret = `coach-hard-worker-secret-${suffix}`;
const config: AppConfig = {
  environment: "test",
  appOrigin,
  authSecret: `coach-hard-auth-secret-${suffix}`,
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
type Ack = { data: WorkspaceData; revision: number; updatedAt: string };

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

const asMember = (member: Member) => ({
  ...gateway(),
  origin: appOrigin,
  cookie: member.cookie,
  "x-forma-member": member.memberRef,
});

async function mint(member: Member, label: string, scope?: "read" | "full") {
  assert.ok(app);
  return app.inject({
    method: "POST",
    url: "/api/account/coach-tokens",
    headers: { ...asMember(member), "content-type": "application/json" },
    payload: scope ? { label, scope } : { label },
  });
}

async function mintToken(member: Member, label: string, scope?: "full") {
  const response = await mint(member, label, scope);
  assert.equal(response.statusCode, 201, response.body);
  return response.json() as {
    token: string;
    record: { id: string; scope: string };
  };
}

async function readWorkspace(member: Member) {
  assert.ok(app);
  return (
    await app.inject({
      method: "GET",
      url: "/api/workspace",
      headers: asMember(member),
    })
  ).json() as Ack;
}

async function coachRead(token: string, ip = "203.0.113.20") {
  assert.ok(app);
  return app.inject({
    method: "GET",
    url: "/api/coach/workspace",
    headers: { ...gateway(ip), authorization: `Bearer ${token}` },
  });
}

async function coachPatch(
  token: string,
  payload: unknown,
  ip = "203.0.113.21",
) {
  assert.ok(app);
  return app.inject({
    method: "PATCH",
    url: COACH_DATA_PATH,
    headers: {
      ...gateway(ip),
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    payload: payload as object,
  });
}

async function lastUsed(tokenId: string): Promise<string | null> {
  assert.ok(pool);
  const result = await pool.query<{ last_used_at: Date | null }>(
    "SELECT last_used_at FROM member_coach_token WHERE id = $1",
    [tokenId],
  );
  const value = result.rows[0]?.last_used_at ?? null;
  return value ? value.toISOString() : null;
}

/** The stored owner ID, which is the internal user ID rather than the member reference. */
async function ownerOf(tokenId: string): Promise<string> {
  assert.ok(pool);
  const result = await pool.query<{ owner_id: string }>(
    "SELECT owner_id FROM member_coach_token WHERE id = $1",
    [tokenId],
  );
  return result.rows[0].owner_id;
}

/** The row's transaction id: it changes only when the row is rewritten. */
async function rowVersion(tokenId: string): Promise<string> {
  assert.ok(pool);
  const result = await pool.query<{ xmin: string }>(
    "SELECT xmin::text AS xmin FROM member_coach_token WHERE id = $1",
    [tokenId],
  );
  return result.rows[0].xmin;
}

async function waitFor(check: () => Promise<boolean>) {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert.fail("The awaited condition never became true.");
}

test("a refused request never records use, and a successful read records it at most once per five minutes", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const member = await registerMember("Hardening");
  const reader = await mintToken(member, "Reader");
  const own = await readWorkspace(member);

  // A read token asking for a write is refused by scope before any use is recorded.
  const refused = await coachPatch(reader.token, {
    expectedRevision: own.revision,
    operationId: `refused-${suffix}`,
    changes: { schedule: [1] },
  });
  assert.equal(refused.statusCode, 403, refused.body);
  assert.equal(refused.json().error, "insufficient_scope");
  assert.equal(await lastUsed(reader.record.id), null);

  // The first successful read records use.
  assert.equal((await coachRead(reader.token)).statusCode, 200);
  const first = await lastUsed(reader.record.id);
  assert.notEqual(first, null);
  const versionAfterFirst = await rowVersion(reader.record.id);

  // A second read within the window leaves the row untouched.
  assert.equal((await coachRead(reader.token)).statusCode, 200);
  assert.equal(await lastUsed(reader.record.id), first);
  assert.equal(await rowVersion(reader.record.id), versionAfterFirst);

  // Once the stamp is older than five minutes, the next read refreshes it.
  await pool.query(
    `UPDATE member_coach_token SET last_used_at = clock_timestamp() - interval '6 minutes'
      WHERE id = $1`,
    [reader.record.id],
  );
  const stale = await lastUsed(reader.record.id);
  assert.equal((await coachRead(reader.token)).statusCode, 200);
  const refreshed = await lastUsed(reader.record.id);
  assert.notEqual(refreshed, stale);
  assert.ok(Date.parse(refreshed!) > Date.parse(stale!));
});

test("the mint budget counts well-formed attempts, answers 429 on the eleventh within an hour, and belongs to the member", async () => {
  assert.ok(app);
  clearEmailSink();
  const minter = await registerMember("Minter");

  for (let attempt = 1; attempt <= MAX_ACTIVE_COACH_TOKENS; attempt += 1) {
    const response = await mint(minter, `Device ${attempt}`);
    assert.equal(response.statusCode, 201, response.body);
  }
  // Attempts past the active cap are well-formed, so they spend budget as well.
  for (
    let attempt = MAX_ACTIVE_COACH_TOKENS + 1;
    attempt <= COACH_MINT_LIMIT;
    attempt += 1
  ) {
    const response = await mint(minter, `Device ${attempt}`);
    assert.equal(response.statusCode, 409, `attempt ${attempt}`);
    assert.deepEqual(response.json(), { error: "token_limit" });
  }

  const eleventh = await mint(minter, "Eleventh");
  assert.equal(eleventh.statusCode, 429, eleventh.body);
  assert.deepEqual(eleventh.json(), { error: "rate_limited" });
  assert.equal(eleventh.headers["retry-after"], "3600");
  assert.equal(eleventh.headers["cache-control"]?.includes("no-store"), true);

  // The budget is per member: another member can still mint.
  const other = await registerMember("Minterb");
  assert.equal((await mint(other, "Fresh device")).statusCode, 201);
});

test("the member-wide write budget applies across a member's tokens, and a refused write is neither stored nor counted as use", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const member = await registerMember("Writer");
  const laptop = await mintToken(member, "Laptop", "full");
  const phone = await mintToken(member, "Phone", "full");
  const tablet = await mintToken(member, "Tablet", "full");

  let revision = (await readWorkspace(member)).revision;
  const startRevision = revision;
  let operation = 0;
  const writeWith = async (token: string) => {
    operation += 1;
    const response = await coachPatch(token, {
      expectedRevision: revision,
      operationId: `member-budget-${suffix}-${operation}`,
      changes: { schedule: [operation % 7] },
    });
    if (response.statusCode === 200) revision = response.json().revision;
    return response;
  };

  // Laptop and phone alternate, so each stays inside its own budget of
  // COACH_WRITE_LIMIT while together they exhaust the member-wide budget.
  for (let write = 1; write <= COACH_MEMBER_WRITE_LIMIT; write += 1) {
    const response = await writeWith(write % 2 ? laptop.token : phone.token);
    assert.equal(response.statusCode, 200, `${write}: ${response.body}`);
  }
  assert.equal(revision, startRevision + COACH_MEMBER_WRITE_LIMIT);

  // The third token has spent nothing itself, yet the member's cap is reached.
  const refused = await writeWith(tablet.token);
  assert.equal(refused.statusCode, 429, refused.body);
  assert.deepEqual(refused.json(), { error: "rate_limited" });
  assert.equal(refused.headers["retry-after"], "3600");
  assert.equal((await readWorkspace(member)).revision, revision);
  // A rate-limited request is not use: the tablet token was never recorded.
  assert.equal(await lastUsed(tablet.record.id), null);
});

test("a token revoked or expired while its edit is in flight cannot commit that edit", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const member = await registerMember("Inflight");
  const revoked = await mintToken(member, "Revoked mid-edit", "full");
  const expiring = await mintToken(member, "Expired mid-edit", "full");
  const before = await readWorkspace(member);

  // Authenticate, then hold the body back until the token has been revoked.
  // The write must be refused because writeWorkspace calls
  // assertCoachTokenActive inside its transaction. Until that call is wired,
  // this test fails: the edit commits with the revoked token.
  const edit = async (
    tokenId: string,
    token: string,
    change: () => Promise<void>,
  ) => {
    const body = new PassThrough();
    const pending = app!.inject({
      method: "PATCH",
      url: COACH_DATA_PATH,
      headers: {
        ...gateway("203.0.113.30"),
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      payload: body,
    });
    await waitFor(async () => (await lastUsed(tokenId)) !== null);
    await change();
    body.end(
      JSON.stringify({
        expectedRevision: before.revision,
        operationId: `inflight-${randomUUID()}`,
        changes: { schedule: [2] },
      }),
    );
    return pending;
  };

  const revokedEdit = await edit(revoked.record.id, revoked.token, async () => {
    const response = await app!.inject({
      method: "DELETE",
      url: `/api/account/coach-tokens/${revoked.record.id}`,
      headers: asMember(member),
    });
    assert.equal(response.statusCode, 200);
  });
  assert.equal(revokedEdit.statusCode, 401, revokedEdit.body);
  assert.deepEqual(revokedEdit.json(), { error: "unauthorized" });
  assert.equal((await readWorkspace(member)).revision, before.revision);

  const expiredEdit = await edit(
    expiring.record.id,
    expiring.token,
    async () => {
      await pool!.query(
        `UPDATE member_coach_token
          SET created_at = clock_timestamp() - interval '2 seconds',
              expires_at = clock_timestamp() - interval '1 second'
        WHERE id = $1`,
        [expiring.record.id],
      );
    },
  );
  assert.equal(expiredEdit.statusCode, 401, expiredEdit.body);
  assert.deepEqual(expiredEdit.json(), { error: "unauthorized" });
  const after = await readWorkspace(member);
  assert.equal(after.revision, before.revision);
  assert.deepEqual(after.data.schedule, before.data.schedule);
});

test("assertCoachTokenActive refuses revoked, expired and foreign tokens, and blocks a concurrent revocation until commit", async () => {
  assert.ok(app && pool);
  clearEmailSink();
  const owner = await registerMember("Locker");
  const other = await registerMember("Lockerb");
  const token = await mintToken(owner, "Locked");
  const otherToken = await mintToken(other, "Other locked");
  const tokenId = token.record.id;
  // The check takes the stored owner ID, not the session's member reference.
  const ownerId = await ownerOf(tokenId);
  const otherId = await ownerOf(otherToken.record.id);
  assert.notEqual(ownerId, otherId);

  // Ownership is part of the check: another member's user ID never matches.
  const probe = await pool.connect();
  try {
    await probe.query("BEGIN");
    await assertCoachTokenActive(probe, ownerId, tokenId);
    await assert.rejects(
      assertCoachTokenActive(probe, otherId, tokenId),
      CoachTokenInactive,
    );
    await probe.query("ROLLBACK");
  } finally {
    probe.release();
  }

  // An open check holds a share lock: a revocation waits for it to finish.
  const holder = await pool.connect();
  try {
    await holder.query("BEGIN");
    await assertCoachTokenActive(holder, ownerId, tokenId);
    let revocationDone = false;
    const revocation = revokeCoachToken(pool, ownerId, tokenId).then(
      (result) => {
        revocationDone = true;
        return result;
      },
    );
    await new Promise((resolve) => setTimeout(resolve, 200));
    assert.equal(revocationDone, false, "revocation must wait for the check");
    await holder.query("COMMIT");
    assert.equal(await revocation, true);
  } catch (error) {
    await holder.query("ROLLBACK").catch(() => undefined);
    throw error;
  } finally {
    holder.release();
  }

  // Once revoked, the same check refuses inside a fresh transaction.
  const revoked = await pool.connect();
  try {
    await revoked.query("BEGIN");
    await assert.rejects(
      assertCoachTokenActive(revoked, ownerId, tokenId),
      CoachTokenInactive,
    );
    await revoked.query("ROLLBACK");
  } finally {
    revoked.release();
  }
});
