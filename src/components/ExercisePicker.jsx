import { useState } from "react";
import { Dumbbell, Plus, Search } from "lucide-react";
import { Button, Modal } from "./UI";
import { selectableExercises } from "../data";
import { matchesExercise } from "../catalog/search.js";

// Searchable exercise list used to add or replace an exercise mid-workout.
export default function ExercisePicker({
  title,
  actionLabel,
  onPick,
  onClose,
}) {
  const [query, setQuery] = useState("");
  const [limit, setLimit] = useState(40);
  const matching = query.trim()
    ? selectableExercises.filter((exercise) => matchesExercise(exercise, query))
    : [];
  return (
    <Modal title={title} onClose={onClose} wide>
      <div className="modal-content exercise-picker-dialog">
        <div className="search-field">
          <Search size={18} />
          <input
            data-autofocus
            aria-label="Search exercises"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setLimit(40);
            }}
            placeholder="Search by name, muscle or equipment…"
          />
        </div>
        <div className="exercise-picker">
          {!query.trim() && (
            <p className="picker-empty">Type to search 1,600+ exercises.</p>
          )}
          {query.trim() !== "" && !matching.length && (
            <p className="picker-empty" role="status">
              No matching exercises. Try a different name or muscle group.
            </p>
          )}
          {matching.slice(0, limit).map((exercise) => (
            <button
              type="button"
              key={exercise.id}
              aria-label={`${actionLabel} ${exercise.name}`}
              onClick={() => onPick(exercise)}
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
        {matching.length > limit && (
          <Button
            variant="secondary"
            onClick={() => setLimit((value) => value + 40)}
          >
            Show more matching exercises
          </Button>
        )}
        <div className="modal-actions">
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
        </div>
      </div>
    </Modal>
  );
}
