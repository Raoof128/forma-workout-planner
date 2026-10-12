import test from "node:test";
import assert from "node:assert/strict";
import { createCloudRepository } from "../src/account/cloudRepository.js";
import { freshData } from "../src/storage.js";

const response = (status, body) =>
  new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
const workspace = (data, revision = 4) => ({
  data,
  revision,
  updatedAt: "2026-10-12T10:00:00.000Z",
});

test("cloud repository loads authoritative data and commits with CAS metadata", async () => {
  const base = freshData();
  const calls = [];
  const repository = createCloudRepository({
    makeId: () => "op-1",
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (options.method === "GET") return response(200, workspace(base));
      const body = JSON.parse(options.body);
      return response(
        200,
        workspace(
          { ...body.data, profile: { ...body.data.profile, goal: 4 } },
          5,
        ),
      );
    },
  });

  await repository.initialize();
  const saved = await repository.commit((current) => ({
    ...current,
    profile: { ...current.profile, goal: 4 },
  }));

  assert.equal(calls[1].options.method, "PUT");
  assert.deepEqual(JSON.parse(calls[1].options.body), {
    data: { ...base, revision: 1, profile: { ...base.profile, goal: 4 } },
    expectedRevision: 4,
    operationId: "op-1",
  });
  assert.equal(saved.saved, true);
  assert.equal(repository.getSnapshot().revision, 5);
  assert.equal(repository.getSnapshot().status, "ready");
});

test("workspace requests stay bound to the member that created the repository", async () => {
  const base = freshData();
  const calls = [];
  const repository = createCloudRepository({
    memberId: "mem_member-a",
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return options.method !== "PUT"
        ? response(200, workspace(base))
        : response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  await repository.commit((current) => ({
    ...current,
    profile: { ...current.profile, goal: 7 },
  }));
  await repository.exportData();

  assert.deepEqual(
    calls.map(({ options }) => options.headers["X-Forma-Member"]),
    ["mem_member-a", "mem_member-a", "mem_member-a"],
  );
});

test("account_changed clears member data and does not retry a stale write under a new cookie", async () => {
  const base = freshData();
  const calls = [];
  let changed = 0;
  const repository = createCloudRepository({
    memberId: "mem_member-a",
    onAccountChanged: () => {
      changed += 1;
    },
    fetchImpl: async (_url, options) => {
      calls.push(options);
      if (options.method === "GET") return response(200, workspace(base));
      return response(409, {
        error: "account_changed",
        message: "Session changed.",
      });
    },
  });
  await repository.initialize();
  await assert.rejects(
    repository.commit((current) => ({
      ...current,
      profile: { ...current.profile, goal: 7 },
    })),
    (error) => error.accountChanged === true,
  );

  assert.equal(calls.length, 2);
  assert.equal(calls[1].headers["X-Forma-Member"], "mem_member-a");
  assert.equal(changed, 1);
  assert.equal(repository.getSnapshot().data, null);
  assert.equal(repository.getSnapshot().revision, null);
  assert.equal(repository.getSnapshot().retryPayload, null);
  assert.equal(repository.getSnapshot().conflict, null);
  assert.notEqual(repository.getSnapshot().status, "conflict");
});

test("a conflict preserves the attempted update and exposes latest cloud data", async () => {
  const base = freshData();
  const latest = { ...base, profile: { ...base.profile, goal: 5 } };
  const repository = createCloudRepository({
    makeId: () => "conflict-op",
    fetchImpl: async (_url, options) =>
      options.method === "GET"
        ? response(200, workspace(base))
        : response(409, {
            error: "revision_conflict",
            message: "Workspace changed.",
            ...workspace(latest, 6),
          }),
  });
  await repository.initialize();

  await assert.rejects(
    repository.commit((current) => ({
      ...current,
      profile: { ...current.profile, goal: 2 },
    })),
    (error) => error.conflict === true,
  );
  assert.equal(repository.getSnapshot().status, "conflict");
  assert.equal(repository.getSnapshot().revision, 6);
  assert.equal(repository.getSnapshot().data.profile.goal, 5);
  assert.equal(repository.getSnapshot().conflict.attempted.profile.goal, 2);
});

test("ambiguous transport failures retry the exact serialized operation", async () => {
  const base = freshData();
  const puts = [];
  let attempt = 0;
  const repository = createCloudRepository({
    makeId: () => "stable-op",
    fetchImpl: async (_url, options) => {
      if (options.method === "GET") return response(200, workspace(base));
      puts.push(options.body);
      attempt += 1;
      if (attempt === 1) throw new TypeError("connection reset");
      return response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  await repository.commit((current) => ({
    ...current,
    profile: { ...current.profile, goal: 3 },
  }));

  assert.equal(puts.length, 2);
  assert.equal(puts[0], puts[1]);
  assert.equal(JSON.parse(puts[0]).operationId, "stable-op");
});

test("dispose cancels an in-flight save and prevents queued writes from starting", async () => {
  const base = freshData();
  let putCount = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "GET") return response(200, workspace(base));
      putCount += 1;
      return new Promise((_, reject) => {
        options.signal.addEventListener("abort", () => {
          const error = new Error("aborted");
          error.name = "AbortError";
          reject(error);
        });
      });
    },
  });
  await repository.initialize();
  const first = repository.commit((current) => ({
    ...current,
    profile: { ...current.profile, goal: 2 },
  }));
  const second = repository.commit((current) => ({
    ...current,
    profile: { ...current.profile, goal: 5 },
  }));
  await new Promise((resolve) => setImmediate(resolve));
  repository.dispose();

  await assert.rejects(first, { name: "AbortError" });
  await assert.rejects(second, { name: "AbortError" });
  assert.equal(putCount, 1);
});

test("an unknown save outcome blocks new commits until the exact operation is retried", async () => {
  const base = freshData();
  const bodies = [];
  let failures = 2;
  const repository = createCloudRepository({
    makeId: () => "same-op",
    fetchImpl: async (_url, options) => {
      if (options.method === "GET") return response(200, workspace(base));
      bodies.push(options.body);
      if (failures > 0) {
        failures -= 1;
        throw new TypeError("connection lost after commit");
      }
      return response(200, workspace(JSON.parse(options.body).data, 5));
    },
  });
  await repository.initialize();
  await assert.rejects(
    repository.commit((current) => ({
      ...current,
      profile: { ...current.profile, goal: 4 },
    })),
  );
  await assert.rejects(
    repository.commit((current) => ({
      ...current,
      profile: { ...current.profile, goal: 6 },
    })),
    /Retry the pending cloud save/,
  );
  await repository.retry();

  assert.equal(bodies.length, 3);
  assert.equal(bodies[0], bodies[1]);
  assert.equal(bodies[1], bodies[2]);
  assert.equal(repository.getSnapshot().data.profile.goal, 4);
});

test("an older overlapping refresh cannot replace a newer revision", async () => {
  const base = freshData();
  let releaseFirst;
  let getCount = 0;
  const repository = createCloudRepository({
    fetchImpl: async (_url, options) => {
      if (options.method === "PUT") return response(500, { message: "unused" });
      getCount += 1;
      if (getCount === 1)
        return new Promise((resolve) => {
          releaseFirst = resolve;
        });
      return response(
        200,
        workspace({ ...base, profile: { ...base.profile, goal: 6 } }, 6),
      );
    },
  });
  const first = repository.initialize();
  await new Promise((resolve) => setImmediate(resolve));
  await repository.refresh();
  releaseFirst(response(200, workspace(base, 5)));
  await first;

  assert.equal(repository.getSnapshot().revision, 6);
  assert.equal(repository.getSnapshot().data.profile.goal, 6);
});
