import { expect, test } from "@playwright/test";

// End-to-end coverage for coach tokens: mint in Account › Security, read the
// summary with the bearer token, confirm it is owner-scoped, then revoke it.
// A full-access token also reads and edits the whole workspace.

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
    .getByRole("checkbox", { name: /agree to the Terms of Use/i })
    .check();
  await page
    .getByRole("checkbox", { name: /consent to FORMA storing/i })
    .check();
  await page
    .getByRole("button", { name: "Create account", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("verification link");
  const verification = await latestVerificationEmail(page.request, email);
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
  return { memberId: session.user?.id };
}

async function openSecurity(page) {
  await clickMainNavigation(page, "Account");
  await page.getByRole("button", { name: "Security", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Coach access" }),
  ).toBeVisible();
}

async function coachRead(request, token, query = "") {
  const response = await request.get(`/api/coach/workspace${query}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
    failOnStatusCode: false,
  });
  return {
    status: response.status(),
    cacheControl: response.headers()["cache-control"],
    body: await response.json().catch(() => null),
  };
}

test("a member mints a read-only coach token, a coach reads only that member, and revocation ends access", async ({
  browser,
}) => {
  // Two real registrations plus the token journey exceed the default budget.
  test.setTimeout(150_000);
  const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const contextA = await browser.newContext();
  const contextB = await browser.newContext();
  const coachContext = await browser.newContext();
  const pageA = await contextA.newPage();
  const pageB = await contextB.newPage();
  const coach = await coachContext.newPage();

  try {
    await registerAndSignIn(
      pageA,
      "Coach Alpha",
      `coach-a-${stamp}@example.test`,
    );
    await registerAndSignIn(
      pageB,
      "Coach Beta",
      `coach-b-${stamp}@example.test`,
    );
    await coach.goto("/");

    await openSecurity(pageA);
    await expect(pageA.getByText("No coach tokens yet")).toBeVisible();
    await pageA.getByLabel("Token name").fill("Claude coach");
    await pageA.getByRole("button", { name: "Create read-only token" }).click();

    const issued = pageA.getByRole("status").filter({
      hasText: "Copy this token now",
    });
    await expect(issued).toBeVisible();
    const token = (await issued.locator("pre").innerText()).trim();
    expect(token).toMatch(/^forma_coach_[A-Za-z0-9_-]{43}$/);
    // The list shows metadata only; the token itself appears nowhere else.
    const row = pageA.locator(".account-device-row").filter({
      hasText: "Claude coach",
    });
    await expect(row).toBeVisible();
    await expect(row).toContainText("Never used");
    await expect(row).toContainText("Expires");
    expect(await row.innerText()).not.toContain("forma_coach_");
    await pageA.getByRole("button", { name: "I’ve saved it" }).click();
    await expect(issued).toHaveCount(0);
    expect(await pageA.content()).not.toContain(token);

    // An anonymous client with the bearer token reads Alpha's summary only.
    const read = await coachRead(coach.request, token, "?days=28");
    expect(read.status).toBe(200);
    expect(read.cacheControl).toContain("no-store");
    expect(read.body.member.name).toBe("Coach Alpha");
    expect(read.body.days).toBe(28);
    expect(Array.isArray(read.body.routines)).toBe(true);
    expect(read.body.routines.length).toBeGreaterThan(0);
    expect(read.body.sessions).toEqual([]);
    const serialised = JSON.stringify(read.body);
    expect(serialised).not.toContain(`coach-a-${stamp}@example.test`);
    expect(serialised).not.toContain("Coach Beta");
    for (const key of ["email", "revision", "operationId", "userId"])
      expect(serialised).not.toContain(`"${key}"`);

    // Without the token, or with Beta's own signed-in cookies, the route is closed.
    expect((await coachRead(coach.request, null)).status).toBe(401);
    expect((await coachRead(pageB.request, null)).status).toBe(401);
    expect((await coachRead(coach.request, token, "?days=0")).status).toBe(400);
    // The route is strictly GET.
    const write = await coach.request.put("/api/coach/workspace", {
      headers: { authorization: `Bearer ${token}` },
      data: {},
      failOnStatusCode: false,
    });
    // 405 at the Worker allowlist; 403 from the origin Origin check in dev.
    expect([403, 404, 405]).toContain(write.status());
    // The token is not a session: member routes refuse it.
    const asSession = await coach.request.get("/api/workspace", {
      headers: { authorization: `Bearer ${token}` },
      failOnStatusCode: false,
    });
    expect(asSession.status()).toBe(401);

    // Beta cannot see or revoke Alpha's token.
    await openSecurity(pageB);
    await expect(pageB.getByText("No coach tokens yet")).toBeVisible();

    // Alpha sees the last use and revokes; the coach loses access at once.
    await pageA.getByRole("button", { name: "Profile", exact: true }).click();
    await openSecurity(pageA);
    await expect(row).toContainText("Last used");
    pageA.once("dialog", (dialog) => dialog.accept());
    await row.getByRole("button", { name: "Revoke" }).click();
    await expect(pageA.getByText("No coach tokens yet")).toBeVisible();
    expect((await coachRead(coach.request, token)).status).toBe(401);
  } finally {
    await contextA.close();
    await contextB.close();
    await coachContext.close();
  }
});

test("a full-access coach token reads the whole workspace and its edits reach the member's app", async ({
  browser,
}) => {
  test.setTimeout(150_000);
  const stamp = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const memberContext = await browser.newContext();
  const coachContext = await browser.newContext();
  const page = await memberContext.newPage();
  const coach = await coachContext.newPage();
  try {
    await registerAndSignIn(
      page,
      "Coach Gamma",
      `coach-c-${stamp}@example.test`,
    );
    await coach.goto("/");
    await openSecurity(page);
    await page.getByLabel("Token name").fill("Claude full coach");
    await page
      .getByRole("radio", { name: "Full access: read and edit" })
      .check();
    await page
      .getByRole("button", { name: "Create full-access token" })
      .click();
    const issued = page.getByRole("status").filter({
      hasText: "Copy this token now",
    });
    await expect(issued).toContainText("read and change your routines");
    const token = (await issued.locator("pre").innerText()).trim();
    await page.getByRole("button", { name: "I’ve saved it" }).click();
    await expect(
      page.locator(".account-device-row").filter({
        hasText: "Claude full coach",
      }),
    ).toContainText("Full access");
    // The form returns to the least-privilege choice for the next token.
    await expect(page.getByRole("radio", { name: "Read only" })).toBeChecked();

    const headers = { authorization: `Bearer ${token}` };
    const summary = await coachRead(coach.request, token);
    expect(summary.body.access).toBe("full");
    const full = await coach.request.get("/api/coach/workspace/data", {
      headers,
    });
    expect(full.status()).toBe(200);
    const workspace = await full.json();
    expect(workspace.data.profile.name).toBe("Coach Gamma");
    expect(JSON.stringify(workspace)).not.toContain(
      `coach-c-${stamp}@example.test`,
    );

    // The coach renames the first routine and plans the week, from a client
    // that sends no browser Origin.
    const routines = workspace.data.routines.map((routine, index) =>
      index === 0 ? { ...routine, name: "Coach planned upper" } : routine,
    );
    const edit = await coach.request.patch("/api/coach/workspace/data", {
      headers,
      data: {
        expectedRevision: workspace.revision,
        operationId: `coach-edit-${stamp}`,
        changes: { routines, schedule: [0, 2, 4] },
      },
      failOnStatusCode: false,
    });
    expect(edit.status(), await edit.text()).toBe(200);
    expect((await edit.json()).revision).toBe(workspace.revision + 1);

    await page.reload();
    await clickMainNavigation(page, "My routines");
    await expect(
      page.locator(".routine-card").filter({ hasText: "Coach planned upper" }),
    ).toBeVisible();
    // Account actions stay out of reach of any coach token.
    const accountRoute = await coach.request.get("/api/account/coach-tokens", {
      headers,
      failOnStatusCode: false,
    });
    expect([401, 403]).toContain(accountRoute.status());
  } finally {
    await memberContext.close();
    await coachContext.close();
  }
});
