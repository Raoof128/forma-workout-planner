import { test, expect } from "@playwright/test";
test("real session loading uses the lime background and completes without a forced delay", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  await page.route("**/api/auth/get-session", async (route) => {
    await gate;
    await route.fulfill({ json: null });
  });
  try {
    await page.goto("/");
    await expect(
      page
        .getByRole("status")
        .filter({ hasText: "Checking your account session" }),
    ).toContainText("Checking your account session");
    await expect(page.getByRole("main")).toHaveCSS(
      "background-color",
      "rgb(223, 247, 128)",
    );
    await expect(page.locator(".forma-orbit").first()).toHaveCSS(
      "animation-name",
      "none",
    );
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > innerWidth,
      ),
    ).toBe(false);
  } finally {
    release();
  }
  await expect(
    page.getByRole("heading", {
      name: "A little stronger, every day.",
      exact: true,
    }),
  ).toBeVisible();
  await expect(page.locator(".forma-loading-panel")).toHaveCount(0);
});
