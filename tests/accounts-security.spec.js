import { expect, test } from "@playwright/test";

const emailSink = "http://127.0.0.1:3002/emails";
const password = "FORMA-local-test-passphrase-2026";

async function clickMainNavigation(page, name) {
  const item = page.getByRole("button", { name, exact: true });
  const toggle = page.getByRole("button", { name: "Toggle navigation" });
  await expect
    .poll(async () => (await item.isVisible()) || (await toggle.isVisible()))
    .toBe(true);
  if (
    (await toggle.isVisible()) &&
    (await toggle.getAttribute("aria-expanded")) !== "true"
  ) {
    await toggle.click();
  }
  await item.scrollIntoViewIfNeeded();
  await item.click();
}

async function latestVerificationEmail(request, email) {
  await expect
    .poll(async () => {
      const response = await request.get(
        `${emailSink}?email=${encodeURIComponent(email)}`,
      );
      if (!response.ok()) return [];
      return response.json();
    })
    .toEqual(
      expect.arrayContaining([
        expect.objectContaining({ kind: "verify-email", email }),
      ]),
    );
  const response = await request.get(
    `${emailSink}?email=${encodeURIComponent(email)}`,
  );
  const emails = await response.json();
  return emails.filter((item) => item.kind === "verify-email").at(-1);
}

async function registerAndSignIn(page, name, email) {
  await page.goto("/");
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: /create account/i }).click();
  await page.getByLabel("Display name").fill(name);
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("verification link");

  const verification = await latestVerificationEmail(page.request, email);
  expect(verification.url).toBeTruthy();
  const url = new URL(verification.url);
  expect(url.origin).toBe(new URL(page.url()).origin);
  await page.goto(verification.url);

  await clickMainNavigation(page, "Account");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel(/^Password/).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByText(name, { exact: true }).first()).toBeVisible();
  const session = await page.evaluate(async () => {
    const response = await fetch("/api/auth/get-session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    return response.json();
  });
  const memberId = session.user?.id;
  expect(memberId).toMatch(/^mem_[A-Za-z0-9_-]+$/);
  return { memberId };
}

async function workspaceRequest(page, memberId, method = "GET", body) {
  return page.evaluate(
    async ({ memberId, method, body }) => {
      const response = await fetch("/api/workspace", {
        method,
        headers: {
          ...(memberId ? { "X-Forma-Member": memberId } : {}),
          ...(body ? { "content-type": "application/json" } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        credentials: "same-origin",
      });
      return {
        status: response.status,
        cacheControl: response.headers.get("cache-control"),
        body: await response.json().catch(() => null),
      };
    },
    { memberId, method, body },
  );
}

async function privateExport(page, memberId) {
  return page.evaluate(async (memberId) => {
    const response = await fetch("/api/workspace/export", {
      credentials: "same-origin",
      headers: memberId ? { "X-Forma-Member": memberId } : {},
    });
    return {
      status: response.status,
      cacheControl: response.headers.get("cache-control"),
      body: await response.json().catch(() => null),
    };
  }, memberId);
}

test("authenticated workspace reads and writes are isolated between real members", async ({
  browser,
}) => {
  const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const emailA = `security-a-${stamp}@example.test`;
  const emailB = `security-b-${stamp}@example.test`;
  const contextA = await browser.newContext();
  const contextB = await browser.newContext();
  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();
  const anonymous = await browser.newContext();
  const anonymousPage = await anonymous.newPage();

  try {
    await anonymousPage.goto("/");
    const accountA = await registerAndSignIn(pageA, "Member Alpha", emailA);
    const accountB = await registerAndSignIn(pageB, "Member Beta", emailB);

    const anonRead = await workspaceRequest(anonymousPage, null);
    expect(anonRead.status).toBe(401);
    expect(JSON.stringify(anonRead.body)).not.toContain("Member Alpha");
    expect(JSON.stringify(anonRead.body)).not.toContain("Member Beta");

    const firstA = await workspaceRequest(pageA, accountA.memberId);
    const firstB = await workspaceRequest(pageB, accountB.memberId);
    expect(firstA.status).toBe(200);
    expect(firstB.status).toBe(200);
    expect(firstA.cacheControl).toContain("no-store");
    expect(firstB.cacheControl).toContain("no-store");
    expect(firstA.body.data.profile.name).toBe("Member Alpha");
    expect(firstB.body.data.profile.name).toBe("Member Beta");
    expect(firstA.body.data.profile.name).not.toBe(
      firstB.body.data.profile.name,
    );

    const ownedA = {
      ...firstA.body.data,
      profile: { ...firstA.body.data.profile, goal: 5 },
      routines: firstA.body.data.routines.map((routine, index) =>
        index === 0 ? { ...routine, name: "Alpha private routine" } : routine,
      ),
    };
    const savedA = await workspaceRequest(pageA, accountA.memberId, "PUT", {
      data: ownedA,
      expectedRevision: firstA.body.revision,
      operationId: `alpha-${stamp}`,
    });
    expect(savedA.status).toBe(200);
    expect(savedA.body.revision).toBe(firstA.body.revision + 1);

    const csrfAttempt = await pageA.request.post(
      `${new URL(pageA.url()).origin}/api/workspace`,
      {
        headers: {
          origin: "https://attacker.example",
          "content-type": "application/json",
          "x-forma-worker-secret": "browser-forgery-must-not-be-trusted",
          "x-forma-member": accountA.memberId,
        },
        data: {
          data: {
            ...firstA.body.data,
            profile: { ...firstA.body.data.profile, goal: 1 },
          },
          expectedRevision: firstA.body.revision,
          operationId: `csrf-${stamp}`,
        },
      },
    );
    expect(csrfAttempt.status()).toBe(403);

    const forgedOwner = await workspaceRequest(
      pageB,
      accountB.memberId,
      "PUT",
      {
        data: {
          ...firstB.body.data,
          profile: { ...firstB.body.data.profile, goal: 7 },
        },
        expectedRevision: firstB.body.revision,
        operationId: `beta-owner-forgery-${stamp}`,
        ownerId: firstA.body.data.profile.name,
        userId: firstA.body.data.profile.name,
      },
    );
    expect(forgedOwner.status).toBe(400);

    const afterA = await workspaceRequest(pageA, accountA.memberId);
    const afterB = await workspaceRequest(pageB, accountB.memberId);
    expect(afterA.body.data.profile.goal).toBe(5);
    expect(afterA.body.data.routines[0].name).toBe("Alpha private routine");
    expect(afterA.body.revision).toBe(savedA.body.revision);
    expect(afterB.body.data.profile.name).toBe("Member Beta");
    expect(afterB.body.data.routines[0].name).toBe(
      firstB.body.data.routines[0].name,
    );
    expect(afterB.body.data.profile.goal).toBe(firstB.body.data.profile.goal);

    const exportedA = await privateExport(pageA, accountA.memberId);
    expect(exportedA.status).toBe(200);
    expect(exportedA.cacheControl).toContain("no-store");
    expect(exportedA.body.profile.name).toBe("Member Alpha");
    expect(exportedA.body.routines[0].name).toBe("Alpha private routine");
    expect(JSON.stringify(exportedA.body)).not.toContain("Member Beta");

    const noCookieExport = await anonymousPage.evaluate(async () => {
      const response = await fetch("/api/workspace/export");
      return response.status;
    });
    expect(noCookieExport).toBe(401);
    const memberCookies = await contextA.cookies();
    const sessionCookies = memberCookies.filter((cookie) =>
      /session/i.test(cookie.name),
    );
    expect(sessionCookies.length).toBeGreaterThan(0);
    const tamperedContext = await browser.newContext();
    const tamperedPage = await tamperedContext.newPage();
    await tamperedPage.goto(new URL("/", pageA.url()).href);
    await tamperedContext.addCookies(
      sessionCookies.map((cookie) => ({
        ...cookie,
        value: "tampered-session-token",
      })),
    );
    const tamperedRead = await workspaceRequest(
      tamperedPage,
      accountA.memberId,
    );
    expect(tamperedRead.status).toBe(401);
    await tamperedContext.close();

    await pageA.reload();
    await clickMainNavigation(pageA, "Account");
    await pageA
      .getByRole("button", { name: "Training data", exact: true })
      .click();
    await expect(
      pageA.getByText("Alpha private routine", { exact: true }),
    ).toBeVisible();
    await pageA.getByRole("button", { name: "Profile", exact: true }).click();
    await pageA.getByLabel("Weekly workout goal").selectOption("4");

    // Both tabs share one cookie jar. Tab A keeps its captured member ID and
    // loaded private data while tab B signs out A and signs in as B.
    const switchTab = await contextA.newPage();
    await switchTab.goto("/");
    await clickMainNavigation(switchTab, "Account");
    await switchTab
      .getByRole("button", { name: "Privacy", exact: true })
      .click();
    await switchTab
      .getByRole("button", { name: "Sign out", exact: true })
      .click();
    await switchTab.getByLabel("Email address").fill(emailB);
    await switchTab.getByLabel(/^Password/).fill(password);
    await switchTab
      .getByRole("button", { name: "Sign in", exact: true })
      .click();
    await expect(
      switchTab.getByText("Member Beta", { exact: true }).first(),
    ).toBeVisible();
    const betaInSharedContext = await switchTab.evaluate(async () => {
      const response = await fetch("/api/auth/get-session", {
        credentials: "same-origin",
        cache: "no-store",
      });
      const session = await response.json();
      return session.user?.id;
    });
    expect(betaInSharedContext).toBe(accountB.memberId);

    const staleRead = await workspaceRequest(pageA, accountA.memberId);
    const staleExport = await privateExport(pageA, accountA.memberId);
    const staleWrite = await workspaceRequest(pageA, accountA.memberId, "PUT", {
      data: {
        ...firstA.body.data,
        profile: { ...firstA.body.data.profile, goal: 6 },
      },
      expectedRevision: firstA.body.revision,
      operationId: `old-tab-${stamp}`,
    });
    const staleSessions = await pageA.evaluate(async (memberId) => {
      const response = await fetch("/api/account/sessions", {
        credentials: "same-origin",
        headers: { "X-Forma-Member": memberId },
      });
      return { status: response.status, body: await response.json() };
    }, accountA.memberId);
    for (const response of [
      staleRead,
      staleExport,
      staleWrite,
      staleSessions,
    ]) {
      expect(response.status).toBe(409);
      expect(response.body).toEqual({ error: "account_changed" });
      expect(response.body).not.toHaveProperty("data");
    }

    // Click the real stale form control without foregrounding tab A first.
    // This exercises the request made from A's cached workspace and old ID.
    await pageA.evaluate(() => {
      const button = [...document.querySelectorAll("button")].find((item) =>
        item.textContent?.includes("Save changes"),
      );
      button?.click();
    });
    await expect(
      pageA.getByText("Member Beta", { exact: true }).first(),
    ).toBeVisible();
    await clickMainNavigation(pageA, "Account");
    await pageA.getByRole("button", { name: "Profile", exact: true }).click();
    await expect(pageA.getByLabel("Display name")).toHaveValue("Member Beta");
    await pageA
      .getByRole("button", { name: "Training data", exact: true })
      .click();
    await expect(
      pageA.getByText("Alpha private routine", { exact: true }),
    ).toHaveCount(0);

    const betaAfterOldWrite = await workspaceRequest(
      switchTab,
      accountB.memberId,
    );
    expect(betaAfterOldWrite.status).toBe(200);
    expect(betaAfterOldWrite.body.data.profile.name).toBe("Member Beta");
    expect(betaAfterOldWrite.body.data.profile.goal).toBe(
      firstB.body.data.profile.goal,
    );

    await switchTab
      .getByRole("button", { name: "Privacy", exact: true })
      .click();
    await switchTab
      .getByRole("button", { name: "Sign out", exact: true })
      .click();
    await expect
      .poll(() =>
        switchTab.evaluate(async () => {
          const response = await fetch("/api/auth/get-session", {
            credentials: "same-origin",
            cache: "no-store",
          });
          return (await response.json())?.user?.id ?? null;
        }),
      )
      .toBeNull();
    const loggedOutRead = await workspaceRequest(switchTab, accountB.memberId);
    expect(loggedOutRead.status).toBe(401);
    expect(JSON.stringify(loggedOutRead.body)).not.toContain("Member Beta");
  } finally {
    await Promise.all([contextA.close(), contextB.close(), anonymous.close()]);
  }
});
