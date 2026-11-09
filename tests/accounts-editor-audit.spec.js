import { test, expect } from "@playwright/test";
import {
  deferred,
  fixtureState,
  installAccountRoutes,
} from "./accounts-frontend-audit.helpers.js";

async function pendingEditor(page, baseURL, kind, failure = false) {
  const state = fixtureState();
  const started = deferred();
  const release = deferred();
  state.putFailure = failure;
  state.putGate = async () => {
    started.resolve();
    await release.promise;
  };
  await installAccountRoutes(page, state, baseURL);
  await page.goto(kind === "routine" ? "/#routines" : "/#history");
  await page
    .locator(kind === "routine" ? ".routine-card" : ".history-row")
    .first()
    .click();
  await page
    .getByRole("button", {
      name: kind === "routine" ? "Edit routine" : "Edit workout",
      exact: true,
    })
    .click();
  const dialog = page.getByRole("dialog");
  const name = dialog.getByLabel(
    kind === "routine" ? "Routine name" : "Workout name",
    { exact: true },
  );
  await name.fill("Submitted audit draft");
  await dialog
    .getByRole("button", {
      name: kind === "routine" ? "Save routine" : "Save corrections",
      exact: true,
    })
    .click();
  await started.promise;
  return { state, started, release, dialog, name };
}

for (const kind of ["routine", "history"]) {
  test(`${kind} editor freezes its submitted draft until a delayed save completes`, async ({
    page,
    baseURL,
  }) => {
    const pending = await pendingEditor(page, baseURL, kind);
    try {
      await expect(pending.name).toBeDisabled();
      const controls = pending.dialog
        .locator("input, textarea, select, button")
        .filter({ visible: true });
      // The close icon remains focusable; its guarded handler keeps the pending editor open.
      for (const control of await controls.all()) {
        if ((await control.getAttribute("aria-label")) === "Close dialog")
          continue;
        await expect(control).toBeDisabled();
      }
      await page.keyboard.press("Escape");
      await expect(pending.dialog).toBeVisible();
    } finally {
      pending.release.resolve();
    }
    if (kind === "routine") {
      await expect(pending.dialog).toHaveCount(0);
    } else {
      // Saving a correction returns to the receipt, which remains open.
      await expect(
        pending.dialog.getByRole("heading", {
          name: "Workout complete",
          exact: true,
        }),
      ).toBeVisible();
      await expect(pending.name).toHaveCount(0);
    }
    const saved =
      kind === "routine"
        ? pending.state.data.routines[0]
        : pending.state.data.history[0];
    expect(saved.name).toBe("Submitted audit draft");
    expect(pending.state.puts).toHaveLength(1);
  });

  test(`${kind} editor preserves and unlocks its draft after a rejected save`, async ({
    page,
    baseURL,
  }) => {
    const pending = await pendingEditor(page, baseURL, kind, true);
    try {
      await expect(pending.name).toBeDisabled();
    } finally {
      pending.release.resolve();
    }
    await expect(pending.dialog.getByRole("alert")).toContainText(
      "Could not save",
    );
    await expect(pending.name).toBeEnabled();
    await expect(pending.name).toHaveValue("Submitted audit draft");
    const unchanged =
      kind === "routine"
        ? pending.state.data.routines[0]
        : pending.state.data.history[0];
    expect(unchanged.name).not.toBe("Submitted audit draft");
    expect(pending.state.puts).toHaveLength(2);
    expect(pending.state.puts[1]).toEqual(pending.state.puts[0]);
  });
}

test("routine order confirms persistence only after the write succeeds", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  const started = deferred();
  const release = deferred();
  state.putGate = async () => {
    started.resolve();
    await release.promise;
  };
  await installAccountRoutes(page, state, baseURL);
  await page.goto("/#routines");
  await page
    .getByLabel("Actions for Upper body strength", { exact: true })
    .click();
  await page
    .getByRole("button", { name: "Move later", exact: true })
    .first()
    .click();
  await started.promise;
  const announcement = page.locator(".routine-grid + .sr-only");
  try {
    await expect(announcement).toHaveText(
      "Saving the new position for Upper body strength.",
    );
    await expect(page.locator(".routine-card-wrap.is-landed")).toHaveCount(0);
    await page
      .getByLabel("Actions for Upper body strength", { exact: true })
      .click();
    await expect(
      page.getByRole("button", { name: "Move earlier", exact: true }).first(),
    ).toBeDisabled();
    await expect(
      page.getByRole("button", { name: "Move later", exact: true }).first(),
    ).toBeDisabled();
  } finally {
    release.resolve();
  }
  await expect(announcement).toHaveText(
    "Moved Upper body strength to position 2 of 3.",
  );
  expect(state.data.routines[1].id).toBe("upper");
});

test("a rejected routine move restores the saved order without a success announcement", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  state.putFailure = true;
  await installAccountRoutes(page, state, baseURL);
  await page.goto("/#routines");
  await page
    .getByLabel("Actions for Upper body strength", { exact: true })
    .click();
  await page
    .getByRole("button", { name: "Move later", exact: true })
    .first()
    .click();
  await expect(page.locator(".routine-grid + .sr-only")).toContainText(
    "Could not confirm",
  );
  await expect(page.locator(".routine-card-wrap").first()).toHaveAttribute(
    "data-routine-id",
    "upper",
  );
  await expect(page.locator(".routine-card-wrap.is-landed")).toHaveCount(0);
  expect(state.data.routines[0].id).toBe("upper");
});
