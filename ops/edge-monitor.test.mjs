import assert from "node:assert/strict";
import { test } from "node:test";
import monitor, { inspectHealth } from "./edge-monitor.mjs";

test("an unreachable gateway and a missing remote backup are both detected", async () => {
  const env = {
    APP_ORIGIN: "https://forma.test",
    BACKUPS: { get: async () => null },
  };
  const signals = await inspectHealth(env, async () => {
    throw new Error("offline");
  });
  assert.deepEqual(signals, [
    "public_account_gateway_unreachable",
    "off_host_backup_missing",
  ]);
  assert.equal(monitor.fetch().status, 404);
});

test("a fresh remote backup and successful gateway return healthy", async () => {
  const stamp = new Date()
    .toISOString()
    .replace(/[-:]/g, "")
    .replace(/\.\d+Z$/, "Z");
  const env = {
    APP_ORIGIN: "https://forma.test",
    BACKUPS: {
      get: async () => ({ json: async () => ({ createdAt: stamp }) }),
    },
  };
  assert.deepEqual(
    await inspectHealth(env, async (_url, init) => {
      assert.equal(init.redirect, "manual");
      return new globalThis.Response("ok");
    }),
    [],
  );
});

test("R2 outage still yields an actionable signal alongside gateway failure", async () => {
  const env = {
    APP_ORIGIN: "https://forma.test",
    BACKUPS: {
      get: async () => {
        throw new Error("R2 unavailable");
      },
    },
  };
  assert.deepEqual(
    await inspectHealth(
      env,
      async () => new globalThis.Response("offline", { status: 503 }),
    ),
    ["public_account_gateway_unhealthy", "off_host_backup_unavailable"],
  );
});

test("malformed remote manifests are reported instead of disabling alerts", async () => {
  const env = {
    APP_ORIGIN: "https://forma.test",
    BACKUPS: {
      get: async () => ({
        json: async () => {
          throw new Error("invalid JSON");
        },
      }),
    },
  };
  assert.deepEqual(
    await inspectHealth(env, async () => new globalThis.Response("ok")),
    ["off_host_backup_unavailable"],
  );
});

test("an R2 failure reaches alerts after two checks using independent state", async () => {
  const original = globalThis.fetch;
  const state = new Map();
  let messages = 0;
  const env = {
    APP_ORIGIN: "https://forma.test",
    CLOUDFLARE_ACCOUNT_ID: "test",
    EMAIL_TOKEN: "test",
    EMAIL_FROM: "ops@example.test",
    ALERT_TO: "operator@example.test",
    BACKUPS: {
      get: async () => {
        throw new Error("R2 unavailable");
      },
    },
    STATE: {
      get: async (key) => (state.has(key) ? JSON.parse(state.get(key)) : null),
      put: async (key, value) => state.set(key, value),
    },
  };
  globalThis.fetch = async (url) => {
    if (url.startsWith(env.APP_ORIGIN))
      return new globalThis.Response("healthy");
    messages++;
    return globalThis.Response.json({
      success: true,
      result: { queued: [env.ALERT_TO] },
    });
  };
  try {
    await monitor.scheduled(null, env);
    assert.equal(messages, 0);
    await monitor.scheduled(null, env);
    assert.equal(messages, 1);
    await monitor.scheduled(null, env);
    assert.equal(messages, 1);
  } finally {
    globalThis.fetch = original;
  }
});
