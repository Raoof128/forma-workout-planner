import { strict as assert } from "node:assert";
import { test } from "node:test";
import { handleApiRequest, isNativeClientRequest, type Env } from "../index.ts";

// The iOS app has no Origin to send. It is let through the same-origin write
// rule only when it names itself and carries none of the headers a browser
// always adds. Everything else about the gateway is unchanged.

const env: Env = {
  BACKEND_URL: "https://api.internal.example",
  APP_ORIGIN: "https://forma.example",
  ACCESS_CLIENT_ID: "test-access-id",
  ACCESS_CLIENT_SECRET: "test-access-secret",
  FORMA_WORKER_SECRET: "test-worker-secret",
  ASSETS: { fetch: async () => new Response("asset") },
};

const SESSION_COOKIE = "__Secure-forma.session_token=native-cookie";
const NATIVE = { "x-forma-client": "ios" };

function request(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("cf-connecting-ip", "198.51.100.42");
  return new Request(`https://forma.example${path}`, { ...init, headers });
}

function recorder() {
  const calls: { url: URL; headers: Headers; method?: string }[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({
      url: new URL(input.toString()),
      headers: new Headers(init?.headers),
      method: init?.method,
    });
    return new Response("{}", {
      headers: { "content-type": "application/json" },
    });
  };
  return { calls, fetcher };
}

async function send(
  path: string,
  method: string,
  headers: Record<string, string>,
  body: string | undefined = method === "GET" ? undefined : "{}",
) {
  const { calls, fetcher } = recorder();
  const response = await handleApiRequest(
    request(path, {
      method,
      headers: { "content-type": "application/json", ...headers },
      body,
    }),
    env,
    fetcher,
  );
  return { response, calls };
}

test("NATIVE-01: the predicate needs the exact marker and no browser-only header", () => {
  const native = (headers: Record<string, string>) =>
    isNativeClientRequest(new Headers(headers));
  assert.equal(native(NATIVE), true);
  assert.equal(native({ ...NATIVE, cookie: SESSION_COOKIE }), true);
  assert.equal(native({}), false);
  assert.equal(native({ "x-forma-client": "IOS" }), false);
  assert.equal(native({ "x-forma-client": "ios, ios" }), false);
  assert.equal(native({ "x-forma-client": "android" }), false);
  assert.equal(native({ "x-forma-client": "" }), false);
  for (const [name, value] of [
    ["origin", "https://forma.example"],
    ["origin", "https://attacker.example"],
    ["origin", ""],
    ["origin", "null"],
    ["referer", "https://forma.example/"],
    ["referer", ""],
    ["sec-fetch-site", "same-origin"],
    ["sec-fetch-site", "none"],
    ["sec-fetch-mode", "cors"],
    ["sec-fetch-dest", "empty"],
  ]) {
    assert.equal(
      native({ ...NATIVE, [name]: value }),
      false,
      `${name}: ${value}`,
    );
  }
});

test("NATIVE-02: a native write with a session cookie passes and reaches the origin with the marker", async () => {
  for (const [method, path] of [
    ["POST", "/api/auth/sign-in/email"],
    ["POST", "/api/auth/sign-out"],
    ["PUT", "/api/workspace"],
    ["POST", "/api/account/sessions/revoke-others"],
    ["DELETE", `/api/account/sessions/${"a".repeat(43)}/revoke`],
    ["DELETE", `/api/account/coach-tokens/${"b".repeat(22)}`],
  ] as const) {
    const { response, calls } = await send(path, method, {
      ...NATIVE,
      cookie: `${SESSION_COOKIE}; CF_Authorization=edge-only`,
      "x-forma-member": "mem_native",
    });
    assert.equal(response.status, 200, `${method} ${path}`);
    assert.equal(calls.length, 1, `${method} ${path}`);
    const seen = calls[0].headers;
    assert.equal(seen.get("x-forma-client"), "ios");
    assert.equal(seen.get("cookie"), SESSION_COOKIE);
    assert.equal(seen.get("x-forma-member"), "mem_native");
    assert.equal(seen.has("origin"), false);
    assert.equal(seen.get("x-forma-worker-secret"), "test-worker-secret");
  }
});

test("NATIVE-03: an ordinary write without Origin is still refused, with or without a spoofed marker value", async () => {
  for (const headers of [
    {} as Record<string, string>,
    { cookie: SESSION_COOKIE },
    { "x-forma-client": "android", cookie: SESSION_COOKIE },
    { "x-forma-client": "IOS", cookie: SESSION_COOKIE },
    { "x-forma-client": "web", cookie: SESSION_COOKIE },
  ]) {
    const { response, calls } = await send("/api/workspace", "PUT", headers);
    assert.equal(response.status, 403, JSON.stringify(headers));
    assert.equal(calls.length, 0);
  }
});

test("NATIVE-04: the marker with any Origin behaves exactly as before", async () => {
  // Foreign Origin: refused for every method.
  for (const [method, path] of [
    ["GET", "/api/workspace"],
    ["PUT", "/api/workspace"],
    ["POST", "/api/auth/sign-out"],
  ] as const) {
    const { response, calls } = await send(path, method, {
      ...NATIVE,
      origin: "https://attacker.example",
      cookie: SESSION_COOKIE,
    });
    assert.equal(response.status, 403, `${method} ${path}`);
    assert.equal(calls.length, 0);
  }
  // The app's own Origin is an ordinary same-origin write; the marker is not
  // forwarded because the request is not native.
  const { response, calls } = await send("/api/workspace", "PUT", {
    ...NATIVE,
    origin: "https://forma.example",
    cookie: SESSION_COOKIE,
  });
  assert.equal(response.status, 200);
  assert.equal(calls[0].headers.get("origin"), "https://forma.example");
  assert.equal(calls[0].headers.has("x-forma-client"), false);
  // An empty Origin is still an Origin: not native, and not same-origin.
  const empty = await send("/api/workspace", "PUT", {
    ...NATIVE,
    origin: "",
    cookie: SESSION_COOKIE,
  });
  assert.equal(empty.response.status, 403);
  assert.equal(empty.calls.length, 0);
});

test("NATIVE-05: the marker with Referer or Sec-Fetch headers is a browser request", async () => {
  const cases: Record<string, string>[] = [
    { referer: "https://attacker.example/page" },
    { referer: "https://forma.example/" },
    { "sec-fetch-site": "cross-site" },
    { "sec-fetch-site": "same-site" },
    { "sec-fetch-site": "same-origin" },
    { "sec-fetch-site": "none" },
    { "sec-fetch-mode": "cors" },
    { "sec-fetch-dest": "empty" },
  ];
  for (const extra of cases) {
    const { response, calls } = await send("/api/workspace", "PUT", {
      ...NATIVE,
      cookie: SESSION_COOKIE,
      ...extra,
    });
    assert.equal(response.status, 403, JSON.stringify(extra));
    assert.equal(calls.length, 0);
  }
  // A cross-site fetch is still refused outright, for reads too.
  const crossSiteRead = await send("/api/workspace", "GET", {
    ...NATIVE,
    "sec-fetch-site": "cross-site",
    cookie: SESSION_COOKIE,
  });
  assert.equal(crossSiteRead.response.status, 403);
  assert.equal(crossSiteRead.calls.length, 0);
});

test("NATIVE-06: a read carrying the marker alongside browser headers does not reach the origin as native", async () => {
  const { response, calls } = await send("/api/workspace", "GET", {
    ...NATIVE,
    referer: "https://attacker.example/",
    cookie: SESSION_COOKIE,
  });
  assert.equal(response.status, 200);
  // The origin cannot see Referer, so the Worker withholds the marker.
  assert.equal(calls[0].headers.has("x-forma-client"), false);
  assert.equal(calls[0].headers.has("referer"), false);
  const plain = await send("/api/workspace", "GET", { cookie: SESSION_COOKIE });
  assert.equal(plain.calls[0].headers.has("x-forma-client"), false);
});

test("NATIVE-07: the native rule changes no other gateway rule", async () => {
  // Unknown and disallowed routes and methods stay closed.
  for (const [method, path, status] of [
    ["POST", "/api/admin/users", 404],
    ["POST", "/api/account/other", 404],
    ["POST", "/api/auth//sign-out", 404],
    ["DELETE", "/api/workspace", 405],
    ["POST", "/api/workspace/export", 405],
    ["POST", "/api/coach/workspace", 405],
  ] as const) {
    const { response, calls } = await send(path, method, NATIVE);
    assert.equal(response.status, status, `${method} ${path}`);
    assert.equal(calls.length, 0);
  }
  // Bodies keep their limits.
  const oversized = await send(
    "/api/auth/sign-in/email",
    "POST",
    { ...NATIVE, "content-length": String(64 * 1024 + 1) },
    "{}",
  );
  assert.equal(oversized.response.status, 413);
  assert.equal(oversized.calls.length, 0);
  // Only FORMA cookies are forwarded.
  const cookies = await send("/api/auth/sign-in/email", "POST", {
    ...NATIVE,
    cookie: "CF_Authorization=edge; theme=dark; forma.two_factor=challenge",
  });
  assert.equal(
    cookies.calls[0].headers.get("cookie"),
    "forma.two_factor=challenge",
  );
  // The edge client IP is still required outside development.
  const noEdgeIp = await handleApiRequest(
    new Request("https://forma.example/api/auth/sign-out", {
      method: "POST",
      headers: NATIVE,
      body: "{}",
    }),
    env,
    recorder().fetcher,
  );
  assert.equal(noEdgeIp.status, 503);
});

test("NATIVE-08: Authorization is still forwarded only on coach routes, and the marker does not widen them", async () => {
  const bearer = "Bearer coach-token_123";
  const nonCoach = await send("/api/workspace", "GET", {
    ...NATIVE,
    authorization: bearer,
    cookie: SESSION_COOKIE,
  });
  assert.equal(nonCoach.calls[0].headers.has("authorization"), false);
  assert.equal(nonCoach.calls[0].headers.get("x-forma-client"), "ios");

  const auth = await send("/api/auth/sign-out", "POST", {
    ...NATIVE,
    authorization: bearer,
  });
  assert.equal(auth.calls[0].headers.has("authorization"), false);

  const coach = await send("/api/coach/workspace", "GET", {
    ...NATIVE,
    authorization: bearer,
    cookie: SESSION_COOKIE,
    "x-forma-member": "mem_native",
  });
  assert.equal(coach.calls[0].headers.get("authorization"), bearer);
  assert.equal(coach.calls[0].headers.has("cookie"), false);
  assert.equal(coach.calls[0].headers.has("x-forma-member"), false);

  // The coach edit keeps its own exemption; the marker adds nothing to it.
  const edit = await send("/api/coach/workspace/data", "PATCH", {
    authorization: bearer,
  });
  assert.equal(edit.response.status, 200);
  const foreign = await send("/api/coach/workspace/data", "PATCH", {
    ...NATIVE,
    authorization: bearer,
    origin: "https://attacker.example",
  });
  assert.equal(foreign.response.status, 403);
});
