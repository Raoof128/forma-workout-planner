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

test("coach failures preserve the bearer challenge without forwarding private origin headers", async () => {
  for (const [status, challenge] of [
    [401, 'Bearer realm="forma-coach"'],
    [403, 'Bearer realm="forma-coach", error="insufficient_scope"'],
  ] as const) {
    const response = await handleApiRequest(
      edgeRequest("/api/coach/workspace/data"),
      env,
      async () =>
        json('{"error":"unauthorized"}', {
          status,
          headers: {
            "www-authenticate": challenge,
            "cf-access-client-secret": "private-origin-header",
            "x-origin-debug": "private-origin-header",
          },
        }),
    );
    assert.equal(response.status, status);
    assert.equal(response.headers.get("www-authenticate"), challenge);
    assert.equal(response.headers.get("cf-access-client-secret"), null);
    assert.equal(response.headers.get("x-origin-debug"), null);
    assert.equal(response.headers.get("cache-control"), "no-store");
    await response.text();
  }
});

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

test("COACH-05: full-access routes forward the bearer only, and edits need no browser Origin", async () => {
  const seen: {
    method?: string;
    path: string;
    headers: Headers;
    size: number;
  }[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers);
    const body = init?.body
      ? await new Response(init.body as BodyInit).arrayBuffer()
      : new ArrayBuffer(0);
    seen.push({
      method: init?.method,
      path: new URL(input.toString()).pathname,
      headers,
      size: body.byteLength,
    });
    return json();
  };
  const bearer = { authorization: `Bearer ${token}` };
  const ambient = {
    cookie: "forma.session_token=abc; other=1",
    "x-forma-member": "member-ref",
  };
  // A server-side tool: bearer, JSON, no Origin, no Fetch metadata.
  const edit = await handleApiRequest(
    edgeRequest("/api/coach/workspace/data", {
      method: "PATCH",
      headers: { ...bearer, ...ambient, "content-type": "application/json" },
      body: JSON.stringify({ changes: { schedule: [1] } }),
    }),
    env,
    fetcher,
  );
  assert.equal(edit.status, 200);
  const read = await handleApiRequest(
    edgeRequest("/api/coach/workspace/data", {
      headers: { ...bearer, ...ambient },
    }),
    env,
    fetcher,
  );
  assert.equal(read.status, 200);
  const search = await handleApiRequest(
    edgeRequest("/api/coach/exercises?q=row", { headers: bearer }),
    env,
    fetcher,
  );
  assert.equal(search.status, 200);
  assert.deepEqual(
    seen.map((item) => `${item.method} ${item.path}`),
    [
      "PATCH /api/coach/workspace/data",
      "GET /api/coach/workspace/data",
      "GET /api/coach/exercises",
    ],
  );
  for (const item of seen) {
    assert.equal(item.headers.get("authorization"), `Bearer ${token}`);
    assert.equal(item.headers.get("cookie"), null);
    assert.equal(item.headers.get("x-forma-member"), null);
  }

  // A large edit (a whole history) is allowed the workspace body limit.
  const big = "x".repeat(200 * 1024);
  const large = await handleApiRequest(
    edgeRequest("/api/coach/workspace/data", {
      method: "PATCH",
      headers: { ...bearer, "content-type": "application/json" },
      body: JSON.stringify({ note: big }),
    }),
    env,
    fetcher,
  );
  assert.equal(large.status, 200);
  assert.ok(seen.at(-1)!.size > 200 * 1024);

  let calls = 0;
  const counting = async () => {
    calls += 1;
    return json();
  };
  const refused = await Promise.all([
    // A web page on another site cannot drive an edit, even with a token.
    handleApiRequest(
      edgeRequest("/api/coach/workspace/data", {
        method: "PATCH",
        headers: { ...bearer, origin: "https://attacker.example" },
        body: "{}",
      }),
      env,
      counting,
    ),
    handleApiRequest(
      edgeRequest("/api/coach/workspace/data", {
        method: "PATCH",
        headers: { ...bearer, "sec-fetch-site": "cross-site" },
        body: "{}",
      }),
      env,
      counting,
    ),
    // Only PATCH edits; PUT, POST and DELETE stay closed on the coach routes.
    ...["PUT", "POST", "DELETE"].map((method) =>
      handleApiRequest(
        edgeRequest("/api/coach/workspace/data", {
          method,
          headers: bearer,
          body: method === "DELETE" ? undefined : "{}",
        }),
        env,
        counting,
      ),
    ),
    handleApiRequest(
      edgeRequest("/api/coach/exercises", {
        method: "POST",
        headers: bearer,
        body: "{}",
      }),
      env,
      counting,
    ),
    handleApiRequest(
      edgeRequest("/api/coach/workspace/data/extra"),
      env,
      counting,
    ),
  ]);
  assert.deepEqual(
    refused.map((response) => response.status),
    [403, 403, 405, 405, 405, 405, 404],
  );
  assert.equal(calls, 0);

  // The member's own workspace save still needs the same-origin proof.
  const memberSave = await handleApiRequest(
    edgeRequest("/api/workspace", {
      method: "PUT",
      headers: { ...ambient, "content-type": "application/json" },
      body: "{}",
    }),
    env,
    counting,
  );
  assert.equal(memberSave.status, 403);
  // And the bearer header never reaches the member routes.
  const elsewhere: Headers[] = [];
  await handleApiRequest(
    edgeRequest("/api/workspace", { headers: bearer }),
    env,
    async (_input, init) => {
      elsewhere.push(new Headers(init?.headers));
      return json();
    },
  );
  assert.equal(elsewhere[0].get("authorization"), null);
});
