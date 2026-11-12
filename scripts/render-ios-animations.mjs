/**
 * Records the website's animated exercise demonstrations as looping videos
 * for the native app, which cannot play SMIL. Called by
 * scripts/build-ios-media.py; run it directly only to re-record:
 *
 *   node scripts/render-ios-animations.mjs <output-folder> <exercise-id>...
 *
 * Each SVG is opened in headless Chromium with its animations paused, and
 * every frame is drawn at an exact time (`setCurrentTime`), so the video is
 * the same motion as the web at 30 frames per second, never a screen capture
 * that can drop frames. Writes `<id>.mp4` (H.264, no audio) and `<id>.png`,
 * the still start pose the web shows for reduced motion.
 */
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import console from "node:console";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fps = 30;
const [output, ...ids] = process.argv.slice(2);
if (!output || ids.length === 0) {
  console.error(
    "usage: render-ios-animations.mjs <output-folder> <exercise-id>...",
  );
  process.exit(2);
}
const animations = JSON.parse(
  await readFile(path.join(root, "src/catalog/animations.json"), "utf8"),
);
const publicFile = (src) => path.join(root, "public", src.replace(/^\//, ""));

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 960, height: 720 },
  deviceScaleFactor: 1,
});
try {
  for (const id of ids) {
    const entry = animations[id];
    if (!entry) throw new Error(`no animation for ${id}`);
    const frames = await mkdtemp(path.join(os.tmpdir(), `forma-${id}-`));
    try {
      await page.goto(`file://${publicFile(entry.src)}`);
      const count = Math.round(entry.seconds * fps);
      for (let index = 0; index < count; index += 1) {
        await page.evaluate((time) => {
          const svg = globalThis.document.documentElement;
          svg.pauseAnimations();
          svg.setCurrentTime(time);
        }, index / fps);
        await page.screenshot({
          path: path.join(frames, `${String(index).padStart(4, "0")}.png`),
        });
      }
      const encoded = spawnSync(
        "ffmpeg",
        [
          "-y",
          "-loglevel",
          "error",
          "-framerate",
          String(fps),
          "-i",
          path.join(frames, "%04d.png"),
          "-c:v",
          "libx264",
          "-preset",
          "slow",
          "-crf",
          "26",
          "-tune",
          "animation",
          "-pix_fmt",
          "yuv420p",
          "-movflags",
          "+faststart",
          "-an",
          path.join(output, `${id}.mp4`),
        ],
        { stdio: "inherit" },
      );
      if (encoded.status !== 0) throw new Error(`ffmpeg failed for ${id}`);
      await page.goto(`file://${publicFile(entry.still)}`);
      await page.screenshot({ path: path.join(output, `${id}.png`) });
      console.log(`recorded ${id}: ${count} frames`);
    } finally {
      await rm(frames, { recursive: true, force: true });
    }
  }
} finally {
  await browser.close();
}
