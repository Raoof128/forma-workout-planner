import { test, expect } from "@playwright/test";

test("public guest workspace offers working backups rather than unavailable account forms", async ({
  page,
}) => {
  await page.goto("/#account");
  await expect(
    page.getByRole("heading", { name: "Your local workspace" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Sign in", exact: true }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Profile and backups" }).click();
  await expect(page).toHaveURL(/#settings$/);
  await expect(
    page.getByRole("button", { name: "Export my data", exact: true }),
  ).toBeVisible();
});

test("expanded exercise library searches all pages and loads source-attributed full guides", async ({
  page,
}) => {
  await page.goto("/#library");
  await expect(page.locator(".library-card")).toHaveCount(24);
  await page
    .getByRole("button", { name: "Show more exercises", exact: true })
    .click();
  await expect(page.locator(".library-card")).toHaveCount(48);
  await page.getByLabel("Search exercise library").fill("Farmer's Walk");
  await expect(page.locator(".library-card").first()).toContainText(
    "Farmer's Walk",
  );
  await page.locator(".library-card").first().click();
  await expect(page.getByRole("dialog")).toContainText("Free Exercise DB");
  await expect(page.getByRole("dialog")).toContainText("Unlicense");
  await expect(page.getByText("Loading full instructions…")).toHaveCount(0);
  await expect(page.locator(".instruction")).toHaveText(/\n\n/);
});

test("cardio templates log time and distance, persist history and allow measurement correction", async ({
  page,
}) => {
  await page.goto("/#routines");
  await page.getByRole("button", { name: /^Treadmill walk/ }).click();
  await expect(page.getByRole("dialog")).toContainText("1200 sec");
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await page
    .getByLabel("Walking, Treadmill set 1 durationSeconds", { exact: true })
    .fill("900");
  await page
    .getByLabel("Walking, Treadmill set 1 distanceMeters", { exact: true })
    .fill("800");
  await page
    .getByRole("button", {
      name: "Complete Walking, Treadmill set 1",
      exact: true,
    })
    .click();
  await expect(page.locator(".set-done")).toHaveCount(1);
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page.getByRole("button", { name: "Save workout", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Every session counts." }),
  ).toBeVisible();
  await page.locator(".history-row").first().click();
  await expect(page.getByRole("dialog")).toContainText("900 sec · 800 m");
  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  await page
    .getByLabel("Correct Walking, Treadmill set 1 distanceMeters", {
      exact: true,
    })
    .fill("850");
  await page
    .getByRole("button", { name: "Save corrections", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toContainText("900 sec · 850 m");
  await page.reload();
  const data = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(data.history[0].exercises[0].sets[0].distanceMeters).toBe(850);
});
