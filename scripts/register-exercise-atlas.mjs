import assert from "node:assert/strict";
import { log } from "node:console";
import process from "node:process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { selectableExercises } from "../src/data.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const batchFile = process.argv[2];
assert(batchFile, "Supply a reviewed original-art batch JSON file.");
const batch = JSON.parse(
  fs.readFileSync(path.resolve(root, batchFile), "utf8"),
);
assert(/^[a-z0-9-]+$/.test(batch.name));
assert.equal(batch.publicPath, `/exercise-media/original/${batch.name}.png`);
const bytes = fs.readFileSync(batch.sourceGeneratedPath);
assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
const width = bytes.readUInt32BE(16);
const height = bytes.readUInt32BE(20);
assert(Number.isInteger(batch.columns) && batch.columns > 0);
assert(Number.isInteger(batch.rows) && batch.rows > 0);
const registryPath = path.join(
  root,
  "docs/research/original-art/registry.json",
);
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const exercises = new Map(
  selectableExercises.map((exercise) => [exercise.id, exercise]),
);
for (const cell of batch.cells) {
  if (cell.reviewStatus !== "accepted") continue;
  assert(cell.reviewNote?.trim(), "A visual-review note is required.");
  assert(cell.column >= 0 && cell.column < batch.columns);
  assert(cell.row >= 0 && cell.row < batch.rows);
  const assetId = `forma-original-${batch.name}-${cell.column}-${cell.row}`;
  registry.assets[assetId] = {
    src: `${batch.publicPath}?v=${sha256.slice(0, 12)}`,
    sha256,
    width,
    height,
    sourceLabel: "FORMA original artwork",
    title: cell.title,
    kind: batch.kind,
    original: true,
    sourceUrl: batch.publicPath,
    creator: "FORMA (AI-assisted original illustration)",
    credit: "Original artwork created for FORMA.",
    creditLinks: [],
    license: "Original artwork commissioned for FORMA (AI-assisted)",
    licenseUrl: "https://openai.com/policies/terms-of-use/",
    region: {
      columns: batch.columns,
      rows: batch.rows,
      column: cell.column,
      row: cell.row,
    },
  };
  for (const id of cell.ids ?? [cell.id]) {
    const exercise = exercises.get(id);
    assert(exercise, `Unknown exercise ${id}`);
    const guide = exercise.source
      ? (instructions[exercise.instructionId ?? id] ?? exercise.description)
      : exercise.description;
    registry.exercises[id] = {
      assetId,
      caption:
        cell.caption ??
        (batch.kind.includes("equipment")
          ? `${cell.title} · Equipment reference; follow the guide for setup and movement.`
          : `${cell.title} · Representative exercise position; follow the guide for the complete movement.`),
      reviewStatus: "accepted",
      reviewNote: cell.reviewNote,
      guideSha256: crypto.createHash("sha256").update(guide).digest("hex"),
    };
  }
}
fs.mkdirSync(path.join(root, "public/exercise-media/original"), {
  recursive: true,
});
fs.copyFileSync(
  batch.sourceGeneratedPath,
  path.join(root, "public", batch.publicPath),
);
fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2) + "\n");
log(
  `Registered reviewed cells from ${batch.name}; generated source preserved.`,
);
