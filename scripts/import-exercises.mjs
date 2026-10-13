import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath, URL } from "node:url";
import { Buffer } from "node:buffer";
import { log } from "node:console";
import { format } from "prettier";

// Deliberately import text only. The source repository's image provenance is
// unresolved; no image paths, images or third-party runtime requests are used.
const freeRevision = "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5";
const wgerRevision = "d09dd5e50e7dbeafe492b1a9b7c5cb1f1e89c73e";
const sources = [];
async function readJson(url) {
  const response = await globalThis.fetch(url, {
    signal: globalThis.AbortSignal.timeout(30000),
  });
  if (!response.ok)
    throw new Error(`Catalog source failed: ${response.status}`);
  const text = await response.text();
  if (Buffer.byteLength(text) > 8 * 1024 * 1024)
    throw new Error("Source too large");
  sources.push({
    url,
    sha256: createHash("sha256").update(text).digest("hex"),
  });
  return JSON.parse(text);
}
const freeUrl = `https://raw.githubusercontent.com/yuhonas/free-exercise-db/${freeRevision}/dist/exercises.json`;
const wgerUrl = `https://raw.githubusercontent.com/wger-project/wger/${wgerRevision}/`;
const [free, translations, bases, categories, equipment, muscles, licenses] =
  await Promise.all([
    readJson(freeUrl),
    ...[
      "exercises/fixtures/translations.json",
      "exercises/fixtures/exercise-base-data.json",
      "exercises/fixtures/categories.json",
      "exercises/fixtures/equipment.json",
      "exercises/fixtures/muscles.json",
      "core/fixtures/licenses.json",
    ].map((path) => readJson(`${wgerUrl}wger/${path}`)),
  ]);
const byId = (rows) => new Map(rows.map((row) => [row.pk, row.fields]));
const baseMap = byId(bases),
  categoryMap = byId(categories),
  equipmentMap = byId(equipment),
  muscleMap = byId(muscles),
  licenseMap = byId(licenses);
const normalize = (name) => name.toLowerCase().replace(/[^a-z0-9]/g, "");
const legacyNames = [
  "Barbell bench press",
  "One-arm dumbbell row",
  "Dumbbell shoulder press",
  "Lat pulldown",
  "Dumbbell biceps curl",
  "Cable triceps pushdown",
  "Barbell back squat",
  "Romanian deadlift",
  "Leg press",
  "Dumbbell reverse lunge",
  "Standing calf raise",
  "Forearm plank",
  "Kettlebell goblet squat",
  "Push-up",
  "Dumbbell lateral raise",
  "Dead bug",
];
const names = new Set(legacyNames.map(normalize));
const knownAliases = new Set([
  "barbellbenchpressmediumgrip",
  "onearmdumbbellrow",
  "dumbbellshoulderpress",
  "dumbbellbicepcurl",
  "tricepspushdown",
  "barbellsquat",
  "legpress",
  "standingdumbbellcalfraise",
  "pushups",
  "sidelateralraise",
]);
const catalog = [];
const group = (name) =>
  /chest|pector/.test(name)
    ? "Chest"
    : /lat|back|trapez/.test(name)
      ? "Back"
      : /shoulder|deltoid/.test(name)
        ? "Shoulders"
        : /bicep|tricep|forearm|arm/.test(name)
          ? "Arms"
          : /abdom|oblique|core/.test(name)
            ? "Core"
            : /quad|hamstring|glut|calv|adduct|abduct|leg|tibial/.test(name)
              ? "Legs"
              : "Full body";
const cleanText = (text) =>
  text
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(
      /&(?:nbsp|amp|quot|lt|gt|#39);/g,
      (entity) =>
        ({
          "&nbsp;": " ",
          "&amp;": "&",
          "&quot;": '"',
          "&lt;": "<",
          "&gt;": ">",
          "&#39;": "'",
        })[entity],
    )
    .replace(/\s+/g, " ")
    .trim();
function measurement(name, category) {
  if (/carry|walk.*farm|farmer.*walk|sled|yoke/.test(name))
    return "load_distance";
  if (/plank.*(?:tap|touch|reach|row|extension)|push.*plank/.test(name))
    return "load_reps";
  if (/jump.*rope/.test(name)) return "duration";
  if (
    category === "cardio" ||
    /treadmill|elliptical|stationary.*bike|cycling|running|swimming|rowing.*erg/.test(
      name,
    )
  )
    return "duration_distance";
  if (
    category === "stretching" ||
    /stretch|plank|isometric|wall sit|dead hang/.test(name)
  )
    return "duration";
  return "load_reps";
}
function add(row) {
  const key = normalize(row.name);
  if (names.has(key) || knownAliases.has(key) || row.description.length < 60)
    return false;
  names.add(key);
  catalog.push({
    ...row,
    weight: 0,
    metric: measurement(row.name.toLowerCase(), row.category),
  });
  return true;
}
for (const row of free) {
  const equipmentName =
    {
      "body only": "Bodyweight",
      bands: "Resistance band",
      kettlebells: "Kettlebell",
      "e-z curl bar": "EZ bar",
      "exercise ball": "Exercise ball",
      "foam roll": "Foam roller",
      "medicine ball": "Medicine ball",
      other: "Specialty equipment",
    }[row.equipment] ??
    (row.equipment
      ? row.equipment[0].toUpperCase() + row.equipment.slice(1)
      : "Bodyweight");
  add({
    id: `db-${row.id.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
    name: row.name,
    muscle: group((row.primaryMuscles ?? []).join(" ")),
    equipment: equipmentName,
    primaryMuscles: row.primaryMuscles,
    secondaryMuscles: row.secondaryMuscles,
    category: row.category,
    level: row.level,
    description: row.instructions.map(cleanText).join("\n\n"),
    source: {
      title: "Free Exercise DB",
      url: `https://github.com/yuhonas/free-exercise-db/blob/${freeRevision}/exercises/${row.id}.json`,
      author:
        "Free Exercise DB contributors; original dataset by Ollie Jennings",
      license: "Unlicense",
      licenseUrl: "https://unlicense.org/",
    },
  });
}
let wgerAdded = 0,
  wgerExcluded = 0;
for (const row of translations.filter((row) => row.fields.language === 2)) {
  const t = row.fields,
    b = baseMap.get(t.exercise),
    license = licenseMap.get(t.license);
  // Keep per-entry content licensing separate from wger's AGPL code license.
  if (!b || !license || ![1, 2, 3, 4].includes(t.license)) {
    wgerExcluded++;
    continue;
  }
  const primary = b.muscles.map((id) => muscleMap.get(id)?.name_en ?? "");
  const category = categoryMap.get(b.category)?.name ?? "Full body";
  if (
    add({
      id: `wger-${b.uuid}`,
      name: t.name,
      muscle: group((primary.join(" ") || category).toLowerCase()),
      equipment:
        b.equipment
          .map((id) => equipmentMap.get(id)?.name)
          .filter(Boolean)
          .join(" + ") || "Bodyweight",
      primaryMuscles: primary,
      secondaryMuscles: b.muscles_secondary
        .map((id) => muscleMap.get(id)?.name_en)
        .filter(Boolean),
      category: category === "Cardio" ? "cardio" : "strength",
      level: "Unspecified",
      description: cleanText(t.description_source || t.description),
      source: {
        title: "wger",
        url: `https://wger.de/en/exercise/${t.exercise}/view/`,
        author: t.license_author || "wger contributors",
        license: license.short_name,
        licenseUrl: license.url,
        modified: "HTML removed; taxonomy and measurement labels normalized",
      },
    })
  )
    wgerAdded++;
}
let liveAdded = 0;
try {
  const snapshot = JSON.parse(
    await readFile(
      new URL("../docs/research/current-wger-additions.json", import.meta.url),
      "utf8",
    ),
  );
  for (const row of snapshot.additions) if (add(row)) liveAdded++;
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
catalog.sort((a, b) => a.name.localeCompare(b.name, "en"));
if (
  catalog.length < 800 ||
  new Set(catalog.map((row) => row.id)).size !== catalog.length
)
  throw new Error("Catalog incomplete or duplicate IDs");
const root = new URL("../", import.meta.url);
const instructions = Object.fromEntries(
  catalog.map((row) => [row.id, row.description]),
);
const json = (value) => format(JSON.stringify(value), { parser: "json" });
await writeFile(
  new URL("src/catalog/instructions.json", root),
  await json(instructions),
);
await writeFile(
  new URL("src/catalog/exercises.json", root),
  await json(
    catalog.map((row) => ({
      ...row,
      description: row.description.split(/\n\n/)[0].slice(0, 360),
    })),
  ),
);
await writeFile(
  new URL("docs/research/catalog-import.json", root),
  JSON.stringify(
    {
      freeRevision,
      wgerRevision,
      sourceRecords: free.length,
      importedAdditional: catalog.length,
      legacyPreserved: 16,
      total: catalog.length + 16,
      wgerAdded,
      wgerExcluded,
      liveAdded,
      contentOnly: true,
      excludedImages: true,
      sources: sources.sort((a, b) => a.url.localeCompare(b.url)),
    },
    null,
    2,
  ) + "\n",
);
log(
  `Generated ${catalog.length + 16} exercises; preserved all 16 legacy IDs. ${wgerAdded} additional wger entries. ${fileURLToPath(new URL("src/catalog/exercises.json", root))}`,
);
