import pg from "pg";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

const { Pool } = pg;

export async function startServer(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error("DATABASE_URL is required");

  const config = loadConfig();
  const pool = new Pool({
    connectionString: databaseUrl,
    max: Number(process.env.DATABASE_POOL_SIZE ?? 10),
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

  const shutdown = async () => {
    await app.close();
    await pool.end();
  };
  process.once("SIGINT", () => void shutdown());
  process.once("SIGTERM", () => void shutdown());
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  startServer().catch(() => {
    process.stderr.write(
      "FORMA API startup failed; check required configuration and database availability.\n",
    );
    process.exitCode = 1;
  });
}
