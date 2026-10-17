import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";
import {
  openDragEditor,
  holdRowOverNext,
  saveAndReadDrag,
} from "./routine-drag.helpers.js";

test("the full exercise library selects exercises and returns to the named routine draft", async ({
  page,
}) => {
  const fixture = freshData();
  fixture.routines = [];
  await page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
  await page.goto("/#routines");
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Routine name").fill("Library draft");
  await dialog.getByLabel("Estimated duration (minutes)").fill("47");
  await dialog
    .getByRole("button", { name: "Browse exercise library", exact: true })
    .click();
  await expect(
    dialog.getByRole("heading", { name: "Exercise library", exact: true }),
  ).toBeVisible();
  await dialog.getByLabel("Search exercise library").fill("bench press");
  await dialog.getByLabel("Filter by equipment").selectOption("Barbell");
  await dialog.getByRole("button", { name: "Chest", exact: true }).click();
  await dialog
    .getByRole("button", {
      name: "Add Barbell bench press to routine",
      exact: true,
    })
    .click();
  await expect(
    dialog.getByRole("button", {
      name: "Remove Barbell bench press from routine",
      exact: true,
    }),
  ).toHaveAttribute("aria-pressed", "true");
  await dialog
    .getByLabel("Search exercise library")
    .fill("one-arm dumbbell row");
  await dialog.getByLabel("Filter by equipment").selectOption("Dumbbell");
  await dialog.getByRole("button", { name: "Back", exact: true }).click();
  await dialog
    .getByRole("button", {
      name: "Add One-arm dumbbell row to routine",
      exact: true,
    })
    .click();
  await dialog
    .getByRole("button", { name: "Back to routine", exact: true })
    .first()
    .click();
  await expect(dialog.getByLabel("Routine name")).toHaveValue("Library draft");
  await expect(dialog.getByLabel("Estimated duration (minutes)")).toHaveValue(
    "47",
  );
  await expect(dialog.locator(".prescription:not(.labels)")).toHaveCount(2);
  await dialog
    .getByLabel("Barbell bench press reps", { exact: true })
    .fill("8-12");
  const saved = await saveAndReadDrag(page, dialog);
  expect(saved.map((e) => e.exerciseId)).toEqual(["bench", "row"]);
  expect(saved[0]).toMatchObject({ reps: 8, repsMax: 12 });
  const stored = await page.evaluate(
    () => JSON.parse(localStorage.getItem("forma-v1")).routines[0],
  );
  expect(stored).toMatchObject({ name: "Library draft", minutes: 47 });
});

test("returning from the library preserves unsaved inputs, notes, supersets and focus", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  const { dialog, names } = editor;
  await dialog.getByLabel(`${names[0]} reps`, { exact: true }).fill("7-9");
  await dialog.getByLabel(`Options for ${names[0]}`).click();
  await dialog
    .getByLabel(`${names[0]} note`, { exact: true })
    .fill("Keep this unsaved cue");
  const opener = dialog.getByRole("button", {
    name: "Browse exercise library",
    exact: true,
  });
  await opener.click();
  await expect(
    dialog.getByRole("button", {
      name: `Remove ${names[0]} from routine`,
      exact: true,
    }),
  ).toHaveAttribute("aria-pressed", "true");
  await dialog.getByLabel("Search exercise library").fill("squat");
  await dialog.getByRole("button", { name: "Legs", exact: true }).click();
  await page.keyboard.press("Escape");
  await expect(
    dialog.getByRole("heading", { name: "Edit your routine", exact: true }),
  ).toBeVisible();
  await expect(opener).toBeFocused();
  await expect(
    dialog.getByLabel(`${names[0]} reps`, { exact: true }),
  ).toHaveValue("7-9");
  await expect(
    dialog.getByLabel(`${names[0]} note`, { exact: true }),
  ).toHaveValue("Keep this unsaved cue");
  await editor.rows
    .first()
    .evaluate((node) => node.scrollIntoView({ block: "center" }));
  await holdRowOverNext(page, editor);
  await page.mouse.up();
  await expect(editor.rows.nth(1)).toContainText(names[0]);
  expect(await saveAndReadDrag(page, dialog)).toEqual([
    editor.original[1],
    {
      ...editor.original[0],
      reps: 7,
      repsMax: 9,
      note: "Keep this unsaved cue",
    },
    ...editor.original.slice(2),
  ]);
});
