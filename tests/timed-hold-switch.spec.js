import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const HOLLOW = "wger-d059c63d-0a81-48a3-912a-44070c0def2e";
const LSIT = "wger-16202754-f567-4d23-a866-2c9cc8eba71d";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const programming = {
  repsMax: null,
  rpe: null,
  restSeconds: null,
  perSide: false,
  note: null,
  groupId: null,
};
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

test("a routine hold moves to seconds only when the member asks", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-21T00:00:00Z") });
  const data = snapshot();
  const hollow = {
    ...programming,
    exerciseId: HOLLOW,
    sets: 4,
    reps: 8,
    repsMax: 12,
    weight: 0,
    rpe: 8,
    restSeconds: 75,
    note: "Ribs down",
    groupId: "pair-1",
  };
  data.routines[0].exercises[1] = {
    ...data.routines[0].exercises[1],
    ...programming,
    groupId: "pair-1",
  };
  data.routines[0].exercises.splice(2, 0, hollow);
  data.routines[0].exercises.push({
    ...programming,
    exerciseId: "plank",
    sets: 3,
    reps: 3,
    weight: 0,
  });
  data.history = [
    {
      id: "old-skills",
      routineId: data.routines[0].id,
      name: "Skills",
      startedAt: Date.parse("2026-10-20T00:00:00Z"),
      date: "2026-10-20T00:10:00.000Z",
      duration: 600,
      notes: "",
      exercises: [
        { exerciseId: HOLLOW, sets: [{ weight: 0, reps: 10, done: true }] },
      ],
    },
  ];
  const order = data.routines[0].exercises.map((entry) => entry.exerciseId);
  await seed(page, data, "routines");
  await page
    .getByRole("button", { name: /^Upper body strength \d+ exercises/ })
    .click();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  const dialog = page.getByRole("dialog");

  // Still in reps, and offered the switch; the legacy plank is not.
  await expect(
    dialog.getByLabel("Hollow Hold reps", { exact: true }),
  ).toHaveValue("8–12");
  await expect(
    dialog.getByRole("button", { name: /^Use the timed version of/ }),
  ).toHaveCount(1);
  await dialog
    .getByRole("button", { name: "Use the timed version of Hollow Hold" })
    .click();

  const seconds = dialog.getByLabel("Hollow Hold durationSeconds", {
    exact: true,
  });
  await expect(seconds).toBeFocused();
  await expect(seconds).toHaveValue("60");
  await expect(
    dialog.getByLabel("Hollow Hold reps", { exact: true }),
  ).toHaveCount(0);
  await expect(
    dialog.getByRole("button", { name: /^Use the timed version of/ }),
  ).toHaveCount(0);
  // Nothing is stored until the member saves.
  expect((await stored(page)).routines[0].exercises[2].exerciseId).toBe(HOLLOW);
  await seconds.fill("45");
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();

  await expect
    .poll(async () => (await stored(page)).routines[0].exercises[2])
    .toEqual({
      ...hollow,
      exerciseId: `forma-${HOLLOW}`,
      entryId: HOLLOW,
      reps: 1,
      repsMax: null,
      durationSeconds: 45,
    });
  const saved = await stored(page);
  expect(saved.routines[0].exercises.map((entry) => entry.exerciseId)).toEqual(
    order.map((id) => (id === HOLLOW ? `forma-${HOLLOW}` : id)),
  );
  expect(saved.routines[0].exercises[1].groupId).toBe("pair-1");
  // Past workouts keep the rep ID and their reps.
  expect(saved.history[0].exercises[0]).toMatchObject({
    exerciseId: HOLLOW,
    sets: [{ weight: 0, reps: 10, done: true }],
  });

  await page
    .getByRole("button", { name: /^Upper body strength \d+ exercises/ })
    .click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  // Still the A2 half of the superset, now with the hold timer.
  await expect(
    page.getByRole("heading", { name: "A2 Hollow Hold", exact: true }),
  ).toBeVisible();
  await expect(
    page
      .getByRole("group", { name: "Hold timer for Hollow Hold" })
      .getByRole("timer"),
  ).toHaveText("00:45");
});

test("a workout card switches a rep-logged hold after confirming", async ({
  page,
}) => {
  const data = snapshot();
  data.active = {
    id: "skills-active",
    routineId: "upper",
    name: "Skills workout",
    startedAt: Date.parse("2026-10-21T00:00:00Z"),
    notes: "",
    restSeconds: 60,
    restEnd: null,
    restPaused: null,
    exercises: [
      { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: false }] },
      {
        exerciseId: LSIT,
        note: "Point toes",
        rpe: 8,
        restSeconds: 90,
        sets: [
          { weight: 0, reps: 10, done: true },
          { weight: 0, reps: 10, done: false },
        ],
      },
    ],
  };
  await seed(page, data, "workout");

  await page
    .getByRole("button", { name: "Options for L-sit", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Use the timed version", exact: true })
    .click();
  const confirm = page.getByRole("dialog", { name: "Log L-sit in seconds?" });
  await expect(confirm).toContainText(
    "the 1 completed set of L-sit in reps will not be saved",
  );
  await confirm.getByRole("button", { name: "Keep reps" }).click();
  expect((await stored(page)).active.exercises[1].exerciseId).toBe(LSIT);

  await page
    .getByRole("button", { name: "Options for L-sit", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Use the timed version", exact: true })
    .click();
  await page
    .getByRole("dialog", { name: "Log L-sit in seconds?" })
    .getByRole("button", { name: "Use the timed version" })
    .click();

  await expect
    .poll(async () => (await stored(page)).active.exercises[1])
    .toMatchObject({
      exerciseId: `forma-${LSIT}`,
      note: "Point toes",
      rpe: 8,
      restSeconds: 90,
      sets: [
        { durationSeconds: 60, done: false },
        { durationSeconds: 60, done: false },
      ],
    });
  await expect(page.getByRole("status")).toContainText(
    "L-sit now logs seconds with the hold timer.",
  );
  await expect(
    page.getByRole("group", { name: "Hold timer for L-sit" }),
  ).toBeVisible();
  // Bench presses never get the option.
  await page
    .getByRole("button", {
      name: "Options for Barbell bench press",
      exact: true,
    })
    .click();
  await expect(
    page.getByRole("menuitem", { name: "Use the timed version" }),
  ).toHaveCount(0);
});
