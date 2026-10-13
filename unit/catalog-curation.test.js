import test from "node:test";
import assert from "node:assert/strict";
import {
  exercises,
  exerciseById,
  publishedExercises,
  selectableExercises,
  guideExercise,
} from "../src/data.js";
import curation from "../src/catalog/curation.json" with { type: "json" };
import instructions from "../src/catalog/instructions.json" with { type: "json" };
import { freshData, parseBackup, validateData } from "../src/storage.js";
import { defaultPrescription } from "../src/exerciseMetrics.js";
import {
  createCatalogView,
  matchesEquipment,
  usableGuide,
} from "../src/catalog/curation.js";

test("duplicate names become searchable aliases without mutating compatibility records", () => {
  const rows = [
    {
      id: "curl",
      name: "Hammer Curls",
      equipment: "Dumbbell",
      metric: "load_reps",
    },
    {
      id: "other",
      name: "Hammer Curl",
      equipment: "Dumbbell",
      metric: "load_reps",
    },
    {
      id: "bar",
      name: "Barbell curl",
      equipment: "Barbell",
      metric: "load_reps",
    },
  ];
  const original = structuredClone(rows);
  const result = createCatalogView(rows, {
    aliases: { other: "curl" },
    hidden: [],
    overrides: {},
  });
  assert.deepEqual(
    result.map((x) => x.id),
    ["curl", "bar"],
  );
  assert.ok(result[0].aliases.includes("Hammer Curl"));
  assert.deepEqual(rows, original);
});

test("specific machine metadata remains discoverable through machine and attachment filters", () => {
  const rows = [{ id: "press", name: "Chest press", equipment: "Bodyweight" }];
  const [entry] = createCatalogView(rows, {
    aliases: {},
    hidden: [],
    overrides: {
      press: {
        equipment: "Chest press machine",
        equipmentTags: ["Machine", "Chest press machine"],
        category: "strength",
      },
    },
  });
  assert.equal(entry.equipment, "Chest press machine");
  assert.ok(matchesEquipment(entry, "Machine"));
  assert.ok(matchesEquipment(entry, "Chest press machine"));
  assert.equal(matchesEquipment(entry, "Bodyweight"), false);
});

test("boilerplate is not a usable guide and hidden records remain available for saved data", () => {
  assert.equal(
    usableGuide(
      "Custom description created by the Integrated Conditioning routine importer for wger.",
    ),
    false,
  );
  assert.equal(usableGuide("Coming soon. ".repeat(10)), false);
  assert.equal(
    usableGuide(
      "Sit with your back supported and adjust the seat so the handles are at chest height. Push forward with control, then return without letting the weights slam.",
    ),
    true,
  );
  const records = [
    {
      id: "archived",
      name: "Unreviewed old movement",
      equipment: "Bodyweight",
    },
  ];
  assert.deepEqual(
    createCatalogView(records, {
      aliases: {},
      hidden: ["archived"],
      overrides: {},
    }),
    [],
  );
  assert.equal(records[0].id, "archived");
});

test("dangling aliases and cycles fail rather than silently discarding movements", () => {
  const rows = [
    { id: "a", name: "A" },
    { id: "b", name: "B" },
  ];
  assert.throws(
    () => createCatalogView(rows, { aliases: { a: "missing" } }),
    /Unknown/,
  );
  assert.throws(
    () => createCatalogView(rows, { aliases: { a: "b", b: "a" } }),
    /cycle/,
  );
});

test("every selectable exercise has an actual guide and correct source attribution", () => {
  for (const row of selectableExercises) {
    const guide = guideExercise(row.id);
    assert.ok(
      usableGuide(
        guide.source
          ? instructions[guide.instructionId ?? guide.id]
          : guide.description,
      ),
      row.id,
    );
    if (!guide.source && row.id.startsWith("forma-")) {
      assert.ok(guide.references.length > 0, row.id);
      for (const reference of guide.references)
        assert.equal(new URL(reference.url).protocol, "https:");
    }
  }
  assert.ok(
    selectableExercises.every(
      (row) => !curation.aliases[row.id] && !curation.hidden.includes(row.id),
    ),
  );
});

test("all historical IDs retain the same objects and backup measurements after deduplication", () => {
  for (const row of publishedExercises)
    assert.equal(exerciseById.get(row.id), row);
  const data = freshData();
  data.history = Object.keys(curation.aliases).map((id, index) => {
    const prescription = defaultPrescription(exerciseById.get(id));
    const { sets: unusedSets, ...measurement } = prescription;
    void unusedSets;
    return {
      id: `old-${index}`,
      name: "Existing workout",
      startedAt: 1000,
      date: "2026-10-13T00:00:00.000Z",
      duration: 60,
      exercises: [{ exerciseId: id, sets: [{ ...measurement, done: true }] }],
    };
  });
  const restored = parseBackup(JSON.stringify(data));
  assert.deepEqual(
    restored.history.map((x) => x.exercises),
    data.history.map((x) => x.exercises),
  );
  assert.equal(exerciseById.get("plank").metric, undefined);
  assert.equal(exerciseById.get("db-plank").metric, "duration");
});

test("every newly reviewed machine and timed identity validates through the shared API schema", () => {
  const additions = exercises.filter(
    (row) => !publishedExercises.includes(row),
  );
  assert.ok(additions.length >= 20);
  for (const row of additions) {
    const data = freshData();
    data.routines[0].exercises = [
      { exerciseId: row.id, ...defaultPrescription(row) },
    ];
    assert.equal(
      validateData(data).routines[0].exercises[0].exerciseId,
      row.id,
    );
  }
  const machineIds = selectableExercises
    .filter((row) => matchesEquipment(row, "Machine"))
    .map((row) => row.id);
  for (const id of [
    "forma-fan-bike",
    "forma-machine-torso-rotation",
    "forma-upper-body-ergometer",
    "forma-recumbent-stepper",
  ])
    assert.ok(machineIds.includes(id), id);
});

test("machine taxonomy never relabels barbell, elastic-band or butterfly floor variants", () => {
  const view = new Map(selectableExercises.map((row) => [row.id, row]));
  assert.equal(view.get("db-barbell-hack-squat").equipment, "Barbell");
  assert.equal(
    view.get("db-external-rotation-with-band").equipment,
    "Resistance band",
  );
  assert.equal(
    view.get("wger-ca514fad-c6ce-47b0-93a0-dc73a3507099").equipment,
    "Resistance band",
  );
  for (const id of [
    "wger-1bb3bbaf-2dc2-4651-95db-71faf5304075",
    "wger-df3a6900-55c1-435b-bcde-7510dc229b20",
    "wger-de06856d-109d-4bef-acab-0918028cea36",
  ])
    assert.equal(matchesEquipment(view.get(id), "Machine"), false);
});

test("barbell, band and butterfly floor movements are never classified as machines by their names", () => {
  for (const id of [
    "db-barbell-hack-squat",
    "wger-1bb3bbaf-2dc2-4651-95db-71faf5304075",
    "wger-df3a6900-55c1-435b-bcde-7510dc229b20",
    "wger-de06856d-109d-4bef-acab-0918028cea36",
  ]) {
    const row = selectableExercises.find((entry) => entry.id === id);
    assert.ok(row, id);
    assert.equal(matchesEquipment(row, "Machine"), false, id);
  }
  const band = guideExercise("wger-dc3a2072-abc3-4ef9-b8e6-f5ae6b11bc7f");
  assert.ok(matchesEquipment(band, "Resistance band"));
  assert.equal(matchesEquipment(band, "Cable"), false);
  assert.equal(band.name, "Band external rotation");
});
