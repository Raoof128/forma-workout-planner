import test from "node:test";
import assert from "node:assert/strict";
import {
  freshData,
  validateData,
  parseBackup,
  readBackupFile,
  MAX_BACKUP_BYTES,
} from "../src/storage.js";
import {
  dateKey,
  weekDates,
  estimatedOneRM,
  sessionVolume,
  sessionSets,
} from "../src/data.js";
const session = () => ({
  id: "workout",
  name: "Test",
  startedAt: 1000,
  exercises: [
    { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: true }] },
  ],
});

test("legacy version 1 backups receive revision and timer defaults", () => {
  const data = freshData();
  delete data.revision;
  data.active = session();
  const result = parseBackup(JSON.stringify(data));
  assert.equal(result.revision, 0);
  assert.equal(result.active.restSeconds, 90);
  assert.equal(result.active.restEnd, null);
  assert.equal(result.active.notes, "");
});

test("history with no completed sets cannot inflate workout counts", () => {
  const data = freshData();
  data.history = [{ ...session(), date: "2026-10-11T00:00:00Z", duration: 60 }];
  data.history[0].exercises[0].sets[0].done = false;
  assert.throws(() => validateData(data), /at least one completed set/);
});

test("a session cannot be active and completed under the same ID", () => {
  const data = freshData();
  data.active = session();
  data.history = [{ ...session(), date: "2026-10-11T00:00:00Z", duration: 60 }];
  assert.throws(() => validateData(data), /already present in history/);
});

test("out-of-range timestamps are rejected before rendering or timer arithmetic", () => {
  const data = freshData();
  data.active = { ...session(), startedAt: 1e100 };
  assert.throws(() => validateData(data));
  data.active = { ...session(), restEnd: 1e100 };
  assert.throws(() => validateData(data));
});

test("backup size is bounded before reading files and before parsing strings", async () => {
  let read = false;
  await assert.rejects(
    readBackupFile({
      size: MAX_BACKUP_BYTES + 1,
      text() {
        read = true;
        return "{}";
      },
    }),
    /20 MiB/,
  );
  assert.equal(read, false);
  assert.throws(() => parseBackup(" ".repeat(MAX_BACKUP_BYTES + 1)), /20 MiB/);
  assert.throws(
    () => parseBackup("é".repeat(MAX_BACKUP_BYTES / 2 + 1)),
    /20 MiB/,
  );
});

test("completed-set validation permits a blank unfinished draft but not completed blanks", () => {
  const data = freshData();
  data.active = session();
  const set = data.active.exercises[0].sets[0];
  set.weight = "";
  set.reps = "";
  set.done = false;
  assert.doesNotThrow(() => validateData(data));
  set.done = true;
  assert.throws(() => validateData(data));
});

test("calendar calculations stay in Sydney across daylight-saving boundaries", () => {
  assert.equal(dateKey("2026-10-03T15:59:59Z"), "2026-10-04");
  assert.equal(dateKey("2026-10-03T16:00:00Z"), "2026-10-04");
  assert.equal(dateKey("2026-10-11T13:00:00Z"), "2026-10-12");
  const week = weekDates();
  assert.equal(week[0].getUTCDay(), 1);
  assert.equal(week[6].getUTCDay(), 0);
  assert.equal(new Set(week.map(dateKey)).size, 7);
});

test("training totals count completed sets and keep the actual single-rep load", () => {
  const data = session();
  data.exercises[0].sets.push({ weight: 100, reps: 10, done: false });
  assert.equal(sessionVolume(data), 400);
  assert.equal(sessionSets(data), 1);
  assert.equal(estimatedOneRM(100, 1), 100);
  assert.equal(estimatedOneRM(50, 6), 60);
});

test("ID generation works when randomUUID is unavailable", async () => {
  const { createId } = await import("../src/data.js");
  const id = createId({
    getRandomValues: (bytes) => {
      bytes.fill(255);
      return bytes;
    },
  });
  assert.match(
    id,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
});
