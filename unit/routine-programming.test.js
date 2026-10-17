import test from "node:test";
import assert from "node:assert/strict";
import * as programming from "../src/routineProgramming.js";
import { freshData, validateData, parseBackup } from "../src/storage.js";
import { exerciseById, selectableExercises } from "../src/data.js";
import { defaultPrescription } from "../src/exerciseMetrics.js";

for (const [input, expected] of [
  ["8-10", { reps: 8, repsMax: 10 }],
  ["8–10", { reps: 8, repsMax: 10 }],
  ["10", { reps: 10, repsMax: null }],
  [" 8 - 8 ", { reps: 8, repsMax: null }],
]) {
  test(`rep input ${input} parses`, () =>
    assert.deepEqual(programming.parseRepRange(input), expected));
}
for (const input of [
  "",
  "0",
  "101",
  "10-8",
  "1.5",
  "-5",
  "8-101",
  "8-10-12",
  "8abc",
  "8–",
  "1e1",
]) {
  test(`rep input ${JSON.stringify(input)} is rejected`, () =>
    assert.throws(() => programming.parseRepRange(input), /reps/i));
}
test("v1 backup migrates once and preserves named routines and history", () => {
  const data = freshData();
  data.version = 1;
  const names = [
    "Monday – Upper Bodey",
    "Tuesday – Core",
    "Wednesday – Leg",
    "Thursday – Upper B",
    "Friday – Legs B",
  ];
  data.routines = names.map((name, i) => ({
    ...structuredClone(data.routines[0]),
    id: `routine-${i}`,
    name,
  }));
  data.active = {
    id: "active",
    name: "Legacy",
    startedAt: 1,
    exercises: [
      { exerciseId: "bench", sets: [{ weight: 30, reps: 10, done: false }] },
    ],
  };
  data.history = [
    {
      ...structuredClone(data.active),
      id: "history",
      date: "2026-10-01T00:00:00Z",
      duration: 60,
    },
  ];
  data.history[0].exercises[0].sets[0].done = true;
  const migrated = parseBackup(JSON.stringify(data));
  assert.equal(migrated.version, 2);
  assert.deepEqual(
    migrated.routines.map((r) => r.name),
    names,
  );
  assert.equal(migrated.routines[0].exercises[0].repsMax, null);
  assert.equal(migrated.routines[0].exercises[0].perSide, false);
  assert.equal(migrated.history[0].exercises[0].sets[0].weight, 30);
  assert.deepEqual(validateData(migrated), migrated);
});
test("incline aliases migrate in routines, active and history without losing colliding rows", () => {
  const data = freshData();
  data.version = 1;
  const alias = "wger-4b23738a-67a8-41af-996d-abc53a7c3f97";
  data.routines[0].exercises = [
    { exerciseId: alias, sets: 3, reps: 8, weight: 15 },
    { exerciseId: "db-incline-dumbbell-press", sets: 4, reps: 12, weight: 20 },
  ];
  data.active = {
    id: "a",
    name: "Test",
    startedAt: 1,
    exercises: data.routines[0].exercises.map((e) => ({
      exerciseId: e.exerciseId,
      sets: [{ weight: e.weight, reps: e.reps, done: true }],
    })),
  };
  data.history = [
    {
      ...structuredClone(data.active),
      id: "h",
      date: "2026-10-01T00:00:00Z",
      duration: 60,
    },
  ];
  const result = validateData(data);
  for (const entries of [
    result.routines[0].exercises,
    result.active.exercises,
    result.history[0].exercises,
  ]) {
    assert.deepEqual(
      entries.map((e) => e.exerciseId),
      ["db-incline-dumbbell-press", "db-incline-dumbbell-press"],
    );
    assert.equal(new Set(entries.map(programming.entryKey)).size, 2);
  }
  assert.ok(
    JSON.stringify(validateData(result)) === JSON.stringify(result),
    "Migration serialization must be idempotent for conflict comparisons",
  );
  assert.equal(result.routines[0].exercises[0].reps, 8);
  assert.equal(result.routines[0].exercises[1].reps, 12);
  assert.deepEqual(validateData(result), result);
});
test("picker names/equipment match saved display and incline synonyms share one entry", () => {
  for (const e of selectableExercises) {
    assert.equal(exerciseById.get(e.id).name, e.name, e.id);
    assert.equal(exerciseById.get(e.id).equipment, e.equipment, e.id);
  }
  assert.equal(
    exerciseById.get("wger-0ecfec6f-5d0f-4e8a-8d37-f6203a8923b8").equipment,
    "Cable",
  );
  assert.equal(
    selectableExercises.filter(
      (e) => e.name.toLowerCase() === "incline dumbbell press",
    ).length,
    1,
  );
  assert.equal(
    selectableExercises.filter((e) =>
      /^incline dumbbell fly(?:es)?$/i.test(e.name),
    ).length,
    1,
  );
  assert.equal(defaultPrescription(exerciseById.get("lunge")).perSide, true);
});
test("new programming fields are validated and retained", () => {
  const data = freshData();
  Object.assign(data.routines[0].exercises[0], {
    reps: 8,
    repsMax: 10,
    rpe: 8.5,
    restSeconds: 90,
    perSide: true,
    note: "<b>30° bench</b>",
    groupId: null,
  });
  assert.equal(
    validateData(data).routines[0].exercises[0].note,
    "<b>30° bench</b>",
  );
  for (const [key, value] of [
    ["repsMax", 7],
    ["repsMax", 101],
    ["rpe", 0],
    ["rpe", 10.5],
    ["rpe", 8.2],
    ["restSeconds", 9],
    ["restSeconds", 601],
    ["restSeconds", 1.5],
    ["note", "x".repeat(141)],
    ["perSide", "true"],
  ]) {
    const bad = structuredClone(data);
    bad.routines[0].exercises[0][key] = value;
    assert.throws(() => validateData(bad), key);
  }
});
test("rest uses a timestamp, clamps adjustments and only follows the last superset exercise", () => {
  const entries = [
    { exerciseId: "bench", groupId: "a" },
    { exerciseId: "row", groupId: "a" },
    { exerciseId: "squat" },
  ];
  assert.equal(programming.shouldRest(entries, 0), false);
  assert.equal(programming.shouldRest(entries, 1), true);
  assert.equal(programming.restRemaining({ restEnd: 91000 }, 61000), 30);
  assert.equal(programming.restRemaining({ restEnd: 91000 }, 120000), 0);
  assert.equal(
    programming.adjustRest({ restEnd: 91000, restPaused: null }, 15, 61000)
      .restEnd,
    106000,
  );
  assert.equal(
    programming.adjustRest({ restEnd: 65000 }, -15, 61000).restEnd,
    null,
  );
  assert.equal(
    programming.adjustRest({ restEnd: null, restPaused: 590 }, 15, 61000)
      .restPaused,
    600,
  );
});

test("supersets reject noncontiguous groups and normalization clears broken groups", () => {
  const rows = [
    { exerciseId: "bench", groupId: "a" },
    { exerciseId: "row", groupId: "b" },
    { exerciseId: "curl", groupId: "a" },
    { exerciseId: "squat", groupId: "b" },
  ];
  assert.equal(programming.validGroups(rows), false);
  assert.ok(
    programming.normalizeGroups(rows).every((row) => row.groupId === null),
  );
});

test("equipment audit catches name mismatches and reviewed selectable library is clean", async () => {
  const { auditEquipment } =
    await import("../scripts/audit-exercise-equipment.mjs");
  assert.equal(
    auditEquipment([
      { id: "bad", name: "Seated Cable Row", equipment: "Bodyweight" },
    ]).length,
    1,
  );
  assert.deepEqual(auditEquipment(selectableExercises), []);
});

test("pause and resume use action time even when a save queue runs later", () => {
  assert.deepEqual(
    programming.toggleRest(
      { restEnd: 91000, restPaused: null, restSeconds: 90 },
      61000,
    ),
    { restEnd: null, restPaused: 30, restSeconds: 90 },
  );
  assert.equal(
    programming.toggleRest(
      { restEnd: null, restPaused: 30, restSeconds: 90 },
      61000,
    ).restEnd,
    91000,
  );
});

test("privacy disclosure covers optional target and actual RPE", async () => {
  const { legalDocuments } = await import("../src/legal/content.js");
  assert.match(JSON.stringify(legalDocuments.privacy), /perceived exertion/);
});

test("v1 unfinished out-of-range drafts migrate without losing original entered values", () => {
  const data = freshData();
  data.version = 1;
  data.active = {
    id: "a",
    name: "Legacy drafts",
    startedAt: 1,
    exercises: [
      {
        exerciseId: "bench",
        sets: [
          { weight: 1001, reps: 0, done: false },
          { weight: -5, reps: 101, done: false },
          { weight: 20, reps: 2.5, done: false },
        ],
      },
    ],
  };
  const migrated = validateData(data);
  assert.deepEqual(
    migrated.active.exercises[0].sets.map((s) => [
      s.weight,
      s.reps,
      s.legacyDraft,
    ]),
    [
      ["", "", { weight: "1001", reps: "0" }],
      ["", "", { weight: "-5", reps: "101" }],
      [20, "", { reps: "2.5" }],
    ],
  );
  assert.deepEqual(validateData(migrated), migrated);
  const bad = structuredClone(migrated);
  bad.active.exercises[0].sets[0].reps = 0;
  assert.throws(() => validateData(bad));
});

test("unrelated historical alias names remain stable while picker IDs use reviewed names", () => {
  assert.equal(
    exerciseById.get("wger-422a48aa-a41e-46e7-b84f-0bd99ccb0737").name,
    "Hammer Curl",
  );
});
