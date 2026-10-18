import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";
test("removing and restoring a canonical group preserves all historical alias prescriptions", async ({
  page,
}) => {
  const data = freshData();
  const rows = [
    { exerciseId: "bench", sets: 3, reps: 8, weight: 40 },
    { exerciseId: "row", sets: 2, reps: 10, weight: 16 },
    {
      exerciseId: "wger-3717d144-7815-4a97-9a56-956fb889c996",
      sets: 2,
      reps: 5,
      weight: 60,
    },
  ];
  data.routines[0].exercises = rows;
  await page.addInitScript(
    (fixture) => localStorage.setItem("forma-v1", JSON.stringify(fixture)),
    data,
  );
  await page.goto("/#routines");
  await page.locator(".routine-card").first().click();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  await page
    .getByLabel("Search exercises for routine")
    .fill("Barbell bench press");
  const entry = page
    .locator(".exercise-picker button")
    .filter({ hasText: /^Barbell bench press/ });
  await expect(entry).toHaveAttribute("aria-pressed", "true");
  await entry.click();
  await expect(entry).toHaveAttribute("aria-pressed", "false");
  await entry.click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  const saved = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(saved.routines[0].exercises).toEqual(
    rows.map((row) => ({
      ...row,
      repsMax: null,
      rpe: null,
      restSeconds: null,
      perSide: false,
      note: null,
      groupId: null,
    })),
  );
});
