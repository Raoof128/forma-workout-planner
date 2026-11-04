import assert from "node:assert/strict";
import test from "node:test";
import { watchReadings, watchTotals } from "../src/watchSummary.js";

test("Watch totals weight heart rate by recorded time, as on the iPhone", () => {
  const totals = watchTotals([
    {
      watch: {
        elapsedSeconds: 600,
        averageHeartRate: 100,
        maxHeartRate: 140,
        activeEnergyKcal: 50,
      },
    },
    {},
    {
      watch: {
        elapsedSeconds: 1800,
        averageHeartRate: 140,
        maxHeartRate: 171,
        activeEnergyKcal: 200,
      },
    },
    { watch: { elapsedSeconds: 300 } },
  ]);
  assert.deepEqual(totals, {
    workouts: 3,
    averageHeartRate: 130,
    highestHeartRate: 171,
    activeEnergyKcal: 250,
    elapsedSeconds: 2700,
  });
});

test("no Watch workouts give empty totals", () => {
  assert.deepEqual(watchTotals([{}]), {
    workouts: 0,
    averageHeartRate: null,
    highestHeartRate: null,
    activeEnergyKcal: 0,
    elapsedSeconds: 0,
  });
});

test("readings leave out what the Watch did not record", () => {
  assert.deepEqual(watchReadings(undefined), []);
  assert.deepEqual(
    watchReadings({ elapsedSeconds: 61, maxHeartRate: 150 }).map((r) => r.key),
    ["time", "max"],
  );
  assert.equal(
    watchReadings({ elapsedSeconds: 1, activeEnergyKcal: 1200 })[1].value,
    `${(1200).toLocaleString()} kcal`,
  );
});
