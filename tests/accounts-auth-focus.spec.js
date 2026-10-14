import { test, expect } from "@playwright/test";
test.beforeEach(async ({ page }) => {
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/get-session"))
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: "null",
      });
    if (path.endsWith("/auth/sign-in/email"))
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ twoFactorRedirect: true }),
      });
    return route.abort();
  });
});
test("auth mode changes focus the new form heading", async ({ page }) => {
  await page.goto("/#account");
  const signup = page.getByRole("button", {
    name: "New to FORMA? Create account",
    exact: true,
  });
  await signup.focus();
  await page.keyboard.press("Enter");
  const heading = page.getByRole("heading", {
    name: "Create your account",
    exact: true,
  });
  await expect(heading).toBeFocused();
  const position = await heading.evaluate((el) => ({
    top: el.getBoundingClientRect().top,
    bottom: el.getBoundingClientRect().bottom,
    stickyBottom: document.querySelector(".mobile-top").getClientRects().length
      ? document.querySelector(".mobile-top").getBoundingClientRect().bottom
      : 0,
    height: innerHeight,
  }));
  expect(position.top).toBeGreaterThanOrEqual(position.stickyBottom);
  expect(position.bottom).toBeLessThanOrEqual(position.height);
  await page.keyboard.press("Tab");
  await expect(page.getByLabel("Display name", { exact: true })).toBeFocused();
  const signin = page.getByRole("button", {
    name: "Already have an account? Sign in",
    exact: true,
  });
  await signin.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("heading", { name: "Welcome back", exact: true }),
  ).toBeFocused();
  const forgot = page.getByRole("button", {
    name: "Forgot password?",
    exact: true,
  });
  await forgot.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("heading", { name: "Reset your password", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(page.getByLabel("Email address", { exact: true })).toBeFocused();
});
test("MFA transition focuses its new form heading", async ({ page }) => {
  await page.goto("/#account");
  await page
    .getByLabel("Email address", { exact: true })
    .fill("synthetic@example.test");
  await page
    .getByLabel("Password", { exact: true })
    .fill("synthetic-passphrase");
  const submit = page.getByRole("button", { name: "Sign in", exact: true });
  await submit.focus();
  await page.keyboard.press("Enter");
  const mfaHeading = page.getByRole("heading", {
    name: "One more step",
    exact: true,
  });
  await expect(mfaHeading).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(
    page.getByLabel("Authenticator code", { exact: true }),
  ).toBeFocused();
});
