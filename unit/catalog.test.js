import test from "node:test";
import assert from "node:assert/strict";
import { exercises, exerciseById, sessionVolume } from "../src/data.js";
import { freshData, validateData, parseBackup } from "../src/storage.js";
import {
  defaultPrescription,
  validMeasurement,
  measurementText,
} from "../src/exerciseMetrics.js";
import { workoutTemplates } from "../src/workoutTemplates.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };
import { matchesExercise } from "../src/catalog/search.js";

test("catalog search matches aliases, punctuation and words across fields", () => {
  const exercise = {
    name: "Dumbbell Push-up",
    muscle: "Chest",
    equipment: "Dumbbell",
    aliases: ["Développé"],
  };
  assert.ok(matchesExercise(exercise, "pushup"));
  assert.ok(matchesExercise(exercise, "chest dumbbell"));
  assert.ok(matchesExercise(exercise, "developpe"));
  assert.equal(matchesExercise(exercise, "chest barbell"), false);
});

test("catalog preserves legacy IDs and gives every imported entry licensed text provenance", () => {
  assert.ok(exercises.length >= 1500);
  assert.equal(exerciseById.size, exercises.length);
  for (const id of [
    "bench",
    "row",
    "shoulder",
    "pulldown",
    "curl",
    "triceps",
    "squat",
    "rdl",
    "legpress",
    "lunge",
    "calf",
    "plank",
    "goblet",
    "pushup",
    "lateral",
    "deadbug",
  ])
    assert.ok(exerciseById.has(id), id);
  for (const exercise of exercises.slice(16).filter((row) => row.source)) {
    assert.ok(exercise.description.length > 0, exercise.id);
    assert.ok(
      instructions[exercise.instructionId ?? exercise.id].length >= 60,
      exercise.id,
    );
    assert.ok(exercise.source.author && exercise.source.license);
    assert.equal(new URL(exercise.source.url).protocol, "https:");
    assert.equal("images" in exercise, false);
  }
});

test("timed cardio, holds and carries retain their units through backup round trips", () => {
  for (const id of ["db-running-treadmill", "db-plank", "db-farmers-walk"]) {
    const exercise = exerciseById.get(id);
    const prescription = defaultPrescription(exercise);
    const data = freshData();
    data.routines[0].exercises = [{ exerciseId: id, ...prescription }];
    data.history = [
      {
        id: `test-${id}`,
        name: "Measured session",
        startedAt: 1000,
        date: "2026-10-13T00:00:00.000Z",
        duration: 60,
        exercises: [
          { exerciseId: id, sets: [{ ...prescription, done: true }] },
        ],
      },
    ];
    const restored = parseBackup(JSON.stringify(data));
    const set = restored.history[0].exercises[0].sets[0];
    assert.ok(validMeasurement(exercise, set));
    assert.equal(
      sessionVolume(restored.history[0]),
      0,
      "seconds/meters cannot become kilograms lifted",
    );
    assert.match(measurementText(exercise, set), /sec|m/);
    if (prescription.durationSeconds)
      assert.equal(set.durationSeconds, prescription.durationSeconds);
    if (prescription.distanceMeters)
      assert.equal(set.distanceMeters, prescription.distanceMeters);
  }
});

test("missing or invalid timed measurements are rejected by the shared API validator", () => {
  const data = freshData();
  data.active = {
    id: "timed",
    name: "Timed workout",
    startedAt: 1000,
    exercises: [
      { exerciseId: "db-plank", sets: [{ weight: 0, reps: 1, done: true }] },
    ],
  };
  assert.throws(() => validateData(data), /measurements/);
  data.active.exercises[0].sets[0].durationSeconds = -1;
  assert.throws(() => validateData(data));
  data.active.exercises[0].sets[0].durationSeconds = 30;
  assert.equal(
    validateData(data).active.exercises[0].sets[0].durationSeconds,
    30,
  );
});

test("workout templates validate and never prescribe arbitrary starting weights", () => {
  assert.equal(workoutTemplates.length, 12);
  const data = freshData();
  data.routines = workoutTemplates;
  assert.equal(validateData(data).routines.length, 12);
  assert.ok(
    workoutTemplates.every((template) =>
      template.exercises.every((item) => item.weight === 0),
    ),
  );
});

test("expanded catalog retains finite per-workout bounds and rejects unknown exercise IDs", () => {
  const data = freshData();
  data.routines[0].exercises = exercises.slice(0, 101).map((exercise) => ({
    exerciseId: exercise.id,
    ...defaultPrescription(exercise),
  }));
  assert.throws(() => validateData(data));
  data.routines[0].exercises = [
    { exerciseId: "unknown-exercise", sets: 1, weight: 0, reps: 1 },
  ];
  assert.throws(() => validateData(data));
});
