import { drizzle } from "drizzle-orm/libsql";
import { createDatabaseClient } from "./client";
import * as schema from "./schema";

const client = createDatabaseClient();

// For e2e tests with in-memory DB, we'll initialize schema on first query
// For production with Turso, schema already exists
export const db = drizzle(client, { schema });

export * from "./schema";
