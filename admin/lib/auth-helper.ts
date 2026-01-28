import { auth } from "@/auth";
import type { Session } from "next-auth";

/**
 * Get the current session, with e2e test support.
 * In e2e mode (IS_E2E=true), returns a mock session automatically.
 * Otherwise, calls the actual auth() function.
 */
export async function getSession(): Promise<Session | null> {
  // Return mock session for e2e tests
  if (process.env.IS_E2E === "true") {
    return {
      user: {
        id: "test-user-id",
        name: "Test User",
        email: "test@example.com",
        image: null,
      },
      expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  // Normal auth flow
  return await auth();
}
