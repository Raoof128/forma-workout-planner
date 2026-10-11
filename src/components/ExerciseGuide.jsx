import { Dumbbell, BookOpen } from "lucide-react";
import { Button, Modal } from "./UI";
export default function ExerciseGuide({ exercise, onClose }) {
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
        <p className="instruction">{exercise.description}</p>
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
