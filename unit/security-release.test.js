import test from "node:test";
import assert from "node:assert/strict";
import {
  freshData,
  parseBackup,
  readBackupFile,
  MAX_BACKUP_BYTES,
} from "../src/storage.js";

function addDangerousOwnProperties(value, marker) {
  Object.defineProperty(value, "__proto__", {
    enumerable: true,
    configurable: true,
    value: { polluted: marker },
  });
  value.constructor = { prototype: { polluted: marker } };
  value.prototype = { polluted: marker };
}

test("backup parsing strips prototype-shaped unknown keys without polluting Object.prototype", () => {
  const backup = freshData();
  addDangerousOwnProperties(backup, "top-level");
  addDangerousOwnProperties(backup.profile, "profile");
  addDangerousOwnProperties(backup.routines[0], "routine");
  addDangerousOwnProperties(backup.routines[0].exercises[0], "exercise");
  const raw = JSON.stringify(backup);

  assert.equal(Object.hasOwn(Object.prototype, "polluted"), false);
  const parsed = parseBackup(raw);
  assert.equal(Object.hasOwn(Object.prototype, "polluted"), false);
  assert.equal({}.polluted, undefined);
  assert.equal(Object.hasOwn(parsed, "__proto__"), false);
  assert.equal(Object.hasOwn(parsed, "constructor"), false);
  assert.equal(Object.hasOwn(parsed.profile, "__proto__"), false);
  assert.equal(Object.hasOwn(parsed.profile, "constructor"), false);
  assert.equal(Object.hasOwn(parsed.profile, "prototype"), false);
  assert.equal(Object.hasOwn(parsed.routines[0], "__proto__"), false);
  assert.equal(Object.hasOwn(parsed.routines[0], "constructor"), false);
  assert.equal(Object.hasOwn(parsed.routines[0], "prototype"), false);
  assert.equal(
    Object.hasOwn(parsed.routines[0].exercises[0], "__proto__"),
    false,
  );
  assert.equal(
    Object.hasOwn(parsed.routines[0].exercises[0], "constructor"),
    false,
  );
  assert.equal(
    Object.hasOwn(parsed.routines[0].exercises[0], "prototype"),
    false,
  );
});

test("malformed JSON and schema-invalid backups are rejected", () => {
  assert.throws(() => parseBackup("{not json"));

  const backup = freshData();
  backup.routines[0].image = 3;
  assert.throws(() => parseBackup(JSON.stringify(backup)));

  const unknownExercise = freshData();
  unknownExercise.routines[0].exercises[0].exerciseId = "constructor";
  assert.throws(() => parseBackup(JSON.stringify(unknownExercise)));
});

test("oversized backup files are rejected before their contents are read", async () => {
  let read = false;
  await assert.rejects(
    readBackupFile({
      size: MAX_BACKUP_BYTES + 1,
      async text() {
        read = true;
        throw new Error("Should not read an oversized file");
      },
    }),
    /20 MiB/,
  );
  assert.equal(read, false);
});
