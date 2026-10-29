// Read synthetic output from FORMAContractProbe and validate actual Swift JSON
// with the authoritative web/server contract. No member records are needed.
import { readFile } from "node:fs/promises";
import { log } from "node:console";
import process from "node:process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { exerciseById } from "../src/data.js";
import { defaultPrescription, tracksLoadReps } from "../src/exerciseMetrics.js";
import { validateData } from "../src/storage.js";
import { sessionEntry } from "../src/workoutSession.js";

function measurementEvidence(entry, exercise) {
  const setFields = [
    "weight",
    "reps",
    "sides",
    "durationSeconds",
    "distanceMeters",
    "rpe",
    "legacyDraft",
    "done",
  ];
  return {
    targetReps: entry.targetReps ?? null,
    // Non-repetition rows may retain an inert catalogue perSide flag. Only
    // load/repetition entries use it to determine their logged side units.
    perSide: tracksLoadReps(exercise) && entry.perSide === true,
    repsMax: entry.repsMax ?? null,
    rpe: entry.rpe ?? null,
    restSeconds: entry.restSeconds ?? null,
    note: entry.note ?? null,
    groupId: entry.groupId ?? null,
    sets: entry.sets.map((set) =>
      Object.fromEntries(setFields.map((key) => [key, set[key] ?? null])),
    ),
  };
}

export function checkNativeContracts(probe) {
  if (probe?.synthetic !== true || !Array.isArray(probe.cases))
    throw new Error("Choose synthetic FORMAContractProbe output.");
  const expected = new Set(exerciseById.keys());
  const seen = new Set();
  for (const row of probe.cases) {
    if (!expected.has(row.id) || seen.has(row.id))
      throw new Error("Native contract cases have an unknown or duplicate ID.");
    seen.add(row.id);
    const parsed = validateData(row.workspace, { strict: true });
    if (
      row.workspace.active !== null ||
      row.workspace.history.length !== 1 ||
      row.workspace.history[0].exercises.length !== 1 ||
      row.workspace.history[0].exercises[0].exerciseId !== row.id ||
      row.workspace.history[0].exercises[0].sets[0]?.done !== true
    )
      throw new Error(`Native case ${row.id} did not finish its own workout.`);
    const exercise = exerciseById.get(row.id);
    const reference = sessionEntry({
      exerciseId: row.id,
      ...defaultPrescription(exercise),
    });
    reference.sets[0].done = true;
    if (
      !isDeepStrictEqual(
        measurementEvidence(parsed.history[0].exercises[0], exercise),
        measurementEvidence(reference, exercise),
      )
    ) {
      throw new Error(
        `Native case ${row.id} changed its published default measurements or set completion.`,
      );
    }
  }
  if (seen.size !== expected.size)
    throw new Error("Native contract output does not cover every accepted ID.");
  return seen.size;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const path = process.argv[2];
  if (!path)
    throw new Error("Usage: node scripts/check-ios-contracts.mjs PROBE_JSON");
  const count = checkNativeContracts(JSON.parse(await readFile(path, "utf8")));
  log(
    `Verified ${count} actual Swift-generated workouts against strict workspace validation.`,
  );
}
