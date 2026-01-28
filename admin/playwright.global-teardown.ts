async function globalTeardown() {
  console.log('E2E tests completed. In-memory database auto-cleaned.');
  // In-memory database is automatically destroyed when process terminates
}

export default globalTeardown;
