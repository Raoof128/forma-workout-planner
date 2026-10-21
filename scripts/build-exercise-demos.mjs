// Builds self-hosted demonstration clips from the reviewed registry.
//
//   node scripts/build-exercise-demos.mjs <folder of downloaded originals>
//
// Each original must match the SHA-256 recorded at review (Commons' own
// SHA-1 is kept in the registry as provenance). Clips
// are trimmed, scaled to at most 720 px wide, stripped of audio and encoded
// as H.264 MP4 with a JPEG poster. Ordinary builds use the committed output;
// rerun this only after changing the registry. Needs FFmpeg with libx264.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { log } from "node:console";
import { guideExercise, selectableExercises } from "../src/data.js";

const root = path.resolve(import.meta.dirname, "..");
const registryFile = "docs/research/exercise-videos/registry.json";
const registry = JSON.parse(
  fs.readFileSync(path.join(root, registryFile), "utf8"),
);
const originals = process.argv[2];
assert(originals, "Pass the folder holding the downloaded originals.");
const out = path.join(root, "public/exercise-demos");
fs.mkdirSync(out, { recursive: true });
const selectable = new Set(selectableExercises.map((exercise) => exercise.id));
const sha256 = (file) =>
  crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");

const demos = { sources: registry.sources, clips: {}, exercises: {} };
for (const clip of registry.clips) {
  assert(registry.sources[clip.sourceId], `Unknown source for ${clip.id}`);
  if (!clip.formaIds.length) continue;
  // A segment of a longer source names that source's file in `original`.
  const original = path.join(originals, `${clip.original ?? clip.id}.webm`);
  // `sha1` is the checksum Commons publishes (provenance only); verify the
  // download against the SHA-256 recorded when it was reviewed.
  assert.equal(
    sha256(original),
    clip.originalSha256,
    `Original changed: ${clip.id}`,
  );
  const [start, end] = clip.trim;
  assert(end > start, `Empty trim for ${clip.id}`);
  const video = path.join(out, `${clip.id}.mp4`);
  const poster = path.join(out, `${clip.id}.jpg`);
  const scale = "scale='min(720,iw)':-2:flags=lanczos,fps=30";
  execFileSync("ffmpeg", [
    ...["-v", "error", "-y", "-ss", `${start}`, "-to", `${end}`],
    ...["-i", original, "-an", "-vf", scale, "-c:v", "libx264"],
    ...["-profile:v", "main", "-pix_fmt", "yuv420p", "-crf", "27"],
    ...["-preset", "slow", "-movflags", "+faststart", video],
  ]);
  execFileSync("ffmpeg", [
    ...["-v", "error", "-y", "-ss", `${clip.poster}`, "-i", original],
    ...["-frames:v", "1", "-vf", scale.replace(",fps=30", ""), "-q:v", "4"],
    poster,
  ]);
  const [width, height] = execFileSync("ffprobe", [
    ...["-v", "error", "-select_streams", "v:0", "-show_entries"],
    ...["stream=width,height", "-of", "csv=p=0", video],
  ])
    .toString()
    .trim()
    .split(",")
    .map(Number);
  demos.clips[clip.id] = {
    src: `/exercise-demos/${clip.id}.mp4`,
    poster: `/exercise-demos/${clip.id}.jpg`,
    width,
    height,
    sourceId: clip.sourceId,
    title: clip.title,
    url: clip.url,
    author: clip.author,
    sha256: sha256(video),
  };
  for (const id of clip.formaIds) {
    assert(selectable.has(id), `${id} is not a selectable exercise`);
    assert.equal(guideExercise(id).id, id, `${id} is not a guide id`);
    assert(!demos.exercises[id], `${id} has two clips`);
    demos.exercises[id] = { clipId: clip.id, caption: clip.caption };
  }
}
fs.writeFileSync(
  path.join(root, "src/catalog/demos.json"),
  `${JSON.stringify(demos, null, 2)}\n`,
);
log(
  `${Object.keys(demos.clips).length} clips for ${Object.keys(demos.exercises).length} exercises.`,
);
