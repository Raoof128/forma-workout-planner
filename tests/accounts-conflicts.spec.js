import { expect, test } from "@playwright/test";

const emailSink = "http://127.0.0.1:3002/emails";
const password = "FORMA-local-test-passphrase-2026";
const stamp = () => `${Date.now()}-${Math.random().toString(16).slice(2)}`;

async function clickMainNavigation(page, name) {
  const item = page.getByRole("button", { name, exact: true });
  const toggle = page.getByRole("button", { name: "Toggle navigation" });
  await expect
    .poll(async () => (await item.isVisible()) || (await toggle.isVisible()))
    .toBe(true);
  const insideViewport = await item.evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return rect.left >= 0 && rect.right <= window.innerWidth;
  });
  if (!insideViewport) await toggle.click();
  await item.scrollIntoViewIfNeeded();
  await item.click();
}

async function verificationEmail(request, email) {
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      const messages = response.ok() ? await response.json() : [];
      return messages.some(
        (message) => message.kind === "verify-email" && message.email === email,
      );
    })
    .toBe(true);
  const response = await request.get(
    `${emailSink}?email=${encodeURIComponent(email)}`,
  );
  return (await response.json())
    .filter((message) => message.kind === "verify-email")
    .at(-1);
}

async function createAccount(page, name, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill(name);
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page
    .getByRole("checkbox", { name: /agree to the Terms of Use/i })
    .check();
  await page
    .getByRole("checkbox", { name: /consent to FORMA storing/i })
    .check();
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(
    page.getByRole("status").filter({ hasText: "verification link" }),
  ).toContainText("verification link");
  const verification = await verificationEmail(page.request, email);
  await page.goto(verification.url);
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByText(name, { exact: true }).first()).toBeVisible();
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json())?.user?.id;
  });
}

async function signIn(page, name, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByText(name, { exact: true }).first()).toBeVisible();
  return page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return (await response.json())?.user?.id;
  });
}

async function readWorkspace(page, memberId) {
  return page.evaluate(async (boundMemberId) => {
    const response = await fetch("/api/workspace", {
      credentials: "same-origin",
      cache: "no-store",
      headers: { "X-Forma-Member": boundMemberId },
    });
    return { status: response.status, body: await response.json() };
  }, memberId);
}

async function openProfile(page) {
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Profile", exact: true }).click();
}

async function installDelayedGetAndLostAck(page) {
  let releaseStaleRead;
  let staleReadCaptured;
  let staleReadCompleted;
  const staleReadReady = new Promise((resolve) => {
    staleReadCaptured = resolve;
  });
  const staleReadDone = new Promise((resolve) => {
    staleReadCompleted = resolve;
  });
  const holdStaleRead = new Promise((resolve) => {
    releaseStaleRead = resolve;
  });
  let heldFirstRead = false;
  const putBodies = [];

  await page.route("**/api/workspace", async (route) => {
    const request = route.request();
    if (request.method() === "GET" && !heldFirstRead) {
      heldFirstRead = true;
      const oldResponse = await route.fetch();
      staleReadCaptured();
      await holdStaleRead;
      await route.fulfill({ response: oldResponse });
      staleReadCompleted();
      return;
    }
    if (request.method() === "PUT") {
      putBodies.push(request.postData());
      if (putBodies.length === 1) {
        // Let the real API commit, then drop its acknowledgement. The client
        // must retry the same operation ID and normalized payload.
        const committedResponse = await route.fetch();
        expect(committedResponse.ok()).toBe(true);
        await route.abort("failed");
        return;
      }
    }
    await route.continue();
  });

  return {
    putBodies,
    staleReadReady,
    staleReadDone,
    releaseStaleRead,
  };
}

test("cloud conflict can be exported and explicitly reloaded without replacing the latest copy", async ({
  browser,
}) => {
  const run = stamp();
  const email = `conflict-${run}@example.test`;
  const contextA = await browser.newContext();
  const contextB = await browser.newContext();
  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();

  try {
    const memberId = await createAccount(pageA, "Conflict Member", email);
    expect(await signIn(pageB, "Conflict Member", email)).toBe(memberId);
    await openProfile(pageA);
    const base = await readWorkspace(pageA, memberId);
    expect(base.status).toBe(200);

    const cloudGoal = 6;
    const updated = {
      ...base.body.data,
      profile: { ...base.body.data.profile, goal: cloudGoal },
    };
    const cloudCommit = await pageB.evaluate(
      async ({ memberId, data, revision, operationId }) => {
        const response = await fetch("/api/workspace", {
          method: "PUT",
          credentials: "same-origin",
          headers: {
            "Content-Type": "application/json",
            "X-Forma-Member": memberId,
          },
          body: JSON.stringify({
            data: { ...data, revision: revision + 1 },
            expectedRevision: revision,
            operationId,
          }),
        });
        return { status: response.status, body: await response.json() };
      },
      {
        memberId,
        data: updated,
        revision: base.body.revision,
        operationId: `conflict-cloud-${run}`,
      },
    );
    expect(cloudCommit.status).toBe(200);

    const attemptedGoal = 2;
    await pageA.getByLabel("Weekly workout goal").evaluate((select, value) => {
      Object.getOwnPropertyDescriptor(
        HTMLSelectElement.prototype,
        "value",
      ).set.call(select, value);
      select.dispatchEvent(new Event("change", { bubbles: true }));
    }, String(attemptedGoal));
    await pageA
      .getByRole("button", { name: "Save changes", exact: true })
      .evaluate((button) => button.click());
    await expect(pageA.locator(".account-sync-alert")).toContainText(
      "Training data changed on another device",
    );
    await expect(
      pageA.getByText("Needs review", { exact: true }),
    ).toBeVisible();

    const attemptedDownload = pageA.waitForEvent("download");
    await pageA
      .getByRole("button", { name: "Export my unsynced changes" })
      .click();
    const download = await attemptedDownload;
    expect(download.suggestedFilename()).toBe("forma-unsynced-changes.json");
    const downloadPath = await download.path();
    const { readFile } = await import("node:fs/promises");
    const attempted = JSON.parse(await readFile(downloadPath, "utf8"));
    expect(attempted.profile.goal).toBe(attemptedGoal);
    expect((await readWorkspace(pageB, memberId)).body.data.profile.goal).toBe(
      cloudGoal,
    );

    await pageA
      .getByLabel(/I understand reloading replaces my unsynced edits/)
      .check();
    await pageA.getByRole("button", { name: "Reload cloud data" }).click();
    await expect(pageA.getByLabel("Weekly workout goal")).toHaveValue(
      String(cloudGoal),
    );
    const reloaded = await readWorkspace(pageA, memberId);
    expect(reloaded.status).toBe(200);
    expect(reloaded.body.data.profile.goal).toBe(cloudGoal);
    expect(reloaded.body.revision).toBe(cloudCommit.body.revision);
    await expect(
      pageA.getByRole("button", { name: "Reload cloud data" }),
    ).toHaveCount(0);
  } finally {
    await Promise.all([contextA.close(), contextB.close()]);
  }
});

test("lost save acknowledgement retries one operation and a stale refresh cannot roll it back", async ({
  page,
}) => {
  const run = stamp();
  const email = `retry-${run}@example.test`;
  const memberId = await createAccount(page, "Retry Member", email);
  await openProfile(page);
  const base = await readWorkspace(page, memberId);
  expect(base.status).toBe(200);

  const { putBodies, staleReadReady, staleReadDone, releaseStaleRead } =
    await installDelayedGetAndLostAck(page);
  try {
    // Capture an old real GET response, but deliver it only after the save has
    // been acknowledged. The repository must ignore this older revision.
    await page.evaluate(() => window.dispatchEvent(new Event("focus")));
    await staleReadReady;

    const nextGoal = 5;
    await page.getByLabel("Weekly workout goal").selectOption(String(nextGoal));
    await page
      .getByRole("button", { name: "Save changes", exact: true })
      .click();
    await expect(
      page.getByText("Profile and training goal saved.", { exact: true }),
    ).toBeVisible();
    expect(putBodies).toHaveLength(2);
    expect(JSON.parse(putBodies[0])).toEqual(JSON.parse(putBodies[1]));
    expect(JSON.parse(putBodies[0]).operationId).toMatch(/^account-goal-/);

    const committed = await readWorkspace(page, memberId);
    expect(committed.status).toBe(200);
    expect(committed.body.data.profile.goal).toBe(nextGoal);
    expect(committed.body.revision).toBe(base.body.revision + 1);

    releaseStaleRead();
    await staleReadDone;
    await page.evaluate(
      () => new Promise((resolve) => requestAnimationFrame(() => resolve())),
    );
    await expect(page.getByLabel("Weekly workout goal")).toHaveValue(
      String(nextGoal),
    );
    const final = await readWorkspace(page, memberId);
    expect(final.body.revision).toBe(committed.body.revision);
    expect(final.body.data.profile.goal).toBe(nextGoal);
  } finally {
    releaseStaleRead();
    await page.unroute("**/api/workspace");
  }
});
