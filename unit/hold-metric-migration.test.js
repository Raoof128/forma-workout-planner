import test from "node:test";
import assert from "node:assert/strict";
import {
  exerciseById,
  guideExercise,
  selectableExercises,
  sessionVolume,
} from "../src/data.js";
import curation from "../src/catalog/curation.json" with { type: "json" };
import instructions from "../src/catalog/instructions.json" with { type: "json" };
import media from "../src/catalog/media.json" with { type: "json" };
import registry from "../docs/research/original-art/registry.json" with { type: "json" };
import { canonicalId } from "../src/catalog/curation.js";
import { freshData, parseBackup, validateData } from "../src/storage.js";
import {
  holdUnit,
  loadType,
  loggedText,
  usesHoldTimer,
  visibleFields,
} from "../src/exerciseLoad.js";

// The holds whose guides describe holding a position, each with the load
// class it was reviewed with. Arch Hang is not here: its guide says "Hold it
// for time/reps", so its rep logging stays.
const holds = [
  ["wger-d059c63d-0a81-48a3-912a-44070c0def2e", "Hollow Hold", "none"],
  ["wger-16202754-f567-4d23-a866-2c9cc8eba71d", "L-sit", "none"],
  [
    "wger-a092afaf-aa5a-4384-b407-a6b52cf1c008",
    "L-Sit (Foot Supported)",
    "none",
  ],
  ["wger-d2cf769a-9271-41ae-90fc-aef813e41740", "Straddle L-Sit", "none"],
  ["wger-9396a728-3da4-4390-ae4d-882395805008", "Tuck L-sit", "none"],
  ["wger-f41ac754-45a0-443b-afe5-e624e215229f", "Front Lever", "none"],
  ["wger-e79616cb-f5fb-4b10-b99d-09d43774e142", "Front lever tuck", "none"],
  ["wger-8e1cda15-542b-4714-8cc5-c1fe5089ee27", "Back Lever", "none"],
  ["wger-a82944ae-24f4-4f7a-8aac-af251f6907e5", "Planche Lean Hold", "none"],
  ["wger-74d4697d-8a97-4ea2-9d05-fa4d2bd7221e", "Deadhang", "added"],
  ["wger-9f9edad8-7da0-448c-bfcb-ec61f2d28162", "Sloper hanging", "none"],
  ["wger-6c9c9d14-e6bf-43ed-9859-a689e2131fe0", "Ring Support Hold", "none"],
  ["wger-35008ce6-74ca-40db-b965-44a1eccfa061", "Handstand", "none"],
  ["wger-1d1a53dd-e00f-477e-83f7-09c8ef9a71cd", "elbow lever", "none"],
  ["wger-23d2b2ce-4ae7-441a-a122-9f6784f15aa6", "Sphinx", "none"],
];
const HOLLOW = "wger-d059c63d-0a81-48a3-912a-44070c0def2e";
const DEADHANG = "wger-74d4697d-8a97-4ea2-9d05-fa4d2bd7221e";
const ARCH_HANG = "wger-f4291da4-09c2-4605-a90c-c926c6a92515";
const timed = (id) => `forma-${id}`;
const selectable = new Set(selectableExercises.map((row) => row.id));
const workout = (id, exercises) => ({
  id,
  name: "Skills",
  startedAt: 1000,
  date: "2026-10-20T00:00:00.000Z",
  duration: 600,
  exercises,
});

test("each reviewed hold has a timed identity that new selections use", () => {
  for (const [id, name, load] of holds) {
    const saved = exerciseById.get(id);
    const hold = exerciseById.get(timed(id));
    assert.equal(saved.metric, "load_reps", `${name} keeps its saved units`);
    assert.equal(hold?.metric, "duration", `${name} has a timed identity`);
    assert.equal(hold.name, name);
    assert(selectable.has(timed(id)), `${name} is offered timed`);
    assert(!selectable.has(id), `${name} is not offered in reps`);
    assert.equal(canonicalId(id, curation), timed(id));
    assert.equal(usesHoldTimer(hold), true, name);
    assert.equal(usesHoldTimer(saved), false, `${name} reps get no timer`);
    assert.deepEqual(holdUnit(hold), {
      key: "durationSeconds",
      seconds: 1,
      max: 86400,
    });
    assert.equal(loadType(hold), load, name);
    assert.equal(loadType(saved), load, name);
    const guide = guideExercise(id);
    assert.equal(guide.id, timed(id), `${name} rep logs open the same guide`);
    assert.equal(instructions[guide.instructionId], instructions[id], name);
    assert.equal(
      media.exercises[timed(id)]?.assetId,
      registry.exercises[id].assetId,
      `${name} keeps its reviewed illustration`,
    );
  }
});

test("Arch Hang keeps reps because its guide also prescribes reps", () => {
  const archHang = exerciseById.get(ARCH_HANG);
  assert.equal(archHang.metric, "load_reps");
  assert(selectable.has(ARCH_HANG));
  assert.equal(canonicalId(ARCH_HANG, curation), ARCH_HANG);
  assert.equal(exerciseById.has(timed(ARCH_HANG)), false);
  assert.equal(usesHoldTimer(archHang), false);
});

test("saved rep sets of a migrated hold keep their meaning", () => {
  const data = freshData();
  const repSets = (id, done) => [
    { weight: id === DEADHANG ? 5 : 0, reps: id === DEADHANG ? 3 : 10, done },
  ];
  data.history = [
    workout(
      "old-skills",
      holds.map(([id]) => ({ exerciseId: id, sets: repSets(id, true) })),
    ),
  ];
  data.routines[0].exercises = holds.map(([id]) => ({
    exerciseId: id,
    sets: 3,
    reps: 10,
    weight: 0,
  }));
  data.active = {
    id: "active-skills",
    name: "Skills",
    startedAt: 2000,
    exercises: holds.map(([id]) => ({
      exerciseId: id,
      sets: repSets(id, false),
    })),
  };
  const restored = parseBackup(JSON.stringify(data));
  const savedIds = holds.map(([id]) => id);
  for (const owner of [
    restored.history[0],
    restored.routines[0],
    restored.active,
  ])
    assert.deepEqual(
      owner.exercises.map((entry) => entry.exerciseId),
      savedIds,
      "saved entries keep their rep IDs",
    );
  // The v2 migration runs after validation, so a saved ID moved to its timed
  // identity would only fail on the next save. Validate the result again.
  assert.doesNotThrow(() => validateData(structuredClone(restored)));

  const hollow = restored.history[0].exercises[0];
  const deadhang = restored.history[0].exercises[9];
  assert.equal(deadhang.exerciseId, DEADHANG);
  assert.deepEqual(hollow.sets[0], {
    legacyDraft: null,
    weight: 0,
    reps: 10,
    rpe: null,
    done: true,
  });
  assert.equal(restored.routines[0].exercises[1].reps, 10);
  assert.equal(restored.active.exercises[13].sets[0].reps, 10);

  assert.equal(loggedText(exerciseById.get(HOLLOW), hollow.sets[0]), "10 reps");
  assert.equal(
    loggedText(exerciseById.get(DEADHANG), deadhang.sets[0]),
    "+5 kg × 3 reps",
  );
  // 5 kg added for 3 Deadhang reps; the bodyweight holds add nothing.
  assert.equal(sessionVolume(restored.history[0]), 15);
  assert.deepEqual(
    visibleFields(exerciseById.get(HOLLOW), hollow).map((f) => f.key),
    ["reps"],
  );
  assert.deepEqual(
    visibleFields(exerciseById.get(DEADHANG), deadhang).map((f) => f.label),
    ["ADDED (KG)", "REPS"],
  );
});

test("new sets of a timed hold log seconds and add no lifting volume", () => {
  const data = freshData();
  data.history = [
    workout("timed-skills", [
      {
        exerciseId: timed(HOLLOW),
        sets: [{ weight: 0, reps: 1, durationSeconds: 45, done: true }],
      },
      {
        exerciseId: timed(DEADHANG),
        sets: [{ weight: 10, reps: 1, durationSeconds: 20, done: true }],
      },
    ]),
  ];
  const restored = parseBackup(JSON.stringify(data));
  const [hollow, deadhang] = restored.history[0].exercises;
  assert.equal(
    loggedText(exerciseById.get(timed(HOLLOW)), hollow.sets[0]),
    "45 sec",
  );
  assert.equal(
    loggedText(exerciseById.get(timed(DEADHANG)), deadhang.sets[0]),
    "20 sec · +10 kg",
  );
  assert.equal(sessionVolume(restored.history[0]), 0);
  assert.deepEqual(
    visibleFields(exerciseById.get(timed(DEADHANG)), deadhang).map(
      (f) => f.label,
    ),
    ["TIME (SECONDS)", "ADDED (KG)"],
  );

  // A completed set of the timed identity needs its seconds.
  data.history[0].exercises[0].sets = [{ weight: 0, reps: 10, done: true }];
  assert.throws(
    () => parseBackup(JSON.stringify(data)),
    /valid exercise measurements/,
  );
});
