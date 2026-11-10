import type { FullConfig } from "@playwright/test";
import { rm } from "node:fs/promises";

async function globalTeardown(config: FullConfig) {
  const path = config.metadata.e2eDatabasePath as string | undefined;
  if (path) {
    await Promise.all([path, `${path}-shm`, `${path}-wal`].map(file => rm(file, { force: true })));
  }
  console.log("E2E tests completed.");
}

export default globalTeardown;
