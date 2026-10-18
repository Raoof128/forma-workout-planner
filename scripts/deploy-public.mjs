import { spawn } from "node:child_process";
import { log } from "node:console";
import { readFile } from "node:fs/promises";
import { URL } from "node:url";
import process from "node:process";

// The existing infrastructure token creates a one-hour scoped deploy token.
// Its value lives only in child-process memory; revoke it on every exit path.
const base = "https://api.cloudflare.com/client/v4";
if (
  process.argv
    .slice(2)
    .some((arg) => !["--staging", "--inspect", "--dashboard"].includes(arg))
)
  throw new Error(
    "Supported deployment flags: --staging, --inspect, --dashboard",
  );
// --dashboard deploys the private operations dashboard Worker instead.
const dashboard = process.argv.includes("--dashboard");
if (dashboard && process.argv.includes("--staging"))
  throw new Error("The operations dashboard has no staging environment");
const management = process.env.CLOUDFLARE_API_TOKEN;
const environment = process.argv.includes("--staging")
  ? "staging"
  : "production";
if (!management) throw new Error("CLOUDFLARE_API_TOKEN is required");
async function api(path, token = management, options = {}) {
  const response = await globalThis.fetch(base + path, {
    ...options,
    cache: "no-store",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    signal: globalThis.AbortSignal.timeout(30000),
  });
  const data = await response.json();
  if (!response.ok || data.success !== true)
    throw new Error(
      `Cloudflare ${path.split("?")[0]} failed: HTTP ${response.status}; ${(data.errors ?? []).map((error) => `${error.code}: ${String(error.message).replaceAll(token, "[REDACTED]").replaceAll(management, "[REDACTED]")}`).join("; ")}`,
    );
  return data.result;
}
const zone = (await api("/zones?name=raoufabedini.dev"))[0];
if (!zone || zone.name !== "raoufabedini.dev")
  throw new Error("Launch zone unavailable");
const groups = await api("/user/tokens/permission_groups");
const permission = (name) => {
  const group = groups.find((group) => group.name === name);
  if (!group) throw new Error(`Missing permission group: ${name}`);
  return { id: group.id };
};
const expires = new Date(Date.now() + 3600000)
  .toISOString()
  .replace(/\.\d{3}Z$/, "Z");
const token = await api("/user/tokens", management, {
  method: "POST",
  body: JSON.stringify({
    name: "forma-public-catalog-deploy-1h",
    expires_on: expires,
    policies: [
      {
        effect: "allow",
        permission_groups: [
          permission("Workers Scripts Write"),
          permission("Account Settings Read"),
        ],
        resources: { [`com.cloudflare.api.account.${zone.account.id}`]: "*" },
      },
      {
        effect: "allow",
        permission_groups: [
          permission("Workers Routes Write"),
          permission("Zone Read"),
        ],
        resources: { [`com.cloudflare.api.account.zone.${zone.id}`]: "*" },
      },
    ],
  }),
});
try {
  // New token permissions can need a short activation interval. Retry only
  // the read probe, never a deployment or message-producing operation.
  let scripts;
  for (let attempt = 0; attempt < 12; attempt++) {
    try {
      scripts = await api(
        `/accounts/${zone.account.id}/workers/scripts`,
        token.value,
      );
      break;
    } catch (error) {
      if (attempt === 11) throw error;
      await new Promise((resolve) => globalThis.setTimeout(resolve, 5000));
    }
  }
  log(
    JSON.stringify({
      account: zone.account.id,
      existingFormaWorkers: scripts
        .filter((script) => script.id?.includes("forma"))
        .map((script) => script.id),
      tokenExpires: expires,
    }),
  );
  if (process.argv.includes("--inspect")) {
    const domains = await api(
      `/accounts/${zone.account.id}/workers/domains`,
      token.value,
    );
    log(
      JSON.stringify({
        domains: domains
          .filter((domain) => domain.hostname?.includes("forma"))
          .map((domain) => ({
            hostname: domain.hostname,
            service: domain.service,
          })),
      }),
    );
  } else {
    const config = dashboard
      ? "../ops/wrangler.dashboard.jsonc"
      : "../wrangler.jsonc";
    const manifest = await readFile(new URL(config, import.meta.url), "utf8");
    if (
      !manifest.includes(
        dashboard ? "forma-ops.raoufabedini.dev" : "forma.raoufabedini.dev",
      ) ||
      manifest.includes("forma-api.invalid")
    )
      throw new Error("Launch configuration is incomplete");
    const args = dashboard
      ? ["wrangler", "deploy", "--config", "ops/wrangler.dashboard.jsonc"]
      : ["wrangler", "deploy", "--env", environment];
    const exitCode = await new Promise((resolve, reject) => {
      const child = spawn("npx", args, {
        stdio: "inherit",
        env: {
          ...process.env,
          CLOUDFLARE_API_TOKEN: token.value,
          CLOUDFLARE_ACCOUNT_ID: zone.account.id,
          WRANGLER_SEND_METRICS: "false",
        },
      });
      child.once("error", reject);
      child.once("exit", resolve);
    });
    if (exitCode !== 0) throw new Error(`Worker deployment exited ${exitCode}`);
  }
} finally {
  await api(`/user/tokens/${token.id}`, management, { method: "DELETE" });
  log("One-hour deployment token revoked.");
}
