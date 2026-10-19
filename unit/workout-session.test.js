import test from "node:test";
import assert from "node:assert/strict";
import unilateral from "../src/catalog/unilateral.json" with { type: "json" };
import { exerciseById, exercises, sessionVolume } from "../src/data.js";
import { freshData, validateData } from "../src/storage.js";
import {
  applySetValue,
  measurementText,
  setFields,
  sideReps,
  validMeasurement,
  validSides,
} from "../src/exerciseMetrics.js";
import { defaultPerSide, sideLabel } from "../src/routineProgramming.js";
import {
  addedEntry,
  moveEntry,
  removeEntry,
  sessionEntry,
  updateSetValue,
} from "../src/workoutSession.js";

const lunge = exerciseById.get("lunge");
const bench = exerciseById.get("bench");

test("the unilateral review names real catalogue rows with a limb label", () => {
  const ids = new Set(exercises.map((exercise) => exercise.id));
  for (const [id, side] of Object.entries(unilateral)) {
    assert.ok(ids.has(id), `${id} is not in the catalogue`);
    assert.ok(["arm", "leg", "side"].includes(side), `${id}: ${side}`);
  }
  assert.ok(Object.keys(unilateral).length >= 350);
  assert.equal(exerciseById.get("row").side, "arm");
  assert.equal(lunge.side, "leg");
  assert.equal(exerciseById.get("deadbug").side, "side");
  assert.equal(bench.side, undefined);
  // Alias rows share the reviewed verdict of their canonical exercise.
  assert.equal(exerciseById.get("db-dumbbell-rear-lunge").side, "leg");
});

test("reviewed sides drive per-side defaults and labels; names still cover custom rows", () => {
  assert.equal(defaultPerSide(lunge), true);
  assert.equal(defaultPerSide(bench), false);
  assert.equal(sideLabel(exerciseById.get("deadbug")), "side");
  assert.equal(
    sideLabel({ name: "Single-arm cable row", muscle: "Back" }),
    "arm",
  );
  assert.equal(defaultPerSide({ name: "Bulgarian split squat" }), true);
});

test("a per-side load/rep entry logs left and right and keeps reps as the total", () => {
  const entry = sessionEntry({
    exerciseId: "lunge",
    sets: 2,
    reps: 10,
    weight: 12,
    perSide: true,
  });
  assert.deepEqual(
    setFields(lunge, entry).map((field) => field.key),
    ["weight", "left", "right"],
  );
  assert.deepEqual(entry.sets[0], {
    weight: 12,
    reps: 20,
    sides: { left: 10, right: 10 },
    done: false,
  });
  const bilateral = sessionEntry({
    exerciseId: "bench",
    sets: 1,
    reps: 8,
    weight: 40,
  });
  assert.equal(bilateral.sets[0].sides, undefined);
  assert.equal(bilateral.sets[0].reps, 8);
  const timed = sessionEntry({
    exerciseId: "db-plank",
    sets: 1,
    reps: 1,
    weight: 0,
    perSide: true,
    durationSeconds: 30,
  });
  assert.equal(timed.sets[0].sides, undefined);
  assert.equal(timed.sets[0].durationSeconds, 30);
});

test("changing one side refreshes the total and blank sides block completion", () => {
  const set = {
    weight: 12,
    reps: 20,
    sides: { left: 10, right: 10 },
    done: false,
  };
  const left = applySetValue(set, "left", 8);
  assert.equal(left.reps, 18);
  assert.deepEqual(left.sides, { left: 8, right: 10 });
  const blank = applySetValue(left, "right", "");
  assert.equal(blank.reps, "");
  assert.equal(validMeasurement(lunge, blank), false);
  assert.equal(validMeasurement(lunge, left), true);
  assert.equal(validSides({ reps: 19, sides: { left: 10, right: 10 } }), false);
  assert.equal(measurementText(lunge, left), "12 kg × 8 L / 10 R");
  assert.equal(sideReps(left), 10);
  assert.equal(sideReps({ reps: 8 }), 8);
});

test("workspace validation accepts consistent sides and rejects inconsistent ones", () => {
  const session = (set) => ({
    id: "sides",
    name: "Sides",
    startedAt: 1000,
    exercises: [{ exerciseId: "lunge", perSide: true, sets: [set] }],
  });
  const data = freshData();
  data.active = session({
    weight: 12,
    reps: 18,
    sides: { left: 8, right: 10 },
    done: true,
  });
  const parsed = validateData(data, { strict: true });
  assert.deepEqual(parsed.active.exercises[0].sets[0].sides, {
    left: 8,
    right: 10,
  });
  assert.equal(sessionVolume(parsed.active), 12 * 18);
  data.active = session({
    weight: 12,
    reps: 20,
    sides: { left: 8, right: 10 },
    done: true,
  });
  assert.throws(() => validateData(data), /left and right/);
  data.active = session({
    weight: 12,
    reps: "",
    sides: { left: 8, right: "" },
    done: false,
  });
  assert.equal(validateData(data).active.exercises[0].sets[0].reps, "");
  data.active = session({
    weight: 12,
    reps: "",
    sides: { left: 8, right: "" },
    done: true,
  });
  assert.throws(() => validateData(data));
  // Sets logged before this change stay valid without a sides breakdown.
  data.active = session({ weight: 12, reps: 10, done: true });
  assert.equal(validateData(data).active.exercises[0].sets[0].sides, undefined);
});

test("the fill preference is stored on the profile and defaults on", () => {
  const data = freshData();
  assert.equal(data.profile.fillSets, true);
  data.profile.fillSets = false;
  assert.equal(validateData(data, { strict: true }).profile.fillSets, false);
});

test("filling carries a value to later unfinished sets that still match", () => {
  const entry = {
    exerciseId: "bench",
    sets: [
      { weight: 40, reps: 10, done: false },
      { weight: 40, reps: 10, done: false },
      { weight: 45, reps: 10, done: false },
      { weight: 40, reps: 10, done: true },
      { weight: 40, reps: 10, done: false },
    ],
  };
  const filled = updateSetValue(entry, 0, "weight", 50, { fill: true });
  assert.deepEqual(
    filled.sets.map((set) => set.weight),
    [50, 50, 45, 40, 50],
  );
  const single = updateSetValue(entry, 0, "weight", 50);
  assert.deepEqual(
    single.sets.map((set) => set.weight),
    [50, 40, 45, 40, 40],
  );
  // Only later sets follow: editing set 3 never rewrites sets 1 and 2.
  const later = updateSetValue(entry, 2, "reps", 8, { fill: true });
  assert.deepEqual(
    later.sets.map((set) => set.reps),
    [10, 10, 8, 10, 8],
  );
  // A completed set never changes, even when it is the edited one.
  assert.equal(
    updateSetValue(entry, 3, "reps", 1, { fill: true }).sets[3].reps,
    10,
  );
  const sides = sessionEntry({
    exerciseId: "lunge",
    sets: 3,
    reps: 10,
    weight: 12,
    perSide: true,
  });
  const leftFilled = updateSetValue(sides, 0, "left", 12, { fill: true });
  assert.deepEqual(
    leftFilled.sets.map((set) => [set.sides.left, set.reps]),
    [
      [12, 22],
      [12, 22],
      [12, 22],
    ],
  );
});

test("mid-workout edits add unique entries, move them and keep one exercise", () => {
  const session = {
    exercises: [
      sessionEntry({ exerciseId: "bench", sets: 1, reps: 8, weight: 40 }),
      {
        ...sessionEntry({ exerciseId: "row", sets: 1, reps: 8, weight: 16 }),
        groupId: "g",
      },
      {
        ...sessionEntry({ exerciseId: "curl", sets: 1, reps: 8, weight: 10 }),
        groupId: "g",
      },
    ],
  };
  const added = addedEntry(bench);
  assert.equal(added.exerciseId, "bench");
  assert.ok(added.entryId);
  assert.equal(added.sets.length, 3);
  const data = freshData();
  data.active = {
    id: "edit",
    name: "Edit",
    startedAt: 1000,
    exercises: [...session.exercises, added],
  };
  assert.equal(validateData(data).active.exercises.length, 4);
  const moved = moveEntry(session.exercises, "curl", -1);
  assert.deepEqual(
    moved.map((entry) => entry.exerciseId),
    ["bench", "curl", "row"],
  );
  assert.deepEqual(
    moved.map((entry) => entry.groupId),
    [null, "g", "g"],
  );
  assert.equal(moveEntry(session.exercises, "bench", -1), session.exercises);
  const removed = removeEntry(session.exercises, "row");
  assert.deepEqual(
    removed.map((entry) => entry.exerciseId),
    ["bench", "curl"],
  );
  // A superset of one exercise is no superset: the group tag is dropped.
  assert.equal(removed[1].groupId, null);
  assert.equal(removeEntry([session.exercises[0]], "bench").length, 1);
});

test("replacing an exercise keeps sets only when both log the same fields", async () => {
  const { replaceEntry, setsLostByReplacing } =
    await import("../src/workoutSession.js");
  const bench = {
    ...sessionEntry({ exerciseId: "bench", sets: 2, reps: 8, weight: 40 }),
    groupId: "g",
    restSeconds: 120,
  };
  bench.sets[0] = { ...bench.sets[0], done: true };
  const curl = sessionEntry({
    exerciseId: "curl",
    sets: 1,
    reps: 8,
    weight: 10,
  });
  const incline = exerciseById.get("db-incline-dumbbell-press");
  const kept = replaceEntry([bench, curl], "bench", incline);
  assert.equal(kept[0].exerciseId, "db-incline-dumbbell-press");
  assert.deepEqual(kept[0].sets, bench.sets);
  assert.equal(kept[0].groupId, "g");
  assert.equal(kept[0].restSeconds, 120);
  assert.ok(kept[0].entryId);
  assert.equal(kept[1], curl);
  assert.equal(setsLostByReplacing(bench, incline), 0);
  const plank = exerciseById.get("db-plank");
  assert.equal(setsLostByReplacing(bench, plank), 1);
  const swapped = replaceEntry([bench, curl], "bench", plank);
  assert.equal(swapped[0].sets.length, 2);
  assert.ok(swapped[0].sets.every((set) => !set.done && set.durationSeconds));
  // A per-side lunge logs left/right, so a bilateral swap starts fresh sets.
  const lunge = sessionEntry({
    exerciseId: "lunge",
    sets: 1,
    reps: 10,
    weight: 10,
    perSide: true,
  });
  assert.equal(
    replaceEntry([lunge], "lunge", exerciseById.get("squat"))[0].sets[0].sides,
    undefined,
  );
  assert.equal(replaceEntry([bench], "missing", plank)[0], bench);
});
