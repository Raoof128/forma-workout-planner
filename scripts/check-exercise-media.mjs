import assert from "node:assert/strict";
import { log } from "node:console";
import process from "node:process";
import { URL } from "node:url";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { selectableExercises } from "../src/data.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const read = (file) =>
  JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
const media = read("src/catalog/media.json");
const review = read("docs/research/original-art/coverage.json");
const registry = read("docs/research/original-art/registry.json");
const ids = new Set(selectableExercises.map((exercise) => exercise.id));
const exercises = new Map(
  selectableExercises.map((exercise) => [exercise.id, exercise]),
);
assert.equal(review.assignments.length, ids.size, "Incomplete review scope");
assert.equal(
  new Set(review.assignments.map((row) => row.exerciseId)).size,
  ids.size,
);
assert(review.assignments.every((row) => ids.has(row.exerciseId)));
const approved = new Map(
  review.assignments
    .filter((row) => row.status === "accepted")
    .map((row) => [row.exerciseId, row.assetId]),
);
for (const [id, entry] of Object.entries(media.exercises)) {
  assert(ids.has(id), `Unknown exercise ${id}`);
  assert.equal(
    approved.get(id),
    entry.assetId,
    `Unreviewed selection for ${id}`,
  );
  assert(media.assets[entry.assetId], `Missing asset for ${id}`);
  assert.equal(registry.exercises[id]?.reviewStatus, "accepted");
  const exercise = exercises.get(id);
  const guide = exercise.source
    ? (instructions[exercise.instructionId ?? id] ?? exercise.description)
    : exercise.description;
  assert.equal(
    registry.exercises[id].guideSha256,
    crypto.createHash("sha256").update(guide).digest("hex"),
    `Guide changed since visual review: ${id}`,
  );
  assert(entry.caption?.trim(), `Missing caption for ${id}`);
}
for (const [id, asset] of Object.entries(media.assets)) {
  const url = new URL(asset.src, "https://forma.example");
  assert.equal(
    url.origin,
    "https://forma.example",
    `External image request: ${id}`,
  );
  assert(url.pathname.startsWith("/exercise-media/"));
  const file = path.resolve(root, "public", `.${url.pathname}`);
  assert(
    file.startsWith(path.join(root, "public", "exercise-media") + path.sep),
  );
  const bytes = fs.readFileSync(file);
  const sha = crypto.createHash("sha256").update(bytes).digest("hex");
  assert.equal(sha, asset.sha256, `Changed image bytes: ${id}`);
  assert.equal(
    url.searchParams.get("v"),
    sha.slice(0, 12),
    `Stale image version: ${id}`,
  );
  assert(
    asset.creator && asset.license && asset.sourceUrl,
    `Missing attribution: ${id}`,
  );
  assert.equal(
    asset.original,
    true,
    `Third-party artwork is not allowed: ${id}`,
  );
  if (asset.region) {
    const { column, row, columns, rows } = asset.region;
    assert([column, row, columns, rows].every(Number.isInteger));
    assert(column >= 0 && column < columns && row >= 0 && row < rows);
    assert.equal(asset.width, bytes.readUInt32BE(16));
    assert.equal(asset.height, bytes.readUInt32BE(20));
    assert(columns > 0 && rows > 0, `Invalid atlas grid: ${id}`);
    if (asset.region.bounds) {
      const { x, y, width, height } = asset.region.bounds;
      assert([x, y, width, height].every(Number.isInteger));
      assert(x >= 0 && y >= 0 && width > 0 && height > 0);
      assert(
        x + width <= asset.width && y + height <= asset.height,
        `Crop outside image: ${id}`,
      );
    }
  }
}
const missing = [...ids].filter((id) => !media.exercises[id]);
log(
  `Exercise media: ${Object.keys(media.exercises).length}/${ids.size} matched; ${missing.length} remaining.`,
);
if (process.argv.includes("--require-complete"))
  assert.equal(
    missing.length,
    0,
    "Every selectable exercise needs reviewed media before the complete-library release.",
  );
