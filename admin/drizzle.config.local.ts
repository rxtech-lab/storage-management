import { defineConfig } from "drizzle-kit";
import { join } from "path";

const dbPath = process.env.LOCAL_DB_PATH || join(process.cwd(), ".local-data", "local.db");

export default defineConfig({
  schema: "./lib/db/schema/index.ts",
  out: "./lib/db/migrations",
  dialect: "sqlite",
  dbCredentials: {
    url: dbPath,
  },
});
