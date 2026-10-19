import aliases from "./catalog/programming-aliases.json" with { type: "json" };

export const entryKey = (entry) => entry.entryId ?? entry.exerciseId;
export const isArchived = (routine) => routine.archivedAt !== undefined;
export function parseRepRange(value) {
  const match = /^\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?\s*$/.exec(String(value));
  const reps = Number(match?.[1]);
  const max = Number(match?.[2] ?? match?.[1]);
  if (!match || reps < 1 || max > 100 || reps > max)
    throw new Error("Use reps from 1–100, such as 10 or 8–10.");
  return { reps, repsMax: max > reps ? max : null };
}
export const repRangeText = (entry) =>
  entry.repsMax > entry.reps
    ? `${entry.reps}–${entry.repsMax}`
    : `${entry.reps}`;
export function sideLabel(exercise) {
  if (exercise?.side) return exercise.side;
  return exercise?.muscle === "Legs" ||
    /lunge|split squat|single.leg|calf|step.up/i.test(exercise?.name ?? "")
    ? "leg"
    : "arm";
}
// Reviewed unilateral catalogue entries (`side`) default to per-side logging;
// the name test keeps custom or unreviewed rows sensible.
export function defaultPerSide(exercise) {
  return (
    exercise?.side !== undefined ||
    /\b(lunge|lunges|split squat|single.arm|one.arm|single.leg|one.leg|bulgarian)\b/i.test(
      exercise?.name ?? "",
    )
  );
}
export const repsText = (entry, exercise) =>
  `${repRangeText(entry)}${entry.perSide ? ` / ${sideLabel(exercise)}` : " reps"}`;

// Only reviewed identical-unit incline synonyms migrate; timed aliases retain units.
export function migrateProgramming(data) {
  const migrateEntries = (entries) => {
    const migrated = entries.map((entry) => ({
      ...entry,
      exerciseId: aliases[entry.exerciseId] ?? entry.exerciseId,
    }));
    const counts = new Map();
    for (const entry of migrated)
      counts.set(entry.exerciseId, (counts.get(entry.exerciseId) ?? 0) + 1);
    return migrated.map((entry, index) =>
      (counts.get(entry.exerciseId) > 1 &&
        entry.exerciseId !== entries[index].exerciseId) ||
      (counts.get(entry.exerciseId) > 1 &&
        entries.some(
          (original) => aliases[original.exerciseId] === entry.exerciseId,
        ))
        ? {
            exerciseId: entry.exerciseId,
            entryId:
              entry.entryId ?? `legacy-${index}-${entries[index].exerciseId}`,
            ...entry,
          }
        : entry,
    );
  };
  return {
    ...data,
    version: 2,
    routines: data.routines.map((r) => ({
      ...r,
      exercises: migrateEntries(r.exercises),
    })),
    history: data.history.map((s) => ({
      ...s,
      exercises: migrateEntries(s.exercises),
    })),
    active: data.active
      ? { ...data.active, exercises: migrateEntries(data.active.exercises) }
      : null,
  };
}
export function validGroups(entries) {
  const groups = new Map();
  entries.forEach((entry, index) => {
    if (entry.groupId)
      groups.set(entry.groupId, [...(groups.get(entry.groupId) ?? []), index]);
  });
  return [...groups.values()].every(
    (indices) =>
      indices.length >= 2 && indices.at(-1) - indices[0] + 1 === indices.length,
  );
}
export function normalizeGroups(entries) {
  const invalid = new Set(
    entries
      .map((e) => e.groupId)
      .filter(Boolean)
      .filter((group) => {
        const positions = entries.flatMap((e, index) =>
          e.groupId === group ? [index] : [],
        );
        return (
          positions.length < 2 ||
          positions.at(-1) - positions[0] + 1 !== positions.length
        );
      }),
  );
  return entries.map((entry) =>
    invalid.has(entry.groupId) ? { ...entry, groupId: null } : entry,
  );
}
export function groupLabels(entries) {
  const groups = [...new Set(entries.map((e) => e.groupId).filter(Boolean))];
  return entries.map((entry, index) =>
    entry.groupId
      ? `${String.fromCharCode(65 + groups.indexOf(entry.groupId))}${entries.slice(0, index + 1).filter((e) => e.groupId === entry.groupId).length}`
      : String(index + 1).padStart(2, "0"),
  );
}
export const shouldRest = (entries, index) =>
  !entries[index].groupId ||
  entries[index + 1]?.groupId !== entries[index].groupId;
export function restRemaining(session, now = Date.now()) {
  return session.restEnd
    ? Math.max(0, Math.ceil((session.restEnd - now) / 1000))
    : (session.restPaused ?? 0);
}
export function adjustRest(session, delta, now = Date.now()) {
  const seconds = Math.min(
    600,
    Math.max(0, restRemaining(session, now) + delta),
  );
  return session.restEnd
    ? {
        ...session,
        restEnd: seconds ? now + seconds * 1000 : null,
        restPaused: null,
      }
    : { ...session, restEnd: null, restPaused: seconds || null };
}

export function toggleRest(session, now = Date.now()) {
  return session.restEnd
    ? {
        ...session,
        restEnd: null,
        restPaused: Math.min(600, restRemaining(session, now)),
      }
    : {
        ...session,
        restEnd: now + (session.restPaused || session.restSeconds || 90) * 1000,
        restPaused: null,
      };
}
