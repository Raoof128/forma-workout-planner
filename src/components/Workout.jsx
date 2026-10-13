import { useEffect, useState, useEffectEvent } from "react";
import {
  Check,
  Plus,
  Timer,
  Pause,
  Play,
  SkipForward,
  Flag,
  ChevronLeft,
  Trash2,
  Dumbbell,
  BookOpen,
} from "lucide-react";
import { Button, PageHeading, Modal } from "./UI";
import ExerciseGuide from "./ExerciseGuide";
import SavedField from "./SavedField";
import { exercises, formatTime, sessionSets, sessionVolume } from "../data";
import { metricFields, validMeasurement } from "../exerciseMetrics.js";
export default function Workout({
  session,
  onUpdate,
  onFinish,
  onCancel,
  onBack,
  notify,
}) {
  const [now, setNow] = useState(() => Date.now());
  const [confirm, setConfirm] = useState(false);
  const [guide, setGuide] = useState(null);
  const [saving, setSaving] = useState(false);
  const [restOpen, setRestOpen] = useState(false);
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(timer);
  }, []);
  const remaining = session.restEnd
    ? Math.max(0, Math.ceil((session.restEnd - now) / 1000))
    : session.restPaused || 0;
  const endRest = useEffectEvent(() => {
    const expected = session.restEnd;
    void onUpdate((current) =>
      current.restEnd === expected
        ? { ...current, restEnd: null, restPaused: null }
        : current,
    );
    notify("Rest complete. Ready for your next set.");
  });
  useEffect(() => {
    if (session.restEnd && remaining === 0) endRest();
  }, [session.restEnd, remaining]);
  const elapsed = Math.max(0, Math.floor((now - session.startedAt) / 1000));
  const complete = sessionSets(session);
  const total = session.exercises.reduce(
    (sum, item) => sum + item.sets.length,
    0,
  );
  function updateSet(exerciseId, index, key, value) {
    void onUpdate((current) => ({
      ...current,
      exercises: current.exercises.map((item) =>
        item.exerciseId !== exerciseId
          ? item
          : {
              ...item,
              sets: item.sets.map((set, si) =>
                si !== index || set.done ? set : { ...set, [key]: value },
              ),
            },
      ),
    }));
  }
  function check(exerciseId, index) {
    const set = session.exercises.find((item) => item.exerciseId === exerciseId)
      .sets[index];
    if (
      !set.done &&
      !validMeasurement(
        exercises.find((item) => item.id === exerciseId),
        set,
      )
    ) {
      const exercise = exercises.find((item) => item.id === exerciseId);
      notify(
        !exercise?.metric || exercise.metric === "load_reps"
          ? "Enter 1–100 reps and a weight from 0–1,000 kg."
          : "Enter valid measurements in the units shown before completing the set.",
      );
      return;
    }
    const expected = set.done;
    void onUpdate((current) => {
      const latest = current.exercises.find(
        (item) => item.exerciseId === exerciseId,
      ).sets[index];
      if (latest.done !== expected)
        throw new Error(
          "This set changed in another tab. Check its latest state before changing it.",
        );
      return {
        ...current,
        ...(!expected
          ? {
              restEnd: Date.now() + (current.restSeconds || 90) * 1000,
              restPaused: null,
            }
          : {}),
        exercises: current.exercises.map((item) =>
          item.exerciseId !== exerciseId
            ? item
            : {
                ...item,
                sets: item.sets.map((value, si) =>
                  si !== index ? value : { ...value, done: !expected },
                ),
              },
        ),
      };
    });
  }
  function finish() {
    if (!complete) notify("Complete at least one set to save your workout.");
    else setConfirm(true);
  }
  return (
    <>
      <button className="text-button back-link" onClick={onBack}>
        <ChevronLeft size={16} />
        Back to overview · workout stays active
      </button>
      <PageHeading
        title={session.name}
        subtitle="One set at a time. You’ve got this."
      >
        <Button variant="lime" onClick={finish}>
          <Flag size={17} />
          Finish workout
        </Button>
      </PageHeading>
      <div className="session-stats panel">
        <div>
          <span>ELAPSED TIME</span>
          <strong>{formatTime(elapsed)}</strong>
        </div>
        <div>
          <span>SETS COMPLETED</span>
          <strong>
            {complete}
            <small> / {total}</small>
          </strong>
        </div>
        <div>
          <span>VOLUME LIFTED</span>
          <strong>
            {sessionVolume(session).toLocaleString()}
            <small> kg</small>
          </strong>
        </div>
      </div>
      <div className="mobile-rest-bar">
        <button
          className="text-button"
          onClick={() => setRestOpen(true)}
          aria-label="Open rest timer"
        >
          <Timer size={18} />
          <span>
            Rest <strong>{formatTime(remaining)}</strong>
          </span>
        </button>
        <Button
          variant="secondary"
          onClick={() =>
            void onUpdate((current) => ({
              ...current,
              restEnd: null,
              restPaused: null,
            }))
          }
        >
          <SkipForward size={16} />
          Skip rest
        </Button>
      </div>
      <div className="workout-layout">
        <div className="workout-exercises">
          {session.exercises.map((entry) => {
            const exercise = exercises.find(
              (item) => item.id === entry.exerciseId,
            );
            return (
              <section className="panel log-exercise" key={entry.exerciseId}>
                <header>
                  <div className="exercise-icon">
                    <Dumbbell size={21} />
                  </div>
                  <div>
                    <h3>{exercise.name}</h3>
                    <p>
                      {exercise.muscle} · {exercise.equipment}
                    </p>
                  </div>
                  <button
                    className="icon-button"
                    aria-label={`Instructions for ${exercise.name}`}
                    onClick={() => setGuide(exercise)}
                  >
                    <BookOpen size={19} />
                  </button>
                  <span className="count-label">
                    {entry.sets.filter((set) => set.done).length}/
                    {entry.sets.length}
                  </span>
                </header>
                {exercise.id === "plank" && (
                  <p className="movement-note">
                    One rep = a 10-second hold. For a 30-second plank, enter 3
                    reps.
                  </p>
                )}
                <div className="set-row set-labels">
                  <span>SET</span>
                  {metricFields(exercise).map((field) => (
                    <span key={field.key}>{field.label}</span>
                  ))}
                  <span>DONE</span>
                </div>
                {entry.sets.map((set, index) => (
                  <div
                    className={`set-row ${set.done ? "set-done" : ""}`}
                    key={index}
                  >
                    <span>{index + 1}</span>
                    {metricFields(exercise).map((field) => (
                      <SavedField
                        key={field.key}
                        type="number"
                        disabled={set.done}
                        aria-label={`${exercise.name} set ${index + 1} ${field.key}`}
                        min={field.min}
                        max={field.max}
                        step={field.step}
                        value={set[field.key] ?? ""}
                        onChange={(event) =>
                          updateSet(
                            exercise.id,
                            index,
                            field.key,
                            event.target.value === ""
                              ? ""
                              : Number(event.target.value),
                          )
                        }
                      />
                    ))}
                    <button
                      aria-label={`${set.done ? "Uncomplete" : "Complete"} ${exercise.name} set ${index + 1}`}
                      aria-pressed={set.done}
                      className="check-set"
                      onClick={() => check(exercise.id, index)}
                    >
                      {set.done ? (
                        <Check size={18} />
                      ) : (
                        <span aria-hidden="true" className="unchecked-set" />
                      )}
                    </button>
                  </div>
                ))}
                <button
                  className="add-set"
                  disabled={entry.sets.length >= 100}
                  onClick={() =>
                    void onUpdate((current) => ({
                      ...current,
                      exercises: current.exercises.map((item) =>
                        item.exerciseId !== exercise.id
                          ? item
                          : {
                              ...item,
                              sets: [
                                ...item.sets,
                                { ...item.sets.at(-1), done: false },
                              ],
                            },
                      ),
                    }))
                  }
                >
                  <Plus size={16} />
                  Add set
                </button>
              </section>
            );
          })}
          <Button variant="lime" className="finish-bottom" onClick={finish}>
            <Flag size={17} />
            Finish workout
          </Button>
        </div>
        <aside className="workout-aside">
          <div className="panel desktop-rest">
            <RestControls
              session={session}
              remaining={remaining}
              onUpdate={onUpdate}
            />
          </div>
          <section className="panel notes-panel">
            <h3>Session notes</h3>
            <SavedField
              as="textarea"
              aria-label="Session notes"
              maxLength={10000}
              placeholder="How are you feeling today?"
              value={session.notes}
              onChange={(event) => {
                const notes = event.target.value;
                void onUpdate((current) => ({ ...current, notes }));
              }}
            />
          </section>
          <button className="text-button danger discard" onClick={onCancel}>
            <Trash2 size={16} />
            Discard workout
          </button>
        </aside>
      </div>
      {restOpen && (
        <Modal title="Rest timer" onClose={() => setRestOpen(false)}>
          <RestControls
            session={session}
            remaining={remaining}
            onUpdate={onUpdate}
          />
        </Modal>
      )}
      {guide && (
        <ExerciseGuide exercise={guide} onClose={() => setGuide(null)} />
      )}{" "}
      {confirm && (
        <Modal
          title="Finish strong."
          onClose={() => !saving && setConfirm(false)}
        >
          <div className="modal-content">
            <p>
              You completed{" "}
              <strong>
                {complete} {complete === 1 ? "set" : "sets"}
              </strong>{" "}
              and lifted{" "}
              <strong>{sessionVolume(session).toLocaleString()} kg</strong>.{" "}
              {complete < total
                ? `${total - complete} unfinished sets will not count toward your progress.`
                : "Every planned set, done."}
            </p>
            <div className="modal-actions">
              <Button
                variant="secondary"
                disabled={saving}
                onClick={() => setConfirm(false)}
              >
                Keep training
              </Button>
              <Button
                variant="lime"
                disabled={saving}
                onClick={async () => {
                  setSaving(true);
                  try {
                    await onFinish(elapsed);
                  } finally {
                    setSaving(false);
                  }
                }}
              >
                <Check size={17} />
                {saving ? "Saving…" : "Save workout"}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </>
  );
}

function RestControls({ session, remaining, onUpdate }) {
  function startRest(seconds) {
    // Start at the action, not when an asynchronous save queue processes it.
    const deadline = Date.now() + seconds * 1000;
    void onUpdate((current) => ({
      ...current,
      restSeconds: seconds,
      restEnd: deadline,
      restPaused: null,
    }));
  }
  return (
    <section className="rest-panel">
      <div className="section-title">
        <h3>Rest timer</h3>
        <Timer size={19} />
      </div>
      <div
        className="timer-value"
        role="timer"
        aria-label={`${remaining} seconds remaining`}
      >
        {formatTime(remaining)}
      </div>
      <p>
        {remaining
          ? "Breathe. Reset. Go again."
          : "Take a moment between sets."}
      </p>
      <div className="timer-options" aria-label="Rest duration">
        {[60, 90, 120].map((seconds) => (
          <button
            key={seconds}
            aria-pressed={(session.restSeconds || 90) === seconds}
            onClick={() => startRest(seconds)}
          >
            {seconds}s
          </button>
        ))}
      </div>
      <p className="rest-preference">
        {session.restSeconds || 90} seconds after each completed set
      </p>
      <div className="timer-actions">
        <Button
          aria-label={session.restEnd ? "Pause rest timer" : "Start rest timer"}
          variant="secondary"
          onClick={() =>
            void onUpdate((current) =>
              current.restEnd
                ? {
                    ...current,
                    restPaused: Math.min(
                      600,
                      Math.max(
                        0,
                        Math.ceil((current.restEnd - Date.now()) / 1000),
                      ),
                    ),
                    restEnd: null,
                  }
                : {
                    ...current,
                    restEnd:
                      Date.now() +
                      (current.restPaused || current.restSeconds || 90) * 1000,
                    restPaused: null,
                  },
            )
          }
        >
          {session.restEnd ? <Pause size={16} /> : <Play size={16} />}
        </Button>
        <Button
          variant="secondary"
          onClick={() =>
            void onUpdate((current) => ({
              ...current,
              restEnd: null,
              restPaused: null,
            }))
          }
        >
          <SkipForward size={16} />
          Skip
        </Button>
      </div>
    </section>
  );
}
