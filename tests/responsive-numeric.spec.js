import { test, expect } from "@playwright/test";
import { initialData } from "../src/data.js";

const fixedTime = "2026-11-04T09:00:00.000Z";

function numericFixture() {
  const data = structuredClone(initialData);
  data.profile.name = "Numeric layout audit";
  data.history = [];
  data.active = {
    id: "numeric-layout-session",
    routineId: data.routines[0].id,
    name: "Numeric layout audit",
    startedAt: Date.parse(fixedTime) - 900_000,
    notes: "",
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    exercises: [
      {
        entryId: "numeric-bench",
        exerciseId: "bench",
        sets: [{ weight: 999.5, reps: 100, rpe: 9.5, done: false }],
      },
      {
        entryId: "numeric-row",
        exerciseId: "row",
        perSide: true,
        sets: [
          {
            weight: 999.5,
            reps: 100,
            sides: { left: 50, right: 50 },
            rpe: 9.5,
            done: false,
          },
        ],
      },
      {
        entryId: "numeric-cardio",
        exerciseId: "db-running-treadmill",
        sets: [
          {
            weight: 0,
            reps: 1,
            durationSeconds: 86400,
            distanceMeters: 1000000,
            rpe: 9.5,
            done: false,
          },
        ],
      },
      {
        entryId: "numeric-plank",
        exerciseId: "db-plank",
        sets: [
          {
            weight: 0,
            reps: 1,
            durationSeconds: 86400,
            rpe: 9.5,
            done: false,
          },
        ],
      },
    ],
  };
  return data;
}

async function numericGeometry(card) {
  return card.evaluate((node) => {
    const row = node.querySelector(".set-row:not(.set-labels)");
    const rowBounds = row.getBoundingClientRect();
    const button = row.querySelector(".check-set");
    const done = button.getBoundingClientRect();
    const hit = document.elementFromPoint(
      done.x + done.width / 2,
      done.y + done.height / 2,
    );
    const fields = [...row.querySelectorAll("input")].map((input) => {
      const style = getComputedStyle(input);
      const mirror = document.createElement("span");
      Object.assign(mirror.style, {
        position: "fixed",
        left: "0",
        top: "-10000px",
        display: "inline-block",
        width: "max-content",
        whiteSpace: "pre",
        margin: "0",
        padding: "0",
        border: "0",
      });
      // A composite font shorthand can leave canvas on its fallback font.
      // Measure the actual loaded face and numeric features in the DOM instead.
      for (const property of [
        "fontFamily",
        "fontSize",
        "fontWeight",
        "fontStyle",
        "fontStretch",
        "fontVariantNumeric",
        "fontFeatureSettings",
        "fontVariationSettings",
        "fontOpticalSizing",
        "fontKerning",
        "fontSynthesis",
        "letterSpacing",
        "textTransform",
        "direction",
      ])
        mirror.style[property] = style[property];
      mirror.textContent = input.value;
      document.body.append(mirror);
      const textWidth = mirror.getBoundingClientRect().width;
      mirror.remove();
      const bounds = input.getBoundingClientRect();
      const contentWidth =
        bounds.width -
        parseFloat(style.paddingLeft) -
        parseFloat(style.paddingRight) -
        parseFloat(style.borderLeftWidth) -
        parseFloat(style.borderRightWidth);
      return {
        label: input.getAttribute("aria-label"),
        value: input.value,
        fontFamily: style.fontFamily,
        fontSize: style.fontSize,
        width: bounds.width,
        height: bounds.height,
        textWidth,
        contentWidth,
        clipped: textWidth > contentWidth + 0.5,
      };
    });
    return {
      fields,
      rowOverflow: row.scrollWidth > row.clientWidth + 1,
      pageOverflow:
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth + 1,
      doneWidth: done.width,
      doneHeight: done.height,
      doneWithinRow:
        done.left >= rowBounds.left - 0.5 &&
        done.right <= rowBounds.right + 0.5,
      doneWithinViewport:
        done.left >= 0 &&
        done.right <= innerWidth &&
        done.top >= 0 &&
        done.bottom <= innerHeight,
      doneHit: !!hit && button.contains(hit),
    };
  });
}

for (const width of [320, 360])
  test(`numeric workout values remain readable and Done stays reachable at ${width}px`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.clock.setFixedTime(new Date(fixedTime));
    await page.addInitScript(
      (data) => localStorage.setItem("forma-v1", JSON.stringify(data)),
      numericFixture(),
    );
    await page.goto("/#workout");
    const cards = page.locator(".log-exercise");
    await expect(cards).toHaveCount(4);
    const loadedFont = await page.evaluate(async () => {
      await document.fonts.ready;
      return [...document.fonts].some(
        (font) => font.family.includes("DM Sans") && font.status === "loaded",
      );
    });
    expect(loadedFont).toBe(true);
    const values = [
      ["999.5", "100", "9.5"],
      ["999.5", "50", "50", "9.5"],
      ["86400", "1000000", "9.5"],
      ["86400", "9.5"],
    ];
    for (const [index, expectedValues] of values.entries()) {
      const card = cards.nth(index);
      for (const focused of [false, true]) {
        if (focused) {
          const field = card
            .locator(".set-row:not(.set-labels) input")
            .nth(index === 2 ? 1 : 0);
          await field.focus();
          await expect(field).toBeFocused();
        } else await page.locator("main h1").focus();
        await card.scrollIntoViewIfNeeded();
        const geometry = await numericGeometry(card);
        expect(geometry.fields.map((field) => field.value)).toEqual(
          expectedValues,
        );
        expect(geometry.fields.filter((field) => field.clipped)).toEqual([]);
        for (const field of geometry.fields) {
          expect(field.fontFamily).toContain("DM Sans");
          expect(field.fontSize).toBe("16px");
          expect(field.width).toBeGreaterThanOrEqual(24);
          expect(field.height).toBeGreaterThanOrEqual(44);
        }
        expect(geometry.rowOverflow).toBe(false);
        expect(geometry.pageOverflow).toBe(false);
        expect(geometry.doneWidth).toBe(44);
        expect(geometry.doneHeight).toBe(44);
        expect(geometry.doneWithinRow).toBe(true);
        expect(geometry.doneWithinViewport).toBe(true);
        expect(geometry.doneHit).toBe(true);
      }
    }
  });
