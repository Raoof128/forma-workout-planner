import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import worker, { handleApiRequest, type Env } from "../index.ts";

// Regression tests for the gateway hardening batch: anonymous body limits,
// cross-site navigation, upstream content types and 5xx bodies, cookie
// forwarding, API path matching, client disconnects and the Wrangler config.

const env: Env = {
  BACKEND_URL: "https://api.internal.example",
  APP_ORIGIN: "https://forma.example",
  ACCESS_CLIENT_ID: "test-access-id",
  ACCESS_CLIENT_SECRET: "test-access-secret",
  FORMA_WORKER_SECRET: "test-worker-secret",
  ASSETS: { fetch: async () => new Response("asset") },
};

const SESSION_COOKIE = "__Secure-forma.session_token=member";
const TOKEN = `forma_coach_${"a".repeat(43)}`;
const LARGE = 200 * 1024;

function request(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("cf-connecting-ip", "198.51.100.42");
  return new Request(`https://forma.example${path}`, { ...init, headers });
}

function largeRequest(
  path: string,
  method: "PUT" | "PATCH",
  headers: Record<string, string>,
) {
  return request(path, {
    method,
    headers: {
      "content-type": "application/json",
      "content-length": String(LARGE),
      ...headers,
    },
    body: "x".repeat(LARGE),
  });
}

const json = (body = "{}", init: ResponseInit = {}) =>
  new Response(body, {
    ...init,
    headers: { "content-type": "application/json", ...(init.headers ?? {}) },
  });

function counter(response: () => Response = () => json()) {
  const calls: { path: string; headers: Headers }[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({
      path: new URL(input.toString()).pathname,
      headers: new Headers(init?.headers),
    });
    return response();
  };
  return { calls, fetcher };
}

test("HARDEN-01: anonymous large bodies get the small limit before any origin fetch", async () => {
  const origin = { origin: "https://forma.example" };
  const anonymous = counter();
  const refused = [
    largeRequest("/api/workspace", "PUT", origin),
    largeRequest("/api/coach/workspace/data", "PATCH", {}),
    largeRequest("/api/coach/workspace/data", "PATCH", origin),
    // A bearer token is a credential only on the coach edit route.
    largeRequest("/api/workspace", "PUT", {
      ...origin,
      authorization: `Bearer ${TOKEN}`,
    }),
    // A cookie part without `name=value` is not a session credential.
    largeRequest("/api/workspace", "PUT", {
      ...origin,
      cookie: "forma.abc",
    }),
    // A coach edit with only a session cookie is not a coach credential.
    largeRequest("/api/coach/workspace/data", "PATCH", {
      cookie: SESSION_COOKIE,
    }),
  ];
  for (const req of refused) {
    const response = await handleApiRequest(req, env, anonymous.fetcher);
    assert.equal(response.status, 413, `${req.method} ${req.url}`);
    await response.text();
  }
  assert.equal(anonymous.calls.length, 0);

  const member = counter();
  const saved = await handleApiRequest(
    largeRequest("/api/workspace", "PUT", {
      ...origin,
      cookie: SESSION_COOKIE,
    }),
    env,
    member.fetcher,
  );
  assert.equal(saved.status, 200);
  await saved.text();
  const edit = await handleApiRequest(
    largeRequest("/api/coach/workspace/data", "PATCH", {
      authorization: `Bearer ${TOKEN}`,
    }),
    env,
    member.fetcher,
  );
  assert.equal(edit.status, 200);
  await edit.text();
  assert.equal(member.calls.length, 2);
});

test("HARDEN-02: a cross-site request is exempt only as a top-level navigation", async () => {
  const links = [
    "/api/auth/verify-email?token=abc",
    "/api/auth/reset-password/abc?callbackURL=%2F",
    "/api/auth/delete-user/callback?token=abc",
  ];
  const { calls, fetcher } = counter();
  for (const path of links) {
    const noCors = await handleApiRequest(
      request(path, {
        headers: {
          "sec-fetch-site": "cross-site",
          "sec-fetch-mode": "no-cors",
        },
      }),
      env,
      fetcher,
    );
    assert.equal(noCors.status, 403, `no-cors ${path}`);
    await noCors.text();

    const navigate = await handleApiRequest(
      request(path, {
        headers: {
          "sec-fetch-site": "cross-site",
          "sec-fetch-mode": "navigate",
        },
      }),
      env,
      fetcher,
    );
    assert.equal(navigate.status, 200, `navigate ${path}`);
    await navigate.text();
  }
  assert.equal(calls.length, links.length);

  // Navigation does not widen the rule: other paths and methods stay closed.
  const otherPath = await handleApiRequest(
    request("/api/workspace/export", {
      headers: { "sec-fetch-site": "cross-site", "sec-fetch-mode": "navigate" },
    }),
    env,
    fetcher,
  );
  assert.equal(otherPath.status, 403);
  await otherPath.text();
  const postLink = await handleApiRequest(
    request("/api/auth/verify-email?token=abc", {
      method: "POST",
      headers: {
        "sec-fetch-site": "cross-site",
        "sec-fetch-mode": "navigate",
        "content-type": "application/json",
      },
      body: "{}",
    }),
    env,
    fetcher,
  );
  assert.equal(postLink.status, 403);
  await postLink.text();
  assert.equal(calls.length, links.length);

  // Without Fetch metadata (a non-browser client) the check does not apply.
  const plain = await handleApiRequest(
    request("/api/workspace/export"),
    env,
    fetcher,
  );
  assert.equal(plain.status, 200);
  await plain.text();
  const plainLink = await handleApiRequest(
    request("/api/auth/verify-email?token=abc"),
    env,
    fetcher,
  );
  assert.equal(plainLink.status, 200);
  await plainLink.text();
});

test("HARDEN-03: an upstream body with no Content-Type is refused unless the status has no body", async () => {
  const streamBody = () =>
    new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new TextEncoder().encode("<html>untyped</html>"));
        controller.close();
      },
    });
  const untyped = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () => new Response(streamBody()),
  );
  assert.equal(untyped.status, 502);
  assert.equal(
    await untyped.text(),
    '{"error":"The API returned an invalid response type"}',
  );

  const untypedBytes = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () => new Response(new TextEncoder().encode("{}")),
  );
  assert.equal(untypedBytes.status, 502);
  await untypedBytes.text();

  for (const status of [204, 304]) {
    const bodiless = await handleApiRequest(
      request("/api/workspace"),
      env,
      async () => new Response(null, { status }),
    );
    assert.equal(bodiless.status, status);
  }
  const empty = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () => new Response(null, { status: 200 }),
  );
  assert.equal(empty.status, 200);
});

test("HARDEN-04: upstream 5xx bodies are replaced with the fixed error, and 4xx bodies pass through", async () => {
  const leaky = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () =>
      new Response('{"error":"relation member_workspace does not exist"}', {
        status: 500,
        statusText: "relation member_workspace",
        headers: {
          "content-type": "application/json",
          "x-origin-debug": "private",
          etag: '"private"',
        },
      }),
  );
  assert.equal(leaky.status, 500);
  const leakyBody = await leaky.text();
  assert.equal(leakyBody, '{"error":"upstream_error"}');
  assert.doesNotMatch(leakyBody, /relation member_workspace/);
  assert.doesNotMatch(leaky.statusText, /relation/);
  assert.equal(leaky.headers.get("x-origin-debug"), null);
  assert.equal(leaky.headers.get("etag"), null);
  assert.equal(leaky.headers.get("cache-control"), "no-store");
  assert.equal(
    leaky.headers.get("content-type"),
    "application/json; charset=utf-8",
  );

  const unavailable = await handleApiRequest(
    request("/api/workspace"),
    env,
    async () =>
      new Response("maintenance window", {
        status: 503,
        headers: { "content-type": "text/plain", "retry-after": "30" },
      }),
  );
  assert.equal(unavailable.status, 503);
  assert.equal(unavailable.headers.get("retry-after"), "30");
  assert.equal(await unavailable.text(), '{"error":"upstream_error"}');

  for (const [status, body] of [
    [429, '{"error":"rate_limited","retryAfter":30}'],
    [409, '{"error":"account_changed"}'],
  ] as const) {
    const response = await handleApiRequest(
      request("/api/workspace"),
      env,
      async () => json(body, { status }),
    );
    assert.equal(response.status, status);
    assert.equal(await response.text(), body);
  }
});

test("HARDEN-05: a request cookie part without '=' is never forwarded to the origin", async () => {
  const { calls, fetcher } = counter();
  const mixed = await handleApiRequest(
    request("/api/workspace", {
      headers: {
        cookie: "forma.abc; =orphan; forma.=x; __Secure-forma.session_token=s1",
      },
    }),
    env,
    fetcher,
  );
  await mixed.text();
  assert.equal(
    calls[0].headers.get("cookie"),
    "__Secure-forma.session_token=s1",
  );

  const bare = await handleApiRequest(
    request("/api/workspace", { headers: { cookie: "forma.abc" } }),
    env,
    fetcher,
  );
  await bare.text();
  assert.equal(calls[1].headers.has("cookie"), false);
});

test("HARDEN-06: only /api and paths under it reach the API gateway; /apple is the SPA", async () => {
  const workerEnv: Env = {
    ...env,
    ASSETS: {
      fetch: async (req: Request) =>
        new Response(`app ${new URL(req.url).pathname}`),
    },
  };
  for (const path of ["/apple", "/apiary", "/api-docs"]) {
    const response = await worker.fetch(request(path), workerEnv);
    assert.equal(response.status, 200, path);
    assert.equal(await response.text(), `app ${path}`);
  }

  const { calls, fetcher } = counter();
  const direct = await handleApiRequest(request("/apple"), env, fetcher);
  assert.equal(direct.status, 404);
  await direct.text();
  assert.equal(calls.length, 0);

  // The API prefix itself still goes to the gateway, never to the assets.
  let assets = 0;
  const apiEnv: Env = {
    ...env,
    ASSETS: {
      fetch: async () => {
        assets += 1;
        return new Response("app shell");
      },
    },
  };
  const api = await worker.fetch(request("/api/"), apiEnv);
  assert.equal(api.status, 404);
  await api.text();
  assert.equal(assets, 0);
});

test("HARDEN-07: a client that disconnects aborts the upstream request", async () => {
  // A request whose signal is already aborted must abort the upstream fetch.
  const preAborted = new AbortController();
  preAborted.abort();
  let seenAborted: boolean | undefined;
  const early = await handleApiRequest(
    request("/api/workspace", { signal: preAborted.signal }),
    env,
    async (_input, init) => {
      seenAborted = init?.signal?.aborted;
      throw init?.signal?.reason ?? new Error("aborted");
    },
  );
  assert.equal(seenAborted, true);
  assert.equal(early.headers.get("cache-control"), "no-store");
  await early.text();

  // A client that disconnects while the upstream is in flight aborts it too.
  const controller = new AbortController();
  let started!: () => void;
  const fetchStarted = new Promise<void>((resolve) => {
    started = resolve;
  });
  let midFlightAborted = false;
  const pending = handleApiRequest(
    request("/api/workspace", { signal: controller.signal }),
    env,
    async (_input, init) => {
      const signal = init?.signal;
      started();
      return new Promise<Response>((_resolve, reject) => {
        signal?.addEventListener("abort", () => {
          midFlightAborted = signal.aborted;
          reject(signal.reason);
        });
      });
    },
  );
  await fetchStarted;
  controller.abort();
  const response = await pending;
  assert.equal(midFlightAborted, true);
  assert.equal(response.headers.get("cache-control"), "no-store");
  await response.text();
});

// Wrangler config is JSONC: drop whole-line comments and trailing commas.
type WranglerConfig = {
  name?: string;
  workers_dev?: boolean;
  preview_urls?: boolean;
  env?: Record<string, unknown>;
};
function readWranglerConfig(): WranglerConfig {
  const text = readFileSync(
    new URL("../../wrangler.jsonc", import.meta.url),
    "utf8",
  );
  const json = text
    .split("\n")
    .filter((line) => !line.trim().startsWith("//"))
    .join("\n")
    .replace(/,(\s*[}\]])/g, "$1");
  return JSON.parse(json) as WranglerConfig;
}

test("HARDEN-08: the top-level Wrangler config disables workers.dev and preview URLs, and env blocks are unchanged", () => {
  const config = readWranglerConfig();
  assert.equal(config.workers_dev, false);
  assert.equal(config.preview_urls, false);
  assert.equal(config.name, "forma-workout-planner");
  assert.deepEqual(config.env, {
    staging: {
      name: "forma-workout-planner-staging",
      workers_dev: false,
      preview_urls: false,
      routes: [
        { pattern: "forma-staging.raoufabedini.dev", custom_domain: true },
      ],
      vars: {
        ENVIRONMENT: "staging",
        APP_ORIGIN: "https://forma-staging.raoufabedini.dev",
        BACKEND_URL: "https://forma-api-staging.raoufabedini.dev",
      },
    },
    production: {
      name: "forma-workout-planner-production",
      workers_dev: false,
      preview_urls: false,
      routes: [{ pattern: "forma.raoufabedini.dev", custom_domain: true }],
      vars: {
        ENVIRONMENT: "production",
        APP_ORIGIN: "https://forma.raoufabedini.dev",
        BACKEND_URL: "https://forma-api.raoufabedini.dev",
      },
    },
  });
});
