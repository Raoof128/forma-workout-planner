import test from "node:test";
import assert from "node:assert/strict";
import { exerciseById, selectableExercises } from "../src/data.js";
import review from "../src/catalog/logging-review.json" with { type: "json" };
import {
  holdUnit,
  loadType,
  loggedText,
  usesHoldTimer,
  visibleFields,
} from "../src/exerciseLoad.js";

const keys = (exercise, entry, sets) =>
  visibleFields(exercise, entry, sets).map((field) => field.key);

test("every selectable exercise has exactly one reviewed load decision", () => {
  const seen = new Map();
  for (const kind of ["load", "added", "none"])
    for (const id of review[kind]) {
      assert(!seen.has(id), `${id} is listed twice`);
      seen.set(id, kind);
    }
  for (const exercise of selectableExercises)
    assert(
      seen.has(exercise.id),
      `${exercise.id} (${exercise.name}) is unreviewed`,
    );
  for (const id of seen.keys())
    assert(exerciseById.has(id), `${id} is not in the catalogue`);
  for (const id of review.noTimer)
    assert.equal(
      exerciseById.get(id)?.metric,
      "duration",
      `${id} is not timed`,
    );
});

test("no-load exercises drop the weight column but keep older weighted logs", () => {
  const roller = exerciseById.get("db-ab-roller");
  const plank = exerciseById.get("db-plank");
  assert.equal(loadType(roller), "none");
  assert.equal(loadType(plank), "none");
  assert.deepEqual(keys(roller, {}, [{ weight: 0, reps: 10 }]), ["reps"]);
  assert.deepEqual(keys(plank, {}, [{ weight: 0, durationSeconds: 60 }]), [
    "durationSeconds",
  ]);
  assert.deepEqual(keys(roller, {}, [{ weight: 5, reps: 10 }]), [
    "weight",
    "reps",
  ]);
  const bench = exerciseById.get("bench");
  assert.equal(loadType(bench), "load");
  assert.deepEqual(keys(bench, {}, [{ weight: 0, reps: 5 }]), [
    "weight",
    "reps",
  ]);
});

test("bodyweight movements with optional added load label the column", () => {
  const pullups = exerciseById.get("db-pullups");
  assert.equal(loadType(pullups), "added");
  const weight = visibleFields(pullups, {}, []).find((f) => f.key === "weight");
  assert.equal(weight.label, "ADDED (KG)");
  assert.equal(loggedText(pullups, { weight: 0, reps: 8 }), "8 reps");
  assert.equal(loggedText(pullups, { weight: 10, reps: 6 }), "+10 kg × 6 reps");
});

test("logged text leaves out 0 kg where nothing is lifted", () => {
  const roller = exerciseById.get("db-ab-roller");
  const plank = exerciseById.get("db-plank");
  const bench = exerciseById.get("bench");
  assert.equal(loggedText(roller, { weight: 0, reps: 12 }), "12 reps");
  assert.equal(loggedText(plank, { weight: 0, durationSeconds: 45 }), "45 sec");
  assert.equal(loggedText(bench, { weight: 80, reps: 5 }), "80 kg × 5");
  assert.equal(loggedText(roller, { weight: 5, reps: 12 }), "5 kg × 12");
});

test("only timed exercises offer the hold timer", () => {
  assert.equal(usesHoldTimer(exerciseById.get("db-plank")), true);
  assert.equal(usesHoldTimer(exerciseById.get("db-ab-roller")), false);
  assert.equal(usesHoldTimer(exerciseById.get("bench")), false);
  const cardio = selectableExercises.find(
    (exercise) => exercise.metric === "duration_distance",
  );
  assert.equal(usesHoldTimer(cardio), false);
  for (const exercise of selectableExercises)
    if (usesHoldTimer(exercise)) assert.equal(exercise.metric, "duration");
});

test("the legacy starter plank keeps reps and times 10-second reps", () => {
  const legacy = exerciseById.get("plank");
  assert.equal(loadType(legacy), "none");
  assert.deepEqual(keys(legacy, {}, [{ weight: 0, reps: 3 }]), ["reps"]);
  assert.equal(usesHoldTimer(legacy), true);
  // Per-side logging has no single rep count for the timer to write.
  assert.equal(usesHoldTimer(legacy, { perSide: true }), false);
  // 100 reps is the most a set records, so the timer stops at 1,000 s.
  assert.deepEqual(holdUnit(legacy), { key: "reps", seconds: 10, max: 1000 });
  assert.deepEqual(holdUnit(exerciseById.get("db-plank")), {
    key: "durationSeconds",
    seconds: 1,
    max: 86400,
  });
});
