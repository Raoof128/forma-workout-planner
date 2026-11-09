/* global window, document, PerformanceObserver, performance, requestAnimationFrame, URL, innerHeight, structuredClone, localStorage */
import process from "node:process";
import { mkdir, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { chromium } from "@playwright/test";
import { initialData } from "../../../../src/data.js";

const mode = process.argv[2] || "production";
if (!["production", "react"].includes(mode))
  throw new Error("Choose production or react measurement mode.");
const output =
  process.env.FORMA_PERFORMANCE_OUTPUT || "/tmp/forma-web-performance-20261104";
const origins = {
  before: process.env.FORMA_BEFORE_ORIGIN || "http://127.0.0.1:4174",
  after: process.env.FORMA_AFTER_ORIGIN || "http://127.0.0.1:4173",
};
for (const [phase, origin] of Object.entries(origins)) {
  const url = new URL(origin);
  if (
    url.protocol !== "http:" ||
    !["127.0.0.1", "localhost"].includes(url.hostname)
  )
    throw new Error(
      "This audit harness accepts local loopback HTTP origins only.",
    );
  origins[phase] = url.origin;
}
await mkdir(output, { recursive: true });
const results = [];
const browser = await chromium.launch();
const receipt = {
  mode,
  browser: await browser.version(),
  createdAt: new Date().toISOString(),
  origins,
  results,
  limitations: [
    "Local synthetic lab samples; no field/p75 Core Web Vitals or physical-device claim.",
    "Click-to-paint samples include two animation frames; they are not field INP.",
    "React development profiling has overhead and is separate from production timings.",
  ],
};
const frame = (page) =>
  page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );
async function observe(page) {
  await page.addInitScript(() => {
    window.auditMetrics = {
      lcp: [],
      shifts: [],
      longTasks: [],
      events: [],
      clicks: [],
    };
    for (const [type, key] of [
      ["largest-contentful-paint", "lcp"],
      ["layout-shift", "shifts"],
      ["longtask", "longTasks"],
      ["event", "events"],
    ]) {
      if (!PerformanceObserver.supportedEntryTypes.includes(type)) continue;
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          window.auditMetrics[key].push({
            startTime: entry.startTime,
            duration: entry.duration,
            value: entry.value,
            hadRecentInput: entry.hadRecentInput,
            interactionId: entry.interactionId,
            name: entry.name,
            size: entry.size,
            element: entry.element?.tagName,
          });
        }
      }).observe({
        type,
        buffered: true,
        ...(type === "event" ? { durationThreshold: 16 } : {}),
      });
    }
    document.addEventListener(
      "click",
      (event) => {
        if (!event.isTrusted) return;
        const started = performance.now();
        const label = event.target
          .closest("button,a")
          ?.textContent.trim()
          .slice(0, 80);
        requestAnimationFrame(() =>
          requestAnimationFrame(() =>
            window.auditMetrics.clicks.push({
              label,
              duration: performance.now() - started,
            }),
          ),
        );
      },
      true,
    );
  });
}
async function navigate(page, name) {
  const toggle = page.getByRole("button", {
    name: "Toggle navigation",
    exact: true,
  });
  if (await toggle.isVisible()) await toggle.click();
  await page.getByRole("button", { name, exact: true }).click();
  await frame(page);
}
async function production(phase, trial, profile) {
  const context = await browser.newContext({
    viewport: profile.viewport,
    isMobile: profile.mobile,
    hasTouch: profile.mobile,
    locale: "en-AU",
    timezoneId: "Australia/Sydney",
    reducedMotion: "reduce",
  });
  try {
    const page = await context.newPage();
    page.setDefaultTimeout(60000);
    const issues = [];
    page.on("pageerror", (error) => issues.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") issues.push(message.text());
    });
    await page.route("**/*", (route) => {
      const url = new URL(route.request().url());
      if (url.protocol.startsWith("http") && url.origin !== origins[phase]) {
        issues.push("Unexpected external origin: " + url.origin);
        return route.abort();
      }
      return route.continue();
    });
    const cdp = await context.newCDPSession(page);
    await cdp.send("Performance.enable");
    await cdp.send("Network.enable");
    await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: profile.cpu });
    if (profile.mobile)
      await cdp.send("Network.emulateNetworkConditions", {
        offline: false,
        latency: 150,
        downloadThroughput: 200000,
        uploadThroughput: 93750,
        connectionType: "cellular4g",
      });
    await observe(page);
    await page.goto(origins[phase], { waitUntil: "load", timeout: 60000 });
    await page
      .getByRole("heading", {
        name: "A little stronger, every day.",
        exact: true,
      })
      .waitFor();
    await page.evaluate(async () => {
      await document.fonts.ready;
      await Promise.all(
        [...document.images]
          .filter((image) => {
            const bounds = image.getBoundingClientRect();
            return bounds.top < innerHeight && bounds.bottom > 0;
          })
          .map((image) => image.decode().catch(() => {})),
      );
    });
    // Paint observers can report after load and the first two frames. Wait for
    // an actual candidate before taking the cold snapshot, rather than treating
    // an empty desktop observer buffer as a zero LCP.
    await page.waitForFunction(
      () =>
        !PerformanceObserver.supportedEntryTypes.includes(
          "largest-contentful-paint",
        ) || window.auditMetrics.lcp.length > 0,
    );
    await frame(page);
    const cold = await page.evaluate(() => ({
      readyAt: performance.now(),
      navigation: performance.getEntriesByType("navigation")[0].toJSON(),
      paint: performance
        .getEntriesByType("paint")
        .map((entry) => entry.toJSON()),
      resources: performance.getEntriesByType("resource").map((entry) => ({
        name: new URL(entry.name).pathname,
        transferSize: entry.transferSize,
        encodedBodySize: entry.encodedBodySize,
        decodedBodySize: entry.decodedBodySize,
      })),
      metrics: structuredClone(window.auditMetrics),
    }));
    await navigate(page, "My routines");
    await page
      .getByRole("heading", { name: "Make every session yours.", exact: true })
      .waitFor();
    await page.locator(".routine-card").first().click();
    await page
      .getByRole("button", { name: "Start workout", exact: true })
      .click();
    await page
      .getByLabel("Barbell bench press set 1 weight", { exact: true })
      .fill("50");
    await page
      .getByRole("button", {
        name: "Complete Barbell bench press set 1",
        exact: true,
      })
      .click();
    await frame(page);
    const interactions = await page.evaluate(() =>
      structuredClone(window.auditMetrics),
    );
    const { metrics } = await cdp.send("Performance.getMetrics");
    results.push({
      phase,
      trial,
      profile,
      issues,
      cold,
      interactions,
      runtime: Object.fromEntries(
        metrics.map((entry) => [entry.name, entry.value]),
      ),
    });
    if (issues.length)
      throw new Error("The lab journey recorded browser errors.");
  } finally {
    await context.close();
  }
}
async function react(phase, trial) {
  const context = await browser.newContext({
    viewport: { width: 1536, height: 1024 },
    reducedMotion: "reduce",
    timezoneId: "Australia/Sydney",
  });
  try {
    const page = await context.newPage();
    const issues = [];
    page.on("pageerror", (error) => issues.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") issues.push(message.text());
    });
    const fixture = { ...structuredClone(initialData), revision: 0 };
    fixture.history = Array.from({ length: 2000 }, (_, index) => ({
      id: "audit-history-" + index,
      name: "Synthetic session",
      startedAt: 1700000000000 + index * 1000,
      date: new Date(1700000000000 + index * 1000).toISOString(),
      duration: 60,
      notes: "",
      exercises: [
        { exerciseId: "bench", sets: [{ weight: 50, reps: 8, done: true }] },
      ],
    }));
    fixture.active = {
      id: "audit-active",
      name: "Synthetic training",
      startedAt: Date.now() - 30000,
      notes: "",
      restSeconds: 90,
      restEnd: null,
      restPaused: null,
      exercises: [
        { exerciseId: "bench", sets: [{ weight: 40, reps: 8, done: false }] },
      ],
    };
    await page.addInitScript((data) => {
      localStorage.setItem("forma-v1", JSON.stringify(data));
      window.auditReact = [];
      window.auditStage = "mount";
      window.recordAuditRender = (
        id,
        renderPhase,
        actualDuration,
        baseDuration,
        startTime,
        commitTime,
      ) =>
        window.auditReact.push({
          id,
          renderPhase,
          actualDuration,
          baseDuration,
          startTime,
          commitTime,
          stage: window.auditStage,
        });
    }, fixture);
    let inputHash;
    await page.route(/\/src\/main\.jsx(?:\?.*)?$/, async (route) => {
      const response = await route.fetch();
      const body = await response.text();
      inputHash = createHash("sha256").update(body).digest("hex");
      const marker = 'createRoot(document.getElementById("root")).render(';
      const position = body.indexOf(marker);
      if (position < 0)
        throw new Error(
          "Transformed main module changed; refusing to guess a profiling patch.",
        );
      const render =
        'createRoot(document.getElementById("root")).render(React.createElement(React.StrictMode, null, React.createElement(React.Profiler, {id:"audit",onRender:window.recordAuditRender}, React.createElement(ErrorBoundary, null, React.createElement(AccountProvider, null, React.createElement(App))))));';
      await route.fulfill({ response, body: body.slice(0, position) + render });
    });
    await page.goto(origins[phase] + "/#workout");
    await page
      .getByRole("heading", { name: "Synthetic training", exact: true })
      .waitFor();
    await page.evaluate(() => {
      window.auditStage = "idle timer";
    });
    await page.evaluate(
      () =>
        new Promise((resolve) => {
          const start = performance.now();
          function tick() {
            if (performance.now() - start >= 3000) resolve();
            else requestAnimationFrame(tick);
          }
          requestAnimationFrame(tick);
        }),
    );
    await page.evaluate(() => {
      window.auditStage = "edit and complete";
    });
    await page
      .getByLabel("Barbell bench press set 1 weight", { exact: true })
      .fill("52");
    await page
      .getByRole("button", {
        name: "Complete Barbell bench press set 1",
        exact: true,
      })
      .click();
    await frame(page);
    await page.evaluate(() => {
      window.auditStage = "progress";
    });
    await navigate(page, "Progress");
    await page
      .getByRole("heading", {
        name: "See your strength take shape.",
        exact: true,
      })
      .waitFor();
    await frame(page);
    const samples = await page.evaluate(() => window.auditReact);
    if (!samples.length)
      throw new Error("The React profiler returned no samples.");
    results.push({
      phase,
      trial,
      inputHash,
      historySessions: 2000,
      samples,
      issues,
    });
    if (issues.length)
      throw new Error("The React profiling journey recorded browser errors.");
  } finally {
    await context.close();
  }
}
try {
  for (let trial = 1; trial <= (mode === "production" ? 5 : 3); trial++) {
    for (const phase of trial % 2 ? ["before", "after"] : ["after", "before"]) {
      if (mode === "react") await react(phase, trial);
      else
        for (const profile of [
          {
            name: "desktop",
            viewport: { width: 1536, height: 1024 },
            mobile: false,
            cpu: 1,
          },
          {
            name: "mobile lab",
            viewport: { width: 390, height: 844 },
            mobile: true,
            cpu: 4,
          },
        ])
          await production(phase, trial, profile);
      await writeFile(
        output + "/" + mode + ".json",
        JSON.stringify(receipt, null, 2) + "\n",
      );
      process.stdout.write(
        JSON.stringify({ phase, trial, mode, completed: results.length }) +
          "\n",
      );
    }
  }
} catch (error) {
  receipt.error = error.stack;
  process.exitCode = 1;
} finally {
  await browser.close();
  await writeFile(
    output + "/" + mode + ".json",
    JSON.stringify(receipt, null, 2) + "\n",
  );
}
