import demos from "../catalog/demos.json";

export function hasExerciseDemo(id) {
  return Boolean(demos.exercises[id]);
}

// A self-hosted, silent demonstration clip. It never autoplays: the member
// presses play, and the poster loads only the first frame's image.
export default function ExerciseDemo({ id, name }) {
  const entry = demos.exercises[id];
  const clip = entry && demos.clips[entry.clipId];
  const source = clip && demos.sources[clip.sourceId];
  if (!source) return null;
  return (
    <figure className="exercise-demo">
      <video
        src={clip.src}
        poster={clip.poster}
        width={clip.width}
        height={clip.height}
        controls
        muted
        loop
        playsInline
        preload="none"
        aria-label={`Demonstration video: ${name}`}
      />
      <figcaption>
        {entry.caption && (
          <p className="small exercise-media-caption">{entry.caption}</p>
        )}
        <p className="small muted exercise-attribution">
          Demonstration:{" "}
          <a href={clip.url} target="_blank" rel="noopener noreferrer">
            {clip.title}
          </a>{" "}
          · {clip.author} ·{" "}
          {source.licenseUrl ? (
            <a
              href={source.licenseUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              {source.license}
            </a>
          ) : (
            source.license
          )}
          {source.notice ? `. ${source.notice}` : ""}
        </p>
      </figcaption>
    </figure>
  );
}
