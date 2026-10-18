import process from "node:process";
import { fileURLToPath } from "node:url";
import { selectableExercises } from "../src/data.js";

const rules = [
  [/\bcable\b/i, /cable/i, "Cable"],
  [/\bbarbell\b/i, /barbell|olympic bar/i, "Barbell"],
  [/\bdumbbells?\b|\bdb\b/i, /dumbbell/i, "Dumbbell"],
  [/\bmachine\b/i, /machine|cable|smith|leverage|sled|station/i, "Machine"],
  [/\bkettlebells?\b/i, /kettlebell/i, "Kettlebell"],
  [/\bband(?:ed|s)?\b/i, /band/i, "Band"],
  [/\bsmith\b/i, /smith/i, "Smith machine"],
];
export function auditEquipment(records) {
  // The attributed guide specifies an EZ bar despite the historical Barbell title.
  const reviewedExceptions = new Set([
    "db-reverse-barbell-preacher-curls:Barbell",
  ]);
  return records.flatMap((exercise) =>
    rules
      .filter(
        ([name, equipment]) =>
          name.test(exercise.name) &&
          !equipment.test(
            [exercise.equipment, ...(exercise.equipmentTags ?? [])].join(" "),
          ),
      )
      .filter(
        ([, , expected]) =>
          !reviewedExceptions.has(`${exercise.id}:${expected}`),
      )
      .map(([, , expected]) => ({
        id: exercise.id,
        name: exercise.name,
        equipment: exercise.equipment,
        expected,
      })),
  );
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const findings = auditEquipment(selectableExercises);
  process.stdout.write(JSON.stringify(findings, null, 2) + "\n");
  if (process.argv.includes("--check") && findings.length) process.exitCode = 1;
}
