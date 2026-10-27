import test from "node:test";
import assert from "node:assert/strict";
import * as programming from "../src/routineProgramming.js";
import { exerciseById } from "../src/data.js";
import { freshData, validateData } from "../src/storage.js";
import { sessionEntry } from "../src/workoutSession.js";

const targetError = (entry, exercise) =>
  programming.perSideTargetError?.(entry, exercise) ?? null;

test("per-side targets explain the logging limit, including the upper rep range", () => {
  const exercise = exerciseById.get("row");
  for (const targets of [{ reps: 60 }, { reps: 45, repsMax: 60 }])
    assert.equal(
      targetError({ perSide: true, ...targets }, exercise),
      `Use 1–50 reps per side for ${exercise.name} before starting this workout.`,
    );
});

test("50 reps per side still starts, and ordinary or timed targets are unaffected", () => {
  const base = freshData();
  const entry = { ...base.routines[0].exercises[1], perSide: true, reps: 50 };
  assert.equal(targetError(entry, exerciseById.get("row")), null);
  const active = {
    id: "per-side-maximum",
    name: "Synthetic unilateral workout",
    startedAt: 0,
    exercises: [sessionEntry(entry)],
  };
  assert.equal(
    validateData({ ...base, active }).active.exercises[0].sets[0].reps,
    100,
  );
  assert.equal(
    targetError(
      { ...entry, perSide: false, reps: 100 },
      exerciseById.get("row"),
    ),
    null,
  );
  assert.equal(
    targetError(
      { ...entry, reps: 100 },
      { id: "synthetic-timed", metric: "duration" },
    ),
    null,
  );
});

test("previously saved overrange routines remain valid and are never silently rewritten", () => {
  const base = freshData();
  base.routines[0].exercises[1].reps = 60;
  base.routines[0].exercises[1].perSide = true;
  const before = structuredClone(base);
  const parsed = validateData(base);
  assert.equal(parsed.routines[0].exercises[1].reps, 60);
  assert.ok(
    targetError(parsed.routines[0].exercises[1], exerciseById.get("row")),
  );
  assert.deepEqual(base, before);
});
