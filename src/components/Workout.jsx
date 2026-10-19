import { useEffect, useState, useEffectEvent, useRef } from "react";
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
  Minus,
  ArrowUp,
  ArrowDown,
  ArrowLeftRight,
} from "lucide-react";
import { Button, PageHeading, Modal } from "./UI";
import ExerciseGuide from "./ExerciseGuide";
import SavedField from "./SavedField";
import ActionsMenu from "./ActionsMenu";
import ExercisePicker from "./ExercisePicker";
import { exerciseById, formatTime, sessionSets, sessionVolume } from "../data";
import {
  logsSides,
  readSetValue,
  setFields,
  validMeasurement,
} from "../exerciseMetrics.js";
import {
  addedEntry,
  moveEntry,
  removeEntry,
  replaceEntry,
  setsLostByReplacing,
  updateSetValue,
} from "../workoutSession.js";
import {
  entryKey,
  repsText,
  groupLabels,
  shouldRest,
  restRemaining,
  adjustRest,
  toggleRest,
} from "../routineProgramming.js";
export default function Workout({
  session,
  muted = false,
  fillSets = true,
  onFillSets,
  onUpdate,
  onFinish,
  onCancel,
  onBack,
  notify,
}) {
  const announcedEnd = useRef(null);
  const invalidDrafts = useRef(new Set());
  const audio = useRef(null);
  function prepareCue() {
    if (muted) return;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return;
    try {
      audio.current ??= new Audio();
      void audio.current.resume().catch(() => {});
    } catch {
      /* Sound is optional on unsupported devices. */
    }
  }
  useEffect(
    () => () => {
      void audio.current?.close().catch(() => {});
    },
    [],
  );
  const [now, setNow] = useState(() => Date.now());
  const [confirm, setConfirm] = useState(false);
  const [guide, setGuide] = useState(null);
  const [saving, setSaving] = useState(false);
  const [restOpen, setRestOpen] = useState(false);
  // { mode: "add" } or { mode: "replace", key } while the exercise picker is open.
  const [picker, setPicker] = useState(null);
  // A change that would discard completed sets waits here for confirmation.
  const [pending, setPending] = useState(null);
  // The toggle flips at once; the profile save follows and wins if it fails.
  const [fill, setFill] = useState(fillSets);
  useEffect(() => {
    setFill(fillSets);
  }, [fillSets]);
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 250);
    const refresh = () => setNow(Date.now());
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      clearInterval(timer);
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, []);
  const remaining = restRemaining(session, now);
  const endRest = useEffectEvent(() => {
    const expected = session.restEnd;
    if (announcedEnd.current === expected) return;
    announcedEnd.current = expected;
    try {
      navigator.vibrate?.([150, 80, 150]);
    } catch {
      /* Optional device capability. */
    }
    if (!muted && audio.current?.state === "running") {
      const oscillator = audio.current.createOscillator();
      const gain = audio.current.createGain();
      oscillator.frequency.value = 880;
      gain.gain.setValueAtTime(0.15, audio.current.currentTime);
      gain.gain.exponentialRampToValueAtTime(
        0.001,
        audio.current.currentTime + 0.3,
      );
      oscillator.connect(gain);
      gain.connect(audio.current.destination);
      oscillator.start();
      oscillator.stop(audio.current.currentTime + 0.3);
    }
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
  function updateSet(rowKey, index, key, value) {
    const entry = session.exercises.find((item) => entryKey(item) === rowKey);
    const field =
      key === "rpe"
        ? { min: 1, max: 10, step: 0.5 }
        : setFields(exerciseById.get(entry.exerciseId), entry).find(
            (field) => field.key === key,
          );
    const draftKey = JSON.stringify([rowKey, index, key]);
    const valid =
      value === "" ||
      value === null ||
      (typeof value === "number" &&
        Number.isFinite(value) &&
        value >= field.min &&
        value <= field.max &&
        (field.step === "any" || Number.isInteger(value / Number(field.step))));
    if (!valid) {
      invalidDrafts.current.add(draftKey);
      return;
    }
    invalidDrafts.current.delete(draftKey);
    // Measurements can flow on to the remaining sets; RPE is always per set.
    const follow = fill && key !== "rpe";
    void onUpdate((current) => ({
      ...current,
      exercises: current.exercises.map((item) =>
        entryKey(item) !== rowKey
          ? item
          : updateSetValue(item, index, key, value, { fill: follow }),
      ),
    }));
  }
  function changeSets(rowKey, change) {
    void onUpdate((current) => ({
      ...current,
      exercises: current.exercises.map((item) =>
        entryKey(item) !== rowKey ? item : { ...item, sets: change(item.sets) },
      ),
    }));
  }
  function check(rowKey, index) {
    const entry = session.exercises.find((item) => entryKey(item) === rowKey);
    const exerciseId = entry.exerciseId;
    const set = entry.sets[index];
    prepareCue();
    const clickedAt = Date.now();
    if (
      !set.done &&
      invalidDrafts.current.has(JSON.stringify([rowKey, index, "rpe"]))
    ) {
      notify("Enter RPE from 1–10 in half steps, or clear it.");
      return;
    }
    const invalid = [...invalidDrafts.current].some((key) => {
      const [row, si] = JSON.parse(key);
      return row === rowKey && si === index;
    });
    const exercise = exerciseById.get(exerciseId);
    const measurementMessage = logsSides(exercise, entry)
      ? "Enter 1–50 reps for the left and the right side and a weight from 0–1,000 kg."
      : !exercise?.metric || exercise.metric === "load_reps"
        ? "Enter 1–100 reps and a weight from 0–1,000 kg."
        : "Enter valid measurements in the units shown before completing the set.";
    if (!set.done && (invalid || !validMeasurement(exercise, set))) {
      notify(measurementMessage);
      return;
    }
    const expected = set.done;
    void onUpdate((current) => {
      const latest = current.exercises.find((item) => entryKey(item) === rowKey)
        .sets[index];
      if (latest.done !== expected)
        throw new Error(
          "This set changed in another tab. Check its latest state before changing it.",
        );
      // A value typed an instant ago may only land here; keep the same advice.
      if (!expected && !validMeasurement(exercise, latest))
        throw new Error(measurementMessage);
      return {
        ...current,
        ...(!expected &&
        shouldRest(
          current.exercises,
          current.exercises.findIndex((item) => entryKey(item) === rowKey),
        )
          ? {
              restEnd:
                clickedAt +
                (current.exercises.find((item) => entryKey(item) === rowKey)
                  .restSeconds ??
                  current.restSeconds ??
                  90) *
                  1000,
              restPaused: null,
            }
          : {}),
        exercises: current.exercises.map((item) =>
          entryKey(item) !== rowKey
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
  const setsDone = (entry) => entry.sets.filter((set) => set.done).length;
  const nameOf = (entry) => exerciseById.get(entry.exerciseId).name;
  // Menus and dialogs close on use; put focus back on a card's ⋯ button once
  // the change has rendered, so keyboard users keep their place.
  function focusCard(key) {
    requestAnimationFrame(() => {
      const card = [...document.querySelectorAll(".log-exercise")].find(
        (item) => item.dataset.entryKey === key,
      );
      if (!card) return;
      card.scrollIntoView({ block: "nearest" });
      card
        .querySelector(".actions-menu-trigger")
        ?.focus({ preventScroll: true });
    });
  }
  async function move(entry, direction) {
    const key = entryKey(entry);
    const to = session.exercises.indexOf(entry) + direction;
    const result = await onUpdate((current) => ({
      ...current,
      exercises: moveEntry(current.exercises, key, direction),
    }));
    if (!result) return;
    notify(
      `Moved ${nameOf(entry)} to position ${to + 1} of ${session.exercises.length}.`,
    );
    focusCard(key);
  }
  async function remove(entry) {
    const key = entryKey(entry);
    const keys = session.exercises.map(entryKey);
    const index = keys.indexOf(key);
    const neighbour = keys[index + 1] ?? keys[index - 1];
    setPending(null);
    const result = await onUpdate((current) => ({
      ...current,
      exercises: removeEntry(current.exercises, key),
    }));
    if (!result) return;
    notify(`${nameOf(entry)} removed from this workout.`);
    focusCard(neighbour);
  }
  async function add(exercise) {
    setPicker(null);
    if (session.exercises.length >= 100) {
      notify("A workout can hold at most 100 exercises.");
      return;
    }
    const entry = addedEntry(exercise);
    const result = await onUpdate((current) =>
      current.exercises.length >= 100
        ? current
        : { ...current, exercises: [...current.exercises, entry] },
    );
    if (!result) return;
    notify(`${exercise.name} added to this workout.`);
    focusCard(entryKey(entry));
  }
  async function replace(entry, exercise) {
    const index = session.exercises.indexOf(entry);
    setPicker(null);
    setPending(null);
    const result = await onUpdate((current) => ({
      ...current,
      exercises: replaceEntry(current.exercises, entryKey(entry), exercise),
    }));
    if (!result) return;
    notify(`Replaced ${nameOf(entry)} with ${exercise.name}.`);
    const next = result.data?.active?.exercises[index];
    if (next) focusCard(entryKey(next));
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
          {session.exercises.map((entry, entryIndex) => {
            const exercise = exerciseById.get(entry.exerciseId);
            const fields = setFields(exercise, entry);
            const rowClass = `set-row${fields.length > 2 ? " set-row-sides" : ""}`;
            const lastSet = entry.sets.at(-1);
            return (
              <section
                className="panel log-exercise"
                key={entryKey(entry)}
                data-entry-key={entryKey(entry)}
              >
                <header>
                  <div className="exercise-icon">
                    <Dumbbell size={21} />
                  </div>
                  <div>
                    <h3>
                      {entry.groupId && (
                        <span className="superset-label">
                          {groupLabels(session.exercises)[entryIndex]}{" "}
                        </span>
                      )}
                      {exercise.name}
                    </h3>
                    {entry.note && <p className="program-note">{entry.note}</p>}
                    <p className="program-target">
                      {entry.targetReps && (
                        <>
                          Target:{" "}
                          {repsText(
                            { ...entry, reps: entry.targetReps },
                            exercise,
                          )}{" "}
                          ·{" "}
                        </>
                      )}
                      {entry.rpe != null && <>RPE {entry.rpe} · </>}
                      {entry.restSeconds ?? session.restSeconds} s rest
                    </p>
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
                  <ActionsMenu
                    label={`Options for ${exercise.name}`}
                    items={[
                      {
                        label: "Move up",
                        icon: <ArrowUp size={16} />,
                        disabled: entryIndex === 0,
                        onSelect: () => void move(entry, -1),
                      },
                      {
                        label: "Move down",
                        icon: <ArrowDown size={16} />,
                        disabled: entryIndex === session.exercises.length - 1,
                        onSelect: () => void move(entry, 1),
                      },
                      {
                        label: "Replace exercise",
                        icon: <ArrowLeftRight size={16} />,
                        onSelect: () =>
                          setPicker({ mode: "replace", key: entryKey(entry) }),
                      },
                      {
                        label: "Remove exercise",
                        icon: <Trash2 size={16} />,
                        danger: true,
                        disabled: session.exercises.length <= 1,
                        onSelect: () =>
                          setsDone(entry)
                            ? setPending({
                                kind: "remove",
                                key: entryKey(entry),
                              })
                            : void remove(entry),
                      },
                    ]}
                  />
                </header>
                {exercise.id === "plank" && (
                  <p className="movement-note">
                    One rep = a 10-second hold. For a 30-second plank, enter 3
                    reps.
                  </p>
                )}
                <div className={`${rowClass} set-labels`}>
                  <span>SET</span>
                  {fields.map((field) => (
                    <span key={field.key}>{field.label}</span>
                  ))}
                  <span>RPE</span>
                  <span>DONE</span>
                </div>
                {entry.sets.map((set, index) => (
                  <div
                    className={`${rowClass} ${set.done ? "set-done" : ""}`}
                    key={index}
                  >
                    <span>{index + 1}</span>
                    {fields.map((field) => (
                      <SavedField
                        key={field.key}
                        type="number"
                        disabled={set.done}
                        aria-label={`${exercise.name} set ${index + 1} ${field.key}`}
                        min={field.min}
                        max={field.max}
                        step={field.step}
                        placeholder={
                          field.side
                            ? set.sides
                              ? undefined
                              : String(set.reps || "")
                            : set.legacyDraft?.[field.key]
                        }
                        value={readSetValue(set, field.key)}
                        onChange={(event) =>
                          updateSet(
                            entryKey(entry),
                            index,
                            field.key,
                            event.target.value === ""
                              ? ""
                              : Number(event.target.value),
                          )
                        }
                      />
                    ))}
                    <SavedField
                      type="number"
                      disabled={set.done}
                      aria-label={`${exercise.name} set ${index + 1} rpe`}
                      min="1"
                      max="10"
                      step="0.5"
                      placeholder="—"
                      value={set.rpe ?? ""}
                      onChange={(event) =>
                        updateSet(
                          entryKey(entry),
                          index,
                          "rpe",
                          event.target.value === ""
                            ? null
                            : Number(event.target.value),
                        )
                      }
                    />
                    <button
                      aria-label={`${set.done ? "Uncomplete" : "Complete"} ${exercise.name} set ${index + 1}`}
                      aria-pressed={set.done}
                      className="check-set"
                      onClick={() => check(entryKey(entry), index)}
                    >
                      {set.done ? (
                        <Check size={18} />
                      ) : (
                        <span aria-hidden="true" className="unchecked-set" />
                      )}
                    </button>
                  </div>
                ))}
                <div className="set-actions">
                  <button
                    className="add-set"
                    disabled={entry.sets.length >= 100}
                    onClick={() =>
                      changeSets(entryKey(entry), (sets) =>
                        sets.length >= 100
                          ? sets
                          : [
                              ...sets,
                              { ...sets.at(-1), rpe: null, done: false },
                            ],
                      )
                    }
                  >
                    <Plus size={16} />
                    Add set
                  </button>
                  {entry.sets.length > 1 && !lastSet.done && (
                    <button
                      className="add-set remove-set"
                      aria-label={`Remove ${exercise.name} set ${entry.sets.length}`}
                      onClick={() =>
                        changeSets(entryKey(entry), (sets) =>
                          sets.length > 1 && !sets.at(-1).done
                            ? sets.slice(0, -1)
                            : sets,
                        )
                      }
                    >
                      <Minus size={16} />
                      Remove set
                    </button>
                  )}
                </div>
              </section>
            );
          })}
          <button
            type="button"
            className="add-set add-exercise"
            disabled={session.exercises.length >= 100}
            onClick={() => setPicker({ mode: "add" })}
          >
            <Plus size={16} />
            Add exercise
          </button>
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
            <label className="checkbox-field fill-toggle">
              <input
                type="checkbox"
                checked={fill}
                onChange={async (event) => {
                  const next = event.target.checked;
                  setFill(next);
                  if ((await onFillSets?.(next)) === null) setFill(!next);
                }}
              />
              Fill the remaining sets with what I type
            </label>
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
      )}
      {picker && (
        <ExercisePicker
          title={
            picker.mode === "add"
              ? "Add an exercise"
              : `Replace ${nameOf(session.exercises.find((item) => entryKey(item) === picker.key))}`
          }
          actionLabel={picker.mode === "add" ? "Add" : "Replace with"}
          onClose={() => {
            const key = picker.key;
            setPicker(null);
            if (key) focusCard(key);
          }}
          onPick={(exercise) => {
            if (picker.mode === "add") {
              void add(exercise);
              return;
            }
            const entry = session.exercises.find(
              (item) => entryKey(item) === picker.key,
            );
            if (!entry) {
              setPicker(null);
              return;
            }
            const lost = setsLostByReplacing(entry, exercise);
            if (lost) {
              setPicker(null);
              setPending({ kind: "replace", key: picker.key, exercise, lost });
            } else void replace(entry, exercise);
          }}
        />
      )}
      {pending &&
        session.exercises.find((item) => entryKey(item) === pending.key) && (
          <ConfirmChange
            pending={pending}
            entry={session.exercises.find(
              (item) => entryKey(item) === pending.key,
            )}
            done={setsDone(
              session.exercises.find((item) => entryKey(item) === pending.key),
            )}
            onCancel={() => {
              const key = pending.key;
              setPending(null);
              focusCard(key);
            }}
            onConfirm={(entry) =>
              void (pending.kind === "remove"
                ? remove(entry)
                : replace(entry, pending.exercise))
            }
          />
        )}
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
                loading={saving}
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
                Save workout
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
        Default rest: {session.restSeconds || 90} seconds
      </p>
      <div className="timer-adjustments">
        <Button
          variant="secondary"
          aria-label="Subtract 15 seconds"
          disabled={!remaining}
          onClick={() => {
            const clickedAt = Date.now();
            void onUpdate((current) => adjustRest(current, -15, clickedAt));
          }}
        >
          −15 s
        </Button>
        <Button
          variant="secondary"
          aria-label="Add 15 seconds"
          disabled={!remaining}
          onClick={() => {
            const clickedAt = Date.now();
            void onUpdate((current) => adjustRest(current, 15, clickedAt));
          }}
        >
          +15 s
        </Button>
      </div>
      <div className="timer-actions">
        <Button
          aria-label={session.restEnd ? "Pause rest timer" : "Start rest timer"}
          variant="secondary"
          onClick={() => {
            const clickedAt = Date.now();
            void onUpdate((current) => toggleRest(current, clickedAt));
          }}
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

function ConfirmChange({ pending, entry, done, onCancel, onConfirm }) {
  const name = exerciseById.get(entry.exerciseId).name;
  const sets = `${done} completed ${done === 1 ? "set" : "sets"}`;
  const replacing = pending.kind === "replace";
  return (
    <Modal
      title={
        replacing
          ? `Replace ${name} with ${pending.exercise.name}?`
          : `Remove ${name}?`
      }
      onClose={onCancel}
    >
      <div className="modal-content">
        <p>
          {replacing
            ? `${pending.exercise.name} records different measurements, so the ${sets} of ${name} will not be saved.`
            : `Its ${sets} will not be saved with this workout.`}
        </p>
        <div className="modal-actions">
          <Button variant="secondary" data-autofocus onClick={onCancel}>
            Keep {name}
          </Button>
          <Button variant="danger-solid" onClick={() => onConfirm(entry)}>
            {replacing ? "Replace exercise" : "Remove exercise"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
