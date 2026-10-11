import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";
import { artifactPath, settlePage } from "./helpers.js";
const origin = "http://localhost:5173";
function edgeData() {
  const data = structuredClone(initialData);
  data.profile.name = "Alexandria".repeat(5);
  data.routines[0].name = "Strength".repeat(7) + " day";
  data.routines[0].minutes = 1000;
  data.routines[0].exercises[0] = {
    exerciseId: "bench",
    sets: 12,
    reps: 100,
    weight: 999.5,
  };
  data.active = {
    id: "edge-session",
    routineId: "upper",
    name: data.routines[0].name,
    startedAt: Date.now() - 36000000,
    notes: "Workout notes ".repeat(50),
    restSeconds: 120,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        exerciseId: "bench",
        sets: Array.from({ length: 12 }, () => ({
          weight: 999.5,
          reps: 100,
          done: true,
        })),
      },
    ],
  };
  data.history = Array.from({ length: 8 }, (_, i) => ({
    ...structuredClone(data.active),
    id: `history-${i}`,
    date: new Date(Date.now() - i * 86400000).toISOString(),
    duration: 36000,
    notes: "A".repeat(1000),
  }));
  return data;
}
async function seed(page, data) {
  await page.goto(origin);
  await page.evaluate(
    (data) => localStorage.setItem("forma-v1", JSON.stringify(data)),
    data,
  );
  await page.reload();
}
async function route(page, name) {
  await page.goto(`${origin}/#${name}`);
  await expect(page.locator("main")).toHaveAttribute("data-page", name);
  await settlePage(page);
}
async function fit(page, label) {
  const overflow = await page.evaluate(() => {
    const nodes = [
      document.documentElement,
      ...document.querySelectorAll(
        "main,.modal[open],.panel,.hero,.profile-button,.resume-sidebar,.routine-card,.prescription,.volume-chart,.library-card",
      ),
    ];
    return nodes
      .filter(
        (el) =>
          el.getClientRects().length && el.scrollWidth > el.clientWidth + 2,
      )
      .map((el) => ({
        element: el.className || el.tagName,
        width: el.clientWidth,
        scroll: el.scrollWidth,
      }));
  });
  expect(overflow, label).toEqual([]);
}
for (const width of [320, 390, 540, 768, 1024, 1440, 1920])
  test(`all screens and editing dialogs contain maximum content at ${width}px`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height: 900 });
    await seed(page, edgeData());
    for (const name of [
      "overview",
      "routines",
      "library",
      "workout",
      "history",
      "progress",
      "settings",
    ]) {
      await route(page, name);
      await fit(page, name);
    }
    await route(page, "routines");
    await page.locator(".routine-card").first().click();
    await fit(page, "routine details");
    await page.getByRole("button", { name: "Edit routine" }).click();
    await fit(page, "routine editor");
    const input = page.getByLabel("Barbell bench press weight", {
      exact: true,
    });
    await expect(input).toHaveValue("999.5");
    const metrics = await input.evaluate((el) => ({
      width: el.clientWidth,
      padding:
        parseFloat(getComputedStyle(el).paddingLeft) +
        parseFloat(getComputedStyle(el).paddingRight),
      font: getComputedStyle(el).font,
    }));
    expect(metrics.width - metrics.padding).toBeGreaterThanOrEqual(44);
    await page.keyboard.press("Escape");
    await route(page, "history");
    await page.locator(".history-row").first().click();
    await fit(page, "long history note");
    await page.getByRole("button", { name: "Edit workout" }).click();
    await fit(page, "history editor");
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await route(page, "overview");
    await page.screenshot({
      path: artifactPath(`polished-overview-${width}.png`),
      fullPage: true,
      animations: "disabled",
    });
  });

test("short landscape drawer can reach settings and return focus", async ({
  page,
}) => {
  await page.setViewportSize({ width: 667, height: 375 });
  await page.goto(origin);
  await page.getByLabel("Toggle navigation").click();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await expect(page.locator("main")).toHaveAttribute("data-page", "settings");
  await expect(page.locator(".sidebar")).toHaveAttribute("inert", "");
  await fit(page, "landscape settings");
});

test("routine picker explains no matches and empty overview offers creation", async ({
  page,
}) => {
  const data = structuredClone(initialData);
  data.routines = [];
  await seed(page, data);
  await expect(page.locator(".hero button")).toHaveText("Create routine");
  await page.locator(".hero button").click();
  await page.getByLabel("Search exercises for routine").fill("zzzz");
  await expect(
    page.getByRole("status").filter({ hasText: "No matching exercises" }),
  ).toBeVisible();
});

test("local fonts load without a third-party font service and motion preference is respected", async ({
  page,
}) => {
  const fontRequests = [];
  page.on("request", (request) => {
    if (/fonts\.google/.test(request.url())) fontRequests.push(request.url());
  });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto(origin);
  await settlePage(page);
  expect(fontRequests).toEqual([]);
  expect(
    await page.locator("h1").evaluate((el) => getComputedStyle(el).fontFamily),
  ).toContain("Barlow Condensed");
  expect(
    await page
      .locator(".page-heading")
      .evaluate((el) => getComputedStyle(el).animationName),
  ).toBe("none");
  expect(
    await page.evaluate(() =>
      document.fonts.check('700 48px "Barlow Condensed"'),
    ),
  ).toBe(true);
});

test("history stays chronological after an unordered backup", async ({
  page,
}) => {
  const data = edgeData();
  data.history.reverse();
  await seed(page, data);
  await route(page, "history");
  await page.locator(".history-row").first().click();
  await expect(page.getByRole("dialog")).toContainText(
    new Intl.DateTimeFormat("en-AU", {
      timeZone: "Australia/Sydney",
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
    }).format(new Date(data.history.at(-1).date)),
  );
});

test("imported timestamps with mixed precision sort by time", async ({
  page,
}) => {
  const data = edgeData();
  data.active = null;
  data.history = data.history.slice(0, 2);
  data.history[0].date = "2026-10-11T01:00:00Z";
  data.history[0].routineId = data.routines[0].id;
  data.history[0].name = "Earlier workout";
  data.history[1].date = "2026-10-11T01:00:00.500Z";
  data.history[1].routineId = data.routines[1].id;
  data.history[1].name = "Latest workout";
  data.history[1].exercises[0].sets[0].weight = 100;
  await seed(page, data);
  await expect(page.locator(".hero h2")).toHaveText(data.routines[2].name);
  await route(page, "history");
  await expect(page.locator(".history-row").first()).toContainText(
    "Latest workout",
  );
  await route(page, "progress");
  const bars = await page
    .locator(".volume-bar")
    .evaluateAll((nodes) =>
      nodes.map((node) => node.getBoundingClientRect().height),
    );
  expect(bars[0]).toBeGreaterThan(bars[1]);
});
