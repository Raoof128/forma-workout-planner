const folded = (value) =>
  value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");

const searchText = new WeakMap();
let previousQuery = "";
let previousWords = [];

export function matchesExercise(exercise, query) {
  if (query !== previousQuery) {
    previousWords = query.trim().split(/\s+/).map(folded).filter(Boolean);
    previousQuery = query;
  }
  if (!previousWords.length) return true;

  const source = [
    exercise.name,
    exercise.muscle,
    exercise.equipment,
    exercise.category,
    ...(exercise.equipmentTags ?? []),
    ...(exercise.aliases ?? []),
    ...(exercise.primaryMuscles ?? []),
    ...(exercise.secondaryMuscles ?? []),
  ]
    .filter(Boolean)
    .join(" ");
  // Compare the source so edits to records or their arrays invalidate the cache.
  const cached = searchText.get(exercise);
  const text = cached?.source === source ? cached.text : folded(source);
  if (!cached || cached.source !== source) {
    if (
      exercise !== null &&
      (typeof exercise === "object" || typeof exercise === "function")
    ) {
      searchText.set(exercise, { source, text });
    }
  }
  return previousWords.every((word) => text.includes(word));
}
