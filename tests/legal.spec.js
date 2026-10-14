import { test, expect } from "@playwright/test";
import { createRequire } from "node:module";
import { settlePage } from "./helpers.js";

const require = createRequire(import.meta.url);
const axePath = require.resolve("axe-core/axe.min.js");

const documents = [
  {
    hash: "privacy",
    title: "Privacy Policy",
    link: "Privacy",
    sections: [
      "Who we are",
      "What we collect",
      "Disclosure outside Australia",
      "Access and correction",
      "Complaints",
    ],
  },
  {
    hash: "terms",
    title: "Terms of Use",
    link: "Terms",
    sections: [
      "Eligibility",
      "Health and safety",
      "Your rights under the Australian Consumer Law",
      "Governing law",
    ],
  },
];

for (const document of documents) {
  test(`${document.title} is reachable, complete, and accessible`, async ({
    page,
  }) => {
    await page.goto("/");
    await page.setViewportSize({ width: 1280, height: 900 });
    await page
      .getByRole("navigation", { name: "Legal" })
      .getByRole("link", { name: document.link })
      .click();
    await expect(page).toHaveURL(new RegExp(`#${document.hash}$`));
    await expect(
      page.getByRole("heading", { level: 1, name: document.title }),
    ).toBeVisible();
    await expect(page).toHaveTitle(`${document.title} · FORMA`);
    for (const section of document.sections)
      await expect(
        page.getByRole("heading", { level: 2, name: section }),
      ).toBeVisible();
    await expect(page.locator(".legal-meta")).toContainText("Effective");

    await settlePage(page);
    await page.addScriptTag({ path: axePath });
    const violations = await page.evaluate(async () => {
      const result = await window.axe.run(document.querySelector("main"), {
        runOnly: {
          type: "tag",
          values: ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"],
        },
      });
      return result.violations.map((v) => `${v.id}: ${v.nodes.length}`);
    });
    expect(violations).toEqual([]);
  });
}

test("legal pages open directly by URL and fit a phone screen", async ({
  page,
}) => {
  await page.setViewportSize({ width: 360, height: 780 });
  for (const document of documents) {
    await page.goto(`/#${document.hash}`);
    await expect(
      page.getByRole("heading", { level: 1, name: document.title }),
    ).toBeVisible();
    const overflow = await page.evaluate(
      () =>
        window.document.documentElement.scrollWidth >
        window.document.documentElement.clientWidth,
    );
    expect(overflow).toBe(false);
  }
});

for (const document of documents) {
  test(`${document.title} contents moves keyboard focus to the selected section`, async ({
    page,
  }) => {
    await page.goto(`/#${document.hash}`);
    const section = document.sections.at(-1);
    const link = page
      .getByRole("navigation", { name: `${document.title} contents` })
      .getByRole("link", { name: section, exact: true });
    await link.focus();
    await page.keyboard.press("Enter");
    await expect(
      page.getByRole("heading", { level: 2, name: section, exact: true }),
    ).toBeFocused();
    await expect(page).toHaveURL(new RegExp(`#${document.hash}$`));
  });
}

test("legal contents avoids animated scrolling when reduced motion is requested", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/#privacy");
  await page.evaluate(() => {
    window.legalScrollCalls = [];
    const scroll = Element.prototype.scrollIntoView;
    Element.prototype.scrollIntoView = function (options) {
      window.legalScrollCalls.push(options);
      return scroll.call(this, options);
    };
  });
  const link = page
    .getByRole("navigation", { name: "Privacy Policy contents" })
    .getByRole("link", { name: "Complaints", exact: true });
  await link.focus();
  await page.keyboard.press("Enter");
  await expect
    .poll(() => page.evaluate(() => window.legalScrollCalls.at(-1)?.behavior))
    .toBe("auto");
  await expect(
    page.getByRole("heading", { level: 2, name: "Complaints", exact: true }),
  ).toBeFocused();
});
