import { test, expect } from "@playwright/test";
import { validateData } from "../src/storage.js";
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

function historicalSession() {
  const routine = structuredClone(initialData.routines[0]);
  const session = {
    id: "ui-history-fixture",
    routineId: routine.id,
    name: routine.name,
    date: new Date().toISOString(),
    startedAt: Date.now() - 60000,
    duration: 60,
    notes: "Original note",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: routine.exercises.map((exercise) => ({
      exerciseId: exercise.exerciseId,
      sets: Array.from({ length: exercise.sets }, () => ({
        weight: exercise.weight,
        reps: exercise.reps,
        done: true,
      })),
    })),
  };
  return validateData({ ...snapshot(), history: [session] }).history[0];
}

test(
  "skip link, desktop brand, profile shortcut and active session navigation reach their targets",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "global-skip-content,navigation-desktop-brand,navigation-profile-shortcut,navigation-active-session",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot());
    const skip = page.getByRole("link", { name: "Skip to content" });
    await skip.focus();
    await page.keyboard.press("Enter");
    await expect(page.locator("main h1")).toBeFocused();
    await expect(page).toHaveURL(/#overview$/);

    await page.getByRole("link", { name: "FORMA" }).click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "overview");
    await expect(page).toHaveURL(/#overview$/);

    await page.getByRole("button", { name: /Guest workspace/ }).click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "account");
    await expect(
      page.getByRole("heading", { name: "Your local workspace", exact: true }),
    ).toBeVisible();

    const data = snapshot();
    data.active = {
      id: "active-ui-fixture",
      routineId: data.routines[0].id,
      name: data.routines[0].name,
      startedAt: Date.now(),
      notes: "",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: data.routines[0].exercises.map((exercise) => ({
        exerciseId: exercise.exerciseId,
        sets: Array.from({ length: exercise.sets }, () => ({
          weight: exercise.weight,
          reps: exercise.reps,
          done: false,
        })),
      })),
    };
    await seed(page, data, "overview");
    await page.getByRole("button", { name: /Workout in progress/ }).click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "workout");
    await expect(page).toHaveURL(/#workout$/);
    expect((await stored(page)).active.id).toBe("active-ui-fixture");
  },
);

test(
  "preferred next routine updates the overview start target and creates that active session",
  {
    annotation: [
      {
        type: "interaction",
        description: "overview-preferred-routine,overview-start-cta",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    const target = data.routines[1];
    await seed(page, data);
    await page.getByLabel("Choose next session").selectOption(target.id);
    await expect(page.locator(".hero")).toContainText(target.name);
    await page
      .locator(".hero")
      .getByRole("button", { name: "Start workout", exact: true })
      .click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "workout");
    expect((await stored(page)).active.name).toBe(target.name);

    const active = snapshot();
    active.active = {
      id: "resume-cta-fixture",
      routineId: active.routines[0].id,
      name: active.routines[0].name,
      startedAt: Date.now(),
      notes: "",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: active.routines[0].exercises.map((exercise) => ({
        exerciseId: exercise.exerciseId,
        sets: Array.from({ length: exercise.sets }, () => ({
          weight: exercise.weight,
          reps: exercise.reps,
          done: false,
        })),
      })),
    };
    await seed(page, active, "overview");
    await page
      .locator(".hero")
      .getByRole("button", { name: "Resume workout", exact: true })
      .click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "workout");
    expect((await stored(page)).active.id).toBe("resume-cta-fixture");
  },
);

test(
  "schedule opens from its overview banner and a clean close leaves the schedule unchanged",
  {
    annotation: [
      {
        type: "interaction",
        description: "overview-schedule-banner,schedule-close-clean",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    const before = [...data.schedule];
    await seed(page, data);
    await page.getByRole("button", { name: "Schedule your week" }).click();
    await expect(page.getByRole("dialog")).toContainText(
      "Make room for yourself.",
    );
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    expect((await stored(page)).schedule).toEqual(before);
  },
);

test(
  "routine editor closes a clean draft directly and keeps invalid submissions open",
  {
    annotation: [
      {
        type: "interaction",
        description: "routine-editor-cancel-clean,routine-editor-save-invalid",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    const count = data.routines.length;
    await seed(page, data, "routines");
    await page.locator(".routine-card").first().click();
    await page.getByRole("button", { name: "Edit routine" }).click();
    await page.getByRole("button", { name: "Cancel", exact: true }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    await expect(
      page.getByRole("heading", { name: "Discard unsaved changes?" }),
    ).toHaveCount(0);

    await page
      .getByRole("button", { name: "Create routine", exact: true })
      .click();
    await page.getByLabel("Routine name").fill("No exercises yet");
    await page.getByRole("button", { name: "Save routine" }).click();
    await expect(page.getByRole("alert")).toContainText(
      "choose at least one exercise",
    );
    await expect(page.getByRole("dialog")).toBeVisible();
    expect((await stored(page)).routines).toHaveLength(count);
  },
);

test(
  "history editor retains notes on keep, rejects removing every completed set, and discards without saving",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "history-row-open,history-edit-open,history-editor-keep-set,history-editor-notes,history-editor-cancel-dirty,history-editor-discard-choice,history-editor-save-invalid",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    const session = historicalSession();
    data.history = [session];
    await seed(page, data, "history");
    const row = page.locator(".history-row");
    await row.click();
    await page.getByRole("button", { name: "Edit workout" }).click();
    const note = page.getByLabel("Workout notes");
    await note.fill("Unsaved correction");
    await page.getByRole("button", { name: "Cancel", exact: true }).click();
    await expect(
      page.getByRole("heading", { name: "Discard workout changes?" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Keep editing" }).click();
    await expect(note).toHaveValue("Unsaved correction");

    for (const checkbox of await page.getByRole("checkbox").all()) {
      await checkbox.uncheck();
    }
    await page.getByRole("button", { name: "Save corrections" }).click();
    await expect(page.getByRole("alert")).toContainText(
      "Keep at least one completed set",
    );
    await expect(page.getByRole("dialog")).toBeVisible();
    expect((await stored(page)).history[0]).toEqual(session);

    await page.getByRole("button", { name: "Close dialog" }).click();
    await page.getByRole("button", { name: "Discard changes" }).click();
    await expect(
      page.getByRole("heading", { name: "Workout complete" }),
    ).toBeVisible();
    expect((await stored(page)).history[0]).toEqual(session);
  },
);

test(
  "empty overview, workout, history and progress calls to action start the default routine",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "overview-start-cta,workout-empty-start,history-empty-start,progress-empty-start",
      },
    ],
  },
  async ({ page }) => {
    const targetName = initialData.routines[0].name;
    for (const route of ["overview", "workout", "history", "progress"]) {
      await seed(page, snapshot(), route);
      const buttonName = {
        overview: "Start workout",
        workout: "Start workout",
        history: "Start your first workout",
        progress: "Let’s get started",
      }[route];
      const button =
        route === "overview"
          ? page
              .locator(".hero")
              .getByRole("button", { name: buttonName, exact: true })
          : page.getByRole("button", { name: buttonName, exact: true });
      if (route === "workout") {
        await expect(
          page.getByRole("heading", { name: "No workout is running." }),
        ).toBeVisible();
      }
      await button.click();
      await expect(page.locator("main")).toHaveAttribute(
        "data-page",
        "workout",
      );
      expect((await stored(page)).active.name).toBe(targetName);
    }
  },
);

test(
  "keeping a history workout after opening deletion leaves its details and saved data intact",
  {
    annotation: [
      {
        type: "interaction",
        description: "history-delete-open,history-delete-keep",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    const session = historicalSession();
    data.history = [session];
    await seed(page, data, "history");
    await page.locator(".history-row").click();
    await page
      .getByRole("button", { name: "Delete workout", exact: true })
      .click();
    await expect(
      page.getByRole("heading", { name: "Delete this workout?" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Keep workout" }).click();
    await expect(
      page.getByRole("heading", { name: "Workout complete" }),
    ).toBeVisible();
    expect((await stored(page)).history).toEqual([session]);
  },
);

test(
  "routine detail closes cleanly and workout Back returns to overview with the session active",
  {
    annotation: [
      {
        type: "interaction",
        description: "routine-detail-close,routine-detail-start,workout-back",
      },
    ],
  },
  async ({ page }) => {
    await seed(page, snapshot(), "routines");
    const card = page.locator(".routine-card").first();
    await card.click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(page.getByRole("dialog")).toHaveCount(0);
    await expect(card).toBeFocused();

    await card.click();
    await page
      .getByRole("button", { name: "Start workout", exact: true })
      .click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "workout");
    await page
      .getByRole("button", { name: "Back to overview · workout stays active" })
      .click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "overview");
    await expect(
      page
        .locator(".hero")
        .getByRole("button", { name: "Resume workout", exact: true }),
    ).toBeVisible();
    const activeId = (await stored(page)).active.id;
    await page
      .getByRole("button", { name: "My routines", exact: true })
      .click();
    await page.locator(".routine-card").first().click();
    await page
      .getByRole("button", { name: "Start workout", exact: true })
      .click();
    await expect(page.locator("main")).toHaveAttribute("data-page", "workout");
    expect((await stored(page)).active.id).toBe(activeId);
  },
);

test(
  "history detail closes by button and backdrop, restores row focus, and stays open for inside clicks",
  {
    annotation: [
      {
        type: "interaction",
        description:
          "history-row-open,history-detail-close,modal-backdrop-shared",
      },
    ],
  },
  async ({ page }) => {
    const data = snapshot();
    data.history = [historicalSession()];
    await seed(page, data, "history");
    const row = page.locator(".history-row");
    await row.click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await dialog.getByRole("heading", { name: "Workout complete" }).click();
    await expect(dialog).toBeVisible();
    await page.getByRole("button", { name: "Close dialog" }).click();
    await expect(dialog).toHaveCount(0);
    await expect(row).toBeFocused();

    await row.click();
    await expect(dialog).toBeVisible();
    const viewport = page.viewportSize();
    await page.mouse.click(viewport.width - 2, viewport.height - 2);
    await expect(dialog).toHaveCount(0);
    await expect(row).toBeFocused();
  },
);
