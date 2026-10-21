// A routine entry saved before its hold moved to seconds keeps the rep ID, so
// its saved sets keep their meaning. These helpers let a member move such an
// entry onto the hold's timed identity on purpose; nothing switches silently,
// and history is never rewritten.
import curation from "./catalog/curation.json" with { type: "json" };
import { canonicalId } from "./catalog/curation.js";
import { exerciseById } from "./data.js";
import { tracksLoadReps } from "./exerciseMetrics.js";
import { entryKey } from "./routineProgramming.js";

// The legacy plank keeps its 10-second reps and has its own timer.
const LEGACY_PLANK = "plank";

// The timed row a rep-logged saved ID now resolves to, or null. Seconds-and-
// metres entries are left alone: they already log time, and switching would
// drop their distance.
export function timedVersion(exerciseId) {
  if (exerciseId === LEGACY_PLANK) return null;
  const saved = exerciseById.get(exerciseId);
  const timed = exerciseById.get(canonicalId(exerciseId, curation));
  return saved &&
    timed &&
    timed.id !== saved.id &&
    tracksLoadReps(saved) &&
    timed.metric === "duration"
    ? timed
    : null;
}

// The routine entry moved to its timed identity. Sets, load, RPE, rest, note,
// superset and position stay; the rep target becomes a seconds target, and
// per-side logging (which only applies to reps) is cleared. The old ID
// becomes the entry key, so the row keeps its place in the editor.
export function toTimedVersion(entry, durationSeconds = 60) {
  const timed = timedVersion(entry.exerciseId);
  if (!timed) return entry;
  return {
    ...entry,
    entryId: entryKey(entry),
    exerciseId: timed.id,
    reps: 1,
    repsMax: null,
    perSide: false,
    durationSeconds,
  };
}
