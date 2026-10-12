import { defineConfig, devices } from "@playwright/test";

const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
const apiUrl = "http://127.0.0.1:3001/healthz";
const webUrl = "http://127.0.0.1:5175";
const productionBuild = process.env.FORMA_ACCOUNT_BUILD === "1";
const webCommand = productionBuild
  ? "npm run build && npm run preview -- --host 127.0.0.1 --port 5175 --strictPort"
  : "npm run dev -- --host 127.0.0.1 --port 5175 --strictPort";

export default defineConfig({
  testDir: "./tests",
  testMatch: "accounts*.spec.js",
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? [["line"], ["github"]] : "list",
  outputDir: "test-results/accounts",
  projects: [
    {
      name: productionBuild
        ? "accounts-production-chromium"
        : "accounts-chromium",
      use: {
        browserName: "chromium",
        ...(executablePath ? { launchOptions: { executablePath } } : {}),
      },
    },
    {
      name: productionBuild
        ? "accounts-production-chromium-mobile"
        : "accounts-chromium-mobile",
      use: {
        ...devices["iPhone 13"],
        browserName: "chromium",
        ...(executablePath ? { launchOptions: { executablePath } } : {}),
      },
    },
    {
      name: productionBuild
        ? "accounts-production-firefox"
        : "accounts-firefox",
      use: { browserName: "firefox" },
    },
    {
      name: productionBuild ? "accounts-production-webkit" : "accounts-webkit",
      use: { browserName: "webkit" },
    },
    {
      name: productionBuild
        ? "accounts-production-webkit-mobile"
        : "accounts-webkit-mobile",
      use: { ...devices["iPhone 13"], browserName: "webkit" },
    },
  ],
  use: {
    baseURL: webUrl,
    viewport: { width: 1280, height: 900 },
    headless: true,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  webServer: [
    {
      command: "npm run accounts:test-server",
      url: apiUrl,
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      command: webCommand,
      url: webUrl,
      env: {
        FORMA_API_TARGET: "http://127.0.0.1:3001",
        FORMA_DEV_WORKER_SECRET:
          "forma-local-worker-secret-at-least-32-characters",
        VITE_ACCOUNT_MODE: "account",
      },
      reuseExistingServer: false,
      timeout: 120_000,
    },
  ],
});
