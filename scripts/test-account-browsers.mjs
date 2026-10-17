import { spawn } from "node:child_process";
import { fileURLToPath, URL } from "node:url";
import { join, resolve } from "node:path";
import process from "node:process";
import { log } from "node:console";
import config from "../playwright.accounts.config.js";

// Better Auth's in-memory rate bucket belongs to one test server. Give each
// independent browser profile its own server/schema instead of pooling every
// synthetic member behind one edge IP for the entire matrix. Limits stay intact.
const root = fileURLToPath(new URL("../", import.meta.url));
const args = process.argv.slice(2);
const forwarded = [];
const selected = [];
let output = config.outputDir;
for (let index = 0; index < args.length; index++) {
  const arg = args[index];
  if (arg === "--project") selected.push(args[++index]);
  else if (arg.startsWith("--project=")) selected.push(arg.slice(10));
  else if (arg === "--output") output = args[++index];
  else if (arg.startsWith("--output=")) output = arg.slice(9);
  else forwarded.push(arg);
}
if (selected.some((name) => !name) || !output)
  throw new Error("--project and --output require values");
// Only '*' is special; compare literal segments without a dynamic regular
// expression or backtracking, including for very long CLI filters.
const matches = (name, pattern) => {
  const parts = pattern.split("*");
  if (parts.length === 1) return name === pattern;
  if (!name.startsWith(parts[0])) return false;
  let offset = parts[0].length;
  for (const part of parts.slice(1, -1)) {
    const found = name.indexOf(part, offset);
    if (found < 0) return false;
    offset = found + part.length;
  }
  const last = parts.at(-1);
  return name.length - offset >= last.length && name.endsWith(last);
};
const allNames = config.projects.map((project) => project.name);
if (
  selected.some((pattern) => !allNames.some((name) => matches(name, pattern)))
)
  throw new Error("An account browser project filter matched no projects");
const projects = allNames.filter(
  (name) =>
    !selected.length || selected.some((pattern) => matches(name, pattern)),
);
if (!projects.length) throw new Error("No account browser projects matched");
const cli = join(root, "node_modules/@playwright/test/cli.js");
const discovery =
  forwarded.includes("--list") ||
  forwarded.includes("--help") ||
  forwarded.includes("-h");
const groups = discovery ? [projects] : projects.map((name) => [name]);
let child;
let stopping = false;
const stop = () => {
  stopping = true;
  child?.kill("SIGINT");
};
process.once("SIGINT", stop);
process.once("SIGTERM", stop);
const failed = [];
let completed = 0;
for (const names of groups) {
  if (stopping) break;
  if (!discovery) log(`\nAccount browser with an isolated server: ${names[0]}`);
  const code = await new Promise((accept, reject) => {
    child = spawn(
      process.execPath,
      [
        cli,
        "test",
        "--config=playwright.accounts.config.js",
        ...forwarded,
        ...names.map((name) => `--project=${name}`),
        `--output=${resolve(root, output, names[0])}`,
      ],
      { cwd: root, stdio: "inherit" },
    );
    child.once("error", reject);
    child.once("exit", (status) => accept(status ?? 1));
  });
  completed++;
  if (code !== 0) failed.push(...names);
}
if (!discovery)
  log(
    `Account browser projects completed: ${completed}; failed: ${failed.length}`,
  );
process.exitCode = stopping ? 130 : failed.length ? 1 : 0;
