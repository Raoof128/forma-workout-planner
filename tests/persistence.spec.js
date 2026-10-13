import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";
const origin = "http://localhost:5173";

test("rejected Web Locks keep the app usable without unhandled errors", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.addInitScript(() => {
    Object.defineProperty(navigator, "locks", {
      value: {
        request: () =>
          Promise.reject(new DOMException("Denied", "SecurityError")),
      },
    });
  });
  await page.goto(origin);
  await expect(page.getByRole("alert")).toContainText("saving is unavailable");
  await page.locator(".hero button").click();
  await page.getByLabel("Session notes").fill("Retained without locks");
  await page.getByRole("button", { name: "Overview", exact: true }).click();
  await page.locator(".hero button").click();
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Retained without locks",
  );
  expect(errors).toEqual([]);
});

test("missing secure-context UUID and locks still permit temporary routines and workouts", async ({
  page,
}) => {
  await page.addInitScript(() => {
    Object.defineProperty(navigator, "locks", { value: undefined });
    Object.defineProperty(crypto, "randomUUID", { value: undefined });
  });
  await page.goto(`${origin}/#routines`);
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  await page.getByLabel("Routine name").fill("Temporary routine");
  await page.locator(".exercise-picker button").first().click();
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  const card = page
    .locator(".routine-card")
    .filter({ hasText: "Temporary routine" });
  await card.click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(page.locator("h1")).toHaveText("Temporary routine");
  await expect(page.getByRole("alert")).toContainText("saving is unavailable");
});

test("restore after quota recovery preserves temporary edits and saved originals", async ({
  page,
}) => {
  await page.goto(`${origin}/#settings`);
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("forma-v1")))
    .not.toBeNull();
  await page.evaluate(() => {
    const write = Storage.prototype.setItem;
    window.blockWrites = true;
    Storage.prototype.setItem = function (key, value) {
      if (window.blockWrites)
        throw new DOMException("Full", "QuotaExceededError");
      return write.call(this, key, value);
    };
  });
  await page.getByLabel("Your name").fill("Temporary profile");
  await page
    .getByRole("button", { name: "Save preferences", exact: true })
    .click();
  await expect(page.getByRole("alert")).toContainText("saving is unavailable");
  await page.getByLabel("Import backup", { exact: true }).setInputFiles({
    name: "backup.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(initialData)),
  });
  await page.evaluate(() => {
    window.blockWrites = false;
  });
  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();
  await expect(page.locator(".hero")).toBeVisible();
  const originals = await page.evaluate(() =>
    Object.keys(localStorage)
      .filter((key) => key.startsWith("forma-v1-recovery-"))
      .map((key) => JSON.parse(localStorage.getItem(key)).profile.name),
  );
  expect(originals).toContain("Temporary profile");
  expect(originals).toContain("Guest");
});

test("starting stale routine details cannot silently use old prescriptions", async ({
  page,
  context,
}) => {
  await page.goto(`${origin}/#routines`);
  await page.locator(".routine-card").first().click();
  const other = await context.newPage();
  await other.goto(`${origin}/#routines`);
  await other.locator(".routine-card").first().click();
  await other
    .getByRole("button", { name: "Edit routine", exact: true })
    .click();
  await other
    .getByLabel("Barbell bench press weight", { exact: true })
    .fill("77");
  await other
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await expect(other.getByRole("dialog")).toHaveCount(0);
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText(
    "routine changed in another tab",
  );
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).active,
    ),
  ).toBeNull();
});

test("fractional imported weights can be corrected and a future rest timer can pause", async ({
  page,
}) => {
  const data = structuredClone(initialData);
  data.routines[0].exercises[0].weight = 22.25;
  data.active = {
    id: "fractional",
    name: "Fractional workout",
    startedAt: Date.now(),
    restEnd: Date.now() + 3600000,
    exercises: [
      { exerciseId: "bench", sets: [{ weight: 22.25, reps: 8, done: true }] },
    ],
  };
  data.history = [
    {
      ...data.active,
      id: "fractional-history",
      restEnd: null,
      date: new Date().toISOString(),
      duration: 60,
    },
  ];
  await page.goto(origin);
  await page.evaluate(
    (data) => localStorage.setItem("forma-v1", JSON.stringify(data)),
    data,
  );
  await page.goto(`${origin}/#routines`);
  await page.reload();
  await page.locator(".routine-card").first().click();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  await page.getByLabel("Routine name").fill("Preserve fractional weight");
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.goto(`${origin}/#history`);
  await page.locator(".history-row").click();
  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  await page.getByLabel("Workout name").fill("Corrected fractional workout");
  await page
    .getByRole("button", { name: "Save corrections", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Workout complete", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Close dialog", exact: true }).click();
  await page.goto(`${origin}/#workout`);
  await page
    .getByRole("button", { name: "Pause rest timer", exact: true })
    .click();
  await expect
    .poll(() =>
      page.evaluate(
        () => JSON.parse(localStorage.getItem("forma-v1")).active.restPaused,
      ),
    )
    .toBe(600);
});

test("repeated concurrent profile and session writes preserve both fields", async ({
  page,
  context,
}) => {
  test.setTimeout(60000);
  await page.goto(origin);
  await page.locator(".hero button").click();
  const other = await context.newPage();
  await other.goto(`${origin}/#settings`);
  for (let i = 0; i < 12; i++) {
    await other.getByLabel("Your name").fill(`Concurrent profile ${i}`);
    await Promise.all([
      page.getByLabel("Session notes").fill(`Concurrent note ${i}`),
      other
        .getByRole("button", { name: "Save preferences", exact: true })
        .click(),
    ]);
    await expect
      .poll(() =>
        page.evaluate(() => {
          const data = JSON.parse(localStorage.getItem("forma-v1"));
          return [data.profile.name, data.active.notes];
        }),
      )
      .toEqual([`Concurrent profile ${i}`, `Concurrent note ${i}`]);
    await expect(
      other.getByRole("button", { name: "Save preferences", exact: true }),
    ).toBeEnabled();
  }
  await page.reload();
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Concurrent note 11",
  );
});
