import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { initialData } from "../src/data.js";

const origin = "http://localhost:5173";
const snapshot = () => ({ ...structuredClone(initialData), revision: 0 });

async function seed(page, data, route = "overview") {
  await page.goto(origin);
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`${origin}/#${route}`);
  await page.reload();
}

async function stored(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));
}

test(
  "calendar navigation selects weeks and schedule saves only after confirmation",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "overview-calendar-previous,overview-calendar-next,overview-this-week,overview-calendar-day,overview-edit-schedule-selected-day,schedule-day-toggle,schedule-close-dirty,schedule-discard-choice,schedule-save,schedule-discard-choice,toast-dismiss",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot());
    const week = page.locator(".calendar-heading > span").first();
    const currentWeek = await week.innerText();

    await page.getByRole("button", { name: "Previous week" }).click();
    await expect(week).not.toHaveText(currentWeek);
    await expect(page.locator(".day").first()).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await page.getByRole("button", { name: "Next week" }).click();
    await expect(week).toHaveText(currentWeek);

    await page.getByRole("button", { name: "Previous week" }).click();
    await page.getByRole("button", { name: "This week" }).click();
    await expect(week).toHaveText(currentWeek);

    const day = page.locator(".day").nth(1);
    await day.click();
    await expect(day).toHaveAttribute("aria-pressed", "true");
    await page.getByRole("button", { name: "Edit schedule" }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    const sunday = dialog.getByRole("button", { name: "Sunday" });
    await expect(sunday).toHaveAttribute("aria-pressed", "false");
    await sunday.click();
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(
      page.getByRole("heading", { name: "Discard schedule changes?" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Keep editing" }).click();
    await expect(sunday).toHaveAttribute("aria-pressed", "true");
    expect((await stored(page)).schedule).not.toContain(6);

    await page.getByRole("button", { name: "Tuesday", exact: true }).click();
    await page.getByRole("button", { name: "Close dialog" }).click();
    await page.getByRole("button", { name: "Discard changes" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).schedule).toEqual([0, 1, 3, 5]);

    await page.getByRole("button", { name: "Edit schedule" }).click();
    const reopenedSunday = page
      .getByRole("dialog")
      .getByRole("button", { name: "Sunday" });
    await reopenedSunday.click();
    await page.getByRole("button", { name: "Save schedule" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).schedule).toEqual([0, 1, 3, 5, 6]);
    await page.getByRole("button", { name: "Dismiss notification" }).click();
    await expect(page.getByRole("status")).toHaveCount(0);
  },
);

test(
  "routine prescriptions reorder and delete confirmation preserves or removes the selected routine",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "routine-card,routine-detail-edit,routine-editor-duration,routine-editor-move-up,routine-editor-move-down,routine-editor-save-valid,routine-detail-delete-open,routine-delete-keep,routine-delete-confirm",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot(), "routines");
    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Edit routine" }).click();

    const moveUp = page.getByRole("button", {
      name: "Move One-arm dumbbell row up",
    });
    const moveDown = page.getByRole("button", {
      name: "Move Barbell bench press down",
    });
    await expect(
      page.getByRole("button", { name: "Move Barbell bench press up" }),
    ).toBeDisabled();
    await expect(
      page.getByRole("button", { name: "Move Cable triceps pushdown down" }),
    ).toBeDisabled();
    await page.getByLabel("Estimated duration (minutes)").fill("75");
    await moveUp.click();
    await expect(
      page.getByRole("button", { name: "Move One-arm dumbbell row up" }),
    ).toBeDisabled();
    await expect(moveDown).toBeEnabled();
    await page.getByRole("button", { name: "Save routine" }).click();
    await expect
      .poll(async () =>
        (await stored(page)).routines[0].exercises.map(
          (item) => item.exerciseId,
        ),
      )
      .toEqual(["row", "bench", "shoulder", "pulldown", "curl", "triceps"]);
    expect((await stored(page)).routines[0].minutes).toBe(75);

    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Edit routine" }).click();
    await expect(page.getByLabel("Estimated duration (minutes)")).toHaveValue(
      "75",
    );
    await page
      .getByRole("button", { name: "Move One-arm dumbbell row down" })
      .click();
    await page.getByRole("button", { name: "Save routine" }).click();
    await expect
      .poll(async () =>
        (await stored(page)).routines[0].exercises.map(
          (item) => item.exerciseId,
        ),
      )
      .toEqual(["bench", "row", "shoulder", "pulldown", "curl", "triceps"]);

    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Delete routine" }).click();
    await page.getByRole("button", { name: "Keep it" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).routines).toHaveLength(3);

    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Delete routine" }).click();
    await page
      .getByRole("dialog")
      .getByRole("button", { name: "Delete routine", exact: true })
      .click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).routines.map((routine) => routine.id)).toEqual([
      "lower",
      "full",
    ]);
  },
);

test(
  "dirty routine editor keeps drafts on cancel and discards only after confirmation",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "routine-editor-name,routine-editor-cancel-dirty,routine-editor-discard-keep,routine-editor-discard-confirm",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot(), "routines");
    const originalName = (await stored(page)).routines[0].name;
    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Edit routine" }).click();
    await page.getByLabel("Routine name").fill("Unsaved shoulder day");
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(
      page.getByRole("heading", { name: "Discard unsaved changes?" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Keep editing" }).click();
    await expect(page.getByLabel("Routine name")).toHaveValue(
      "Unsaved shoulder day",
    );
    await page.getByRole("button", { name: "Close dialog" }).click();
    await page.getByRole("button", { name: "Discard changes" }).click();
    expect((await stored(page)).routines[0].name).toBe(originalName);
    await expect(page.getByRole("dialog")).toHaveCount(0);
  },
);

test(
  "library search, muscle and equipment filters compose and guide closes with keyboard",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "library-search,library-equipment-filter,library-muscle-filter,library-card-guide,library-clear-filters,exercise-guide-close,modal-escape-shared",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot(), "library");
    await page.getByRole("button", { name: "Chest", exact: true }).click();
    await page.getByLabel("Filter by equipment").selectOption("Barbell");
    await page.getByLabel("Search exercise library").fill("bench");
    await expect(page.locator(".library-card")).toHaveCount(1);
    await expect(page.locator(".library-card")).toContainText(
      "Barbell bench press",
    );

    const card = page.locator(".library-card");
    await card.focus();
    await page.keyboard.press("Enter");
    const dialog = page.getByRole("dialog");
    await expect(dialog).toContainText("How to perform");
    await page.keyboard.press("Escape");
    await expect(dialog).toHaveCount(0);
    await expect(card).toBeFocused();

    await page.getByLabel("Search exercise library").fill("zzzz");
    await expect(
      page.getByRole("heading", { name: "No matching movements" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Clear filters" }).click();
    await expect(page.getByLabel("Search exercise library")).toHaveValue("");
    await expect(page.getByLabel("Filter by equipment")).toHaveValue(
      "All equipment",
    );
    await expect(
      page.getByRole("button", { name: "All muscles", exact: true }),
    ).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator(".library-card")).toHaveCount(16);
  },
);

test(
  "profile name and weekly goal enforce their UI bounds and persist selected targets",
  {
    annotation: [
      {
        type: "interaction",
        description: "settings-name,settings-weekly-goal,settings-save-profile",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot(), "settings");
    const name = page.getByLabel("Your name");
    await name.fill("X".repeat(60));
    await expect(name).toHaveValue("X".repeat(50));
    await page.getByLabel("Weekly workout goal").selectOption("1");
    await page.getByRole("button", { name: "Save preferences" }).click();
    await expect
      .poll(async () => (await stored(page)).profile)
      .toEqual({ name: "X".repeat(50), goal: 1 });

    await page.getByLabel("Weekly workout goal").selectOption("7");
    await page.getByRole("button", { name: "Save preferences" }).click();
    await expect.poll(async () => (await stored(page)).profile.goal).toBe(7);
    await expect(page.locator(".profile-button")).toContainText("X".repeat(50));
  },
);

test(
  "Settings backup restore can be cancelled or confirmed and changes persisted data",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "settings-import-picker,settings-import-cancel,settings-import-restore",
      },
    ],
  },
  async ({ page }) => {
    const original = snapshot();
    const backup = snapshot();
    backup.profile = { name: "Backup athlete", goal: 2 };
    backup.schedule = [2, 4];
    await seed(page, original, "settings");
    const file = {
      name: "forma-backup.json",
      mimeType: "application/json",
      buffer: Buffer.from(JSON.stringify(backup)),
    };

    await page.getByLabel("Import backup").setInputFiles(file);
    await expect(page.getByRole("dialog")).toContainText(
      "Restore this backup?",
    );
    await page.getByRole("button", { name: "Cancel" }).click();
    expect((await stored(page)).profile.name).toBe(original.profile.name);

    await page.getByLabel("Import backup").setInputFiles(file);
    await page.getByRole("button", { name: "Restore backup" }).click();
    await expect(page.locator(".hero")).toBeVisible();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).profile).toEqual(backup.profile);
    expect((await stored(page)).schedule).toEqual(backup.schedule);
  },
);

test(
  "recovery reset confirmation preserves the corrupt original until a confirmed reset",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "recovery-fresh-open,recovery-fresh-keep,recovery-fresh-reset",
      },
    ],
  },
  async ({ page }) => {
    const raw = "{invalid workspace";
    await page.goto(origin);
    await page.evaluate(
      (value) => localStorage.setItem("forma-v1", value),
      raw,
    );
    await page.reload();
    await expect(
      page.getByRole("heading", { name: "Your saved data needs attention." }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Start a fresh workspace" }).click();
    await page.getByRole("button", { name: "Keep original" }).click();
    expect(await page.evaluate(() => localStorage.getItem("forma-v1"))).toBe(
      raw,
    );

    await page.getByRole("button", { name: "Start a fresh workspace" }).click();
    await page.getByRole("button", { name: "Start fresh" }).click();
    await expect(page.locator(".hero")).toBeVisible();
    expect((await stored(page)).routines).toHaveLength(3);
    const preserved = await page.evaluate(
      (value) =>
        Object.keys(localStorage)
          .filter((key) => key.startsWith("forma-v1-recovery-"))
          .map((key) => localStorage.getItem(key))
          .includes(value),
      raw,
    );
    expect(preserved).toBe(true);
  },
);

test(
  "navigation handles unknown hashes, forward and Back with page focus and title updates",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "navigation-main-items,navigation-settings,overview-view-routines",
      },
    ],
  },
  async ({ page }) => {
    await page.goto(`${origin}/#not-a-page`);
    await expect(page.locator("main")).toHaveAttribute("data-page", "overview");
    await page.getByRole("button", { name: "View all" }).click();
    await expect(page).toHaveURL(/#routines$/);
    await expect(page).toHaveTitle("My routines · FORMA");
    await expect(page.locator("main h1")).toBeFocused();
    await page.getByRole("button", { name: "Settings", exact: true }).click();
    await expect(page).toHaveURL(/#settings$/);
    await expect(page.locator("main h1")).toBeFocused();
    await page.goBack();
    await expect(page.locator("main")).toHaveAttribute("data-page", "routines");
    await page.goForward();
    await expect(page.locator("main")).toHaveAttribute("data-page", "settings");
  },
);

test(
  "mobile navigation and shared guide dialog support focus return and keyboard trapping at 375px",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "navigation-mobile-toggle,navigation-mobile-shade,navigation-mobile-brand,library-card-guide,exercise-guide-close,modal-close-shared,modal-escape-shared",
      },
    ],
  },
  async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await seed(page, snapshot(), "library");
    const toggle = page.getByRole("button", { name: "Toggle navigation" });
    await toggle.click();
    await expect(toggle).toHaveAttribute("aria-expanded", "true");
    await expect(page.locator("main")).toHaveAttribute("inert", "");
    await page
      .getByRole("button", { name: "Close navigation" })
      .click({ position: { x: 365, y: 120 } });
    await expect(toggle).toBeFocused();
    await expect(toggle).toHaveAttribute("aria-expanded", "false");
    await expect(page.locator("main")).not.toHaveAttribute("inert");

    const card = page.locator(".library-card").first();
    await card.focus();
    await page.keyboard.press("Enter");
    const close = page.getByRole("button", { name: "Close dialog" });
    const gotIt = page.getByRole("button", { name: "Got it" });
    await expect(close).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(gotIt).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(close).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toHaveCount(0);
    await expect(card).toBeFocused();
    await card.focus();
    await page.keyboard.press("Enter");
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    await expect(card).toBeFocused();

    await toggle.click();
    await page.locator(".mobile-top .brand").focus();
    await page.keyboard.press("Enter");
    await expect(page.locator("main")).toHaveAttribute("data-page", "overview");
    await expect(toggle).toHaveAttribute("aria-expanded", "false");
  },
);

test(
  "error fallback downloads saved data, reports denied storage and reloads the workspace",
  {
    annotation: [
      {
        type: "interaction",
        description: "error-boundary-download,error-boundary-reload",
      },
    ],
  },
  async ({ page }) => {
    const raw = JSON.stringify(snapshot());
    let appRequests = 0;
    await page.route(/\/src\/App\.jsx(?:\?.*)?$/, async (route) => {
      appRequests += 1;
      await route.fulfill({
        status: 200,
        contentType: "text/javascript",
        body: 'export default function App() { throw new Error("controlled boundary fixture"); }',
      });
    });
    await page.goto(origin);
    await page.evaluate(
      (value) => localStorage.setItem("forma-v1", value),
      raw,
    );
    await page.reload();
    await expect(
      page.getByRole("heading", { name: "Let’s get your workspace back." }),
    ).toBeVisible();

    const downloadPromise = page.waitForEvent("download");
    await page.getByRole("button", { name: "Download saved data" }).click();
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toContain("forma-original-data");
    expect(readFileSync(await download.path(), "utf8")).toBe(raw);

    const beforeReload = appRequests;
    await page.getByRole("button", { name: "Reload workspace" }).click();
    await expect.poll(() => appRequests).toBeGreaterThan(beforeReload);
    await expect(
      page.getByRole("heading", { name: "Let’s get your workspace back." }),
    ).toBeVisible();

    await page.evaluate(() => {
      Storage.prototype.getItem = function () {
        throw new DOMException("Blocked", "SecurityError");
      };
    });
    await page.getByRole("button", { name: "Download saved data" }).click();
    await expect(page.getByRole("alert")).toContainText(
      "could not access the saved data",
    );
  },
);
