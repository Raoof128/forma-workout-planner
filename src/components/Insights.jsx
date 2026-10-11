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
import {
  exercises,
  sessionSets,
  sessionVolume,
  formatTime,
  displayDate,
  estimatedOneRM,
} from "../data";
export function WorkoutHistory({ history, onStart, onSave, onDelete }) {
  const [detail, setDetail] = useState(null);
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  return (
    <>
      <PageHeading
        title="Every session counts."
        subtitle="A record of your effort. A reminder of how far you’ve come."
      />
      {!history.length ? (
        <Empty
          icon={History}
          title="Your story starts with a session."
          description="Finish your first workout and it will appear here, with every set and rep."
        >
          <Button variant="lime" onClick={onStart}>
            Start your first workout <ArrowUpRight size={17} />
          </Button>
        </Empty>
      ) : (
        <div className="history-list">
          {history.map((s) => (
            <button
              key={s.id}
              className="history-row panel"
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
              <div>
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
              <span>
                <Clock size={16} />
                {formatTime(s.duration)}
              </span>
              <span>
                <Dumbbell size={16} />
                {sessionSets(s)} {sessionSets(s) === 1 ? "set" : "sets"}
              </span>
              <span className="volume">
                {sessionVolume(s).toLocaleString()} kg
              </span>
              <ArrowUpRight size={19} />
            </button>
          ))}
        </div>
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
            <div className="modal-content">
              <div className="success-mark">
                <Check size={28} />
              </div>
              <h2>{detail.name}</h2>
              <p className="muted">
                {displayDate(detail.date, {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                  year: "numeric",
                })}
              </p>
              <div className="detail-meta">
                <span>{formatTime(detail.duration)} duration</span>
                <span>{sessionSets(detail)} sets</span>
                <span>{sessionVolume(detail).toLocaleString()} kg volume</span>
              </div>
              {detail.exercises
                .filter((e) => e.sets.some((s) => s.done))
                .map((e) => (
                  <div className="history-exercise" key={e.exerciseId}>
                    <strong>
                      {exercises.find((x) => x.id === e.exerciseId)?.name ||
                        e.exerciseId}
                    </strong>
                    <p>
                      {e.sets
                        .filter((s) => s.done)
                        .map((s, i) => (
                          <span key={i}>
                            {s.weight} kg × {s.reps}
                          </span>
                        ))}
                    </p>
                  </div>
                ))}
              {detail.notes && (
                <div className="tip">
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
    </>
  );
}
export function Progress({ history, onStart }) {
  const volume = history.reduce((n, s) => n + sessionVolume(s), 0);
  const sets = history.reduce((n, s) => n + sessionSets(s), 0);
  const records = exercises
    .map((e) => {
      const done = history.flatMap((s) =>
        s.exercises
          .filter((x) => x.exerciseId === e.id)
          .flatMap((x) => x.sets.filter((s) => s.done)),
      );
      return {
        ...e,
        maxWeight: Math.max(0, ...done.map((s) => Number(s.weight))),
        oneRM: Math.max(
          0,
          ...done
            .filter((s) => s.reps <= 12)
            .map((s) => estimatedOneRM(s.weight, s.reps)),
        ),
        sets: done.length,
      };
    })
    .filter((e) => e.sets > 0);
  const recent = [...history].reverse().slice(-8);
  return (
    <>
      <PageHeading
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
                      height: `${Math.max(0, (150 * sessionVolume(s)) / Math.max(1, ...recent.map(sessionVolume)))}px`,
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
            <div className="record-row record-labels">
              <span>EXERCISE</span>
              <span>MAX WEIGHT</span>
              <span>EST. 1RM</span>
            </div>
            {records.map((e) => (
              <div className="record-row" key={e.id}>
                <strong>{e.name}</strong>
                <span>{e.maxWeight} kg</span>
                <span>
                  {e.oneRM ? `${Math.round(e.oneRM * 10) / 10} kg` : "—"}
                </span>
              </div>
            ))}
          </section>
        </>
      )}
    </>
  );
}
