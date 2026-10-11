import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "@playwright/test";
export const artifactPath = (name) =>
  join(
    process.env.FORMA_ARTIFACT_DIR || join(tmpdir(), "forma-qa"),
    test.info().project.name,
    name,
  );
export async function settlePage(page) {
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(
      document
        .getAnimations()
        .map((animation) => animation.finished.catch(() => {})),
    );
  });
}
