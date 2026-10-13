const folded = (value) =>
  value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
export function matchesExercise(exercise, query) {
  const text = folded(
    [
      exercise.name,
      exercise.muscle,
      exercise.equipment,
      exercise.category,
      ...(exercise.aliases ?? []),
      ...(exercise.primaryMuscles ?? []),
      ...(exercise.secondaryMuscles ?? []),
    ]
      .filter(Boolean)
      .join(" "),
  );
  return query
    .trim()
    .split(/\s+/)
    .every((word) => text.includes(folded(word)));
}
