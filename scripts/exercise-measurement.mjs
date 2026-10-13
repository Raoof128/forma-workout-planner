// Keep imported measurement labels deterministic without regex backtracking.
export function inferMeasurement(name, category) {
  const hasAny = (words) => words.some((word) => name.includes(word));
  const inOrder = (first, second) => {
    const start = name.indexOf(first);
    return start !== -1 && name.indexOf(second, start + first.length) !== -1;
  };
  if (
    hasAny(["carry", "sled", "yoke"]) ||
    inOrder("walk", "farm") ||
    inOrder("farmer", "walk")
  )
    return "load_distance";
  if (
    ["tap", "touch", "reach", "row", "extension"].some((word) =>
      inOrder("plank", word),
    ) ||
    inOrder("push", "plank")
  )
    return "load_reps";
  if (inOrder("jump", "rope")) return "duration";
  if (
    category === "cardio" ||
    hasAny(["treadmill", "elliptical", "cycling", "running", "swimming"]) ||
    inOrder("stationary", "bike") ||
    inOrder("rowing", "erg")
  )
    return "duration_distance";
  if (
    category === "stretching" ||
    hasAny(["stretch", "plank", "isometric", "wall sit", "dead hang"])
  )
    return "duration";
  return "load_reps";
}
