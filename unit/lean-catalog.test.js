import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import leanExerciseCatalog, {
  leanCatalogRows,
} from "../scripts/vite-lean-catalog.mjs";

const read = (path) => JSON.parse(readFileSync(path, "utf8"));
const catalog = read("src/catalog/exercises.json");
const curation = read("src/catalog/curation.json");
const instructions = read("src/catalog/instructions.json");

test("the browser catalogue drops only the description preview", () => {
  const lean = leanCatalogRows(catalog);
  assert.equal(lean.length, catalog.length);
  lean.forEach((row, index) => {
    const expected = { ...catalog[index] };
    delete expected.description;
    assert.deepEqual(row, expected);
  });
});

test("every sourced catalogue guide still has lazily loaded full text", () => {
  // The preview is only safe to drop while the full instructions cover it.
  const missing = catalog
    .filter((row) => row.source)
    .map((row) => curation.overrides?.[row.id]?.instructionId ?? row.id)
    .filter((id) => typeof instructions[id] !== "string");
  assert.deepEqual(missing, []);
});

test("the Vite transform applies only to the exercise catalogue", () => {
  const plugin = leanExerciseCatalog();
  const code = JSON.stringify([{ id: "a", name: "A", description: "x" }]);
  assert.equal(plugin.transform(code, "/app/src/catalog/curation.json"), null);
  const result = plugin.transform(
    code,
    "/app/src/catalog/exercises.json?import",
  );
  assert.deepEqual(JSON.parse(result.code), [{ id: "a", name: "A" }]);
});
