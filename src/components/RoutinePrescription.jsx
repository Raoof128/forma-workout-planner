import { ArrowUp, ArrowDown, GripVertical } from "lucide-react";
import { metricFields, tracksLoadReps } from "../exerciseMetrics.js";
import { entryKey, sideLabel } from "../routineProgramming.js";

export default function RoutinePrescription({
  item,
  exercise,
  index,
  count,
  repInput,
  onRepInput,
  update,
  move,
  reorder,
  join,
  joined,
  defaultRest,
}) {
  const key = entryKey(item);
  const fields = [
    { key: "sets", label: "Sets", min: 1, max: 12, step: 1 },
    ...(tracksLoadReps(exercise)
      ? [
          { key: "reps", label: "Reps", range: true },
          ...metricFields(exercise)
            .filter((f) => f.key === "weight")
            .map((f) => ({ ...f, label: "Load (kg)" })),
        ]
      : metricFields(exercise)),
    { key: "rpe", label: "RPE", min: 1, max: 10, step: 0.5, optional: true },
    {
      key: "restSeconds",
      label: "Rest (s)",
      min: 10,
      max: 600,
      step: 1,
      optional: true,
    },
  ];
  return (
    <div
      className="prescription"
      onDragOver={(event) => event.preventDefault()}
      onDrop={(event) => {
        event.preventDefault();
        const from = event.dataTransfer.getData("text/plain");
        if (from) reorder(from, key);
      }}
    >
      <div className="prescription-name">
        <span>{exercise.name}</span>
        <div className="reorder-actions">
          <button
            type="button"
            className="icon-button"
            draggable
            aria-label={`Drag ${exercise.name}`}
            onDragStart={(event) => {
              event.dataTransfer.setData("text/plain", key);
              event.dataTransfer.effectAllowed = "move";
            }}
          >
            <GripVertical size={14} />
          </button>
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
            disabled={index === count - 1}
            aria-label={`Move ${exercise.name} down`}
            onClick={() => move(index, 1)}
          >
            <ArrowDown size={14} />
          </button>
        </div>
        {exercise.id === "plank" && <small>1 rep = 10-second hold</small>}
      </div>
      {fields.map((field) => (
        <label className="prescription-field" key={field.key}>
          <span>{field.label}</span>
          <input
            aria-label={`${exercise.name} ${field.key}`}
            type={field.range ? "text" : "number"}
            inputMode={field.range ? "text" : undefined}
            min={field.min}
            max={field.max}
            step={field.step}
            required={!field.optional}
            placeholder={
              field.key === "restSeconds"
                ? String(defaultRest)
                : field.range
                  ? "8-10"
                  : field.optional
                    ? "—"
                    : undefined
            }
            value={field.range ? repInput : (item[field.key] ?? "")}
            onChange={(event) =>
              field.range
                ? onRepInput(key, event.target.value)
                : update(
                    key,
                    field.key,
                    event.target.value === ""
                      ? field.optional
                        ? null
                        : ""
                      : Number(event.target.value),
                  )
            }
          />
        </label>
      ))}
      <details className="prescription-options">
        <summary aria-label={`Options for ${exercise.name}`}>⋯</summary>
        <div>
          <label className="field">
            Note / variant cue
            <input
              aria-label={`${exercise.name} note`}
              maxLength={140}
              value={item.note ?? ""}
              onChange={(event) =>
                update(key, "note", event.target.value || null)
              }
            />
          </label>
          <label className="checkbox-field">
            <input
              type="checkbox"
              aria-label={`${exercise.name} per side`}
              checked={item.perSide ?? false}
              onChange={(event) => update(key, "perSide", event.target.checked)}
            />
            Reps per {sideLabel(exercise)}
          </label>
          <label className="checkbox-field">
            <input
              type="checkbox"
              aria-label={`${exercise.name} superset with previous`}
              disabled={index === 0}
              checked={joined}
              onChange={(event) => join(index, event.target.checked)}
            />
            Superset with previous exercise
          </label>
        </div>
      </details>
    </div>
  );
}
