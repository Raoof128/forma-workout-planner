import test from "node:test";
import assert from "node:assert/strict";
import { createCloudRepository } from "../src/account/cloudRepository.js";
import {
  freshData,
  legacyFingerprint,
  markLegacyMigrated,
  readLegacyMigration,
  MAX_HISTORY_SESSIONS,
  MAX_ROUTINES,
  MAX_TOTAL_SETS,
  validateData,
} from "../src/storage.js";

// Frontend/shared-schema regressions from the 2026-10-12 red-team engagement.
// See docs/security/penetration-test-report.md (FE-01, FE-03).

const response = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function session(index, exerciseId, sets = 1) {
  return {
    id: `s${index}`,
    name: "Session",
    startedAt: 1,
    date: "2026-01-01T00:00:00.000Z",
    duration: 1,
    exercises: [
      {
        exerciseId,
        sets: Array.from({ length: sets }, () => ({
          weight: 20,
          reps: 5,
          done: true,
        })),
      },
    ],
  };
}

test("FE-01: oversized workspaces are rejected before per-set validation runs", () => {
  const base = freshData();
  const exerciseId = base.routines[0].exercises[0].exerciseId;
  const tooManySets = {
    ...base,
    history: Array.from({ length: 5456 }, (_, i) =>
      session(i, exerciseId, 100),
    ),
  };
  const started = performance.now();
  assert.throws(() => validateData(tooManySets), /at most 150000 sets/);
  assert.ok(performance.now() - started < 250, "rejection must be cheap");

  assert.throws(
    () =>
      validateData({
        ...base,
        history: Array.from({ length: MAX_HISTORY_SESSIONS + 1 }, (_, i) =>
          session(i, exerciseId),
        ),
      }),
    /at most 10000 workouts/,
  );
  assert.throws(
    () =>
      validateData({
        ...base,
        routines: Array.from({ length: MAX_ROUTINES + 1 }, (_, i) => ({
          ...base.routines[0],
          id: `r${i}`,
        })),
      }),
    /at most 200 routines/,
  );

  // A decade of heavy training at the limits still validates quickly.
  const limit = {
    ...base,
    history: Array.from({ length: MAX_HISTORY_SESSIONS }, (_, i) =>
      session(i, exerciseId, MAX_TOTAL_SETS / MAX_HISTORY_SESSIONS),
    ),
  };
  const t0 = performance.now();
  assert.equal(validateData(limit).history.length, MAX_HISTORY_SESSIONS);
  assert.ok(performance.now() - t0 < 5000);
});

test("FE-03: restore/import is pinned to the reviewed cloud revision", async () => {
  const base = freshData();
  let revision = 2;
  const puts = [];
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "PUT") {
        puts.push(JSON.parse(options.body));
        revision += 1;
        return response(200, {
          data: { ...JSON.parse(options.body).data, revision },
          revision,
          updatedAt: "2026-10-12T10:00:00.000Z",
        });
      }
      return response(200, {
        data: { ...base, revision },
        revision,
        updatedAt: "2026-10-12T10:00:00.000Z",
      });
    },
  });
  await repository.initialize();
  // The member reviewed a backup while the cloud was at revision 0; another
  // device has since saved revision 2.
  await assert.rejects(
    repository.importLegacy(base, { expectedRevision: 0 }),
    (error) => error.staleReview === true,
  );
  assert.equal(puts.length, 0);
  await repository.importLegacy(base, { expectedRevision: 2 });
  assert.equal(puts.length, 1);
  assert.equal(puts[0].expectedRevision, 2);
});

test("FE-04: browser guest data is offered for import once, to the member who imported it", () => {
  const store = new Map();
  const previous = globalThis.localStorage;
  globalThis.localStorage = {
    getItem: (key) => (store.has(key) ? store.get(key) : null),
    setItem: (key, value) => store.set(key, String(value)),
  };
  try {
    const raw = JSON.stringify(freshData());
    assert.equal(readLegacyMigration(), null);
    markLegacyMigrated("mem_member-a", legacyFingerprint(raw));
    const marker = readLegacyMigration();
    assert.equal(marker.member, "mem_member-a");
    assert.equal(marker.fingerprint, legacyFingerprint(raw));
    // New guest training changes the fingerprint, so it is offered again.
    assert.notEqual(legacyFingerprint(`${raw} `), marker.fingerprint);
    store.set("forma-v1-migrated", "{not json");
    assert.equal(readLegacyMigration(), null);
  } finally {
    globalThis.localStorage = previous;
  }
});
