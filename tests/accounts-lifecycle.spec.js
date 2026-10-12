import { expect, test } from "@playwright/test";
import { readFile } from "node:fs/promises";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";

const emailSink = "http://127.0.0.1:3002/emails";
const originalPassword = "FORMA-local-test-passphrase-2026";
const replacementPassword = "FORMA-reset-test-passphrase-2026";
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

async function emailOfKind(request, email, kind) {
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      const messages = response.ok() ? await response.json() : [];
      return messages.some((message) => message.kind === kind);
    })
    .toBe(true);
  const response = await request.get(
    `${emailSink}?email=${encodeURIComponent(email)}`,
  );
  return (await response.json())
    .filter((message) => message.kind === kind)
    .at(-1);
}

async function registerAndVerify(page, name, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill(name);
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(originalPassword);
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("verification link");
  const message = await emailOfKind(page.request, email, "verify-email");
  expect(message.url).toBeTruthy();
  await page.goto(message.url);
}

async function signIn(page, email, password) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
}

async function openAccountSection(page, section) {
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: section, exact: true }).click();
}

async function getSessionUser(page) {
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json())?.user || null;
  });
}

function totpFromUri(totpURI) {
  const encodedSecret = new URL(totpURI).searchParams.get("secret");
  if (!encodedSecret)
    throw new Error("Authenticator setup response had no secret");
  const secret = new TextDecoder().decode(base32.decode(encodedSecret));
  return createOTP(secret).totp();
}

test("password recovery, sessions, authenticator recovery, and deletion use real flows", async ({
  browser,
}) => {
  const email = `lifecycle-${stamp()}@example.test`;
  const firstContext = await browser.newContext();
  const firstPage = await firstContext.newPage();
  const secondContext = await browser.newContext();
  const secondPage = await secondContext.newPage();

  try {
    await registerAndVerify(firstPage, "Lifecycle Member", email);

    // Use the delivered token and the actual reset form. The generic message
    // must not reveal whether an address has an account.
    await clickMainNavigation(firstPage, "Account");
    await pageAsSignedOutReset(firstPage, email, replacementPassword);
    await expect(firstPage.getByRole("status")).toContainText(
      "Password updated",
    );
    await expect(
      firstPage.getByRole("heading", { name: "Welcome back" }),
    ).toBeVisible();
    await signIn(firstPage, email, replacementPassword);
    await expect(
      firstPage.getByText("Lifecycle Member", { exact: true }).first(),
    ).toBeVisible();

    // A second independent browser creates a separately revocable session.
    await signIn(secondPage, email, replacementPassword);
    await expect(
      secondPage.getByText("Lifecycle Member", { exact: true }).first(),
    ).toBeVisible();
    await openAccountSection(firstPage, "Security");
    await expect(
      firstPage.getByRole("heading", { name: "Active sessions" }),
    ).toBeVisible();
    await expect(
      firstPage.getByRole("button", { name: "Revoke", exact: true }),
    ).toBeVisible();
    await firstPage
      .getByRole("button", { name: "Revoke", exact: true })
      .click();
    await expect(
      firstPage.getByRole("button", { name: "Revoke", exact: true }),
    ).toHaveCount(0);
    await secondPage.reload();
    await expect.poll(() => getSessionUser(secondPage)).toBeNull();

    // Enroll and verify TOTP; recovery codes appear only during setup. Consume
    // one through Better Auth's real sign-in challenge on a fresh context.
    await firstPage
      .getByLabel("Confirm your password")
      .fill(replacementPassword);
    await firstPage
      .getByRole("button", { name: "Set up authenticator" })
      .click();
    const setupCodeBlock = firstPage.locator(
      ".account-mfa-setup .account-codes pre",
    );
    await expect(setupCodeBlock).toBeVisible();
    const recoveryCode = (await setupCodeBlock.innerText()).split(/\s+/)[0];
    const setupText = await firstPage.locator(".account-mfa-setup").innerText();
    const uriMatch = setupText.match(/otpauth:\/\/[^\s]+/);
    // The interface intentionally displays the key for manual setup. Read it
    // from the DOM to calculate a fresh one-time code without mocking auth.
    const secretText = await firstPage
      .locator(".account-mfa-setup code")
      .innerText();
    const totpURI =
      uriMatch?.[0] || `otpauth://totp/FORMA?secret=${secretText}`;
    await firstPage
      .getByLabel("Authenticator code")
      .fill(await totpFromUri(totpURI));
    await firstPage.getByRole("button", { name: "Verify and enable" }).click();
    await expect(firstPage.getByRole("status")).toContainText(
      "Two-step verification is now on",
    );
    const recoveryDownloadPromise = firstPage.waitForEvent("download");
    await firstPage.getByRole("button", { name: "Download codes" }).click();
    const recoveryDownload = await recoveryDownloadPromise;
    expect(recoveryDownload.suggestedFilename()).toBe(
      "forma-recovery-codes.txt",
    );
    const downloadedCodes = (
      await readFile(await recoveryDownload.path(), "utf8")
    )
      .trim()
      .split(/\s+/);
    expect(downloadedCodes).toContain(recoveryCode);

    await signIn(secondPage, email, replacementPassword);
    await expect(
      secondPage.getByRole("heading", { name: "One more step" }),
    ).toBeVisible();
    await secondPage.getByRole("button", { name: "Use recovery code" }).click();
    await secondPage.getByLabel("Recovery code").fill(recoveryCode);
    await secondPage
      .getByRole("button", { name: "Verify and sign in" })
      .click();
    await expect(
      secondPage.getByText("Lifecycle Member", { exact: true }).first(),
    ).toBeVisible();

    // Better Auth first sends an approval link to the current mailbox, then a
    // verification link to the requested address. Follow both before deletion.
    const newEmail = `lifecycle-updated-${stamp()}@example.test`;
    await openAccountSection(secondPage, "Profile");
    await secondPage.getByLabel("New email address").fill(newEmail);
    await secondPage
      .getByRole("button", { name: "Send verification", exact: true })
      .click();
    await expect(secondPage.getByRole("status")).toContainText(
      "current inbox, then verify the new address",
    );
    const approval = await emailOfKind(
      secondPage.request,
      email,
      "change-email",
    );
    expect(approval.url).toBeTruthy();
    await secondPage.goto(approval.url);
    const newAddressVerification = await emailOfKind(
      secondPage.request,
      newEmail,
      "verify-email",
    );
    expect(newAddressVerification.url).toBeTruthy();
    await secondPage.goto(newAddressVerification.url);
    await expect
      .poll(async () => (await getSessionUser(secondPage))?.email)
      .toBe(newEmail);

    // Deletion is a two-stage operation: the request sends mail, and the
    // account remains active until the emailed confirmation URL is used.
    await openAccountSection(secondPage, "Privacy");
    await secondPage
      .getByRole("button", { name: "Review account deletion" })
      .click();
    await secondPage
      .getByRole("button", { name: "Cancel", exact: true })
      .click();
    expect(await getSessionUser(secondPage)).toBeTruthy();
    await expect(
      secondPage.getByRole("button", { name: "Review account deletion" }),
    ).toBeVisible();
    await secondPage
      .getByRole("button", { name: "Review account deletion" })
      .click();
    await secondPage
      .getByLabel("Confirm your password")
      .fill(replacementPassword);
    await secondPage.getByLabel("Type DELETE to confirm").fill("DELETE");
    await secondPage
      .getByRole("button", { name: "Send confirmation email" })
      .click();
    await expect(secondPage.getByRole("status")).toContainText(
      "Confirmation email sent. Your account remains active until you confirm.",
    );
    expect(await getSessionUser(secondPage)).toBeTruthy();
    const deletion = await emailOfKind(
      secondPage.request,
      newEmail,
      "delete-account",
    );
    await secondPage.goto(deletion.url);
    await expect.poll(() => getSessionUser(secondPage)).toBeNull();
  } finally {
    await firstContext.close();
    await secondContext.close();
  }
});

async function pageAsSignedOutReset(page, email, newPassword) {
  await page.getByRole("button", { name: /forgot password/i }).click();
  await page.getByLabel("Email address").fill(email);
  await page.getByRole("button", { name: "Send reset link" }).click();
  await expect(page.getByRole("status")).toContainText(
    "reset link is on its way",
  );
  const reset = await emailOfKind(page.request, email, "reset-password");
  expect(reset.url).toBeTruthy();
  await page.goto(reset.url);
  await expect(
    page.getByRole("heading", { name: "Choose a new password" }),
  ).toBeVisible();
  await page
    .locator('.account-form input[autocomplete="new-password"]')
    .fill(newPassword);
  await page.getByRole("button", { name: "Update password" }).click();
}
