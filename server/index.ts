import pg from "pg";
import { z } from "zod";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

const { Pool } = pg;

export async function startServer(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL is required");

  const config = loadConfig();
  const poolSize = Number(process.env.DATABASE_POOL_SIZE ?? 10);
  if (!Number.isInteger(poolSize) || poolSize < 1 || poolSize > 100)
    throw new Error("DATABASE_POOL_SIZE must be a whole number from 1 to 100");
  const pool = new Pool({
    connectionString: databaseUrl,
    max: poolSize,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });
  // pg discards failed idle clients. Handle that event so a transient loss
  // does not terminate the API; subsequent requests acquire a new connection.
  pool.on("error", () => {
    process.stderr.write(
      "FORMA database connection lost; discarded idle connection.\n",
    );
  });
  await pool.query("SELECT 1");

  const app = await createApp({ pool, config });
  const port = Number(process.env.PORT ?? 3000);
  await app.listen({ host: process.env.HOST ?? "0.0.0.0", port });

  // Drain in-flight requests, then close the pool. A hung request must not
  // stop the process from exiting before Docker's grace period (10 s) ends,
  // and a failed close must still release the database connections.
  const shutdown = async () => {
    const deadline = setTimeout(() => {
      process.stderr.write("FORMA API shutdown timed out; exiting.\n");
      process.exit(1);
    }, 8_000);
    deadline.unref();
    try {
      await app.close();
    } catch {
      process.stderr.write("FORMA API close failed; closing the pool.\n");
      process.exitCode = 1;
    } finally {
      await pool.end().catch(() => {});
      clearTimeout(deadline);
    }
  };
  process.once("SIGINT", () => void shutdown());
  process.once("SIGTERM", () => void shutdown());
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  startServer().catch((error: unknown) => {
    // Name what is wrong without echoing values (they may be secrets).
    const fields =
      error instanceof z.ZodError
        ? ` Invalid settings: ${[...new Set(error.issues.map((issue) => issue.path.join(".")))].join(", ")}.`
        : error instanceof Error && !("code" in error)
          ? ` ${error.message}.`
          : "";
    process.stderr.write(
      `FORMA API startup failed; check required configuration and database availability.${fields}\n`,
    );
    process.exitCode = 1;
  });
}
