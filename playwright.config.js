import { defineConfig } from "@playwright/test";

const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;

export default defineConfig({
  testDir: "./tests",
  testIgnore: ["production.spec.js"],
  workers: 2,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI
    ? [
        ["line"],
        ["html", { outputFolder: "playwright-report/dev", open: "never" }],
      ]
    : "list",
  outputDir: "test-results/dev",
  projects: [
    {
      name: "chromium",
      use: {
        browserName: "chromium",
        ...(executablePath ? { launchOptions: { executablePath } } : {}),
      },
    },
    { name: "firefox", use: { browserName: "firefox" } },
    { name: "webkit", use: { browserName: "webkit" } },
  ],
  use: {
    baseURL: "http://127.0.0.1:5173",
    viewport: { width: 1536, height: 1024 },
    headless: true,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev -- --host 127.0.0.1 --port 5173 --strictPort",
    url: "http://127.0.0.1:5173",
    reuseExistingServer:
      !process.env.CI && process.env.PLAYWRIGHT_REUSE_SERVER === "1",
    timeout: 120_000,
  },
});
