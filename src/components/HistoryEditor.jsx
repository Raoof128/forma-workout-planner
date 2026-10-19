import { useState, useEffect } from "react";
import { Button, Modal } from "./UI";
import { exerciseById, sessionSets } from "../data";
import { entryKey } from "../routineProgramming.js";
import { applySetValue, readSetValue, setFields } from "../exerciseMetrics.js";
export default function HistoryEditor({ session, onSave, onClose }) {
  const [draft, setDraft] = useState(() => structuredClone(session));
  const [discard, setDiscard] = useState(false);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const dirty = JSON.stringify(draft) !== JSON.stringify(session);
  useEffect(() => {
    if (!dirty) return;
    const warn = (event) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  const close = () => {
    if (!saving) {
      if (dirty) setDiscard(true);
      else onClose();
    }
  };
  function update(ei, si, key, value) {
    setDraft((current) => ({
      ...current,
      exercises: current.exercises.map((entry, index) =>
        index !== ei
          ? entry
          : {
              ...entry,
              sets: entry.sets.map((set, index) =>
                index !== si ? set : applySetValue(set, key, value),
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
            const exercise = exerciseById.get(entry.exerciseId);
            if (!session.exercises[ei].sets.some((set) => set.done))
              return null;
            const fields = setFields(exercise, entry);
            const rowClass = `set-row${fields.length > 2 ? " set-row-sides" : ""}`;
            return (
              <section className="history-edit-exercise" key={entryKey(entry)}>
                <h3>{exercise.name}</h3>
                <div className={`${rowClass} set-labels`}>
                  <span>SET</span>
                  {fields.map((field) => (
                    <span key={field.key}>{field.label}</span>
                  ))}
                  <span>RPE</span>
                  <span>KEEP</span>
                </div>
                {entry.sets.map(
                  (set, si) =>
                    session.exercises[ei].sets[si].done && (
                      <div className={rowClass} key={si}>
                        <span>{si + 1}</span>
                        {fields.map((field) => (
                          <input
                            key={field.key}
                            aria-label={`Correct ${exercise.name} set ${si + 1} ${field.key}`}
                            type="number"
                            min={field.min}
                            max={field.max}
                            step={field.step}
                            required={set.done}
                            placeholder={set.legacyDraft?.[field.key]}
                            value={readSetValue(set, field.key)}
                            onChange={(event) =>
                              update(
                                ei,
                                si,
                                field.key,
                                event.target.value === ""
                                  ? ""
                                  : Number(event.target.value),
                              )
                            }
                          />
                        ))}
                        <input
                          aria-label={`Correct ${exercise.name} set ${si + 1} rpe`}
                          type="number"
                          min="1"
                          max="10"
                          step="0.5"
                          value={set.rpe ?? ""}
                          onChange={(event) =>
                            update(
                              ei,
                              si,
                              "rpe",
                              event.target.value === ""
                                ? null
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
            <Button
              type="submit"
              variant="lime"
              disabled={saving}
              loading={saving}
            >
              Save corrections
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
