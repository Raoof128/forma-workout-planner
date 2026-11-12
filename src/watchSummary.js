// What an Apple Watch recorded, for the journal and Progress. The iPhone writes
// `session.watch` (see watchSummarySchema in storage.js); the browser only reads
// it. FORMACore's `WatchTotals` gives the same numbers on the iPhone.

/** Totals across every finished workout the Watch recorded. */
export function watchTotals(history) {
  let workouts = 0;
  let weighted = 0;
  let weightedSeconds = 0;
  let highestHeartRate = null;
  let activeEnergyKcal = 0;
  let elapsedSeconds = 0;
  for (const session of history) {
    const watch = session.watch;
    if (!watch) continue;
    workouts += 1;
    elapsedSeconds += watch.elapsedSeconds;
    activeEnergyKcal += watch.activeEnergyKcal ?? 0;
    if (watch.averageHeartRate !== undefined && watch.elapsedSeconds > 0) {
      weighted += watch.averageHeartRate * watch.elapsedSeconds;
      weightedSeconds += watch.elapsedSeconds;
    }
    if (watch.maxHeartRate !== undefined)
      highestHeartRate = Math.max(highestHeartRate ?? 0, watch.maxHeartRate);
  }
  return {
    workouts,
    averageHeartRate: weightedSeconds
      ? Math.round(weighted / weightedSeconds)
      : null,
    highestHeartRate,
    activeEnergyKcal,
    elapsedSeconds,
  };
}

/** The readings one summary has, in display order. Missing ones are left out. */
export function watchReadings(watch) {
  if (!watch) return [];
  const readings = [
    { key: "time", label: "Recorded time", seconds: watch.elapsedSeconds },
  ];
  if (watch.averageHeartRate !== undefined)
    readings.push({
      key: "average",
      label: "Average heart rate",
      value: `${watch.averageHeartRate} bpm`,
    });
  if (watch.maxHeartRate !== undefined)
    readings.push({
      key: "max",
      label: "Highest heart rate",
      value: `${watch.maxHeartRate} bpm`,
    });
  if (watch.activeEnergyKcal !== undefined)
    readings.push({
      key: "energy",
      label: "Active energy",
      value: `${watch.activeEnergyKcal.toLocaleString()} kcal`,
    });
  return readings;
}
