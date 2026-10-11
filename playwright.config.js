import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  use: { viewport: { width: 1536, height: 1024 }, headless: true },
  webServer: {
    command: "npm run dev -- --port 5173",
    url: "http://localhost:5173",
    reuseExistingServer: true,
  },
});
