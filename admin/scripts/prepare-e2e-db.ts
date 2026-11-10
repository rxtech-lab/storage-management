import { createClient } from "@libsql/client";
import { initializeSchema } from "../lib/db/init-schema";

const url = process.env.E2E_DATABASE_URL;
if (process.env.IS_E2E !== "true" || !url?.startsWith("file:")) {
  throw new Error("E2E setup requires IS_E2E=true and a file-based E2E_DATABASE_URL");
}

// Finish all DDL before Next.js starts separate route workers on the shared file.
const client = createClient({ url });
try {
  await initializeSchema(client);
} finally {
  client.close();
}
