import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
const set = (weight, reps, extra = {}) => ({
  weight,
  reps,
  done: false,
  ...extra,
});
const sideSet = (weight, left, right, extra = {}) =>
  set(weight, left + right, { sides: { left, right }, ...extra });
const activeSession = () => ({
  id: "editing-active",
  routineId: "lower",
  name: "Editing workout",
  startedAt: Date.now() - 30_000,
  notes: "",
  restSeconds: 90,
  restEnd: null,
  restPaused: null,
  exercises: [
    {
      exerciseId: "bench",
      perSide: false,
      sets: [set(40, 8), set(40, 8), set(40, 8)],
    },
    {
      exerciseId: "lunge",
      perSide: true,
      targetReps: 10,
      sets: [sideSet(10, 10, 10), sideSet(10, 10, 10)],
    },
  ],
});
async function seed(page, data, hash = "workout") {
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
const field = (page, name) => page.getByLabel(name, { exact: true });
const status = (page, text) =>
  page.getByRole("status").filter({ hasText: text });

test("typed weight and reps fill the remaining unfinished sets unless turned off", async ({
  page,
}) => {
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data);
  const weights = (index) =>
    field(page, `Barbell bench press set ${index} weight`);
  await weights(1).fill("50");
  await expect(weights(3)).toHaveValue("50");
  await field(page, "Barbell bench press set 1 reps").fill("12");
  await expect(field(page, "Barbell bench press set 3 reps")).toHaveValue("12");
  await weights(3).fill("55");
  await weights(2).fill("52");
  await expect(weights(3)).toHaveValue("55");
  await expect
    .poll(async () =>
      (await stored(page)).active.exercises[0].sets.map((item) => item.weight),
    )
    .toEqual([50, 52, 55]);
  // A completed set is never rewritten by a later edit above it.
  await page
    .getByRole("button", {
      name: "Complete Barbell bench press set 2",
      exact: true,
    })
    .click();
  await weights(1).fill("60");
  await expect(weights(2)).toHaveValue("52");
  await expect(weights(3)).toHaveValue("55");

  const toggle = page.getByLabel("Fill the remaining sets with what I type");
  await expect(toggle).toBeChecked();
  await toggle.uncheck();
  await expect(
    status(page, "Each set now keeps its own values."),
  ).toBeVisible();
  await expect
    .poll(async () => (await stored(page)).profile.fillSets)
    .toBe(false);
  await weights(3).fill("60");
  await weights(1).fill("45");
  await expect(weights(3)).toHaveValue("60");
  await page.reload();
  await expect(
    page.getByLabel("Fill the remaining sets with what I type"),
  ).not.toBeChecked();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await expect(
    page.getByLabel("Fill the remaining sets with the weight and reps I type"),
  ).not.toBeChecked();
});

test("unilateral exercises log left and right, complete as a total and read back in history", async ({
  page,
}) => {
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data);
  const lunge = page
    .locator(".log-exercise")
    .filter({ hasText: "Dumbbell reverse lunge" });
  await expect(lunge.locator(".set-labels")).toContainText("LEFT");
  await expect(lunge.locator(".set-labels")).toContainText("RIGHT");
  await expect(lunge).toContainText("Target: 10 / leg");
  await expect(
    page
      .locator(".log-exercise")
      .filter({ hasText: "Barbell bench press" })
      .locator(".set-labels"),
  ).not.toContainText("LEFT");

  await field(page, "Dumbbell reverse lunge set 1 left").fill("12");
  await expect(field(page, "Dumbbell reverse lunge set 2 left")).toHaveValue(
    "12",
  );
  const complete = (index) =>
    page.getByRole("button", {
      name: `Complete Dumbbell reverse lunge set ${index}`,
      exact: true,
    });
  await field(page, "Dumbbell reverse lunge set 1 right").fill("60");
  await complete(1).click();
  await expect(status(page, "left and the right side")).toBeVisible();
  await field(page, "Dumbbell reverse lunge set 1 right").fill("9");
  await complete(1).click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[0])
    .toMatchObject({ done: true, reps: 21, sides: { left: 12, right: 9 } });
  await expect(page.locator(".session-stats")).toContainText("210");

  await field(page, "Dumbbell reverse lunge set 2 right").fill("");
  await complete(2).click();
  await expect(status(page, "left and the right side")).toBeVisible();
  await expect
    .poll(async () => (await stored(page)).active.exercises[1].sets[1].done)
    .toBe(false);
  await page.reload();
  await expect(field(page, "Dumbbell reverse lunge set 2 left")).toHaveValue(
    "12",
  );
  await expect(field(page, "Dumbbell reverse lunge set 2 right")).toHaveValue(
    "",
  );

  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page.getByRole("button", { name: "Save workout", exact: true }).click();
  await page.locator(".history-row").first().click();
  await expect(page.getByRole("dialog")).toContainText("10 kg × 12 L / 9 R");
  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  await expect(
    page.getByLabel("Correct Dumbbell reverse lunge set 1 right", {
      exact: true,
    }),
  ).toHaveValue("9");
  await page
    .getByLabel("Correct Dumbbell reverse lunge set 1 right", { exact: true })
    .fill("11");
  await page
    .getByRole("button", { name: "Save corrections", exact: true })
    .click();
  await expect
    .poll(async () => (await stored(page)).history[0].exercises[1].sets[0])
    .toMatchObject({ reps: 23, sides: { left: 12, right: 11 } });
});

test("a running workout can gain, reorder and lose exercises and drop an unfinished set", async ({
  page,
}) => {
  const data = snapshot();
  data.active = activeSession();
  await seed(page, data);
  await page
    .getByRole("button", {
      name: "Remove Barbell bench press set 3",
      exact: true,
    })
    .click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets.length)
    .toBe(2);
  await page
    .getByRole("button", {
      name: "Complete Dumbbell reverse lunge set 2",
      exact: true,
    })
    .click();
  await expect(
    page.getByRole("button", {
      name: "Remove Dumbbell reverse lunge set 2",
      exact: true,
    }),
  ).toHaveCount(0);

  await page.getByRole("button", { name: "Edit workout", exact: true }).click();
  const dialog = page.getByRole("dialog");
  await dialog
    .getByRole("textbox", { name: "Search exercises to add" })
    .fill("alternate hammer curl");
  await dialog
    .getByRole("button")
    .filter({ hasText: "Alternate Hammer Curl" })
    .filter({ has: page.locator("small") })
    .first()
    .click();
  await expect(
    status(page, "Alternate Hammer Curl added to this workout."),
  ).toBeVisible();
  await expect(dialog.locator(".exercise-row")).toHaveCount(3);
  await dialog
    .getByRole("button", { name: "Move Alternate Hammer Curl up", exact: true })
    .click();
  await expect
    .poll(async () =>
      (await stored(page)).active.exercises.map((item) => item.exerciseId),
    )
    .toEqual(["bench", "db-alternate-hammer-curl", "lunge"]);
  // A reviewed unilateral exercise starts logging each side at once.
  const added = (await stored(page)).active.exercises[1];
  expect(added.perSide).toBe(true);
  expect(added.sets).toHaveLength(3);
  expect(added.sets[0]).toMatchObject({
    sides: { left: 10, right: 10 },
    reps: 20,
  });

  await dialog
    .getByRole("button", { name: "Remove Barbell bench press", exact: true })
    .click();
  await expect(
    status(page, "Barbell bench press removed from this workout."),
  ).toBeVisible();
  const removeLunge = dialog.getByRole("button", {
    name: /^Remove Dumbbell reverse lunge/,
  });
  await removeLunge.click();
  await expect(removeLunge).toHaveAccessibleName(
    "Remove Dumbbell reverse lunge and its 1 completed set",
  );
  expect((await stored(page)).active.exercises).toHaveLength(2);
  await removeLunge.click();
  await expect
    .poll(async () =>
      (await stored(page)).active.exercises.map((item) => item.exerciseId),
    )
    .toEqual(["db-alternate-hammer-curl"]);
  await expect(
    dialog.getByRole("button", {
      name: "Remove Alternate Hammer Curl",
      exact: true,
    }),
  ).toBeDisabled();
  await dialog
    .getByRole("button", { name: "Done editing", exact: true })
    .click();
  await expect(page.locator(".log-exercise")).toHaveCount(1);
  await expect(page.locator(".log-exercise .set-labels")).toContainText("LEFT");
  await page.reload();
  await expect(page.locator(".log-exercise")).toHaveCount(1);
  await expect(
    page.getByRole("heading", { name: "Alternate Hammer Curl" }),
  ).toBeVisible();
});

test("starting a routine with a per-side exercise plans both sides", async ({
  page,
}) => {
  await seed(page, snapshot(), "routines");
  await page
    .locator(".routine-card")
    .filter({ hasText: "Lower body foundation" })
    .click();
  await expect(page.getByRole("dialog")).toContainText("3 × 10 / leg");
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { level: 1, name: "Lower body foundation" }),
  ).toBeVisible();
  await expect(field(page, "Dumbbell reverse lunge set 1 left")).toHaveValue(
    "10",
  );
  await expect(field(page, "Barbell back squat set 1 reps")).toHaveValue("10");
  expect(
    (await stored(page)).active.exercises.find(
      (item) => item.exerciseId === "lunge",
    ).sets[0],
  ).toMatchObject({ reps: 20, sides: { left: 10, right: 10 } });
});
