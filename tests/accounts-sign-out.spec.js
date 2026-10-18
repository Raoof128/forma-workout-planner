import { expect, test } from "@playwright/test";
import pg from "pg";

const emailSink = "http://127.0.0.1:3002/emails";
const password = "FORMA-sign-out-passphrase-2026";
// Two browsers each register or sign in, so allow more than the default.
test.describe.configure({ timeout: 120_000 });

const stamp = () => `${Date.now()}-${Math.random().toString(16).slice(2)}`;

// Wait until either the desktop sidebar item or the phone menu toggle is
// showing, then open the phone drawer when it is closed.
async function openDrawerIfNeeded(page, item) {
  const toggle = page.getByRole("button", { name: "Toggle navigation" });
  await expect
    .poll(async () => (await item.isVisible()) || (await toggle.isVisible()))
    .toBe(true);
  if (
    (await toggle.isVisible()) &&
    (await toggle.getAttribute("aria-expanded")) !== "true"
  )
    await toggle.click();
}

async function clickMainNavigation(page, name) {
  const item = page
    .locator("#main-sidebar")
    .getByRole("button", { name, exact: true });
  await openDrawerIfNeeded(page, item);
  await item.scrollIntoViewIfNeeded();
  await item.click();
}

async function latestVerification(request, email) {
  let message;
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      const messages = response.ok() ? await response.json() : [];
      message = messages.filter((item) => item.kind === "verify-email").at(-1);
      return !!message;
    })
    .toBe(true);
  return message;
}

async function getUser(page) {
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json())?.user || null;
  });
}

async function signIn(page, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(
    page.getByText("Sign-out Member", { exact: true }).first(),
  ).toBeVisible();
}

async function register(page, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill("Sign-out Member");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page
    .getByRole("checkbox", { name: /agree to the Terms of Use/i })
    .check();
  await page
    .getByRole("checkbox", { name: /consent to FORMA storing/i })
    .check();
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(
    page.getByRole("status").filter({ hasText: "verification link" }),
  ).toContainText("verification link");
  const verification = await latestVerification(page.request, email);
  await page.goto(verification.url);
  await signIn(page, email);
}

// Make every session for this member older than the five-minute step-up
// window, as for someone who signed in earlier in the day.
async function ageSessions(email) {
  const client = new pg.Client({
    connectionString: process.env.TEST_DATABASE_URL,
  });
  await client.connect();
  try {
    const { rows } = await client.query(
      `SELECT nspname FROM pg_namespace WHERE nspname LIKE 'forma_browser_%'`,
    );
    for (const { nspname } of rows)
      await client.query(
        `UPDATE "${nspname}"."session" AS s
           SET "createdAt" = now() - interval '10 minutes'
          FROM "${nspname}"."user" AS u
         WHERE s."userId" = u.id AND u.email = $1`,
        [email],
      );
  } finally {
    await client.end();
  }
}

async function openSecurity(page) {
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Security", exact: true }).click();
}

async function openProfileMenu(page) {
  const trigger = page.getByRole("button", { name: /Account menu/ });
  await openDrawerIfNeeded(page, trigger);
  await trigger.click();
  await expect(trigger).toHaveAttribute("aria-expanded", "true");
  return page.getByRole("menu", { name: "Account menu" });
}

test("the sidebar profile menu signs out of this device", async ({ page }) => {
  const email = `sidebar-${stamp()}@example.test`;
  await register(page, email);
  await clickMainNavigation(page, "Overview");

  const menu = await openProfileMenu(page);
  await expect(menu.getByRole("menuitem")).toHaveText([
    "Manage account",
    "Sign out",
  ]);
  await expect(menu.getByRole("menuitem").first()).toBeFocused();
  await page.keyboard.press("ArrowDown");
  await expect(
    menu.getByRole("menuitem", { name: "Sign out", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(menu).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: /Account menu/ }),
  ).toBeFocused();

  const reopened = await openProfileMenu(page);
  await reopened.getByRole("menuitem", { name: "Sign out" }).click();
  await expect(page.locator(".toast")).toContainText("You’ve signed out.");
  await expect.poll(() => getUser(page)).toBeNull();
  await expect(page.locator("main")).toHaveAttribute("data-page", "account");
  await expect(page.getByLabel("Email address")).toBeVisible();
});

test("sign out everywhere works long after signing in", async ({ browser }) => {
  const email = `everywhere-${stamp()}@example.test`;
  const primaryContext = await browser.newContext();
  const secondaryContext = await browser.newContext();
  const primary = await primaryContext.newPage();
  const secondary = await secondaryContext.newPage();
  try {
    await register(primary, email);
    await signIn(secondary, email);
    await ageSessions(email);
    await openSecurity(primary);
    primary.once("dialog", (dialog) => dialog.accept());
    await primary
      .getByRole("button", { name: "Sign out everywhere", exact: true })
      .click();
    await expect.poll(() => getUser(primary)).toBeNull();
    await expect.poll(() => getUser(secondary)).toBeNull();
    await expect(primary.getByText(/reauthentication/i)).toHaveCount(0);
  } finally {
    await primaryContext.close();
    await secondaryContext.close();
  }
});

test("signing out other devices after an older sign-in confirms the password", async ({
  browser,
}) => {
  const email = `others-${stamp()}@example.test`;
  const primaryContext = await browser.newContext();
  const secondaryContext = await browser.newContext();
  const primary = await primaryContext.newPage();
  const secondary = await secondaryContext.newPage();
  try {
    await register(primary, email);
    await signIn(secondary, email);
    await ageSessions(email);
    await openSecurity(primary);
    primary.once("dialog", (dialog) => dialog.accept());
    await primary
      .getByRole("button", { name: "Sign out other devices", exact: true })
      .click();
    const stepUp = primary.locator("form.account-step-up");
    const confirm = stepUp.getByLabel("Confirm your password", {
      exact: true,
    });
    await expect(confirm).toBeFocused();
    await confirm.fill("not the right passphrase");
    await primary
      .getByRole("button", { name: "Confirm and sign out", exact: true })
      .click();
    await expect(stepUp.getByRole("alert")).toContainText(
      "That password isn’t right.",
    );
    expect(await getUser(secondary)).not.toBeNull();
    await confirm.fill(password);
    await primary
      .getByRole("button", { name: "Confirm and sign out", exact: true })
      .click();
    await expect(primary.locator(".toast")).toContainText(
      "Other devices were signed out.",
    );
    await expect(confirm).toHaveCount(0);
    await expect.poll(() => getUser(secondary)).toBeNull();
    expect(await getUser(primary)).not.toBeNull();
    await expect(primary.locator(".account-device-row")).toHaveCount(1);
  } finally {
    await primaryContext.close();
    await secondaryContext.close();
  }
});
