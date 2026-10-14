import { useState } from "react";
import media from "../catalog/media.json";
import Loading from "./Loading";

export function hasExerciseMedia(id) {
  return Boolean(media.exercises[id]);
}

function MediaImage({ asset, name, compact }) {
  const [status, setStatus] = useState("loading");
  const region = asset.region;
  const bounds =
    region &&
    (region.bounds ?? {
      x: (region.column * asset.width) / region.columns,
      y: (region.row * asset.height) / region.rows,
      width: asset.width / region.columns,
      height: asset.height / region.rows,
    });
  const kind = asset.kind.includes("equipment")
    ? "Equipment illustration"
    : "Exercise illustration";
  return (
    <span
      className={`exercise-media-frame${region ? " exercise-media-atlas" : ""}`}
      style={
        region
          ? {
              aspectRatio: `${bounds.width} / ${bounds.height}`,
            }
          : undefined
      }
    >
      <img
        alt={compact ? "" : `${kind} for ${name}: ${asset.title}`}
        loading={compact ? "lazy" : "eager"}
        decoding="async"
        style={
          region
            ? {
                width: `${(asset.width / bounds.width) * 100}%`,
                height: `${(asset.height / bounds.height) * 100}%`,
                left: `${(-bounds.x / bounds.width) * 100}%`,
                top: `${(-bounds.y / bounds.height) * 100}%`,
                opacity: status === "ready" ? 1 : 0,
              }
            : { opacity: status === "ready" ? 1 : 0 }
        }
        src={asset.src}
        onLoad={() => setStatus("ready")}
        onError={() => setStatus("error")}
      />
      {status === "loading" && (
        <Loading
          inline
          className="exercise-media-loading"
          label={compact ? "Loading image" : "Loading exercise image"}
          announce={!compact}
        />
      )}
      {status === "error" && (
        <span className="small muted exercise-media-unavailable">
          Image unavailable
        </span>
      )}
    </span>
  );
}

export default function ExerciseMedia({ id, name, compact = false }) {
  const entry = media.exercises[id];
  const asset = entry && media.assets[entry.assetId];
  if (!asset) return null;
  if (compact)
    return (
      <span className="exercise-media-preview" aria-hidden="true">
        <MediaImage key={asset.src} asset={asset} name={name} compact />
      </span>
    );
  return (
    <figure className="exercise-media">
      <MediaImage key={asset.src} asset={asset} name={name} />
      <figcaption>
        <p className="small exercise-media-caption">{entry.caption}</p>
        <p className="small muted exercise-attribution">
          {`Original FORMA ${asset.kind.includes("equipment") ? "equipment" : "exercise"} illustration · AI-assisted`}
        </p>
      </figcaption>
    </figure>
  );
}
