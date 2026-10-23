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
