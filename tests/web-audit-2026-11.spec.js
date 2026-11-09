// Regressions for the November 2026 web frontend audit
// (docs/audits/web-frontend-2026-11/). Guest mode, dev server.
import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const origin = "http://127.0.0.1:5173";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const activeSession = (overrides = {}) => ({
  id: "audit-active",
  routineId: "upper",
  name: "Audit workout",
  startedAt: Date.now() - 30_000,
  notes: "",
  restSeconds: 60,
  restEnd: null,
  restPaused: null,
  exercises: [
    {
      exerciseId: "bench",
      sets: [
        { weight: 50, reps: 8, done: false },
        { weight: 50, reps: 8, done: false },
      ],
    },
    {
      exerciseId: "db-plank",
      sets: [{ weight: 0, reps: 1, durationSeconds: 60, done: false }],
    },
  ],
  ...overrides,
});
async function seed(page, data, hash) {
  await page.goto(origin);
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`${origin}/#${hash}`);
  await page.reload();
  await expect(page.locator("main h1")).toBeVisible();
}
const stored = (page) =>
  page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
const card = (page, name) =>
  page.locator(".log-exercise").filter({
    has: page.getByRole("heading", { name, exact: true }),
  });

test("a running hold survives leaving the workout screen and still logs", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-11-09T00:00:00Z") });
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data, "workout");

  const timer = card(page, "Plank").getByRole("group", {
    name: "Hold timer for Plank",
  });
  await timer
    .getByRole("button", { name: "Start 60-second hold for Plank set 1" })
    .click();
  await page.clock.fastForward(20_000);
  await expect(timer.getByRole("timer")).toHaveText("00:40");

  await page.getByRole("button", { name: /^Back to overview/ }).click();
  await expect(page.locator("main h1")).not.toHaveText(/audit workout/i);
  await page.clock.fastForward(10_000);
  await page.evaluate(() => (location.hash = "workout"));

  // Still running from where it was, not reset and not dropped.
  await expect(timer.getByRole("timer")).toHaveText("00:30");
  await page.clock.fastForward(31_000);
  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[0])
    .toMatchObject({ durationSeconds: 60, done: true });
});

test("session notes save after typing pauses, not on every keystroke", async ({
  page,
}) => {
  await page.addInitScript(() => {
    window.__notesWrites = 0;
    const setItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === "forma-v1" && String(value).includes("Felt strong"))
        window.__notesWrites += 1;
      return setItem.call(this, key, value);
    };
  });
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data, "workout");

  const notes = page.getByLabel("Session notes");
  await notes.pressSequentially("Felt strong today, bar speed good", {
    delay: 15,
  });
  await expect
    .poll(async () => (await stored(page)).active.notes)
    .toBe("Felt strong today, bar speed good");
  // 33 keystrokes; one idle save (two at most if the typing stalled once).
  expect(await page.evaluate(() => window.__notesWrites)).toBeLessThanOrEqual(
    2,
  );

  // Text typed right before leaving the screen is not lost.
  await notes.pressSequentially(". Rest 2 min");
  await page.getByRole("button", { name: /^Back to overview/ }).click();
  await expect
    .poll(async () => (await stored(page)).active.notes)
    .toBe("Felt strong today, bar speed good. Rest 2 min");
});

test("a text selection that ends outside a dialog does not close it", async ({
  page,
}) => {
  await seed(page, snapshot(), "routines");
  await page.locator(".routine-card").first().click();
  await page.getByRole("button", { name: "Edit routine" }).first().click();
  const dialog = page.getByRole("dialog");
  const name = dialog.getByLabel("Routine name");
  await name.fill("Upper body strength edited");

  const box = await name.boundingBox();
  await page.mouse.move(box.x + box.width - 10, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(4, 4, { steps: 8 });
  await page.mouse.up();
  await expect(dialog).toBeVisible();
  await expect(name).toHaveValue("Upper body strength edited");
});

test("set rows fit the workout card at 320px", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data, "workout");
  const check = page.getByRole("button", {
    name: "Complete Barbell bench press set 1",
    exact: true,
  });
  // The logged set's row, not the column-label row above it.
  const overflow = await check.evaluate((button) => {
    const row = button.closest(".set-row");
    const box = row.getBoundingClientRect();
    return [...row.children].map((child) => {
      const rect = child.getBoundingClientRect();
      return Math.max(rect.right - box.right, box.left - rect.left, 0);
    });
  });
  expect(Math.max(...overflow)).toBeLessThanOrEqual(0.5);
  const size = await check.boundingBox();
  expect(size.width).toBeGreaterThanOrEqual(40);
});

test("calendar days and the brand link name their visible text first", async ({
  page,
}) => {
  await seed(page, snapshot(), "overview");
  const day = page.locator(".day").first();
  const weekday = await day.locator(":scope > span").first().innerText();
  // Visible "Mon" and "9" start the name; the full description follows.
  await expect(day).toHaveAccessibleName(
    new RegExp(
      `^${weekday}\\s*\\d+\\s*, \\w+day \\d+ \\w+, \\d+ workouts? logged`,
    ),
  );
  await expect(
    page.getByRole("link", { name: "FORMA", exact: true }).first(),
  ).toBeVisible();
});
