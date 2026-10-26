import test from "node:test";
import assert from "node:assert/strict";
import { selectableExercises } from "../src/data.js";
import { matchesExercise } from "../src/catalog/search.js";
const fold = (value) =>
  value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
function originalMatch(exercise, query) {
  const text = fold(
    [
      exercise.name,
      exercise.muscle,
      exercise.equipment,
      exercise.category,
      ...(exercise.equipmentTags ?? []),
      ...(exercise.aliases ?? []),
      ...(exercise.primaryMuscles ?? []),
      ...(exercise.secondaryMuscles ?? []),
    ]
      .filter(Boolean)
      .join(" "),
  );
  return query
    .trim()
    .split(/\s+/)
    .every((word) => text.includes(fold(word)));
}
test("catalog search preserves the complete result set for all names and aliases", () => {
  const queries = [
    "",
    " \t\n ",
    "...",
    "DÉVELOPPÉ",
    "chest dumbbell",
    "cable lat",
    "upper back",
    "no-such-exercise-000",
    ...selectableExercises.flatMap((exercise) => [
      exercise.name,
      ...(exercise.aliases ?? []),
    ]),
  ];
  for (const query of queries) {
    assert.deepEqual(
      selectableExercises
        .filter((exercise) => matchesExercise(exercise, query))
        .map((exercise) => exercise.id),
      selectableExercises
        .filter((exercise) => originalMatch(exercise, query))
        .map((exercise) => exercise.id),
      query,
    );
  }
});
test("search sees changed fields and in-place edits of aliases and tags", () => {
  const exercise = {
    name: "Bench",
    muscle: "Chest",
    equipment: "Barbell",
    aliases: ["Press"],
    equipmentTags: ["Rack"],
    primaryMuscles: ["pectorals"],
    secondaryMuscles: ["triceps"],
  };
  for (const query of ["bench", "press", "rack", "pectorals", "triceps"])
    assert.equal(matchesExercise(exercise, query), true);
  exercise.name = "Squat";
  exercise.muscle = "Legs";
  exercise.equipment = "Dumbbell";
  exercise.aliases[0] = "Goblet";
  exercise.equipmentTags[0] = "Free weights";
  exercise.primaryMuscles[0] = "quadriceps";
  exercise.secondaryMuscles[0] = "glutes";
  for (const query of [
    "bench",
    "press",
    "rack",
    "pectorals",
    "triceps",
    "barbell",
    "chest",
  ])
    assert.equal(matchesExercise(exercise, query), false, query);
  for (const query of [
    "squat",
    "goblet",
    "free weights",
    "quadriceps",
    "glutes",
    "dumbbell",
    "legs",
  ])
    assert.equal(matchesExercise(exercise, query), true, query);
  exercise.aliases.push("Goblet squat");
  assert.equal(matchesExercise(exercise, "goblet squat"), true);
});
test("identical IDs do not share search metadata and an empty query includes every record", () => {
  const one = { id: "same", name: "Push-up" },
    two = { id: "same", name: "Row" };
  assert.equal(matchesExercise(one, "pushup"), true);
  assert.equal(matchesExercise(two, "pushup"), false);
  for (const query of ["", " ", "...", "\t"])
    for (const exercise of [one, two])
      assert.equal(matchesExercise(exercise, query), true);
});
