import { entryKey } from "../routineProgramming.js";
import { useState } from "react";
import HistoryEditor from "./HistoryEditor";
import {
  History,
  ArrowUpRight,
  Check,
  Dumbbell,
  Clock,
  ChartNoAxesColumnIncreasing,
  TrendingUp,
  Trophy,
  Pencil,
  Trash2,
} from "lucide-react";
import { Button, PageHeading, Empty, Modal } from "./UI";
import { measurementText, tracksLoadReps } from "../exerciseMetrics.js";
import "../workout-history.css";
import {
  exercises,
  exerciseById,
  sessionSets,
  sessionVolume,
  formatTime,
  displayDate,
  estimatedOneRM,
} from "../data";

function sessionMeasurements(session) {
  let seconds = 0;
  let metres = 0;
  let lifting = false;
  for (const entry of session.exercises) {
    const exercise = exerciseById.get(entry.exerciseId);
    for (const set of entry.sets) {
      if (!set.done) continue;
      if (tracksLoadReps(exercise)) lifting = true;
      else {
        if (
          exercise?.metric === "duration" ||
          exercise?.metric === "duration_distance"
        )
          seconds += set.durationSeconds || 0;
        if (
          exercise?.metric === "duration_distance" ||
          exercise?.metric === "load_distance"
        )
          metres += set.distanceMeters || 0;
      }
    }
  }
  return { lifting, seconds, metres };
}

function SessionMeasurement({ session }) {
  const { lifting, seconds, metres } = sessionMeasurements(session);
  const value = lifting
    ? `${sessionVolume(session).toLocaleString()} kg`
    : metres
      ? `${metres.toLocaleString()} m`
      : `${seconds.toLocaleString()} sec`;
  return (
    <span className="journal-measurement">
      <strong>{value}</strong>
      <small>
        {lifting
          ? "Lifting volume"
          : metres
            ? seconds
              ? `${seconds.toLocaleString()} sec logged`
              : "Distance logged"
            : "Time logged"}
      </small>
    </span>
  );
}

export function WorkoutHistory({ history, onStart, onSave, onDelete }) {
  const [detail, setDetail] = useState(null);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const sorted = [...history].sort(
    (a, b) => Date.parse(b.date) - Date.parse(a.date),
  );
  const months = new Map();
  for (const session of sorted) {
    const month = displayDate(session.date, { month: "long", year: "numeric" });
    if (!months.has(month)) months.set(month, []);
    months.get(month).push(session);
  }
  const totalSets = history.reduce(
    (total, session) => total + sessionSets(session),
    0,
  );
  const totalMinutes = Math.round(
    history.reduce((total, session) => total + session.duration, 0) / 60,
  );
  const detailMeasurements = detail ? sessionMeasurements(detail) : null;
  const detailExercises = detail
    ? detail.exercises.filter((entry) => entry.sets.some((set) => set.done))
    : [];
  return (
    <div className="history-journal">
      <PageHeading
        eyebrow="The work you put in"
        title="Every session counts."
        subtitle="A record of your effort. A reminder of how far you’ve come."
      />
      {!history.length ? (
        <div className="journal-empty panel">
          <span className="journal-kicker">Your training journal</span>
          <Empty
            icon={History}
            title="Your story starts with a session."
            description="Finish your first workout and it will appear here, with every completed set and measurement."
          >
            <Button variant="lime" onClick={onStart}>
              Start your first workout <ArrowUpRight size={17} />
            </Button>
          </Empty>
          <div className="journal-empty-footer">
            <span>Every set.</span>
            <span>Every session.</span>
            <span>All your effort.</span>
          </div>
        </div>
      ) : (
        <>
          <section
            className="journal-summary"
            aria-label="Workout history summary"
          >
            <div className="journal-summary-intro">
              <span className="journal-kicker">Your training journal</span>
              <h2>The work adds up.</h2>
              <p>Completed sessions, kept in one place.</p>
            </div>
            <dl>
              <div>
                <dt>Sessions logged</dt>
                <dd>{history.length.toLocaleString()}</dd>
              </div>
              <div>
                <dt>Sets completed</dt>
                <dd>{totalSets.toLocaleString()}</dd>
              </div>
              <div>
                <dt>Minutes trained</dt>
                <dd>{totalMinutes.toLocaleString()}</dd>
              </div>
            </dl>
          </section>
          <div className="journal-archive-heading">
            <h2>Session archive</h2>
            <span>Latest first · Select a session to review</span>
          </div>
          {[...months].map(([month, sessions]) => (
            <section className="journal-month" key={month} aria-label={month}>
              <div className="journal-month-heading">
                <h3>{month}</h3>
                <span>
                  {sessions.length}{" "}
                  {sessions.length === 1 ? "session" : "sessions"}
                </span>
              </div>
              <div className="history-list">
                {sessions.map((s) => (
                  <button
                    key={s.id}
                    className="history-row panel journal-row"
                    onClick={() => setDetail(s)}
                  >
                    <span className="history-date">
                      <strong>{displayDate(s.date, { day: "numeric" })}</strong>
                      <span>
                        {displayDate(s.date, {
                          month: "short",
                        })}
                      </span>
                    </span>
                    <div className="journal-session-title">
                      <h3>{s.name}</h3>
                      <p>
                        {displayDate(s.date, {
                          weekday: "long",
                          year: "numeric",
                          month: "long",
                          day: "numeric",
                        })}
                      </p>
                    </div>
                    <div className="journal-session-metrics">
                      <span>
                        <Clock size={15} aria-hidden="true" />
                        {formatTime(s.duration)}
                        <small>Duration</small>
                      </span>
                      <span>
                        <Dumbbell size={15} aria-hidden="true" />
                        {sessionSets(s)} {sessionSets(s) === 1 ? "set" : "sets"}
                        <small>Completed</small>
                      </span>
                      <SessionMeasurement session={s} />
                    </div>
                    <span className="journal-row-arrow" aria-hidden="true">
                      <ArrowUpRight size={19} />
                    </span>
                  </button>
                ))}
              </div>
            </section>
          ))}
          <p className="journal-footnote">
            Lifting volume counts completed weight × rep sets. Time and distance
            stay in their own units.
          </p>
        </>
      )}
      {detail && !editing && (
        <Modal
          title={deleting ? "Delete this workout?" : "Workout complete"}
          onClose={() => {
            if (deleting) setDeleting(false);
            else setDetail(null);
          }}
          wide
        >
          {deleting ? (
            <div className="modal-content">
              <p>
                This removes the workout and recalculates your progress. Your
                routines stay unchanged.
              </p>
              <div className="modal-actions">
                <Button variant="secondary" onClick={() => setDeleting(false)}>
                  Keep workout
                </Button>
                <Button
                  variant="danger-solid"
                  onClick={async () => {
                    if (await onDelete(detail)) {
                      setDeleting(false);
                      setDetail(null);
                    }
                  }}
                >
                  Delete workout
                </Button>
              </div>
            </div>
          ) : (
            <div className="modal-content journal-detail">
              <div className="journal-detail-heading">
                <div className="success-mark">
                  <Check size={25} />
                </div>
                <span className="journal-kicker">Session recorded</span>
              </div>
              <h2 className="journal-detail-title">{detail.name}</h2>
              <p className="muted">
                {displayDate(detail.date, {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                  year: "numeric",
                })}
              </p>
              <div className="detail-meta journal-detail-meta">
                <span>
                  <strong>{formatTime(detail.duration)}</strong>
                  <small>Duration</small>
                </span>
                <span>
                  <strong>{sessionSets(detail)} sets</strong>
                  <small>Completed</small>
                </span>
                <SessionMeasurement session={detail} />
              </div>
              {!detailMeasurements.lifting && (
                <p className="journal-metric-note">
                  Time and distance are recorded below and do not count as
                  lifting volume.
                </p>
              )}
              <div className="journal-detail-section-heading">
                <h3>Completed exercises</h3>
                <span>
                  {detailExercises.length}{" "}
                  {detailExercises.length === 1 ? "movement" : "movements"}
                </span>
              </div>
              {detailExercises.map((e) => (
                <div className="history-exercise" key={entryKey(e)}>
                  <strong>
                    {exerciseById.get(e.exerciseId)?.name || e.exerciseId}
                  </strong>
                  <p>
                    {e.sets
                      .filter((s) => s.done)
                      .map((s, i) => (
                        <span key={i}>
                          {measurementText(exerciseById.get(e.exerciseId), s)}
                          {s.rpe != null && ` · RPE ${s.rpe}`}
                        </span>
                      ))}
                  </p>
                </div>
              ))}
              {detail.notes && (
                <div className="tip journal-notes">
                  <span className="journal-kicker">Session notes</span>
                  <p>{detail.notes}</p>
                </div>
              )}
              <div className="modal-actions">
                <Button variant="secondary" onClick={() => setDeleting(true)}>
                  <Trash2 size={16} />
                  Delete workout
                </Button>
                <Button variant="lime" onClick={() => setEditing(true)}>
                  <Pencil size={16} />
                  Edit workout
                </Button>
              </div>
            </div>
          )}
        </Modal>
      )}
      {detail && editing && (
        <HistoryEditor
          session={detail}
          onClose={() => setEditing(false)}
          onSave={async (next, original) => {
            if (await onSave(next, original)) {
              setDetail(next);
              setEditing(false);
              return true;
            }
            return false;
          }}
        />
      )}
    </div>
  );
}
export function Progress({ history, onStart }) {
  const volume = history.reduce((n, s) => n + sessionVolume(s), 0);
  const sets = history.reduce((n, s) => n + sessionSets(s), 0);
  const records = exercises
    .filter(tracksLoadReps)
    .map((e) => {
      const done = history.flatMap((s) =>
        s.exercises
          .filter((x) => x.exerciseId === e.id)
          .flatMap((x) => x.sets.filter((s) => s.done)),
      );
      return {
        ...e,
        maxWeight: done.reduce((max, set) => Math.max(max, set.weight), 0),
        oneRM: done.reduce(
          (max, set) =>
            set.reps <= 12
              ? Math.max(max, estimatedOneRM(set.weight, set.reps))
              : max,
          0,
        ),
        sets: done.length,
      };
    })
    .filter((e) => e.sets > 0);
  const recent = [...history]
    .sort((a, b) => Date.parse(a.date) - Date.parse(b.date))
    .slice(-8);
  const maxVolume = Math.max(1, ...recent.map(sessionVolume));
  return (
    <>
      <PageHeading
        eyebrow="Built one session at a time"
        title="See your strength take shape."
        subtitle="Small steps add up. Here’s the work you’ve put in."
      />
      <div className="progress-stats">
        {[
          [Dumbbell, history.length, "Workouts completed"],
          [
            ChartNoAxesColumnIncreasing,
            volume.toLocaleString(),
            "Total volume · kg",
          ],
          [Check, sets, "Sets completed"],
        ].map(([Icon, value, label]) => (
          <div className="panel progress-stat" key={label}>
            <Icon size={21} />
            <strong>{value}</strong>
            <span>{label}</span>
          </div>
        ))}
      </div>
      {!history.length ? (
        <Empty
          icon={TrendingUp}
          title="Progress begins with showing up."
          description="Log your first session to start tracking training volume and personal bests."
        >
          <Button variant="lime" onClick={onStart}>
            Let’s get started <ArrowUpRight size={17} />
          </Button>
        </Empty>
      ) : (
        <>
          <section className="panel progress-chart">
            <div className="section-title">
              <div>
                <h2>Training volume</h2>
                <p className="muted small">
                  Completed sets × weight × reps per session
                </p>
              </div>
              <span className="small muted">
                Last {recent.length}{" "}
                {recent.length === 1 ? "session" : "sessions"}
              </span>
            </div>
            <div className="volume-chart">
              {recent.map((s) => (
                <div key={s.id}>
                  <strong>{sessionVolume(s).toLocaleString()}</strong>
                  <div
                    className="volume-bar"
                    style={{
                      height: `${Math.max(0, (150 * sessionVolume(s)) / maxVolume)}px`,
                    }}
                  />
                  <span>
                    {displayDate(s.date, {
                      month: "short",
                      day: "numeric",
                    })}
                  </span>
                </div>
              ))}
            </div>
          </section>
          <section className="panel records">
            <div className="section-title">
              <h2>Personal bests</h2>
              <Trophy size={20} />
            </div>
            <p className="muted small">
              Single reps use the actual load. Other estimates use the Epley
              formula for 2–12 reps.
            </p>
            <table aria-label="Personal bests by exercise">
              <thead>
                <tr className="record-row record-labels">
                  <th scope="col">EXERCISE</th>
                  <th scope="col">MAX WEIGHT</th>
                  <th scope="col">EST. 1RM</th>
                </tr>
              </thead>
              <tbody>
                {records.map((e) => (
                  <tr className="record-row" key={e.id}>
                    <th scope="row">{e.name}</th>
                    <td>{e.maxWeight} kg</td>
                    <td>
                      {e.oneRM ? `${Math.round(e.oneRM * 10) / 10} kg` : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        </>
      )}
    </>
  );
}
