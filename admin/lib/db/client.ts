import { createClient } from "@libsql/client";

let clientInstance: ReturnType<typeof createClient> | null = null;
let initPromise: Promise<void> | null = null;

export function createDatabaseClient() {
  if (clientInstance) {
    return clientInstance;
  }

  if (process.env.IS_E2E === "true") {
    // Use in-memory SQLite for e2e tests
    clientInstance = createClient({ url: ":memory:" });

    // Initialize schema asynchronously (idempotent - uses CREATE TABLE IF NOT EXISTS)
    if (!initPromise) {
      initPromise = (async () => {
        const { initializeSchema } = await import("./init-schema");
        await initializeSchema(clientInstance!);
      })();
    }

    return clientInstance;
  }

  // Production Turso client
  clientInstance = createClient({
    url: process.env.TURSO_DATABASE_URL!,
    authToken: process.env.TURSO_AUTH_TOKEN,
  });

  return clientInstance;
}

// Helper to ensure schema is initialized before queries (for e2e)
export async function ensureSchemaInitialized() {
  if (process.env.IS_E2E === "true" && initPromise) {
    await initPromise;
  }
}
