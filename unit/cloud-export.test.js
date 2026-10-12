import test from "node:test";
import assert from "node:assert/strict";
import { File } from "node:buffer";
import { createCloudRepository } from "../src/account/cloudRepository.js";
import { exercises } from "../src/data.js";
import { freshData, MAX_BACKUP_BYTES, readBackupFile } from "../src/storage.js";

function nearLimitWorkspace() {
  const count = 2_000;
  let noteLength = 10_000;
  const build = () => {
    const data = freshData();
    data.history = Array.from({ length: count }, (_, index) => ({
      id: `export-session-${index}`,
      name: "Near-limit workout",
      startedAt: 1_700_000_000_000 + index,
      notes: "x".repeat(noteLength),
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: [
        {
          exerciseId: exercises[0].id,
          sets: [{ weight: 20, reps: 8, done: true }],
        },
      ],
      date: "2026-10-12T10:00:00.000Z",
      duration: 60,
    }));
    return data;
  };

  let data = build();
  let compact = JSON.stringify(data);
  const safeTarget = MAX_BACKUP_BYTES - 128 * 1024;
  while (Buffer.byteLength(compact) > safeTarget) {
    noteLength -= 100;
    data = build();
    compact = JSON.stringify(data);
  }
  const prettySize = Buffer.byteLength(JSON.stringify(data, null, 2));
  assert.ok(Buffer.byteLength(compact) < MAX_BACKUP_BYTES);
  assert.ok(
    prettySize > MAX_BACKUP_BYTES,
    "fixture must reproduce pretty-printing past the accepted backup limit",
  );
  return { data, compact, noteLength };
}

test("near-limit cloud export downloads compact JSON that passes backup import size validation", async () => {
  const { data, compact, noteLength } = nearLimitWorkspace();
  let downloadedBlob;
  const oldDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
  const oldCreateObjectURL = URL.createObjectURL;
  const oldRevokeObjectURL = URL.revokeObjectURL;
  globalThis.document = {
    createElement: () => ({ click() {} }),
  };
  URL.createObjectURL = (blob) => {
    downloadedBlob = blob;
    return "blob:forma-export-test";
  };
  URL.revokeObjectURL = () => {};

  try {
    const repository = createCloudRepository({
      memberId: "mem_export-test",
      fetchImpl: async (_url, options) => {
        assert.equal(options.headers["X-Forma-Member"], "mem_export-test");
        return new Response(compact, {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      },
    });
    const exported = await repository.exportData();

    assert.equal(exported.history.length, data.history.length);
    assert.ok(downloadedBlob instanceof Blob);
    assert.equal(downloadedBlob.type, "application/json");
    assert.ok(downloadedBlob.size < MAX_BACKUP_BYTES);
    const imported = await readBackupFile(
      new File([downloadedBlob], "forma-account-export.json", {
        type: downloadedBlob.type,
      }),
    );
    assert.equal(imported.history.length, data.history.length);
    assert.equal(imported.history[0].notes.length, noteLength);
  } finally {
    if (oldDocument) Object.defineProperty(globalThis, "document", oldDocument);
    else delete globalThis.document;
    URL.createObjectURL = oldCreateObjectURL;
    URL.revokeObjectURL = oldRevokeObjectURL;
  }
});
