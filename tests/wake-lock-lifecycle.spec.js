import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

async function startHold(page) {
  await page.addInitScript(() => {
    window.wakeRequests = [];
    window.wakeReleases = 0;
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
        id: "wake-lock-test",
        name: "Hold workout",
        startedAt: Date.now(),
        notes: "",
        restSeconds: 60,
        restEnd: null,
        restPaused: null,
        exercises: [
          {
            exerciseId: "db-plank",
            sets: [{ weight: 0, reps: 1, durationSeconds: 60, done: false }],
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
}

test("a wake lock granted after pausing is immediately released", async ({
  page,
}) => {
  await startHold(page);
  await page.getByRole("button", { name: "Pause hold timer" }).click();
  await page.evaluate(() => window.wakeRequests[0]());
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
  await page.getByRole("button", { name: "Resume hold timer" }).click();
  await expect
    .poll(() => page.evaluate(() => window.wakeRequests.length))
    .toBe(2);
  await page.evaluate(() => window.wakeRequests[1]());
  await page.getByRole("button", { name: "Pause hold timer" }).click();
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(2);
});

test("pending visibility requests are deduplicated and late grants after leaving are released", async ({
  page,
}) => {
  await startHold(page);
  await page.evaluate(() => {
    document.dispatchEvent(new Event("visibilitychange"));
    document.dispatchEvent(new Event("visibilitychange"));
  });
  await expect
    .poll(() => page.evaluate(() => window.wakeRequests.length))
    .toBe(1);
  await page.evaluate(() => {
    window.location.hash = "progress";
  });
  await expect(
    page.getByRole("heading", { name: "See your strength take shape." }),
  ).toBeVisible();
  await page.evaluate(() => window.wakeRequests[0]());
  await expect.poll(() => page.evaluate(() => window.wakeReleases)).toBe(1);
});
