import { BookOpen } from "lucide-react";
import { Button, Modal } from "./UI";
import { metricFields } from "../exerciseMetrics.js";
import { guideExercise } from "../data.js";
import ExerciseMedia from "./ExerciseMedia";
import ExerciseDemo from "./ExerciseDemo";
import GuideInstructions from "./GuideInstructions";
export default function ExerciseGuide({ exercise, onClose }) {
  const guide = guideExercise(exercise.id);
  return (
    <Modal title={exercise.name} onClose={onClose}>
      <div className="modal-content">
        <ExerciseMedia id={guide.id} name={guide.name} />
        <div className="tags">
          <span>{guide.muscle}</span>
          <span>{guide.equipment}</span>
        </div>
        <ExerciseDemo id={guide.id} name={guide.name} />
        <h3>How to perform</h3>
        <GuideInstructions
          key={guide.id}
          guide={guide}
          retryHint="Close and reopen this guide to retry; the exercise setup is shown above."
        >
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
        </GuideInstructions>
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
