import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const fixedTime = new Date("2026-11-04T00:00:00Z");
const stored = (page) =>
  page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));

async function startHold(page, { grant = true } = {}) {
  // Mirrors the existing wake-lock-lifecycle fixture: requests resolve only
  // when the test grants them, so late grants are observable without hardware.
  await page.clock.install({ time: fixedTime });
  await page.addInitScript(() => {
    window.wakeRequests = [];
    window.wakeReleases = 0;
    window.holdCues = 0;
    Object.defineProperty(navigator, "vibrate", {
      configurable: true,
      value: () => {
        window.holdCues += 1;
        return true;
      },
    });
    Object.defineProperty(navigator, "wakeLock", {
      configurable: true,
      value: {
        request: () =>
          new Promise((resolve) => {
            window.wakeRequests.push(() => {
              const lock = new EventTarget();
              lock.release = async () => {
                window.wakeReleases += 1;
                lock.dispatchEvent(new Event("release"));
              };
              resolve(lock);
            });
          }),
      },
    });
  });
  await page.goto("/");
  await page.evaluate(
    (data) => localStorage.setItem("forma-v1", JSON.stringify(data)),
    {
      ...structuredClone(initialData),
      revision: 0,
      active: {
        id: "held-session-a",
        name: "Hold lifecycle workout",
        startedAt: fixedTime.getTime(),
        notes: "",
        restSeconds: 60,
        restEnd: null,
        restPaused: null,
        exercises: [
          {
            exerciseId: "db-plank",
            entryId: "held-original",
            sets: [{ weight: 0, reps: 1, durationSeconds: 60, done: false }],
          },
          {
            exerciseId: "bench",
            entryId: "unrelated-bench",
            sets: [{ weight: 30, reps: 8, done: false }],
          },
        ],
      },
    },
  );
  await page.goto("/#workout");
  await page.reload();
  await page
    .getByRole("button", { name: "Start 60-second hold for Plank set 1" })
    .click();
  await expect
    .poll(() => page.evaluate(() => window.wakeRequests.length))
    .toBe(1);
  if (grant) await page.evaluate(() => window.wakeRequests[0]());
}

async function changeFromOtherTab(page, context, update) {
  const other = await context.newPage();
  await other.goto("/");
  const data = await stored(page);
  const next = update(structuredClone(data));
  next.revision = data.revision + 1;
  // Real shared-context storage notification, not a synthetic event sent to
  // the same tab: the displayed workout must consume its actual sync path.
  await other.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    next,
  );
  return other;
}

async function assertNoHiddenCompletion(page) {
  await page.clock.fastForward(61_000);
  const data = await stored(page);
  expect(
    data.active.exercises
      .flatMap((entry) => entry.sets)
      .some((set) => set.done),
  ).toBe(false);
  expect(data.active.restEnd).toBeNull();
  expect(await page.evaluate(() => window.holdCues)).toBe(0);
}

test("removing the held exercise releases its active screen wake lock immediately", async ({
  page,
}) => {
  await startHold(page);
  await page
    .getByRole("button", { name: "Options for Plank", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Remove exercise", exact: true })
    .click();
  await expect(
    page.locator('.log-exercise[data-entry-key="held-original"]'),
  ).toHaveCount(0);
  await expect(page.locator(".log-exercise")).toHaveCount(1);
  // No 60-second advance before this assertion: releasing only on expiry
  // does not satisfy cancellation when the corresponding row is gone.
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await assertNoHiddenCompletion(page);
});

test("replacing the held exercise cancels its wake lock without logging a replacement set", async ({
  page,
}) => {
  await startHold(page);
  await page
    .getByRole("button", { name: "Options for Plank", exact: true })
    .click();
  await page
    .getByRole("menuitem", { name: "Replace exercise", exact: true })
    .click();
  const picker = page.getByRole("dialog", {
    name: "Replace Plank",
    exact: true,
  });
  await picker.getByLabel("Search exercises").fill("incline dumbbell press");
  await picker
    .getByRole("button", { name: /^Replace with Incline Dumbbell Press,/ })
    .click();
  await expect(
    page.locator('.log-exercise[data-entry-key="held-original"]'),
  ).toHaveCount(0);
  await expect(
    page.getByRole("heading", { name: "Incline Dumbbell Press", exact: true }),
  ).toBeVisible();
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await assertNoHiddenCompletion(page);
});

test("another tab removing the held row invalidates a pending wake grant in the same session", async ({
  page,
  context,
}) => {
  await startHold(page, { grant: false });
  const other = await changeFromOtherTab(page, context, (data) => {
    data.active.exercises = data.active.exercises.slice(1);
    return data;
  });
  await expect(
    page.locator('.log-exercise[data-entry-key="held-original"]'),
  ).toHaveCount(0);
  await page.evaluate(() => window.wakeRequests[0]());
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await assertNoHiddenCompletion(page);
  await other.close();
});

test("a different active session with the same entry key owns a fresh timer lifecycle", async ({
  page,
  context,
}) => {
  await startHold(page, { grant: false });
  const other = await changeFromOtherTab(page, context, (data) => {
    data.active.id = "held-session-b";
    data.active.name = "Second hold workout";
    return data;
  });
  await expect(
    page.getByRole("heading", {
      name: "Second hold workout",
      exact: true,
      level: 1,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Start 60-second hold for Plank set 1" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Pause hold timer" }),
  ).toHaveCount(0);
  await page.evaluate(() => window.wakeRequests[0]());
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await assertNoHiddenCompletion(page);
  expect((await stored(page)).active.id).toBe("held-session-b");
  await other.close();
});

test("a remote replacement reusing an entry key cancels the original exercise timer", async ({
  page,
  context,
}) => {
  await startHold(page);
  const other = await changeFromOtherTab(page, context, (data) => {
    data.active.exercises[0] = {
      ...data.active.exercises[0],
      exerciseId: "curl",
      sets: [{ weight: 12, reps: 8, done: false }],
    };
    return data;
  });
  await expect(
    page
      .locator('.log-exercise[data-entry-key="held-original"]')
      .getByRole("heading", { name: "Dumbbell biceps curl", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("group", { name: "Hold timer for Plank" }),
  ).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await assertNoHiddenCompletion(page);
  await other.close();
});
