import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const origin = "http://127.0.0.1:5173";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const singleSession = (overrides = {}) => ({
  id: "release-active",
  routineId: "upper",
  name: "Release test workout",
  startedAt: Date.now() - 30_000,
  notes: "",
  restSeconds: 90,
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
  ],
  ...overrides,
});
async function seed(page, data, hash = "overview") {
  await page.goto(origin);
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`${origin}/#${hash}`);
  await page.reload();
}
async function stored(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
}
async function nav(page, name) {
  await page.getByRole("button", { name, exact: true }).click();
}

test("set validation, completion undo, added sets, finish cancel and save preserve exact data", async ({
  page,
}) => {
  const data = snapshot();
  data.active = singleSession();
  await seed(page, data, "workout");

  const weight = page.getByLabel("Barbell bench press set 1 weight", {
    exact: true,
  });
  const reps = page.getByLabel("Barbell bench press set 1 reps", {
    exact: true,
  });
  const complete = page.getByRole("button", {
    name: "Complete Barbell bench press set 1",
    exact: true,
  });

  await weight.fill("");
  await complete.click();
  await expect(page.getByRole("status")).toContainText("Enter 1–100 reps");
  expect((await stored(page)).active.exercises[0].sets[0].done).toBe(false);

  await weight.fill("50");
  await reps.fill("101");
  await complete.click();
  await expect(page.getByRole("status")).toContainText("Enter 1–100 reps");
  expect((await stored(page)).active.exercises[0].sets[0].done).toBe(false);

  await reps.fill("8");
  await weight.fill("1001");
  await complete.click();
  await expect(page.getByRole("status")).toContainText(
    "weight from 0–1,000 kg",
  );
  expect((await stored(page)).active.exercises[0].sets[0].done).toBe(false);

  await weight.fill("50");
  await complete.click();
  await expect(
    page.getByRole("button", {
      name: "Uncomplete Barbell bench press set 1",
      exact: true,
    }),
  ).toHaveAttribute("aria-pressed", "true");
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0].done)
    .toBe(true);
  await page
    .getByRole("button", {
      name: "Uncomplete Barbell bench press set 1",
      exact: true,
    })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0].done)
    .toBe(false);

  await page.getByRole("button", { name: "Add set", exact: true }).click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets.length)
    .toBe(3);
  expect((await stored(page)).active.exercises[0].sets[2]).toEqual({
    weight: 50,
    reps: 8,
    done: false,
  });
  await page.reload();
  await expect(
    page.getByLabel("Barbell bench press set 3 reps", { exact: true }),
  ).toHaveValue("8");
  await page
    .getByRole("button", {
      name: "Complete Barbell bench press set 1",
      exact: true,
    })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0].done)
    .toBe(true);

  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page
    .getByRole("button", { name: "Keep training", exact: true })
    .click();
  expect((await stored(page)).active.id).toBe("release-active");
  expect((await stored(page)).history).toHaveLength(0);

  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await expect(page.getByRole("dialog")).toContainText(
    "2 unfinished sets will not count",
  );
  await page.getByRole("button", { name: "Save workout", exact: true }).click();
  await expect(page.locator(".history-row")).toHaveCount(1);
  const saved = await stored(page);
  expect(saved.active).toBeNull();
  expect(saved.history[0].exercises[0].sets[0]).toMatchObject({
    weight: 50,
    reps: 8,
    done: true,
  });
  expect(
    saved.history[0].exercises[0].sets.slice(1).every((set) => !set.done),
  ).toBe(true);
});

test("empty finish is blocked and discard can be canceled or confirmed", async ({
  page,
}) => {
  const data = snapshot();
  data.active = singleSession();
  await seed(page, data, "workout");

  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await expect(page.getByRole("status")).toContainText(
    "Complete at least one set",
  );
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect((await stored(page)).history).toHaveLength(0);

  await page
    .getByRole("button", { name: "Discard workout", exact: true })
    .click();
  await page.getByRole("button", { name: "Keep it", exact: true }).click();
  expect((await stored(page)).active.id).toBe("release-active");
  await page
    .getByRole("button", { name: "Discard workout", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Discard workout", exact: true })
    .last()
    .click();
  await expect(page.locator(".hero")).toBeVisible();
  expect((await stored(page)).active).toBeNull();
  expect((await stored(page)).history).toHaveLength(0);
});

test("routine switch can resume, cancel, or replace an active session", async ({
  page,
}) => {
  const switching = snapshot();
  switching.active = singleSession({
    id: "switch-source",
    routineId: "lower",
    name: switching.routines[1].name,
    exercises: switching.routines[1].exercises.map((entry) => ({
      exerciseId: entry.exerciseId,
      sets: Array.from({ length: entry.sets }, () => ({
        weight: entry.weight,
        reps: entry.reps,
        done: false,
      })),
    })),
  });
  await seed(page, switching, "overview");
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toContainText(
    "already have a workout running",
  );
  await page
    .getByRole("button", { name: "Resume existing", exact: true })
    .click();
  await expect(page.locator("h1")).toHaveText(switching.active.name);
  expect((await stored(page)).active.id).toBe("switch-source");

  await nav(page, "Overview");
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await page.getByRole("button", { name: "Close dialog", exact: true }).click();
  expect((await stored(page)).active.id).toBe("switch-source");
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Discard and start new", exact: true })
    .click();
  await expect(page.locator("h1")).toHaveText(switching.routines[0].name);
  const replacement = (await stored(page)).active;
  expect(replacement.id).not.toBe("switch-source");
  expect(replacement.routineId).toBe(switching.routines[0].id);
  expect((await stored(page)).history).toHaveLength(0);
});

test("60, 90, and 120 second timers persist their deadlines and expiry clears timer state", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-12T00:00:00Z") });
  const data = snapshot();
  data.active = singleSession();
  await seed(page, data, "workout");

  for (const seconds of [60, 90, 120]) {
    const before = await page.evaluate(() => Date.now());
    await page
      .getByRole("button", { name: `${seconds}s`, exact: true })
      .click();
    const after = await page.evaluate(() => Date.now());
    await expect
      .poll(async () => (await stored(page)).active.restSeconds)
      .toBe(seconds);
    const active = (await stored(page)).active;
    expect(active.restEnd).toBeGreaterThanOrEqual(before + seconds * 1000);
    // Bracket the click's actual browser time, rather than assuming the
    // automation click completes within one second on every machine.
    expect(active.restEnd).toBeLessThanOrEqual(after + seconds * 1000);
    expect(active.restPaused).toBeNull();
    await expect(
      page.getByRole("button", { name: `${seconds}s`, exact: true }),
    ).toHaveAttribute("aria-pressed", "true");
  }

  await page
    .getByRole("button", { name: "Pause rest timer", exact: true })
    .click();
  await expect.poll(async () => (await stored(page)).active.restEnd).toBeNull();
  expect((await stored(page)).active.restPaused).toBeGreaterThan(0);
  await page
    .getByRole("button", { name: "Start rest timer", exact: true })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.restEnd)
    .not.toBeNull();
  expect((await stored(page)).active.restPaused).toBeNull();

  await page.getByRole("button", { name: "60s", exact: true }).click();
  await page.clock.fastForward(60_100);
  await expect.poll(async () => (await stored(page)).active.restEnd).toBeNull();
  expect((await stored(page)).active.restPaused).toBeNull();
  await expect(page.getByRole("status")).toContainText("Rest complete");
  await page.reload();
  expect((await stored(page)).active.restEnd).toBeNull();
});

test("real-time rest timer smoke decrements and survives a reload", async ({
  page,
}) => {
  const data = snapshot();
  data.active = singleSession();
  await seed(page, data, "workout");
  await page.getByRole("button", { name: "60s", exact: true }).click();
  const deadline = (await stored(page)).active.restEnd;
  await expect(page.locator('[role="timer"]')).toContainText("00:5");
  await page.waitForTimeout(1200);
  const after = (await stored(page)).active.restEnd;
  expect(after).toBe(deadline);
  expect(deadline - Date.now()).toBeGreaterThan(56_000);
  expect(deadline - Date.now()).toBeLessThan(60_000);
  await page.reload();
  await expect(page.locator('[role="timer"]')).toContainText("00:5");
  expect((await stored(page)).active.restEnd).toBe(deadline);
});

test("bodyweight logging counts completed sets with zero external-load volume and survives reload", async ({
  page,
}) => {
  const data = snapshot();
  data.active = {
    ...singleSession(),
    id: "bodyweight-session",
    name: "Bodyweight session",
    exercises: [
      {
        exerciseId: "pushup",
        sets: [{ weight: 0, reps: 12, done: false }],
      },
    ],
  };
  await seed(page, data, "workout");
  await page
    .getByRole("button", { name: "Complete Push-up set 1", exact: true })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0].done)
    .toBe(true);
  await expect(
    page
      .locator(".session-stats > div")
      .filter({ hasText: "SETS COMPLETED" })
      .locator("strong"),
  ).toHaveText("1 / 1");
  await expect(
    page
      .locator(".session-stats > div")
      .filter({ hasText: "VOLUME LIFTED" })
      .locator("strong"),
  ).toHaveText("0 kg");
  expect((await stored(page)).active.exercises[0].sets[0]).toEqual({
    weight: 0,
    reps: 12,
    done: true,
  });
  await page.reload();
  await expect(
    page
      .locator(".session-stats > div")
      .filter({ hasText: "SETS COMPLETED" })
      .locator("strong"),
  ).toHaveText("1 / 1");
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page.getByRole("button", { name: "Save workout", exact: true }).click();
  await expect(page.locator(".history-row")).toContainText("0 kg");
  await nav(page, "Progress");
  await expect(
    page
      .locator(".progress-stat")
      .filter({ hasText: "Sets completed" })
      .locator("strong"),
  ).toHaveText("1");
  await expect(
    page
      .locator(".progress-stat")
      .filter({ hasText: "Total volume · kg" })
      .locator("strong"),
  ).toHaveText("0");
  await expect(page.locator(".records")).toContainText("Push-up");
  await expect(page.locator(".records")).toContainText("0 kg");
});

test("history editor discard keeps persisted data unchanged and stale edits are rejected", async ({
  page,
  context,
}) => {
  const data = snapshot();
  const completed = singleSession({
    id: "history-conflict",
    date: "2026-10-11T10:00:00.000Z",
    duration: 600,
    exercises: [
      {
        exerciseId: "bench",
        sets: [{ weight: 50, reps: 8, done: true }],
      },
    ],
  });
  data.history = [completed];
  await seed(page, data, "history");
  await page.locator(".history-row").click();
  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  const note = page.getByLabel("Workout notes");
  await note.fill("unsaved local correction");
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Discard workout changes?" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Keep editing", exact: true }).click();
  await expect(note).toHaveValue("unsaved local correction");
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await page
    .getByRole("button", { name: "Discard changes", exact: true })
    .click();
  expect((await stored(page)).history[0].notes).toBe("");

  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  await note.fill("stale edit from first tab");
  const other = await context.newPage();
  await other.goto(`${origin}/#history`);
  await other.locator(".history-row").click();
  await other
    .getByRole("button", { name: "Edit workout", exact: true })
    .click();
  await other.getByLabel("Workout name").fill("Updated in second tab");
  await other
    .getByRole("button", { name: "Save corrections", exact: true })
    .click();
  await expect(
    other.getByRole("heading", { name: "Workout complete" }),
  ).toBeVisible();
  await expect
    .poll(async () => (await stored(page)).history[0].name)
    .toBe("Updated in second tab");

  await page
    .getByRole("button", { name: "Save corrections", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText(
    "changed in another tab",
  );
  await expect(
    page.getByRole("heading", { name: "Correct your workout" }),
  ).toBeVisible();
  await expect(note).toHaveValue("stale edit from first tab");
  expect((await stored(page)).history[0].name).toBe("Updated in second tab");
  expect((await stored(page)).history[0].notes).toBe("");
});

test("2,000 completed workouts render correct aggregate progress within a practical bound", async ({
  page,
}) => {
  const data = snapshot();
  const started = Date.now();
  data.history = Array.from({ length: 2000 }, (_, index) => ({
    id: `large-history-${index}`,
    routineId: "upper",
    name: `Session ${index}`,
    startedAt: 1_700_000_000_000 + index * 1000,
    date: new Date(1_700_000_000_000 + index * 1000).toISOString(),
    duration: 3600,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        exerciseId: "bench",
        sets: [{ weight: 1, reps: 1, done: true }],
      },
    ],
  }));
  await seed(page, data, "progress");
  await expect(
    page
      .locator(".progress-stat")
      .filter({ hasText: "Workouts completed" })
      .locator("strong"),
  ).toHaveText("2000");
  await expect(
    page
      .locator(".progress-stat")
      .filter({ hasText: "Total volume · kg" })
      .locator("strong"),
  ).toHaveText("2,000");
  await expect(
    page
      .locator(".progress-stat")
      .filter({ hasText: "Sets completed" })
      .locator("strong"),
  ).toHaveText("2000");
  await expect(page.locator(".records")).toContainText("Barbell bench press");
  expect(Date.now() - started).toBeLessThan(10_000);
  const backupBytes = await page.evaluate(
    () => new Blob([localStorage.getItem("forma-v1")]).size,
  );
  expect(backupBytes).toBeLessThan(20 * 1024 * 1024);
});

test("progress verifies 80 kg × 5 rounding, includes 12 reps, and excludes 13", async ({
  page,
}) => {
  const data = snapshot();
  const makeHistory = (id, exerciseId, weight, reps, date) => ({
    id,
    routineId: "upper",
    name: id,
    startedAt: Date.parse(date),
    date,
    duration: 60,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [{ exerciseId, sets: [{ weight, reps, done: true }] }],
  });
  data.history = [
    makeHistory("epley-12", "bench", 60, 12, "2026-10-10T10:00:00.000Z"),
    makeHistory("epley-13", "row", 60, 13, "2026-10-11T10:00:00.000Z"),
    makeHistory("epley-five", "shoulder", 80, 5, "2026-10-12T10:00:00.000Z"),
  ];
  await seed(page, data, "progress");
  const twelveRep = page
    .locator(".record-row")
    .filter({ hasText: "Barbell bench press" });
  await expect(twelveRep).toContainText("84 kg");
  const row = page
    .locator(".record-row")
    .filter({ hasText: "One-arm dumbbell row" });
  await expect(row).toContainText("60 kg");
  await expect(row).toContainText("—");
  const fiveRep = page
    .locator(".record-row")
    .filter({ hasText: "Dumbbell shoulder press" });
  await expect(fiveRep).toContainText("93.3 kg");
});
