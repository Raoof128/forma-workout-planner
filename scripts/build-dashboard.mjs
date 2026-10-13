import fs from "node:fs/promises";
import { fileURLToPath } from "node:url";
const root = fileURLToPath(new globalThis.URL("../", import.meta.url));
const out = root + ".forma-dashboard-assets";
await fs.mkdir(out + "/fonts", { recursive: true });
await fs.copyFile(root + "ops/dashboard-client.js", out + "/dashboard.js");
for (const name of ["dm-sans-variable.woff2", "barlow-condensed-700.woff2"])
  await fs.copyFile(root + "public/fonts/" + name, out + "/fonts/" + name);
await fs.copyFile(root + "public/favicon.svg", out + "/favicon.svg");
globalThis.console.log("Private dashboard assets built.");
