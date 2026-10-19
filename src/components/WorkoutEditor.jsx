import { useState } from "react";
import {
  ArrowDown,
  ArrowUp,
  Dumbbell,
  Plus,
  Search,
  Trash2,
} from "lucide-react";
import { Button, Modal } from "./UI";
import { exerciseById, selectableExercises } from "../data";
import { matchesExercise } from "../catalog/search.js";
import { entryKey, groupLabels } from "../routineProgramming.js";
import { addedEntry, moveEntry, removeEntry } from "../workoutSession.js";

// Changes the exercises of the running workout: add, move and remove.
// Every action saves straight away, like adding a set does.
export default function WorkoutEditor({ session, onUpdate, onClose, notify }) {
  const [query, setQuery] = useState("");
  const [pickerLimit, setPickerLimit] = useState(40);
  const [confirming, setConfirming] = useState(null);
  const matching = query.trim()
    ? selectableExercises.filter((exercise) => matchesExercise(exercise, query))
    : [];
  const labels = groupLabels(session.exercises);
  function add(exercise) {
    if (session.exercises.length >= 100) {
      notify("A workout can hold at most 100 exercises.");
      return;
    }
    const entry = addedEntry(exercise);
    void onUpdate((current) =>
      current.exercises.length >= 100
        ? current
        : { ...current, exercises: [...current.exercises, entry] },
    );
    notify(`${exercise.name} added to this workout.`);
  }
  function move(key, direction) {
    void onUpdate((current) => ({
      ...current,
      exercises: moveEntry(current.exercises, key, direction),
    }));
  }
  function remove(entry) {
    const key = entryKey(entry);
    if (entry.sets.some((set) => set.done) && confirming !== key) {
      setConfirming(key);
      return;
    }
    setConfirming(null);
    void onUpdate((current) => ({
      ...current,
      exercises: removeEntry(current.exercises, key),
    }));
    notify(
      `${exerciseById.get(entry.exerciseId).name} removed from this workout.`,
    );
  }
  return (
    <Modal title="Edit this workout" onClose={onClose} wide>
      <div className="modal-content workout-editor">
        <p className="muted">
          Changes save as you make them. Completed sets stay logged unless you
          remove their exercise.
        </p>
        <div className="exercise-list" aria-label="Exercises in this workout">
          {session.exercises.map((entry, index) => {
            const exercise = exerciseById.get(entry.exerciseId);
            const done = entry.sets.filter((set) => set.done).length;
            const key = entryKey(entry);
            return (
              <div className="exercise-row" key={key}>
                <span className="exercise-number">{labels[index]}</span>
                <div>
                  <strong>{exercise.name}</strong>
                  <span>
                    {done}/{entry.sets.length} sets done · {exercise.muscle}
                  </span>
                </div>
                <div className="reorder-actions">
                  <button
                    type="button"
                    className="icon-button"
                    aria-label={`Move ${exercise.name} up`}
                    disabled={index === 0}
                    onClick={() => move(key, -1)}
                  >
                    <ArrowUp size={14} />
                  </button>
                  <button
                    type="button"
                    className="icon-button"
                    aria-label={`Move ${exercise.name} down`}
                    disabled={index === session.exercises.length - 1}
                    onClick={() => move(key, 1)}
                  >
                    <ArrowDown size={14} />
                  </button>
                  <button
                    type="button"
                    className={`icon-button danger${confirming === key ? " confirm-remove" : ""}`}
                    aria-label={
                      confirming === key
                        ? `Remove ${exercise.name} and its ${done} completed ${done === 1 ? "set" : "sets"}`
                        : `Remove ${exercise.name}`
                    }
                    disabled={session.exercises.length <= 1}
                    onClick={() => remove(entry)}
                  >
                    <Trash2 size={14} />
                    {confirming === key && <small>Remove {done} done?</small>}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
        {session.exercises.length <= 1 && (
          <p className="muted small">A workout keeps at least one exercise.</p>
        )}
        <h3>Add an exercise</h3>
        <div className="search-field">
          <Search size={18} />
          <input
            data-autofocus
            aria-label="Search exercises to add"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setPickerLimit(40);
            }}
            placeholder="Search exercises…"
          />
        </div>
        <div className="exercise-picker">
          {query.trim() !== "" && !matching.length && (
            <p className="picker-empty" role="status">
              No matching exercises. Try a different name or muscle group.
            </p>
          )}
          {matching.slice(0, pickerLimit).map((exercise) => (
            <button
              type="button"
              key={exercise.id}
              onClick={() => add(exercise)}
            >
              <Dumbbell size={17} />
              <span>
                {exercise.name}
                <small>
                  {exercise.muscle} · {exercise.equipment}
                </small>
              </span>
              <Plus size={18} />
            </button>
          ))}
        </div>
        {matching.length > pickerLimit && (
          <Button
            variant="secondary"
            onClick={() => setPickerLimit((limit) => limit + 40)}
          >
            Show more matching exercises
          </Button>
        )}
        <div className="modal-actions">
          <Button variant="lime" onClick={onClose}>
            Done editing
          </Button>
        </div>
      </div>
    </Modal>
  );
}
