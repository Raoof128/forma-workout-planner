import assert from "node:assert/strict";
import { log } from "node:console";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { URL } from "node:url";
import { selectableExercises } from "../src/data.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const file = (name) => path.join(root, name);
const registry = JSON.parse(
  fs.readFileSync(file("docs/research/original-art/registry.json"), "utf8"),
);
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const runtime = { schemaVersion: 1, assets: {}, previews: {}, exercises: {} };
const previews = new Map();
const previewDirectory = file("public/exercise-media/previews");
fs.mkdirSync(previewDirectory, { recursive: true });
function withPreview(asset) {
  let preview = previews.get(asset.src);
  if (!preview) {
    const source = file(
      `public${new URL(asset.src, "https://forma.example").pathname}`,
    );
    // Recipe and immutable source bytes identify the derivative; never modify originals.
    const key = sha(`${asset.sha256}:half-lanczos-webp-q78-v1`).slice(0, 16);
    const name = `${path.basename(source, ".png")}-${key}.webp`;
    const destination = path.join(previewDirectory, name);
    if (!fs.existsSync(destination))
      execFileSync("ffmpeg", [
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        source,
        "-vf",
        "scale=iw/2:ih/2:flags=lanczos",
        "-c:v",
        "libwebp",
        "-quality",
        "78",
        "-compression_level",
        "6",
        "-threads",
        "1",
        "-map_metadata",
        "-1",
        "-y",
        destination,
      ]);
    const bytes = fs.readFileSync(destination);
    const sha256 = sha(bytes);
    preview = {
      src: `/exercise-media/previews/${name}?v=${sha256.slice(0, 12)}`,
      sha256,
      width: asset.width / 2,
      height: asset.height / 2,
    };
    previews.set(asset.src, preview);
  }
  const { src, sha256, width, height, title, kind, region } = asset;
  const previewId = sha256.slice(0, 16);
  runtime.previews[previewId] = preview;
  return { src, sha256, width, height, title, kind, region, previewId };
}
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
    runtime.assets[entry.assetId] = withPreview(asset);
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
