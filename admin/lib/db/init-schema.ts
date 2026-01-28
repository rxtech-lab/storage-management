import type { Client } from "@libsql/client";
import { readFileSync } from "fs";
import { join } from "path";

let schemaInitialized = false;

export async function initializeSchema(client: Client) {
  // Skip if already initialized in this process
  if (schemaInitialized) {
    return;
  }

  // Read the migration SQL file
  const migrationPath = join(process.cwd(), "lib/db/migrations/0000_certain_jack_flag.sql");
  const migrationSQL = readFileSync(migrationPath, "utf-8");

  // Split by statement-breakpoint and execute each statement
  const statements = migrationSQL
    .split("--> statement-breakpoint")
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    // Replace CREATE TABLE with CREATE TABLE IF NOT EXISTS
    .map((s) => s.replace(/CREATE TABLE `/g, "CREATE TABLE IF NOT EXISTS `"));

  for (const statement of statements) {
    await client.execute(statement);
  }

  schemaInitialized = true;
}
