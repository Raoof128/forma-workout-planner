import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

test("overrange saved per-side targets stay editable and are blocked before a workout starts", async ({
  page,
}) => {
  const data = structuredClone(initialData);
  data.routines[0].exercises = [
    { exerciseId: "row", perSide: true, sets: 3, reps: 60, weight: 20 },
  ];
  await page.goto("/");
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto("/#routines");
  await page.reload();
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText(
    "Use 1–50 reps per side",
  );
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).active,
    ),
  ).toBeNull();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  const reps = page.getByLabel("One-arm dumbbell row reps", { exact: true });
  await expect(reps).toHaveValue("60");
  await reps.fill("40-60");
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Use 1–50 reps per side");
  expect(
    await page.evaluate(
      () =>
        JSON.parse(localStorage.getItem("forma-v1")).routines[0].exercises[0]
          .reps,
    ),
  ).toBe(60);
  await reps.fill("40-50");
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();
  await expect(
    page.getByLabel("One-arm dumbbell row set 1 left", { exact: true }),
  ).toHaveValue("40");
  expect(
    await page.evaluate(
      () =>
        JSON.parse(localStorage.getItem("forma-v1")).active.exercises[0]
          .sets[0],
    ),
  ).toMatchObject({ reps: 80, sides: { left: 40, right: 40 } });
});
