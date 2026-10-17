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
  return metricFields(exercise).every(
    (f) =>
      typeof set[f.key] === "number" &&
      Number.isFinite(set[f.key]) &&
      set[f.key] >= f.min &&
      set[f.key] <= f.max &&
      (f.step !== 1 || Number.isInteger(set[f.key])),
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
      return `${set.weight} kg × ${set.reps}`;
  }
}
export const tracksLoadReps = (exercise) =>
  !exercise?.metric || exercise.metric === "load_reps";
