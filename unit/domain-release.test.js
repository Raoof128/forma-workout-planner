import test from "node:test";
import assert from "node:assert/strict";
import { estimatedOneRM, sessionSets, sessionVolume } from "../src/data.js";

const session = (sets) => ({
  exercises: [{ exerciseId: "bench", sets }],
});

test("completed-set volume uses exact load × reps and ignores unfinished drafts", () => {
  const workout = session([
    { weight: 50, reps: 8, done: true },
    { weight: 50, reps: 8, done: true },
    { weight: 1000, reps: 100, done: false },
  ]);
  assert.equal(sessionVolume(workout), 800);
  assert.equal(sessionSets(workout), 2);
});

test("zero external load bodyweight work counts as a set without invented volume", () => {
  const workout = session([
    { weight: 0, reps: 12, done: true },
    { weight: 0, reps: 10, done: false },
  ]);
  assert.equal(sessionSets(workout), 1);
  assert.equal(sessionVolume(workout), 0);
  assert.equal(estimatedOneRM(0, 12), 0);
});

test("estimated one-rep max keeps actual singles and computes 80 kg × 5 without early rounding", () => {
  assert.equal(estimatedOneRM(100, 1), 100);
  assert.equal(estimatedOneRM(80, 5), 80 * (1 + 5 / 30));
  assert.equal(Math.round(estimatedOneRM(80, 5) * 10) / 10, 93.3);
});

test("empty session aggregates are zero", () => {
  assert.equal(sessionSets({ exercises: [] }), 0);
  assert.equal(sessionVolume({ exercises: [] }), 0);
});
