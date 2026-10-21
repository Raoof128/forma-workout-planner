import test from "node:test";
import assert from "node:assert/strict";
import { exerciseById } from "../src/data.js";
import { freshData, validateData } from "../src/storage.js";
import { usesHoldTimer } from "../src/exerciseLoad.js";
import { entryKey } from "../src/routineProgramming.js";
import { timedVersion, toTimedVersion } from "../src/timedHolds.js";
import {
  replaceEntry,
  sessionEntry,
  setsLostByReplacing,
} from "../src/workoutSession.js";

const HOLLOW = "wger-d059c63d-0a81-48a3-912a-44070c0def2e";
const LSIT = "wger-16202754-f567-4d23-a866-2c9cc8eba71d";
const WALL_SQUAT = "wger-46ee5805-512a-43a2-944c-97f7744b0078";
const WALL_SIT = "forma-wger-3f8ad988-1aee-48ca-ad37-44e39ae1715d";
const BATTLE_ROPES = "wger-a5d1f45b-ff07-45d7-a699-a654f9328934";
const BALL_SLAMS = "wger-a1e8759d-72b9-422f-87a8-9d316fa18498";
const timed = (id) => `forma-${id}`;

test("a hold saved in reps offers its timed identity", () => {
  assert.equal(timedVersion(HOLLOW)?.id, timed(HOLLOW));
  assert.equal(timedVersion(HOLLOW).metric, "duration");
  assert.equal(timedVersion(LSIT)?.id, timed(LSIT));
  // Chained aliases land on the timed row, not the intermediate saved ID.
  assert.equal(timedVersion(WALL_SQUAT)?.id, WALL_SIT);
  assert.equal(timedVersion("db-plate-pinch")?.id, "forma-db-plate-pinch");
});

test("only rep-logged entries with a timed canonical row are offered", () => {
  // The legacy plank keeps its 10-second reps and its own timer.
  assert.equal(timedVersion("plank"), null);
  // Already timed, already canonical, or not timed at all.
  assert.equal(timedVersion(timed(HOLLOW)), null);
  assert.equal(timedVersion("bench"), null);
  assert.equal(timedVersion(BALL_SLAMS), null);
  // Seconds-and-metres entries already log time; switching would drop distance.
  assert.equal(timedVersion(BATTLE_ROPES), null);
  assert.equal(timedVersion("not-an-exercise"), null);
});

const repEntry = {
  exerciseId: HOLLOW,
  sets: 4,
  reps: 8,
  repsMax: 12,
  weight: 0,
  rpe: 8.5,
  restSeconds: 75,
  perSide: false,
  note: "Ribs down",
  groupId: "pair-1",
};

test("switching keeps the programming and the row key", () => {
  const next = toTimedVersion(repEntry);
  assert.deepEqual(next, {
    ...repEntry,
    exerciseId: timed(HOLLOW),
    entryId: HOLLOW,
    reps: 1,
    repsMax: null,
    durationSeconds: 60,
  });
  assert.equal(entryKey(next), entryKey(repEntry));
  assert.equal(toTimedVersion(repEntry, 45).durationSeconds, 45);
  // Per-side logging applies to reps only, so it does not carry over.
  assert.equal(toTimedVersion({ ...repEntry, perSide: true }).perSide, false);
  // An entry that already has its own key keeps it.
  const keyed = { ...repEntry, entryId: "legacy-0-x" };
  assert.equal(toTimedVersion(keyed).entryId, "legacy-0-x");
  // Nothing to switch: the same object comes back.
  const bench = { exerciseId: "bench", sets: 3, reps: 10, weight: 40 };
  assert.equal(toTimedVersion(bench), bench);
  const plank = { exerciseId: "plank", sets: 3, reps: 3, weight: 0 };
  assert.equal(toTimedVersion(plank), plank);
});

test("a switched routine validates and keeps order, superset and history", () => {
  const data = freshData();
  const partner = {
    exerciseId: "bench",
    sets: 3,
    reps: 10,
    weight: 40,
    groupId: "pair-1",
  };
  data.routines[0].exercises = [
    { exerciseId: "squat", sets: 3, reps: 5, weight: 100 },
    partner,
    repEntry,
  ];
  data.history = [
    {
      id: "old-skills",
      name: "Skills",
      startedAt: 1000,
      date: "2026-10-20T00:00:00.000Z",
      duration: 600,
      exercises: [
        { exerciseId: HOLLOW, sets: [{ weight: 0, reps: 10, done: true }] },
      ],
    },
  ];
  const switched = structuredClone(data);
  switched.routines[0].exercises = data.routines[0].exercises.map((entry) =>
    toTimedVersion(entry),
  );
  const saved = validateData(structuredClone(switched));
  assert.deepEqual(
    saved.routines[0].exercises.map((entry) => entry.exerciseId),
    ["squat", "bench", timed(HOLLOW)],
  );
  assert.deepEqual(saved.routines[0].exercises[2], {
    ...toTimedVersion(repEntry),
  });
  // The workout built from it logs seconds with the hold timer.
  const planned = sessionEntry(saved.routines[0].exercises[2]);
  assert.equal(planned.entryId, HOLLOW);
  assert.equal(planned.sets.length, 4);
  assert.deepEqual(planned.sets[0], {
    weight: 0,
    reps: 1,
    durationSeconds: 60,
    done: false,
  });
  assert.ok(usesHoldTimer(exerciseById.get(timed(HOLLOW)), planned));
  // History keeps the rep ID and its reps.
  assert.deepEqual(saved.history[0].exercises[0].exerciseId, HOLLOW);
  assert.equal(saved.history[0].exercises[0].sets[0].reps, 10);
});

test("switching a workout card keeps its note, RPE, rest, load and superset", () => {
  const entry = {
    ...sessionEntry({ ...repEntry, exerciseId: "db-plate-pinch" }),
    sets: [
      { weight: 20, reps: 8, done: true },
      { weight: 15, reps: 8, done: false },
    ],
  };
  const target = timedVersion("db-plate-pinch");
  assert.equal(setsLostByReplacing(entry, target), 1);
  const [next] = replaceEntry([entry], entryKey(entry), target);
  assert.equal(next.exerciseId, "forma-db-plate-pinch");
  assert.equal(next.note, "Ribs down");
  assert.equal(next.rpe, 8.5);
  assert.equal(next.restSeconds, 75);
  assert.equal(next.groupId, "pair-1");
  assert.deepEqual(
    next.sets.map(({ weight, durationSeconds, done }) => ({
      weight,
      durationSeconds,
      done,
    })),
    [
      { weight: 20, durationSeconds: 60, done: false },
      { weight: 15, durationSeconds: 60, done: false },
    ],
  );
});

test("switching a bodyweight hold card logs seconds", () => {
  const entry = {
    ...sessionEntry(repEntry),
    sets: [
      { weight: 0, reps: 8, done: true },
      { weight: 0, reps: 8, done: false },
    ],
  };
  const target = timedVersion(HOLLOW);
  assert.equal(setsLostByReplacing(entry, target), 1);
  const [next] = replaceEntry([entry], entryKey(entry), target);
  assert.equal(next.exerciseId, timed(HOLLOW));
  assert.equal(next.note, "Ribs down");
  assert.equal(next.rpe, 8.5);
  assert.equal(next.restSeconds, 75);
  assert.equal(next.groupId, "pair-1");
  assert.deepEqual(
    next.sets.map((set) => set.durationSeconds),
    [60, 60],
  );
  // A different movement starts without the old cue.
  const [other] = replaceEntry(
    [entry],
    entryKey(entry),
    exerciseById.get("bench"),
  );
  assert.equal(other.note, null);
});
