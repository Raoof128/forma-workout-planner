import { verifyAliasCollisionMigration } from "./helpers.js";
import { test, expect } from "@playwright/test";

test("program every field, reload, overview, superset rest and actual RPE", async ({
  page,
}) => {
  await page.goto("/#routines");
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Routine name").fill("Program v2");
  for (const name of [
    "Incline Dumbbell Press",
    "Dumbbell reverse lunge",
    "Leg press",
  ]) {
    await dialog
      .getByRole("textbox", { name: "Search exercises for routine" })
      .fill(name);
    await dialog
      .getByRole("button")
      .filter({ hasText: name })
      .filter({ has: page.locator("small") })
      .first()
      .click();
  }
  await dialog
    .getByLabel("Incline Dumbbell Press reps", { exact: true })
    .fill("8–10");
  await dialog
    .getByLabel("Incline Dumbbell Press rpe", { exact: true })
    .fill("8");
  await dialog
    .getByLabel("Incline Dumbbell Press restSeconds", { exact: true })
    .fill("90");
  await dialog.getByLabel("Options for Incline Dumbbell Press").click();
  await dialog
    .getByLabel("Incline Dumbbell Press note", { exact: true })
    .fill("30° bench");
  await dialog
    .getByLabel("Dumbbell reverse lunge rpe", { exact: true })
    .fill("8");
  await dialog
    .getByLabel("Dumbbell reverse lunge restSeconds", { exact: true })
    .fill("75");
  await dialog.getByLabel("Options for Dumbbell reverse lunge").click();
  await expect(
    dialog.getByLabel("Dumbbell reverse lunge per side", { exact: true }),
  ).toBeChecked();
  await dialog
    .getByLabel("Dumbbell reverse lunge superset with previous", {
      exact: true,
    })
    .check();
  await dialog.getByLabel("Leg press rpe", { exact: true }).fill("8");
  await dialog.getByLabel("Leg press restSeconds", { exact: true }).fill("90");
  await dialog.getByLabel("Options for Leg press").click();
  await dialog
    .getByLabel("Leg press note", { exact: true })
    .fill("wide stance <b>cue</b>");
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await expect(dialog).toHaveCount(0);
  await page.reload();
  await page.getByRole("button", { name: /Program v2.*3 exercises/ }).click();
  const overview = page.getByRole("dialog");
  await expect(overview.getByText("3 × 8–10 reps")).toBeVisible();
  await expect(overview.getByText("3 × 10 / leg")).toBeVisible();
  await expect(
    overview.getByText("wide stance <b>cue</b>", { exact: true }),
  ).toBeVisible();
  await expect(overview.locator("b")).toHaveCount(0);
  await expect(overview.getByText("A1", { exact: true })).toBeVisible();
  await expect(overview.getByText("A2", { exact: true })).toBeVisible();
  await overview
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Program v2", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Target: 8–10 reps", { exact: false }),
  ).toBeVisible();
  await page
    .getByLabel("Incline Dumbbell Press set 1 rpe", { exact: true })
    .fill("8.5");
  await page
    .getByRole("button", {
      name: "Complete Incline Dumbbell Press set 1",
      exact: true,
    })
    .click();
  await expect(page.getByRole("timer")).toHaveText("00:00");
  await page
    .getByRole("button", {
      name: "Complete Dumbbell reverse lunge set 1",
      exact: true,
    })
    .click();
  await expect(page.getByRole("timer")).toHaveText(/01:1[0-5]/);
  await page
    .getByRole("button", { name: "Add 15 seconds", exact: true })
    .click();
  await expect(page.getByRole("timer")).toHaveText(/01:[23]\d/);
  await page.reload();
  await expect(page.getByRole("timer")).toHaveText(/01:[123]\d/);
  await expect(
    page.getByLabel("Incline Dumbbell Press set 1 rpe", { exact: true }),
  ).toHaveValue("8.5");
  await page.getByRole("button", { name: "Skip", exact: true }).click();
  await expect(page.getByRole("timer")).toHaveText("00:00");
});

test("duplicate routine is independent; drag and arrows preserve programming", async ({
  page,
  browserName,
}) => {
  await page.goto("/#routines");
  await page.getByLabel("Actions for Upper body strength").click();
  await page
    .getByRole("button", { name: "Duplicate routine", exact: true })
    .click();
  await expect(
    page
      .getByRole("dialog")
      .getByRole("heading", { name: "Upper body strength copy", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  const dialog = page.getByRole("dialog");
  await dialog
    .getByLabel("Barbell bench press reps", { exact: true })
    .fill("6-8");
  await dialog
    .getByRole("button", { name: "Move Barbell bench press down", exact: true })
    .click();
  await expect(
    dialog.locator(".prescription:not(.labels)").nth(1),
  ).toContainText("Barbell bench press");
  if (browserName === "chromium") {
    await dialog
      .getByRole("button", { name: "Drag Barbell bench press", exact: true })
      .dragTo(dialog.locator(".prescription:not(.labels)").nth(0));
    await expect(
      dialog.locator(".prescription:not(.labels)").first(),
    ).toContainText("Barbell bench press");
  }
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await page
    .getByRole("button", {
      name: "Upper body strength 6 exercises · 50 min",
      exact: true,
    })
    .click();
  await expect(page.getByRole("dialog").getByText("3 × 10 reps")).toHaveCount(
    6,
  );
});

test("removing and reselecting a superset exercise leaves a saveable routine", async ({
  page,
}) => {
  await page.goto("/#routines");
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Routine name").fill("Restored superset");
  for (const name of ["Barbell bench press", "One-arm dumbbell row"]) {
    await dialog.getByLabel("Search exercises for routine").fill(name);
    await dialog
      .locator(".exercise-picker button")
      .filter({ hasText: name })
      .first()
      .click();
  }
  await dialog.getByLabel("Options for One-arm dumbbell row").click();
  await dialog
    .getByLabel("One-arm dumbbell row superset with previous", { exact: true })
    .check();
  const row = dialog
    .locator(".exercise-picker button")
    .filter({ hasText: "One-arm dumbbell row" })
    .first();
  await row.click();
  await row.click();
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await expect(dialog).toHaveCount(0);
});

test("first migrated alias collision starts immediately without a false stale-routine conflict", async ({
  page,
}) => {
  await verifyAliasCollisionMigration(page);
});
