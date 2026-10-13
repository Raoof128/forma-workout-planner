import { useState, useEffect, useRef } from "react";
import {
  Plus,
  Search,
  Check,
  Dumbbell,
  Trash2,
  Play,
  Pencil,
  Clock,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import { Button, Modal, RoutineCard, PageHeading } from "./UI";
import { createId, exercises, selectableExercises } from "../data";
import {
  defaultPrescription,
  metricFields,
  validMeasurement,
  measurementText,
} from "../exerciseMetrics.js";
import { workoutTemplates } from "../workoutTemplates.js";
import { matchesExercise } from "../catalog/search.js";
import { canonicalId } from "../catalog/curation.js";
import curation from "../catalog/curation.json" with { type: "json" };
export function Routines({ routines, onOpen, onCreate, onUseTemplate }) {
  return (
    <>
      <PageHeading
        eyebrow="Your plan, your pace"
        title="Make every session yours."
        subtitle="Your routines, built around the way you train."
      >
        <Button onClick={onCreate}>
          <Plus size={18} />
          Create routine
        </Button>
      </PageHeading>
      <div className="section-title">
        <h2>
          My routines <span className="count-label">{routines.length}</span>
        </h2>
        <span className="muted small">Ready when you are</span>
      </div>
      <div className="routine-grid full-grid">
        {routines.map((r) => (
          <RoutineCard key={r.id} routine={r} onClick={onOpen} />
        ))}
        <button className="create-card" onClick={onCreate}>
          <span className="empty-icon">
            <Plus size={24} />
          </span>
          <h3>A routine of your own</h3>
          <p>Build your next favorite workout.</p>
        </button>
      </div>
      <div className="section-title">
        <h2>Workout templates</h2>
        <span className="small muted">
          {workoutTemplates.length} starting points
        </span>
      </div>
      <p className="muted">
        Add a template to your routines, then adjust its sets, measurements and
        load to suit you.
      </p>
      <div className="routine-grid full-grid">
        {workoutTemplates.map((template) => (
          <button
            key={template.id}
            className="panel workout-template"
            onClick={() => onUseTemplate(template)}
          >
            <h3>{template.name}</h3>
            <p>{template.description}</p>
            <span className="small muted">
              {template.exercises.length} exercises · {template.minutes} min
            </span>
          </button>
        ))}
      </div>
    </>
  );
}
export function RoutineDetail({ routine, onClose, onStart, onEdit, onDelete }) {
  return (
    <Modal title="Routine overview" onClose={onClose} wide>
      <div
        className={`detail-cover routine-photo photo-${routine.image ?? 0}`}
      />
      <div className="modal-content">
        <h2 className="detail-name">{routine.name}</h2>
        <p className="muted">{routine.description}</p>
        <div className="detail-meta">
          <span>
            <Dumbbell size={17} />
            {routine.exercises.length} exercises
          </span>
          <span>
            <Clock size={17} />
            {routine.minutes} min
          </span>
          <span>{routine.level}</span>
        </div>
        <div className="exercise-list">
          {routine.exercises.map((item, i) => {
            const e = exercises.find((e) => e.id === item.exerciseId);
            return (
              <div className="exercise-row" key={item.exerciseId}>
                <span className="exercise-number">
                  {String(i + 1).padStart(2, "0")}
                </span>
                <div>
                  <strong>{e.name}</strong>
                  <span>
                    {e.muscle} · {e.equipment}
                  </span>
                </div>
                <span className="sets-label">
                  {item.sets} ×{" "}
                  {e.metric && e.metric !== "load_reps"
                    ? measurementText(e, item)
                    : `${item.reps} reps`}
                </span>
              </div>
            );
          })}
        </div>
        <div className="modal-actions">
          <button
            className="icon-button danger"
            aria-label="Delete routine"
            onClick={() => onDelete(routine)}
          >
            <Trash2 size={19} />
          </button>
          <Button variant="secondary" onClick={() => onEdit(routine)}>
            <Pencil size={16} />
            Edit routine
          </Button>
          <Button variant="lime" onClick={() => onStart(routine)}>
            <Play size={17} />
            Start workout
          </Button>
        </div>
      </div>
    </Modal>
  );
}
export function RoutineEditor({ routine, onClose, onSave }) {
  const [name, setName] = useState(routine?.name || "");
  const [items, setItems] = useState(routine?.exercises || []);
  const [minutes, setMinutes] = useState(routine?.minutes || 45);
  const [query, setQuery] = useState("");
  const [pickerLimit, setPickerLimit] = useState(40);
  const matchingExercises = selectableExercises.filter((exercise) =>
    matchesExercise(exercise, query),
  );
  const [error, setError] = useState("");
  const [discard, setDiscard] = useState(false);
  const [saving, setSaving] = useState(false);
  const removed = useRef(new Map());
  const dirty =
    name !== (routine?.name || "") ||
    minutes !== (routine?.minutes || 45) ||
    JSON.stringify(items) !== JSON.stringify(routine?.exercises || []);
  useEffect(() => {
    if (!dirty) return;
    const warn = (event) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  useEffect(() => {
    if (discard) document.querySelector(".draft-confirm button")?.focus();
  }, [discard]);
  function close() {
    if (saving) return;
    if (dirty) setDiscard(true);
    else onClose();
  }
  function toggle(exercise) {
    const group = items
      .map((item, index) => ({ item, index }))
      .filter(
        ({ item }) => canonicalId(item.exerciseId, curation) === exercise.id,
      );
    if (group.length) {
      removed.current.set(exercise.id, group);
      setItems((current) =>
        current.filter(
          (item) => canonicalId(item.exerciseId, curation) !== exercise.id,
        ),
      );
    } else {
      const restored = removed.current.get(exercise.id);
      setItems((current) => {
        if (restored) {
          const next = [...current];
          for (const { item, index } of restored)
            next.splice(Math.min(index, next.length), 0, item);
          return next;
        }
        return [
          ...current,
          {
            exerciseId: exercise.id,
            ...defaultPrescription(exercise),
          },
        ];
      });
    }
  }
  function update(id, key, value) {
    setItems((current) =>
      current.map((item) =>
        item.exerciseId === id ? { ...item, [key]: value } : item,
      ),
    );
  }
  function move(index, direction) {
    setItems((current) => {
      const next = [...current];
      [next[index], next[index + direction]] = [
        next[index + direction],
        next[index],
      ];
      return next;
    });
  }
  async function save(event) {
    event.preventDefault();
    if (!name.trim() || !items.length) {
      setError("Give your routine a name and choose at least one exercise.");
      return;
    }
    if (
      !Number.isInteger(minutes) ||
      minutes < 1 ||
      minutes > 1000 ||
      items.some(
        (item) =>
          !Number.isInteger(item.sets) ||
          item.sets < 1 ||
          item.sets > 12 ||
          !validMeasurement(
            exercises.find((exercise) => exercise.id === item.exerciseId),
            item,
          ),
      )
    ) {
      setError(
        "Use 1–12 sets and valid measurements in the units shown for each exercise.",
      );
      return;
    }
    setSaving(true);
    try {
      const saved = await onSave({
        ...routine,
        id: routine?.id || createId(),
        name: name.trim(),
        description: routine?.description || "Your workout. Your way.",
        minutes,
        level: routine?.level || "Custom",
        image: routine?.image ?? 2,
        exercises: items,
      });
      if (!saved)
        setError("Could not save. Check the message and keep your draft open.");
    } finally {
      setSaving(false);
    }
  }
  return (
    <Modal
      title={
        discard
          ? "Discard unsaved changes?"
          : routine
            ? "Edit your routine"
            : "Create your routine"
      }
      onClose={discard ? () => setDiscard(false) : close}
      wide
    >
      {discard ? (
        <div className="modal-content draft-confirm">
          <p>
            Your routine has unsaved changes. Keep editing to preserve them.
          </p>
          <div className="modal-actions">
            <Button variant="secondary" onClick={() => setDiscard(false)}>
              Keep editing
            </Button>
            <Button variant="danger-solid" onClick={onClose}>
              Discard changes
            </Button>
          </div>
        </div>
      ) : (
        <form onSubmit={save} className="modal-content">
          <label className="field">
            Routine name
            <input
              data-autofocus
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="e.g. Monday upper body"
              maxLength={60}
            />
          </label>
          <label className="field duration-field">
            Estimated duration (minutes)
            <input
              type="number"
              required
              min="1"
              max="1000"
              value={minutes}
              onChange={(event) =>
                setMinutes(
                  event.target.value === "" ? "" : Number(event.target.value),
                )
              }
            />
          </label>
          <div className="editor-heading">
            <h3>Choose your exercises</h3>
            <span className="muted small" role="status">
              {items.length} selected
            </span>
          </div>
          <div className="search-field">
            <Search size={18} />
            <input
              aria-label="Search exercises for routine"
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPickerLimit(40);
              }}
              placeholder="Search exercises…"
            />
          </div>
          <div className="exercise-picker">
            {!matchingExercises.length && (
              <p className="picker-empty" role="status">
                No matching exercises. Try a different name or muscle group.
              </p>
            )}
            {matchingExercises.slice(0, pickerLimit).map((exercise) => {
              const picked = items.some(
                (item) =>
                  canonicalId(item.exerciseId, curation) === exercise.id,
              );
              return (
                <button
                  type="button"
                  key={exercise.id}
                  aria-pressed={picked}
                  className={picked ? "picked" : ""}
                  onClick={() => toggle(exercise)}
                >
                  <Dumbbell size={17} />
                  <span>
                    {exercise.name}
                    <small>
                      {exercise.muscle} · {exercise.equipment}
                    </small>
                  </span>
                  {picked ? <Check size={18} /> : <Plus size={18} />}
                </button>
              );
            })}
          </div>
          {matchingExercises.length > pickerLimit && (
            <Button
              variant="secondary"
              onClick={() => setPickerLimit((limit) => limit + 40)}
            >
              Show more matching exercises
            </Button>
          )}
          {items.length > 0 && (
            <div className="prescriptions">
              <div className="prescription labels">
                <span>EXERCISE / ORDER</span>
                <span>SETS</span>
                <span>TARGET</span>
                <span>MEASUREMENT</span>
              </div>
              {items.map((item, index) => {
                const exercise = exercises.find(
                  (value) => value.id === item.exerciseId,
                );
                return (
                  <div className="prescription" key={item.exerciseId}>
                    <div>
                      <span>{exercise.name}</span>
                      <div className="reorder-actions">
                        <button
                          type="button"
                          className="icon-button"
                          disabled={index === 0}
                          aria-label={`Move ${exercise.name} up`}
                          onClick={() => move(index, -1)}
                        >
                          <ArrowUp size={14} />
                        </button>
                        <button
                          type="button"
                          className="icon-button"
                          disabled={index === items.length - 1}
                          aria-label={`Move ${exercise.name} down`}
                          onClick={() => move(index, 1)}
                        >
                          <ArrowDown size={14} />
                        </button>
                      </div>
                      {exercise.id === "plank" && (
                        <small>1 rep = 10-second hold</small>
                      )}
                    </div>
                    {[
                      { key: "sets", label: "SETS", min: 1, max: 12, step: 1 },
                      ...metricFields(exercise),
                    ].map(({ key, label, min, max, step }) => (
                      <label className="prescription-field" key={key}>
                        <span>{label}</span>
                        <input
                          aria-label={`${exercise.name} ${key}`}
                          type="number"
                          min={min}
                          max={max}
                          step={step}
                          required
                          value={item[key] ?? ""}
                          onChange={(event) =>
                            update(
                              item.exerciseId,
                              key,
                              event.target.value === ""
                                ? ""
                                : Number(event.target.value),
                            )
                          }
                        />
                      </label>
                    ))}
                  </div>
                );
              })}
            </div>
          )}
          {error && (
            <p role="alert" className="error">
              {error}
            </p>
          )}
          <div className="modal-actions">
            <Button variant="secondary" disabled={saving} onClick={close}>
              Cancel
            </Button>
            <Button
              type="submit"
              variant="lime"
              disabled={saving}
              loading={saving}
            >
              <Check size={17} />
              Save routine
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
