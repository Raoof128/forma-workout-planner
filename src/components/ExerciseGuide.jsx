import { Dumbbell, BookOpen } from "lucide-react";
import { Button, Modal } from "./UI";
import { useEffect, useState } from "react";
import { metricFields } from "../exerciseMetrics.js";
let instructionRequest;
function loadInstructions() {
  instructionRequest ??= import("../catalog/instructions.json")
    .then((module) => module.default)
    .catch((error) => {
      instructionRequest = undefined;
      throw error;
    });
  return instructionRequest;
}
export default function ExerciseGuide({ exercise, onClose }) {
  const [detail, setDetail] = useState(null);
  useEffect(() => {
    if (!exercise.source) return;
    let active = true;
    loadInstructions()
      .then((instructions) => {
        if (active)
          setDetail({ id: exercise.id, text: instructions[exercise.id] });
      })
      .catch(() => {
        if (active) setDetail({ id: exercise.id, error: true });
      });
    return () => {
      active = false;
    };
  }, [exercise.id, exercise.source]);
  return (
    <Modal title={exercise.name} onClose={onClose}>
      <div className="modal-content">
        <div className="exercise-detail-icon">
          <Dumbbell size={45} />
        </div>
        <div className="tags">
          <span>{exercise.muscle}</span>
          <span>{exercise.equipment}</span>
        </div>
        <h3>How to perform</h3>
        <p className="instruction">
          {detail?.id === exercise.id && detail.text
            ? detail.text
            : exercise.description}
        </p>
        {exercise.source && detail?.id !== exercise.id && (
          <p className="small muted" role="status">
            Loading full instructions…
          </p>
        )}
        {detail?.id === exercise.id && detail.error && (
          <p className="small" role="alert">
            The full guide could not load. Close and reopen this guide to retry;
            the exercise setup is shown above.
          </p>
        )}
        <p className="small muted">
          Log{" "}
          {metricFields(exercise)
            .map((field) => field.label.toLowerCase())
            .join(" and ")}
          {exercise.level ? ` · ${exercise.level}` : ""}.
        </p>
        {exercise.source && (
          <p className="small muted exercise-attribution">
            Instructions:{" "}
            <a
              href={exercise.source.url}
              target="_blank"
              rel="noopener noreferrer"
            >
              {exercise.source.title}
            </a>{" "}
            · {exercise.source.author} ·{" "}
            <a
              href={exercise.source.licenseUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              {exercise.source.license}
            </a>
            . {exercise.source.modified}
          </p>
        )}
        <div className="tip">
          <BookOpen size={20} />
          <p>
            Use a comfortable weight and controlled movement. Stop if you feel
            pain.
          </p>
        </div>
        <Button variant="lime" onClick={onClose}>
          Got it
        </Button>
      </div>
    </Modal>
  );
}
