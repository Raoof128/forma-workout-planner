import { expect, test } from "@playwright/test";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";

const emailSink = "http://127.0.0.1:3002/emails";
const currentPassword = "FORMA-controls-current-passphrase-2026";
const nextPassword = "FORMA-controls-next-passphrase-2026";
const stamp = () => `${Date.now()}-${Math.random().toString(16).slice(2)}`;

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

async function latestVerification(request, email) {
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      const messages = response.ok() ? await response.json() : [];
      return messages.some(
        (message) => message.kind === "verify-email" && message.email === email,
      );
    })
    .toBe(true);
  const response = await request.get(
    `${emailSink}?email=${encodeURIComponent(email)}`,
  );
  return (await response.json())
    .filter((message) => message.kind === "verify-email")
    .at(-1);
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

async function registerAndSignIn(page, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill("Control Member");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(currentPassword);
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
  expect(verification.url).toBeTruthy();
  await page.goto(verification.url);
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(currentPassword);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(
    page.getByText("Control Member", { exact: true }).first(),
  ).toBeVisible();
}

async function signIn(page, email, password) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
}

async function openSecurity(page) {
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Security", exact: true }).click();
}

async function createTotp(uri) {
  const encoded = new URL(uri).searchParams.get("secret");
  if (!encoded) throw new Error("Authenticator setup URI is missing its key");
  return createOTP(new TextDecoder().decode(base32.decode(encoded))).totp();
}

test("password updates, session revocation, recovery-code rotation, and sign-out actions are real", async ({
  browser,
}) => {
  const email = `auth-controls-${stamp()}@example.test`;
  const primaryContext = await browser.newContext();
  const primary = await primaryContext.newPage();
  const secondaryContext = await browser.newContext();
  const secondary = await secondaryContext.newPage();

  try {
    await registerAndSignIn(primary, email);
    await signIn(secondary, email, currentPassword);
    await expect(
      secondary.getByText("Control Member", { exact: true }).first(),
    ).toBeVisible();

    await openSecurity(primary);
    await primary.getByRole("button", { name: "Refresh sessions" }).click();
    await expect
      .poll(() => primary.locator(".account-device-row").count())
      .toBeGreaterThanOrEqual(2);
    await primary
      .getByLabel("Current password", { exact: true })
      .fill(currentPassword);
    await primary
      .getByRole("textbox", { name: /^New password/ })
      .fill(nextPassword);
    await primary
      .getByLabel("Confirm new password", { exact: true })
      .fill(nextPassword);
    await primary.getByRole("button", { name: "Update password" }).click();
    await expect(
      primary.getByText("Password updated. Other sessions were signed out.", {
        exact: true,
      }),
    ).toBeVisible();
    await expect.poll(() => getUser(secondary)).toBeNull();
    await signIn(secondary, email, currentPassword);
    await expect(secondary.getByRole("alert")).toContainText(
      "Invalid email or password",
    );
    await signIn(secondary, email, nextPassword);
    await expect(
      secondary.getByText("Control Member", { exact: true }).first(),
    ).toBeVisible();

    // Explicitly revoke all other devices, separately from password-change
    // revocation, and verify the second context loses its session.
    primary.once("dialog", (dialog) => dialog.accept());
    await primary
      .getByRole("button", { name: "Sign out other devices" })
      .click();
    await expect.poll(() => getUser(secondary)).toBeNull();

    await signIn(secondary, email, nextPassword);
    await expect(
      secondary.getByText("Control Member", { exact: true }).first(),
    ).toBeVisible();
    await primary
      .getByLabel("Confirm your password", { exact: true })
      .fill(nextPassword);
    await primary.getByRole("button", { name: "Set up authenticator" }).click();
    const enrollment = primary.locator(".account-mfa-setup");
    await expect(enrollment).toBeVisible();
    const initialCodes = (
      await enrollment.locator(".account-codes pre").innerText()
    )
      .trim()
      .split(/\s+/);
    const uri = `otpauth://totp/FORMA?secret=${encodeURIComponent(
      await enrollment.locator("code").innerText(),
    )}`;
    await primary.getByLabel("Authenticator code").fill(await createTotp(uri));
    await primary.getByRole("button", { name: "Verify and enable" }).click();
    await expect(
      primary.getByText("Two-step verification is now on.", { exact: true }),
    ).toBeVisible();

    const recoveryCodeBlock = primary.locator(".account-codes pre");
    await primary
      .getByRole("button", { name: "Generate new recovery codes", exact: true })
      .click();
    await primary.getByRole("button", { name: "Cancel", exact: true }).click();
    await expect(recoveryCodeBlock).toHaveText(initialCodes.join("\n"));

    await primary
      .getByRole("button", { name: "Generate new recovery codes", exact: true })
      .click();
    await primary
      .getByLabel("Confirm your password", { exact: true })
      .fill(nextPassword);
    await primary
      .getByRole("button", { name: "Generate new codes", exact: true })
      .click();
    await expect
      .poll(async () => (await recoveryCodeBlock.innerText()).trim())
      .not.toBe(initialCodes.join("\n"));
    const rotatedCodes = (await recoveryCodeBlock.innerText())
      .trim()
      .split(/\s+/);
    expect(rotatedCodes).not.toEqual(initialCodes);
    await expect(
      primary.getByRole("button", { name: "Turn off", exact: true }),
    ).toBeVisible();

    await primary
      .getByRole("button", { name: "Turn off", exact: true })
      .click();
    await primary.getByRole("button", { name: "Cancel", exact: true }).click();
    await expect(
      primary.getByRole("button", { name: "Turn off", exact: true }),
    ).toBeVisible();
    await primary
      .getByRole("button", { name: "Turn off", exact: true })
      .click();
    await primary
      .getByLabel("Confirm your password", { exact: true })
      .fill(nextPassword);
    await primary
      .getByRole("button", { name: "Turn off two-step verification" })
      .click();
    await expect(
      primary.getByText("Two-step verification is off.", { exact: true }),
    ).toBeVisible();

    primary.once("dialog", (dialog) => dialog.accept());
    await primary
      .getByRole("button", { name: "Sign out other devices" })
      .click();
    await expect.poll(() => getUser(secondary)).toBeNull();
    await signIn(secondary, email, nextPassword);
    await expect(
      secondary.getByText("Control Member", { exact: true }).first(),
    ).toBeVisible();

    primary.once("dialog", (dialog) => dialog.accept());
    await primary.getByRole("button", { name: "Sign out everywhere" }).click();
    await expect.poll(() => getUser(primary)).toBeNull();
    await expect.poll(() => getUser(secondary)).toBeNull();
    const privateRead = await secondary.evaluate(async () => {
      const sessionResponse = await fetch("/api/auth/get-session", {
        credentials: "same-origin",
        cache: "no-store",
      });
      const member = (await sessionResponse.json())?.user?.id;
      const response = await fetch("/api/workspace", {
        credentials: "same-origin",
        headers: member ? { "X-Forma-Member": member } : {},
      });
      return { status: response.status, body: await response.json() };
    });
    expect(privateRead.status).toBe(401);
    expect(privateRead.body).not.toHaveProperty("data");
  } finally {
    await primaryContext.close();
    await secondaryContext.close();
  }
});
