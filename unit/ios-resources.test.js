import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
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
import {
  buildIOSResources,
  writeIOSResources,
} from "../scripts/build-ios-resources.mjs";
import { checkNativeContracts } from "../scripts/check-ios-contracts.mjs";

const outputs = await buildIOSResources();
const json = (path) => JSON.parse(outputs.get(path));
const catalog = json("ios/FORMA/Resources/catalog.json");
const seed = json("ios/FORMA/Resources/seed-workspace.json");
const parity = json("ios/Fixtures/parity.json");
const nativeById = new Map(catalog.map((entry) => [entry.id, entry]));

function contractEvidence() {
  return {
    synthetic: true,
    cases: catalog.map((exercise) => {
      const entry = sessionEntry({
        exerciseId: exercise.id,
        ...exercise.defaults,
      });
      entry.sets[0].done = true;
      return {
        id: exercise.id,
        workspace: {
          ...structuredClone(seed),
          history: [
            {
              id: `synthetic-contract-${exercise.id}`,
              name: "Synthetic contract-checker control",
              startedAt: 1792440000000,
              notes:
                "Test-only JavaScript control, not Swift-generated evidence.",
              restSeconds: 90,
              restEnd: null,
              restPaused: null,
              exercises: [entry],
              date: "2026-10-20T00:00:00.000Z",
              duration: 60,
            },
          ],
        },
      };
    }),
  };
}

test("native contract checker accepts every authoritative default measurement", () => {
  assert.equal(checkNativeContracts(contractEvidence()), exerciseById.size);
});

test("native contract checker rejects schema-valid changes to units, loads, sides or completion", () => {
  const mutations = [
    [
      "plank",
      (entry) => {
        entry.sets[0].reps = 1;
        entry.sets[0].durationSeconds = 100;
      },
    ],
    [
      "bench",
      (entry) => {
        entry.sets[0].weight += 0.25;
      },
    ],
    [
      "db-plank",
      (entry) => {
        entry.sets[0].durationSeconds += 1;
      },
    ],
    [
      "row",
      (entry) => {
        entry.sets[0].sides.left += 1;
        entry.sets[0].reps += 1;
      },
    ],
    [
      "bench",
      (entry) => {
        entry.sets[1].done = true;
      },
    ],
    [
      "bench",
      (entry) => {
        entry.sets.pop();
      },
    ],
    [
      "bench",
      (entry) => {
        entry.targetReps += 1;
      },
    ],
  ];
  for (const [id, mutate] of mutations) {
    const probe = contractEvidence();
    const row = probe.cases.find((item) => item.id === id);
    mutate(row.workspace.history[0].exercises[0]);
    // These corruptions are still accepted by the shared storage schema;
    // a probe parity check must independently detect changed measurements.
    validateData(row.workspace, { strict: true });
    assert.throws(
      () => checkNativeContracts(probe),
      /default measurements/,
      id,
    );
  }
});

test("native decorative assets match their durable provenance checksums", async () => {
  const record = JSON.parse(
    await readFile(
      new URL("../ios/design/asset-checksums.json", import.meta.url),
      "utf8",
    ),
  );
  assert.equal(record.algorithm, "sha256");
  assert.equal(record.files.length, 3);
  for (const asset of record.files) {
    const bytes = await readFile(new URL(`../${asset.path}`, import.meta.url));
    assert.equal(
      createHash("sha256").update(bytes).digest("hex"),
      asset.sha256,
      asset.path,
    );
    assert.equal(bytes.length, asset.bytes, asset.path);
  }
});

test("native provenance covers the generator's complete local import graph", async () => {
  const visited = new Set();
  async function visit(relativePath) {
    if (visited.has(relativePath)) return;
    visited.add(relativePath);
    if (!/\.[cm]?js$/.test(relativePath)) return;
    const source = await readFile(
      new URL(`../${relativePath}`, import.meta.url),
      "utf8",
    );
    const imports =
      /^\s*(?:import|export)\s+[\s\S]*?\sfrom\s+["']([^"']+)["']/gm;
    for (const match of source.matchAll(imports)) {
      if (match[1].startsWith(".")) {
        await visit(
          path.posix.normalize(
            path.posix.join(path.posix.dirname(relativePath), match[1]),
          ),
        );
      }
    }
  }
  await visit("scripts/build-ios-resources.mjs");
  const manifest = json("ios/FORMA/Resources/resource-manifest.json");
  const recorded = new Set(manifest.sources.map((source) => source.path));
  assert.deepEqual(
    [...visited].sort(),
    [...recorded].sort(),
    "Every source affecting the native export needs a provenance hash.",
  );
});

test("native resources retain every accepted ID and only reviewed selectable IDs", () => {
  assert.equal(catalog.length, 1711);
  assert.equal(nativeById.size, exerciseById.size);
  assert.equal(catalog.filter((entry) => entry.selectable).length, 1411);
  const selectable = new Set(selectableExercises.map((entry) => entry.id));
  for (const [id, source] of exerciseById) {
    const native = nativeById.get(id);
    assert.ok(native, id);
    assert.equal(native.selectable, selectable.has(id), id);
    assert.equal(native.metric, source.metric ?? "load_reps", id);
    assert.equal(native.canonicalId, canonicalId(id, curation), id);
    assert.equal(native.loadType, loadType(source), id);
    assert.deepEqual(native.defaults, defaultPrescription(source), id);
    assert.equal(native.perSide, defaultPrescription(source).perSide, id);
  }
});

test("native guides and per-entry source rights preserve reviewed text and original provenance", () => {
  for (const [id, source] of exerciseById) {
    const native = nativeById.get(id);
    const guide = guideExercise(id);
    assert.deepEqual(native.source, guide.source ?? null, id);
    assert.deepEqual(native.rawSource, source.source ?? null, id);
    assert.deepEqual(native.references, guide.references ?? [], id);
    assert.equal(native.guideId, guide.id, id);
    assert.equal(native.description, source.description, id);
    if (!guide.guideUnavailable) {
      const expected = guide.source
        ? (instructions[guide.instructionId ?? guide.id] ?? guide.description)
        : guide.description;
      assert.equal(native.guide, expected, id);
    }
    if (native.source) {
      for (const key of ["title", "url", "author", "license", "licenseUrl"])
        assert.equal(typeof native.source[key], "string", `${id}/${key}`);
      assert.equal(native.source.modified, guide.source.modified, id);
    }
  }
});

test("native compatibility rows never take logging units from canonical guide aliases", () => {
  const plank = nativeById.get("plank");
  assert.equal(plank.metric, "load_reps");
  assert.equal(nativeById.get("db-plank").metric, "duration");
  assert.deepEqual(plank.holdUnit, { key: "reps", seconds: 10, max: 1000 });
  assert.equal(plank.usesHoldTimer, true);
  let differingUnits = 0;
  for (const [id, original] of exerciseById) {
    const guide = guideExercise(id);
    if ((original.metric ?? "load_reps") !== (guide.metric ?? "load_reps")) {
      differingUnits++;
      assert.equal(nativeById.get(id).metric, original.metric ?? "load_reps");
    }
    assert.deepEqual(nativeById.get(id).holdUnit, holdUnit(original));
    assert.equal(nativeById.get(id).usesHoldTimer, usesHoldTimer(original));
  }
  assert.ok(differingUnits > 20);
});

test("native seed is exactly fresh version-2 data with all three complete starters and no invented history", () => {
  assert.deepEqual(seed, freshData());
  assert.equal(seed.version, 2);
  assert.deepEqual(seed.history, []);
  assert.equal(seed.active, null);
  assert.equal(seed.routines.length, 3);
  assert.deepEqual(
    seed.routines.map((routine) => routine.exercises.length),
    [6, 6, 6],
  );
  assert.deepEqual(validateData(seed, { strict: true }), seed);
});

test("every native default can produce a routine, active workout and completed export accepted by the web validator", () => {
  for (const exercise of catalog) {
    const prescription = { exerciseId: exercise.id, ...exercise.defaults };
    const workspace = structuredClone(seed);
    const routine = { ...workspace.routines[0], exercises: [prescription] };
    workspace.routines = [routine];
    validateData(workspace, { strict: true });
    workspace.active = {
      id: "synthetic-native-bridge",
      name: "Synthetic native bridge",
      routineId: routine.id,
      startedAt: 1792440000000,
      notes: "Fictional development fixture.",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: [sessionEntry(prescription)],
    };
    validateData(workspace, { strict: true });
    workspace.active.exercises[0].sets[0].done = true;
    validateData(workspace, { strict: true });
    workspace.history = [
      {
        ...workspace.active,
        date: "2026-10-20T00:00:00.000Z",
        duration: 60,
      },
    ];
    workspace.active = null;
    validateData(workspace, { strict: true });
  }
});

test("synthetic parity cases are strict valid workspaces with truthful independent measurement totals", () => {
  assert.equal(parity.synthetic, true);
  assert.ok(parity.cases.length >= 8);
  for (const item of parity.cases) {
    assert.deepEqual(
      validateData(item.workspace, { strict: true }),
      item.workspace,
      item.id,
    );
    const sessions = [...item.workspace.history, item.workspace.active].filter(
      Boolean,
    );
    assert.equal(
      sessions.reduce((n, session) => n + sessionSets(session), 0),
      item.expected.completedSets,
      item.id,
    );
    assert.equal(
      sessions.reduce((n, session) => n + sessionVolume(session), 0),
      item.expected.volume,
      item.id,
    );
    for (const [field, expected] of [
      ["durationSeconds", "durationSeconds"],
      ["distanceMeters", "distanceMeters"],
    ]) {
      const total = sessions
        .flatMap((session) => session.exercises)
        .flatMap((entry) => entry.sets)
        .filter((set) => set.done)
        .reduce((n, set) => n + Number(set[field] ?? 0), 0);
      assert.equal(total, item.expected[expected], `${item.id}/${field}`);
    }
  }
  const showcase = parity.cases.find((item) => item.id === "showcase-receipt");
  assert.deepEqual(showcase.expected, {
    completedSets: 12,
    volume: 2760,
    durationSeconds: 135,
    distanceMeters: 0,
  });
  assert.equal(showcase.workspace.history[0].duration, 38 * 60);
  const unilateral = parity.cases.find((item) => item.id === "unequal-sides");
  const set = unilateral.workspace.active.exercises[0].sets[0];
  assert.equal(set.reps, set.sides.left + set.sides.right);
  assert.notEqual(set.sides.left, set.sides.right);
});

test("native legal resources retain exact current source policies and label local prototype scope", () => {
  const legal = json("ios/FORMA/Resources/legal.json");
  assert.deepEqual(legal.privacy, legalDocuments.privacy);
  assert.deepEqual(legal.terms, legalDocuments.terms);
  assert.equal(legal.privacy.version, "1.3");
  assert.equal(legal.nativeGuestNotice.status, "prototype-not-release-policy");
  const notice = JSON.stringify(legal.nativeGuestNotice).toLowerCase();
  assert.match(notice, /application support/);
  assert.match(notice, /export/);
  assert.match(notice, /no analytics/);
  assert.match(notice, /no account/);
  assert.match(notice, /importing a backup is not available/);
  assert.match(notice, /excluded from device backups/);
  assert.doesNotMatch(notice, /may include these local files/);
  // Apple Watch workouts write to Apple Health; the notice must say so and
  // must not claim that no Health data is involved.
  assert.match(notice, /apple health/);
  assert.match(notice, /heart rate/);
  assert.doesNotMatch(notice, /no healthkit data/);
});

test("catalogue notices retain original and reviewed credits without claiming license clearance", () => {
  const notices = json("ios/FORMA/Resources/catalogue-notices.json");
  assert.equal(notices.status, "source-credits-retained-not-legal-clearance");
  assert.equal(notices.entries.length, catalog.length);
  for (const entry of notices.entries) {
    const native = nativeById.get(entry.id);
    assert.deepEqual(entry.source, native.source);
    assert.deepEqual(entry.rawSource, native.rawSource);
    assert.deepEqual(entry.references, native.references);
  }
});

test("committed resources reproduce byte-for-byte and the check command makes no changes", async () => {
  for (const [relativePath, content] of outputs)
    assert.equal(
      await readFile(new URL(`../${relativePath}`, import.meta.url), "utf8"),
      content,
      relativePath,
    );
  const second = await buildIOSResources();
  assert.deepEqual([...second], [...outputs]);
  const result = await writeIOSResources({ check: true });
  assert.match(result, /1711 accepted IDs/);
  assert.match(result, /1411 selectable/);
});

test("drift check rejects changed resources and leaves their original bytes available for review", async (context) => {
  const destination = await mkdtemp(
    path.join(tmpdir(), "forma-ios-resources-"),
  );
  context.after(() => rm(destination, { recursive: true, force: true }));
  await writeIOSResources({ destination });
  const target = path.join(
    destination,
    "ios/FORMA/Resources/seed-workspace.json",
  );
  const changed = `${outputs.get("ios/FORMA/Resources/seed-workspace.json")} `;
  await writeFile(target, changed);
  await assert.rejects(
    writeIOSResources({ check: true, destination }),
    /missing or stale: ios\/FORMA\/Resources\/seed-workspace\.json/,
  );
  assert.equal(await readFile(target, "utf8"), changed);
  await rm(target);
  await assert.rejects(
    writeIOSResources({ check: true, destination }),
    /missing or stale: ios\/FORMA\/Resources\/seed-workspace\.json/,
  );
});
