import assert from "node:assert/strict";
import test from "node:test";
import { exerciseById, exercises } from "../src/data.js";
import { progressRecords } from "../src/progressSummary.js";

const entry = (exerciseId, sets) => ({ exerciseId, sets });
const set = (weight, reps, extra = {}) => ({
  weight,
  reps,
  done: true,
  ...extra,
});

test("records preserve saved identities and catalogue order across sessions", () => {
  const alias = "wger-3717d144-7815-4a97-9a56-956fb889c996";
  const history = [
    { exercises: [entry(alias, [set(90, 1)]), entry("bench", [set(50, 8)])] },
    {
      exercises: [entry("bench", [set(55, 10), set(100, 1, { done: false })])],
    },
  ];
  const original = structuredClone(history);
  const result = progressRecords(history);
  assert.deepEqual(
    result.map((record) => record.id),
    exercises.filter((e) => [alias, "bench"].includes(e.id)).map((e) => e.id),
  );
  assert.deepEqual(
    result.find((record) => record.id === alias),
    {
      ...exerciseById.get(alias),
      maxWeight: 90,
      oneRM: 90,
      sets: 1,
    },
  );
  assert.deepEqual(
    result.find((record) => record.id === "bench"),
    {
      ...exerciseById.get("bench"),
      maxWeight: 55,
      oneRM: 55 * (1 + 10 / 30),
      sets: 2,
    },
  );
  assert.deepEqual(history, original);
});

test("strength estimates use the stronger side, while high reps only update maximum load", () => {
  const result = progressRecords([
    {
      exercises: [
        entry("row", [
          set(20, 17, { sides: { left: 8, right: 9 } }),
          set(30, 13),
        ]),
      ],
    },
  ]);
  assert.equal(result[0].oneRM, 26);
  assert.equal(result[0].maxWeight, 30);
  assert.equal(result[0].sets, 2);
});

test("time, distance and unfinished entries produce no strength records", () => {
  const timed = exercises.filter((e) =>
    ["duration", "duration_distance", "load_distance"].includes(e.metric),
  );
  assert.ok(new Set(timed.map((e) => e.metric)).size === 3);
  assert.deepEqual(
    progressRecords([
      {
        exercises: [
          ...timed.map((e) =>
            entry(e.id, [
              set(200, 1, { durationSeconds: 60, distanceMeters: 500 }),
            ]),
          ),
          entry("bench", [set(50, 8, { done: false })]),
        ],
      },
    ]),
    [],
  );
  assert.deepEqual(progressRecords([]), []);
});

test("records show the reviewed name the logger and history use", () => {
  const raw = exercises.find(
    (e) => e.metric === "load_reps" && exerciseById.get(e.id).name !== e.name,
  );
  const [record] = progressRecords([
    { exercises: [entry(raw.id, [set(20, 5)])] },
  ]);
  assert.equal(record.name, exerciseById.get(raw.id).name);
  assert.notEqual(record.name, raw.name);
});
