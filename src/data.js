import catalog from "./catalog/exercises.json" with { type: "json" };
import machineExercises from "./catalog/machine-exercises.json" with { type: "json" };
import curation from "./catalog/curation.json" with { type: "json" };
import unilateral from "./catalog/unilateral.json" with { type: "json" };
import { canonicalId, createCatalogView } from "./catalog/curation.js";
import { tracksLoadReps } from "./exerciseMetrics.js";
import { defaultPerSide } from "./routineProgramming.js";

const originalExercises = [
  {
    id: "bench",
    name: "Barbell bench press",
    muscle: "Chest",
    equipment: "Barbell",
    description:
      "Lie on a flat bench with feet planted. Grip the bar just wider than shoulder width. Lower it toward your mid-chest with control, then press up without bouncing.",
    weight: 40,
  },
  {
    id: "row",
    name: "One-arm dumbbell row",
    muscle: "Back",
    equipment: "Dumbbell",
    description:
      "Support one hand and knee on a bench. Keep your back neutral and pull the dumbbell toward your hip. Lower slowly and repeat on both sides.",
    weight: 16,
  },
  {
    id: "shoulder",
    name: "Dumbbell shoulder press",
    muscle: "Shoulders",
    equipment: "Dumbbell",
    description:
      "Sit tall with dumbbells at shoulder height. Press overhead while keeping your ribs down. Lower under control.",
    weight: 12,
  },
  {
    id: "pulldown",
    name: "Lat pulldown",
    muscle: "Back",
    equipment: "Machine",
    description:
      "Sit with thighs secured and grip the bar slightly wider than your shoulders. Pull toward the upper chest, leading with your elbows. Return slowly.",
    weight: 35,
  },
  {
    id: "curl",
    name: "Dumbbell biceps curl",
    muscle: "Arms",
    equipment: "Dumbbell",
    description:
      "Stand tall with elbows close to your body. Curl the weights without swinging. Lower slowly to a comfortable full extension.",
    weight: 10,
  },
  {
    id: "triceps",
    name: "Cable triceps pushdown",
    muscle: "Arms",
    equipment: "Cable",
    description:
      "Keep elbows by your sides and shoulders relaxed. Extend the elbows to press the handle down. Return with control.",
    weight: 15,
  },
  {
    id: "squat",
    name: "Barbell back squat",
    muscle: "Legs",
    equipment: "Barbell",
    description:
      "Set the bar across your upper back. Brace your trunk, sit down between your hips, and keep knees tracking with toes. Push through your feet to stand.",
    weight: 40,
  },
  {
    id: "rdl",
    name: "Romanian deadlift",
    muscle: "Legs",
    equipment: "Barbell",
    description:
      "With knees slightly bent, move your hips backward and keep the bar close to your legs. Stop at a comfortable hamstring stretch, then extend the hips to stand.",
    weight: 40,
  },
  {
    id: "legpress",
    name: "Leg press",
    muscle: "Legs",
    equipment: "Machine",
    description:
      "Keep your back supported. Lower the platform until your hips remain stable, then push evenly through your feet without locking your knees.",
    weight: 60,
  },
  {
    id: "lunge",
    name: "Dumbbell reverse lunge",
    muscle: "Legs",
    equipment: "Dumbbell",
    description:
      "Step back and lower both knees with control. Keep your front knee tracking with your toes. Push through your front foot and alternate sides.",
    weight: 10,
  },
  {
    id: "calf",
    name: "Standing calf raise",
    muscle: "Legs",
    equipment: "Dumbbell",
    description:
      "Stand tall holding a dumbbell at your side. Rise onto the balls of your feet, pause, then lower your heels slowly.",
    weight: 10,
  },
  {
    id: "plank",
    name: "Forearm plank",
    muscle: "Core",
    equipment: "Bodyweight",
    description:
      "Place elbows under shoulders and extend your legs. Brace your abdomen and keep a straight line from head to heels. Each rep here is a controlled 10-second hold.",
    weight: 0,
  },
  {
    id: "goblet",
    name: "Kettlebell goblet squat",
    muscle: "Legs",
    equipment: "Kettlebell",
    description:
      "Hold a kettlebell at chest height. Squat between your knees with your chest tall, then push through your feet to stand.",
    weight: 12,
  },
  {
    id: "pushup",
    name: "Push-up",
    muscle: "Chest",
    equipment: "Bodyweight",
    description:
      "Set hands slightly wider than shoulders. Brace your body, lower your chest between your hands, and press up. Use an elevated surface if needed.",
    weight: 0,
  },
  {
    id: "lateral",
    name: "Dumbbell lateral raise",
    muscle: "Shoulders",
    equipment: "Dumbbell",
    description:
      "With a soft elbow bend, lift dumbbells out to your sides to shoulder height. Keep shoulders relaxed and lower slowly.",
    weight: 5,
  },
  {
    id: "deadbug",
    name: "Dead bug",
    muscle: "Core",
    equipment: "Bodyweight",
    description:
      "Lie on your back with arms raised and knees bent. Keep your lower back stable as you slowly extend the opposite arm and leg. Alternate sides.",
    weight: 0,
  },
];
// Reviewed one-side-at-a-time movements carry the limb they are logged per
// (`side`: arm, leg or side); the catalogue review lives in unilateral.json.
const withSide = (records) =>
  records.map((exercise) => {
    const side =
      unilateral[exercise.id] ?? unilateral[canonicalId(exercise.id, curation)];
    return side ? { ...exercise, side } : exercise;
  });
// Compatibility records keep every published ID and its original logging units.
export const publishedExercises = withSide([...originalExercises, ...catalog]);
export const exercises = [...publishedExercises, ...withSide(machineExercises)];
export const selectableExercises = createCatalogView(exercises, curation);
// Saved rows and pickers share reviewed names/equipment without changing metric units.
const selectableById = new Map(selectableExercises.map((row) => [row.id, row]));
export const exerciseById = new Map(
  exercises.map((exercise) => {
    const reviewed = selectableById.get(exercise.id);
    const family = selectableById.get(canonicalId(exercise.id, curation));
    return [
      exercise.id,
      {
        ...exercise,
        name: reviewed?.name ?? exercise.name,
        equipment:
          reviewed?.equipment ?? family?.equipment ?? exercise.equipment,
      },
    ];
  }),
);
const reviewedGuides = new Map(selectableExercises.map((row) => [row.id, row]));
// Guide, name and artwork for any saved ID. A hold saved in reps resolves to
// its timed row here, so take units from exerciseById, never from this.
export function guideExercise(id) {
  return (
    reviewedGuides.get(canonicalId(id, curation)) ?? {
      ...exerciseById.get(id),
      source: undefined,
      guideUnavailable: true,
    }
  );
}
const items = (ids) =>
  ids.map((id) => {
    const exercise = exercises.find((e) => e.id === id);
    return {
      exerciseId: id,
      sets: 3,
      reps: 10,
      weight: exercise.weight,
      perSide: defaultPerSide(exercise),
    };
  });
export const starterRoutines = [
  {
    id: "upper",
    name: "Upper body strength",
    description: "Build strength. Find your rhythm.",
    minutes: 50,
    level: "Intermediate",
    image: 0,
    exercises: items([
      "bench",
      "row",
      "shoulder",
      "pulldown",
      "curl",
      "triceps",
    ]),
  },
  {
    id: "lower",
    name: "Lower body foundation",
    description: "A stronger foundation starts here.",
    minutes: 50,
    level: "Intermediate",
    image: 1,
    exercises: items(["squat", "rdl", "legpress", "lunge", "calf", "plank"]),
  },
  {
    id: "full",
    name: "Full body essentials",
    description: "A little of everything. A lot of progress.",
    minutes: 45,
    level: "Beginner",
    image: 2,
    exercises: items([
      "goblet",
      "pushup",
      "row",
      "shoulder",
      "lunge",
      "deadbug",
    ]),
  },
];
export const initialData = {
  version: 2,
  routines: starterRoutines,
  history: [],
  active: null,
  profile: { name: "Guest", goal: 4 },
  schedule: [0, 1, 3, 5],
};
export function createId(cryptoApi = globalThis.crypto) {
  if (typeof cryptoApi.randomUUID === "function") return cryptoApi.randomUUID();
  // getRandomValues is also available on HTTP origins used for local previews.
  const bytes = cryptoApi.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
export const TIME_ZONE = "Australia/Sydney";
const keyFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});
const displayFormatters = new Map();
export function dateKey(value = new Date()) {
  return keyFormatter.format(new Date(value));
}
export function displayDate(value, options = {}) {
  const key = JSON.stringify(options);
  if (!displayFormatters.has(key))
    displayFormatters.set(
      key,
      new Intl.DateTimeFormat("en-AU", { timeZone: TIME_ZONE, ...options }),
    );
  return displayFormatters.get(key).format(new Date(value));
}
export function weekDates(offset = 0) {
  const d = new Date(`${dateKey()}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7) + offset * 7);
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(d);
    day.setUTCDate(d.getUTCDate() + index);
    return day;
  });
}
export const sameDay = (a, b) => dateKey(a) === dateKey(b);
export function estimatedOneRM(weight, reps) {
  return reps === 1 ? weight : weight * (1 + reps / 30);
}
export const sessionVolume = (s) =>
  s.exercises.reduce(
    (n, e) =>
      n +
      (tracksLoadReps(exerciseById.get(e.exerciseId)) ? e.sets : [])
        .filter((x) => x.done)
        .reduce((v, x) => v + Number(x.weight) * Number(x.reps), 0),
    0,
  );
export const sessionSets = (s) =>
  s.exercises.reduce((n, e) => n + e.sets.filter((x) => x.done).length, 0);
export const formatTime = (s) =>
  `${Math.floor(s / 60)
    .toString()
    .padStart(2, "0")}:${Math.floor(s % 60)
    .toString()
    .padStart(2, "0")}`;
