import { test, expect } from "@playwright/test";

async function openGuide(page, query, exactName) {
  await page.getByLabel("Search exercise library").fill(query);
  const cards = page.locator(".library-card");
  await (
    exactName
      ? cards.filter({
          has: page.getByRole("heading", { name: exactName, exact: true }),
        })
      : cards.first()
  ).click();
  return page.getByRole("dialog");
}

test("machine equipment references do not replace free-weight exercise poses", async ({
  page,
}) => {
  await page.goto("/#library");
  const dialog = await openGuide(
    page,
    "seated calf raise",
    "Seated Calf Raise",
  );
  const image = dialog.getByRole("img", { name: /Equipment illustration/ });
  await expect(image).toBeVisible();
  await expect(dialog).toContainText("Equipment reference");
  const machineSrc = await image.getAttribute("src");
  await page.getByRole("button", { name: "Got it", exact: true }).click();
  await openGuide(page, "standing calf raise", "Standing calf raise");
  const freeWeight = dialog.getByRole("img", { name: /Exercise illustration/ });
  await expect(freeWeight).toBeVisible();
  expect(await freeWeight.getAttribute("src")).not.toEqual(machineSrc);
  await expect(dialog).toContainText("holding a dumbbell");
});

test("original equipment illustration loads locally and the guide remains keyboard accessible", async ({
  page,
}) => {
  const externalImages = [];
  page.on("request", (request) => {
    if (
      request.resourceType() === "image" &&
      !request.url().startsWith("http://127.0.0.1")
    )
      externalImages.push(request.url());
  });
  await page.goto("/#library");
  const dialog = await openGuide(page, "upper-body ergometer");
  const image = dialog.getByRole("img", { name: /Equipment illustration/ });
  await expect(image).toBeVisible();
  await expect(image).toHaveJSProperty("naturalWidth", 1536);
  await expect(dialog).toContainText("Original FORMA equipment illustration");
  await expect(dialog).toContainText("turn the cranks smoothly");
  await page.keyboard.press("Escape");
  await expect(dialog).not.toBeVisible();
  await expect(page.locator(".library-card").first()).toBeFocused();
  expect(externalImages).toEqual([]);
});

test("failed image delivery does not leave a permanent loader or hide exercise instructions", async ({
  page,
}) => {
  await page.route("**/exercise-media/**", (route) => route.abort());
  await page.goto("/#library");
  const dialog = await openGuide(page, "upper-body ergometer");
  await expect(dialog.locator(".exercise-media-unavailable")).toBeVisible();
  await expect(dialog.locator(".exercise-media-loading")).toHaveCount(0);
  await expect(dialog).toContainText("turn the cranks smoothly");
  await page.getByRole("button", { name: "Got it", exact: true }).click();
  await expect(dialog).not.toBeVisible();
});
