import { Dumbbell, BookOpen } from "lucide-react";
import { Button, Modal } from "./UI";
import { useEffect, useState } from "react";
import { metricFields } from "../exerciseMetrics.js";
import Loading from "./Loading";
import { guideExercise } from "../data.js";
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
  const guide = guideExercise(exercise.id);
  const [detail, setDetail] = useState(null);
  useEffect(() => {
    if (!guide.source) return;
    let active = true;
    loadInstructions()
      .then((instructions) => {
        if (active)
          setDetail({
            id: guide.id,
            text: instructions[guide.instructionId ?? guide.id],
          });
      })
      .catch(() => {
        if (active) setDetail({ id: guide.id, error: true });
      });
    return () => {
      active = false;
    };
  }, [guide.id, guide.source, guide.instructionId]);
  return (
    <Modal title={exercise.name} onClose={onClose}>
      <div className="modal-content">
        <div className="exercise-detail-icon">
          <Dumbbell size={45} />
        </div>
        <div className="tags">
          <span>{guide.muscle}</span>
          <span>{guide.equipment}</span>
        </div>
        <h3>How to perform</h3>
        <p className="instruction">
          {guide.guideUnavailable
            ? "This older entry is kept for your saved workouts. Its source did not provide usable technique instructions."
            : detail?.id === guide.id && detail.text
              ? detail.text
              : guide.description}
        </p>
        {guide.source && detail?.id !== guide.id && (
          <Loading
            inline
            className="forma-guide-loading"
            label="Loading full instructions…"
          />
        )}
        {detail?.id === guide.id && detail.error && (
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
        {guide.measurementNotes && (
          <p className="small muted">{guide.measurementNotes}</p>
        )}
        {guide.source && (
          <p className="small muted exercise-attribution">
            Instructions:{" "}
            <a
              href={guide.source.url}
              target="_blank"
              rel="noopener noreferrer"
            >
              {guide.source.title}
            </a>{" "}
            · {guide.source.author} ·{" "}
            <a
              href={guide.source.licenseUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              {guide.source.license}
            </a>
            . {guide.source.modified}
          </p>
        )}
        {!!guide.references?.length && (
          <p className="small muted exercise-attribution">
            Original FORMA guide. Equipment references:{" "}
            {guide.references.map((reference, index) => (
              <span key={reference.url}>
                {index > 0 ? " · " : ""}
                <a
                  href={reference.url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {reference.title}
                </a>
              </span>
            ))}
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
