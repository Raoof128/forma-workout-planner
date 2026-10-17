import { expect } from "@playwright/test";
import { freshData } from "../src/storage.js";
import { exerciseById } from "../src/data.js";

export async function openDragEditor(page, count = 3) {
  const fixture = freshData();
  const original = fixture.routines[0];
  fixture.routines = [
    {
      ...original,
      name: "Drag program",
      exercises: Array.from({ length: count }, (_, index) => ({
        ...original.exercises[index % original.exercises.length],
        entryId: `drag-entry-${index}`,
        reps: 6,
        repsMax: 8,
        rpe: 8,
        restSeconds: 90,
        perSide: false,
        note: `Original cue ${index}`,
        groupId: index < 2 ? "drag-pair" : null,
      })),
    },
  ];
  await page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
  await page.goto("/#routines");
  await page.getByRole("button", { name: /^Drag program/ }).click();
  await page.getByRole("button", { name: "Edit routine", exact: true }).click();
  const dialog = page.getByRole("dialog");
  const rows = dialog.locator(".prescription:not(.labels)");
  await expect(rows).toHaveCount(count);
  await rows
    .first()
    .evaluate((node) => node.scrollIntoView({ block: "center" }));
  return {
    dialog,
    rows,
    original: fixture.routines[0].exercises,
    names: fixture.routines[0].exercises.map(
      (item) => exerciseById.get(item.exerciseId).name,
    ),
  };
}

export async function holdRowOverNext(page, editor, positions = 1) {
  const { dialog, rows, names } = editor;
  const row = rows.filter({
    has: page.getByLabel(`${names[0]} reps`, { exact: true }),
  });
  const neighbor = rows.filter({
    has: page.getByLabel(`${names[1]} reps`, { exact: true }),
  });
  const initial = await row.boundingBox();
  const next = await neighbor.boundingBox();
  const handle = await dialog
    .getByRole("button", { name: `Drag ${names[0]}`, exact: true })
    .boundingBox();
  const x = handle.x + handle.width / 2;
  const y = handle.y + handle.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + 8, { steps: 2 });
  let distance = 0;
  for (let index = 1; index <= positions; index++)
    distance += (await rows.nth(index).boundingBox()).height;
  await page.mouse.move(x, y + distance, {
    steps: 16,
  });
  await expect
    .poll(async () =>
      Math.abs((await row.boundingBox()).y - initial.y - distance),
    )
    .toBeLessThan(12);
  await expect
    .poll(() =>
      row.evaluate((node) => [...node.parentNode.children].indexOf(node)),
    )
    .toBe(positions);
  return { row, neighbor, initial, next, destination: initial.y + distance };
}

export async function saveAndReadDrag(page, dialog) {
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await expect(dialog).toHaveCount(0);
  await page.reload();
  return page.evaluate(
    () => JSON.parse(localStorage.getItem("forma-v1")).routines[0].exercises,
  );
}
