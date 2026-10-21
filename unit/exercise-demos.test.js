import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { guideExercise, selectableExercises } from "../src/data.js";
import demos from "../src/catalog/demos.json" with { type: "json" };
import registry from "../docs/research/exercise-videos/registry.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const selectable = new Set(selectableExercises.map((exercise) => exercise.id));

test("demonstration clips are reviewed, licensed, self-hosted and unchanged", () => {
  const reviewed = new Map(registry.clips.map((clip) => [clip.id, clip]));
  for (const [id, entry] of Object.entries(demos.exercises)) {
    assert(selectable.has(id), `${id} is not selectable`);
    assert.equal(guideExercise(id).id, id, `${id} is not a guide id`);
    const clip = demos.clips[entry.clipId];
    assert(clip, `Missing clip for ${id}`);
    assert(
      reviewed.get(entry.clipId)?.formaIds.includes(id),
      `Unreviewed match: ${id}`,
    );
    assert(entry.caption?.trim(), `Missing caption for ${id}`);
  }
  for (const [id, clip] of Object.entries(demos.clips)) {
    const source = demos.sources[clip.sourceId];
    assert(source?.license, `Missing licence for ${id}`);
    assert(clip.author && clip.title, `Missing credit for ${id}`);
    assert.match(clip.url, /^https:\/\/commons\.wikimedia\.org\/wiki\/File:/);
    for (const file of [clip.src, clip.poster]) {
      assert.match(file, /^\/exercise-demos\/[a-z0-9-]+\.(mp4|jpg)$/);
      assert(fs.existsSync(path.join(root, "public", file)), `${file} missing`);
    }
    const bytes = fs.readFileSync(path.join(root, "public", clip.src));
    assert.equal(
      crypto.createHash("sha256").update(bytes).digest("hex"),
      clip.sha256,
      `${clip.src} changed since it was built`,
    );
  }
});
