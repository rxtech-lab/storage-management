import type { Client } from "@libsql/client";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";

let schemaInitialized = false;

export async function initializeSchema(client: Client) {
  // Skip if already initialized in this process
  if (schemaInitialized) {
    return;
  }

  const migrationsDir = join(process.cwd(), "lib/db/migrations");

  // Read all SQL migration files in order
  const migrationFiles = readdirSync(migrationsDir)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  for (const file of migrationFiles) {
    const migrationPath = join(migrationsDir, file);
    const migrationSQL = readFileSync(migrationPath, "utf-8");

    // Split by statement-breakpoint and execute each statement
    const statements = migrationSQL
      .split("--> statement-breakpoint")
      .map((s) => s.trim())
      .filter((s) => s.length > 0)
      // Replace CREATE TABLE with CREATE TABLE IF NOT EXISTS
      .map((s) => s.replace(/CREATE TABLE `/g, "CREATE TABLE IF NOT EXISTS `"))
      // Skip ALTER TABLE statements for in-memory DB (columns already exist in latest schema)
      .filter((s) => !s.startsWith("ALTER TABLE"));

    for (const statement of statements) {
      try {
        await client.execute(statement);
      } catch (error) {
        // Ignore errors for idempotent operations (e.g., table already exists)
        console.warn(`Migration statement warning (${file}):`, error);
      }
    }
  }

  schemaInitialized = true;
}
