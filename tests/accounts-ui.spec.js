import { test, expect } from "@playwright/test";

async function clickMainNavigation(page, name) {
  const item = page.getByRole("button", { name, exact: true });
  const toggle = page.getByRole("button", { name: "Toggle navigation" });
  await expect
    .poll(async () => (await item.isVisible()) || (await toggle.isVisible()))
    .toBe(true);
  if (
    (await toggle.isVisible()) &&
    (await toggle.getAttribute("aria-expanded")) !== "true"
  ) {
    await toggle.click();
  }
  await item.scrollIntoViewIfNeeded();
  await item.click();
}

test("guest account entry offers accessible sign-in and registration flows", async ({
  page,
}) => {
  await page.goto("/");
  await clickMainNavigation(page, "Account");

  await expect(page.getByText("YOUR TRAINING, IN ONE PLACE")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: /welcome back/i }),
  ).toBeVisible();
  await page.getByRole("button", { name: /create account/i }).click();
  await expect(
    page.getByRole("heading", { name: /create your account/i }),
  ).toBeVisible();

  await page.getByLabel("Display name").fill("Alex Member");
  await page.getByLabel("Email address").fill("alex@example.test");
  await page.getByLabel(/^Password/).fill("short");
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(page.getByLabel(/^Password/)).toHaveJSProperty(
    "validity.valid",
    false,
  );

  await page.getByRole("button", { name: /already have an account/i }).click();
  await expect(
    page.getByRole("heading", { name: /welcome back/i }),
  ).toBeVisible();
  await page.getByRole("button", { name: /forgot password/i }).click();
  await expect(
    page.getByRole("heading", { name: /reset your password/i }),
  ).toBeVisible();
  await expect(page.getByLabel("Email address")).toBeVisible();
  await page.getByRole("button", { name: /back to sign in/i }).click();
  await page.getByLabel("Email address").fill("resend@example.test");
  await page.getByRole("button", { name: "Resend verification" }).click();
  await expect(page.getByRole("status")).toContainText(
    "If this address needs verification, a link is on its way.",
  );
  await page.getByRole("button", { name: /continue as guest/i }).click();
  await expect(page.getByRole("heading", { name: "Overview" })).toBeVisible();
});
