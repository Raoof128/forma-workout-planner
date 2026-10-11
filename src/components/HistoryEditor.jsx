import { useState } from "react";
import { Button, Modal } from "./UI";
import { exercises, sessionSets } from "../data";
export default function HistoryEditor({ session, onSave, onClose }) {
  const [draft, setDraft] = useState(() => structuredClone(session));
  const [discard, setDiscard] = useState(false);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const dirty = JSON.stringify(draft) !== JSON.stringify(session);
  const close = () => (dirty ? setDiscard(true) : onClose());
  function update(ei, si, key, value) {
    setDraft((current) => ({
      ...current,
      exercises: current.exercises.map((entry, index) =>
        index !== ei
          ? entry
          : {
              ...entry,
              sets: entry.sets.map((set, index) =>
                index !== si ? set : { ...set, [key]: value },
              ),
            },
      ),
    }));
  }
  async function save(event) {
    event.preventDefault();
    if (!sessionSets(draft)) {
      setError(
        "Keep at least one completed set, or delete the workout from its details.",
      );
      return;
    }
    setSaving(true);
    try {
      if (!(await onSave(draft, session)))
        setError(
          "Could not save these changes. Review the message and try again.",
        );
    } finally {
      setSaving(false);
    }
  }
  return (
    <Modal
      title={discard ? "Discard workout changes?" : "Correct your workout"}
      onClose={discard ? () => setDiscard(false) : close}
      wide
    >
      {discard ? (
        <div className="modal-content">
          <p>Your changes haven’t been saved.</p>
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
        <form className="modal-content" onSubmit={save}>
          <label className="field">
            Workout name
            <input
              value={draft.name}
              required
              maxLength={60}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  name: event.target.value,
                }))
              }
            />
          </label>
          {draft.exercises.map((entry, ei) => {
            const exercise = exercises.find(
              (item) => item.id === entry.exerciseId,
            );
            if (!session.exercises[ei].sets.some((set) => set.done))
              return null;
            return (
              <section className="history-edit-exercise" key={entry.exerciseId}>
                <h3>{exercise.name}</h3>
                <div className="set-row set-labels">
                  <span>SET</span>
                  <span>KG</span>
                  <span>REPS</span>
                  <span>KEEP</span>
                </div>
                {entry.sets.map(
                  (set, si) =>
                    session.exercises[ei].sets[si].done && (
                      <div className="set-row" key={si}>
                        <span>{si + 1}</span>
                        <input
                          aria-label={`Correct ${exercise.name} set ${si + 1} weight`}
                          type="number"
                          min="0"
                          max="1000"
                          step="0.5"
                          required={set.done}
                          value={set.weight}
                          onChange={(event) =>
                            update(
                              ei,
                              si,
                              "weight",
                              event.target.value === ""
                                ? ""
                                : Number(event.target.value),
                            )
                          }
                        />
                        <input
                          aria-label={`Correct ${exercise.name} set ${si + 1} reps`}
                          type="number"
                          min="1"
                          max="100"
                          required={set.done}
                          value={set.reps}
                          onChange={(event) =>
                            update(
                              ei,
                              si,
                              "reps",
                              event.target.value === ""
                                ? ""
                                : Number(event.target.value),
                            )
                          }
                        />
                        <input
                          aria-label={`Keep ${exercise.name} set ${si + 1}`}
                          type="checkbox"
                          checked={set.done}
                          onChange={(event) =>
                            update(ei, si, "done", event.target.checked)
                          }
                        />
                      </div>
                    ),
                )}
              </section>
            );
          })}
          <label className="field">
            Workout notes
            <textarea
              value={draft.notes}
              maxLength={10000}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  notes: event.target.value,
                }))
              }
            />
          </label>
          {error && (
            <p className="error" role="alert">
              {error}
            </p>
          )}
          <div className="modal-actions">
            <Button variant="secondary" disabled={saving} onClick={close}>
              Cancel
            </Button>
            <Button type="submit" variant="lime" disabled={saving}>
              Save corrections
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
