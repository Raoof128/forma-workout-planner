import { estimatedOneRM, exercises } from "./data.js";
import { sideReps, tracksLoadReps } from "./exerciseMetrics.js";

const strengthExercises = exercises.filter(tracksLoadReps);
const strengthIds = new Set(strengthExercises.map((exercise) => exercise.id));

// Aggregate saved identities once; aliases keep their own records and the
// catalogue still determines display order.
export function progressRecords(history) {
  const totals = new Map();
  for (const session of history) {
    for (const entry of session.exercises) {
      if (!strengthIds.has(entry.exerciseId)) continue;
      for (const set of entry.sets) {
        if (!set.done) continue;
        let record = totals.get(entry.exerciseId);
        if (!record) {
          record = { maxWeight: 0, oneRM: 0, sets: 0 };
          totals.set(entry.exerciseId, record);
        }
        record.maxWeight = Math.max(record.maxWeight, set.weight);
        const reps = sideReps(set);
        if (reps <= 12)
          record.oneRM = Math.max(
            record.oneRM,
            estimatedOneRM(set.weight, reps),
          );
        record.sets += 1;
      }
    }
  }
  return strengthExercises
    .filter((exercise) => totals.has(exercise.id))
    .map((exercise) => ({ ...exercise, ...totals.get(exercise.id) }));
}
