import { useState } from "react";
import { Pause, Play } from "lucide-react";
import animations from "../catalog/animations.json";

export function hasExerciseAnimation(id) {
  return Boolean(animations[id]);
}

function prefersReducedMotion() {
  return Boolean(
    globalThis.matchMedia?.("(prefers-reduced-motion: reduce)").matches,
  );
}

// An original animated demonstration (SMIL in an <img>, so the page CSP and
// sandboxing stay unchanged). It loops, so it always has a pause control, and
// it starts on the still start pose when the device asks for reduced motion.
export default function ExerciseAnimation({ id, name }) {
  const [playing, setPlaying] = useState(() => !prefersReducedMotion());
  const entry = animations[id];
  if (!entry) return null;
  return (
    <figure className="exercise-animation">
      <img
        key={playing ? "animated" : "still"}
        src={playing ? entry.src : entry.still}
        alt={`How to perform ${name}: ${entry.description}`}
        width="960"
        height="720"
        loading="lazy"
        decoding="async"
      />
      <figcaption>
        <span className="small muted exercise-attribution">
          Animated FORMA demonstration · {entry.seconds} s loop
        </span>
        <button
          type="button"
          className="exercise-animation-toggle"
          aria-label={`${playing ? "Pause" : "Play"} demonstration of ${name}`}
          onClick={() => setPlaying((value) => !value)}
        >
          {playing ? <Pause size={16} /> : <Play size={16} />}
          {playing ? "Pause" : "Play"}
        </button>
      </figcaption>
    </figure>
  );
}
