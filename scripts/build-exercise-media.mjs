import assert from "node:assert/strict";
import { log } from "node:console";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { selectableExercises } from "../src/data.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const file = (name) => path.join(root, name);
const registry = JSON.parse(
  fs.readFileSync(file("docs/research/original-art/registry.json"), "utf8"),
);
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const runtime = { schemaVersion: 1, assets: {}, exercises: {} };
const scope = selectableExercises.map((exercise) => {
  const guide = exercise.source
    ? (instructions[exercise.instructionId ?? exercise.id] ??
      exercise.description)
    : exercise.description;
  const guideSha256 = sha(guide);
  const entry = registry.exercises[exercise.id];
  if (entry?.reviewStatus === "accepted") {
    const asset = registry.assets[entry.assetId];
    assert(asset?.original, `Original artwork required for ${exercise.id}`);
    assert(
      entry.reviewNote?.trim(),
      `Review notes required for ${exercise.id}`,
    );
    assert.equal(
      entry.guideSha256,
      guideSha256,
      `Guide changed since illustration review: ${exercise.id}`,
    );
    runtime.assets[entry.assetId] = asset;
    runtime.exercises[exercise.id] = {
      assetId: entry.assetId,
      caption: entry.caption,
    };
  }
  return {
    exerciseId: exercise.id,
    name: exercise.name,
    equipment: exercise.equipment,
    guideSha256,
    status: runtime.exercises[exercise.id] ? "accepted" : "pending",
    ...(entry ? { assetId: entry.assetId, reviewNote: entry.reviewNote } : {}),
  };
});
fs.writeFileSync(
  file("src/catalog/media.json"),
  JSON.stringify(runtime, null, 2) + "\n",
);
fs.writeFileSync(
  file("docs/research/original-art/coverage.json"),
  JSON.stringify(
    {
      schemaVersion: 1,
      total: scope.length,
      accepted: Object.keys(runtime.exercises).length,
      assignments: scope,
    },
    null,
    2,
  ) + "\n",
);
log(
  `Original FORMA illustrations: ${Object.keys(runtime.exercises).length}/${scope.length}.`,
);
