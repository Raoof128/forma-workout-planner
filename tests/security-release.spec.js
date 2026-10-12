import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const origin = "http://localhost:5173";
const attackText = "<img src=https://evil.invalid onerror=alert(1)>";

async function waitForStore(page) {
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("forma-v1")))
    .not.toBeNull();
}

test("malformed import reports failure and leaves the current workspace untouched", async ({
  page,
}) => {
  await page.goto(`${origin}/#settings`);
  await waitForStore(page);
  const before = await page.evaluate(() => localStorage.getItem("forma-v1"));

  await page.getByLabel("Import backup", { exact: true }).setInputFiles({
    name: "malformed.json",
    mimeType: "application/json",
    buffer: Buffer.from("{not valid JSON"),
  });

  await expect(page.getByRole("alert")).toContainText(
    "Nothing has been changed",
  );
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(await page.evaluate(() => localStorage.getItem("forma-v1"))).toBe(
    before,
  );
});

test("dangerous imported text stays literal and application assets make no external requests", async ({
  page,
}) => {
  const externalRequests = [];
  const pageErrors = [];
  const dialogs = [];
  page.on("request", (request) => {
    const requestUrl = new URL(request.url());
    if (requestUrl.origin !== origin) externalRequests.push(request.url());
  });
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("dialog", async (dialog) => {
    dialogs.push(dialog.type());
    await dialog.dismiss();
  });

  await page.goto(`${origin}/#settings`);
  await waitForStore(page);

  const backup = structuredClone(initialData);
  backup.profile.name = attackText;
  backup.routines[0].name = attackText;
  backup.routines[0].description = attackText;
  backup.history = [
    {
      id: "xss-history",
      routineId: backup.routines[0].id,
      name: attackText,
      startedAt: 1_000,
      notes: attackText,
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: [
        {
          exerciseId: "bench",
          sets: [{ weight: 20, reps: 5, done: true }],
        },
      ],
      date: "2026-10-11T00:00:00.000Z",
      duration: 60,
    },
  ];

  await page.getByLabel("Import backup", { exact: true }).setInputFiles({
    name: "untrusted.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(backup)),
  });
  await expect(page.getByRole("dialog")).toContainText("untrusted.json");
  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();

  await expect(page.locator(".profile-button")).toContainText(attackText);
  const restored = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(restored.profile.name).toBe(attackText);
  expect(restored.routines[0].name).toBe(attackText);
  expect(restored.routines[0].description).toBe(attackText);
  expect(restored.history[0].name).toBe(attackText);
  expect(restored.history[0].notes).toBe(attackText);

  await page.reload();
  await expect(page.locator(".profile-button")).toContainText(attackText);
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await expect(page.locator(".routine-card").first()).toContainText(attackText);
  await page
    .getByRole("button", { name: "Workout history", exact: true })
    .click();
  await expect(page.locator(".history-row h3").first()).toHaveText(attackText);
  await page.locator(".history-row").click();
  await expect(page.locator(".modal-content h2")).toHaveText(attackText);
  await expect(page.locator(".modal-content .tip p")).toHaveText(attackText);

  expect(await page.locator("img[src*='evil.invalid']").count()).toBe(0);
  expect(dialogs).toEqual([]);
  expect(pageErrors).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test("export failure is surfaced to the user", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(URL, "createObjectURL", {
      configurable: true,
      value() {
        throw new Error("Download unavailable");
      },
    });
  });
  await page.goto(`${origin}/#settings`);
  await page
    .getByRole("button", { name: "Export my data", exact: true })
    .click();
  await expect(page.getByRole("alert")).toHaveText(
    "The backup download could not start. Try again.",
  );
});
