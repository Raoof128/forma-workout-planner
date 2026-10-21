import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { guideExercise, selectableExercises } from "../src/data.js";
import animations from "../src/catalog/animations.json" with { type: "json" };

const root = path.resolve(import.meta.dirname, "..");
const selectable = new Set(selectableExercises.map((exercise) => exercise.id));

test("animated demonstrations map selectable exercises to self-hosted files", () => {
  assert.ok(Object.keys(animations).length >= 32);
  for (const [id, entry] of Object.entries(animations)) {
    assert(selectable.has(id), `${id} is not selectable`);
    assert.equal(guideExercise(id).id, id, `${id} is not a guide id`);
    assert(entry.description?.trim(), `Missing description for ${id}`);
    assert(entry.seconds > 0, `Missing loop length for ${id}`);
    for (const file of [entry.src, entry.still]) {
      assert.match(file, /^\/exercise-animations\/[a-z0-9-]+\.svg$/);
      const full = path.join(root, "public", file);
      assert(fs.existsSync(full), `${file} missing`);
      const svg = fs.readFileSync(full, "utf8");
      assert(svg.length < 300_000, `${file} is too large`);
      assert(!/<script|href="https?:/i.test(svg), `${file} loads code or URLs`);
    }
    const animated = fs.readFileSync(
      path.join(root, "public", entry.src),
      "utf8",
    );
    const still = fs.readFileSync(
      path.join(root, "public", entry.still),
      "utf8",
    );
    assert.match(animated, /<animate /, `${entry.src} does not animate`);
    assert.doesNotMatch(still, /<animate /, `${entry.still} is not still`);
  }
});
