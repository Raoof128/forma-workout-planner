import { artifactPath } from "./helpers.js";
import { test, expect } from "@playwright/test";
import { initialData, dateKey, weekDates } from "../src/data.js";
import { readFileSync } from "node:fs";
const origin = "http://localhost:5173";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });
function session(routine = initialData.routines[0], id = "test-session") {
  return {
    id,
    routineId: routine.id,
    name: routine.name,
    startedAt: Date.now() - 60000,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: routine.exercises.map((e) => ({
      exerciseId: e.exerciseId,
      sets: Array.from({ length: e.sets }, () => ({
        weight: e.weight,
        reps: e.reps,
        done: false,
      })),
    })),
  };
}
async function seed(page, data, hash = "overview") {
  await page.goto(origin);
  await page.evaluate(
    (data) =>
      localStorage.setItem(
        "forma-v1",
        typeof data === "string" ? data : JSON.stringify(data),
      ),
    data,
  );
  await page.goto(`${origin}/#${hash}`);
  await page.reload();
}
async function stored(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
}
async function nav(page, name) {
  await page.getByRole("button", { name, exact: true }).click();
}
async function editFirst(page) {
  await nav(page, "My routines");
  await page.locator(".routine-card").first().click();
  await nav(page, "Edit routine");
}

test("concurrent tabs preserve independent edits and merge session fields", async ({
  page,
  context,
}) => {
  const data = snapshot();
  data.active = session();
  await seed(page, data, "workout");
  const other = await context.newPage();
  await other.goto(`${origin}/#settings`);
  await other.getByLabel("Your name").fill("Second tab");
  await Promise.all([
    page.getByLabel("Session notes").fill("First tab notes"),
    nav(other, "Save preferences"),
  ]);
  await expect
    .poll(async () => (await stored(page)).active.notes)
    .toBe("First tab notes");
  await expect
    .poll(async () => (await stored(page)).profile.name)
    .toBe("Second tab");
  await other.goto(`${origin}/#workout`);
  await Promise.all([
    page
      .getByLabel("Barbell bench press set 1 weight", { exact: true })
      .fill("77"),
    other
      .getByLabel("Barbell bench press set 2 reps", { exact: true })
      .fill("7"),
  ]);
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[0].weight)
    .toBe(77);
  await expect
    .poll(async () => (await stored(page)).active.exercises[0].sets[1].reps)
    .toBe(7);
});

test("stale routine drafts cannot overwrite newer tab changes", async ({
  page,
  context,
}) => {
  await seed(page, snapshot());
  await editFirst(page);
  await page.getByLabel("Routine name").fill("Stale draft");
  const other = await context.newPage();
  await other.goto(origin);
  await editFirst(other);
  await other.getByLabel("Routine name").fill("Latest name");
  await nav(other, "Save routine");
  await expect(other.getByRole("dialog")).toHaveCount(0);
  await nav(page, "Save routine");
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(
    page.getByRole("status").filter({ hasText: "changed in another tab" }),
  ).toBeVisible();
  expect((await stored(page)).routines[0].name).toBe("Latest name");
});

for (const kind of ["invalid JSON", "invalid nested shape", "unknown exercise"])
  test(`${kind} is preserved and recoverable`, async ({ page }) => {
    const data = snapshot();
    if (kind === "invalid nested shape") data.profile = null;
    if (kind === "unknown exercise")
      data.routines[0].exercises[0].exerciseId = "missing";
    const raw = kind === "invalid JSON" ? "{broken" : JSON.stringify(data);
    await seed(page, raw);
    await expect(
      page.getByRole("heading", { name: "Your saved data needs attention." }),
    ).toBeVisible();
    expect(await page.evaluate(() => localStorage.getItem("forma-v1"))).toBe(
      raw,
    );
    const downloadPromise = page.waitForEvent("download");
    await nav(page, "Download original data");
    const file = await downloadPromise;
    expect(readFileSync(await file.path(), "utf8")).toBe(raw);
    await nav(page, "Start a fresh workspace");
    await nav(page, "Start fresh");
    await expect(page.locator(".hero")).toBeVisible();
    expect(
      await page.evaluate(
        (raw) =>
          Object.keys(localStorage).some(
            (key) =>
              key.startsWith("forma-v1-recovery-") &&
              localStorage.getItem(key) === raw,
          ),
        raw,
      ),
    ).toBe(true);
  });

test("denied storage stays usable and accurately reports temporary data", async ({
  page,
}) => {
  await page.addInitScript(() => {
    Storage.prototype.setItem = function () {
      throw new DOMException("Blocked", "SecurityError");
    };
  });
  await page.goto(origin);
  await expect(page.getByRole("alert")).toContainText("saving is unavailable");
  await page.locator(".hero button").click();
  await page.getByLabel("Session notes").fill("Temporary notes");
  await nav(page, "Overview");
  await expect(page.locator(".dashboard-footnote")).toContainText(
    "Changes are temporary",
  );
  await page.locator(".hero button").click();
  await expect(page.getByLabel("Session notes")).toHaveValue("Temporary notes");
  await nav(page, "Settings");
  const downloadPromise = page.waitForEvent("download");
  await nav(page, "Export my data");
  const file = await downloadPromise;
  expect(JSON.parse(readFileSync(await file.path(), "utf8")).active.notes).toBe(
    "Temporary notes",
  );
});

test("rest duration, running deadline and paused state survive routes and reload", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session();
  await seed(page, data, "workout");
  await nav(page, "120s");
  await expect(
    page.getByRole("button", { name: "120s", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  const end = (await stored(page)).active.restEnd;
  await nav(page, "Overview");
  await page.locator(".hero button").click();
  expect((await stored(page)).active.restEnd).toBe(end);
  await page.reload();
  await expect(page.locator(".timer-value")).not.toHaveText("00:00");
  expect((await stored(page)).active.restEnd).toBe(end);
  await nav(page, "Pause rest timer");
  await expect.poll(async () => (await stored(page)).active.restEnd).toBeNull();
  const paused = (await stored(page)).active.restPaused;
  await page.reload();
  expect((await stored(page)).active.restPaused).toBe(paused);
  await nav(page, "Skip");
  await nav(page, "Complete Barbell bench press set 1");
  await expect
    .poll(async () => (await stored(page)).active.restEnd - Date.now())
    .toBeGreaterThan(115000);
});

test("finish dialog traps keyboard focus and does not reset it on timer ticks", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session();
  data.active.exercises[0].sets[0].done = true;
  await seed(page, data, "workout");
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await expect(page.getByLabel("Close dialog")).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(
    page.getByRole("button", { name: "Save workout", exact: true }),
  ).toBeFocused();
  await page.waitForTimeout(1300);
  await expect(
    page.getByRole("button", { name: "Save workout", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(page.getByLabel("Close dialog")).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Finish workout", exact: true }).first(),
  ).toBeFocused();
});

test("mobile drawer keeps hidden controls out of tab order and traps open navigation", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(origin);
  await expect(page.locator(".sidebar")).toHaveAttribute("inert", "");
  for (let i = 0; i < 15; i++) {
    await page.keyboard.press("Tab");
    expect(
      await page.evaluate(() => !!document.activeElement.closest(".sidebar")),
    ).toBe(false);
  }
  const toggle = page.getByLabel("Toggle navigation");
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  for (let i = 0; i < 20; i++) {
    await page.keyboard.press("Tab");
    expect(
      await page.evaluate(
        () =>
          !!document.activeElement.closest(".sidebar") ||
          document.activeElement.getAttribute("aria-label") ===
            "Toggle navigation",
      ),
    ).toBe(true);
  }
  await page.keyboard.press("Escape");
  await expect(toggle).toBeFocused();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator("main")).not.toHaveAttribute("inert");
});

test("dirty routine changes are retained and duration and prescriptions are preserved", async ({
  page,
}) => {
  await seed(page, snapshot());
  await editFirst(page);
  const minutes = await page
    .getByLabel("Estimated duration (minutes)")
    .inputValue();
  await page.getByLabel("Routine name").fill("Renamed workout");
  await page
    .getByLabel("Barbell bench press weight", { exact: true })
    .fill("72.5");
  await page.keyboard.press("Escape");
  await expect(
    page.getByRole("heading", { name: "Discard unsaved changes?" }),
  ).toBeVisible();
  await nav(page, "Keep editing");
  await expect(page.getByLabel("Routine name")).toHaveValue("Renamed workout");
  const pick = page
    .locator(".exercise-picker button")
    .filter({ hasText: "Barbell bench press" });
  await pick.click();
  await pick.click();
  await expect(
    page.getByLabel("Barbell bench press weight", { exact: true }),
  ).toHaveValue("72.5");
  await page.getByLabel("Move Barbell bench press up", { exact: true }).click();
  await nav(page, "Save routine");
  await expect(page.getByRole("dialog")).toHaveCount(0);
  const routine = (await stored(page)).routines[0];
  expect(routine.minutes).toBe(Number(minutes));
  expect(routine.exercises.find((e) => e.exerciseId === "bench").weight).toBe(
    72.5,
  );
});

test("hero names the active routine and starting another asks which session to keep", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session(data.routines[1]);
  await seed(page, data);
  await expect(page.locator(".hero h2")).toHaveText(data.active.name);
  await page.locator(".routine-card").first().click();
  await nav(page, "Start workout");
  await expect(page.getByRole("dialog")).toContainText(
    "already have a workout running",
  );
  expect((await stored(page)).active.name).toBe(data.active.name);
  await nav(page, "Resume existing");
  await expect(page.locator("h1")).toHaveText(data.active.name);
});

test("maximum length title keeps its start button inside the hero", async ({
  page,
}) => {
  const data = snapshot();
  data.routines[0].name = "A".repeat(60);
  await seed(page, data);
  for (const width of [1536, 1024, 768, 390, 320]) {
    await page.setViewportSize({ width, height: 900 });
    const hero = await page.locator(".hero").boundingBox(),
      button = await page.locator(".hero button").boundingBox();
    expect(button.y + button.height).toBeLessThanOrEqual(hero.y + hero.height);
    expect(button.x + button.width).toBeLessThanOrEqual(hero.x + hero.width);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
  }
});

test("weekly bars use actual counts and eight progress bars fit 320px", async ({
  page,
}) => {
  const data = snapshot();
  const monday = weekDates()[0];
  data.history = Array.from({ length: 8 }, (_, i) => {
    const value = session(undefined, `session-${i}`);
    value.exercises[0].sets[0].done = true;
    return {
      ...value,
      date: i
        ? new Date(monday.getTime() - i * 86400000).toISOString()
        : monday.toISOString(),
      duration: 60,
    };
  });
  await seed(page, data);
  const bars = await page
    .locator(".week-chart .bar")
    .evaluateAll((nodes) => nodes.map((n) => n.getBoundingClientRect().height));
  expect(bars[0]).toBeGreaterThan(0);
  expect(bars.slice(1)).toEqual([0, 0, 0, 0, 0, 0]);
  await nav(page, "Progress");
  await page.setViewportSize({ width: 320, height: 844 });
  const panel = await page.locator(".progress-chart").boundingBox();
  const last = await page.locator(".volume-chart > div").last().boundingBox();
  expect(last.x + last.width).toBeLessThanOrEqual(panel.x + panel.width);
  expect(
    await page
      .locator(".volume-chart")
      .evaluate((el) => el.scrollWidth <= el.clientWidth),
  ).toBe(true);
});

test("backup validation and export/import round trip preserve data", async ({
  page,
}) => {
  const data = snapshot();
  data.profile.name = "Backup person";
  await seed(page, data, "settings");
  const downloadPromise = page.waitForEvent("download");
  await nav(page, "Export my data");
  const file = await downloadPromise;
  const path = await file.path();
  await page.getByLabel("Your name").fill("Changed");
  await nav(page, "Save preferences");
  await expect(page.locator(".profile-button")).toContainText("Changed");
  await page.getByLabel("Import backup", { exact: true }).setInputFiles({
    name: "bad.json",
    mimeType: "application/json",
    buffer: Buffer.from("{broken"),
  });
  await expect(page.getByRole("alert")).toContainText(
    "Nothing has been changed",
  );
  expect((await stored(page)).profile.name).toBe("Changed");
  await page.getByLabel("Import backup", { exact: true }).setInputFiles(path);
  await nav(page, "Restore backup");
  await expect(page.locator(".profile-button")).toContainText("Backup person");
  expect(
    await page.evaluate(
      () =>
        Object.keys(localStorage).filter((k) =>
          k.startsWith("forma-v1-recovery-"),
        ).length,
    ),
  ).toBe(1);
});

test("history correction and deletion recalculate progress; one rep uses actual load", async ({
  page,
}) => {
  const data = snapshot();
  const value = session();
  value.exercises[0].sets[0] = { weight: 100, reps: 1, done: true };
  data.history = [{ ...value, date: new Date().toISOString(), duration: 60 }];
  await seed(page, data, "progress");
  await expect(page.locator(".record-row").last()).toContainText("100 kg");
  await expect(page.locator(".records")).not.toContainText("103.3");
  await nav(page, "Workout history");
  await page.locator(".history-row").click();
  await nav(page, "Edit workout");
  await page.getByLabel("Correct Barbell bench press set 1 weight").fill("80");
  await page.getByLabel("Correct Barbell bench press set 1 reps").fill("5");
  await nav(page, "Save corrections");
  await expect(
    page.getByRole("heading", { name: "Workout complete" }),
  ).toBeVisible();
  await nav(page, "Close dialog");
  await nav(page, "Progress");
  await expect(page.locator(".progress-stats")).toContainText("400");
  await expect(page.locator(".records")).toContainText("93.3 kg");
  await nav(page, "Workout history");
  await page.locator(".history-row").click();
  await nav(page, "Delete workout");
  await nav(page, "Delete workout");
  await expect(page.locator(".history-row")).toHaveCount(0);
  expect((await stored(page)).history).toHaveLength(0);
});

test("hash navigation supports bookmarks and browser Back", async ({
  page,
}) => {
  await page.goto(`${origin}/#library`);
  await expect(page.locator("h1")).toHaveText("Good form. Better sessions.");
  await nav(page, "Progress");
  await page.goBack();
  await expect(page.locator("h1")).toHaveText("Good form. Better sessions.");
  await page.reload();
  await expect(page.locator("h1")).toHaveText("Good form. Better sessions.");
  expect(dateKey(new Date("2026-10-11T14:00:00Z"))).toBe("2026-10-12");
});

test("finishing in one tab and updating preferences in another preserves both saves", async ({
  page,
  context,
}) => {
  const data = snapshot();
  data.active = session();
  data.active.exercises[0].sets[0].done = true;
  await seed(page, data, "workout");
  const other = await context.newPage();
  await other.goto(`${origin}/#settings`);
  await other.getByLabel("Your name").fill("Concurrent finish");
  await page
    .getByRole("button", { name: "Finish workout", exact: true })
    .first()
    .click();
  await Promise.all([
    nav(page, "Save workout"),
    nav(other, "Save preferences"),
  ]);
  await expect.poll(async () => (await stored(page)).history.length).toBe(1);
  await expect
    .poll(async () => (await stored(page)).profile.name)
    .toBe("Concurrent finish");
  expect((await stored(page)).active).toBeNull();
});

test("mobile rest controls stay reachable and expose instructions during logging", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session();
  await page.setViewportSize({ width: 320, height: 844 });
  await seed(page, data, "workout");
  await expect(page.getByLabel("Open rest timer")).toBeVisible();
  await nav(page, "Open rest timer");
  await nav(page, "120s");
  await page.keyboard.press("Escape");
  await nav(page, "Complete Barbell bench press set 1");
  await expect(page.locator(".mobile-rest-bar")).toContainText("01:");
  await page.locator(".log-exercise").last().scrollIntoViewIfNeeded();
  const bar = await page.locator(".mobile-rest-bar").boundingBox();
  expect(bar.y).toBeGreaterThanOrEqual(65);
  expect(bar.y + bar.height).toBeLessThan(844);
  await nav(page, "Open rest timer");
  await expect(
    page.getByRole("button", { name: "120s", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await page.keyboard.press("Escape");
  await page
    .getByLabel("Instructions for Barbell bench press", { exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "How to perform" }),
  ).toBeVisible();
  await nav(page, "Got it");
  await nav(page, "Skip rest");
  await expect(page.locator(".mobile-rest-bar")).toContainText("00:00");
  await expect.poll(async () => (await stored(page)).active.restEnd).toBeNull();
  await expect
    .poll(async () => (await stored(page)).active.restPaused)
    .toBeNull();
  await page.reload();
  await expect(page.locator(".mobile-rest-bar")).toContainText("00:00");
  expect((await stored(page)).active.restEnd).toBeNull();
  expect((await stored(page)).active.restPaused).toBeNull();
  await page.screenshot({
    path: artifactPath("320-workout.png"),
    fullPage: true,
  });
});

test("fast typing persists complete values and a valid backup restores from recovery", async ({
  page,
}) => {
  const data = snapshot();
  data.active = session();
  await seed(page, data, "workout");
  await page
    .getByLabel("Session notes")
    .pressSequentially("Rapid notes 1234567890");
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Rapid notes 1234567890",
  );
  await expect
    .poll(async () => (await stored(page)).active.notes)
    .toBe("Rapid notes 1234567890");
  await expect(page.locator(".app-shell")).toHaveAttribute(
    "data-saving",
    "false",
  );
  await page.reload();
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Rapid notes 1234567890",
  );
  const backup = await stored(page);
  await seed(page, "bad json");
  await page.getByLabel("Restore recovery backup").setInputFiles({
    name: "backup.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(backup)),
  });
  await expect(page.locator(".hero")).toBeVisible();
  expect((await stored(page)).active.notes).toBe("Rapid notes 1234567890");
});

test("a storage read failure preserves the current session for export", async ({
  page,
}) => {
  const data = snapshot();
  data.profile.name = "Preserved person";
  data.active = session();
  data.active.notes = "Keep this workout";
  await seed(page, data, "workout");
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Keep this workout",
  );
  await page.evaluate(() => {
    Storage.prototype.getItem = function () {
      throw new DOMException("Blocked", "SecurityError");
    };
    window.dispatchEvent(new StorageEvent("storage", { key: "forma-v1" }));
  });
  await expect(page.getByRole("alert")).toContainText("saving is unavailable");
  await expect(page.getByLabel("Session notes")).toHaveValue(
    "Keep this workout",
  );
  await nav(page, "Settings");
  await expect(page.getByLabel("Your name")).toHaveValue("Preserved person");
  await expect(
    page.getByText(
      "Browser saving is unavailable. Export your current routines and logs now to keep a copy after this visit.",
      { exact: true },
    ),
  ).toBeVisible();
  const download = page.waitForEvent("download");
  await nav(page, "Export my data");
  const file = await download;
  expect(JSON.parse(readFileSync(await file.path(), "utf8")).active.notes).toBe(
    "Keep this workout",
  );
});

test("recovery distinguishes an invalid backup from a failed storage write", async ({
  page,
}) => {
  await seed(page, "{broken");
  await expect(
    page.getByRole("heading", { name: "Your saved data needs attention." }),
  ).toBeVisible();
  await page.getByLabel("Restore recovery backup").setInputFiles({
    name: "invalid.json",
    mimeType: "application/json",
    buffer: Buffer.from("{}"),
  });
  await expect(page.getByRole("alert")).toContainText(
    "not a valid FORMA backup",
  );
  await page.evaluate(() => {
    Storage.prototype.setItem = function () {
      throw new DOMException("Full", "QuotaExceededError");
    };
  });
  await page.getByLabel("Restore recovery backup").setInputFiles({
    name: "valid.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(snapshot())),
  });
  await expect(page.getByRole("alert")).toContainText(
    "Recovery could not be saved",
  );
  await expect(page.getByLabel("Restore recovery backup")).toBeEnabled();
  expect(await page.evaluate(() => localStorage.getItem("forma-v1"))).toBe(
    "{broken",
  );
});
