import { expect, test } from "@playwright/test";

function monitorBrowser(page) {
  const problems = [];
  const allowedOrigin = new URL(test.info().project.use.baseURL).origin;
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (
      (url.protocol === "http:" || url.protocol === "https:") &&
      url.origin !== allowedOrigin
    ) {
      problems.push(`unexpected external request: ${request.url()}`);
    }
  });
  page.on("pageerror", (error) =>
    problems.push(`page error: ${error.message}`),
  );
  page.on("console", (message) => {
    if (message.type() === "error")
      problems.push(`console error: ${message.text()}`);
  });
  page.on("requestfailed", (request) => {
    const failure = request.failure()?.errorText || "unknown request failure";
    problems.push(`request failed: ${request.url()} (${failure})`);
  });
  page.on("response", (response) => {
    if (response.status() >= 400) {
      problems.push(`HTTP ${response.status()}: ${response.url()}`);
    }
  });
  return problems;
}

async function openSettings(page) {
  if (test.info().project.name.includes("mobile")) {
    await page.getByRole("button", { name: "Toggle navigation" }).click();
  }
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Your space. Your preferences." }),
  ).toBeVisible();
}

async function openPageNavigation(page, name) {
  if (test.info().project.name.includes("mobile")) {
    await page.getByRole("button", { name: "Toggle navigation" }).click();
  }
  await page.getByRole("button", { name, exact: true }).click();
}

test("production settings, backup restore, and saved data survive reload", async ({
  page,
}) => {
  const problems = monitorBrowser(page);
  const response = await page.goto("/");
  expect(response?.ok()).toBe(true);
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();
  await page.evaluate(() => document.fonts.ready);
  expect(
    await page.evaluate(() => document.fonts.status),
    "production fonts should finish loading",
  ).toBe("loaded");

  await openSettings(page);
  await page.getByLabel("Your name").fill("Production smoke");
  await page.getByRole("button", { name: "Save preferences" }).click();
  await expect(page.locator(".profile-button")).toContainText(
    "Production smoke",
  );
  await page.reload();
  await expect(page.locator(".profile-button")).toContainText(
    "Production smoke",
  );
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1"))?.profile.name,
    ),
  ).toBe("Production smoke");

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export my data" }).click();
  const backup = await downloadPromise;
  expect(backup.suggestedFilename()).toContain("forma-backup");
  const backupPath = await backup.path();

  await page.getByLabel("Your name").fill("Changed after backup");
  await page.getByRole("button", { name: "Save preferences" }).click();
  await expect(page.locator(".profile-button")).toContainText(
    "Changed after backup",
  );
  await page
    .getByLabel("Import backup", { exact: true })
    .setInputFiles(backupPath);
  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();
  await expect(page.locator(".profile-button")).toContainText(
    "Production smoke",
  );
  await page.reload();
  await expect(page.locator(".profile-button")).toContainText(
    "Production smoke",
  );
  expect(problems).toEqual([]);
});

test("production navigation works and the layout fits desktop and mobile viewports", async ({
  page,
}) => {
  const problems = monitorBrowser(page);
  const response = await page.goto("/");
  expect(response?.ok()).toBe(true);
  await expect(
    page.getByRole("heading", { name: "A little stronger, every day." }),
  ).toBeVisible();

  if (test.info().project.name.includes("mobile")) {
    await expect(
      page.getByRole("button", { name: "Toggle navigation" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Toggle navigation" }).click();
  }
  await page.getByRole("button", { name: "My routines", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Make every session yours." }),
  ).toBeVisible();
  await expect(page).toHaveURL(/#routines$/);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
    "production layout should not overflow its viewport",
  ).toBe(true);
  expect(problems).toEqual([]);
});

test("production workout can be completed, saved, and restored after reload", async ({
  page,
}) => {
  const problems = monitorBrowser(page);
  const response = await page.goto("/");
  expect(response?.ok()).toBe(true);
  await openPageNavigation(page, "My routines");
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();

  const completionButton = page
    .getByRole("button", {
      name: /^Complete .+ set 1$/,
    })
    .first();
  await expect(completionButton).toBeEnabled();
  await completionButton.click();
  await expect(page.locator(".set-done")).toHaveCount(1);
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await page.getByRole("button", { name: "Save workout", exact: true }).click();

  await expect(page.locator(".history-row")).toHaveCount(1);
  expect(
    await page.evaluate(() => {
      const data = JSON.parse(localStorage.getItem("forma-v1"));
      return { history: data.history.length, active: data.active };
    }),
  ).toEqual({ history: 1, active: null });
  await page.reload();
  await expect(page.locator(".history-row")).toHaveCount(1);
  expect(
    await page.evaluate(
      () => JSON.parse(localStorage.getItem("forma-v1")).history,
    ),
  ).toHaveLength(1);
  expect(problems).toEqual([]);
});

test("production writes from concurrent tabs preserve profile and active workout", async ({
  page,
  context,
}) => {
  const problems = monitorBrowser(page);
  const response = await page.goto("/");
  expect(response?.ok()).toBe(true);
  await openPageNavigation(page, "My routines");
  await page.locator(".routine-card").first().click();
  await page
    .getByRole("button", { name: "Start workout", exact: true })
    .click();

  const other = await context.newPage();
  const otherProblems = monitorBrowser(other);
  await other.goto("/#settings");
  await other.getByLabel("Your name").fill("Production concurrent");
  await Promise.all([
    page.getByLabel("Session notes").fill("Persisted across production tabs"),
    other.getByRole("button", { name: "Save preferences" }).click(),
  ]);

  await expect
    .poll(async () =>
      page.evaluate(() => {
        const data = JSON.parse(localStorage.getItem("forma-v1"));
        return {
          profile: data.profile.name,
          notes: data.active?.notes,
        };
      }),
    )
    .toEqual({
      profile: "Production concurrent",
      notes: "Persisted across production tabs",
    });
  expect(problems).toEqual([]);
  expect(otherProblems).toEqual([]);
});
