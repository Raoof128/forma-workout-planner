import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";

test("existing archived routines stay hidden, editable and restorable without losing programming", async ({
  page,
}) => {
  const fixture = freshData();
  fixture.version = 1;
  fixture.routines.forEach((routine) => {
    routine.archivedAt = 1;
  });
  await page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
  await page.goto("/#overview");
  await expect(
    page.getByRole("heading", { name: "Upper body strength", exact: true }),
  ).toHaveCount(0);
  await page.goto("/#routines");
  await expect(
    page.getByRole("button", { name: /^Upper body strength 6 exercises/ }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Archived", exact: true }).click();
  await page
    .getByRole("button", { name: /^Upper body strength 6 exercises/ })
    .click();
  await expect(
    page.getByRole("button", { name: "Start workout", exact: true }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  await page
    .getByLabel("Barbell bench press reps", { exact: true })
    .fill("6-8");
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await page.reload();
  await page.getByRole("button", { name: "Archived", exact: true }).click();
  await page
    .getByRole("button", { name: /^Upper body strength 6 exercises/ })
    .click();
  await expect(
    page.getByRole("dialog").getByText("3 × 6–8 reps"),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Restore routine", exact: true })
    .click();
  await page.getByRole("button", { name: "Active", exact: true }).click();
  await expect(
    page.getByRole("button", { name: /^Upper body strength 6 exercises/ }),
  ).toBeVisible();
  const saved = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(saved.routines[0].archivedAt).toBeUndefined();
  expect(saved.routines[0].exercises[0].repsMax).toBe(8);
  await page.getByLabel("Actions for Upper body strength").click();
  await page
    .getByRole("button", { name: "Archive routine", exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: /^Upper body strength 6 exercises/ }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Archived", exact: true }).click();
  await page.getByLabel("Actions for Upper body strength").click();
  await page
    .getByRole("button", { name: "Duplicate routine", exact: true })
    .click();
  await expect(
    page
      .getByRole("dialog")
      .getByRole("heading", { name: "Upper body strength copy", exact: true }),
  ).toBeVisible();
  const copied = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(
    copied.routines.find(
      (routine) => routine.name === "Upper body strength copy",
    ).archivedAt,
  ).toBeUndefined();
  expect(copied.routines[0].archivedAt).toBeGreaterThan(0);
});
