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

  const menu = (name) =>
    page.getByRole("button", { name: `Options for ${name}`, exact: true });
  const choose = async (name, item) => {
    await menu(name).click();
    await page.getByRole("menuitem", { name: item, exact: true }).click();
  };
  const order = async () =>
    (await stored(page)).active.exercises.map((item) => item.exerciseId);

  // The ⋯ menu follows the menu button pattern and opens on the first
  // available action; on the first card that is "Move down".
  await expect(menu("Barbell bench press")).toHaveAttribute(
    "aria-haspopup",
    "menu",
  );
  await menu("Barbell bench press").click();
  await expect(menu("Barbell bench press")).toHaveAttribute(
    "aria-expanded",
    "true",
  );
  await expect(page.getByRole("menuitem", { name: "Move up" })).toHaveAttribute(
    "aria-disabled",
    "true",
  );
  await expect(page.getByRole("menuitem", { name: "Move down" })).toBeFocused();
  await page.keyboard.press("End");
  await expect(
    page.getByRole("menuitem", { name: "Remove exercise" }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("menu")).toHaveCount(0);
  await expect(menu("Barbell bench press")).toBeFocused();

  // Add an exercise below the last card; a reviewed unilateral move logs sides.
  await page.getByRole("button", { name: "Add exercise", exact: true }).click();
  const picker = page.getByRole("dialog", { name: "Add an exercise" });
  await picker.getByLabel("Search exercises").fill("alternate hammer curl");
  await picker
    .getByRole("button", { name: "Add Alternate Hammer Curl", exact: true })
    .click();
  await expect(
    status(page, "Alternate Hammer Curl added to this workout."),
  ).toBeVisible();
  await expect(menu("Alternate Hammer Curl")).toBeFocused();
  const added = (await stored(page)).active.exercises[2];
  expect(added.perSide).toBe(true);
  expect(added.sets).toHaveLength(3);
  expect(added.sets[0]).toMatchObject({
    sides: { left: 10, right: 10 },
    reps: 20,
  });

  // Keyboard: open with Enter, move up, and focus stays with the card.
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem", { name: "Move up" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect
    .poll(order)
    .toEqual(["bench", "db-alternate-hammer-curl", "lunge"]);
  await expect(
    status(page, "Moved Alternate Hammer Curl to position 2 of 3."),
  ).toBeVisible();
  await expect(menu("Alternate Hammer Curl")).toBeFocused();

  // Replace keeps every set when both exercises log the same fields.
  await choose("Barbell bench press", "Replace exercise");
  const replacing = page.getByRole("dialog", {
    name: "Replace Barbell bench press",
  });
  await replacing.getByLabel("Search exercises").fill("incline dumbbell press");
  await replacing
    .getByRole("button", {
      name: "Replace with Incline Dumbbell Press",
      exact: true,
    })
    .click();
  await expect
    .poll(order)
    .toEqual([
      "db-incline-dumbbell-press",
      "db-alternate-hammer-curl",
      "lunge",
    ]);
  expect((await stored(page)).active.exercises[0].sets).toHaveLength(2);

  // Removing an exercise with a completed set asks first, and Keep is safe.
  await choose("Dumbbell reverse lunge", "Remove exercise");
  const confirm = page.getByRole("dialog", {
    name: "Remove Dumbbell reverse lunge?",
  });
  await expect(confirm).toContainText("Its 1 completed set will not be saved");
  await expect(
    confirm.getByRole("button", { name: "Keep Dumbbell reverse lunge" }),
  ).toBeFocused();
  await confirm
    .getByRole("button", { name: "Keep Dumbbell reverse lunge" })
    .click();
  expect(await order()).toHaveLength(3);
  await choose("Dumbbell reverse lunge", "Remove exercise");
  await page
    .getByRole("dialog", { name: "Remove Dumbbell reverse lunge?" })
    .getByRole("button", { name: "Remove exercise", exact: true })
    .click();
  await expect
    .poll(order)
    .toEqual(["db-incline-dumbbell-press", "db-alternate-hammer-curl"]);
  // An exercise with no completed sets is removed straight away.
  await choose("Incline Dumbbell Press", "Remove exercise");
  await expect(
    status(page, "Incline Dumbbell Press removed from this workout."),
  ).toBeVisible();
  await expect.poll(order).toEqual(["db-alternate-hammer-curl"]);
  // The last exercise cannot be removed.
  await menu("Alternate Hammer Curl").click();
  await expect(
    page.getByRole("menuitem", { name: "Remove exercise" }),
  ).toHaveAttribute("aria-disabled", "true");
  await page.keyboard.press("Escape");
  await expect(page.locator(".log-exercise .set-labels")).toContainText("LEFT");
  await page.reload();
  await expect(page.locator(".log-exercise")).toHaveCount(1);
  await expect(
    page.getByRole("heading", { name: "Alternate Hammer Curl" }),
  ).toBeVisible();
});

test("replacing with an exercise that logs different fields asks before dropping completed sets", async ({
  page,
}) => {
  const data = snapshot();
  data.active = activeSession();
  data.active.exercises[0].sets[0].done = true;
  await seed(page, data);
  await page
    .getByRole("button", {
      name: "Options for Barbell bench press",
      exact: true,
    })
    .click();
  await page.getByRole("menuitem", { name: "Replace exercise" }).click();
  const picker = page.getByRole("dialog", {
    name: "Replace Barbell bench press",
  });
  await picker.getByLabel("Search exercises").fill("high plank");
  await picker
    .getByRole("button", { name: "Replace with High plank", exact: true })
    .click();
  const confirm = page.getByRole("dialog", {
    name: "Replace Barbell bench press with High plank?",
  });
  await expect(confirm).toContainText("records different measurements");
  await confirm.getByRole("button", { name: "Replace exercise" }).click();
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].exerciseId)
    .toBe("wger-b2b40a54-e42b-49ec-97da-4c929ae41d42");
  const sets = (await stored(page)).active.exercises[0].sets;
  expect(sets).toHaveLength(3);
  expect(sets.every((set) => !set.done && set.durationSeconds === 60)).toBe(
    true,
  );
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
