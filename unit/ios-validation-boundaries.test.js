import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { validateData } from "../src/storage.js";

const resource = (name) =>
  readFile(
    new URL(`../ios/Fixtures/${name}.json`, import.meta.url),
    "utf8",
  ).then(JSON.parse);
const [corpus, parity] = await Promise.all([
  resource("validation-boundaries"),
  resource("parity"),
]);
const fresh = (id) =>
  structuredClone(parity.cases.find((item) => item.id === id).workspace);

function assertBoundary(workspace, fixture) {
  const validate = () => validateData(workspace, { strict: true });
  if (fixture.accepted) assert.doesNotThrow(validate, fixture.id);
  else assert.throws(validate, undefined, fixture.id);
}

test("shared native date boundaries match strict web calendar and UTC grammar", () => {
  assert.equal(corpus.synthetic, true);
  for (const fixture of corpus.historyDates) {
    const workspace = fresh("showcase-receipt");
    workspace.history[0].date = fixture.value;
    assertBoundary(workspace, fixture);
  }
});

test("shared native optional routine bounds match strict web validation", () => {
  for (const fixture of corpus.routineMeasurements) {
    const workspace = fresh("active-upper");
    workspace.routines[0].exercises[0][fixture.field] = fixture.value;
    assertBoundary(workspace, fixture);
  }
});

test("shared native active completion metadata bounds match strict web validation", () => {
  for (const fixture of corpus.activeCompletionMetadata) {
    const workspace = fresh("active-upper");
    if (fixture.date !== null) workspace.active.date = fixture.date;
    if (fixture.duration !== null) workspace.active.duration = fixture.duration;
    assertBoundary(workspace, fixture);
  }
});

test("shared native Apple Watch summary bounds match strict web validation", () => {
  for (const fixture of corpus.watchSummaries) {
    const workspace = fresh("showcase-receipt");
    workspace.history[0].watch = fixture.summary;
    assertBoundary(workspace, fixture);
  }
});

test("a Watch summary belongs to finished workouts only", () => {
  const summary = { elapsedSeconds: 60, averageHeartRate: 120 };
  const finished = fresh("showcase-receipt");
  finished.history[0].watch = summary;
  assert.deepEqual(
    validateData(finished, { strict: true }).history[0].watch,
    summary,
  );
  const unknown = fresh("showcase-receipt");
  unknown.history[0].watch = { ...summary, samples: [118, 121] };
  assert.throws(() => validateData(unknown, { strict: true }));
  const active = fresh("active-upper");
  active.active.watch = summary;
  assert.throws(() => validateData(active, { strict: true }));
  assert.equal(validateData(active).active.watch, undefined);
});
