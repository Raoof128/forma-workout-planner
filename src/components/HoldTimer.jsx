import { Pause, Play, Square, Timer, X } from "lucide-react";
import { formatTime } from "../data";

export const HOLD_MIN = 5;
export const HOLD_MAX = 3600;
export const HOLD_STEP = 5;

const reps = (count) => `${count} ${count === 1 ? "rep" : "reps"}`;

// A settable countdown for one timed set. The workout owns the state; this
// only renders it. Previous/next adjustments change the length before
// starting; while running, the member can pause, end the set early (logging
// the time held) or cancel without logging. `unitSeconds` above 1 means the
// set counts reps of that many seconds (the legacy plank), so the length
// moves in whole reps and ending early logs only the full reps held.
export default function HoldTimer({
  name,
  setNumber,
  length,
  remaining,
  running,
  unitSeconds = 1,
  max = HOLD_MAX,
  onAdjust,
  onStart,
  onPause,
  onResume,
  onEnd,
  onCancel,
}) {
  const active = remaining != null;
  const shown = active ? remaining : length;
  const held = length - (remaining ?? length);
  const progress = active ? Math.min(1, held / length) : 0;
  const step = Math.max(HOLD_STEP, unitSeconds);
  const min = Math.max(HOLD_MIN, unitSeconds);
  const units = Math.floor(held / unitSeconds);
  const logs =
    unitSeconds === 1
      ? `${held} seconds`
      : `${reps(units)} (${units * unitSeconds} seconds)`;
  return (
    <div
      className={`hold-timer${active ? " is-active" : ""}`}
      role="group"
      aria-label={`Hold timer for ${name}`}
    >
      <div className="hold-timer-main">
        <Timer size={18} aria-hidden="true" />
        <div
          className="hold-timer-value"
          role="timer"
          aria-label={`${shown} seconds ${active ? "remaining" : "hold"}`}
        >
          {formatTime(shown)}
        </div>
        {!active && (
          <div className="hold-timer-adjust">
            <button
              type="button"
              className="icon-button"
              aria-label={`Shorter hold, ${Math.max(min, length - step)} seconds`}
              disabled={length <= min}
              onClick={() => onAdjust(-step)}
            >
              −{step}
            </button>
            <button
              type="button"
              className="icon-button"
              aria-label={`Longer hold, ${Math.min(max, length + step)} seconds`}
              disabled={length >= max}
              onClick={() => onAdjust(step)}
            >
              +{step}
            </button>
          </div>
        )}
        <div className="hold-timer-actions">
          {!active && (
            <button
              type="button"
              className="button lime"
              disabled={setNumber == null}
              aria-label={
                setNumber == null
                  ? `All ${name} sets are logged`
                  : `Start ${length}-second hold for ${name} set ${setNumber}`
              }
              onClick={onStart}
            >
              <Play size={16} aria-hidden="true" />
              Start
            </button>
          )}
          {active && (
            <>
              <button
                type="button"
                className="button secondary"
                aria-label={running ? "Pause hold timer" : "Resume hold timer"}
                onClick={running ? onPause : onResume}
              >
                {running ? (
                  <Pause size={16} aria-hidden="true" />
                ) : (
                  <Play size={16} aria-hidden="true" />
                )}
                {running ? "Pause" : "Resume"}
              </button>
              <button
                type="button"
                className="button secondary"
                disabled={units < 1}
                aria-label={`End set ${setNumber} now and log ${logs}`}
                onClick={onEnd}
              >
                <Square size={14} aria-hidden="true" />
                End set
              </button>
              <button
                type="button"
                className="icon-button"
                aria-label="Cancel hold timer without logging"
                onClick={onCancel}
              >
                <X size={18} aria-hidden="true" />
              </button>
            </>
          )}
        </div>
      </div>
      <div className="hold-timer-track" aria-hidden="true">
        <span style={{ transform: `scaleX(${progress})` }} />
      </div>
      <p className="hold-timer-note small muted">
        {setNumber == null
          ? "Every set is logged."
          : active
            ? `Set ${setNumber} logs itself when time is up.`
            : unitSeconds === 1
              ? `Set ${setNumber}: logs the time and starts your rest when it ends.`
              : `Set ${setNumber}: logs a rep for every ${unitSeconds} seconds and starts your rest when it ends.`}
      </p>
    </div>
  );
}
