import assert from "node:assert/strict";
import { Buffer } from "node:buffer";
import { test } from "node:test";
import dashboard, { safeStatus, verifyAccess } from "./dashboard.mjs";
const { crypto, Request, Response, TextEncoder } = globalThis;

test("anonymous and forged requests never read operational state", async () => {
  let reads = 0;
  const env = {
    HOSTNAME: "forma-ops.example.test",
    ACCESS_ISSUER: "https://team.cloudflareaccess.com",
    ACCESS_AUDIENCE: "expected",
    OWNER_EMAIL: "owner@example.test",
    STATE: {
      get: async () => {
        reads++;
        return {};
      },
    },
  };
  for (const header of [undefined, "bad.jwt.signature"]) {
    const request = new Request("https://forma-ops.example.test/api/status", {
      headers: header ? { "Cf-Access-Jwt-Assertion": header } : {},
    });
    assert.equal((await dashboard.fetch(request, env)).status, 401);
  }
  assert.equal(reads, 0);
});

test("display status strips secrets and limits log records", () => {
  const result = safeStatus({
    checkedAt: "2026-10-13T03:00:00Z",
    failures: 1,
    signals: ["off_host_backup_missing", "secret@example.test"],
    secret: "never display",
    journal: Array.from({ length: 80 }, () => ({
      at: "2026-10-13T03:00:00Z",
      event: "healthy",
      signals: [],
      email: "private",
    })),
  });
  assert.equal(result.journal.length, 40);
  assert.deepEqual(result.signals, ["off_host_backup_missing"]);
  assert.equal(JSON.stringify(result).includes("private"), false);
  assert.equal(JSON.stringify(result).includes("secret"), false);
});

test("correctly signed JWT still needs the right audience and owner", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const key = await crypto.subtle.exportKey("jwk", pair.publicKey);
  key.kid = "test";
  const env = {
    ACCESS_ISSUER: "https://team.cloudflareaccess.com",
    ACCESS_AUDIENCE: "expected",
    OWNER_EMAIL: "owner@example.test",
  };
  const fetchKey = async (_url, init) => {
    assert.equal(init.redirect, "manual");
    return Response.json({ keys: [key] });
  };
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  const sign = async (claims) => {
    const input = encode({ alg: "RS256", kid: "test" }) + "." + encode(claims);
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      pair.privateKey,
      new TextEncoder().encode(input),
    );
    return input + "." + Buffer.from(signature).toString("base64url");
  };
  const claims = {
    iss: env.ACCESS_ISSUER,
    aud: [env.ACCESS_AUDIENCE],
    exp: Math.floor(Date.now() / 1000) + 60,
    email: env.OWNER_EMAIL,
  };
  assert.equal(await verifyAccess(await sign(claims), env, fetchKey), true);
  assert.equal(
    await verifyAccess(
      await sign({ ...claims, aud: "expected" }),
      env,
      fetchKey,
    ),
    true,
  );
  assert.equal(
    await verifyAccess(await sign({ ...claims, aud: "other" }), env, fetchKey),
    false,
  );
  assert.equal(
    await verifyAccess(
      await sign({ ...claims, aud: ["other"] }),
      env,
      fetchKey,
    ),
    false,
  );
  assert.equal(
    await verifyAccess(
      await sign({ ...claims, email: "another@example.test" }),
      env,
      fetchKey,
    ),
    false,
  );
  assert.equal(
    await verifyAccess(await sign({ ...claims, exp: 1 }), env, fetchKey),
    false,
  );
});
