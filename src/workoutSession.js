import { createId, exerciseById } from "./data.js";
import {
  applySetValue,
  defaultPrescription,
  logsSides,
  readSetValue,
} from "./exerciseMetrics.js";
import { entryKey, normalizeGroups } from "./routineProgramming.js";

// One session entry built from a routine prescription. Unilateral load/rep
// entries log each side, so every planned set starts with the target per side.
export function sessionEntry(item, { entryId } = {}) {
  const exercise = exerciseById.get(item.exerciseId);
  const sides = logsSides(exercise, item);
  return {
    exerciseId: item.exerciseId,
    ...((entryId ?? item.entryId) ? { entryId: entryId ?? item.entryId } : {}),
    targetReps: item.reps,
    repsMax: item.repsMax ?? null,
    rpe: item.rpe ?? null,
    restSeconds: item.restSeconds ?? null,
    perSide: item.perSide ?? false,
    note: item.note ?? null,
    groupId: item.groupId ?? null,
    sets: Array.from({ length: item.sets }, () => ({
      weight: item.weight,
      reps: sides ? item.reps * 2 : item.reps,
      ...(sides ? { sides: { left: item.reps, right: item.reps } } : {}),
      ...(item.durationSeconds === undefined
        ? {}
        : { durationSeconds: item.durationSeconds }),
      ...(item.distanceMeters === undefined
        ? {}
        : { distanceMeters: item.distanceMeters }),
      done: false,
    })),
  };
}

// An exercise added while a workout is running. A fresh entry ID keeps the
// row unique even when the same exercise already appears in the session.
export function addedEntry(exercise) {
  return sessionEntry(
    { exerciseId: exercise.id, ...defaultPrescription(exercise) },
    { entryId: createId() },
  );
}

// One logged value changed on one set. With `fill`, later unfinished sets
// that still show this set's previous value follow it, so a lifter types a
// weight once; a set already changed on purpose keeps its own value.
export function updateSetValue(
  entry,
  index,
  key,
  value,
  { fill = false } = {},
) {
  const previous = readSetValue(entry.sets[index], key);
  return {
    ...entry,
    sets: entry.sets.map((set, position) => {
      if (position === index)
        return set.done ? set : applySetValue(set, key, value);
      if (!fill || position < index || set.done) return set;
      return readSetValue(set, key) === previous
        ? applySetValue(set, key, value)
        : set;
    }),
  };
}

// Session entries after one is moved by `direction` (-1 up, 1 down).
export function moveEntry(entries, key, direction) {
  const from = entries.findIndex((entry) => entryKey(entry) === key);
  const to = from + direction;
  if (from < 0 || to < 0 || to >= entries.length) return entries;
  const next = [...entries];
  [next[from], next[to]] = [next[to], next[from]];
  return normalizeGroups(next);
}

export function removeEntry(entries, key) {
  if (entries.length <= 1) return entries;
  return normalizeGroups(entries.filter((entry) => entryKey(entry) !== key));
}
