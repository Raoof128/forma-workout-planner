import test from "node:test";
import assert from "node:assert/strict";
import { workspacePutSchema } from "../schema.js";
import { freshData } from "../../src/storage.js";

test("API retains v2 programming fields and rejects every invalid bound and nested unknown key", () => {
  const data = freshData();
  data.routines[0].archivedAt = 1;
  Object.assign(data.routines[0].exercises[0], {
    reps: 8,
    repsMax: 10,
    rpe: 8.5,
    restSeconds: 75,
    perSide: true,
    note: "30° bench",
  });
  const payload = () => ({
    data: structuredClone(data),
    expectedRevision: 0,
    operationId: "programming",
  });
  data.profile.fillSets = false;
  data.active = {
    id: "sides",
    name: "Sides",
    startedAt: 1000,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        exerciseId: "lunge",
        perSide: true,
        sets: [
          { weight: 12, reps: 18, sides: { left: 8, right: 10 }, done: true },
        ],
      },
    ],
  };
  const parsed = workspacePutSchema.parse(payload());
  assert.equal(parsed.data.routines[0].exercises[0].rpe, 8.5);
  assert.equal(parsed.data.routines[0].archivedAt, 1);
  assert.equal(parsed.data.profile.fillSets, false);
  assert.deepEqual(parsed.data.active?.exercises[0].sets[0].sides, {
    left: 8,
    right: 10,
  });
  {
    const input = payload();
    input.data.active.exercises[0].sets[0].reps = 20;
    assert.equal(workspacePutSchema.safeParse(input).success, false, "sides");
  }
  for (const [key, value] of [
    ["repsMax", 0],
    ["repsMax", 101],
    ["repsMax", 7],
    ["rpe", 0.5],
    ["rpe", 10.5],
    ["rpe", 8.1],
    ["restSeconds", 9],
    ["restSeconds", 601],
    ["note", "n".repeat(141)],
    ["ownerId", "someone-else"],
  ]) {
    const input = payload();
    Object.assign(input.data.routines[0].exercises[0], {
      [key as string]: value,
    });
    assert.equal(
      workspacePutSchema.safeParse(input).success,
      false,
      `${key}=${value}`,
    );
  }
  for (const path of ["root", "profile", "routine"]) {
    const input = payload();
    Object.assign(
      path === "root"
        ? input.data
        : path === "profile"
          ? input.data.profile
          : input.data.routines[0],
      { unknown: "no" },
    );
    assert.equal(workspacePutSchema.safeParse(input).success, false, path);
  }
});

test("API validates actual set RPE and unfinished numeric drafts", () => {
  const data = freshData();
  data.active = {
    id: "a",
    name: "Workout",
    startedAt: 1,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        exerciseId: "bench",
        sets: [{ weight: 20, reps: 8, done: false, rpe: 8.5 }],
      },
    ],
  } as typeof data.active;
  const input = { data, expectedRevision: 0, operationId: "set-rpe" };
  assert.equal(workspacePutSchema.safeParse(input).success, true);
  for (const rpe of [0, 11, 8.1]) {
    data.active!.exercises[0].sets[0].rpe = rpe;
    assert.equal(workspacePutSchema.safeParse(input).success, false);
  }
});
