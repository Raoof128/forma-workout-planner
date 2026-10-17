import { test, expect } from "@playwright/test";
import {
  openRoutineCards,
  dragCard,
  savedRoutineIds,
} from "./routine-card-drag.helpers.js";

const pageErrors = new WeakMap();
test.beforeEach(({ page }) => {
  const errors = [];
  pageErrors.set(page, errors);
  page.on("pageerror", (error) => errors.push(error.message));
});
test.afterEach(({ page }) => {
  expect(pageErrors.get(page)).toEqual([]);
});

function cardLift(card) {
  return card.evaluate((node) => {
    const style = getComputedStyle(node.querySelector(".routine-card"));
    return { scale: style.scale, shadow: style.boxShadow };
  });
}

test("dragging a routine card lifts it, reorders the grid and saves the order", async ({
  page,
}) => {
  const grid = await openRoutineCards(page);
  const [first, second] = grid.ids;
  const card = grid.card(first);
  const drop = await dragCard(page, card, grid.card(second));
  await expect(card).toHaveClass(/is-lifted/);
  await expect
    .poll(async () => Number((await cardLift(card)).scale))
    .toBe(1.03);
  expect((await cardLift(card)).shadow).toContain("rgb(174, 196, 119)");
  await drop();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(card).toHaveClass(/is-landed/);
  await expect(card).not.toHaveClass(/is-landed/, { timeout: 3000 });
  await expect(grid.cards.nth(1)).toHaveAttribute("data-routine-id", first);
  await expect
    .poll(() => savedRoutineIds(page))
    .toEqual([second, first, grid.archived, ...grid.ids.slice(2)]);
  await page.reload();
  await expect(grid.cards.nth(1)).toHaveAttribute("data-routine-id", first);
});

test("escape cancels a card drag and keeps the saved order", async ({
  page,
}) => {
  const grid = await openRoutineCards(page);
  const card = grid.card(grid.ids[0]);
  const drop = await dragCard(page, card, grid.card(grid.ids[2]));
  await expect(grid.cards.nth(0)).not.toHaveAttribute(
    "data-routine-id",
    grid.ids[0],
  );
  await page.keyboard.press("Escape");
  await drop();
  await expect(grid.cards.nth(0)).toHaveAttribute(
    "data-routine-id",
    grid.ids[0],
  );
  await expect(card).not.toHaveClass(/is-lifted/);
  await expect(page.locator(".routine-card-wrap.is-landed")).toHaveCount(0);
  expect(await savedRoutineIds(page)).toEqual(grid.saved);
});

test("a plain click still opens the routine", async ({ page }) => {
  const grid = await openRoutineCards(page);
  await grid.card(grid.ids[1]).locator(".routine-card").click();
  await expect(page.getByRole("dialog")).toBeVisible();
});

test("card menu moves routines without dragging and announces the result", async ({
  page,
}) => {
  const grid = await openRoutineCards(page);
  const name = grid.names[0];
  await page.getByLabel(`Actions for ${name}`, { exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Move earlier", exact: true }),
  ).toBeDisabled();
  await page.getByRole("button", { name: "Move later", exact: true }).click();
  await expect(grid.cards.nth(1)).toHaveAttribute(
    "data-routine-id",
    grid.ids[0],
  );
  await expect(
    page.locator('[aria-live="polite"]').filter({ hasText: name }),
  ).toHaveText(`Moved ${name} to position 2 of ${grid.ids.length}.`);
  await expect(
    page.getByLabel(`Actions for ${name}`, { exact: true }),
  ).toBeFocused();
  await expect
    .poll(() => savedRoutineIds(page))
    .toEqual([grid.ids[1], grid.ids[0], grid.archived, ...grid.ids.slice(2)]);
});

test("reduced motion keeps the lifted outline without scaling", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  const grid = await openRoutineCards(page);
  const card = grid.card(grid.ids[0]);
  const drop = await dragCard(page, card, grid.card(grid.ids[1]));
  await expect(card).toHaveClass(/is-lifted/);
  const lift = await cardLift(card);
  expect(lift.scale).toBe("none");
  expect(lift.shadow).toContain("rgb(174, 196, 119)");
  await drop();
  await expect(grid.cards.nth(1)).toHaveAttribute(
    "data-routine-id",
    grid.ids[0],
  );
});
