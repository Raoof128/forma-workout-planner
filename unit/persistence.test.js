import test from "node:test";
import assert from "node:assert/strict";
import { createWorkoutRepository } from "../src/persistence.js";
import { freshData, parseBackup, STORAGE_KEY } from "../src/storage.js";

function fixture({ raw = JSON.stringify(freshData()), locks } = {}) {
  const entries = new Map([[STORAGE_KEY, raw]]);
  let serial = 0;
  let readDenied = false;
  let writeDenied = false;
  let tail = Promise.resolve();
  const sharedLocks = locks || {
    request(_name, action) {
      const result = tail.then(action);
      tail = result.catch(() => {});
      return result;
    },
  };
  const adapters = {
    read() {
      if (readDenied)
        return { data: freshData(), raw: null, issue: "unavailable" };
      const value = entries.get(STORAGE_KEY) ?? null;
      if (value === null) return { data: freshData(), raw: null, issue: null };
      try {
        return { data: parseBackup(value), raw: value, issue: null };
      } catch {
        return { data: null, raw: value, issue: "invalid" };
      }
    },
    write(key, value) {
      if (writeDenied) throw new Error("Quota exceeded");
      entries.set(key, value);
    },
    getLocks: () => sharedLocks,
    now: () => 1000,
    makeId: () => `id-${++serial}`,
  };
  return {
    entries,
    adapters,
    repository: createWorkoutRepository(adapters),
    denyRead(value = true) {
      readDenied = value;
    },
    denyWrite(value = true) {
      writeDenied = value;
    },
  };
}
const rename = (name) => (data) => ({
  ...data,
  profile: { ...data.profile, name },
});

test("initialization and mutations handle a rejecting Web Locks API", async () => {
  const state = fixture({
    locks: { request: () => Promise.reject(new Error("Blocked")) },
  });
  await state.repository.initialize();
  assert.equal(state.repository.getSnapshot().issue, "unavailable");
  const result = await state.repository.commit(rename("Temporary"));
  assert.equal(result.saved, false);
  assert.equal(result.data.profile.name, "Temporary");
  assert.equal(result.data.revision, 1);
  assert.equal(
    parseBackup(state.entries.get(STORAGE_KEY)).profile.name,
    "Alex Morgan",
  );
});

test("a lock rejection after initialization retains the edit once in memory", async () => {
  let denied = false;
  const state = fixture({
    locks: {
      request: (_name, action) =>
        denied
          ? Promise.reject(new Error("Denied"))
          : Promise.resolve(action()),
    },
  });
  await state.repository.initialize();
  denied = true;
  let calls = 0;
  const result = await state.repository.commit((data) => {
    calls++;
    return rename("Retained")(data);
  });
  assert.equal(calls, 1);
  assert.equal(result.data.profile.name, "Retained");
  assert.equal(result.saved, false);
});

test("a mutation error is never retried or partially adopted", async () => {
  const { repository } = fixture();
  let calls = 0;
  await assert.rejects(
    repository.commit((data) => {
      calls++;
      data.profile.name = "Mutated draft";
      throw new Error("Conflict");
    }),
    /Conflict/,
  );
  assert.equal(calls, 1);
  assert.equal(repository.getSnapshot().data.profile.name, "Alex Morgan");
});

test("temporary mode advances revisions and rejects a stale restore confirmation", async () => {
  const state = fixture();
  state.denyWrite();
  await state.repository.commit(rename("First temporary edit"));
  const revision = state.repository.getSnapshot().data.revision;
  await state.repository.commit(rename("Second temporary edit"));
  state.denyWrite(false);
  await assert.rejects(
    state.repository.commit(() => freshData(), {
      recover: true,
      expectedRevision: revision,
    }),
    /changed while reviewing/,
  );
  assert.equal(
    state.repository.getSnapshot().data.profile.name,
    "Second temporary edit",
  );
});

test("restoring from temporary mode preserves both original disk and memory", async () => {
  const state = fixture();
  state.denyWrite();
  await state.repository.commit(rename("Unsaved work"));
  const revision = state.repository.getSnapshot().data.revision;
  state.denyWrite(false);
  await state.repository.commit(() => freshData(), {
    recover: true,
    expectedRevision: revision,
  });
  const originals = [...state.entries]
    .filter(([key]) => key !== STORAGE_KEY)
    .map(([, raw]) => parseBackup(raw).profile.name);
  assert.deepEqual(
    new Set(originals),
    new Set(["Alex Morgan", "Unsaved work"]),
  );
  assert.equal(state.repository.getSnapshot().data.revision, revision + 1);
});

test("recovery will not overwrite another tab's replacement of corrupt data", async () => {
  const state = fixture({ raw: "{broken" });
  const next = freshData();
  next.profile.name = "Recovered elsewhere";
  state.entries.set(STORAGE_KEY, JSON.stringify(next));
  await assert.rejects(
    state.repository.commit(() => freshData(), {
      recover: true,
      expectedRaw: "{broken",
    }),
    /changed while reviewing/,
  );
  assert.equal(
    parseBackup(state.entries.get(STORAGE_KEY)).profile.name,
    "Recovered elsewhere",
  );
  assert.equal(state.entries.size, 1);
});

test("unreadable storage blocks replacement and leaves in-memory data intact", async () => {
  const state = fixture();
  state.denyRead();
  state.repository.sync();
  await assert.rejects(
    state.repository.commit(() => freshData(), { recover: true }),
    /Recovery could not be saved/,
  );
  assert.equal(state.entries.size, 1);
  assert.equal(state.repository.getSnapshot().data.profile.name, "Alex Morgan");
});

test("repeated recoveries in the same millisecond keep distinct originals", async () => {
  const state = fixture();
  const backup = freshData();
  backup.profile.name = "Restored";
  await state.repository.commit(() => backup, { recover: true });
  await state.repository.commit(() => freshData(), { recover: true });
  assert.equal(state.entries.size, 3);
  const names = [...state.entries]
    .filter(([key]) => key !== STORAGE_KEY)
    .map(([, raw]) => parseBackup(raw).profile.name);
  assert.deepEqual(names, ["Alex Morgan", "Restored"]);
});

test("two repositories serialize independent mutations without losing fields", async () => {
  const state = fixture();
  const other = createWorkoutRepository(state.adapters);
  await Promise.all([
    state.repository.commit(rename("Concurrent")),
    other.commit((data) => ({ ...data, schedule: [1, 4] })),
  ]);
  const data = parseBackup(state.entries.get(STORAGE_KEY));
  assert.equal(data.profile.name, "Concurrent");
  assert.deepEqual(data.schedule, [1, 4]);
  assert.equal(data.revision, 2);
});

test("failed preservation never replaces the current workspace", async () => {
  const state = fixture();
  const original = state.entries.get(STORAGE_KEY);
  state.denyWrite();
  await assert.rejects(
    state.repository.commit(() => freshData(), { recover: true }),
    /Recovery could not be saved/,
  );
  assert.equal(state.entries.get(STORAGE_KEY), original);
});

test("loss of storage access on recovery keeps the invalid-data state", () => {
  const state = fixture({ raw: "broken" });
  state.denyRead();
  state.repository.sync();
  assert.equal(state.repository.getSnapshot().issue, "invalid");
  assert.equal(state.repository.getSnapshot().raw, "broken");
});

test("task-local storage snapshots are refreshed and flushed while the lock is held", async () => {
  let canonical = JSON.stringify(freshData());
  let tail = Promise.resolve();
  const locks = {
    request(_name, action) {
      const result = tail.then(action);
      tail = result.catch(() => {});
      return result;
    },
  };
  function makeRepository() {
    let cached = canonical;
    let dirty = false;
    return createWorkoutRepository({
      read: () => ({ data: parseBackup(cached), raw: cached, issue: null }),
      write: (_key, value) => {
        cached = value;
        dirty = true;
      },
      getLocks: () => locks,
      checkpoint: async () => {
        if (dirty) canonical = cached;
        cached = canonical;
        dirty = false;
      },
    });
  }
  const first = makeRepository(),
    second = makeRepository();
  await Promise.all([
    first.commit(rename("Checkpointed")),
    second.commit((data) => ({ ...data, schedule: [2, 5] })),
  ]);
  const result = parseBackup(canonical);
  assert.equal(result.profile.name, "Checkpointed");
  assert.deepEqual(result.schedule, [2, 5]);
  assert.equal(result.revision, 2);
});
