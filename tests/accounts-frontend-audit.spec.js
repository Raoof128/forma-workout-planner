import { test, expect } from "@playwright/test";
import {
  deferred,
  fixtureState,
  installAccountRoutes,
} from "./accounts-frontend-audit.helpers.js";

async function openAccount(page, state, baseURL) {
  await installAccountRoutes(page, state, baseURL);
  await page.goto("/#account");
}

const workspaceReads = (state) =>
  state.requests.filter(
    (request) => request.path === "/api/workspace" && request.method === "GET",
  ).length;

const profileFields = (page) => ({
  name: page.getByLabel("Display name", { exact: true }),
  goal: page.getByLabel("Weekly workout goal"),
  email: page.getByLabel("New email address", { exact: true }),
});

async function expectDraft(fields, { name, goal, email }) {
  await expect(fields.name).toHaveValue(name);
  await expect(fields.goal).toHaveValue(goal);
  await expect(fields.email).toHaveValue(email);
}

test("initial cloud connection retry starts a fresh GET when no save is pending", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  state.failWorkspace = true;
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await openAccount(page, state, baseURL);
  await expect(
    page.getByRole("heading", {
      name: "Cloud data is unavailable",
      exact: true,
    }),
  ).toBeVisible();
  const before = workspaceReads(state);
  state.failWorkspace = false;
  await page
    .getByRole("button", { name: "Retry connection", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Good work, Web.", exact: true }),
  ).toBeVisible();
  expect(workspaceReads(state)).toBeGreaterThan(before);
  expect(state.puts).toEqual([]);
  expect(errors).toEqual([]);
  await expect(page).toHaveURL(/#account$/);
  const accountHeading = page.getByRole("heading", {
    name: "Account",
    exact: true,
  });
  await page
    .getByRole("link", { name: "Skip to content", exact: true })
    .focus();
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/#account$/);
  await expect(accountHeading).toBeFocused();
});

test("a profile acknowledgement preserves later name goal and email drafts", async ({
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
  await openAccount(page, state, baseURL);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  const fields = profileFields(page);
  const save = page.getByRole("button", { name: "Save changes", exact: true });
  try {
    await fields.name.fill("Submitted Name");
    await fields.goal.selectOption("5");
    await save.click();
    await started.promise;
    await fields.name.fill("Later Draft");
    await fields.goal.selectOption("6");
    await fields.email.fill("later-draft@example.test");
  } finally {
    release.resolve();
  }
  await expect(save).toBeEnabled();
  await expectDraft(fields, {
    name: "Later Draft",
    goal: "6",
    email: "later-draft@example.test",
  });
  expect(state.data.profile.name).toBe("Submitted Name");
  expect(state.data.profile.goal).toBe(5);
  await expect(
    page.getByText("Your newer edits are still in the form.", { exact: false }),
  ).toBeVisible();
  await save.click();
  await expect.poll(() => state.data.profile.name).toBe("Later Draft");
  await expect(save).toBeEnabled();
  expect(state.data.profile.goal).toBe(6);
});

test("background refresh updates saved state without replacing dirty profile fields", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  await openAccount(page, state, baseURL);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  const fields = profileFields(page);
  await fields.name.fill("Unsent Local Name");
  await fields.goal.selectOption("5");
  await fields.email.fill("unsent-local@example.test");
  state.data = {
    ...state.data,
    revision: 1,
    profile: { ...state.data.profile, name: "Remote Profile", goal: 7 },
  };
  state.revision = 1;
  state.user = { ...state.user, name: "Remote Profile" };
  await page.evaluate(() => window.dispatchEvent(new Event("focus")));
  await expect(page.locator(".account-nav-member")).toContainText(
    "Remote Profile",
  );
  await expectDraft(fields, {
    name: "Unsent Local Name",
    goal: "5",
    email: "unsent-local@example.test",
  });
  await page
    .getByRole("button", { name: "Cancel changes", exact: true })
    .click();
  await expect(fields.name).toHaveValue("Remote Profile");
  await expect(fields.goal).toHaveValue("7");
});

test("explicit conflict reload discards reviewed training fields and preserves later input", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  state.conflictData = {
    ...state.data,
    profile: { ...state.data.profile, name: "Remote Profile", goal: 7 },
  };
  await openAccount(page, state, baseURL);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  const fields = profileFields(page);
  const rounds = [
    {
      laterName: "Later Local Name",
      laterGoal: null,
      name: "Later Local Name",
      goal: "7",
    },
    { laterName: null, laterGoal: "6", name: "Remote Profile", goal: "6" },
  ];
  for (const [index, round] of rounds.entries()) {
    await fields.name.fill(`Reviewed Local Name ${index}`);
    await fields.goal.selectOption("2");
    await page
      .getByRole("button", { name: "Save changes", exact: true })
      .click();
    await expect(page.locator(".account-sync-alert")).toBeVisible();
    await expect(fields.goal).toHaveValue("2");
    const started = deferred();
    const release = deferred();
    state.getGate = async () => {
      started.resolve();
      await release.promise;
    };
    try {
      await page
        .getByLabel("I understand reloading replaces my unsynced edits.")
        .check();
      await page
        .getByRole("button", { name: "Reload cloud data", exact: true })
        .click();
      await started.promise;
      if (round.laterName) await fields.name.fill(round.laterName);
      if (round.laterGoal) await fields.goal.selectOption(round.laterGoal);
      await fields.email.fill("later-local@example.test");
    } finally {
      release.resolve();
    }
    await expect(page.locator(".account-sync-alert")).toHaveCount(0);
    await expectDraft(fields, {
      name: round.name,
      goal: round.goal,
      email: "later-local@example.test",
    });
    expect(state.puts).toHaveLength(index + 1);
    expect(state.data.profile.name).toBe("Remote Profile");
    expect(state.data.profile.goal).toBe(7);
  }
});

test("manual sync retry preserves the exact pending write instead of refreshing it away", async ({
  page,
  baseURL,
}) => {
  const state = fixtureState();
  state.putFailure = 2;
  await openAccount(page, state, baseURL);
  await page.getByRole("button", { name: "Profile", exact: true }).click();
  await page.getByLabel("Weekly workout goal").selectOption("5");
  const before = workspaceReads(state);
  await page.getByRole("button", { name: "Save changes", exact: true }).click();
  await expect(page.locator(".account-sync-alert")).toBeVisible();
  expect(state.puts).toHaveLength(2);
  expect(state.data.profile.goal).toBe(4);
  await page.getByRole("button", { name: "Retry sync", exact: true }).click();
  await expect(page.locator(".account-sync-alert")).toHaveCount(0);
  expect(state.puts).toHaveLength(3);
  expect(state.puts[1]).toEqual(state.puts[0]);
  expect(state.puts[2]).toEqual(state.puts[0]);
  expect(state.puts[0].operationId).toMatch(/^account-goal-/);
  expect(state.data.profile.goal).toBe(5);
  expect(workspaceReads(state)).toBe(before);
});
