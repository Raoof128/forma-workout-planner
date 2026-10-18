import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, expect } from "@playwright/test";
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

export async function verifyAliasCollisionMigration(page) {
  const { freshData } = await import("../src/storage.js");
  const data = freshData();
  data.version = 1;
  data.routines = [
    {
      ...data.routines[0],
      name: "Alias collision",
      exercises: [
        {
          exerciseId: "wger-4b23738a-67a8-41af-996d-abc53a7c3f97",
          sets: 3,
          reps: 8,
          weight: 15,
        },
        {
          exerciseId: "db-incline-dumbbell-press",
          sets: 4,
          reps: 12,
          weight: 20,
        },
      ],
    },
  ];
  await page.addInitScript(
    (fixture) => localStorage.setItem("forma-v1", JSON.stringify(fixture)),
    data,
  );
  await page.goto("/#routines");
  await expect
    .poll(() =>
      page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")).version),
    )
    .toBe(2);
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(
    page.getByRole("heading", {
      name: "Alias collision",
      exact: true,
      level: 1,
    }),
  ).toBeVisible();
  await expect(page.locator(".log-exercise")).toHaveCount(2);
}
