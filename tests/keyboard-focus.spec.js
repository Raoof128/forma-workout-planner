import { test, expect } from "@playwright/test";

// A styling fixture avoids accessing an authenticated member workspace.
// The real account import uses this native file input and wrapper class.
test("account import wrapper shows keyboard focus around its transparent file input", async ({
  page,
}) => {
  await page.goto("/");
  await page.evaluate(() => {
    const fixture = document.createElement("section");
    fixture.innerHTML = `<button type="button" id="before-import">Before import</button>
      <label class="account-secondary account-import-label">Import workout backup
        <input type="file" accept="application/json,.json" />
      </label>`;
    document.querySelector("main").append(fixture);
  });
  await page.locator("#before-import").focus();
  await page.keyboard.press("Tab");
  const input = page.getByLabel("Import workout backup", { exact: true });
  await expect(input).toBeFocused();
  await expect(input).toHaveCSS("opacity", "0");
  const wrapper = page.locator(".account-import-label");
  await expect(wrapper).toHaveCSS("outline-style", "solid");
  await expect(wrapper).toHaveCSS("outline-width", "3px");
});
