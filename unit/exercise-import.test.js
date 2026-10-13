import test from "node:test";
import assert from "node:assert/strict";
import catalog from "../src/catalog/exercises.json" with { type: "json" };
import { inferMeasurement } from "../scripts/exercise-measurement.mjs";

test("catalog refresh preserves all published supplemental measurement units", () => {
  assert.equal(catalog.length, 1645);
  for (const row of catalog) {
    assert.equal(
      inferMeasurement(row.name.toLowerCase(), row.category),
      row.metric,
      row.id,
    );
  }
});

test("measurement precedence distinguishes moving planks, carries and timed cardio", () => {
  for (const [name, category, expected] of [
    ["plank shoulder tap", "strength", "load_reps"],
    ["push up plank", "strength", "load_reps"],
    ["plank", "strength", "duration"],
    ["farmer walk", "cardio", "load_distance"],
    ["walk the farm", "strength", "load_distance"],
    ["jump rope", "cardio", "duration"],
    ["stationary exercise bike", "strength", "duration_distance"],
    ["rowing ergometer", "strength", "duration_distance"],
    ["wall sit", "strength", "duration"],
    ["bench press", "strength", "load_reps"],
  ])
    assert.equal(inferMeasurement(name, category), expected, name);
});
