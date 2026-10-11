import { test, expect } from "@playwright/test";
import { createRequire } from "node:module";
import { initialData } from "../src/data.js";
const require = createRequire(import.meta.url);
const axePath = require.resolve("axe-core/axe.min.js");
for (const width of [1536, 390])
  test(`accessible pages and dialogs at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 1024 });
    await page.goto("http://localhost:5173");
    const data = structuredClone(initialData);
    data.active = {
      id: "a11y-session",
      routineId: data.routines[0].id,
      name: data.routines[0].name,
      startedAt: Date.now() - 60000,
      notes: "",
      exercises: data.routines[0].exercises.map((e) => ({
        exerciseId: e.exerciseId,
        sets: [{ weight: e.weight, reps: e.reps, done: true }],
      })),
    };
    data.history = [
      {
        ...data.active,
        id: "a11y-history",
        date: new Date().toISOString(),
        duration: 60,
      },
    ];
    await page.evaluate(
      (data) => localStorage.setItem("forma-v1", JSON.stringify(data)),
      data,
    );
    await page.reload();
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    async function audit(label) {
      await page.addScriptTag({ path: axePath });
      const violations = await page.evaluate(async () => {
        const result = await window.axe.run(document, {
          runOnly: {
            type: "tag",
            values: ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"],
          },
        });
        return result.violations.map((v) => ({
          id: v.id,
          impact: v.impact,
          nodes: v.nodes.map((n) => ({
            html: n.html,
            summary: n.failureSummary,
          })),
        }));
      });
      expect.soft(violations, label).toEqual([]);
      expect
        .soft(
          await page.evaluate(
            () => document.documentElement.scrollWidth <= innerWidth,
          ),
          `${label} overflow`,
        )
        .toBe(true);
    }
    for (const route of [
      "overview",
      "routines",
      "library",
      "workout",
      "history",
      "progress",
      "settings",
    ]) {
      await page.goto(`http://localhost:5173/#${route}`);
      await expect(page.locator("main h1")).toBeVisible();
      await audit(route);
      await page.screenshot({
        path: `/workspace/scratch/forma-fixed/${width}-${route}.png`,
        fullPage: true,
      });
      if (route === "routines") {
        await page
          .getByRole("button", { name: "Create routine", exact: true })
          .click();
        await page.locator(".exercise-picker button").first().click();
        await audit("routine editor");
        await page.getByRole("button", { name: "Close dialog" }).click();
        await page.getByRole("button", { name: "Discard changes" }).click();
      }
      if (route === "library") {
        await page.locator(".library-card").first().click();
        await audit("exercise guide");
        await page.getByRole("button", { name: "Got it" }).click();
      }
      if (route === "workout") {
        await page
          .getByRole("button", { name: "Finish workout", exact: true })
          .first()
          .click();
        await audit("finish workout");
        await page.keyboard.press("Escape");
      }
      if (route === "history") {
        await page.locator(".history-row").click();
        await audit("history detail");
        await page.getByRole("button", { name: "Edit workout" }).click();
        await audit("history editor");
        await page.keyboard.press("Escape");
        await page.keyboard.press("Escape");
      }
    }
    expect(errors).toEqual([]);
  });
