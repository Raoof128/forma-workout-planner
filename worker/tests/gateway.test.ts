import { strict as assert } from "node:assert";
import { test } from "node:test";
import worker, { handleApiRequest, type Env } from "../index.ts";

const env: Env = {
  BACKEND_URL: "https://api.internal.example",
  APP_ORIGIN: "https://forma.example",
  ACCESS_CLIENT_ID: "test-access-id",
  ACCESS_CLIENT_SECRET: "test-access-secret",
  FORMA_WORKER_SECRET: "test-worker-secret",
  ASSETS: { fetch: async () => new Response("asset") },
};

function request(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  // Model Cloudflare replacing this value at the public edge, even when the
  // browser supplied a forged value in RequestInit.
  headers.set("cf-connecting-ip", "198.51.100.42");
  return new Request(`https://forma.example${path}`, { ...init, headers });
}

test("proxies only the approved fixed-origin API routes and strips spoofable headers", async () => {
  let seenUrl: URL | undefined;
  let seenHeaders: Headers | undefined;
  const response = await handleApiRequest(
    request("/api/workspace?include=history", {
      method: "GET",
      headers: {
        cookie: "__Secure-forma.session_token=member-cookie",
        "cf-access-client-id": "attacker-id",
        "cf-access-client-secret": "attacker-secret",
        "cf-connecting-ip": "203.0.113.10",
        "x-forma-client-ip": "203.0.113.11",
        "x-forma-worker-secret": "attacker-worker-secret",
        "x-forwarded-for": "127.0.0.1",
        "x-user-id": "attacker-user",
        "x-request-id": "trace-1",
      },
    }),
    env,
    async (input, init) => {
      seenUrl = new URL(input.toString());
      seenHeaders = new Headers(init?.headers);
      return new Response('{"revision":3}', {
        headers: { "content-type": "application/json" },
      });
    },
  );

  assert.equal(
    seenUrl?.href,
    "https://api.internal.example/api/workspace?include=history",
  );
  assert.equal(
    seenHeaders?.get("cookie"),
    "__Secure-forma.session_token=member-cookie",
  );
  assert.equal(seenHeaders?.get("cf-access-client-id"), "test-access-id");
  assert.equal(
    seenHeaders?.get("cf-access-client-secret"),
    "test-access-secret",
  );
  assert.equal(seenHeaders?.get("x-forma-worker-secret"), "test-worker-secret");
  assert.equal(seenHeaders?.has("cf-connecting-ip"), false);
  assert.equal(seenHeaders?.get("x-forma-client-ip"), "198.51.100.42");
  assert.equal(seenHeaders?.has("x-forwarded-for"), false);
  assert.equal(seenHeaders?.has("x-user-id"), false);
  assert.equal(seenHeaders?.get("x-request-id"), "trace-1");
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.status, 200);
  assert.equal(await response.text(), '{"revision":3}');
});

test("blocks unknown, ambiguous, and non-API paths without calling the origin", async () => {
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return new Response("unexpected");
  };
  for (const path of [
    "/api",
    "/api/admin/users",
    "/api/account/other",
    "/api/account/sessions/not-a-reference/revoke",
    "/api/%2fworkspace",
    "/api/auth//session",
    "/api/auth/%252f",
    "/dashboard",
  ]) {
    const response = await handleApiRequest(request(path), env, fetcher);
    assert.ok(response.status === 404);
    assert.equal(
      response.headers.get("content-type")?.startsWith("application/json"),
      true,
    );
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
  assert.equal(calls, 0);
});

test("allows only the account session routes and their intended methods", async () => {
  const routed: string[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    routed.push(`${init?.method} ${new URL(input.toString()).pathname}`);
    return new Response("{}", {
      headers: { "content-type": "application/json" },
    });
  };
  const id = "a".repeat(43);
  const origin = { origin: "https://forma.example" };
  const responses = await Promise.all([
    handleApiRequest(request("/api/account/sessions"), env, fetcher),
    handleApiRequest(
      request(`/api/account/sessions/${id}/revoke`, {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      request("/api/account/sessions/revoke-others", {
        method: "POST",
        headers: origin,
        body: "{}",
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      request("/api/account/sessions/revoke-all", {
        method: "POST",
        headers: origin,
        body: "{}",
      }),
      env,
      fetcher,
    ),
  ]);
  assert.deepEqual(
    responses.map((response) => response.status),
    [200, 200, 200, 200],
  );
  assert.deepEqual(routed, [
    "GET /api/account/sessions",
    `DELETE /api/account/sessions/${id}/revoke`,
    "POST /api/account/sessions/revoke-others",
    "POST /api/account/sessions/revoke-all",
  ]);
  for (const response of responses) await response.text();
  const unsupported = await handleApiRequest(
    request("/api/account/sessions", { method: "DELETE", headers: origin }),
    env,
    fetcher,
  );
  assert.equal(unsupported.status, 405);
});

test("Worker routes `/api` and unknown API paths before static assets while securing SPA responses", async () => {
  let assets = 0;
  const workerEnv: Env = {
    ...env,
    ASSETS: {
      fetch: async () => {
        assets += 1;
        return new Response("app shell");
      },
    },
  };
  const api = await worker.fetch(request("/api"), workerEnv);
  const unknownApi = await worker.fetch(request("/api/missing"), workerEnv);
  assert.equal(api.status, 404);
  assert.equal(unknownApi.status, 404);
  assert.equal(assets, 0);

  const page = await worker.fetch(request("/account"), workerEnv);
  assert.equal(await page.text(), "app shell");
  assert.equal(
    page.headers.get("content-security-policy")?.includes("default-src 'self'"),
    true,
  );
  assert.equal(page.headers.get("x-content-type-options"), "nosniff");
  assert.equal(assets, 1);
});

test("requires the exact app Origin for writes and rejects untrusted Origins", async () => {
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return new Response("ok");
  };
  const missing = await handleApiRequest(
    request("/api/workspace", { method: "PUT", body: "{}" }),
    env,
    fetcher,
  );
  const hostile = await handleApiRequest(
    request(`/api/account/sessions/${"a".repeat(43)}/revoke`, {
      method: "DELETE",
      headers: { origin: "https://evil.example" },
    }),
    env,
    fetcher,
  );
  const valid = await handleApiRequest(
    request("/api/workspace", {
      method: "PUT",
      headers: { origin: "https://forma.example" },
      body: "{}",
    }),
    env,
    fetcher,
  );
  assert.equal(missing.status, 403);
  assert.equal(hostile.status, 403);
  assert.equal(valid.status, 200);
  assert.equal(calls, 1);
  await valid.text();
});

test("does not follow redirects and rewrites only same-origin backend redirects", async () => {
  let redirect: Response | undefined;
  const sameOrigin = await handleApiRequest(
    request("/api/auth/sign-in/social"),
    env,
    async (_input, init) => {
      assert.equal(init?.redirect, "manual");
      const headers = new Headers({
        location: "/api/auth/callback/google?state=x#account",
      });
      headers.append(
        "set-cookie",
        "forma.state=opaque; Path=/; HttpOnly; Secure",
      );
      return new Response(null, { status: 302, headers });
    },
  );
  assert.equal(
    sameOrigin.headers.get("location"),
    "https://forma.example/api/auth/callback/google?state=x#account",
  );
  assert.equal(sameOrigin.headers.getSetCookie().length, 1);
  redirect = await handleApiRequest(
    request("/api/auth/callback"),
    env,
    async () =>
      new Response(null, {
        status: 302,
        headers: { location: "https://attacker.example/steal" },
      }),
  );
  assert.equal(redirect.status, 502);
  assert.equal(redirect.headers.get("location"), null);
  const notModified = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () => new Response(null, { status: 304 }),
  );
  assert.equal(notModified.status, 304);
});

test("preserves multiple Set-Cookie headers and never caches private API responses", async () => {
  const response = await handleApiRequest(
    request("/api/auth/get-session"),
    env,
    async () => {
      const headers = new Headers();
      headers.append("set-cookie", "forma.session=first; Path=/; HttpOnly");
      headers.append("set-cookie", "forma.csrf=second; Path=/; Secure");
      headers.set("cache-control", "public, max-age=3600");
      return new Response("{}", { headers });
    },
  );
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.getSetCookie().length, 2);
  await response.text();
});

test("does not pass through an Access login page or other HTML as an API response", async () => {
  const response = await handleApiRequest(
    request("/api/health"),
    env,
    async () =>
      new Response("<html>login</html>", {
        headers: { "content-type": "text/html" },
      }),
  );
  assert.equal(response.status, 502);
  assert.equal(
    response.headers.get("content-type")?.startsWith("application/json"),
    true,
  );
  assert.equal(
    await response.text(),
    '{"error":"The API returned an invalid response type"}',
  );
});

test("rejects untrusted target configuration and missing gateway credentials", async () => {
  for (const invalid of [
    { ...env, BACKEND_URL: "http://127.0.0.1:3000" },
    { ...env, BACKEND_URL: "https://user:pass@api.internal.example" },
    { ...env, BACKEND_URL: "https://api.internal.example/base" },
    { ...env, FORMA_WORKER_SECRET: "" },
  ]) {
    const response = await handleApiRequest(
      request("/api/health"),
      invalid,
      async () => new Response("must not fetch"),
    );
    assert.equal(response.status, 503);
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
});

test("enforces content length and streaming request limits", async () => {
  const largeLength = await handleApiRequest(
    request("/api/workspace", {
      method: "PUT",
      headers: {
        origin: "https://forma.example",
        "content-length": String(20 * 1024 * 1024 + 16 * 1024 + 1),
      },
    }),
    env,
    async () => new Response("must not fetch"),
  );
  assert.equal(largeLength.status, 413);

  const payload = new Uint8Array(20 * 1024 * 1024 + 16 * 1024 + 1);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(payload);
      controller.close();
    },
  });
  const streaming = await handleApiRequest(
    new Request("https://forma.example/api/workspace", {
      method: "PUT",
      headers: {
        origin: "https://forma.example",
        "cf-connecting-ip": "198.51.100.42",
      },
      body: stream,
      duplex: "half",
    } as RequestInit & { duplex: "half" }),
    env,
    async (_input, init) => {
      await new Response(init?.body).arrayBuffer();
      return new Response("unexpected");
    },
  );
  assert.equal(streaming.status, 413);
});

test("passes backend failures as bounded no-store JSON errors", async () => {
  const response = await handleApiRequest(
    request("/api/health"),
    env,
    async () => {
      throw new Error("secret upstream details");
    },
  );
  assert.equal(response.status, 502);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(
    await response.text(),
    '{"error":"The API is temporarily unavailable"}',
  );
});
