import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const HOLLOW = "wger-d059c63d-0a81-48a3-912a-44070c0def2e";
const LSIT = "wger-16202754-f567-4d23-a866-2c9cc8eba71d";
const CRUCIFIX = "db-crucifix";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const session = (exercises) => ({
  id: "skills-active",
  routineId: "upper",
  name: "Skills workout",
  startedAt: Date.parse("2026-10-21T00:00:00Z") - 30_000,
  notes: "",
  restSeconds: 60,
  restEnd: null,
  restPaused: null,
  exercises,
});
async function seed(page, data, hash) {
  await page.goto("/");
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`/#${hash}`);
  await page.reload();
}
const stored = (page) =>
  page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
const card = (page, name) =>
  page.locator(".log-exercise").filter({
    has: page.getByRole("heading", { name, exact: true }),
  });

test("a hold added to a workout logs seconds with the hold timer", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-21T00:00:00Z") });
  const data = snapshot();
  data.active = session([
    { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: false }] },
  ]);
  await seed(page, data, "workout");

  await page.getByRole("button", { name: "Add exercise", exact: true }).click();
  await page.getByLabel("Search exercises").fill("Hollow Hold");
  // Only the timed identity is offered; the rep-logged one stays for old logs.
  await expect(
    page.getByRole("button", { name: /^Add Hollow Hold/ }),
  ).toHaveCount(1);
  await page
    .getByRole("button", { name: "Add Hollow Hold", exact: true })
    .click();

  const hollow = card(page, "Hollow Hold");
  const timer = hollow.getByRole("group", {
    name: "Hold timer for Hollow Hold",
  });
  await expect(timer.getByRole("timer")).toHaveText("01:00");
  await expect(
    hollow.getByLabel("Hollow Hold set 1 durationSeconds"),
  ).toBeVisible();
  await expect(hollow.getByLabel("Hollow Hold set 1 reps")).toHaveCount(0);
  await expect(hollow.getByLabel("Hollow Hold set 1 weight")).toHaveCount(0);

  await timer
    .getByRole("button", { name: "Start 60-second hold for Hollow Hold set 1" })
    .click();
  await page.clock.fastForward(61_000);
  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[0])
    .toMatchObject({ weight: 0, durationSeconds: 60, done: true });
  expect((await stored(page)).active.exercises[1].exerciseId).toBe(
    `forma-${HOLLOW}`,
  );
  await expect(page.getByRole("status")).toContainText(
    "Hollow Hold set 1 logged: 60 seconds",
  );
});

test("older rep logs of a migrated hold keep their reps and get no timer", async ({
  page,
}) => {
  const data = snapshot();
  data.history = [
    {
      ...session([
        { exerciseId: LSIT, sets: [{ weight: 0, reps: 12, done: true }] },
      ]),
      id: "skills-done",
      date: "2026-10-20T00:00:00.000Z",
      duration: 600,
    },
  ];
  data.active = session([
    { exerciseId: LSIT, sets: [{ weight: 0, reps: 10, done: false }] },
  ]);
  await seed(page, data, "workout");

  const lsit = card(page, "L-sit");
  await expect(lsit.getByLabel("L-sit set 1 reps")).toHaveValue("10");
  await expect(lsit.getByLabel("L-sit set 1 durationSeconds")).toHaveCount(0);
  await expect(lsit.getByRole("group", { name: /^Hold timer/ })).toHaveCount(0);
  await lsit
    .getByRole("button", { name: "Instructions for L-sit", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toContainText(
    "Hold for as long as required",
  );
  await page.getByRole("button", { name: "Close dialog" }).first().click();

  await lsit
    .getByRole("button", { name: "Complete L-sit set 1", exact: true })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0])
    .toMatchObject({
      exerciseId: LSIT,
      sets: [{ weight: 0, reps: 10, done: true }],
    });

  await page.goto("/#history");
  await page.locator(".history-row").click();
  const logged = page.locator(".history-exercise");
  await expect(logged).toContainText("L-sit");
  await expect(logged).toContainText("12 reps");
});

test("a loaded hold keeps its weight column beside the seconds", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-21T00:00:00Z") });
  const data = snapshot();
  data.active = session([
    { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: false }] },
  ]);
  await seed(page, data, "workout");

  await page.getByRole("button", { name: "Add exercise", exact: true }).click();
  await page.getByLabel("Search exercises").fill("Crucifix");
  await page.getByRole("button", { name: "Add Crucifix", exact: true }).click();

  const crucifix = card(page, "Crucifix");
  await expect(
    crucifix.getByRole("group", { name: "Hold timer for Crucifix" }),
  ).toBeVisible();
  await expect(crucifix.getByLabel("Crucifix set 1 reps")).toHaveCount(0);
  await crucifix.getByLabel("Crucifix set 1 weight").fill("10");
  await crucifix.getByLabel("Crucifix set 1 durationSeconds").fill("40");
  await crucifix
    .getByRole("button", { name: "Complete Crucifix set 1", exact: true })
    .click();
  const crucifixEntry = async () => (await stored(page)).active.exercises[1];
  await expect
    .poll(async () => (await crucifixEntry()).sets[0])
    .toMatchObject({ weight: 10, durationSeconds: 40, done: true });
  expect((await crucifixEntry()).exerciseId).toBe(`forma-${CRUCIFIX}`);
});
