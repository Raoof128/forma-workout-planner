import { test, expect } from "@playwright/test";
import { openDragEditor, saveAndReadDrag } from "./routine-drag.helpers.js";

async function touchMove(page, session, start, end) {
  await session.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [{ x: start.x, y: start.y, id: 1 }],
  });
  for (let step = 1; step <= 18; step++) {
    await session.send("Input.dispatchTouchEvent", {
      type: "touchMove",
      touchPoints: [
        {
          x: start.x + ((end.x - start.x) * step) / 18,
          y: start.y + ((end.y - start.y) * step) / 18,
          id: 1,
        },
      ],
    });
    await page.evaluate(() => new Promise(requestAnimationFrame));
  }
}

async function holdTouchRow(page, context, editor) {
  const session = await context.newCDPSession(page);
  const row = editor.rows.filter({
    has: page.getByLabel(`${editor.names[0]} reps`, { exact: true }),
  });
  const first = await row.boundingBox();
  const second = await editor.rows.nth(1).boundingBox();
  const handle = await row
    .getByRole("button", { name: /^Drag / })
    .boundingBox();
  const start = {
    x: handle.x + handle.width / 2,
    y: handle.y + handle.height / 2,
  };
  await touchMove(page, session, start, {
    x: start.x,
    y: start.y + second.y - first.y,
  });
  await expect
    .poll(async () => (await row.boundingBox()).y)
    .toBeGreaterThan(first.y + 25);
  return session;
}

test("a trusted touch gesture moves the full row and retains every saved prescription", async ({
  page,
  context,
}) => {
  const editor = await openDragEditor(page);
  const session = await holdTouchRow(page, context, editor);
  await session.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect(editor.rows.nth(1)).toContainText(editor.names[0]);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual([
    editor.original[1],
    editor.original[0],
    editor.original[2],
  ]);
  await session.detach();
});

test("touch cancellation restores the original order and superset without closing the editor", async ({
  page,
  context,
}) => {
  const editor = await openDragEditor(page);
  const session = await holdTouchRow(page, context, editor);
  await session.send("Input.dispatchTouchEvent", {
    type: "touchCancel",
    touchPoints: [],
  });
  await expect(editor.rows.first()).toContainText(editor.names[0]);
  await expect(editor.dialog).toBeVisible();
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
  await session.detach();
});

test("touch scrolling outside the handle remains native and does not reorder exercises", async ({
  page,
  context,
}) => {
  const editor = await openDragEditor(page, 18);
  const session = await context.newCDPSession(page);
  const bounds = await editor.dialog.boundingBox();
  const before = await editor.dialog.evaluate((node) => node.scrollTop);
  const start = {
    x: bounds.x + bounds.width - 18,
    y: bounds.y + bounds.height - 120,
  };
  await touchMove(page, session, start, { x: start.x, y: start.y - 240 });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect
    .poll(() => editor.dialog.evaluate((node) => node.scrollTop))
    .toBeGreaterThan(before + 50);
  expect(await saveAndReadDrag(page, editor.dialog)).toEqual(editor.original);
  await session.detach();
});
