import { strict as assert } from "node:assert";
import { test } from "node:test";
import { handleApiRequest, type Env } from "../index.ts";

// Gateway behaviour for read-only coach access (bearer token) and the
// member-session routes that manage those tokens.

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

const token = `forma_coach_${"a".repeat(43)}`;

test("COACH-01: the bearer header reaches the origin only on the coach read route, without cookies", async () => {
  let seen: Headers | undefined;
  const response = await handleApiRequest(
    edgeRequest("/api/coach/workspace?days=28", {
      headers: {
        authorization: `Bearer ${token}`,
        cookie: "forma.session_token=should-not-travel",
        "x-forma-member": "mem_should-not-travel",
        "x-request-id": "coach-1",
      },
    }),
    env,
    async (input, init) => {
      assert.equal(
        new URL(input.toString()).href,
        "https://api.internal.example/api/coach/workspace?days=28",
      );
      seen = new Headers(init?.headers);
      return json('{"days":28}');
    },
  );
  assert.equal(response.status, 200);
  assert.ok(seen);
  assert.equal(seen.get("authorization"), `Bearer ${token}`);
  assert.equal(seen.has("cookie"), false);
  assert.equal(seen.has("x-forma-member"), false);
  assert.equal(seen.get("x-forma-worker-secret"), "test-worker-secret");
  assert.equal(seen.get("x-forma-client-ip"), "198.51.100.42");
  assert.equal(seen.get("x-request-id"), "coach-1");
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("COACH-02: malformed Authorization values are dropped and other routes never see the header", async () => {
  for (const value of [
    "Basic dXNlcjpwYXNz",
    "Bearer",
    "Bearer two tokens",
    `Bearer ${"x".repeat(121)}`,
    "Bearer <script>",
  ]) {
    let seen: Headers | undefined;
    await handleApiRequest(
      edgeRequest("/api/coach/workspace", {
        headers: { authorization: value },
      }),
      env,
      async (_input, init) => {
        seen = new Headers(init?.headers);
        return json();
      },
    );
    assert.equal(seen?.has("authorization"), false, value);
  }
  for (const path of ["/api/workspace", "/api/account/coach-tokens"]) {
    let seen: Headers | undefined;
    await handleApiRequest(
      edgeRequest(path, {
        headers: {
          authorization: `Bearer ${token}`,
          cookie: "forma.session_token=abc",
        },
      }),
      env,
      async (_input, init) => {
        seen = new Headers(init?.headers);
        return json();
      },
    );
    assert.equal(seen?.has("authorization"), false, path);
    assert.equal(seen?.get("cookie"), "forma.session_token=abc", path);
  }
});

test("COACH-03: coach routes accept only their intended methods and shapes", async () => {
  const routed: string[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    routed.push(`${init?.method} ${new URL(input.toString()).pathname}`);
    return json();
  };
  const origin = { origin: "https://forma.example" };
  const id = "b".repeat(22);
  const allowed = await Promise.all([
    handleApiRequest(edgeRequest("/api/coach/workspace"), env, fetcher),
    handleApiRequest(edgeRequest("/api/account/coach-tokens"), env, fetcher),
    handleApiRequest(
      edgeRequest("/api/account/coach-tokens", {
        method: "POST",
        headers: { ...origin, "content-type": "application/json" },
        body: '{"label":"Claude"}',
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest(`/api/account/coach-tokens/${id}`, {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
  ]);
  for (const response of allowed) assert.equal(response.status, 200);
  assert.deepEqual(routed, [
    "GET /api/coach/workspace",
    "GET /api/account/coach-tokens",
    "POST /api/account/coach-tokens",
    `DELETE /api/account/coach-tokens/${id}`,
  ]);

  const refused = await Promise.all([
    handleApiRequest(
      edgeRequest("/api/coach/workspace", { method: "POST", headers: origin }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest("/api/coach/workspace", {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest("/api/account/coach-tokens", {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest(`/api/account/coach-tokens/${id}`, { method: "GET" }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest("/api/account/coach-tokens/short", {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
    handleApiRequest(
      edgeRequest(`/api/account/coach-tokens/${id}/extra`, {
        method: "DELETE",
        headers: origin,
      }),
      env,
      fetcher,
    ),
    handleApiRequest(edgeRequest("/api/coach"), env, fetcher),
    handleApiRequest(edgeRequest("/api/coach/tokens"), env, fetcher),
  ]);
  assert.deepEqual(
    refused.map((response) => response.status),
    [405, 405, 405, 405, 404, 404, 404, 404],
  );
  assert.equal(routed.length, 4);
});

test("COACH-04: minting and revoking tokens still need the same-origin browser context", async () => {
  let calls = 0;
  const fetcher = async () => {
    calls += 1;
    return json();
  };
  const crossOrigin = await handleApiRequest(
    edgeRequest("/api/account/coach-tokens", {
      method: "POST",
      headers: {
        origin: "https://attacker.example",
        "content-type": "application/json",
      },
      body: "{}",
    }),
    env,
    fetcher,
  );
  assert.equal(crossOrigin.status, 403);
  const noOrigin = await handleApiRequest(
    edgeRequest(`/api/account/coach-tokens/${"c".repeat(22)}`, {
      method: "DELETE",
    }),
    env,
    fetcher,
  );
  assert.equal(noOrigin.status, 403);
  const crossSiteRead = await handleApiRequest(
    edgeRequest("/api/coach/workspace", {
      headers: {
        "sec-fetch-site": "cross-site",
        authorization: `Bearer ${token}`,
      },
    }),
    env,
    fetcher,
  );
  // A browser on another site cannot use the member's bearer token either.
  assert.equal(crossSiteRead.status, 403);
  assert.equal(calls, 0);
});
