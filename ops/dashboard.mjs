import { dashboardHtml } from "./dashboard-page.mjs";

const allowedSignals = new Set([
  "public_account_gateway_unhealthy",
  "public_account_gateway_unreachable",
  "off_host_backup_missing",
  "off_host_backup_overdue",
  "off_host_backup_unavailable",
]);
const validTime = (value) =>
  typeof value === "string" && Number.isFinite(Date.parse(value));
export function safeStatus(value) {
  const source = value && typeof value === "object" ? value : {};
  const signals = (Array.isArray(source.signals) ? source.signals : []).filter(
    (x) => allowedSignals.has(x),
  );
  const journal = (Array.isArray(source.journal) ? source.journal : [])
    .slice(0, 40)
    .filter((row) => validTime(row?.at))
    .map((row) => ({
      at: row.at,
      event: row.event === "healthy" ? "healthy" : "attention",
      alertSent: row.alertSent === true,
      signals: (Array.isArray(row.signals) ? row.signals : []).filter((x) =>
        allowedSignals.has(x),
      ),
    }));
  return {
    checkedAt: validTime(source.checkedAt) ? source.checkedAt : null,
    signals,
    failures: Number.isInteger(source.failures)
      ? Math.max(0, Math.min(source.failures, 10000))
      : 0,
    journal,
    alertedAt: Number.isFinite(source.alertedAt) ? source.alertedAt : null,
  };
}

function bytes(value) {
  return Uint8Array.from(
    globalThis.atob(value.replaceAll("-", "+").replaceAll("_", "/")),
    (x) => x.charCodeAt(0),
  );
}
export async function verifyAccess(token, env, request = globalThis.fetch) {
  try {
    if (
      typeof token !== "string" ||
      token.length > 16384 ||
      !/^https:\/\/[a-z0-9-]+\.cloudflareaccess\.com$/.test(env.ACCESS_ISSUER)
    )
      return false;
    const parts = token.split(".");
    if (
      parts.length !== 3 ||
      parts.some((x) => !x || !/^[A-Za-z0-9_-]+$/.test(x))
    )
      return false;
    const decode = (part) =>
      JSON.parse(new globalThis.TextDecoder().decode(bytes(part)));
    const header = decode(parts[0]),
      claims = decode(parts[1]);
    if (
      header.alg !== "RS256" ||
      typeof header.kid !== "string" ||
      header.kid.length > 128
    )
      return false;
    const audiences = Array.isArray(claims.aud)
      ? claims.aud
      : typeof claims.aud === "string"
        ? [claims.aud]
        : [];
    if (
      claims.iss !== env.ACCESS_ISSUER ||
      !audiences.includes(env.ACCESS_AUDIENCE) ||
      !Number.isFinite(claims.exp) ||
      claims.exp <= Date.now() / 1000 ||
      (Number.isFinite(claims.nbf) && claims.nbf > Date.now() / 1000 + 30)
    )
      return false;
    // Access grants only this owner or an explicitly provisioned maintenance
    // service policy. Ordinary FORMA account cookies grant no dashboard access.
    if (
      typeof claims.email === "string" &&
      claims.email.toLowerCase() !== env.OWNER_EMAIL.toLowerCase()
    )
      return false;
    if (
      typeof claims.email !== "string" &&
      typeof claims.common_name !== "string"
    )
      return false;
    const response = await request(
      env.ACCESS_ISSUER + "/cdn-cgi/access/certs",
      // Workers supports manual/follow redirect modes. Refuse redirects by
      // inspecting the unfollowed response instead of unsupported error mode.
      { redirect: "manual", signal: globalThis.AbortSignal.timeout(10000) },
    );
    if (!response.ok) return false;
    const data = await response.json();
    const jwk = data.keys?.find(
      (key) => key.kid === header.kid && key.kty === "RSA",
    );
    if (!jwk) return false;
    const key = await globalThis.crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    return await globalThis.crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      bytes(parts[2]),
      new globalThis.TextEncoder().encode(parts[0] + "." + parts[1]),
    );
  } catch {
    return false;
  }
}

const headers = {
  "Cache-Control": "private, no-store",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
};
function reply(body, status = 200, type = "text/plain;charset=utf-8") {
  return new globalThis.Response(body, {
    status,
    headers: { ...headers, "Content-Type": type },
  });
}
export default {
  async fetch(request, env) {
    const url = new globalThis.URL(request.url);
    if (url.hostname !== env.HOSTNAME) return reply("Not found", 404);
    if (request.method !== "GET" && request.method !== "HEAD")
      return reply("Method not allowed", 405);
    if (
      !(await verifyAccess(request.headers.get("Cf-Access-Jwt-Assertion"), env))
    )
      return reply("Owner access required", 401);
    if (url.pathname === "/api/status") {
      try {
        return reply(
          JSON.stringify(safeStatus(await env.STATE.get("edge-state", "json"))),
          200,
          "application/json",
        );
      } catch {
        return reply(
          JSON.stringify({ error: "monitor_unavailable" }),
          503,
          "application/json",
        );
      }
    }
    if (url.pathname === "/" || url.pathname === "/index.html") {
      const response = reply(dashboardHtml, 200, "text/html;charset=utf-8");
      response.headers.set(
        "Content-Security-Policy",
        "default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self'; font-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
      );
      return response;
    }
    if (
      [
        "/dashboard.js",
        "/favicon.svg",
        "/fonts/dm-sans-variable.woff2",
        "/fonts/barlow-condensed-700.woff2",
      ].includes(url.pathname) &&
      env.ASSETS
    ) {
      const response = await env.ASSETS.fetch(request);
      const secured = new globalThis.Response(response.body, response);
      for (const [name, value] of Object.entries(headers))
        secured.headers.set(name, value);
      return secured;
    }
    return reply("Not found", 404);
  },
};
