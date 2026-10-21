import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const origin = "http://127.0.0.1:5173";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const timedSets = (count) =>
  Array.from({ length: count }, () => ({
    weight: 0,
    reps: 1,
    durationSeconds: 60,
    done: false,
  }));
const session = (overrides = {}) => ({
  id: "hold-active",
  routineId: "core",
  name: "Core test workout",
  startedAt: Date.now() - 30_000,
  notes: "",
  restSeconds: 60,
  restEnd: null,
  restPaused: null,
  exercises: [
    {
      exerciseId: "db-ab-roller",
      sets: [
        { weight: 0, reps: 10, done: false },
        { weight: 0, reps: 10, done: false },
      ],
    },
    { exerciseId: "db-plank", sets: timedSets(3) },
    {
      exerciseId: "bench",
      sets: [{ weight: 50, reps: 8, done: false }],
    },
  ],
  ...overrides,
});
async function seed(page, data, hash = "workout") {
  await page.goto(origin);
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`${origin}/#${hash}`);
  await page.reload();
}
const stored = (page) =>
  page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
const card = (page, name) =>
  page.locator(".log-exercise").filter({
    has: page.getByRole("heading", { name, exact: true }),
  });

test("exercises with no external load log without a weight column", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session();
  await seed(page, data);

  const roller = card(page, "Ab Roller");
  await expect(roller.getByLabel("Ab Roller set 1 reps")).toBeVisible();
  await expect(roller.getByLabel("Ab Roller set 1 weight")).toHaveCount(0);
  await expect(roller.locator(".set-labels")).not.toContainText("WEIGHT");
  await expect(roller.getByRole("group", { name: /^Hold timer/ })).toHaveCount(
    0,
  );

  const plank = card(page, "Plank");
  await expect(plank.getByLabel("Plank set 1 durationSeconds")).toBeVisible();
  await expect(plank.getByLabel("Plank set 1 weight")).toHaveCount(0);
  // Timed exercises no longer show a "1 reps" target.
  await expect(plank.locator(".program-target")).not.toContainText("reps");

  await expect(
    card(page, "Barbell bench press").getByLabel(
      "Barbell bench press set 1 weight",
    ),
  ).toBeVisible();

  await roller
    .getByRole("button", { name: "Complete Ab Roller set 1", exact: true })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0])
    .toMatchObject({ weight: 0, reps: 10, done: true });
});

test("an older log that carries weight keeps its weight column", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session({
    exercises: [
      {
        exerciseId: "db-ab-roller",
        sets: [{ weight: 5, reps: 10, done: false }],
      },
    ],
  });
  await seed(page, data);
  await expect(page.getByLabel("Ab Roller set 1 weight")).toHaveValue("5");
});

test("the plank hold timer counts down, pauses, logs the set and starts rest", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-21T00:00:00Z") });
  const data = snapshot();
  data.active = session();
  await seed(page, data);

  const plank = card(page, "Plank");
  const timer = plank.getByRole("group", { name: "Hold timer for Plank" });
  await expect(timer).toBeVisible();
  await expect(timer.getByRole("timer")).toHaveText("01:00");
  await expect(
    card(page, "Barbell bench press").getByRole("group", {
      name: /^Hold timer/,
    }),
  ).toHaveCount(0);

  await timer.getByRole("button", { name: /^Longer hold/ }).click();
  await expect(timer.getByRole("timer")).toHaveText("01:05");
  await timer.getByRole("button", { name: /^Shorter hold/ }).click();
  await expect(timer.getByRole("timer")).toHaveText("01:00");

  await timer
    .getByRole("button", { name: "Start 60-second hold for Plank set 1" })
    .click();
  await page.clock.fastForward(30_000);
  await expect(timer.getByRole("timer")).toHaveText("00:30");
  await timer.getByRole("button", { name: "Pause hold timer" }).click();
  await page.clock.fastForward(10_000);
  await expect(timer.getByRole("timer")).toHaveText("00:30");
  await timer.getByRole("button", { name: "Resume hold timer" }).click();
  await page.clock.fastForward(31_000);

  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[0])
    .toMatchObject({ weight: 0, reps: 1, durationSeconds: 60, done: true });
  expect((await stored(page)).active.restEnd).not.toBeNull();
  await expect(page.getByRole("status")).toContainText(
    "Plank set 1 logged: 60 seconds",
  );
  await expect(
    plank.getByRole("button", { name: "Uncomplete Plank set 1", exact: true }),
  ).toBeVisible();

  // Ending early logs the time actually held.
  await timer
    .getByRole("button", { name: "Start 60-second hold for Plank set 2" })
    .click();
  await page.clock.fastForward(20_000);
  await timer
    .getByRole("button", { name: "End set 2 now and log 20 seconds" })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[1])
    .toMatchObject({ weight: 0, reps: 1, durationSeconds: 20, done: true });

  // Cancelling logs nothing.
  await timer
    .getByRole("button", { name: "Start 60-second hold for Plank set 3" })
    .click();
  await page.clock.fastForward(5_000);
  await timer
    .getByRole("button", { name: "Cancel hold timer without logging" })
    .click();
  await page.clock.fastForward(70_000);
  expect((await stored(page)).active.exercises[1].sets[2]).toMatchObject({
    weight: 0,
    reps: 1,
    durationSeconds: 60,
    done: false,
  });
});

test("the starter plank's timer logs one rep per 10 seconds held", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-21T00:00:00Z") });
  const data = snapshot();
  data.active = session({
    exercises: [
      {
        exerciseId: "plank",
        sets: [
          { weight: 0, reps: 3, done: false },
          { weight: 0, reps: 3, done: false },
        ],
      },
    ],
  });
  await seed(page, data);

  const timer = page.getByRole("group", {
    name: "Hold timer for Forearm plank",
  });
  await expect(timer.getByRole("timer")).toHaveText("00:30");
  await expect(page.getByLabel("Forearm plank set 1 weight")).toHaveCount(0);
  await timer.getByRole("button", { name: "Longer hold, 40 seconds" }).click();
  await expect(timer.getByRole("timer")).toHaveText("00:40");
  await timer.getByRole("button", { name: "Shorter hold, 30 seconds" }).click();

  await timer
    .getByRole("button", {
      name: "Start 30-second hold for Forearm plank set 1",
    })
    .click();
  await page.clock.fastForward(31_000);
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0])
    .toMatchObject({ weight: 0, reps: 3, done: true });
  await expect(page.getByRole("status")).toContainText(
    "Forearm plank set 1 logged: 3 reps (30 seconds)",
  );

  // Ending early logs only the full 10-second reps held.
  await timer
    .getByRole("button", {
      name: "Start 30-second hold for Forearm plank set 2",
    })
    .click();
  await page.clock.fastForward(5_000);
  await expect(
    timer.getByRole("button", { name: /^End set 2 now/ }),
  ).toBeDisabled();
  await page.clock.fastForward(20_000);
  await timer
    .getByRole("button", {
      name: "End set 2 now and log 2 reps (20 seconds)",
    })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[1])
    .toMatchObject({ weight: 0, reps: 2, done: true });
});

test("the routine editor shows no load input for no-load exercises", async ({
  page,
}) => {
  const data = snapshot();
  data.routines[0].exercises.unshift({
    exerciseId: "db-ab-roller",
    repsMax: 15,
    rpe: null,
    restSeconds: 60,
    perSide: false,
    note: null,
    groupId: null,
    sets: 3,
    reps: 10,
    weight: 0,
  });
  await seed(page, data, "routines");
  await page
    .getByRole("button", { name: /^Upper body strength \d+ exercises/ })
    .click();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  await expect(
    page.getByLabel("Ab Roller reps", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByLabel("Ab Roller weight", { exact: true }),
  ).toHaveCount(0);
  await expect(
    page.getByLabel("Barbell bench press weight", { exact: true }),
  ).toBeVisible();
});
