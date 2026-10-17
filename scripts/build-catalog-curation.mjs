import { readFile, writeFile } from "node:fs/promises";
import { format } from "prettier";
import { URL } from "node:url";
import { log } from "node:console";
import { publishedExercises } from "../src/data.js";
import {
  canonicalId,
  createCatalogView,
  usableGuide,
} from "../src/catalog/curation.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };

const root = new URL("../", import.meta.url);
const read = async (name) =>
  JSON.parse(await readFile(new URL(name, root), "utf8"));
const review = await read("docs/research/exercise-quality-review.json");
const machines = await read("docs/research/machine-coverage.json");
const originals = await read("docs/research/reviewed-machine-additions.json");
const repairs = await read("docs/research/reviewed-guide-repairs.json");
const byId = new Map(publishedExercises.map((row) => [row.id, row]));
const policy = { version: 1, aliases: {}, hidden: [], overrides: {} };
const edit = (id, value) => {
  policy.overrides[id] = { ...policy.overrides[id], ...value };
};
for (const group of review.groups) {
  if (!byId.has(group.canonicalId)) throw new Error("Unknown canonical ID");
  for (const id of group.duplicateIds) {
    if (!byId.has(id) || policy.aliases[id])
      throw new Error("Unknown or overlapping duplicate ID");
    policy.aliases[id] = group.canonicalId;
  }
  const patch = { name: group.canonicalName, equipment: group.equipment };
  if (group.guideInstructionId !== group.canonicalId) {
    patch.instructionId = group.guideInstructionId;
    patch.source = group.guideSource;
    patch.description = instructions[group.guideInstructionId].slice(0, 360);
  }
  edit(group.canonicalId, patch);
}
// Preserve historical ten-second-per-rep plank data; offer the timed ID for new selections.
policy.aliases.plank = "db-plank";
policy.aliases["wger-e6bf0364-ccce-4053-afe1-eef206a50291"] = "pulldown";
edit("db-air-bike", { name: "Bicycle crunch", category: "strength" });
const additions = originals.map((row) => ({
  ...row,
  description: row.instructions,
  equipment: row.equipmentFamilyName,
}));
for (const correction of review.measurementCorrections) {
  const original = byId.get(correction.existingId),
    guide = byId.get(correction.guideInstructionId);
  if (!original || !guide || !usableGuide(instructions[guide.id]))
    throw new Error("No usable attributed correction guide");
  additions.push({
    ...original,
    ...policy.overrides[original.id],
    id: correction.replacementId,
    name: correction.name,
    metric: correction.to,
    weight: 0,
    source: guide.source,
    instructionId: guide.id,
    description: instructions[guide.id].slice(0, 360),
  });
  for (const id of correction.aliasIds)
    policy.aliases[id] = correction.replacementId;
}
// Reviewed identical-unit programming aliases, also used by the v2 data migration.
for (const [id, correction] of Object.entries(
  await read("src/catalog/equipment-corrections.json"),
))
  edit(id, correction);
const records = [...publishedExercises, ...additions];
const recordById = new Map(records.map((row) => [row.id, row]));
for (const correction of machines.equipmentMetadataCorrections) {
  const id = canonicalId(correction.exerciseId, policy);
  // A guide-reviewed group takes precedence over name-based audit suggestions.
  if (!policy.overrides[id]?.equipment)
    edit(id, { equipment: correction.suggestedEquipment });
}
for (const [id, repair] of Object.entries(repairs))
  edit(canonicalId(id, policy), repair);
Object.assign(
  policy.aliases,
  await read("src/catalog/programming-aliases.json"),
);
// Specific station names augment broad Machine/Cable filters. They do not merge identities.
const stationNames = [
  ["smith", "Smith machine"],
  ["pendulum", "Pendulum squat machine"],
  ["belt squat", "Belt squat machine"],
  ["glute drive", "Glute drive machine"],
  ["v-squat", "V-squat machine"],
  ["hack squat", "Hack squat machine"],
  ["hackenschmitt", "Hack squat machine"],
  ["leg press", "Leg press machine"],
  ["leg extension", "Leg extension machine"],
  ["leg curl", "Leg curl machine"],
  ["thigh abductor", "Hip abduction machine"],
  ["thigh adductor", "Hip adduction machine"],
  ["pec deck", "Pec deck machine"],
  ["butterfly", "Pec deck machine"],
  ["machine preacher", "Preacher curl machine"],
  ["preacher curl machine", "Preacher curl machine"],
  ["machine bicep", "Biceps curl machine"],
  ["biceps curl machine", "Biceps curl machine"],
  ["machine bench", "Chest press machine"],
  ["machine chest", "Chest press machine"],
  ["machine shoulder", "Shoulder press machine"],
  ["machine lateral", "Lateral raise machine"],
  ["machine side lateral", "Lateral raise machine"],
  ["reverse machine fly", "Rear delt machine"],
];
for (const row of createCatalogView(records, policy)) {
  const name = row.name.toLowerCase();
  const machine =
    row.equipment.toLowerCase().includes("machine") ||
    name.includes("smith machine");
  const station = machine
    ? stationNames.find(([phrase]) => name.includes(phrase))
    : undefined;
  const cable =
    row.equipment === "Cable" ||
    (name.includes("cable") && !row.equipment.includes("Resistance band"));
  const equipment = cable ? "Cable" : (station?.[1] ?? row.equipment);
  const tags = row.equipmentTags.filter(
    (tag) => tag !== "Bodyweight" || equipment === "Bodyweight",
  );
  if (station || cable) tags.push("Machine", equipment);
  if (equipment !== row.equipment || station || cable)
    edit(row.id, {
      equipment,
      equipmentTags: [
        ...new Set(
          tags.filter((tag) => tag !== row.equipment).concat(equipment),
        ),
      ],
    });
}
for (const row of createCatalogView(records, policy)) {
  const guide = row.source
    ? instructions[row.instructionId ?? row.id]
    : row.description;
  if (!usableGuide(guide)) policy.hidden.push(row.id);
}
const visible = createCatalogView(records, policy);
for (const id of Object.keys(policy.overrides))
  if (!recordById.has(id)) throw new Error("Unknown override");
const summary = {
  reviewedAt: "2026-10-14",
  compatibilityRecords: records.length,
  originalIdsPreserved: publishedExercises.length,
  selectableMovements: visible.length,
  reviewedDuplicateGroups: review.groups.length,
  aliasRecords: Object.keys(policy.aliases).length,
  hiddenUnreviewedGuides: policy.hidden.length,
  authoredMachineAdditions: originals.length,
  authoredGuideRepairs: Object.keys(repairs).length,
  newMeasurementIdentities: review.measurementCorrections.length,
  metadataOverrides: Object.keys(policy.overrides).length,
  originalEquipmentFamiliesReviewed: machines.families.length,
};
const save = async (name, value) =>
  writeFile(
    new URL(name, root),
    await format(JSON.stringify(value), { parser: "json" }),
  );
await save("src/catalog/machine-exercises.json", additions);
await save("src/catalog/curation.json", policy);
await save("docs/research/catalog-quality-summary.json", summary);
log(JSON.stringify(summary));
