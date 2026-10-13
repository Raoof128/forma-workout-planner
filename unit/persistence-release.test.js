import test from "node:test";
import assert from "node:assert/strict";
import { createWorkoutRepository } from "../src/persistence.js";
import { freshData, parseBackup, STORAGE_KEY } from "../src/storage.js";

for (const [label, getLocks] of [
  [
    "a throwing locks getter",
    () => {
      throw new Error("Locks API denied");
    },
  ],
  ["an unavailable locks API", () => undefined],
]) {
  test(`a commit remains single-application and temporary with ${label}`, async () => {
    let raw = JSON.stringify(freshData());
    let writes = 0;
    let updates = 0;
    const repository = createWorkoutRepository({
      read: () => ({ data: parseBackup(raw), raw, issue: null }),
      write: (key, nextRaw) => {
        assert.equal(key, STORAGE_KEY);
        writes += 1;
        raw = nextRaw;
      },
      getLocks,
    });

    const result = await repository.commit((data) => {
      updates += 1;
      return { ...data, profile: { ...data.profile, name: "Temporary once" } };
    });

    assert.equal(updates, 1);
    assert.equal(writes, 0);
    assert.equal(result.saved, false);
    assert.equal(result.data.profile.name, "Temporary once");
    assert.equal(result.data.revision, 1);
    assert.equal(repository.getSnapshot().issue, "unavailable");
    assert.equal(parseBackup(raw).profile.name, "Guest");
  });
}
