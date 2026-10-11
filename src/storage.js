import { z } from "zod";
import { exercises, initialData, dateKey } from "./data";

export const STORAGE_KEY = "forma-v1";
const number = z.number().finite();
const id = z.string().min(1).max(200);
const exerciseId = z.enum(exercises.map((exercise) => exercise.id));
const editableNumber = z.union([number, z.literal("")]);
const setSchema = z
  .object({ weight: editableNumber, reps: editableNumber, done: z.boolean() })
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
  startedAt: number.nonnegative(),
  notes: z.string().max(10000).default(""),
  restSeconds: number.int().min(10).max(600).default(90),
  restEnd: number.nonnegative().nullable().default(null),
  restPaused: number.min(0).max(600).nullable().default(null),
  exercises: z
    .array(z.object({ exerciseId, sets: z.array(setSchema).min(1).max(100) }))
    .min(1)
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
      z.object({
        exerciseId,
        sets: number.int().min(1).max(12),
        reps: number.int().min(1).max(100),
        weight: number.min(0).max(1000),
      }),
    )
    .min(1)
    .refine(unique("exerciseId"), "Duplicate exercise"),
});
export const dataSchema = z.object({
  version: z.literal(1),
  revision: number.int().nonnegative().default(0),
  routines: z.array(routineSchema).refine(unique("id"), "Duplicate routine"),
  history: z
    .array(
      sessionSchema.extend({
        date: z.string().datetime(),
        duration: number.nonnegative(),
      }),
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
export function validateData(value) {
  return dataSchema.parse(value);
}
export function freshData() {
  return validateData(structuredClone(initialData));
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
    return { data: validateData(JSON.parse(raw)), issue: null, raw };
  } catch {
    return { data: null, issue: "invalid", raw };
  }
}
export function downloadData(value, name = "forma-backup", raw = false) {
  const blob = new Blob([raw ? value : JSON.stringify(value, null, 2)], {
    type: raw ? "text/plain" : "application/json",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${name}-${dateKey()}.${raw ? "txt" : "json"}`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
