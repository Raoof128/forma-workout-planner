import { defaultPerSide } from "./routineProgramming.js";
const field = (key, label, max, min = 0, step = "any") => ({
  key,
  label,
  max,
  min,
  step,
});
const weight = field("weight", "WEIGHT (KG)", 1000);
const reps = field("reps", "REPS", 100, 1, 1);
// Each side of a unilateral set; the two together stay within the 100-rep bound.
export const SIDE_KEYS = ["left", "right"];
const sideFields = [
  { ...field("left", "LEFT", 50, 1, 1), side: true },
  { ...field("right", "RIGHT", 50, 1, 1), side: true },
];
const seconds = field("durationSeconds", "TIME (SECONDS)", 86400, 1);
const distance = field("distanceMeters", "DISTANCE (METERS)", 1000000, 1);
export function metricFields(exercise) {
  switch (exercise?.metric) {
    case "duration":
      return [seconds, weight];
    case "duration_distance":
      return [seconds, distance];
    case "load_distance":
      return [weight, distance];
    default:
      return [weight, reps];
  }
}
// Logging columns for one session entry: unilateral load/rep entries log
// each side instead of a single rep count.
export const logsSides = (exercise, entry) =>
  entry?.perSide === true && tracksLoadReps(exercise);
export function setFields(exercise, entry) {
  return logsSides(exercise, entry)
    ? [weight, ...sideFields]
    : metricFields(exercise);
}
export const readSetValue = (set, key) =>
  SIDE_KEYS.includes(key) ? (set.sides?.[key] ?? "") : (set[key] ?? "");
// Returns the set with one logged value changed. A side value also refreshes
// the total rep count so volume and validation keep using `reps`.
export function applySetValue(set, key, value) {
  if (!SIDE_KEYS.includes(key)) return { ...set, [key]: value };
  const sides = { left: "", right: "", ...set.sides, [key]: value };
  return {
    ...set,
    sides,
    reps:
      Number.isInteger(sides.left) && Number.isInteger(sides.right)
        ? sides.left + sides.right
        : "",
  };
}
export const validSides = (set) =>
  !set.sides ||
  (Number.isInteger(set.sides.left) &&
    Number.isInteger(set.sides.right) &&
    set.reps === set.sides.left + set.sides.right);
export function defaultPrescription(exercise) {
  const fields = metricFields(exercise);
  return {
    perSide: defaultPerSide(exercise),
    sets: exercise?.metric === "duration_distance" ? 1 : 3,
    reps: exercise?.metric && exercise.metric !== "load_reps" ? 1 : 10,
    weight: exercise?.weight ?? 0,
    ...(fields.some((f) => f.key === "durationSeconds")
      ? { durationSeconds: 60 }
      : {}),
    ...(fields.some((f) => f.key === "distanceMeters")
      ? { distanceMeters: 100 }
      : {}),
  };
}
export function validMeasurement(exercise, set) {
  return (
    validSides(set) &&
    metricFields(exercise).every(
      (f) =>
        typeof set[f.key] === "number" &&
        Number.isFinite(set[f.key]) &&
        set[f.key] >= f.min &&
        set[f.key] <= f.max &&
        (f.step !== 1 || Number.isInteger(set[f.key])),
    )
  );
}
export function measurementText(exercise, set) {
  switch (exercise?.metric) {
    case "duration":
      return `${set.durationSeconds} sec${set.weight > 0 ? ` · ${set.weight} kg` : ""}`;
    case "duration_distance":
      return `${set.durationSeconds} sec · ${set.distanceMeters} m`;
    case "load_distance":
      return `${set.weight} kg · ${set.distanceMeters} m`;
    default:
      return set.sides
        ? `${set.weight} kg × ${set.sides.left} L / ${set.sides.right} R`
        : `${set.weight} kg × ${set.reps}`;
  }
}
// Reps performed by one side: the basis for strength estimates on unilateral sets.
export const sideReps = (set) =>
  set.sides ? Math.max(set.sides.left, set.sides.right) : set.reps;
export const tracksLoadReps = (exercise) =>
  !exercise?.metric || exercise.metric === "load_reps";
