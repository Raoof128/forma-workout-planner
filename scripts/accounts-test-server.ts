/** Isolated test harness. Never used by the deployed API. */
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import pg from "pg";
import { createApp } from "../server/app.js";
import { inspectEmailSink } from "../server/email.js";

if (process.env.NODE_ENV === "production")
  throw new Error("Test harness refuses production mode");
process.env.NODE_ENV = "test";
const url = process.env.TEST_DATABASE_URL;
if (!url)
  throw new Error(
    "TEST_DATABASE_URL must name an isolated test PostgreSQL database",
  );
const schema = `forma_browser_${randomUUID().replaceAll("-", "")}`;
const admin = new pg.Pool({ connectionString: url, max: 2 });
await admin.query(`CREATE SCHEMA "${schema}"`);
const pool = new pg.Pool({
  connectionString: url,
  options: `-c search_path=${schema}`,
  max: 8,
});
for (const file of (
  await readdir(new URL("../server/migrations/", import.meta.url))
)
  .filter((f) => /^\d{4}[-_].+\.sql$/.test(f))
  .sort()) {
  await pool.query(
    await readFile(
      new URL(`../server/migrations/${file}`, import.meta.url),
      "utf8",
    ),
  );
}
const app = await createApp({
  pool,
  config: {
    environment: "test",
    appOrigin: "http://127.0.0.1:5175",
    authSecret: "forma-local-auth-secret-at-least-32-characters",
    workerSharedSecret: "forma-local-worker-secret-at-least-32-characters",
    emailFrom: "accounts@forma.test",
    emailSinkEnabled: true,
    authRateLimitMax: 1000,
  },
});
await app.listen({ host: "127.0.0.1", port: 3001 });
const control = createServer((request, response) => {
  const target = new URL(request.url ?? "/", "http://127.0.0.1:3002");
  response.setHeader("cache-control", "no-store");
  response.setHeader("content-type", "application/json");
  if (request.method !== "GET" || target.pathname !== "/emails") {
    response.writeHead(404).end("{}");
    return;
  }
  const email = target.searchParams.get("email");
  if (!email) {
    response.writeHead(400).end("{}");
    return;
  }
  response.end(
    JSON.stringify(
      inspectEmailSink().filter((message) => message.email === email),
    ),
  );
});
control.listen(3002, "127.0.0.1");
console.log("Isolated account API and email test control ready");
let closing = false;
async function close() {
  if (closing) return;
  closing = true;
  control.close();
  await app.close();
  await pool.end();
  await admin.query(`DROP SCHEMA "${schema}" CASCADE`);
  await admin.end();
}
process.once("SIGINT", () => void close());
process.once("SIGTERM", () => void close());
