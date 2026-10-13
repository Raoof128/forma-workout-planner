export interface Env {
  BACKEND_URL?: string;
  APP_ORIGIN: string;
  ACCESS_CLIENT_ID: string;
  ACCESS_CLIENT_SECRET: string;
  FORMA_WORKER_SECRET: string;
  ASSETS: { fetch(request: Request): Promise<Response> };
  ENVIRONMENT?: "development" | "staging" | "production";
}

// Workspace data caps at 20 MiB; match the backend's additional JSON framing allowance.
const MAX_BODY_BYTES = 20 * 1024 * 1024 + 16 * 1024;
// Every other API body is small JSON. Large uploads are accepted only where a
// workspace document is expected, so anonymous callers cannot make the origin
// buffer and parse 20 MiB on auth routes.
const MAX_SMALL_BODY_BYTES = 64 * 1024;
// Forward an explicit allowlist rather than stripping known-bad names; any
// header not listed here never reaches the origin.
const FORWARDED_REQUEST_HEADERS = new Set([
  "accept",
  "accept-language",
  "content-type",
  "cookie",
  "origin",
  "user-agent",
  "x-forma-member",
  "x-request-id",
  "sec-fetch-site",
  "sec-fetch-mode",
  "sec-fetch-dest",
]);
const FORWARDED_RESPONSE_HEADERS = new Set([
  "content-type",
  "content-language",
  "content-disposition",
  "etag",
  "last-modified",
  "retry-after",
  "vary",
]);
const API_CONTENT_TYPES = ["application/json", "text/plain"];
// Only FORMA's own Better Auth cookies may be set through the gateway. This
// also keeps any Cloudflare Access cookie on the Worker-to-origin hop private.
const APP_COOKIE = /^(?:__Secure-|__Host-)?forma\.[A-Za-z0-9_.-]+$/;
// Token-bearing email links are the only legitimate cross-site API requests.
const CROSS_SITE_NAVIGATIONS = new Set([
  "/api/auth/verify-email",
  "/api/auth/delete-user/callback",
]);
const REQUEST_TIMEOUT_MS = 30_000;
const METHODS = new Set([
  "GET",
  "HEAD",
  "POST",
  "PUT",
  "PATCH",
  "DELETE",
  "OPTIONS",
]);
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);
const HOP_HEADERS = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
  "host",
  "forwarded",
  "x-real-ip",
  "x-client-ip",
  "x-forwarded-for",
  "x-forwarded-host",
  "x-forwarded-proto",
  "x-forwarded-port",
  "x-forwarded-server",
  "x-original-url",
  "x-rewrite-url",
  "x-envoy-original-path",
  "x-auth-request-email",
  "x-auth-request-user",
  "x-auth-request-access-token",
  "cf-connecting-ip",
  "x-forma-client-ip",
  "true-client-ip",
  "cf-access-client-id",
  "cf-access-client-secret",
  "x-forma-worker-secret",
  "x-forma-user-id",
  "x-authenticated-user",
  "x-authenticated-user-email",
  "x-user-id",
]);

type Fetcher = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

function jsonError(status: number, error: string): Response {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
  });
  // Browsers ignore HSTS on plain-HTTP development responses.
  applyApiSecurityHeaders(headers, true);
  return new Response(JSON.stringify({ error }), { status, headers });
}

function configuredOrigin(
  value: string,
  name: string,
  allowLocalHttp: boolean,
): URL {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new TypeError(`${name} must be an absolute URL`);
  }
  const localHttp =
    allowLocalHttp &&
    url.protocol === "http:" &&
    ["localhost", "127.0.0.1"].includes(url.hostname);
  if (
    (!localHttp && url.protocol !== "https:") ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    throw new TypeError(
      `${name} must be an HTTPS origin without credentials, path, query, or fragment`,
    );
  }
  return url;
}

function allowedMethods(pathname: string): Set<string> | null {
  if (pathname === "/api/health") return new Set(["GET", "HEAD"]);
  if (pathname === "/api/workspace") return new Set(["GET", "PUT"]);
  if (pathname === "/api/workspace/export") return new Set(["GET"]);
  if (pathname === "/api/account/sessions") return new Set(["GET"]);
  if (
    pathname === "/api/account/sessions/revoke-others" ||
    pathname === "/api/account/sessions/revoke-all"
  )
    return new Set(["POST"]);
  if (/^\/api\/account\/sessions\/[A-Za-z0-9_-]{43}\/revoke$/.test(pathname))
    return new Set(["DELETE"]);
  if (pathname === "/api/auth" || pathname.startsWith("/api/auth/")) {
    // Reject ambiguous encoded separators, dot segments and path syntax the origin might decode differently.
    return !pathname.includes("//") &&
      !/[%\\]/.test(pathname) &&
      pathname.split("/").every((part) => part !== "." && part !== "..")
      ? METHODS
      : null;
  }
  return null;
}

function filteredRequestHeaders(request: Request, env: Env): Headers {
  // Cloudflare overwrites CF-Connecting-IP at the app edge. It can be rewritten
  // again when the Worker calls a private Tunnel, so copy the trusted inbound
  // value to our own header before stripping caller-supplied metadata.
  const trustedClientIp = request.headers.get("cf-connecting-ip");
  const headers = new Headers();
  for (const [name, value] of request.headers) {
    const lower = name.toLowerCase();
    if (!FORWARDED_REQUEST_HEADERS.has(lower) || HOP_HEADERS.has(lower))
      continue;
    if (lower === "cookie") {
      // Forward only FORMA's own cookies. Cloudflare Access (CF_Authorization)
      // and any other site cookies stay at the edge.
      const appCookies = value
        .split(";")
        .map((part) => part.trim())
        .filter((part) => APP_COOKIE.test(part.slice(0, part.indexOf("="))));
      if (appCookies.length) headers.append("cookie", appCookies.join("; "));
      continue;
    }
    headers.append(name, value);
  }
  headers.set("cf-access-client-id", env.ACCESS_CLIENT_ID);
  headers.set("cf-access-client-secret", env.ACCESS_CLIENT_SECRET);
  headers.set("x-forma-worker-secret", env.FORMA_WORKER_SECRET);
  if (trustedClientIp) headers.set("x-forma-client-ip", trustedClientIp);
  return headers;
}

function limitedStream(
  source: ReadableStream<Uint8Array>,
  onDone: () => void,
  onLimit: () => void = () => undefined,
  limit = MAX_BODY_BYTES,
): ReadableStream<Uint8Array> {
  const reader = source.getReader();
  let total = 0;
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      try {
        const { done, value } = await reader.read();
        if (done) {
          onDone();
          controller.close();
          return;
        }
        total += value.byteLength;
        if (total > limit) {
          onLimit();
          await reader.cancel("body exceeded gateway limit");
          onDone();
          controller.error(new RangeError("gateway body limit exceeded"));
          return;
        }
        controller.enqueue(value);
      } catch (error) {
        onDone();
        controller.error(error);
      }
    },
    async cancel(reason) {
      onDone();
      await reader.cancel(reason);
    },
  });
}

function validateLocation(
  location: string,
  backend: URL,
  appOrigin: URL,
): string | null {
  try {
    const resolved = new URL(location, backend);
    if (resolved.username || resolved.password) return null;
    if (resolved.origin === appOrigin.origin) return resolved.href;
    if (resolved.origin === backend.origin) {
      return new URL(
        `${resolved.pathname}${resolved.search}${resolved.hash}`,
        appOrigin,
      ).href;
    }
  } catch {
    // Invalid Location is rejected without returning the upstream body or credentials.
  }
  return null;
}

/**
 * Keep only FORMA's cookies and drop any Domain attribute, so an origin
 * mistake cannot widen a session cookie to sibling hosts.
 */
export function sanitiseSetCookie(cookie: string): string | null {
  const [pair, ...attributes] = cookie.split(";");
  const name = pair.slice(0, pair.indexOf("=")).trim();
  if (pair.indexOf("=") < 1 || !APP_COOKIE.test(name)) return null;
  const kept = attributes.filter(
    (attribute) => !/^\s*domain\s*=/i.test(attribute),
  );
  return [pair, ...kept].join(";");
}

function applyApiSecurityHeaders(headers: Headers, secure: boolean): void {
  headers.set("cache-control", "no-store");
  headers.set("x-content-type-options", "nosniff");
  headers.set(
    "content-security-policy",
    "default-src 'none'; frame-ancestors 'none'; sandbox",
  );
  headers.set("x-frame-options", "DENY");
  headers.set("referrer-policy", "no-referrer");
  headers.set("cross-origin-resource-policy", "same-origin");
  if (secure)
    headers.set(
      "strict-transport-security",
      "max-age=31536000; includeSubDomains",
    );
}

function createHandler(fetcher: Fetcher) {
  return async function handle(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/api")) return jsonError(404, "Not found");
    if (!METHODS.has(request.method))
      return jsonError(405, "Method not allowed");

    let backend: URL;
    let appOrigin: URL;
    try {
      backend = configuredOrigin(
        env.BACKEND_URL ?? "",
        "BACKEND_URL",
        env.ENVIRONMENT === "development",
      );
      appOrigin = configuredOrigin(
        env.APP_ORIGIN,
        "APP_ORIGIN",
        env.ENVIRONMENT === "development",
      );
    } catch {
      return jsonError(503, "API gateway is not configured");
    }
    if (
      !env.ACCESS_CLIENT_ID ||
      !env.ACCESS_CLIENT_SECRET ||
      !env.FORMA_WORKER_SECRET
    ) {
      return jsonError(503, "API gateway is not configured");
    }
    const routeMethods = allowedMethods(url.pathname);
    if (!routeMethods) return jsonError(404, "API route not found");
    if (!routeMethods.has(request.method))
      return jsonError(405, "Method not allowed");

    if (
      env.ENVIRONMENT !== "development" &&
      !request.headers.get("cf-connecting-ip")
    ) {
      // Without the edge-supplied client IP every caller would share one
      // auth rate-limit bucket at the origin.
      return jsonError(503, "API gateway is not configured");
    }

    const fetchSite = request.headers.get("sec-fetch-site");
    if (
      fetchSite === "cross-site" &&
      !(
        request.method === "GET" &&
        (CROSS_SITE_NAVIGATIONS.has(url.pathname) ||
          url.pathname.startsWith("/api/auth/reset-password/"))
      )
    ) {
      return jsonError(403, "Cross-site API requests are not allowed");
    }

    const origin = request.headers.get("origin");
    if (origin && origin !== appOrigin.origin)
      return jsonError(403, "Origin is not allowed");
    if (
      ["POST", "PUT", "PATCH", "DELETE"].includes(request.method) &&
      origin !== appOrigin.origin
    ) {
      return jsonError(403, "A same-origin request is required");
    }

    const bodyLimit =
      request.method === "PUT" && url.pathname === "/api/workspace"
        ? MAX_BODY_BYTES
        : MAX_SMALL_BODY_BYTES;
    const declaredLength = request.headers.get("content-length");
    if (
      declaredLength !== null &&
      (!/^\d+$/.test(declaredLength) || Number(declaredLength) > bodyLimit)
    ) {
      return jsonError(413, "Request body is too large");
    }

    const upstreamPath =
      url.pathname === "/api/health" ? "/healthz" : url.pathname;
    const upstreamUrl = new URL(`${upstreamPath}${url.search}`, backend);
    const abort = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    let requestBodyExceeded = false;
    const finish = () => {
      if (timer !== undefined) clearTimeout(timer);
    };
    timer = setTimeout(
      () => abort.abort("gateway timeout"),
      REQUEST_TIMEOUT_MS,
    );

    try {
      const headers = filteredRequestHeaders(request, env);
      let body: ReadableStream<Uint8Array> | undefined;
      if (
        request.method !== "GET" &&
        request.method !== "HEAD" &&
        request.body
      ) {
        body = limitedStream(
          request.body,
          () => undefined,
          () => {
            requestBodyExceeded = true;
          },
          bodyLimit,
        );
      }
      const init: RequestInit & { duplex?: "half" } = {
        method: request.method,
        headers,
        body,
        redirect: "manual",
        signal: abort.signal,
        ...(body ? { duplex: "half" } : {}),
      };
      const upstream = await fetcher(upstreamUrl, init);
      if (REDIRECT_STATUSES.has(upstream.status)) {
        const location = upstream.headers.get("location");
        if (!location) {
          await upstream.body?.cancel("redirect omitted Location");
          finish();
          return jsonError(502, "The API returned an invalid redirect");
        }
        const safeLocation = validateLocation(location, backend, appOrigin);
        if (!safeLocation) {
          await upstream.body?.cancel("unsafe redirect target");
          finish();
          return jsonError(502, "The API returned an unsafe redirect");
        }
        const redirectHeaders = new Headers({ location: safeLocation });
        applyApiSecurityHeaders(
          redirectHeaders,
          appOrigin.protocol === "https:",
        );
        for (const cookie of upstream.headers.getSetCookie?.() ?? []) {
          const safeCookie = sanitiseSetCookie(cookie);
          if (safeCookie) redirectHeaders.append("set-cookie", safeCookie);
        }
        await upstream.body?.cancel("redirect handled by application");
        finish();
        return new Response(null, {
          status: upstream.status,
          headers: redirectHeaders,
        });
      }

      // Only JSON or plain text is an API response. HTML (an Access login
      // page), SVG, XML and anything else is refused rather than rendered.
      const upstreamType = upstream.headers
        .get("content-type")
        ?.toLowerCase()
        .split(";", 1)[0]
        .trim();
      if (
        (upstreamType && !API_CONTENT_TYPES.includes(upstreamType)) ||
        upstream.status < 200 ||
        upstream.status > 599
      ) {
        await upstream.body?.cancel("unexpected API response type");
        finish();
        return jsonError(502, "The API returned an invalid response type");
      }

      const responseHeaders = new Headers();
      for (const [name, value] of upstream.headers) {
        if (FORWARDED_RESPONSE_HEADERS.has(name.toLowerCase()))
          responseHeaders.append(name, value);
      }
      for (const cookie of upstream.headers.getSetCookie?.() ?? []) {
        const safeCookie = sanitiseSetCookie(cookie);
        if (safeCookie) responseHeaders.append("set-cookie", safeCookie);
      }
      applyApiSecurityHeaders(responseHeaders, appOrigin.protocol === "https:");
      const responseLength = upstream.headers.get("content-length");
      if (responseLength !== null && Number(responseLength) > MAX_BODY_BYTES) {
        await upstream.body?.cancel("response exceeded gateway limit");
        finish();
        return jsonError(502, "The API response is too large");
      }
      const responseBody = upstream.body
        ? limitedStream(upstream.body, finish)
        : null;
      if (!responseBody) finish();
      return new Response(responseBody, {
        status: upstream.status,
        statusText: upstream.statusText,
        headers: responseHeaders,
      });
    } catch (error) {
      finish();
      if (requestBodyExceeded)
        return jsonError(413, "Request body is too large");
      if (error instanceof RangeError)
        return jsonError(413, "Request body is too large");
      if (abort.signal.aborted)
        return jsonError(504, "The API request timed out");
      return jsonError(502, "The API is temporarily unavailable");
    }
  };
}

export function handleApiRequest(
  request: Request,
  env: Env,
  fetcher: Fetcher = (input, init) => fetch(input, init),
): Promise<Response> {
  return createHandler(fetcher)(request, env);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const pathname = new URL(request.url).pathname;
    if (pathname.startsWith("/api")) return handleApiRequest(request, env);
    const response = await env.ASSETS.fetch(request);
    const headers = new Headers(response.headers);
    headers.set("x-content-type-options", "nosniff");
    headers.set("referrer-policy", "strict-origin-when-cross-origin");
    headers.set(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=()",
    );
    headers.set("x-frame-options", "DENY");
    headers.set(
      "content-security-policy",
      "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob:; font-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; upgrade-insecure-requests",
    );
    if (new URL(request.url).protocol === "https:")
      headers.set(
        "strict-transport-security",
        "max-age=31536000; includeSubDomains",
      );
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
};
