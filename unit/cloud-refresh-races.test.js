import test from "node:test";
import assert from "node:assert/strict";
import { createCloudRepository } from "../src/account/cloudRepository.js";
import { freshData } from "../src/storage.js";

const response = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
const workspace = (data, revision = 4) => ({
  data,
  revision,
  updatedAt: "2026-10-23T00:00:00.000Z",
});
const deferred = () => {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
};
const rename = (data) => ({
  ...data,
  profile: { ...data.profile, name: "Unsaved training" },
});

for (const failure of ["transport", "conflict"]) {
  test(`a pending refresh preserves a later ${failure} save and its recovery data`, async () => {
    const base = freshData();
    const read = deferred();
    let reads = 0;
    const repository = createCloudRepository({
      fetchImpl: async (_url, options) => {
        if (options.method === "GET")
          return ++reads === 1 ? response(200, workspace(base)) : read.promise;
        if (failure === "transport") throw new TypeError("Connection lost");
        return response(409, {
          error: "stale_revision",
          ...workspace(base, 5),
        });
      },
    });
    await repository.initialize();
    const refresh = repository.refresh();
    await assert.rejects(repository.commit(rename));
    const failed = repository.getSnapshot();
    read.resolve(response(200, workspace(base, 5)));
    await refresh;

    assert.strictEqual(repository.getSnapshot(), failed);
    assert.equal(
      failure === "transport"
        ? failed.retryPayload.data.profile.name
        : failed.conflict.attempted.profile.name,
      "Unsaved training",
    );
    await assert.rejects(
      repository.commit(rename),
      /Retry the pending cloud save|Resolve the cloud conflict/,
    );
  });
}

test("a late refresh failure cannot replace an acknowledged save with an offline error", async () => {
  const base = freshData();
  const read = deferred();
  let reads = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "GET")
        return ++reads === 1 ? response(200, workspace(base)) : read.promise;
      return response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  const refresh = repository.refresh();
  await repository.commit(rename);
  read.resolve(response(503, { error: "unavailable" }));
  await refresh;
  assert.equal(repository.getSnapshot().status, "ready");
  assert.equal(repository.getSnapshot().data.profile.name, "Unsaved training");
  assert.equal(repository.getSnapshot().issue, null);
});

test("focus and poll refreshes do not start reads or replace the saving state during a write", async () => {
  const base = freshData();
  const save = deferred();
  const saving = deferred();
  let reads = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "GET") {
        reads += 1;
        return response(200, workspace(base));
      }
      saving.resolve();
      await save.promise;
      return response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  const commit = repository.commit(rename);
  await saving.promise;
  await Promise.all([repository.refresh(), repository.refresh()]);
  const during = repository.getSnapshot();
  save.resolve();
  await commit;

  assert.equal(reads, 1);
  assert.equal(during.status, "saving");
  assert.equal(repository.getSnapshot().status, "ready");
  assert.equal(repository.getSnapshot().data.profile.name, "Unsaved training");
});

test("conflict recovery blocks new edits until the explicitly requested reload completes", async () => {
  const base = freshData();
  const read = deferred();
  let reads = 0;
  let puts = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "GET")
        return ++reads === 1 ? response(200, workspace(base)) : read.promise;
      puts += 1;
      if (puts === 1)
        return response(409, {
          error: "stale_revision",
          ...workspace(base, 5),
        });
      return response(200, workspace(JSON.parse(options.body).data, 7));
    },
  });
  await repository.initialize();
  await assert.rejects(repository.commit(rename));
  const reload = repository.reloadConflict();
  const edit = repository.commit(rename);
  await assert.rejects(edit, /Resolve the cloud conflict/);
  read.resolve(response(200, workspace(base, 6)));
  await reload;
  assert.equal(repository.getSnapshot().status, "ready");
  assert.equal(repository.getSnapshot().conflict, null);
  await repository.commit(rename);
  assert.equal(puts, 2);
  assert.equal(repository.getSnapshot().data.profile.name, "Unsaved training");
});

test("a late refresh error cannot undo recovery by retrying the original operation", async () => {
  const base = freshData();
  const read = deferred();
  let reads = 0;
  let puts = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "GET")
        return ++reads === 1 ? response(200, workspace(base)) : read.promise;
      if (++puts <= 2) throw new TypeError("Connection lost");
      return response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  const refresh = repository.refresh();
  await assert.rejects(repository.commit(rename));
  await repository.retry();
  read.resolve(response(503, { error: "unavailable" }));
  await refresh;
  assert.equal(repository.getSnapshot().status, "ready");
  assert.equal(repository.getSnapshot().retryPayload, null);
  assert.equal(repository.getSnapshot().data.profile.name, "Unsaved training");
  assert.equal(puts, 3);
});

for (const status of [401, 409]) {
  test(`a late refresh ${status} still clears private data after a failed write`, async () => {
    const base = freshData();
    const read = deferred();
    let reads = 0;
    let sessionChecks = 0;
    const repository = createCloudRepository({
      onUnauthorized: () => {
        sessionChecks += 1;
      },
      fetchImpl: async (_url, options) => {
        if (options.method === "GET")
          return ++reads === 1 ? response(200, workspace(base)) : read.promise;
        throw new TypeError("Connection lost");
      },
    });
    await repository.initialize();
    const refresh = repository.refresh();
    await assert.rejects(repository.commit(rename));
    read.resolve(
      response(status, {
        error: status === 401 ? "unauthorized" : "account_changed",
      }),
    );
    await assert.rejects(refresh);
    assert.equal(repository.getSnapshot().data, null);
    assert.ok(!repository.getSnapshot().retryPayload);
    assert.equal(sessionChecks, 1);
  });
}
