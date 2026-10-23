/**
 * Deterministic native bridge. Run from the repository root:
 *   node scripts/build-ios-resources.mjs          # regenerate
 *   node scripts/build-ios-resources.mjs --check  # fail on drift, never write
 *
 * Generated paths (do not hand-edit):
 *   ios/FORMA/Resources/catalog.json
 *   ios/FORMA/Resources/seed-workspace.json
 *   ios/FORMA/Resources/legal.json
 *   ios/FORMA/Resources/catalogue-notices.json
 *   ios/FORMA/Resources/resource-manifest.json
 *   ios/Fixtures/parity.json
 *
 * The web validator and reviewed catalogue remain authoritative. These are
 * data exports, not a new native schema, instructional asset licence grant,
 * App Store eligibility decision or copy of the web authentication client.
 */
import { createHash } from "node:crypto";
import { Buffer } from "node:buffer";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import {
  exerciseById,
  guideExercise,
  selectableExercises,
  sessionSets,
  sessionVolume,
} from "../src/data.js";
import instructions from "../src/catalog/instructions.json" with { type: "json" };
import curation from "../src/catalog/curation.json" with { type: "json" };
import { canonicalId } from "../src/catalog/curation.js";
import { defaultPrescription } from "../src/exerciseMetrics.js";
import { holdUnit, loadType, usesHoldTimer } from "../src/exerciseLoad.js";
import { freshData, validateData } from "../src/storage.js";
import { sessionEntry } from "../src/workoutSession.js";
import { legalDocuments } from "../src/legal/content.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const json = (value) => `${JSON.stringify(value, null, 2)}\n`;
const sha256 = (value) => createHash("sha256").update(value).digest("hex");
const syntheticStart = 1792440000000;
const syntheticDate = "2026-10-20T00:00:00.000Z";
const unavailableGuide =
  "This older entry is kept for your saved workouts. Its source did not provide usable technique instructions.";

function nativeCatalog() {
  const selectable = new Set(
    selectableExercises.map((exercise) => exercise.id),
  );
  return [...exerciseById.values()]
    .map((exercise) => {
      const guide = guideExercise(exercise.id);
      const defaults = defaultPrescription(exercise);
      return {
        id: exercise.id,
        name: exercise.name,
        muscle: exercise.muscle,
        equipment: exercise.equipment,
        description: exercise.description,
        // Guide aliases may change reps to seconds. Never use guide.metric.
        metric: exercise.metric ?? "load_reps",
        weight: exercise.weight ?? 0,
        perSide: defaults.perSide,
        side: exercise.side ?? null,
        loadType: loadType(exercise),
        selectable: selectable.has(exercise.id),
        canonicalId: canonicalId(exercise.id, curation),
        guideId: guide.id,
        guideUnavailable: guide.guideUnavailable === true,
        guide: guide.guideUnavailable
          ? unavailableGuide
          : guide.source
            ? (instructions[guide.instructionId ?? guide.id] ??
              guide.description)
            : guide.description,
        // Keep exact entry-specific rights keys, including modified notices.
        source: guide.source ?? null,
        rawSource: exercise.source ?? null,
        references: guide.references ?? [],
        aliases: [
          ...new Set([
            ...(exercise.aliases ?? []),
            ...(guide.aliases ?? []),
            ...(guide.name !== exercise.name ? [guide.name] : []),
          ]),
        ].filter((alias) => alias !== exercise.name),
        defaults,
        usesHoldTimer: usesHoldTimer(exercise),
        holdUnit: holdUnit(exercise),
      };
    })
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

function activeSession(id, entries, name = "Synthetic development workout") {
  return {
    id: `synthetic-${id}`,
    name,
    startedAt: syntheticStart,
    notes: "Fictional development fixture. Never preload as member history.",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: entries,
  };
}

function completedEntry(exerciseId, overrides = {}) {
  const exercise = exerciseById.get(exerciseId);
  if (!exercise) throw new Error(`Unknown synthetic exercise ${exerciseId}`);
  const entry = sessionEntry({
    exerciseId,
    ...defaultPrescription(exercise),
    ...overrides,
  });
  return {
    ...entry,
    sets: entry.sets.map((set) => ({ ...set, done: true })),
  };
}

function expectedTotals(workspace) {
  const sessions = [...workspace.history, workspace.active].filter(Boolean);
  const sets = sessions
    .flatMap((session) => session.exercises)
    .flatMap((entry) => entry.sets)
    .filter((set) => set.done);
  return {
    completedSets: sessions.reduce(
      (sum, session) => sum + sessionSets(session),
      0,
    ),
    volume: sessions.reduce((sum, session) => sum + sessionVolume(session), 0),
    durationSeconds: sets.reduce(
      (sum, set) => sum + Number(set.durationSeconds ?? 0),
      0,
    ),
    distanceMeters: sets.reduce(
      (sum, set) => sum + Number(set.distanceMeters ?? 0),
      0,
    ),
  };
}

function parityFixtures() {
  const cases = [];
  function add(id, workspace) {
    const valid = validateData(workspace, { strict: true });
    cases.push({ id, workspace: valid, expected: expectedTotals(valid) });
  }
  add("fresh-guest", freshData());
  for (const routine of freshData().routines) {
    const workspace = freshData();
    workspace.active = {
      ...activeSession(
        `active-${routine.id}`,
        routine.exercises.map((entry) => sessionEntry(entry)),
        routine.name,
      ),
      routineId: routine.id,
    };
    add(`active-${routine.id}`, workspace);
  }

  const showcase = freshData();
  showcase.history = [
    {
      ...activeSession("showcase-receipt", [
        completedEntry("bench", { weight: 60, reps: 8, perSide: false }),
        completedEntry("shoulder", { weight: 20, reps: 10, perSide: false }),
        completedEntry("squat", { weight: 40, reps: 6, perSide: false }),
        completedEntry("db-plank", { durationSeconds: 45, perSide: false }),
      ]),
      date: syntheticDate,
      duration: 38 * 60,
    },
  ];
  add("showcase-receipt", showcase);

  const unilateral = freshData();
  const unilateralEntry = completedEntry("row", { sets: 1, reps: 8 });
  unilateralEntry.sets[0] = {
    ...unilateralEntry.sets[0],
    sides: { left: 8, right: 6 },
    reps: 14,
  };
  unilateral.active = activeSession("unequal-sides", [unilateralEntry]);
  add("unequal-sides", unilateral);

  const metricFixtures = [
    ["timed-hold", "db-plank", { durationSeconds: 45 }],
    [
      "time-and-distance",
      "wger-6c34000f-5d0b-43a9-b16e-00fd00c6db78",
      { durationSeconds: 180, distanceMeters: 300 },
    ],
    ["loaded-carry", "db-farmers-walk", { weight: 30, distanceMeters: 25 }],
    ["legacy-plank-reps", "plank", { reps: 4, perSide: false }],
    [
      "legacy-hold-reps",
      "wger-d059c63d-0a81-48a3-912a-44070c0def2e",
      { reps: 5, perSide: false },
    ],
  ];
  for (const [id, exerciseId, prescription] of metricFixtures) {
    const workspace = freshData();
    workspace.active = activeSession(id, [
      completedEntry(exerciseId, { ...prescription, sets: 1 }),
    ]);
    add(id, workspace);
  }

  const repeated = freshData();
  repeated.active = activeSession("repeated-movement", [
    { ...completedEntry("bench", { sets: 1 }), entryId: "synthetic-bench-a" },
    { ...completedEntry("bench", { sets: 1 }), entryId: "synthetic-bench-b" },
  ]);
  add("repeated-movement", repeated);

  return {
    version: 1,
    synthetic: true,
    description:
      "Fictional parity fixtures generated and strictly validated by the existing web domain. Development/tests only; not initial app history.",
    cases,
  };
}

function nativeLegal() {
  return {
    ...legalDocuments,
    nativeGuestNotice: {
      title: "Native development build: your data",
      version: "0.1",
      effective: "23 October 2026",
      status: "prototype-not-release-policy",
      summary:
        "This development build keeps your training records on your device. It includes no account sign-in, cloud sync, analytics or advertising.",
      blocks: [
        { h: "Local storage", id: "local-storage" },
        {
          p: "Routines, workouts, notes and preferences are saved in the app's Application Support directory on your device, rather than in browser storage. This development build marks its data directory as excluded from device backups. Backup and file-protection behavior still needs verification in the actual iPhone build. Export a copy before uninstalling the app or changing phones.",
        },
        { h: "Export your training", id: "export-training" },
        {
          p: "You can export a FORMA JSON backup through the system file exporter. Importing a backup is not available in this development build. An exported backup contains your training records and is readable by anyone who can access that file. Exported copies remain wherever you choose to save or share them, including after deleting local app data or uninstalling the app.",
        },
        { h: "No account or tracking", id: "account-tracking" },
        {
          p: "No account service is connected in this development build. Your training records are not uploaded by the app. There is no analytics SDK, advertising SDK or cross-app tracking. Opening an external support or source link uses the destination service under its own terms.",
        },
        { h: "Health and safety", id: "health-safety" },
        {
          p: "FORMA is a planning and record-keeping tool, not medical or personalised training advice. Use appropriate technique and equipment and seek qualified guidance when needed. No HealthKit data or physiological readiness score is collected or calculated.",
        },
        { h: "Release policies and contact", id: "release-policies" },
        {
          p: "The bundled Privacy Policy version 1.3 and Terms of Use version 1.0 are unchanged source documents for the existing website. Their browser and account descriptions do not describe all native storage details above. Native release policies, developer eligibility, content rights and App Store declarations still require review before submission. Questions: raoof.r12@gmail.com.",
        },
      ],
    },
  };
}

export async function buildIOSResources() {
  const catalog = nativeCatalog();
  const outputs = new Map([
    ["ios/FORMA/Resources/catalog.json", json(catalog)],
    ["ios/FORMA/Resources/seed-workspace.json", json(freshData())],
    ["ios/FORMA/Resources/legal.json", json(nativeLegal())],
    [
      "ios/FORMA/Resources/catalogue-notices.json",
      json({
        version: 1,
        status: "source-credits-retained-not-legal-clearance",
        notice:
          "Instruction text retains entry-specific original and reviewed source credits. Author, URL, licence URL and modification notices must remain available with the guide. No upstream third-party exercise photographs or wger application code are bundled by this bridge. Share-alike distribution/App Store compatibility and all release rights remain subject to owner/legal review; retaining credits is not a clearance decision.",
        entries: catalog.map((entry) => ({
          id: entry.id,
          guideId: entry.guideId,
          source: entry.source,
          rawSource: entry.rawSource,
          references: entry.references,
        })),
      }),
    ],
    ["ios/Fixtures/parity.json", json(parityFixtures())],
  ]);

  const sourcePaths = [
    "src/data.js",
    "src/storage.js",
    "src/exerciseMetrics.js",
    "src/exerciseLoad.js",
    "src/routineProgramming.js",
    "src/workoutSession.js",
    "src/catalog/exercises.json",
    "src/catalog/machine-exercises.json",
    "src/catalog/curation.json",
    "src/catalog/curation.js",
    "src/catalog/programming-aliases.json",
    "src/catalog/unilateral.json",
    "src/catalog/logging-review.json",
    "src/catalog/instructions.json",
    "src/legal/content.js",
    "scripts/build-ios-resources.mjs",
  ];
  const sources = [];
  for (const relativePath of sourcePaths)
    sources.push({
      path: relativePath,
      sha256: sha256(await readFile(path.join(root, relativePath))),
    });
  outputs.set(
    "ios/FORMA/Resources/resource-manifest.json",
    json({
      version: 1,
      generator: "scripts/build-ios-resources.mjs",
      workspaceVersion: 2,
      acceptedIDs: catalog.length,
      selectableIDs: catalog.filter((entry) => entry.selectable).length,
      sources,
      outputs: [...outputs].map(([relativePath, content]) => ({
        path: relativePath,
        sha256: sha256(content),
        bytes: Buffer.byteLength(content),
      })),
    }),
  );
  return outputs;
}

export async function writeIOSResources({
  check = false,
  destination = root,
} = {}) {
  const outputs = await buildIOSResources();
  const stale = [];
  for (const [relativePath, content] of outputs) {
    const target = path.join(destination, relativePath);
    if (check) {
      let existing;
      try {
        existing = await readFile(target, "utf8");
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
      if (existing !== content) stale.push(relativePath);
    } else {
      await mkdir(path.dirname(target), { recursive: true });
      await writeFile(target, content);
    }
  }
  if (stale.length)
    throw new Error(
      `Native resources are missing or stale: ${stale.join(", ")}. Run node scripts/build-ios-resources.mjs.`,
    );
  const manifest = JSON.parse(
    outputs.get("ios/FORMA/Resources/resource-manifest.json"),
  );
  return `${check ? "Verified" : "Generated"} ${outputs.size} native resources: ${manifest.acceptedIDs} accepted IDs, ${manifest.selectableIDs} selectable.`;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const options = process.argv.slice(2);
  if (options.some((option) => option !== "--check"))
    throw new Error("Usage: node scripts/build-ios-resources.mjs [--check]");
  // Only non-sensitive catalogue/build counts are emitted.
  process.stdout.write(
    `${await writeIOSResources({ check: options.includes("--check") })}\n`,
  );
}
