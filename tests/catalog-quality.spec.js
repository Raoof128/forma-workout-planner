import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";

test("library synonyms share one representative and machine filters expose corrected stations", async ({
  page,
}) => {
  await page.goto("/#library");
  await page.getByLabel("Search exercise library").fill("Hammer Curl");
  await expect(
    page.getByRole("heading", { name: "Hammer Curls", exact: true }),
  ).toHaveCount(1);
  await expect(
    page.getByRole("heading", { name: "Hammer Curl", exact: true }),
  ).toHaveCount(0);
  await page.getByLabel("Search exercise library").fill("Belt squat");
  await page.getByLabel("Filter by equipment").selectOption("Machine");
  await expect(page.locator(".library-card")).toHaveCount(1);
  await page.locator(".library-card").click();
  await expect(page.getByRole("dialog")).toContainText("connect it securely");
  await expect(page.getByRole("dialog")).not.toContainText(
    "Custom description created",
  );
});

test("new fan-bike guide and routine selection use real cardio units", async ({
  page,
}) => {
  await page.goto("/#library");
  await page.getByLabel("Search exercise library").fill("assault bike");
  await expect(page.locator(".library-card")).toHaveCount(1);
  await page.locator(".library-card").click();
  await expect(page.getByRole("dialog")).toContainText("Original FORMA guide");
  await expect(page.getByRole("dialog")).toContainText("seconds");
  await page.getByRole("button", { name: "Got it", exact: true }).click();
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  await page.getByLabel("Routine name").fill("Fan bike session");
  await page.getByLabel("Search exercises for routine").fill("fan bike");
  await expect(page.locator(".exercise-picker button")).toHaveCount(1);
  await page.locator(".exercise-picker button").click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect
    .poll(() =>
      page.evaluate(() =>
        JSON.parse(localStorage.getItem("forma-v1"))?.routines.some(
          (row) => row.name === "Fan bike session",
        ),
      ),
    )
    .toBe(true);
  const data = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  const movement = data.routines.find((row) => row.name === "Fan bike session")
    .exercises[0];
  expect(movement.exerciseId).toBe("forma-fan-bike");
  expect(movement.durationSeconds).toBeGreaterThan(0);
});

test("a saved duplicate ID keeps its name, measurements and guide after canonicalization", async ({
  page,
}) => {
  const data = freshData();
  data.routines[0].exercises = [
    {
      exerciseId: "wger-422a48aa-a41e-46e7-b84f-0bd99ccb0737",
      sets: 1,
      reps: 9,
      weight: 12,
    },
  ];
  await page.addInitScript(
    (fixture) => localStorage.setItem("forma-v1", JSON.stringify(fixture)),
    data,
  );
  await page.goto("/#routines");
  await page.locator(".routine-card").first().click();
  await expect(page.getByRole("dialog")).toContainText("Hammer Curl");
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  await page.getByLabel("Search exercises for routine").fill("Hammer Curl");
  const canonical = page
    .locator(".exercise-picker button")
    .filter({ hasText: /^Hammer Curls/ });
  await expect(canonical).toHaveAttribute("aria-pressed", "true");
  await canonical.click();
  await canonical.click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(
    page.getByLabel("Hammer Curl set 1 weight", { exact: true }),
  ).toHaveValue("12");
  await expect(
    page.getByLabel("Hammer Curl set 1 reps", { exact: true }),
  ).toHaveValue("9");
  await page
    .getByRole("button", { name: "Instructions for Hammer Curl", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toContainText("Free Exercise DB");
  const saved = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(saved.active.exercises[0].exerciseId).toBe(
    "wger-422a48aa-a41e-46e7-b84f-0bd99ccb0737",
  );
});
