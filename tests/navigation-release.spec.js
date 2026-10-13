import { test, expect } from "@playwright/test";

test("a hash change between first render and listener setup selects the current URL", async ({
  page,
}) => {
  await page.addInitScript(() => {
    const original = window.addEventListener;
    let changed = false;
    window.addEventListener = function (type, ...args) {
      if (type === "hashchange" && !changed) {
        changed = true;
        history.replaceState(null, "", "#history");
        window.dispatchEvent(new HashChangeEvent("hashchange"));
      }
      return original.call(this, type, ...args);
    };
  });
  await page.goto("/");
  await expect(page).toHaveURL(/#history$/);
  await expect(page.locator("main")).toHaveAttribute("data-page", "history");
  await expect(
    page.getByRole("heading", { name: "Every session counts." }),
  ).toBeVisible();
});
