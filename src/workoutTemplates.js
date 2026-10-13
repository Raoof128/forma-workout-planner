import { exerciseById } from "./data.js";
import { defaultPrescription } from "./exerciseMetrics.js";
const prescription = (id, targets = {}) => {
  const exercise = exerciseById.get(id);
  if (!exercise) throw new Error(`Missing template exercise: ${id}`);
  return {
    exerciseId: id,
    ...defaultPrescription(exercise),
    weight: 0,
    ...targets,
  };
};
const template = (id, name, description, minutes, ids, targets = {}) => ({
  id: `template-${id}`,
  name,
  description,
  minutes,
  level: "Adaptable",
  image: 2,
  exercises: ids.map((id) => prescription(id, targets)),
});
export const workoutTemplates = [
  template(
    "push",
    "Push day",
    "Chest, shoulders and triceps. Choose a comfortable load and keep each rep controlled.",
    45,
    ["bench", "shoulder", "lateral", "triceps"],
  ),
  template(
    "pull",
    "Pull day",
    "Rows, pulldowns and curls for the back and arms. Adjust sets and load to your experience.",
    40,
    ["row", "pulldown", "curl"],
  ),
  template(
    "legs",
    "Leg day",
    "Squat, hinge, lunge and calf work. Warm up and set loads before starting.",
    45,
    ["squat", "rdl", "lunge", "calf"],
  ),
  template(
    "dumbbells",
    "Dumbbell full body",
    "A full-body session using dumbbells and a bench. Set the weight per movement before you train.",
    35,
    ["row", "shoulder", "lunge", "calf", "curl"],
  ),
  template(
    "bodyweight",
    "Bodyweight essentials",
    "Push-ups, controlled core repetitions and a timed plank. Adjust the plank hold to your ability.",
    20,
    ["pushup", "deadbug", "db-plank"],
  ),
  template(
    "core",
    "Core control",
    "Alternate controlled dead bugs with timed planks. Keep breathing and reduce duration when form changes.",
    15,
    ["deadbug", "db-plank"],
    { sets: 2 },
  ),
  template(
    "walk",
    "Treadmill walk",
    "A steady walk at a comfortable pace. Record the actual time and distance from your machine.",
    20,
    ["db-walking-treadmill"],
    { sets: 1, durationSeconds: 1200, distanceMeters: 1000 },
  ),
  template(
    "run",
    "Treadmill running",
    "Choose your own pace and incline, and include a warm-up. Update the targets to match your planned run.",
    25,
    ["db-running-treadmill"],
    { sets: 1, durationSeconds: 1500, distanceMeters: 3000 },
  ),
  template(
    "cycle",
    "Stationary cycling",
    "Steady cycling with comfortable resistance. Use the bike's actual distance reading for your log.",
    20,
    ["db-bicycling-stationary"],
    { sets: 1, durationSeconds: 1200, distanceMeters: 4000 },
  ),
  template(
    "row",
    "Rowing session",
    "A steady rowing session. Learn the drive and recovery sequence, then choose a sustainable effort.",
    15,
    ["db-rowing-stationary"],
    { sets: 1, durationSeconds: 900, distanceMeters: 2000 },
  ),
  template(
    "carry",
    "Carry and squat",
    "Alternate a loaded carry with goblet squats. Choose your load and use a clear, level walking space.",
    20,
    ["db-farmers-walk", "goblet"],
    { sets: 3 },
  ),
  template(
    "mobility",
    "Whole-body mobility",
    "Gentle neck, quadriceps and calf mobility. Use a comfortable range and adjust each hold rather than forcing a stretch.",
    15,
    [
      "db-chin-to-chest-stretch",
      "db-all-fours-quad-stretch",
      "db-calf-stretch-hands-against-wall",
    ],
    { sets: 2, durationSeconds: 30 },
  ),
];
