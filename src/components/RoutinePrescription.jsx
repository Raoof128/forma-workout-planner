import { useEffect, useRef, useState } from "react";
import { ArrowUp, ArrowDown, GripVertical } from "lucide-react";
import {
  Reorder,
  useDragControls,
  useMotionValue,
  useReducedMotion,
} from "motion/react";
import { metricFields, tracksLoadReps } from "../exerciseMetrics.js";
import { entryKey, sideLabel } from "../routineProgramming.js";
import { loadType } from "../exerciseLoad.js";

export default function RoutinePrescription({
  item,
  exercise,
  index,
  count,
  repInput,
  onRepInput,
  update,
  move,
  join,
  joined,
  defaultRest,
  dragging,
  ordering,
  landed,
  onPress,
  onDragStart,
  onDrag,
  onDragEnd,
}) {
  const key = entryKey(item);
  const controls = useDragControls();
  const pointerAnchor = useRef(null);
  const reduceMotion = useReducedMotion();
  const vertical = useMotionValue(0);
  // Keeps the lifted surface raised until the row has snapped into its slot.
  const [settling, setSettling] = useState(false);
  useEffect(() => {
    if (!settling) return;
    const settle = () => setSettling(false);
    const stop = vertical.on("animationComplete", settle);
    const fallback = setTimeout(settle, 600);
    return () => {
      stop();
      clearTimeout(fallback);
    };
  }, [settling, vertical]);
  const lifted = dragging || settling;
  // No-load exercises keep the column (so rows line up) but show no input,
  // unless an older routine already set a load for them.
  const load = loadType(exercise);
  const loadField = (f) =>
    load === "none" && !(Number(item.weight) > 0)
      ? { key: "weight", empty: true }
      : { ...f, label: load === "added" ? "Added (kg)" : "Load (kg)" };
  const fields = [
    { key: "sets", label: "Sets", min: 1, max: 12, step: 1 },
    ...(tracksLoadReps(exercise)
      ? [
          { key: "reps", label: "Reps", range: true },
          ...metricFields(exercise)
            .filter((f) => f.key === "weight")
            .map(loadField),
        ]
      : metricFields(exercise).map((f) =>
          f.key === "weight" ? loadField(f) : f,
        )),
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
    <Reorder.Item
      as="div"
      value={key}
      data-entry-key={key}
      className={`prescription${dragging ? " is-dragging" : ""}${
        lifted ? " is-lifted" : ""
      }${landed && !lifted ? " is-landed" : ""}`}
      dragListener={false}
      dragControls={controls}
      dragMomentum={false}
      style={{ y: vertical }}
      layout="position"
      transition={{
        layout: reduceMotion
          ? { duration: 0 }
          : { type: "spring", stiffness: 500, damping: 42 },
      }}
      dragTransition={{
        bounceStiffness: 500,
        bounceDamping: 42,
        timeConstant: 180,
      }}
      onDragStart={(event, info) => {
        const anchor = pointerAnchor.current;
        if (!anchor || anchor.time > event.timeStamp) return;
        onDragStart(controls, event, info, anchor.press);
      }}
      onDrag={onDrag}
      onDragEnd={(event) => {
        if (reduceMotion) {
          vertical.stop();
          vertical.set(0);
        } else if (Math.abs(vertical.get()) > 0.5) setSettling(true);
        onDragEnd(event);
      }}
    >
      <div className="prescription-name">
        <span>{exercise.name}</span>
        <div className="reorder-actions">
          <button
            type="button"
            className="icon-button row-drag-handle"
            aria-label={`Drag ${exercise.name}`}
            disabled={ordering && !dragging}
            onPointerDown={(event) => {
              if (!event.isPrimary || event.button !== 0) return;
              const offset =
                event.clientY -
                event.currentTarget
                  .closest(".prescription")
                  .getBoundingClientRect().top;
              pointerAnchor.current = {
                time: event.timeStamp,
                press: onPress(event, offset),
              };
              event.currentTarget.focus({ preventScroll: true });
              controls.start(event, { distanceThreshold: 6 });
            }}
          >
            <GripVertical size={14} />
          </button>
          <button
            type="button"
            className="icon-button"
            disabled={ordering || index === 0}
            aria-label={`Move ${exercise.name} up`}
            onClick={() => move(index, -1)}
          >
            <ArrowUp size={14} />
          </button>
          <button
            type="button"
            className="icon-button"
            disabled={ordering || index === count - 1}
            aria-label={`Move ${exercise.name} down`}
            onClick={() => move(index, 1)}
          >
            <ArrowDown size={14} />
          </button>
        </div>
        {exercise.id === "plank" && <small>1 rep = 10-second hold</small>}
      </div>
      {fields.map((field) =>
        field.empty ? (
          <span
            className="prescription-field prescription-empty"
            key={field.key}
            aria-hidden="true"
          >
            —
          </span>
        ) : (
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
        ),
      )}
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
            Reps per {sideLabel(exercise)} · log left and right separately
          </label>
          <label className="checkbox-field">
            <input
              type="checkbox"
              aria-label={`${exercise.name} superset with previous`}
              disabled={ordering || index === 0}
              checked={joined}
              onChange={(event) => join(index, event.target.checked)}
            />
            Superset with previous exercise
          </label>
        </div>
      </details>
    </Reorder.Item>
  );
}
