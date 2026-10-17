import { defineConfig, devices } from "@playwright/test";

const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
const chromiumLaunchOptions = executablePath
  ? { launchOptions: { executablePath } }
  : {};

export default defineConfig({
  testDir: "./tests",
  testMatch: [
    "production.spec.js",
    "catalog.spec.js",
    "navigation-release.spec.js",
    "routine-programming.spec.js",
    "routine-archive.spec.js",
  ],
  workers: 2,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI
    ? [
        ["line"],
        ["github"],
        [
          "html",
          { outputFolder: "playwright-report/production", open: "never" },
        ],
      ]
    : "list",
  outputDir: "test-results/production",
  projects: [
    {
      name: "production-chromium-desktop",
      use: {
        browserName: "chromium",
        ...chromiumLaunchOptions,
        viewport: { width: 1536, height: 1024 },
      },
    },
    {
      name: "production-firefox-desktop",
      use: {
        browserName: "firefox",
        viewport: { width: 1536, height: 1024 },
      },
    },
    {
      name: "production-webkit-desktop",
      use: {
        browserName: "webkit",
        viewport: { width: 1536, height: 1024 },
      },
    },
    {
      name: "production-chromium-mobile",
      use: {
        ...devices["iPhone 13"],
        browserName: "chromium",
        ...chromiumLaunchOptions,
      },
    },
    {
      name: "production-webkit-mobile",
      use: { ...devices["iPhone 13"], browserName: "webkit" },
    },
  ],
  use: {
    baseURL: "http://127.0.0.1:4173",
    headless: true,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run preview -- --host 127.0.0.1 --port 4173 --strictPort",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
