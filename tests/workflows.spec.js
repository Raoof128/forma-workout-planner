import { artifactPath } from "./helpers.js";
import { test, expect } from "@playwright/test";
test("personal training workflow persists routines, sessions and calculated progress", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("http://localhost:5173");
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Exercise library", exact: true })
    .click();
  await page.getByLabel("Search exercise library").fill("bench");
  await expect(page.locator(".library-card").first()).toContainText(
    "Barbell bench press",
  );
  await page.locator(".library-card").first().click();
  await expect(
    page.getByRole("heading", { name: "How to perform" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Got it" }).click();
  await page.getByLabel("Search exercise library").fill("zzzz");
  await expect(
    page.getByRole("heading", { name: "No matching movements" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Clear filters" }).click();
  await page.getByLabel("Filter by equipment").selectOption("Barbell");
  await expect(page.locator(".library-card").first()).toBeVisible();
  for (const card of await page.locator(".library-card").all())
    await expect(card.locator("p")).toHaveText("Barbell");
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  await page.getByLabel("Routine name").fill("Test strength");
  await page
    .locator(".exercise-picker button")
    .filter({ hasText: "Barbell bench press" })
    .click();
  await page.getByLabel("Barbell bench press sets", { exact: true }).fill("2");
  await page.getByLabel("Barbell bench press reps", { exact: true }).fill("8");
  await page
    .getByLabel("Barbell bench press weight", { exact: true })
    .fill("45");
  await page.getByRole("button", { name: "Save routine" }).click();
  await expect(
    page.getByRole("heading", { name: "Test strength", exact: true }),
  ).toBeVisible();
  await page.reload();
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await page
    .locator(".routine-card")
    .filter({ hasText: "Test strength" })
    .click();
  await page.getByRole("button", { name: "Edit routine" }).click();
  await page
    .getByLabel("Barbell bench press weight", { exact: true })
    .fill("50");
  await page.getByRole("button", { name: "Save routine" }).click();
  await page
    .locator(".routine-card")
    .filter({ hasText: "Test strength" })
    .click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await page
    .getByLabel("Barbell bench press set 1 weight", { exact: true })
    .fill("50");
  await page
    .getByRole("button", {
      name: "Complete Barbell bench press set 1",
      exact: true,
    })
    .click();
  await expect(page.locator(".set-done")).toHaveCount(1);
  await expect(page.locator(".timer-value")).not.toHaveText("00:00");
  await page.getByRole("button", { name: "Skip", exact: true }).click();
  await expect(page.locator(".timer-value")).toHaveText("00:00");
  await expect
    .poll(async () =>
      page.evaluate(
        () => JSON.parse(localStorage.getItem("forma-v1")).active.restEnd,
      ),
    )
    .toBeNull();
  await expect
    .poll(async () =>
      page.evaluate(
        () => JSON.parse(localStorage.getItem("forma-v1")).active.restPaused,
      ),
    )
    .toBeNull();
  await page.reload();
  await expect(page).toHaveURL(/#workout$/);
  await expect(page.locator(".timer-value")).toHaveText("00:00");
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).active.restEnd,
    ),
  ).toBeNull();
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).active.restPaused,
    ),
  ).toBeNull();
  await expect(page.locator(".set-done")).toHaveCount(1);
  await page
    .getByRole("button", {
      name: "Complete Barbell bench press set 2",
      exact: true,
    })
    .click();
  await expect(page.locator(".session-stats")).toContainText("800");
  await page.getByLabel("Session notes").fill("Felt strong today");
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page.getByRole("button", { name: "Save workout", exact: true }).click();
  await expect(page.locator(".history-row")).toHaveCount(1);
  await page.locator(".history-row").click();
  await expect(
    page.getByText("Felt strong today", { exact: true }),
  ).toBeVisible();
  await expect(page.locator(".history-exercise")).toContainText("50 kg × 8");
  await page.getByRole("button", { name: "Close dialog" }).click();
  await page.getByRole("button", { name: "Progress", exact: true }).click();
  await expect(page.locator(".progress-stats")).toContainText("800");
  await expect(page.locator(".records")).toContainText("63.3 kg");
  await page.reload();
  await page
    .getByRole("button", { name: "Workout history", exact: true })
    .click();
  await expect(page.locator(".history-row")).toHaveCount(1);
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByLabel("Your name").fill("Jordan Lee");
  await page.getByLabel("Weekly workout goal").selectOption("3");
  await page.getByRole("button", { name: "Save preferences" }).click();
  await expect(page.locator(".profile-button")).toContainText("Jordan Lee");
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export my data" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toContain("forma-backup");
  await page.getByRole("button", { name: "Overview", exact: true }).click();
  await page.getByRole("button", { name: "Schedule your week" }).click();
  await page.getByRole("button", { name: "Sunday", exact: true }).click();
  await page.getByRole("button", { name: "Save schedule" }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  const saved = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(saved.schedule).toContain(6);
  expect(saved.profile.goal).toBe(3);
  expect(saved.history).toHaveLength(1);
  expect(saved.active).toBeNull();
  expect(errors).toEqual([]);
});
test("mobile navigation, modal and active workout fit a phone", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("http://localhost:5173");
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.getByRole("button", { name: "Toggle navigation" }).click();
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Make every session yours." }),
  ).toBeVisible();
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await page
    .getByRole("button", {
      name: "Complete Barbell bench press set 1",
      exact: true,
    })
    .click();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: artifactPath("mobile-workout.png"),
    fullPage: true,
  });
  await page
    .getByRole("button", { name: "Discard workout", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Discard workout", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();
});
