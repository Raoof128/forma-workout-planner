import { strict as assert } from "node:assert";
import { test } from "node:test";
import { handleApiRequest, sanitiseSetCookie, type Env } from "../index.ts";

// Edge regressions from the 2026-10-12 red-team engagement (EDGE-01..07).
// See docs/security/penetration-test-report.md.

const env: Env = {
  BACKEND_URL: "https://api.internal.example",
  APP_ORIGIN: "https://forma.example",
  ACCESS_CLIENT_ID: "test-access-id",
  ACCESS_CLIENT_SECRET: "test-access-secret",
  FORMA_WORKER_SECRET: "test-worker-secret",
  ENVIRONMENT: "production",
  ASSETS: { fetch: async () => new Response("asset") },
};

function edgeRequest(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("cf-connecting-ip", "198.51.100.42");
  return new Request(`https://forma.example${path}`, { ...init, headers });
}

const json = (body = "{}", init: ResponseInit = {}) =>
  new Response(body, {
    ...init,
    headers: { "content-type": "application/json", ...(init.headers ?? {}) },
  });

test("EDGE-01: non-workspace routes accept only small bodies", async () => {
  let calls = 0;
  const big = "x".repeat(64 * 1024 + 1);
  for (const path of ["/api/auth/sign-up/email", "/api/auth/sign-in/email"]) {
    const response = await handleApiRequest(
      edgeRequest(path, {
        method: "POST",
        headers: { origin: "https://forma.example" },
        body: big,
      }),
      env,
      async (_input, init) => {
        calls += 1;
        await new Response(init?.body).arrayBuffer();
        return json();
      },
    );
    assert.equal(response.status, 413, path);
  }
  const declared = await handleApiRequest(
    edgeRequest("/api/auth/sign-up/email", {
      method: "POST",
      headers: {
        origin: "https://forma.example",
        "content-length": String(64 * 1024 + 1),
      },
    }),
    env,
    async () => json(),
  );
  assert.equal(declared.status, 413);
  // The workspace document keeps its larger allowance.
  const workspace = await handleApiRequest(
    edgeRequest("/api/workspace", {
      method: "PUT",
      headers: { origin: "https://forma.example" },
      body: "x".repeat(1024 * 1024),
    }),
    env,
    async (_input, init) => {
      await new Response(init?.body).arrayBuffer();
      return json();
    },
  );
  assert.equal(workspace.status, 200);
  assert.ok(calls <= 2);
});

test("EDGE-02: only allowlisted request headers reach the origin", async () => {
  let seen: Headers | undefined;
  await handleApiRequest(
    edgeRequest("/api/workspace", {
      headers: {
        cookie: "forma.session_token=abc",
        "x-forma-member": "mem_abc",
        "fastly-client-ip": "127.0.0.1",
        "x-cluster-client-ip": "127.0.0.1",
        "x-http-method-override": "DELETE",
        "x-original-host": "admin.internal",
        authorization: "Bearer attacker",
        via: "1.1 attacker",
        "cf-ipcountry": "XX",
      },
    }),
    env,
    async (_input, init) => {
      seen = new Headers(init?.headers);
      return json();
    },
  );
  assert.ok(seen);
  assert.equal(seen.get("cookie"), "forma.session_token=abc");
  assert.equal(seen.get("x-forma-member"), "mem_abc");
  assert.equal(seen.get("x-forma-client-ip"), "198.51.100.42");
  for (const name of [
    "fastly-client-ip",
    "x-cluster-client-ip",
    "x-http-method-override",
    "x-original-host",
    "authorization",
    "via",
    "cf-ipcountry",
    "cf-connecting-ip",
  ])
    assert.equal(seen.has(name), false, name);
});

test("EDGE-03: upstream headers and cookies are allowlisted and scoped to the app host", async () => {
  const upstream = () => {
    const headers = new Headers({
      "content-type": "application/json",
      "access-control-allow-origin": "https://evil.example",
      "access-control-allow-credentials": "true",
      "strict-transport-security": "max-age=0",
      "clear-site-data": '"*"',
      refresh: "0;url=https://evil.example",
      server: "fastify",
      "x-powered-by": "node",
      "x-forma-internal": "secret-topology",
      "retry-after": "60",
    });
    headers.append(
      "set-cookie",
      "__Secure-forma.session_token=ok; Path=/; Domain=.example.invalid; HttpOnly; Secure; SameSite=Lax",
    );
    headers.append(
      "set-cookie",
      "CF_Authorization=service-jwt; Path=/; HttpOnly; Secure",
    );
    return new Response("{}", { headers });
  };
  const response = await handleApiRequest(
    edgeRequest("/api/workspace"),
    env,
    async () => upstream(),
  );
  for (const name of [
    "access-control-allow-origin",
    "access-control-allow-credentials",
    "clear-site-data",
    "refresh",
    "server",
    "x-powered-by",
    "x-forma-internal",
  ])
    assert.equal(response.headers.get(name), null, name);
  assert.equal(response.headers.get("retry-after"), "60");
  assert.equal(
    response.headers.get("strict-transport-security"),
    "max-age=31536000; includeSubDomains",
  );
  const cookies = response.headers.getSetCookie();
  assert.equal(cookies.length, 1);
  assert.match(cookies[0], /^__Secure-forma\.session_token=ok;/);
  assert.doesNotMatch(cookies[0], /domain/i);
  assert.equal(sanitiseSetCookie("CF_Authorization=x"), null);
  assert.equal(
    sanitiseSetCookie("forma.x=1; Domain=evil; Path=/"),
    "forma.x=1; Path=/",
  );
});

test("EDGE-04: API responses carry restrictive security headers and only JSON or text bodies", async () => {
  const ok = await handleApiRequest(
    edgeRequest("/api/workspace"),
    env,
    async () => json(),
  );
  assert.match(
    ok.headers.get("content-security-policy") ?? "",
    /default-src 'none'/,
  );
  assert.equal(ok.headers.get("x-frame-options"), "DENY");
  assert.equal(ok.headers.get("referrer-policy"), "no-referrer");
  for (const type of [
    "image/svg+xml",
    "application/xhtml+xml",
    "text/xml",
    "text/html; charset=utf-8",
    "multipart/x-mixed-replace",
  ]) {
    const response = await handleApiRequest(
      edgeRequest("/api/workspace"),
      env,
      async () =>
        new Response("<svg onload=alert(1)>", {
          headers: { "content-type": type },
        }),
    );
    assert.equal(response.status, 502, type);
    assert.doesNotMatch(await response.text(), /svg/);
  }
});

test("EDGE-05: malformed upstream redirects and informational statuses fail closed", async () => {
  const missing = await handleApiRequest(
    edgeRequest("/api/auth/verify-email?token=x"),
    env,
    async () => new Response(null, { status: 302 }),
  );
  assert.equal(missing.status, 502);
});

test("EDGE-06: cross-site API requests are refused except token email links", async () => {
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return json();
  };
  const crossSiteRead = await handleApiRequest(
    edgeRequest("/api/workspace/export", {
      headers: { "sec-fetch-site": "cross-site" },
    }),
    env,
    fetcher,
  );
  assert.equal(crossSiteRead.status, 403);
  const crossSiteAuth = await handleApiRequest(
    edgeRequest("/api/auth/get-session", {
      headers: { "sec-fetch-site": "cross-site" },
    }),
    env,
    fetcher,
  );
  assert.equal(crossSiteAuth.status, 403);
  for (const path of [
    "/api/auth/verify-email?token=abc",
    "/api/auth/reset-password/abc?callbackURL=%2F",
    "/api/auth/delete-user/callback?token=abc",
  ]) {
    const link = await handleApiRequest(
      edgeRequest(path, { headers: { "sec-fetch-site": "cross-site" } }),
      env,
      fetcher,
    );
    assert.equal(link.status, 200, path);
  }
  assert.equal(calls, 3);
});

test("EDGE-07: production refuses API traffic that lacks the edge client IP", async () => {
  let calls = 0;
  const response = await handleApiRequest(
    new Request("https://forma.example/api/workspace"),
    env,
    async () => {
      calls += 1;
      return json();
    },
  );
  assert.equal(response.status, 503);
  assert.equal(calls, 0);
});

test("EDGE-08: gateway errors carry HSTS and assets forbid base URL rewriting (ASVS V3.4.1, V3.4.3)", async () => {
  const blocked = await handleApiRequest(
    edgeRequest("/api/unknown"),
    env,
    async () => json(),
  );
  assert.equal(blocked.status, 404);
  assert.match(
    blocked.headers.get("strict-transport-security") ?? "",
    /max-age=31536000/,
  );
  const worker = (await import("../index.ts")).default;
  const page = await worker.fetch(new Request("https://forma.example/"), env);
  assert.match(
    page.headers.get("content-security-policy") ?? "",
    /base-uri 'none'/,
  );
});

test("EDGE-09: only FORMA cookies are forwarded to the origin (deployment hardening)", async () => {
  let seen: Headers | undefined;
  await handleApiRequest(
    edgeRequest("/api/workspace", {
      headers: {
        cookie:
          "CF_Authorization=access-jwt; __Secure-forma.session_token=s1; other=x; forma.two_factor=t",
      },
    }),
    env,
    async (_input, init) => {
      seen = new Headers(init?.headers);
      return json();
    },
  );
  assert.equal(
    seen?.get("cookie"),
    "__Secure-forma.session_token=s1; forma.two_factor=t",
  );
  await handleApiRequest(
    edgeRequest("/api/workspace", {
      headers: { cookie: "CF_Authorization=x" },
    }),
    env,
    async (_input, init) => {
      seen = new Headers(init?.headers);
      return json();
    },
  );
  assert.equal(seen?.has("cookie"), false);
});
