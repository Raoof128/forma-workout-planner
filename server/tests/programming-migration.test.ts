import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import pg from "pg";
import { freshData, validateData } from "../../src/storage.js";

test("SQL v2 migration matches browser migration for all paths, preserves collisions and is idempotent", async () => {
  const url = process.env.TEST_DATABASE_URL;
  assert.ok(
    url,
    "TEST_DATABASE_URL is required; migration tests require PostgreSQL.",
  );
  const schema = `forma_programming_${randomUUID().replaceAll("-", "")}`;
  const pool = new pg.Pool({
    connectionString: url,
    options: `-c search_path=${schema}`,
  });
  try {
    await pool.query(`CREATE SCHEMA ${schema}`);
    await pool.query('CREATE TABLE "user" (id text PRIMARY KEY)');
    await pool.query(
      await readFile(
        new URL("../migrations/0002-workspace.sql", import.meta.url),
        "utf8",
      ),
    );
    const data = freshData();
    data.version = 1;
    data.revision = 7;
    data.routines[0].archivedAt = 1;
    data.routines[0].exercises = [
      {
        exerciseId: "wger-4b23738a-67a8-41af-996d-abc53a7c3f97",
        sets: 3,
        reps: 8,
        weight: 15,
      },
      {
        exerciseId: "db-incline-dumbbell-press",
        sets: 4,
        reps: 12,
        weight: 20,
      },
    ] as (typeof data.routines)[number]["exercises"];
    data.active = {
      id: "a",
      name: "Legacy",
      startedAt: 1,
      notes: "",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: data.routines[0].exercises.map(
        (e: { exerciseId: string; weight: number; reps: number }) => ({
          exerciseId: e.exerciseId,
          sets: [{ weight: e.weight, reps: e.reps, done: true }],
        }),
      ),
    } as typeof data.active;
    data.active!.exercises[0].sets.push({
      weight: Number.MAX_VALUE,
      reps: 1e-7,
      done: false,
    } as NonNullable<typeof data.active>["exercises"][number]["sets"][number]);
    data.history = [
      {
        ...structuredClone(data.active!),
        id: "h",
        date: "2026-10-01T00:00:00Z",
        duration: 60,
      },
    ];
    await pool.query('INSERT INTO "user" (id) VALUES ($1)', [
      "synthetic-member",
    ]);
    await pool.query(
      "INSERT INTO member_workspace (owner_id,data,revision) VALUES ($1,$2,7)",
      ["synthetic-member", JSON.stringify(data)],
    );
    const sql = await readFile(
      new URL("../migrations/0004-routine-programming.sql", import.meta.url),
      "utf8",
    );
    await pool.query(sql);
    const first = (
      await pool.query("SELECT data,revision,updated_at FROM member_workspace")
    ).rows[0];
    assert.equal(first.data.version, 2);
    assert.equal(first.data.routines[0].archivedAt, 1);
    assert.equal(
      validateData(first.data, { strict: true }).routines[0].archivedAt,
      1,
    );
    assert.equal(first.revision, 8);
    assert.deepEqual(validateData(first.data), {
      ...validateData(data),
      revision: 8,
    });
    await pool.query(sql);
    assert.deepEqual(
      (
        await pool.query(
          "SELECT data,revision,updated_at FROM member_workspace",
        )
      ).rows[0],
      first,
    );
  } finally {
    await pool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await pool.end();
  }
});
