import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

// A workout the iPhone app finished with an Apple Watch recording. The web only
// shows the summary; it never writes one.
const finished = (id, name, watch) => ({
  id,
  routineId: "upper",
  name,
  startedAt: Date.parse("2026-10-30T07:00:00Z"),
  notes: "",
  restSeconds: 90,
  restEnd: null,
  restPaused: null,
  date: "2026-10-30T07:45:00Z",
  duration: 2700,
  exercises: [
    { exerciseId: "bench", sets: [{ weight: 60, reps: 8, done: true }] },
  ],
  ...(watch ? { watch } : {}),
});
async function seed(page, history, hash) {
  const data = { ...structuredClone(initialData), revision: 0, history };
  await page.goto("/");
  await page.evaluate(
    (value) => localStorage.setItem("forma-v1", JSON.stringify(value)),
    data,
  );
  await page.goto(`/#${hash}`);
  await page.reload();
}

test("a workout recorded with Apple Watch shows what the Watch collected", async ({
  page,
}) => {
  await seed(
    page,
    [
      finished("watch-day", "Watch day", {
        elapsedSeconds: 2280,
        averageHeartRate: 128,
        maxHeartRate: 162,
        activeEnergyKcal: 310,
      }),
      { ...finished("phone-day", "Phone day"), date: "2026-10-29T07:45:00Z" },
    ],
    "history",
  );
  const watchRow = page.getByRole("button", { name: /Watch day/ });
  await expect(watchRow.getByText("128 bpm avg")).toBeVisible();
  await expect(
    page.getByRole("button", { name: /Phone day/ }).getByText(/bpm/),
  ).toHaveCount(0);

  await watchRow.click();
  const panel = page.getByRole("region", { name: "Collected by Apple Watch" });
  await expect(panel).toBeVisible();
  for (const [label, value] of [
    ["Recorded time", "38:00"],
    ["Average heart rate", "128 bpm"],
    ["Highest heart rate", "162 bpm"],
    ["Active energy", "310 kcal"],
  ]) {
    await expect(panel.getByText(label, { exact: true })).toBeVisible();
    await expect(panel.getByText(value, { exact: true })).toBeVisible();
  }
});

test("Progress totals what the Watch recorded and hides without it", async ({
  page,
}) => {
  await seed(
    page,
    [
      finished("a", "Short", {
        elapsedSeconds: 600,
        averageHeartRate: 100,
        maxHeartRate: 140,
        activeEnergyKcal: 50,
      }),
      {
        ...finished("b", "Long", {
          elapsedSeconds: 1800,
          averageHeartRate: 140,
          maxHeartRate: 171,
          activeEnergyKcal: 200,
        }),
        date: "2026-10-31T07:45:00Z",
      },
    ],
    "progress",
  );
  const totals = page.getByRole("region", { name: "From your Apple Watch" });
  await expect(totals.getByText("2 workouts recorded")).toBeVisible();
  await expect(totals.getByText("130 bpm", { exact: true })).toBeVisible();
  await expect(totals.getByText("171 bpm", { exact: true })).toBeVisible();
  await expect(totals.getByText("250 kcal", { exact: true })).toBeVisible();

  await seed(page, [finished("c", "Phone only")], "progress");
  await expect(
    page.getByRole("heading", { name: "Personal bests" }),
  ).toBeVisible();
  await expect(
    page.getByRole("region", { name: "From your Apple Watch" }),
  ).toHaveCount(0);
});
