import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const recoveryBackup = (name) => {
  const backup = structuredClone(initialData);
  backup.profile.name = name;
  return backup;
};

const currentData = (page) =>
  page.evaluate(() => JSON.parse(localStorage.getItem("forma-v1")));

const uploadRecoveryBackup = async (page, name) => {
  await page.getByLabel("Restore recovery backup").setInputFiles({
    name: `${name.replaceAll(" ", "-")}.json`,
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup(name))),
  });
};

test("a valid backup reviewed before another tab saves is rejected without replacing current data", async ({
  page,
  context,
}) => {
  await page.goto("/#settings");
  await expect.poll(async () => (await currentData(page))?.revision).toBe(0);
  const other = await context.newPage();
  await other.goto("/#settings");

  await page.getByLabel("Import backup").setInputFiles({
    name: "reviewed-backup.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup("Restore candidate"))),
  });
  await expect(page.getByRole("dialog")).toContainText("Restore this backup?");

  await other.getByLabel("Your name").fill("Saved in other tab");
  await other
    .getByRole("button", { name: "Save preferences", exact: true })
    .click();
  await expect
    .poll(async () => (await currentData(page)).profile.name)
    .toBe("Saved in other tab");
  const beforeRestore = await currentData(page);

  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();
  await expect(page.getByRole("dialog").getByRole("alert")).toContainText(
    "saved data changed while reviewing this backup",
  );
  expect(await currentData(page)).toEqual(beforeRestore);
  expect(
    await page.evaluate(() =>
      Object.keys(localStorage).filter((key) =>
        key.startsWith("forma-v1-recovery-"),
      ),
    ),
  ).toHaveLength(0);
});

test("corrupt-data recovery refuses to replace a newer restore from another tab", async ({
  page,
  context,
}) => {
  await page.goto("/");
  await page.evaluate(() =>
    localStorage.setItem("forma-v1", "broken original data"),
  );
  await page.addInitScript(() => {
    window.addEventListener(
      "storage",
      (event) => {
        if (event.key === "forma-v1") event.stopImmediatePropagation();
      },
      true,
    );
    const readFile = File.prototype.text;
    Object.defineProperty(File.prototype, "text", {
      configurable: true,
      value() {
        if (this.name !== "stale-tab-backup.json") return readFile.call(this);
        return new Promise((resolve) => {
          window.__fileReadStarted = true;
          window.__releaseBackupRead = () => readFile.call(this).then(resolve);
        });
      },
    });
  });
  await page.reload();
  await expect(
    page.getByRole("heading", { name: "Your saved data needs attention." }),
  ).toBeVisible();

  const staleImport = page.getByLabel("Restore recovery backup").setInputFiles({
    name: "stale-tab-backup.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup("Stale tab restore"))),
  });
  await expect
    .poll(() => page.evaluate(() => window.__fileReadStarted))
    .toBe(true);

  const other = await context.newPage();
  await other.goto("/");
  await expect(
    other.getByRole("heading", { name: "Your saved data needs attention." }),
  ).toBeVisible();
  await uploadRecoveryBackup(other, "Newer tab restore");
  await expect(other.locator(".hero")).toBeVisible();
  const newer = await currentData(other);
  expect(newer.profile.name).toBe("Newer tab restore");

  await page.evaluate(() => window.__releaseBackupRead());
  await staleImport;
  await expect(page.locator(".hero")).toBeVisible();
  expect(await currentData(page)).toEqual(newer);
  const preservedOriginals = await page.evaluate(() =>
    Object.keys(localStorage)
      .filter((key) => key.startsWith("forma-v1-recovery-"))
      .map((key) => localStorage.getItem(key)),
  );
  expect(preservedOriginals).toContain("broken original data");
});

test("the latest selected backup keeps its preview when an earlier file read finishes later", async ({
  page,
}) => {
  await page.addInitScript(() => {
    const readText = File.prototype.text;
    Object.defineProperty(File.prototype, "text", {
      configurable: true,
      value() {
        if (this.name !== "slow-backup-a.json") return readText.call(this);
        return new Promise((resolve) => {
          window.__slowReadStarted = true;
          window.__releaseSlowRead = () => readText.call(this).then(resolve);
        });
      },
    });
  });
  await page.goto("/#settings");
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("forma-v1")))
    .not.toBeNull();
  const input = page.getByLabel("Import backup", { exact: true });
  await input.setInputFiles({
    name: "slow-backup-a.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup("Backup A"))),
  });
  await expect
    .poll(() => page.evaluate(() => window.__slowReadStarted))
    .toBe(true);

  await input.setInputFiles({
    name: "fast-backup-b.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup("Backup B"))),
  });
  await expect(page.getByRole("dialog")).toContainText("fast-backup-b.json");
  await page.evaluate(() => window.__releaseSlowRead());
  await expect(page.getByRole("dialog")).toContainText("fast-backup-b.json");
  await expect(page.getByRole("dialog")).not.toContainText(
    "slow-backup-a.json",
  );
  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();
  await expect(page.locator(".hero")).toBeVisible();
  expect((await currentData(page)).profile.name).toBe("Backup B");
  await page.reload();
  await expect(page.locator(".profile-button")).toContainText("Backup B");
  expect((await currentData(page)).profile.name).toBe("Backup B");
});

test("a late invalid import cannot clear the latest valid backup or add its error", async ({
  page,
}) => {
  await page.addInitScript(() => {
    const readText = File.prototype.text;
    Object.defineProperty(File.prototype, "text", {
      configurable: true,
      value() {
        if (this.name !== "slow-invalid-a.json") return readText.call(this);
        return new Promise((resolve) => {
          window.__slowReadStarted = true;
          window.__releaseSlowRead = () => readText.call(this).then(resolve);
        });
      },
    });
  });
  await page.goto("/#settings");
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("forma-v1")))
    .not.toBeNull();
  const input = page.getByLabel("Import backup", { exact: true });
  await input.setInputFiles({
    name: "slow-invalid-a.json",
    mimeType: "application/json",
    buffer: Buffer.from("not valid JSON"),
  });
  await expect
    .poll(() => page.evaluate(() => window.__slowReadStarted))
    .toBe(true);

  await input.setInputFiles({
    name: "fast-valid-b.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(recoveryBackup("Backup B"))),
  });
  await expect(page.getByRole("dialog")).toContainText("fast-valid-b.json");
  await page.evaluate(() => window.__releaseSlowRead());
  await expect(page.getByRole("dialog")).toContainText("fast-valid-b.json");
  await expect(page.getByRole("dialog").getByRole("alert")).toHaveCount(0);
  await page
    .getByRole("button", { name: "Restore backup", exact: true })
    .click();
  await expect(page.locator(".hero")).toBeVisible();
  expect((await currentData(page)).profile.name).toBe("Backup B");
  await page.reload();
  await expect(page.locator(".profile-button")).toContainText("Backup B");
  expect((await currentData(page)).profile.name).toBe("Backup B");
});
