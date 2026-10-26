import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

test.use({ timezoneId: "America/Los_Angeles", locale: "en-US" });

async function openAccount(page) {
  await page.clock.setFixedTime(new Date("2026-10-25T13:30:00Z"));
  const data = {
    ...structuredClone(initialData),
    revision: 0,
    history: ["2026-10-25T01:00:00Z", "2026-10-25T13:10:00Z"].map(
      (date, index) => ({
        id: `sydney-${index}`,
        name: `Sydney workout ${index}`,
        date,
        startedAt: Date.parse(date) - 60_000,
        duration: 60,
        exercises: [
          { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: true }] },
        ],
      }),
    ),
  };
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path.endsWith("/auth/get-session"))
      return route.fulfill({
        json: {
          user: {
            id: "audit-member",
            name: "Audit Member",
            email: "audit@example.test",
            emailVerified: true,
            createdAt: "2026-10-25T13:00:00Z",
          },
          session: {
            id: "audit-session",
            userId: "audit-member",
            expiresAt: "2026-11-25T00:00:00Z",
          },
        },
      });
    if (path === "/api/workspace")
      return route.fulfill({
        json: { data, revision: 0, updatedAt: "2026-10-25T13:15:00Z" },
      });
    return route.fulfill({
      status: 404,
      json: { error: "Unexpected audit test request" },
    });
  });
  await page.goto("/#account");
  await expect(
    page.getByRole("heading", { name: "Good work, Guest.", exact: true }),
  ).toBeVisible();
}

test("account weeks and dates follow Sydney across a device week boundary", async ({
  page,
}) => {
  await openAccount(page);
  await expect(
    page
      .locator(".account-summary-card")
      .filter({ hasText: "This week" })
      .locator("strong"),
  ).toHaveText("1 / 4");
  await expect(page.locator(".account-page")).toContainText("October 26, 2026");
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  await expect(
    page.getByText("Weights use kg. Dates use Sydney time."),
  ).toBeVisible();
});

async function delayFiles(page) {
  await page.addInitScript(() => {
    const original = File.prototype.text;
    window.finishFileReads = {};
    File.prototype.text = function () {
      if (!this.name.startsWith("slow")) return original.call(this);
      return new Promise((resolve, reject) => {
        window.finishFileReads[this.name] = () =>
          original.call(this).then(resolve, reject);
      });
    };
  });
}
const backup = (name, data = initialData) => ({
  name,
  mimeType: "application/json",
  buffer: Buffer.from(JSON.stringify(data)),
});

test("new backup selection clears review and stale reads cannot replace or restore it", async ({
  page,
}) => {
  await delayFiles(page);
  await openAccount(page);
  await page
    .getByRole("button", { name: "Training data", exact: true })
    .click();
  const input = page.getByLabel("Import workout backup");
  const review = page.locator(".account-import-review");
  await input.setInputFiles(backup("first.json"));
  await expect(review).toContainText("first.json");
  await input.setInputFiles(backup("slow-old.json"));
  await expect(review).toHaveCount(0);
  await input.setInputFiles(backup("latest.json"));
  await expect(review).toContainText("latest.json");
  await page.evaluate(() => window.finishFileReads["slow-old.json"]());
  await expect(review).toContainText("latest.json");

  await input.setInputFiles(backup("slow-cancelled.json"));
  await input.setInputFiles(backup("cancel-me.json"));
  await expect(review).toContainText("cancel-me.json");
  await review.getByRole("button", { name: "Cancel", exact: true }).click();
  await page.evaluate(() => window.finishFileReads["slow-cancelled.json"]());
  await expect(review).toHaveCount(0);
});

test("an obsolete backup error cannot overwrite a later valid review", async ({
  page,
}) => {
  await delayFiles(page);
  await openAccount(page);
  await page
    .getByRole("button", { name: "Training data", exact: true })
    .click();
  const input = page.getByLabel("Import workout backup");
  await input.setInputFiles(backup("slow-invalid.json", {}));
  await input.setInputFiles(backup("valid.json"));
  await expect(page.locator(".account-import-review")).toContainText(
    "valid.json",
  );
  await page.evaluate(() => window.finishFileReads["slow-invalid.json"]());
  await expect(page.locator(".account-import-review")).toContainText(
    "valid.json",
  );
  await expect(page.getByRole("alert")).toHaveCount(0);
});

test("privacy exports report failure and failed sign-out still hides private data", async ({
  page,
}) => {
  await openAccount(page);
  await page.getByRole("button", { name: "Privacy", exact: true }).click();
  await page
    .getByRole("button", { name: "Export my data", exact: true })
    .click();
  await expect(page.getByRole("alert")).toBeVisible();
  await page.route("**/api/auth/sign-out", (route) =>
    route.fulfill({ status: 503, json: { message: "Could not sign out." } }),
  );
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText(
    "Your private workspace is hidden until the connection is restored.",
  );
  await expect(page.locator(".account-page")).toHaveCount(0);
});
