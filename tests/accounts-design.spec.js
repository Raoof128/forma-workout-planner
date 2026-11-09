import { createRequire } from "node:module";
import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const require = createRequire(import.meta.url);
const axePath = require.resolve("axe-core/axe.min.js");

async function mockWorkspace(page, waitForWorkspace) {
  const data = { ...structuredClone(initialData), revision: 0 };
  await page.route("**/api/**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path === "/api/auth/get-session")
      return route.fulfill({
        json: {
          user: {
            id: "design-audit-member",
            name: "Design Audit Member",
            email: "design-audit@example.test",
            emailVerified: true,
            createdAt: "2026-10-01T00:00:00Z",
          },
          session: {
            userId: "design-audit-member",
            expiresAt: "2099-01-01T00:00:00Z",
          },
        },
      });
    if (path === "/api/workspace" && route.request().method() === "GET") {
      await waitForWorkspace?.();
      return route.fulfill({
        json: { data, revision: 0, updatedAt: "2026-11-04T09:00:00Z" },
      });
    }
    return route.fulfill({ status: 404, json: { error: "Isolated fixture" } });
  });
}

test("a delayed initial workspace focuses its heading and supports Skip to content", async ({
  page,
}) => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  await mockWorkspace(page, () => gate);
  try {
    await page.goto("/#overview", { waitUntil: "domcontentloaded" });
    await expect(page.locator(".forma-loading-panel")).toBeVisible();
  } finally {
    release();
  }
  const heading = page.locator("main h1");
  await expect(heading).toBeFocused();
  await page.getByRole("link", { name: "Skip to content" }).focus();
  await page.keyboard.press("Enter");
  await expect(heading).toBeFocused();
  await expect(page.locator(".dashboard-footnote")).toContainText(
    "Saved to your account.",
  );
});

test("a delayed workspace keeps a control the member already focused reachable", async ({
  page,
}) => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  await mockWorkspace(page, () => gate);
  try {
    await page.goto("/#overview", { waitUntil: "domcontentloaded" });
    await expect(page.locator(".forma-loading-panel")).toBeVisible();
    await page.evaluate(() => {
      const control = document.createElement("input");
      control.id = "member-focus-fixture";
      control.setAttribute("aria-label", "Focused audit control");
      document.body.prepend(control);
      control.focus();
    });
  } finally {
    release();
  }
  await expect(page.locator("main h1")).toHaveAttribute("tabindex", "-1");
  await expect(page.getByLabel("Focused audit control")).toBeFocused();
  await page.getByRole("link", { name: "Skip to content" }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("main h1")).toBeFocused();
});

test("account details retain contrast and phone-sized input text", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockWorkspace(page);
  await page.goto("/#account");
  await expect(page.locator(".account-summary-card").first()).toBeVisible();
  await page.evaluate(() => document.fonts.ready);
  await page.addScriptTag({ path: axePath });
  const violations = await page.evaluate(async () => {
    const result = await window.axe.run(
      document.querySelector(".account-summary-grid"),
      { runOnly: { type: "rule", values: ["color-contrast"] } },
    );
    return result.violations.map((violation) => violation.id);
  });
  expect(violations).toEqual([]);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  await expect(page.getByLabel("Display name", { exact: true })).toHaveCSS(
    "font-size",
    "16px",
  );
  await expect(page.getByLabel("New email address", { exact: true })).toHaveCSS(
    "font-size",
    "16px",
  );
});

test("tablet account navigation leaves the settings panel its full width", async ({
  page,
}) => {
  await page.setViewportSize({ width: 768, height: 900 });
  await mockWorkspace(page);
  await page.goto("/#account");
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  const bounds = await page.evaluate(() => {
    const nav = document.querySelector(".account-nav").getBoundingClientRect();
    const content = document
      .querySelector(".account-content")
      .getBoundingClientRect();
    return {
      navBottom: nav.bottom,
      contentTop: content.top,
      width: content.width,
    };
  });
  expect(bounds.navBottom).toBeLessThanOrEqual(bounds.contentTop);
  expect(bounds.width).toBeGreaterThan(420);
});

test("the mobile member drawer keeps nested menu Tab navigation within its controls", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await mockWorkspace(page);
  await page.goto("/#overview");
  const toggle = page.getByLabel("Toggle navigation");
  await toggle.click();
  const sidebar = page.locator(".sidebar");
  const trigger = sidebar.getByRole("button", { name: /^Account menu:/ });
  const menu = sidebar.getByRole("menu", { name: "Account menu" });
  await trigger.click();
  await expect(menu.getByRole("menuitem").first()).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(menu).toHaveCount(0);
  await expect(
    sidebar.getByRole("link", { name: "Privacy", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(trigger).toBeFocused();
  await trigger.press("ArrowDown");
  await expect(menu.getByRole("menuitem").first()).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(menu).toHaveCount(0);
  await expect(
    sidebar.getByRole("button", { name: "Settings", exact: true }),
  ).toBeFocused();
  await toggle.focus();
  await page.keyboard.press("Shift+Tab");
  await expect(
    sidebar.getByRole("link", { name: "Terms", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(toggle).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(toggle).toBeFocused();
});

test("narrow account security keeps coach access choices and actions reachable", async ({
  page,
}) => {
  await mockWorkspace(page);
  await page.route(/\/api\/account\/(sessions|coach-tokens)$/, (route) =>
    route.fulfill({ json: [] }),
  );
  await page.goto("/#account");
  await page.getByRole("button", { name: "Security", exact: true }).click();
  const form = page.locator(".account-coach-form");
  await expect(form).toBeVisible();
  await page.evaluate(() => document.fonts.ready);

  for (const width of [320, 360, 375]) {
    await page.setViewportSize({ width, height: 1000 });
    const documentWidth = await page.evaluate(() =>
      Math.max(document.documentElement.scrollWidth, document.body.scrollWidth),
    );
    expect(
      documentWidth,
      `Security document at ${width}px`,
    ).toBeLessThanOrEqual(width + 1);

    const name = form.getByLabel("Token name", { exact: true });
    const readOnly = form.getByRole("radio", {
      name: "Read only",
      exact: true,
    });
    const fullAccess = form.getByRole("radio", {
      name: "Full access: read and edit",
      exact: true,
    });
    await fullAccess.check();
    await expect(fullAccess).toBeChecked();
    await readOnly.check();
    await expect(readOnly).toBeChecked();

    for (const control of [
      name,
      readOnly,
      fullAccess,
      form.getByRole("button", { name: "Create read-only token", exact: true }),
    ]) {
      await control.scrollIntoViewIfNeeded();
      const geometry = await control.evaluate((node) => {
        const bounds = node.getBoundingClientRect();
        const panel = node
          .closest(".account-settings-form")
          .getBoundingClientRect();
        const target = document.elementFromPoint(
          bounds.left + bounds.width / 2,
          bounds.top + bounds.height / 2,
        );
        return {
          left: bounds.left,
          right: bounds.right,
          panelLeft: panel.left,
          panelRight: panel.right,
          viewport: innerWidth,
          hit: !!target && (target === node || node.contains(target)),
        };
      });
      expect(geometry.left).toBeGreaterThanOrEqual(geometry.panelLeft);
      expect(geometry.right).toBeLessThanOrEqual(geometry.panelRight);
      expect(geometry.left).toBeGreaterThanOrEqual(0);
      expect(geometry.right).toBeLessThanOrEqual(geometry.viewport);
      expect(geometry.hit).toBe(true);
    }
  }
});

test("tablet authentication keeps every form inside its visible panel", async ({
  page,
}) => {
  await mockWorkspace(page);
  await page.route("**/api/auth/get-session", (route) =>
    route.fulfill({ json: null }),
  );
  for (const width of [768, 820, 960]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("/#account");
    for (const mode of [
      "Welcome back",
      "Create your account",
      "Reset your password",
    ]) {
      if (mode === "Create your account")
        await page
          .getByRole("button", {
            name: "New to FORMA? Create account",
            exact: true,
          })
          .click();
      if (mode === "Reset your password") {
        await page
          .getByRole("button", {
            name: "Already have an account? Sign in",
            exact: true,
          })
          .click();
        await page
          .getByRole("button", { name: "Forgot password?", exact: true })
          .click();
      }
      await expect(
        page.getByRole("heading", { name: mode, exact: true }),
      ).toBeVisible();
      await page.evaluate(() => document.fonts.ready);
      const geometry = await page
        .locator(".account-auth-layout")
        .evaluate((panel) => {
          const bounds = panel.getBoundingClientRect();
          return {
            clientWidth: panel.clientWidth,
            scrollWidth: panel.scrollWidth,
            clipped: [
              ...panel.querySelectorAll(
                ".account-auth-card, .account-auth-aside, input, button, a",
              ),
            ]
              .filter((node) => node.getBoundingClientRect().width > 0)
              .filter((node) => {
                const box = node.getBoundingClientRect();
                return (
                  box.left < bounds.left - 1 || box.right > bounds.right + 1
                );
              })
              .map(
                (node) =>
                  node.tagName +
                  ": " +
                  (node.getAttribute("aria-label") || node.textContent.trim()),
              ),
          };
        });
      expect(geometry.scrollWidth, `${mode} at ${width}px`).toBeLessThanOrEqual(
        geometry.clientWidth + 1,
      );
      expect(geometry.clipped, `${mode} at ${width}px`).toEqual([]);
    }
    await page
      .getByRole("button", { name: "Back to sign in", exact: true })
      .click();
  }
});

test("narrow authentication keeps the complete supporting copy clear of its emblem", async ({
  page,
}) => {
  const unexpectedRequests = [];
  await page.route("**/api/**", (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname;
    if (path === "/api/auth/get-session" && request.method() === "GET")
      return route.fulfill({ json: null });
    unexpectedRequests.push(`${request.method()} ${path}`);
    return route.fulfill({ status: 404, json: { error: "Isolated fixture" } });
  });
  await page.goto("/#account");
  await page
    .getByRole("button", {
      name: "New to FORMA? Create account",
      exact: true,
    })
    .click();
  await expect(
    page.getByRole("heading", { name: "Create your account", exact: true }),
  ).toBeVisible();
  const copy = page.locator(".account-auth-aside p");
  await expect(copy).toHaveText(
    "Your routines and training history stay with your account, ready wherever you train.",
  );
  await page.evaluate(() => document.fonts.ready);

  for (const width of [320, 360, 375, 390, 430, 540]) {
    await page.setViewportSize({ width, height: 1000 });
    const geometry = await copy.evaluate((paragraph) => {
      const style = getComputedStyle(paragraph);
      const range = document.createRange();
      range.selectNodeContents(paragraph);
      const lines = [...range.getClientRects()].filter(
        (box) => box.width > 0 && box.height > 0,
      );
      const aside = paragraph.closest(".account-auth-aside");
      const bounds = aside.getBoundingClientRect();
      const emblem = aside
        .querySelector(".account-auth-emblem")
        .getBoundingClientRect();
      const clippedControls = [
        ...document.querySelectorAll(
          ".account-auth-card input, .account-auth-card button, .account-auth-card a",
        ),
      ].filter((node) => {
        const box = node.getBoundingClientRect();
        return box.width > 0 && (box.left < 0 || box.right > innerWidth);
      });
      return {
        fontLoaded: document.fonts.check(
          `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`,
        ),
        lineCount: lines.length,
        overlaps: lines.filter(
          (box) =>
            box.left < emblem.right &&
            box.right > emblem.left &&
            box.top < emblem.bottom &&
            box.bottom > emblem.top,
        ).length,
        clippedLines: lines.filter(
          (box) =>
            box.left < bounds.left ||
            box.right > bounds.right ||
            box.top < bounds.top ||
            box.bottom > bounds.bottom ||
            box.left < 0 ||
            box.right > innerWidth,
        ).length,
        clippedControls: clippedControls.length,
        documentWidth: Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth,
        ),
      };
    });
    expect(geometry.fontLoaded, `loaded font at ${width}px`).toBe(true);
    expect(geometry.lineCount, `supporting copy at ${width}px`).toBeGreaterThan(
      0,
    );
    expect(geometry.overlaps, `copy/emblem intersections at ${width}px`).toBe(
      0,
    );
    expect(geometry.clippedLines, `copy containment at ${width}px`).toBe(0);
    expect(geometry.clippedControls, `auth controls at ${width}px`).toBe(0);
    expect(
      geometry.documentWidth,
      `document at ${width}px`,
    ).toBeLessThanOrEqual(width + 1);
    await expect(page.locator(".account-auth-aside h2")).toBeVisible();
    await expect(page.locator(".account-auth-emblem")).toBeVisible();
  }
  expect(unexpectedRequests).toEqual([]);
});
