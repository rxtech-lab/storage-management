import { tmpdir } from "node:os";
import { join } from "node:path";
import { defineConfig, devices } from "@playwright/test";

const port = process.env.PLAYWRIGHT_PORT || "3000";
const baseURL = `http://localhost:${port}`;
const e2eDatabasePath = join(tmpdir(), `storage-e2e-${process.pid}.db`);

export default defineConfig({
  metadata: { e2eDatabasePath },
  testDir: "./e2e",
  fullyParallel: false, // Keep database mutations deterministic
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? "github" : "list",
  timeout: 60000, // 60 seconds per test
  globalSetup: "./playwright.global-setup.ts",
  globalTeardown: "./playwright.global-teardown.ts",

  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    actionTimeout: 10000,
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],

  webServer: {
    command: `bun run scripts/prepare-e2e-db.ts && bun run dev --port ${port}`,
    url: baseURL,
    // Never reuse an already-running localhost:3000 server; it may belong to another project.
    reuseExistingServer: false,
    timeout: 120000,
    env: {
      IS_E2E: "true",
      USE_LOCAL_DB: "false",
      E2E_DATABASE_URL: `file:${e2eDatabasePath}`,
      E2E_SCHEMA_INITIALIZED: "true",
      AUTH_SECRET: "test-secret",
      AUTH_ISSUER: "https://test.example.com",
      AUTH_CLIENT_ID: "test-client",
      AUTH_CLIENT_SECRET: "test-secret",
      NEXT_PUBLIC_URL: baseURL,
      APPLE_TEAM_ID: "TESTTEAMID",
      APPLE_APP_BUNDLE_ID: "com.test.app",
      APPLE_APP_CLIP_BUNDLE_ID: "com.test.app.Clip",
    },
  },
});
