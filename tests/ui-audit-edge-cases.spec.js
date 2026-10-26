import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

async function seed(page, data, route) {
  data.revision = 0;
  await page.goto("/");
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`/#${route}`);
  await page.reload();
}

test("a replacement picker survives its target being removed in another tab", async ({
  page,
  context,
}) => {
  const data = structuredClone(initialData);
  data.active = {
    id: "cross-tab-picker",
    name: "Editing across tabs",
    startedAt: Date.now(),
    exercises: ["bench", "squat"].map((exerciseId) => ({
      exerciseId,
      sets: [{ weight: 50, reps: 8, done: false }],
    })),
  };
  await seed(page, data, "workout");
  await page
    .getByRole("button", {
      name: "Options for Barbell bench press",
      exact: true,
    })
    .click();
  await page
    .getByRole("menuitem", { name: "Replace exercise", exact: true })
    .click();
  await expect(
    page.getByRole("dialog", { name: "Replace Barbell bench press" }),
  ).toBeVisible();
  const other = await context.newPage();
  await other.goto("/");
  await other.evaluate(() => {
    const current = JSON.parse(localStorage.getItem("forma-v1"));
    current.revision += 1;
    current.active.exercises.shift();
    localStorage.setItem("forma-v1", JSON.stringify(current));
  });
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(
    page.getByRole("heading", { name: "Editing across tabs", exact: true }),
  ).toBeVisible();
  await expect(page.locator(".log-exercise")).toHaveCount(1);
  await expect(
    page.getByRole("heading", { name: "Barbell back squat", exact: true }),
  ).toBeVisible();
});

test("moving a routine with punctuation in its saved ID restores keyboard focus", async ({
  page,
}) => {
  const data = structuredClone(initialData);
  data.routines[0].id = 'imported"]routine\\id';
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await seed(page, data, "routines");
  const actions = page.getByLabel("Actions for Upper body strength", {
    exact: true,
  });
  await actions.click();
  await page
    .getByRole("button", { name: "Move later", exact: true })
    .first()
    .click();
  await expect(actions).toBeFocused();
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).routines[1].id,
    ),
  ).toBe(data.routines[0].id);
  expect(errors).toEqual([]);
});
