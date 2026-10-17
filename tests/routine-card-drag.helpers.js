import { expect } from "@playwright/test";
import { freshData } from "../src/storage.js";

export async function openRoutineCards(page) {
  const fixture = freshData();
  const [first, second, ...rest] = fixture.routines;
  // An archived routine sits between visible ones so reordering must keep it.
  const archived = {
    ...structuredClone(first),
    id: "card-archived",
    name: "Archived block",
    archivedAt: Date.now(),
  };
  fixture.routines = [first, second, archived, ...rest];
  await page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
  await page.goto("/#routines");
  const cards = page.locator(".routine-grid.full-grid .routine-card-wrap");
  const ids = [first, second, ...rest].map((routine) => routine.id);
  await expect(cards).toHaveCount(ids.length);
  return {
    cards,
    ids,
    archived: archived.id,
    saved: fixture.routines.map((routine) => routine.id),
    names: [first, second, ...rest].map((routine) => routine.name),
    card: (id) => page.locator(`.routine-card-wrap[data-routine-id="${id}"]`),
  };
}

export async function dragCard(page, card, target) {
  const from = await card.boundingBox();
  const to = await target.boundingBox();
  const start = { x: from.x + from.width / 2, y: from.y + 60 };
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await page.mouse.move(start.x + 10, start.y + 4, { steps: 3 });
  const end = { x: to.x + to.width / 2, y: to.y + 60 };
  await page.mouse.move(end.x, end.y, { steps: 18 });
  return async () => {
    await page.mouse.up();
  };
}

export function savedRoutineIds(page) {
  return page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")).routines.map(
      (routine) => routine.id,
    ),
  );
}
