import { Flame, Heart, HeartPulse, Timer, Watch } from "lucide-react";
import { formatTime } from "../data";
import { watchReadings, watchTotals } from "../watchSummary.js";
import "../watch-summary.css";

const icons = { time: Timer, average: Heart, max: HeartPulse, energy: Flame };

/** What the Apple Watch recorded for one workout, in its details. */
export function WatchSummaryPanel({ watch }) {
  const readings = watchReadings(watch);
  if (!readings.length) return null;
  return (
    <section className="watch-summary" aria-labelledby="watch-summary-title">
      <h3 id="watch-summary-title">
        <Watch size={16} aria-hidden="true" />
        Collected by Apple Watch
      </h3>
      <dl>
        {readings.map(({ key, label, value, seconds }) => {
          const Icon = icons[key];
          return (
            <div key={key}>
              <dt>{label}</dt>
              <dd>
                <Icon size={15} aria-hidden="true" />
                {value ?? formatTime(seconds)}
              </dd>
            </div>
          );
        })}
      </dl>
      <p>Recorded on the iPhone app and also saved in Apple Health.</p>
    </section>
  );
}

/** A small marker on journal rows for workouts the Watch recorded. */
export function WatchBadge({ watch }) {
  if (!watch) return null;
  return (
    <span className="watch-badge">
      <Watch size={13} aria-hidden="true" />
      {watch.averageHeartRate !== undefined
        ? `${watch.averageHeartRate} bpm avg`
        : "Apple Watch"}
      <span className="sr-only">, recorded by Apple Watch</span>
    </span>
  );
}

/** Progress: totals across every workout the Watch recorded. */
export function WatchTotalsPanel({ history }) {
  const totals = watchTotals(history);
  if (!totals.workouts) return null;
  return (
    <section
      className="panel watch-totals"
      aria-labelledby="watch-totals-title"
    >
      <div className="section-title">
        <div>
          <h2 id="watch-totals-title">From your Apple Watch</h2>
          <p className="muted small">
            {totals.workouts} {totals.workouts === 1 ? "workout" : "workouts"}{" "}
            recorded on the iPhone app
          </p>
        </div>
        <Watch size={20} aria-hidden="true" />
      </div>
      <dl>
        {totals.averageHeartRate !== null && (
          <div>
            <dt>Average heart rate</dt>
            <dd>{totals.averageHeartRate} bpm</dd>
          </div>
        )}
        {totals.highestHeartRate !== null && (
          <div>
            <dt>Highest heart rate</dt>
            <dd>{totals.highestHeartRate} bpm</dd>
          </div>
        )}
        <div>
          <dt>Active energy</dt>
          <dd>{totals.activeEnergyKcal.toLocaleString()} kcal</dd>
        </div>
        <div>
          <dt>Recorded time</dt>
          <dd>{Math.round(totals.elapsedSeconds / 60).toLocaleString()} min</dd>
        </div>
      </dl>
    </section>
  );
}
