import { createId, exerciseById } from "./data.js";
import {
  applySetValue,
  defaultPrescription,
  logsSides,
  readSetValue,
  setFields,
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

const loggedKeys = (entry) =>
  setFields(exerciseById.get(entry.exerciseId), entry)
    .map((field) => field.key)
    .join(",");

/**
 * Swap one exercise for another in place. When both log the same fields
 * (say, weight and reps), every set, done or not, moves to the new exercise;
 * otherwise the new exercise starts with the same number of fresh sets.
 * Position, superset and rest stay with the slot.
 */
export function replaceEntry(entries, key, exercise) {
  const index = entries.findIndex((entry) => entryKey(entry) === key);
  if (index < 0) return entries;
  const previous = entries[index];
  const fresh = addedEntry(exercise);
  const keep = loggedKeys(previous) === loggedKeys(fresh);
  const next = {
    ...fresh,
    groupId: previous.groupId ?? null,
    restSeconds: previous.restSeconds ?? null,
    sets: keep
      ? previous.sets
      : previous.sets.map(() => ({ ...fresh.sets[0] })),
  };
  return entries.map((entry, position) => (position === index ? next : entry));
}

/** Completed sets that replacing this entry with `exercise` would discard. */
export function setsLostByReplacing(entry, exercise) {
  const fresh = addedEntry(exercise);
  return loggedKeys(entry) === loggedKeys(fresh)
    ? 0
    : entry.sets.filter((set) => set.done).length;
}
