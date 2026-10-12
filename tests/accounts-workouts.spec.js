import { expect, test } from "@playwright/test";
import { createRequire } from "node:module";
import { initialData } from "../src/data.js";

const require = createRequire(import.meta.url);
const axePath = require.resolve("axe-core/axe.min.js");

const emailSink = "http://127.0.0.1:3002/emails";
const password = "FORMA-local-test-passphrase-2026";
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

async function latestVerificationEmail(request, email) {
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      return response.ok() ? response.json() : [];
    })
    .toEqual(
      expect.arrayContaining([
        expect.objectContaining({ kind: "verify-email", email }),
      ]),
    );
  const response = await request.get(
    `${emailSink}?email=${encodeURIComponent(email)}`,
  );
  const messages = await response.json();
  return messages.filter((item) => item.kind === "verify-email").at(-1);
}

async function createVerifiedAccount(page, name, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill(name);
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("verification link");

  const verification = await latestVerificationEmail(page.request, email);
  expect(verification.url).toBeTruthy();
  expect(new URL(verification.url).origin).toBe(new URL(page.url()).origin);
  await page.goto(verification.url);
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByText(name, { exact: true }).first()).toBeVisible();
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json()).user?.id;
  });
}

async function signInExistingAccount(page, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(
    page.getByText("Workout Member", { exact: true }).first(),
  ).toBeVisible();
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json()).user?.id;
  });
}

async function readWorkspace(page, memberId) {
  return page.evaluate(async (boundMemberId) => {
    const sessionResponse = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    const session = await sessionResponse.json();
    if (!session?.user?.id || session.user.id !== boundMemberId) {
      throw new Error("Bound member session changed");
    }
    const response = await fetch("/api/workspace", {
      credentials: "same-origin",
      cache: "no-store",
      headers: { "X-Forma-Member": boundMemberId },
    });
    return { status: response.status, body: await response.json() };
  }, memberId);
}

async function createTwoSetRoutine(page, name) {
  await clickMainNavigation(page, "My routines");
  await page
    .getByRole("button", { name: "Create routine", exact: true })
    .click();
  await page.getByLabel("Routine name").fill(name);
  await page
    .locator(".exercise-picker button")
    .filter({ hasText: "Barbell bench press" })
    .click();
  await page.getByLabel("Barbell bench press sets", { exact: true }).fill("2");
  await page.getByLabel("Barbell bench press reps", { exact: true }).fill("8");
  await page
    .getByLabel("Barbell bench press weight", { exact: true })
    .fill("42");
  await page.getByRole("button", { name: "Save routine", exact: true }).click();
  await expect(
    page.locator(".routine-card").filter({ hasText: name }),
  ).toBeVisible();
}

test("a completed workout persists through reload and a second browser context", async ({
  browser,
}) => {
  const run = stamp();
  const email = `workout-${run}@example.test`;
  const routineName = `Shared strength ${run}`;
  const firstContext = await browser.newContext();
  const firstPage = await firstContext.newPage();
  const secondContext = await browser.newContext();
  const secondPage = await secondContext.newPage();

  try {
    const memberId = await createVerifiedAccount(
      firstPage,
      "Workout Member",
      email,
    );
    await createTwoSetRoutine(firstPage, routineName);
    await firstPage
      .locator(".routine-card")
      .filter({ hasText: routineName })
      .click();
    await firstPage.getByRole("button", { name: "Start workout" }).click();
    await expect(
      firstPage.getByLabel("Barbell bench press set 1 weight", { exact: true }),
    ).toHaveValue("42");
    await firstPage
      .getByLabel("Barbell bench press set 2 weight", { exact: true })
      .fill("200");
    await firstPage
      .getByRole("button", {
        name: "Complete Barbell bench press set 1",
        exact: true,
      })
      .click();
    await expect(firstPage.locator(".set-done")).toHaveCount(1);
    await firstPage
      .getByRole("button", { name: "Finish workout", exact: true })
      .first()
      .click();
    await firstPage
      .getByRole("button", { name: "Save workout", exact: true })
      .click();
    await expect(firstPage.locator(".history-row")).toHaveCount(1);
    await firstPage.reload();
    await clickMainNavigation(firstPage, "Workout history");
    await expect(firstPage.locator(".history-row")).toHaveCount(1);

    const owned = await readWorkspace(firstPage, memberId);
    expect(owned.status).toBe(200);
    expect(owned.body.data.routines.map((item) => item.name)).toContain(
      routineName,
    );
    expect(owned.body.data.history).toHaveLength(1);
    expect(owned.body.data.history[0].exercises[0].sets[0]).toMatchObject({
      weight: 42,
      reps: 8,
      done: true,
    });
    expect(owned.body.data.history[0].exercises[0].sets[1]).toMatchObject({
      weight: 200,
      reps: 8,
      done: false,
    });

    const secondMemberId = await signInExistingAccount(secondPage, email);
    expect(secondMemberId).toBe(memberId);
    const shared = await readWorkspace(secondPage, secondMemberId);
    expect(shared.status).toBe(200);
    expect(shared.body.data.routines.map((item) => item.name)).toContain(
      routineName,
    );
    expect(shared.body.data.history).toHaveLength(1);
    await clickMainNavigation(secondPage, "My routines");
    await expect(
      secondPage.locator(".routine-card").filter({ hasText: routineName }),
    ).toBeVisible();
    await clickMainNavigation(secondPage, "Workout history");
    await expect(secondPage.locator(".history-row")).toHaveCount(1);

    await clickMainNavigation(firstPage, "Account");
    const recordPanel = firstPage.locator(".account-record-panel");
    await expect(recordPanel).toContainText("Barbell bench press");
    await expect(recordPanel).toContainText("42");
    await expect(recordPanel).not.toContainText("200");
  } finally {
    await Promise.all([firstContext.close(), secondContext.close()]);
  }
});

test("local training migration requires review and leaves the browser copy intact", async ({
  page,
}) => {
  const run = stamp();
  const email = `migration-${run}@example.test`;
  const local = structuredClone(initialData);
  local.routines = local.routines.slice(0, 1).map((routine) => ({
    ...routine,
    name: `Local legacy ${run}`,
  }));
  local.history = [];

  await page.goto("/");
  await page.evaluate((data) => {
    localStorage.setItem("forma-v1", JSON.stringify(data));
  }, local);
  await page.reload();
  const memberId = await createVerifiedAccount(page, "Migration Member", email);
  await clickMainNavigation(page, "Account");
  await page
    .getByRole("button", { name: "Training data", exact: true })
    .click();
  await page.getByRole("button", { name: "Review local data" }).click();
  await expect(
    page.getByRole("heading", { name: "Confirm training data" }),
  ).toBeVisible();
  await expect(
    page.locator(".account-import-review .account-import-totals"),
  ).toContainText("1 routines");
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Confirm training data" }),
  ).toBeHidden();
  await expect(
    page.getByRole("button", { name: "Review local data" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Review local data" }).click();
  await expect(
    page.getByRole("button", { name: "Import to account", exact: true }),
  ).toBeDisabled();

  await page
    .getByRole("checkbox", {
      name: /saved a copy of my current cloud training data/,
    })
    .check();
  await expect(
    page.getByRole("button", { name: "Import to account", exact: true }),
  ).toBeDisabled();
  const backupDownload = page.waitForEvent("download");
  await page
    .getByRole("button", {
      name: /Download current cloud copy before replacing/,
    })
    .click();
  expect((await backupDownload).suggestedFilename()).toContain(
    "forma-account-export",
  );
  await page.getByRole("button", { name: "Import to account" }).click();
  await expect(page.getByRole("status")).toContainText(
    "imported into your account",
  );

  const localAfter = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("forma-v1")),
  );
  expect(localAfter.routines).toEqual(local.routines);
  expect(localAfter.history).toEqual(local.history);
  const cloudAfter = await readWorkspace(page, memberId);
  expect(cloudAfter.status).toBe(200);
  expect(cloudAfter.body.data.routines.map((item) => item.name)).toContain(
    `Local legacy ${run}`,
  );

  const beforeFileImport = await readWorkspace(page, memberId);
  const fileBackup = structuredClone(initialData);
  fileBackup.routines = fileBackup.routines.slice(0, 1).map((routine) => ({
    ...routine,
    name: `File backup ${run}`,
  }));
  fileBackup.history = [];
  const uploadBackup = () =>
    page.locator('input[type="file"]').setInputFiles({
      name: "training-backup.json",
      mimeType: "application/json",
      buffer: Buffer.from(JSON.stringify(fileBackup)),
    });
  await uploadBackup();
  await expect(
    page.getByRole("heading", { name: "Confirm training data" }),
  ).toBeVisible();
  await expect(
    page.locator(".account-import-review .account-import-totals"),
  ).toContainText("1 routines");
  expect((await readWorkspace(page, memberId)).body).toEqual(
    beforeFileImport.body,
  );
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  expect((await readWorkspace(page, memberId)).body).toEqual(
    beforeFileImport.body,
  );

  await uploadBackup();
  await expect(
    page.getByRole("heading", { name: "Confirm training data" }),
  ).toBeVisible();
  await page
    .getByRole("checkbox", {
      name: /saved a copy of my current cloud training data/,
    })
    .check();
  await expect(
    page.getByRole("button", { name: "Import to account", exact: true }),
  ).toBeDisabled();
  const fileBackupDownload = page.waitForEvent("download");
  await page
    .getByRole("button", {
      name: /Download current cloud copy before replacing/,
    })
    .click();
  expect((await fileBackupDownload).suggestedFilename()).toContain(
    "forma-account-export",
  );
  await page.getByRole("button", { name: "Import to account" }).click();
  await expect(page.getByRole("status")).toContainText(
    "imported into your account",
  );
  const afterFileImport = await readWorkspace(page, memberId);
  expect(afterFileImport.body.data.routines.map((item) => item.name)).toContain(
    `File backup ${run}`,
  );
});

test("profile goal save persists and cancel discards an unapplied edit", async ({
  page,
}, testInfo) => {
  const localPart = `profile-${stamp().replaceAll("-", "")}`.padEnd(43, "x");
  const email = `${localPart}@example.test`;
  expect(email).toHaveLength(56);
  const memberId = await createVerifiedAccount(page, "Profile Member", email);
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Profile", exact: true }).click();

  const workspaceBefore = await readWorkspace(page, memberId);
  await page.getByLabel("Display name", { exact: true }).fill("Discarded Name");
  await page.getByLabel("Weekly workout goal").selectOption("7");
  await page
    .getByRole("navigation", { name: "Account sections" })
    .getByRole("button", { name: "Overview", exact: true })
    .click();
  const savedGoal = workspaceBefore.body.data.profile.goal;
  await expect(
    page.locator(".account-summary-card").filter({ hasText: "This week" }),
  ).toContainText(`/ ${savedGoal}`);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  await page.getByRole("button", { name: "Cancel changes" }).click();
  await expect(page.getByLabel("Display name", { exact: true })).toHaveValue(
    "Profile Member",
  );
  await expect(page.getByLabel("Weekly workout goal")).toHaveValue(
    String(workspaceBefore.body.data.profile.goal),
  );
  expect((await readWorkspace(page, memberId)).body).toEqual(
    workspaceBefore.body,
  );

  await page
    .getByLabel("Display name", { exact: true })
    .fill("Updated Profile");
  await page.getByLabel("Weekly workout goal").selectOption("5");
  await page.getByRole("button", { name: "Save changes", exact: true }).click();
  await expect(
    page.getByText("Profile and training goal saved.", { exact: true }),
  ).toBeVisible();
  const workspaceAfter = await readWorkspace(page, memberId);
  expect(workspaceAfter.body.data.profile.goal).toBe(5);
  expect(workspaceAfter.body.data.profile.name).toBe("Updated Profile");
  expect(workspaceAfter.body.revision).toBeGreaterThan(
    workspaceBefore.body.revision,
  );
  await expect(page.locator(".account-nav-member")).toContainText(
    "Updated Profile",
  );
  const member = await page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json()).user;
  });
  expect(member.name).toBe("Updated Profile");
  const exported = await page.evaluate(async (boundMemberId) => {
    const response = await fetch("/api/workspace/export", {
      credentials: "same-origin",
      headers: { "X-Forma-Member": boundMemberId },
    });
    return { status: response.status, body: await response.json() };
  }, memberId);
  expect(exported.status).toBe(200);
  expect(exported.body.profile.name).toBe("Updated Profile");

  for (const width of [320, 390, 1536]) {
    await page.setViewportSize({ width, height: 860 });
    try {
      await expect
        .poll(() =>
          page.evaluate(
            () => document.documentElement.scrollWidth <= innerWidth,
          ),
        )
        .toBe(true);
      if (process.env.FORMA_CAPTURE_ACCOUNT_LAYOUT === "1") {
        const navigationToggle = page.getByRole("button", {
          name: "Toggle navigation",
        });
        if (
          (await navigationToggle.isVisible()) &&
          (await navigationToggle.getAttribute("aria-expanded")) === "true"
        ) {
          await navigationToggle.click();
        }
        const dismissNotification = page.getByRole("button", {
          name: "Dismiss notification",
        });
        if (await dismissNotification.isVisible()) {
          await dismissNotification.click();
        }
        await page.screenshot({
          path: testInfo.outputPath(`account-profile-${width}.png`),
          fullPage: true,
        });
      }
    } catch (error) {
      const layout = await page.evaluate(() => ({
        documentWidth: document.documentElement.scrollWidth,
        bodyWidth: document.body.scrollWidth,
        viewportWidth: innerWidth,
        documentOverflowX: getComputedStyle(document.documentElement).overflowX,
        bodyOverflowX: getComputedStyle(document.body).overflowX,
        sidebar: (() => {
          const element = document.querySelector(".sidebar");
          if (!element) return null;
          const rect = element.getBoundingClientRect();
          const style = getComputedStyle(element);
          return {
            left: Math.round(rect.left),
            right: Math.round(rect.right),
            width: Math.round(rect.width),
            position: style.position,
            transform: style.transform,
            overflowX: style.overflowX,
          };
        })(),
        offenders: [...document.querySelectorAll("body *")]
          .map((element) => {
            const rect = element.getBoundingClientRect();
            return {
              tag: element.tagName.toLowerCase(),
              className:
                typeof element.className === "string" ? element.className : "",
              text: element.textContent?.trim().slice(0, 80),
              left: Math.round(rect.left),
              right: Math.round(rect.right),
              width: Math.round(rect.width),
              display: getComputedStyle(element).display,
              position: getComputedStyle(element).position,
            };
          })
          .filter(({ right }) => right > innerWidth + 1)
          .sort((a, b) => b.right - a.right)
          .slice(0, 20),
      }));
      throw new Error(
        `Account profile should fit at ${width}px: ${JSON.stringify(layout)}`,
        { cause: error },
      );
    }
    await expect(
      page.getByRole("heading", { name: "Your profile" }),
    ).toBeVisible();
    const emailInput = page.getByLabel("New email address", { exact: true });
    const emailSubmit = page.getByRole("button", {
      name: "Send verification",
      exact: true,
    });
    await expect(emailInput).toBeVisible();
    await expect(emailSubmit).toBeVisible();
    for (const control of [emailInput, emailSubmit]) {
      expect(
        await control.evaluate((element) => {
          const rect = element.getBoundingClientRect();
          return rect.left >= 0 && rect.right <= window.innerWidth;
        }),
        `Profile email control should fit at ${width}px`,
      ).toBe(true);
    }
    if (width === 320 || width === 1536) {
      await page.addScriptTag({ path: axePath });
      const violations = await page.evaluate(async () => {
        const result = await window.axe.run(document, {
          runOnly: {
            type: "tag",
            values: ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"],
          },
        });
        return result.violations.map(({ id, impact }) => ({ id, impact }));
      });
      expect(violations, `Account profile at ${width}px`).toEqual([]);
    }
  }

  const accountSections = page.getByRole("navigation", {
    name: "Account sections",
  });
  await accountSections.getByRole("button", { name: "Overview" }).click();
  await page.getByRole("button", { name: "All training" }).click();
  await expect(
    page.getByRole("heading", { name: "Training data" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Open routines" }).click();
  await expect(
    page.getByRole("heading", { name: "My routines" }),
  ).toBeVisible();

  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Back to training" }).click();
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();
  await clickMainNavigation(page, "Account");
  await page
    .getByRole("navigation", { name: "Account sections" })
    .getByRole("button", { name: "Overview", exact: true })
    .click();
  await page.getByRole("button", { name: "Browse routines" }).click();
  await expect(
    page.getByRole("heading", { name: "My routines" }),
  ).toBeVisible();
  await clickMainNavigation(page, "Account");
  await page
    .getByRole("button", { name: "Training data", exact: true })
    .click();
  await page.getByRole("button", { name: "Open history" }).click();
  await expect(
    page.getByRole("heading", { name: "Every session counts." }),
  ).toBeVisible();
});
