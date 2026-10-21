// How the app shows an exercise's load and whether it offers a hold timer.
// Display only: stored sets keep their `weight` (0 when nothing is added), so
// the shared validator in exerciseMetrics.js and the API are unchanged. The
// decisions come from src/catalog/logging-review.json, which covers every
// selectable exercise.
import review from "./catalog/logging-review.json" with { type: "json" };
import curation from "./catalog/curation.json" with { type: "json" };
import { canonicalId } from "./catalog/curation.js";
import {
  logsSides,
  measurementText,
  metricFields,
  setFields,
} from "./exerciseMetrics.js";

const none = new Set(review.none);
const added = new Set(review.added);
const noTimer = new Set(review.noTimer);
const resolve = (exercise) =>
  exercise?.id ? canonicalId(exercise.id, curation) : undefined;

// "load": an implement whose kg is logged; "added": bodyweight with optional
// added kg (dip belt, vest); "none": no external load to log.
export function loadType(exercise) {
  const id = resolve(exercise);
  if (none.has(id)) return "none";
  return added.has(id) ? "added" : "load";
}

const carriesLoad = (sets = []) => sets.some((set) => Number(set?.weight) > 0);

// The logging columns to show. A "none" exercise drops the weight column,
// unless one of these sets already carries weight: an older log stays visible
// instead of being hidden.
export function visibleFields(exercise, entry, sets = entry?.sets) {
  const type = loadType(exercise);
  return setFields(exercise, entry)
    .filter(
      (field) => field.key !== "weight" || type !== "none" || carriesLoad(sets),
    )
    .map((field) =>
      field.key === "weight" && type === "added"
        ? { ...field, label: "ADDED (KG)" }
        : field,
    );
}

// A logged set as text, without "0 kg" for exercises that carry no load.
export function loggedText(exercise, set) {
  const type = loadType(exercise);
  const weight = Number(set.weight) || 0;
  const metric = exercise?.metric ?? "load_reps";
  if (
    type === "load" ||
    (type === "none" && weight > 0) ||
    metric === "duration_distance" ||
    metric === "load_distance"
  )
    return measurementText(exercise, set);
  const extra = weight > 0 ? `+${weight} kg` : "";
  if (metric === "duration")
    return `${set.durationSeconds} sec${extra ? ` · ${extra}` : ""}`;
  const reps = set.sides
    ? `${set.sides.left} L / ${set.sides.right} R`
    : `${set.reps} reps`;
  return extra ? `${extra} × ${reps}` : reps;
}

// The legacy starter plank keeps its original units: each rep is a 10-second
// hold, so its timer logs one rep per full 10 seconds.
const LEGACY_PLANK = "plank";

// Timed exercises (planks, holds, timed intervals) get a countdown that logs
// the set; repetition and distance work does not. The legacy plank has none
// while it logs each side, as the timer writes a single rep count.
export const usesHoldTimer = (exercise, entry) =>
  exercise?.id === LEGACY_PLANK
    ? !logsSides(exercise, entry)
    : exercise?.metric === "duration" && !noTimer.has(resolve(exercise));

// The set field a hold timer writes, how many seconds make one unit of it,
// and the longest hold that field can record (100 legacy plank reps).
export function holdUnit(exercise) {
  const legacy = exercise?.id === LEGACY_PLANK;
  const key = legacy ? "reps" : "durationSeconds";
  const seconds = legacy ? 10 : 1;
  const limit = metricFields(exercise).find((f) => f.key === key)?.max ?? 0;
  return { key, seconds, max: limit * seconds };
}
