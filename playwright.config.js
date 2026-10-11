import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  workers: 2,
  projects: [
    { name: "chromium", use: { browserName: "chromium" } },
    { name: "firefox", use: { browserName: "firefox" } },
  ],
  use: { viewport: { width: 1536, height: 1024 }, headless: true },
  webServer: {
    command: "npm run dev -- --port 5173",
    url: "http://localhost:5173",
    reuseExistingServer: true,
  },
});
