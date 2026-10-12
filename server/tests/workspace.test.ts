import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";
import pg from "pg";
import {
  getWorkspace,
  InvalidWorkspace,
  putWorkspace,
  WorkspaceConflict,
} from "../workspace.js";

const { Pool } = pg;
const databaseUrl =
  process.env.WORKSPACE_TEST_DATABASE_URL ?? process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));
const suffix = randomUUID().replaceAll("-", "");
const schema = `forma_workspace_test_${suffix}`;
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
const userA = `member-a-${suffix}`;
const userB = `member-b-${suffix}`;

before(async () => {
  if (!databaseUrl || !adminPool || !pool)
    throw new Error(
      "WORKSPACE_TEST_DATABASE_URL or TEST_DATABASE_URL is required; workspace integration tests require real PostgreSQL.",
    );
  await adminPool.query(`CREATE SCHEMA ${schema}`);
  await pool.query(`
    CREATE TABLE "user" (
      id text PRIMARY KEY,
      name text NOT NULL,
      email text NOT NULL UNIQUE
    )
  `);
  const migration = await readFile(
    join(testDir, "..", "migrations", "0002-workspace.sql"),
    "utf8",
  );
  await pool.query(migration);
  await pool.query(
    `INSERT INTO "user" (id, name, email) VALUES
      ($1, 'Member A', $2), ($3, 'Member B', $4)`,
    [userA, `${userA}@example.test`, userB, `${userB}@example.test`],
  );
});

after(async () => {
  if (pool) await pool.end();
  if (adminPool) {
    await adminPool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await adminPool.end();
  }
});

test("PostgreSQL workspace ownership, concurrency, idempotency, validation, and cascade", async () => {
  assert.ok(pool);

  const first = await getWorkspace(pool, userA, "Member A");
  const other = await getWorkspace(pool, userB, "Member B");
  assert.equal(first.revision, 0);
  assert.equal(first.data.profile.name, "Member A");
  assert.deepEqual(first.data.history, []);
  assert.ok(first.data.routines.length > 0);
  assert.equal(other.data.profile.name, "Member B");
  assert.equal(first.data.routines[0].id, other.data.routines[0].id);

  const changedA = {
    ...first.data,
    profile: { ...first.data.profile, goal: 5 },
    routines: first.data.routines.map((routine, index) =>
      index === 0 ? { ...routine, name: "Member A plan" } : routine,
    ),
  };
  const committed = await putWorkspace(pool, userA, "Member A", {
    data: changedA,
    expectedRevision: 0,
    operationId: "operation-a-1",
  });
  assert.equal(committed.revision, 1);
  assert.equal(committed.data.profile.goal, 5);
  assert.equal(
    (await getWorkspace(pool, userB)).data.routines[0].name,
    other.data.routines[0].name,
  );

  // A different member cannot read or overwrite member A's row by supplying
  // A's client-side data. Every query remains scoped to the authenticated ID.
  const changedB = {
    ...other.data,
    profile: { ...other.data.profile, goal: 2 },
  };
  const committedB = await putWorkspace(pool, userB, "Member B", {
    data: changedB,
    expectedRevision: 0,
    operationId: "operation-b-1",
  });
  assert.equal(committedB.data.profile.goal, 2);
  assert.equal((await getWorkspace(pool, userA)).data.profile.goal, 5);

  // A lost response retry returns its exact original acknowledgement.
  const retry = await putWorkspace(pool, userA, "Member A", {
    data: changedA,
    expectedRevision: 0,
    operationId: "operation-a-1",
  });
  assert.deepEqual(retry, committed);

  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: { ...changedA, profile: { ...changedA.profile, goal: 6 } },
      expectedRevision: 0,
      operationId: "operation-a-1",
    }),
    (error: unknown) =>
      error instanceof WorkspaceConflict &&
      error.code === "operation_id_reused" &&
      error.latest.revision === 1,
  );

  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: { ...changedA, profile: { ...changedA.profile, goal: 1 } },
      expectedRevision: 0,
      operationId: "operation-a-stale",
    }),
    (error: unknown) =>
      error instanceof WorkspaceConflict &&
      error.code === "stale_revision" &&
      error.latest.revision === 1 &&
      error.latest.data.profile.goal === 5,
  );

  const latest = await getWorkspace(pool, userA);
  const concurrentPayloads = [
    {
      data: { ...latest.data, profile: { ...latest.data.profile, goal: 3 } },
      expectedRevision: latest.revision,
      operationId: "operation-concurrent-1",
    },
    {
      data: { ...latest.data, profile: { ...latest.data.profile, goal: 4 } },
      expectedRevision: latest.revision,
      operationId: "operation-concurrent-2",
    },
  ];
  const concurrent = await Promise.allSettled(
    concurrentPayloads.map((payload) =>
      putWorkspace(pool, userA, "Member A", payload),
    ),
  );
  assert.equal(
    concurrent.filter((result) => result.status === "fulfilled").length,
    1,
  );
  assert.equal(
    concurrent.filter((result) => result.status === "rejected").length,
    1,
  );
  const rejected = concurrent.find((result) => result.status === "rejected");
  assert.ok(rejected && rejected.status === "rejected");
  assert.ok(rejected.reason instanceof WorkspaceConflict);
  const postConcurrent = await getWorkspace(pool, userA);
  assert.equal(postConcurrent.revision, latest.revision + 1);
  assert.ok(postConcurrent.updatedAt > latest.updatedAt);

  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: postConcurrent.data,
      userId: userB,
      expectedRevision: postConcurrent.revision,
      operationId: "operation-invalid-extra",
    }),
    InvalidWorkspace,
  );
  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: {
        ...postConcurrent.data,
        routines: [
          postConcurrent.data.routines[0],
          postConcurrent.data.routines[0],
        ],
      },
      expectedRevision: postConcurrent.revision,
      operationId: "operation-invalid-duplicate",
    }),
    InvalidWorkspace,
  );
  assert.equal(
    (await getWorkspace(pool, userA)).revision,
    postConcurrent.revision,
  );

  const duplicateActiveId = {
    id: "same-session-id",
    name: "Active workout",
    startedAt: 1,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      { exerciseId: "bench", sets: [{ weight: 10, reps: 5, done: true }] },
    ],
  };
  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: {
        ...postConcurrent.data,
        active: duplicateActiveId,
        history: [
          {
            ...duplicateActiveId,
            date: new Date().toISOString(),
            duration: 60,
          },
        ],
      },
      expectedRevision: postConcurrent.revision,
      operationId: "operation-invalid-active-history",
    }),
    InvalidWorkspace,
  );

  // The ledger keeps only the most recent 1,000 operations and never more
  // than 30 days. Dropping an acknowledgement remains safe: the old expected
  // revision can only receive a conflict and cannot apply twice.
  await pool.query(
    `UPDATE member_workspace_operations
          SET created_at = clock_timestamp() - interval '31 days'
        WHERE owner_id = $1 AND operation_id = 'operation-a-1'`,
    [userA],
  );
  await pool.query(
    `INSERT INTO member_workspace_operations
         (owner_id, operation_id, request_hash, acknowledgement, created_at)
       SELECT $1, 'retention-' || g::text, repeat('0', 64),
              '{"revision":0,"updatedAt":"2026-01-01T00:00:00.000000Z"}'::jsonb,
              clock_timestamp() - interval '1 hour'
         FROM generate_series(1, 1001) AS g`,
    [userA],
  );
  const beforeRetention = await getWorkspace(pool, userA);
  const retentionUpdate = await putWorkspace(pool, userA, "Member A", {
    data: {
      ...beforeRetention.data,
      profile: { ...beforeRetention.data.profile, goal: 6 },
    },
    expectedRevision: beforeRetention.revision,
    operationId: "operation-retention-trigger",
  });
  assert.equal(retentionUpdate.revision, beforeRetention.revision + 1);
  const retained = await pool.query<{ count: string }>(
    "SELECT count(*) FROM member_workspace_operations WHERE owner_id = $1",
    [userA],
  );
  assert.equal(Number(retained.rows[0].count), 1000);
  await assert.rejects(
    putWorkspace(pool, userA, "Member A", {
      data: changedA,
      expectedRevision: 0,
      operationId: "operation-a-1",
    }),
    (error: unknown) =>
      error instanceof WorkspaceConflict &&
      error.code === "stale_revision" &&
      error.latest.revision === retentionUpdate.revision,
  );

  const deletedRows = await pool.query(
    `SELECT
        (SELECT count(*) FROM member_workspace WHERE owner_id = $1) AS workspace_rows,
        (SELECT count(*) FROM member_workspace_operations WHERE owner_id = $1) AS operation_rows`,
    [userA],
  );
  assert.equal(Number(deletedRows.rows[0].workspace_rows), 1);
  assert.ok(Number(deletedRows.rows[0].operation_rows) > 0);
  await pool.query('DELETE FROM "user" WHERE id = $1', [userA]);
  const cascaded = await pool.query(
    `SELECT
        (SELECT count(*) FROM member_workspace WHERE owner_id = $1) AS workspace_rows,
        (SELECT count(*) FROM member_workspace_operations WHERE owner_id = $1) AS operation_rows`,
    [userA],
  );
  assert.equal(Number(cascaded.rows[0].workspace_rows), 0);
  assert.equal(Number(cascaded.rows[0].operation_rows), 0);
});
