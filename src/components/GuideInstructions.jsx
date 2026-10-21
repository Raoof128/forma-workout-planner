import { useEffect, useState } from "react";
import Loading from "./Loading";
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
// The technique text and its attribution, shared by the exercise guide and
// the routine preview. `children` sits between the text and the credits.
export default function GuideInstructions({ guide, retryHint, children }) {
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
    <>
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
          The full guide could not load. {retryHint}
        </p>
      )}
      {children}
      {guide.source && (
        <p className="small muted exercise-attribution">
          Instructions:{" "}
          <a href={guide.source.url} target="_blank" rel="noopener noreferrer">
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
              <a href={reference.url} target="_blank" rel="noopener noreferrer">
                {reference.title}
              </a>
            </span>
          ))}
        </p>
      )}
    </>
  );
}
