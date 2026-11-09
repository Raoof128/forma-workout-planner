// Reproducible workspace persistence benchmark against a DISPOSABLE PostgreSQL.
//
//   BENCH_DATABASE_URL=postgres://…/scratch npx tsx scripts/bench-workspace.ts
//
// It creates and drops its own schema, applies the workspace migrations and
// drives the real putWorkspace/getWorkspace code with synthetic members. Never
// point it at a staging or production database.
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";
import pg from "pg";
import { freshData } from "../src/storage.js";
import { getWorkspace, putWorkspace } from "../server/workspace.js";

const databaseUrl = process.env.BENCH_DATABASE_URL;
if (!databaseUrl) throw new Error("BENCH_DATABASE_URL is required.");
if (/forma(_staging|_production)?$/.test(new URL(databaseUrl).pathname))
  throw new Error("Refusing a database name that looks like a real one.");

const MEMBERS = Number(process.env.BENCH_MEMBERS ?? 40);
const SESSIONS = Number(process.env.BENCH_SESSIONS ?? 300);
const SEQUENTIAL = Number(process.env.BENCH_SEQUENTIAL ?? 300);
const WARMUP = 30;
const CONCURRENCY = 8;
const schema = `forma_bench_${randomUUID().replaceAll("-", "")}`;

const admin = new pg.Pool({ connectionString: databaseUrl });
const pool = new pg.Pool({
  connectionString: databaseUrl,
  options: `-c search_path=${schema}`,
  max: CONCURRENCY,
});

function workspace(name: string) {
  const data = freshData();
  data.profile.name = name;
  const start = Date.UTC(2026, 0, 1);
  data.history = Array.from({ length: SESSIONS }, (_, index) => ({
    id: randomUUID(),
    routineId: data.routines[0].id,
    name: `Session ${index + 1}`,
    startedAt: start + index * 86_400_000,
    date: new Date(start + index * 86_400_000 + 3_600_000).toISOString(),
    duration: 3600,
    notes: "Synthetic benchmark session.",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: data.routines[0].exercises.map((entry) => ({
      exerciseId: entry.exerciseId,
      sets: Array.from({ length: 3 }, (_, set) => ({
        weight: 20 + set * 2.5,
        reps: 10,
        done: true,
        rpe: null,
      })),
    })),
  }));
  return data;
}

const percentile = (values: number[], p: number) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];
};
const summary = (values: number[]) => ({
  n: values.length,
  p50: Number(percentile(values, 50).toFixed(2)),
  p95: Number(percentile(values, 95).toFixed(2)),
  p99: Number(percentile(values, 99).toFixed(2)),
});

async function main() {
  await admin.query(`CREATE SCHEMA ${schema}`);
  await pool.query(
    `CREATE TABLE "user" (id text PRIMARY KEY, name text NOT NULL, email text NOT NULL UNIQUE)`,
  );
  for (const file of ["0002-workspace.sql", "0004-routine-programming.sql"])
    await pool.query(
      await readFile(new URL(`../server/migrations/${file}`, import.meta.url), "utf8"),
    );
  const members = Array.from({ length: MEMBERS }, (_, index) => `bench-${index}`);
  for (const id of members)
    await pool.query(`INSERT INTO "user" VALUES ($1, $1, $1 || '@example.test')`, [id]);
  const payload = workspace("Bench member");
  const bytes = Buffer.byteLength(JSON.stringify(payload));
  const revisions = new Map<string, number>();
  for (const id of members) {
    const first = await getWorkspace(pool, id, "Bench member");
    revisions.set(id, first.revision);
  }

  // Sequential saves and reads for one member (warm-up excluded).
  const one = members[0];
  const put: number[] = [];
  for (let index = 0; index < WARMUP + SEQUENTIAL; index += 1) {
    const started = performance.now();
    const saved = await putWorkspace(pool, one, "Bench member", {
      data: { ...payload, profile: { ...payload.profile, goal: (index % 7) + 1 } },
      expectedRevision: revisions.get(one)!,
      operationId: randomUUID(),
    });
    if (index >= WARMUP) put.push(performance.now() - started);
    revisions.set(one, saved.revision);
  }
  const get: number[] = [];
  for (let index = 0; index < WARMUP + SEQUENTIAL; index += 1) {
    const started = performance.now();
    await getWorkspace(pool, one, "Bench member");
    if (index >= WARMUP) get.push(performance.now() - started);
  }

  // Concurrent saves across members, CONCURRENCY in flight.
  const queue = members.flatMap((id) => Array.from({ length: 10 }, () => id));
  const concurrent: number[] = [];
  let errors = 0;
  const wall = performance.now();
  const busy = new Set<string>();
  async function worker() {
    while (queue.length) {
      const index = queue.findIndex((id) => !busy.has(id));
      if (index < 0) {
        await new Promise((resolve) => setTimeout(resolve, 1));
        continue;
      }
      const [id] = queue.splice(index, 1);
      busy.add(id);
      const started = performance.now();
      try {
        const saved = await putWorkspace(pool, id, "Bench member", {
          data: payload,
          expectedRevision: revisions.get(id)!,
          operationId: randomUUID(),
        });
        revisions.set(id, saved.revision);
      } catch {
        errors += 1;
      } finally {
        busy.delete(id);
      }
      concurrent.push(performance.now() - started);
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  const seconds = (performance.now() - wall) / 1000;

  console.log(
    JSON.stringify(
      {
        node: process.version,
        workspaceBytes: bytes,
        sessionsPerWorkspace: SESSIONS,
        sequentialPutMs: summary(put),
        sequentialGetMs: summary(get),
        concurrentPutMs: summary(concurrent),
        concurrentThroughputPerSecond: Number((concurrent.length / seconds).toFixed(1)),
        concurrentErrors: errors,
        rssMiB: Number((process.memoryUsage().rss / 1048576).toFixed(1)),
      },
      null,
      2,
    ),
  );
}

main()
  .finally(async () => {
    await pool.end();
    await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
    await admin.end();
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
