import { z } from "zod";
import { exercises, exerciseById, initialData, dateKey } from "./data.js";
import { validMeasurement } from "./exerciseMetrics.js";

export const STORAGE_KEY = "forma-v1";
export const MAX_BACKUP_BYTES = 20 * 1024 * 1024;
// Aggregate bounds keep validation cost predictable for the browser and the
// shared API validator. Ten years of daily training stays well inside them.
export const MAX_ROUTINES = 200;
export const MAX_HISTORY_SESSIONS = 10_000;
export const MAX_TOTAL_SETS = 150_000;
const number = z.number().finite();
const timestamp = number.min(0).max(8640000000000000);
const id = z.string().min(1).max(200);
const exerciseId = z.enum(exercises.map((exercise) => exercise.id));
const editableNumber = z.union([number, z.literal("")]);
const setSchema = z
  .object({
    weight: editableNumber,
    reps: editableNumber,
    done: z.boolean(),
    durationSeconds: z
      .union([number.min(0).max(86400), z.literal("")])
      .optional(),
    distanceMeters: z
      .union([number.min(0).max(1000000), z.literal("")])
      .optional(),
  })
  .refine(
    (set) =>
      !set.done ||
      (typeof set.weight === "number" &&
        set.weight >= 0 &&
        set.weight <= 1000 &&
        Number.isInteger(set.reps) &&
        set.reps >= 1 &&
        set.reps <= 100),
    "Completed sets require valid weight and repetitions.",
  );
const unique = (key) => (values) =>
  new Set(values.map((value) => value[key])).size === values.length;
const sessionSchema = z.object({
  id,
  name: z.string().trim().min(1).max(60),
  routineId: id.optional(),
  startedAt: timestamp,
  notes: z.string().max(10000).default(""),
  restSeconds: number.int().min(10).max(600).default(90),
  restEnd: timestamp.nullable().default(null),
  restPaused: number.min(0).max(600).nullable().default(null),
  exercises: z
    .array(
      z
        .object({ exerciseId, sets: z.array(setSchema).min(1).max(100) })
        .superRefine((entry, context) => {
          const exercise = exerciseById.get(entry.exerciseId);
          entry.sets.forEach((set, index) => {
            if (set.done && !validMeasurement(exercise, set))
              context.addIssue({
                code: "custom",
                message: "Completed sets require valid exercise measurements.",
                path: ["sets", index],
              });
          });
        }),
    )
    .min(1)
    .max(100)
    .refine(unique("exerciseId"), "Duplicate exercise"),
});
const routineSchema = z.object({
  id,
  name: z.string().trim().min(1).max(60),
  description: z.string().max(500),
  minutes: number.int().positive().max(1000),
  level: z.string().min(1).max(50),
  image: number.int().min(0).max(2),
  exercises: z
    .array(
      z
        .object({
          exerciseId,
          sets: number.int().min(1).max(12),
          reps: number.int().min(1).max(100),
          weight: number.min(0).max(1000),
          durationSeconds: number.positive().max(86400).optional(),
          distanceMeters: number.positive().max(1000000).optional(),
        })
        .refine(
          (item) => validMeasurement(exerciseById.get(item.exerciseId), item),
          "Routine targets require valid exercise measurements.",
        ),
    )
    .min(1)
    .max(100)
    .refine(unique("exerciseId"), "Duplicate exercise"),
});
export const dataSchema = z.object({
  version: z.literal(1),
  revision: number.int().nonnegative().default(0),
  routines: z
    .array(routineSchema)
    .max(MAX_ROUTINES)
    .refine(unique("id"), "Duplicate routine"),
  history: z
    .array(
      sessionSchema
        .extend({
          date: z.string().datetime(),
          duration: number.min(0).max(Number.MAX_SAFE_INTEGER),
        })
        .refine(
          (session) =>
            session.exercises.some((entry) =>
              entry.sets.some((set) => set.done),
            ),
          "A completed workout must contain at least one completed set.",
        ),
    )
    .refine(unique("id"), "Duplicate session"),
  active: sessionSchema.nullable(),
  profile: z.object({
    name: z.string().trim().min(1).max(50),
    goal: number.int().min(1).max(7),
  }),
  schedule: z
    .array(number.int().min(0).max(6))
    .max(7)
    .refine((days) => new Set(days).size === days.length),
});
function assertBounded(value) {
  // Count before zod parses each set: an aggregate refine would only run after
  // the expensive per-set work it is meant to prevent.
  if (!value || typeof value !== "object") return;
  const { routines, history, active } = value;
  if (Array.isArray(routines) && routines.length > MAX_ROUTINES)
    throw new Error(`A workspace can hold at most ${MAX_ROUTINES} routines.`);
  if (!Array.isArray(history)) return;
  if (history.length > MAX_HISTORY_SESSIONS)
    throw new Error(
      `A workspace can hold at most ${MAX_HISTORY_SESSIONS} workouts.`,
    );
  let sets = 0;
  for (const session of [...history, active]) {
    if (!session || !Array.isArray(session.exercises)) continue;
    for (const entry of session.exercises)
      if (entry && Array.isArray(entry.sets)) sets += entry.sets.length;
    if (sets > MAX_TOTAL_SETS)
      throw new Error(`A workspace can hold at most ${MAX_TOTAL_SETS} sets.`);
  }
}
export function validateData(value) {
  assertBounded(value);
  const data = dataSchema.parse(value);
  if (
    data.active &&
    data.history.some((session) => session.id === data.active.id)
  )
    throw new Error("The active workout is already present in history.");
  return data;
}
// Records which member imported this browser's guest data, so a shared
// browser does not offer one person's local training to every account.
export const LEGACY_MIGRATION_KEY = "forma-v1-migrated";
export function legacyFingerprint(raw) {
  let hash = 0;
  for (let index = 0; index < raw.length; index += 1)
    hash = (Math.imul(hash, 31) + raw.charCodeAt(index)) | 0;
  return `${raw.length}:${hash >>> 0}`;
}
export function readLegacyMigration() {
  try {
    const value = JSON.parse(localStorage.getItem(LEGACY_MIGRATION_KEY));
    return typeof value?.member === "string" &&
      typeof value?.fingerprint === "string"
      ? value
      : null;
  } catch {
    return null;
  }
}
export function markLegacyMigrated(member, fingerprint) {
  try {
    localStorage.setItem(
      LEGACY_MIGRATION_KEY,
      JSON.stringify({ member, fingerprint }),
    );
  } catch {
    // Storage may be unavailable; the import itself already succeeded.
  }
}
export function freshData() {
  return validateData(structuredClone(initialData));
}
export function parseBackup(raw) {
  if (raw.length > MAX_BACKUP_BYTES || new Blob([raw]).size > MAX_BACKUP_BYTES)
    throw new Error("Choose a FORMA backup no larger than 20 MiB.");
  return validateData(JSON.parse(raw));
}
export async function readBackupFile(file) {
  if (file.size > MAX_BACKUP_BYTES)
    throw new Error("Choose a FORMA backup no larger than 20 MiB.");
  return parseBackup(await file.text());
}
export function readStore() {
  let raw;
  try {
    raw = localStorage.getItem(STORAGE_KEY);
  } catch {
    return { data: freshData(), issue: "unavailable", raw: null };
  }
  if (raw === null) return { data: freshData(), issue: null, raw: null };
  try {
    return { data: parseBackup(raw), issue: null, raw };
  } catch {
    return { data: null, issue: "invalid", raw };
  }
}
export function downloadData(
  value,
  name = "forma-backup",
  raw = false,
  pretty = true,
) {
  const blob = new Blob(
    [raw ? value : JSON.stringify(value, null, pretty ? 2 : 0)],
    {
      type: raw ? "text/plain" : "application/json",
    },
  );
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${name}-${dateKey()}.${raw ? "txt" : "json"}`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
