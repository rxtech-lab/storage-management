async function globalSetup() {
  console.log("Starting e2e tests with an isolated SQLite database");
  // Schema will be initialized automatically by lib/db/client.ts
}

export default globalSetup;
