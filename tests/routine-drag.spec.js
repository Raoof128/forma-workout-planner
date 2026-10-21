import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";
import {
  openDragEditor,
  holdRowOverNext,
  saveAndReadDrag,
} from "./routine-drag.helpers.js";

const pageErrors = new WeakMap();
test.beforeEach(({ page }) => {
  const errors = [];
  pageErrors.set(page, errors);
  page.on("pageerror", (error) => errors.push(error.message));
});
test.afterEach(({ page }) => {
  expect(pageErrors.get(page)).toEqual([]);
});

test("saving waits for the lazy prescription fields to finish loading", async ({
  page,
}) => {
  const fixture = freshData();
  await page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  await page.route(
    /RoutinePrescriptions(?:\.jsx|-[^/]+\.js)(?:\?.*)?$/,
    async (route) => {
      await gate;
      await route.continue();
    },
  );
  let dialog;
  try {
    await page.goto("/#routines");
    await page.locator(".routine-card").first().click();
    await page
      .getByRole("button", { name: "Edit routine", exact: true })
      .click();
    dialog = page.getByRole("dialog");
    await dialog.getByLabel("Routine name").fill("Ready to save");
    await expect(
      dialog.getByRole("status").filter({ hasText: "Loading exercise order" }),
    ).toBeVisible();
    await expect(
      dialog.getByRole("button", { name: "Save routine", exact: true }),
    ).toBeDisabled();
  } finally {
    release();
  }
  await expect(dialog.locator(".prescription:not(.labels)")).toHaveCount(
    fixture.routines[0].exercises.length,
  );
  await expect(
    dialog.getByRole("button", { name: "Save routine", exact: true }),
  ).toBeEnabled();
  await dialog
    .getByRole("button", { name: "Save routine", exact: true })
    .click();
  await expect(dialog).toHaveCount(0);
  await page.reload();
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).routines[0],
    ),
  ).toMatchObject({
    name: "Ready to save",
    exercises: fixture.routines[0].exercises,
  });
});

test("immediate drag releases retain a usable editor and every saved field", async ({
  page,
  isMobile,
}) => {
  // Keep this rapid sequence visible at phone width; edge tests use normal height.
  if (isMobile)
    await page.setViewportSize({ ...page.viewportSize(), height: 1800 });
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.addInitScript(() => {
    window.__routineDragPresses = [];
    window.addEventListener(
      "pointerdown",
      (event) => {
        const handle = event.target.closest(".row-drag-handle");
        if (handle)
          window.__routineDragPresses.push(handle.getAttribute("aria-label"));
      },
      true,
    );
  });
  const editor = await openDragEditor(page);
  const handle = editor.dialog.getByRole("button", {
    name: `Drag ${editor.names[0]}`,
    exact: true,
  });
  const target = editor.rows.filter({
    has: page.getByLabel(`${editor.names[1]} reps`, { exact: true }),
  });
  // dragTo can retry an intercepted press without releasing the mouse.
  // Hover resolves spring hit-testing before each single trusted press.
  for (let attempt = 0; attempt < 3; attempt++) {
    await editor.dialog.evaluate((scroller) => {
      const list = scroller.querySelector(".prescription-order");
      const header = scroller.querySelector(".modal-header");
      scroller.scrollTop +=
        list.getBoundingClientRect().top -
        header.getBoundingClientRect().bottom -
        16;
    });
    // Motion reports drag start and end on later frames. Aim only once the
    // previous drop has landed and every row is at rest: under load a late
    // commit or a stalled spring moves another handle or the target.
    await expect
      .poll(() =>
        editor.rows.evaluateAll(
          (nodes, key) =>
            nodes.every(
              (node) =>
                !node.classList.contains("is-dragging") &&
                new DOMMatrixReadOnly(getComputedStyle(node).transform)
                  .isIdentity,
            )
              ? nodes.findIndex((node) => node.dataset.entryKey === key)
              : -1,
          editor.original[0].entryId,
        ),
      )
      .toBe(attempt % 2);
    await handle.hover();
    await page.mouse.down();
    const destination = await target.boundingBox();
    const releaseY = destination.y + destination.height / 2;
    const bounds = await editor.dialog.boundingBox();
    expect(releaseY).toBeLessThan(
      Math.min(bounds.y + bounds.height, page.viewportSize().height),
    );
    await page.mouse.move(destination.x + destination.width / 2, releaseY);
    await page.mouse.up();
  }
  expect(await page.evaluate(() => window.__routineDragPresses)).toEqual(
    Array(3).fill(`Drag ${editor.names[0]}`),
  );
  await expect(editor.rows).toHaveCount(3);
  await expect(
    editor.dialog.getByRole("button", { name: "Save routine", exact: true }),
  ).toBeEnabled();
  expect(errors).toEqual([]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual([
    editor.original[1],
    editor.original[0],
    editor.original[2],
  ]);
  expect(errors).toEqual([]);
});

test("the entire exercise row follows the pointer while neighbors make room and values survive save", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  const { row, neighbor, initial, next, destination } = await holdRowOverNext(
    page,
    editor,
  );
  await expect
    .poll(async () => (await row.boundingBox()).y)
    .toBeGreaterThan(initial.y + 25);
  await expect
    .poll(async () => Math.abs((await row.boundingBox()).y - destination))
    .toBeLessThan(12);
  await expect
    .poll(async () => (await neighbor.boundingBox()).y)
    .toBeLessThan(next.y - 20);
  await expect(
    row.getByLabel(`${editor.names[0]} reps`, { exact: true }),
  ).toHaveValue("6–8");
  await page.mouse.up();
  await expect(editor.rows.nth(1)).toContainText(editor.names[0]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual([
    editor.original[1],
    editor.original[0],
    editor.original[2],
  ]);
});

test("a fast move across multiple rows catches up while held and saves the displayed slot", async ({
  page,
  isMobile,
}) => {
  // Fit the full two-row jump inside the viewport. Normal phone-height edge
  // scrolling is covered separately; an offscreen release must cancel.
  if (isMobile)
    await page.setViewportSize({ ...page.viewportSize(), height: 1100 });
  const editor = await openDragEditor(page);
  const { pointer } = await holdRowOverNext(page, editor, 2);
  const bounds = await editor.dialog.boundingBox();
  expect(pointer.y).toBeLessThan(
    Math.min(bounds.y + bounds.height, page.viewportSize().height),
  );
  await page.mouse.up();
  await expect(editor.rows.last()).toContainText(editor.names[0]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual([
    { ...editor.original[1], groupId: null },
    editor.original[2],
    { ...editor.original[0], groupId: null },
  ]);
});

test("Escape cancels a dragged preview without closing the editor or losing a superset", async ({
  page,
  isMobile,
}) => {
  // Keep the two-slot preview inside the phone viewport before cancelling it.
  if (isMobile)
    await page.setViewportSize({ ...page.viewportSize(), height: 1100 });
  const editor = await openDragEditor(page);
  const { row, initial, pointer } = await holdRowOverNext(page, editor, 2);
  const bounds = await editor.dialog.boundingBox();
  expect(pointer.y).toBeLessThan(
    Math.min(bounds.y + bounds.height, page.viewportSize().height),
  );
  await expect
    .poll(async () => (await row.boundingBox()).y)
    .toBeGreaterThan(initial.y + 25);
  await page.keyboard.press("Escape");
  await page.mouse.up();
  await expect(editor.dialog).toBeVisible();
  await expect(editor.rows.first()).toContainText(editor.names[0]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
});

test("reduced motion retains direct dragging and editable fields plus arrow reordering", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  const editor = await openDragEditor(page);
  const input = editor.dialog.getByLabel(`${editor.names[0]} reps`, {
    exact: true,
  });
  await input.fill("7-9");
  const { row, initial } = await holdRowOverNext(page, editor);
  await expect
    .poll(async () => (await row.boundingBox()).y)
    .toBeGreaterThan(initial.y + 25);
  await page.mouse.up();
  await expect(editor.rows.nth(1)).toContainText(editor.names[0]);
  await expect(
    editor.dialog.getByRole("button", { name: "Save routine", exact: true }),
  ).toBeEnabled();
  expect(
    await row.evaluate(
      (node) =>
        new DOMMatrixReadOnly(getComputedStyle(node).transform).isIdentity,
    ),
  ).toBe(true);
  await editor.dialog
    .getByRole("button", { name: `Move ${editor.names[0]} up`, exact: true })
    .click();
  await expect(editor.rows.first()).toContainText(editor.names[0]);
  await expect(input).toHaveValue("7-9");
  const saved = await saveAndReadDrag(page, editor.dialog);
  expect(saved[0]).toEqual({ ...editor.original[0], reps: 7, repsMax: 9 });
  expect(saved.slice(1)).toEqual(editor.original.slice(1));
});

test("expanded notes move with their row and remain editable after dropping", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  await editor.dialog.getByLabel(`Options for ${editor.names[0]}`).click();
  const note = editor.dialog.getByLabel(`${editor.names[0]} note`, {
    exact: true,
  });
  await note.fill("Keep the entire cue with this exercise");
  await editor.rows
    .first()
    .evaluate((node) => node.scrollIntoView({ block: "center" }));
  const { row, destination } = await holdRowOverNext(page, editor);
  await expect
    .poll(async () => Math.abs((await row.boundingBox()).y - destination))
    .toBeLessThan(12);
  await expect(
    row.getByLabel(`${editor.names[0]} note`, { exact: true }),
  ).toHaveValue("Keep the entire cue with this exercise");
  await page.mouse.up();
  await expect(editor.rows.nth(1)).toContainText(editor.names[0]);
  await note.fill("Final edited cue");
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual([
    editor.original[1],
    { ...editor.original[0], note: "Final edited cue" },
    editor.original[2],
  ]);
});

test("dropping outside the list cancels the move and retains the original prescriptions", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  const { row, initial } = await holdRowOverNext(page, editor);
  await expect
    .poll(async () => (await row.boundingBox()).y)
    .toBeGreaterThan(initial.y + 25);
  const box = await editor.dialog.boundingBox();
  await page.mouse.move(box.x - 10, box.y + box.height / 2, { steps: 10 });
  await page.mouse.up();
  await expect(editor.dialog).toBeVisible();
  await expect(editor.rows.first()).toContainText(editor.names[0]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
});

test("dragging near the editor edge scrolls the list and cancellation restores every entry", async ({
  page,
}) => {
  const editor = await openDragEditor(page, 18);
  const handle = editor.rows.first().getByRole("button", { name: /^Drag / });
  const box = await handle.boundingBox();
  const bounds = await editor.dialog.boundingBox();
  const scrollBefore = await editor.dialog.evaluate((node) => node.scrollTop);
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + 8, { steps: 2 });
  await page.mouse.move(x, bounds.y + bounds.height - 24, { steps: 16 });
  await expect
    .poll(() => editor.dialog.evaluate((node) => node.scrollTop))
    .toBeGreaterThan(scrollBefore + 50);
  await page.keyboard.press("Escape");
  await page.mouse.up();
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
});

for (const direction of [1, -1]) {
  test(`holding at the ${direction > 0 ? "bottom" : "top"} scrolling edge advances the drop through newly revealed rows`, async ({
    page,
  }) => {
    const editor = await openDragEditor(page, 18);
    const sourceIndex = direction > 0 ? 0 : 17;
    const source = editor.rows.nth(sourceIndex);
    await source.evaluate((node) => node.scrollIntoView({ block: "center" }));
    const box = await source
      .getByRole("button", { name: /^Drag / })
      .boundingBox();
    const bounds = await editor.dialog.boundingBox();
    const header = await editor.dialog.locator(".modal-header").boundingBox();
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x, y + direction * 8, { steps: 2 });
    await expect(editor.dialog.locator(".is-dragging")).toHaveCount(1);
    await page.mouse.move(
      x,
      direction > 0
        ? bounds.y + bounds.height - 24
        : header.y + header.height + 24,
      { steps: 16 },
    );
    const position = () =>
      editor.rows.evaluateAll((nodes) =>
        nodes.findIndex((node) => node.classList.contains("is-dragging")),
      );
    const before = await position();
    await expect
      .poll(async () => direction * ((await position()) - before))
      .toBeGreaterThan(2);
    await page.mouse.up();
    await expect(editor.dialog.locator(".is-dragging")).toHaveCount(0);
    const dropPosition = await editor.rows.evaluateAll(
      (nodes, key) => nodes.findIndex((node) => node.dataset.entryKey === key),
      editor.original[sourceIndex].entryId,
    );
    expect(direction * (dropPosition - before)).toBeGreaterThan(2);
    const saved = await saveAndReadDrag(page, editor.dialog);
    const expected = [...editor.original];
    expected.splice(dropPosition, 0, ...expected.splice(sourceIndex, 1));
    // The superset survives only while its two entries stay adjacent. The
    // bottom drag always splits it; a top drop can land between its entries.
    const pair = expected.flatMap((item, index) =>
      item.groupId ? [index] : [],
    );
    const split = pair[1] - pair[0] !== 1;
    expect(saved).toEqual(
      expected.map((item) =>
        split && item.groupId ? { ...item, groupId: null } : item,
      ),
    );
  });
}

test("structural controls stay disabled during a preview and return after cancellation", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  await editor.dialog.getByLabel(`Options for ${editor.names[0]}`).click();
  await holdRowOverNext(page, editor);
  await expect(
    editor.dialog.getByRole("button", {
      name: `Move ${editor.names[0]} up`,
      exact: true,
    }),
  ).toBeDisabled();
  await expect(
    editor.dialog.getByLabel(`${editor.names[0]} superset with previous`, {
      exact: true,
    }),
  ).toBeDisabled();
  await expect(
    editor.dialog.locator(".exercise-picker button").first(),
  ).toBeDisabled();
  await editor.dialog
    .getByRole("button", { name: "Cancel", exact: true })
    .focus();
  await page.keyboard.press("Escape");
  await expect(
    editor.dialog.getByRole("button", { name: "Save routine", exact: true }),
  ).toBeEnabled();
  await page.mouse.up();
  await expect(
    editor.dialog.locator(".exercise-picker button").first(),
  ).toBeEnabled();
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
});

function liftStyle(row) {
  return row.evaluate((node) => {
    const surface = getComputedStyle(node, "::before");
    const matrix = new DOMMatrixReadOnly(getComputedStyle(node).transform);
    return {
      opacity: Number(surface.opacity),
      scale: surface.scale,
      shadow: surface.boxShadow,
      rowScaled: matrix.a !== 1 || matrix.d !== 1,
    };
  });
}

test("a dragged row lifts on its own surface and confirms where it lands", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  const { row } = await holdRowOverNext(page, editor);
  await expect(row).toHaveClass(/is-lifted/);
  await expect.poll(async () => (await liftStyle(row)).opacity).toBe(1);
  const lifted = await liftStyle(row);
  expect(lifted.shadow).not.toBe("none");
  expect(Number(lifted.scale)).toBeGreaterThan(1);
  // The row itself only translates, so drop geometry stays exact.
  expect(lifted.rowScaled).toBe(false);
  await page.mouse.up();
  await expect(row).toHaveClass(/is-landed/);
  await expect(row).not.toHaveClass(/is-lifted/);
  await expect(row).not.toHaveClass(/is-landed/, { timeout: 3000 });
  await expect.poll(async () => (await liftStyle(row)).opacity).toBe(0);
  expect(
    await row.evaluate(
      (node) =>
        new DOMMatrixReadOnly(getComputedStyle(node).transform).isIdentity,
    ),
  ).toBe(true);
});

test("reduced motion keeps the lifted outline without scaling or flashing", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  const editor = await openDragEditor(page);
  const { row } = await holdRowOverNext(page, editor);
  const lifted = await liftStyle(row);
  expect(lifted.opacity).toBe(1);
  expect(lifted.shadow).not.toBe("none");
  expect(lifted.scale).toBe("none");
  await page.mouse.up();
  await expect(row).not.toHaveClass(/is-lifted/);
  expect((await liftStyle(row)).opacity).toBe(0);
});

test("a cancelled drag settles without the landing confirmation", async ({
  page,
}) => {
  const editor = await openDragEditor(page);
  const { row } = await holdRowOverNext(page, editor);
  await page.keyboard.press("Escape");
  await page.mouse.up();
  await expect(row).not.toHaveClass(/is-lifted/);
  await expect(editor.dialog.locator(".is-landed")).toHaveCount(0);
});
