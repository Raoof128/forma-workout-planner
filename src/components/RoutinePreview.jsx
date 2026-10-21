import { useEffect, useId, useRef } from "react";
import { ChevronLeft, ChevronRight, Clock, Dumbbell } from "lucide-react";
import { Button } from "./UI";
import { exerciseById, guideExercise } from "../data.js";
import { measurementText } from "../exerciseMetrics.js";
import { entryKey, groupLabels, repsText } from "../routineProgramming.js";
import ExerciseMedia from "./ExerciseMedia";
import ExerciseDemo from "./ExerciseDemo";
import GuideInstructions from "./GuideInstructions";

export function prescriptionText(item, exercise) {
  return `${item.sets} × ${
    exercise.metric && exercise.metric !== "load_reps"
      ? measurementText(exercise, item)
      : repsText(item, exercise)
  }`;
}

// One exercise's card: illustration, prescription, demonstration and guide.
export function PreviewSlide({
  item,
  label,
  defaultRest = 90,
  retryHint,
  ...props
}) {
  const exercise = exerciseById.get(item.exerciseId);
  const guide = guideExercise(item.exerciseId);
  return (
    <div className="routine-preview-slide" {...props}>
      <ExerciseMedia id={guide.id} name={guide.name} />
      <h4 className="routine-preview-name">
        <span className="exercise-number">{label}</span>
        {exercise.name}
      </h4>
      <p className="routine-preview-target">
        <strong>{prescriptionText(item, exercise)}</strong>
        {item.rpe != null && ` · RPE ${item.rpe}`} ·{" "}
        {item.restSeconds ?? defaultRest} s rest
      </p>
      {item.note && <p className="program-note">{item.note}</p>}
      <div className="tags">
        <span>{guide.muscle}</span>
        <span>{guide.equipment}</span>
      </div>
      <ExerciseDemo id={guide.id} name={guide.name} />
      <h5>How to perform</h5>
      <GuideInstructions key={guide.id} guide={guide} retryHint={retryHint}>
        {guide.measurementNotes && (
          <p className="small muted">{guide.measurementNotes}</p>
        )}
      </GuideInstructions>
    </div>
  );
}

// A non-rotating carousel (WAI-ARIA APG "grouped" style): Previous and Next
// keep focus so they can be pressed repeatedly (aria-disabled, not disabled,
// at the ends), the slide is labelled "N of total", and the exercise list
// jumps straight to any slide. Only the short position line is announced;
// the full technique text would be too long to read on every step.
export default function RoutinePreview({
  routine,
  index,
  onIndex,
  defaultRest = 90,
  children,
}) {
  const headingId = useId();
  const items = routine.exercises;
  const labels = groupLabels(items);
  const current = Math.min(Math.max(index, 0), items.length - 1);
  const item = items[current];
  const exercise = exerciseById.get(item.exerciseId);
  const position = `${current + 1} of ${items.length}`;
  const picker = useRef(null);
  useEffect(() => {
    // Keep the current chip in view sideways without scrolling the dialog.
    const strip = picker.current;
    const chip = strip?.children[current];
    if (!chip) return;
    if (chip.offsetLeft < strip.scrollLeft)
      strip.scrollLeft = chip.offsetLeft - 4;
    else if (
      chip.offsetLeft + chip.offsetWidth >
      strip.scrollLeft + strip.clientWidth
    )
      strip.scrollLeft =
        chip.offsetLeft + chip.offsetWidth - strip.clientWidth + 4;
  }, [current]);
  return (
    <section
      className="modal-content routine-preview"
      aria-roledescription="carousel"
      aria-labelledby={headingId}
    >
      <div className="routine-preview-heading">
        <h3 id={headingId}>{routine.name}</h3>
        <span className="small muted">
          <Dumbbell size={15} /> {items.length} exercise
          {items.length === 1 ? "" : "s"} · <Clock size={14} />{" "}
          {routine.minutes} min
        </span>
      </div>
      <div className="routine-preview-controls">
        <Button
          variant="secondary"
          aria-label="Previous exercise"
          aria-disabled={current === 0 || undefined}
          onClick={() => current > 0 && onIndex(current - 1)}
        >
          <ChevronLeft size={18} />
          <span className="routine-preview-step-label">Previous</span>
        </Button>
        <span className="small muted routine-preview-position">
          Exercise {position}
        </span>
        <Button
          variant="secondary"
          aria-label="Next exercise"
          aria-disabled={current === items.length - 1 || undefined}
          onClick={() => current < items.length - 1 && onIndex(current + 1)}
        >
          <span className="routine-preview-step-label">Next</span>
          <ChevronRight size={18} />
        </Button>
      </div>
      <div
        role="group"
        aria-label="Choose exercise"
        className="routine-preview-picker"
        ref={picker}
      >
        {items.map((entry, i) => (
          <button
            type="button"
            key={entryKey(entry)}
            aria-disabled={i === current || undefined}
            aria-current={i === current ? "step" : undefined}
            onClick={() => i !== current && onIndex(i)}
          >
            <span className="exercise-number">{labels[i]}</span>
            <span>{exerciseById.get(entry.exerciseId).name}</span>
          </button>
        ))}
      </div>
      <span className="sr-only" aria-live="polite" aria-atomic="true">
        Exercise {position}: {exercise.name}
      </span>
      <div>
        <PreviewSlide
          key={entryKey(item)}
          item={item}
          label={labels[current]}
          defaultRest={defaultRest}
          role="group"
          aria-roledescription="slide"
          aria-label={`${position}: ${exercise.name}`}
          retryHint="Move to another exercise and back to retry."
        />
      </div>
      {children && <div className="modal-actions">{children}</div>}
    </section>
  );
}
