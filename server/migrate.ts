import { readFile, readdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import pg from "pg";

const { Pool } = pg;
const here = dirname(fileURLToPath(import.meta.url));

export async function migrate(databaseUrl = process.env.DATABASE_URL) {
  if (!databaseUrl)
    throw new Error("DATABASE_URL is required to run migrations.");
  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  const lockKey = "forma:schema-migrations";
  try {
    await client.query("SELECT pg_advisory_lock(hashtext($1))", [lockKey]);
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
    const files = (await readdir(join(here, "migrations")))
      .filter((file) => /^\d{4}[-_].+\.sql$/.test(file))
      .sort();
    for (const name of files) {
      const sql = await readFile(join(here, "migrations", name), "utf8");
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
      await client.query("SELECT pg_advisory_unlock(hashtext($1))", [lockKey]);
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
