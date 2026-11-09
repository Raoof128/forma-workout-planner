import { readFile, readdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import pg from "pg";

const { Pool } = pg;
const here = dirname(fileURLToPath(import.meta.url));

export type MigrateOptions = {
  /** Directory of numbered .sql files; tests point this at fixtures. */
  migrationsDir?: string;
  /** How long to wait for another runner's advisory lock. */
  lockWaitMs?: number;
  /** Per-migration lock_timeout: fail fast instead of queueing ahead of the API. */
  lockTimeout?: string;
};

// Zero would disable lock_timeout, so the value must be positive.
const DURATION = /^[1-9]\d*(ms|s|min)$/;

export async function migrate(
  databaseUrl = process.env.DATABASE_URL,
  {
    migrationsDir = join(here, "migrations"),
    lockWaitMs = 120_000,
    lockTimeout = process.env.MIGRATION_LOCK_TIMEOUT ?? "5s",
  }: MigrateOptions = {},
) {
  if (!databaseUrl)
    throw new Error("DATABASE_URL is required to run migrations.");
  if (!DURATION.test(lockTimeout))
    throw new Error("MIGRATION_LOCK_TIMEOUT must look like 5s or 500ms.");
  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  const lockKey = "forma:schema-migrations";
  let locked = false;
  try {
    // Wait a bounded time for a concurrent runner instead of hanging a deploy.
    const deadline = Date.now() + lockWaitMs;
    for (;;) {
      const attempt = await client.query<{ ok: boolean }>(
        "SELECT pg_try_advisory_lock(hashtext($1)) AS ok",
        [lockKey],
      );
      if (attempt.rows[0]?.ok) break;
      if (Date.now() >= deadline)
        throw new Error(
          "Another migration runner holds the schema lock; try again later.",
        );
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    locked = true;
    await client.query(`
      CREATE TABLE IF NOT EXISTS forma_schema_migrations (
        name text PRIMARY KEY,
        checksum char(64),
        applied_at timestamptz NOT NULL DEFAULT clock_timestamp()
      )
    `);
    await client.query(
      "ALTER TABLE forma_schema_migrations ADD COLUMN IF NOT EXISTS checksum char(64)",
    );
    const files = (await readdir(migrationsDir))
      .filter((file) => /^\d{4}[-_].+\.sql$/.test(file))
      .sort();
    const applied = (
      await client.query<{ name: string }>(
        "SELECT name FROM forma_schema_migrations ORDER BY name",
      )
    ).rows.map((row) => row.name);
    // A recorded migration whose file is gone, or a new file that sorts
    // before one already applied, means the release does not match the
    // database. Stop before changing anything.
    const missing = applied.filter((name) => !files.includes(name));
    if (missing.length)
      throw new Error(
        `Applied migration ${missing[0]} is missing from this release.`,
      );
    const lastApplied = applied.at(-1);
    const outOfOrder = files.find(
      (name) => !applied.includes(name) && lastApplied && name < lastApplied,
    );
    if (outOfOrder)
      throw new Error(
        `Migration ${outOfOrder} sorts before applied ${lastApplied}; renumber it.`,
      );
    for (const name of files) {
      const sql = await readFile(join(migrationsDir, name), "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      const exists = await client.query<{ checksum: string | null }>(
        "SELECT checksum FROM forma_schema_migrations WHERE name = $1",
        [name],
      );
      if (exists.rows[0]) {
        const recordedChecksum = exists.rows[0].checksum?.trim();
        if (recordedChecksum && recordedChecksum !== checksum) {
          throw new Error(
            `Applied migration ${name} has changed; add a new migration instead.`,
          );
        }
        if (!recordedChecksum) {
          // Adopt rows from the pre-checksum ledger once. Future edits are
          // detected before any migration statements run.
          await client.query(
            "UPDATE forma_schema_migrations SET checksum = $2 WHERE name = $1",
            [name, checksum],
          );
        }
        continue;
      }
      try {
        await client.query("BEGIN");
        // A DDL statement queued behind a long reader blocks every query that
        // arrives after it. Give up quickly instead; rerun when it is quiet.
        await client.query(`SET LOCAL lock_timeout = '${lockTimeout}'`);
        await client.query(sql);
        await client.query(
          "INSERT INTO forma_schema_migrations (name, checksum) VALUES ($1, $2)",
          [name, checksum],
        );
        await client.query("COMMIT");
      } catch (error) {
        await client.query("ROLLBACK");
        throw error;
      }
    }
  } finally {
    try {
      if (locked)
        await client.query("SELECT pg_advisory_unlock(hashtext($1))", [
          lockKey,
        ]);
    } catch {
      // A failed unlock means the connection is no longer usable; release it
      // and close the pool below.
    } finally {
      client.release();
    }
    await pool.end();
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  migrate().catch((error) => {
    process.stderr.write(`Database migration failed: ${String(error)}\n`);
    process.exitCode = 1;
  });
}
