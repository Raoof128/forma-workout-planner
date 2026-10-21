import { test, expect } from "@playwright/test";
import { freshData } from "../src/storage.js";

function seed(page, fixture = freshData()) {
  return page.addInitScript((data) => {
    if (!localStorage.getItem("forma-v1"))
      localStorage.setItem("forma-v1", JSON.stringify(data));
  }, fixture);
}

test("a routine can be previewed exercise by exercise without starting a workout", async ({
  page,
}) => {
  await seed(page);
  await page.goto("/#routines");
  await page
    .getByRole("button", { name: /^Upper body strength 6 exercises/ })
    .click();
  const dialog = page.getByRole("dialog");
  const opener = dialog.getByRole("button", {
    name: "Preview workout",
    exact: true,
  });
  await opener.click();
  await expect(dialog.locator(".modal-header h2")).toHaveText(
    "Workout preview",
  );
  const back = dialog.getByRole("button", { name: "Back to overview" });
  await expect(back).toBeFocused();
  const previous = dialog.getByRole("button", { name: "Previous exercise" });
  const next = dialog.getByRole("button", { name: "Next exercise" });
  await expect(previous).toHaveAttribute("aria-disabled", "true");
  await expect(
    dialog.getByRole("group", { name: "1 of 6: Barbell bench press" }),
  ).toBeVisible();
  await expect(dialog.locator(".exercise-media img")).toBeVisible();
  await expect(dialog.getByText("How to perform")).toBeVisible();

  await next.press("Enter");
  await expect(next).toBeFocused();
  await expect(dialog.getByRole("group", { name: /^2 of 6: / })).toBeVisible();
  await expect(dialog.locator(".routine-preview .sr-only")).toHaveText(
    /^Exercise 2 of 6: /,
  );

  const picker = dialog.getByRole("group", { name: "Choose exercise" });
  await picker.getByRole("button").last().click();
  await expect(dialog.getByRole("group", { name: /^6 of 6: / })).toBeVisible();
  await expect(next).toHaveAttribute("aria-disabled", "true");
  // aria-disabled keeps the button focusable; pressing it at the end is a no-op.
  await next.press("Enter");
  await expect(next).toBeFocused();
  await expect(dialog.getByRole("group", { name: /^6 of 6: / })).toBeVisible();

  await back.click();
  await expect(dialog.locator(".modal-header h2")).toHaveText(
    "Routine overview",
  );
  await expect(opener).toBeFocused();

  // An exercise name opens only that exercise's card, not the carousel.
  const row = dialog.getByRole("button", { name: "View Lat pulldown" });
  await row.click();
  await expect(dialog.locator(".modal-header h2")).toHaveText("Lat pulldown");
  await expect(dialog.locator(".routine-preview-name")).toHaveText(
    /Lat pulldown$/,
  );
  await expect(dialog.locator(".routine-preview-name")).toHaveCount(1);
  await expect(
    dialog.getByRole("button", { name: "Next exercise" }),
  ).toHaveCount(0);
  await expect(
    dialog.getByRole("group", { name: "Choose exercise" }),
  ).toHaveCount(0);
  await expect(dialog.getByText("How to perform")).toBeVisible();
  await expect(
    dialog.getByRole("button", { name: "Back to overview" }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(dialog.locator(".modal-header h2")).toHaveText(
    "Routine overview",
  );

  // Previewing never starts a workout or changes saved data.
  const stored = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(stored.active ?? null).toBeNull();
});

test("the routine card menu opens the preview", async ({ page }) => {
  await seed(page);
  await page.goto("/#routines");
  await page.getByLabel("Actions for Upper body strength").click();
  await page
    .getByRole("button", { name: "Preview workout", exact: true })
    .click();
  await expect(page.locator(".modal-header h2")).toHaveText("Workout preview");
  await expect(
    page.getByRole("group", { name: "1 of 6: Barbell bench press" }),
  ).toBeVisible();
});

test("a template can be previewed before it is added", async ({ page }) => {
  await page.goto("/#routines");
  // Keyboard activation: WebKit does not focus buttons on mouse click.
  await page.getByRole("button", { name: "Preview Push day" }).press("Enter");
  const dialog = page.getByRole("dialog");
  await expect(dialog.locator(".modal-header h2")).toHaveText(
    "Workout preview",
  );
  await expect(
    dialog.getByRole("group", { name: "1 of 4: Barbell bench press" }),
  ).toBeVisible();
  await dialog.getByRole("button", { name: "Next exercise" }).click();
  await expect(dialog.getByRole("group", { name: /^2 of 4: / })).toBeVisible();
  await dialog.getByRole("button", { name: "Close preview" }).click();
  await expect(dialog).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Preview Push day" }),
  ).toBeFocused();
  const after = await page.evaluate(
    () => JSON.parse(localStorage.getItem("forma-v1") ?? "null")?.routines,
  );
  expect((after ?? []).some((routine) => routine.name === "Push day")).toBe(
    false,
  );

  await page.getByRole("button", { name: "Preview Push day" }).click();
  await dialog.getByRole("button", { name: "Add to my routines" }).click();
  await expect(dialog.locator(".modal-header h2")).toHaveText(
    "Routine overview",
  );
  await expect(dialog).toContainText("Push day");
});

test("matched exercises show a credited, self-hosted demonstration clip", async ({
  page,
}) => {
  const external = [];
  page.on("request", (request) => {
    if (
      request.resourceType() === "media" &&
      !request.url().startsWith("http://127.0.0.1:5173/")
    )
      external.push(request.url());
  });
  await seed(page);
  await page.goto("/#routines");
  await page
    .getByRole("button", { name: /^Upper body strength 6 exercises/ })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog
    .getByRole("button", { name: "View Barbell bench press" })
    .click();
  const video = dialog.getByLabel("Demonstration video: Barbell bench press");
  await expect(video).toBeVisible();
  await expect(video).toHaveAttribute("preload", "none");
  await expect(video).not.toHaveAttribute("autoplay");
  await expect(dialog.locator(".exercise-demo")).toContainText("CC BY 3.0");
  await expect(dialog.locator(".exercise-demo")).toContainText("FitnessScape");
  const playable = await video.evaluate(
    (node) =>
      new Promise((resolve) => {
        node.addEventListener("loadeddata", () => resolve(true), {
          once: true,
        });
        node.addEventListener("error", () => resolve(false), { once: true });
        node.load();
      }),
  );
  expect(playable).toBe(true);
  await page.keyboard.press("Escape");

  // An exercise without a reviewed clip shows no video.
  await dialog
    .getByRole("button", { name: "View One-arm dumbbell row" })
    .click();
  await expect(dialog.locator(".exercise-demo")).toHaveCount(0);
  expect(external).toEqual([]);
});

test("the exercise library guide shows the demonstration clip", async ({
  page,
}) => {
  await page.goto("/#library");
  await page.getByLabel("Search exercise library").fill("barbell back squat");
  await page
    .locator(".library-card")
    .filter({
      has: page.getByRole("heading", {
        name: "Barbell back squat",
        exact: true,
      }),
    })
    .click();
  const dialog = page.getByRole("dialog");
  await expect(
    dialog.getByLabel("Demonstration video: Barbell back squat"),
  ).toBeVisible();
  await expect(dialog.locator(".exercise-demo")).toContainText("FitnessScape");
});
