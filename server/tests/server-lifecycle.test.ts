import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createServer } from "node:net";
import { dirname, join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import pg from "pg";

const databaseUrl = process.env.TEST_DATABASE_URL;
const testDir = dirname(fileURLToPath(import.meta.url));

async function availablePort(): Promise<number> {
  const server = createServer();
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  assert.ok(address && typeof address === "object");
  await new Promise<void>((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
  return address.port;
}

test(
  "API survives a lost idle database connection and reconnects for account requests",
  { timeout: 20000 },
  async (t) => {
    assert.ok(
      databaseUrl,
      "TEST_DATABASE_URL is required for real PostgreSQL lifecycle coverage.",
    );
    const suffix = randomUUID().replaceAll("-", "");
    const schema = `forma_lifecycle_test_${suffix}`;
    const applicationName = `forma-lifecycle-${suffix}`;
    const admin = new pg.Pool({ connectionString: databaseUrl });
    const setup = new pg.Pool({
      connectionString: databaseUrl,
      options: `-c search_path=${schema}`,
    });
    t.after(async () => {
      await setup.end();
      await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
      await admin.end();
    });
    await admin.query(`CREATE SCHEMA ${schema}`);
    for (const name of [
      "0001-auth.sql",
      "0002-workspace.sql",
      "0003-security-throttle.sql",
      "0004-routine-programming.sql",
    ]) {
      await setup.query(
        await readFile(join(testDir, "..", "migrations", name), "utf8"),
      );
    }
    const connection = new URL(databaseUrl);
    connection.searchParams.set("application_name", applicationName);
    connection.searchParams.set("options", `-c search_path=${schema}`);
    const port = await availablePort();
    const origin = `http://127.0.0.1:${port}`;
    const workerSecret = `synthetic-worker-${suffix}`;
    const child = spawn(
      process.execPath,
      ["--import", "tsx", join(testDir, "..", "index.ts")],
      {
        cwd: join(testDir, "..", ".."),
        env: {
          ...process.env,
          NODE_ENV: "test",
          DATABASE_URL: connection.toString(),
          APP_ORIGIN: origin,
          AUTH_SECRET: `synthetic-auth-${suffix}`,
          ORIGIN_SHARED_SECRET: workerSecret,
          EMAIL_SINK_ENABLED: "true",
          PORT: String(port),
          HOST: "127.0.0.1",
        },
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    let stderr = "";
    child.stderr.on("data", (chunk) => {
      stderr += String(chunk);
    });
    child.stdout.resume();
    const exited = new Promise<void>((resolve) =>
      child.once("exit", () => resolve()),
    );
    t.after(async () => {
      if (child.exitCode === null && child.signalCode === null) {
        child.kill("SIGTERM");
        const timer = setTimeout(() => child.kill("SIGKILL"), 2000);
        try {
          await exited;
        } finally {
          clearTimeout(timer);
        }
      }
    });
    let healthy = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      assert.equal(child.exitCode, null, "API must start successfully");
      try {
        const response = await fetch(origin + "/healthz");
        await response.text();
        if (response.ok) {
          healthy = true;
          break;
        }
      } catch {
        /* Wait for the local listener to open. */
      }
      await delay(50);
    }
    assert.equal(healthy, true);
    const terminated = await admin.query<{ pid: number; stopped: boolean }>(
      "SELECT pid, pg_terminate_backend(pid) AS stopped FROM pg_stat_activity WHERE application_name = $1 AND state = 'idle'",
      [applicationName],
    );
    assert.equal(terminated.rowCount, 1);
    assert.equal(terminated.rows[0].stopped, true);
    // Wait until PostgreSQL's error reaches the idle client's event listener.
    for (
      let attempt = 0;
      attempt < 100 && !stderr && child.exitCode === null;
      attempt++
    )
      await delay(10);
    await delay(50);
    assert.equal(
      child.exitCode,
      null,
      "An idle connection failure must not terminate the API",
    );
    assert.equal(
      stderr.trim(),
      "FORMA database connection lost; discarded idle connection.",
    );
    const response = await fetch(origin + "/api/auth/sign-in/email", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin,
        "x-forma-worker-secret": workerSecret,
        "x-forma-client-ip": "198.51.100.42",
      },
      body: JSON.stringify({
        email: `missing-${suffix}@example.test`,
        password: "Synthetic-password-123!",
      }),
    });
    await response.text();
    assert.equal(
      response.status,
      401,
      "The recovered connection must reach the normal account response",
    );
    const replacement = await admin.query<{ pid: number }>(
      "SELECT pid FROM pg_stat_activity WHERE application_name = $1",
      [applicationName],
    );
    assert.ok(
      replacement.rows.some((row) => row.pid !== terminated.rows[0].pid),
    );
    assert.equal(child.exitCode, null);
  },
);
