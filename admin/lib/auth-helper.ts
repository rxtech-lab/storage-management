import { auth } from "@/auth";
import type { Session } from "next-auth";

/**
 * Extract Bearer token from Authorization header
 */
export function getBearerToken(request: Request): string | null {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }
  return authHeader.substring(7);
}

/**
 * Verify Bearer token by calling the OAuth provider's userinfo endpoint
 */
export async function verifyBearerToken(
  token: string
): Promise<Session | null> {
  try {
    const response = await fetch(
      `${process.env.AUTH_ISSUER}/api/oauth/userinfo`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }
    );

    if (!response.ok) {
      console.error("Bearer token verification failed:", response.status);
      return null;
    }

    const userInfo = await response.json();

    // Convert userinfo response to Session format
    return {
      user: {
        id: userInfo.sub || userInfo.id || "unknown",
        name: userInfo.name || null,
        email: userInfo.email || null,
        image: userInfo.picture || null,
      },
      accessToken: token,
      expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  } catch (error) {
    console.error("Error verifying bearer token:", error);
    return null;
  }
}

/**
 * Get the current session with support for both Bearer tokens and session-based auth.
 * In e2e mode (IS_E2E=true), returns a mock session automatically.
 * Otherwise, tries Bearer token first (if request provided), then falls back to session-based auth.
 *
 * @param request - Optional NextRequest to extract Bearer token from
 */
export async function getSession(
  request?: Request
): Promise<Session | null> {
  // Return mock session for e2e tests
  // Support custom test user ID via X-Test-User-Id header for multi-user testing
  if (process.env.IS_E2E === "true") {
    const testUserId = request?.headers.get("X-Test-User-Id") || "test-user-id";
    return {
      user: {
        id: testUserId,
        name: "Test User",
        email: "test@example.com",
        image: null,
      },
      expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  // Try Bearer token authentication first (for mobile/API clients)
  if (request) {
    const token = getBearerToken(request);
    if (token) {
      const session = await verifyBearerToken(token);
      if (session) {
        return session;
      }
    }
  }

  // Fall back to session-based auth (for web app)
  return await auth();
}
